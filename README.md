# App Builder Bot

A starter app-generation service with a web UI, a Telegram bot, and a Flutter mobile client. GitHub Actions can build an Android APK and an **unsigned** iOS IPA.

## Important

- An unsigned IPA is a build artifact, **not an install-ready iPhone app**. iPhone installation requires valid signing/provisioning and a supported distribution method.
- iOS builds use a GitHub-hosted macOS runner. Android builds use Linux.
- This starter generates Flutter `main.dart` source from prompts. It does not execute generated code on the server.

## Build and download APK / unsigned IPA

1. Open **Actions → Build mobile artifacts → Run workflow**.
2. Wait for the Android and iOS jobs to finish.
3. Open the workflow run and download `android-apk` and `unsigned-ios-ipa` from **Artifacts**.

The repository must have Actions enabled. GitHub-hosted runner availability and usage limits apply.

## Run the web API locally

Requires Python 3.11+.

```bash
python -m venv .venv
# Activate the environment, then:
pip install -r requirements.txt
export OPENAI_API_KEY="your-key"
uvicorn server.main:app --reload
```

Open http://127.0.0.1:8000. For Telegram, set `TELEGRAM_BOT_TOKEN` and `OPENAI_API_KEY`, then run `python -m server.telegram_bot`.

Keep secrets in environment variables or GitHub Actions secrets—never commit them. The web service is a development starter and should be protected with authentication and rate limits before public deployment.

## Flutter client

`mobile/lib/main.dart` is the client UI. Configure the API URL at build time with `--dart-define=API_BASE_URL=https://your-api.example`; the default points to localhost and is only suitable for development.
