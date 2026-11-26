// POST /api/generate  { "prompt": "..." }  ->  { "file": "lib/main.dart", "code": "..." }
// Requires header X-App-Key matching the APP_KEY env var.
// AI provider: OpenAI directly when OPENAI_API_KEY is set; otherwise Vercel AI Gateway
// (free monthly credits) authenticated with the deployment's Vercel OIDC token or AI_GATEWAY_API_KEY.
// Env: APP_KEY (required), OPENAI_API_KEY (optional), OPENAI_MODEL (optional), AI_GATEWAY_MODEL (optional),
//      RATE_LIMIT_PER_MIN (optional, default 6), OPENAI_TIMEOUT_MS (optional, default 50000).
'use strict';

const crypto = require('node:crypto');

const MIN_PROMPT = 8;
const MAX_PROMPT = 4000;
const RATE_WINDOW_MS = 60_000;
const RATE_LIMIT = Number(process.env.RATE_LIMIT_PER_MIN || 6);
const TIMEOUT_MS = Number(process.env.OPENAI_TIMEOUT_MS || 50_000);

const SYSTEM_PROMPT = [
  "You generate a single, complete, self-contained Flutter `lib/main.dart` for the user's app idea.",
  'Rules:',
  '- Return ONLY Dart source code. No markdown, no code fences, no explanations before or after.',
  '- Use only the Flutter SDK (package:flutter/material.dart and dart: libraries). No third-party packages.',
  '- Use Material 3 (useMaterial3: true) with light and dark themes.',
  '- The code must compile with the current stable Flutter SDK and null safety.',
  '- Never include API keys, secrets or real personal data.',
].join('\n');

// Best-effort in-memory rate limit. Each warm function instance keeps its own counters,
// so this slows down abuse but is not a global guarantee.
const hits = new Map();

function clientIp(req) {
  const fwd = String(req.headers['x-forwarded-for'] || '');
  return (fwd.split(',')[0] || req.headers['x-real-ip'] || req.socket?.remoteAddress || 'unknown').trim();
}

function rateLimited(ip) {
  const now = Date.now();
  const recent = (hits.get(ip) || []).filter((t) => now - t < RATE_WINDOW_MS);
  if (recent.length >= RATE_LIMIT) {
    hits.set(ip, recent);
    return Math.ceil((RATE_WINDOW_MS - (now - recent[0])) / 1000);
  }
  recent.push(now);
  hits.set(ip, recent);
  if (hits.size > 5000) {
    for (const [k, v] of hits) if (!v.length || now - v[v.length - 1] > RATE_WINDOW_MS) hits.delete(k);
  }
  return 0;
}

function safeEqual(a, b) {
  const ha = crypto.createHash('sha256').update(String(a)).digest();
  const hb = crypto.createHash('sha256').update(String(b)).digest();
  return crypto.timingSafeEqual(ha, hb);
}

function stripFences(text) {
  let s = String(text || '').trim();
  const block = s.match(/```[a-zA-Z0-9_+-]*[ \t]*\r?\n([\s\S]*?)```/);
  if (block) s = block[1];
  else s = s.replace(/^```[a-zA-Z0-9_+-]*[ \t]*\r?\n?/, '').replace(/\r?\n?```\s*$/, '');
  return s.trim() + '\n';
}

function redact(msg) {
  return String(msg || '').replace(/sk-[A-Za-z0-9_\-*.]{4,}/g, 'sk-***').slice(0, 300);
}

function send(res, status, body, extraHeaders = {}) {
  for (const [k, v] of Object.entries(extraHeaders)) res.setHeader(k, v);
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.statusCode = status;
  res.end(JSON.stringify(body));
}

function fail(res, status, code, message, extra = {}) {
  send(res, status, { error: code, detail: message }, extra);
}

async function readJson(req) {
  if (req.body !== undefined && req.body !== null) {
    if (typeof req.body === 'string') return JSON.parse(req.body);
    if (Buffer.isBuffer(req.body)) return JSON.parse(req.body.toString('utf8'));
    return req.body;
  }
  const chunks = [];
  for await (const c of req) chunks.push(c);
  const raw = Buffer.concat(chunks).toString('utf8');
  return raw ? JSON.parse(raw) : {};
}

function pickProvider(req) {
  if (process.env.OPENAI_API_KEY) {
    return {
      name: 'OpenAI',
      url: 'https://api.openai.com/v1/chat/completions',
      token: process.env.OPENAI_API_KEY,
      model: process.env.OPENAI_MODEL || 'gpt-4o-mini',
    };
  }
  const token = process.env.AI_GATEWAY_API_KEY || req.headers['x-vercel-oidc-token'] || process.env.VERCEL_OIDC_TOKEN;
  if (!token) return null;
  return {
    name: 'Vercel AI Gateway',
    url: 'https://ai-gateway.vercel.sh/v1/chat/completions',
    token,
    model: process.env.AI_GATEWAY_MODEL || 'openai/gpt-4.1-mini',
  };
}

module.exports = async function handler(req, res) {
  if (req.method === 'OPTIONS') {
    res.setHeader('Allow', 'POST, OPTIONS');
    res.statusCode = 204;
    return res.end();
  }
  if (req.method !== 'POST') {
    return fail(res, 405, 'method_not_allowed', 'Use POST with a JSON body: {"prompt": "..."}', { Allow: 'POST, OPTIONS' });
  }

  const appKey = process.env.APP_KEY;
  if (!appKey) return fail(res, 503, 'server_not_configured', 'The server is missing APP_KEY. Set it in the Vercel project settings.');
  const given = req.headers['x-app-key'];
  if (!given) return fail(res, 401, 'missing_app_key', 'Missing X-App-Key header. Add your app key in Settings.');
  if (!safeEqual(given, appKey)) return fail(res, 401, 'invalid_app_key', 'The app key is wrong. Check it in Settings.');

  const wait = rateLimited(clientIp(req));
  if (wait) return fail(res, 429, 'rate_limited', `Too many requests. Try again in ${wait} seconds.`, { 'Retry-After': String(wait) });

  let body;
  try {
    body = await readJson(req);
  } catch {
    return fail(res, 400, 'invalid_json', 'The request body must be JSON like {"prompt": "..."}.');
  }
  const prompt = typeof body?.prompt === 'string' ? body.prompt.trim() : '';
  if (!prompt) return fail(res, 400, 'empty_prompt', 'Describe the app you want before generating.');
  if (prompt.length < MIN_PROMPT) return fail(res, 400, 'prompt_too_short', `Please write at least ${MIN_PROMPT} characters.`);
  if (prompt.length > MAX_PROMPT) return fail(res, 400, 'prompt_too_long', `Please keep it under ${MAX_PROMPT} characters (you sent ${prompt.length}).`);

  const provider = pickProvider(req);
  if (!provider) {
    return fail(res, 503, 'no_ai_provider', 'No AI provider is configured. Set OPENAI_API_KEY, or enable Vercel OIDC / AI_GATEWAY_API_KEY for the free AI Gateway.');
  }
  const { url, token, model, name } = provider;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const r = await fetch(url, {
      method: 'POST',
      signal: controller.signal,
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model,
        messages: [
          { role: 'system', content: SYSTEM_PROMPT },
          { role: 'user', content: prompt },
        ],
        max_completion_tokens: 6000,
      }),
    });
    const data = await r.json().catch(() => ({}));
    if (!r.ok) {
      const upstream = redact(data?.error?.message || `HTTP ${r.status}`);
      if (r.status === 401 || r.status === 403) return fail(res, 502, 'ai_auth', `The server's ${name} credentials were rejected: ${upstream}`);
      if (r.status === 402) return fail(res, 503, 'ai_out_of_credit', `${name} is out of credit: ${upstream}`);
      if (r.status === 429) return fail(res, 503, 'ai_busy', `${name} is rate limiting or out of credit. Try again later: ${upstream}`);
      return fail(res, 502, 'ai_error', `${name} returned an error (${r.status}): ${upstream}`);
    }
    const content = data?.choices?.[0]?.message?.content;
    if (!content) return fail(res, 502, 'empty_response', 'The AI returned no code. Try rephrasing your idea.');
    return send(res, 200, { file: 'lib/main.dart', code: stripFences(content), model, provider: name });
  } catch (err) {
    if (err?.name === 'AbortError') {
      return fail(res, 504, 'timeout', `Generation took longer than ${Math.round(TIMEOUT_MS / 1000)} seconds. Try a shorter or simpler idea.`);
    }
    return fail(res, 502, 'network_error', `Could not reach ${name}: ${redact(err?.message)}`);
  } finally {
    clearTimeout(timer);
  }
};

module.exports.stripFences = stripFences;
