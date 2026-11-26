from __future__ import annotations

import os
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse
from openai import OpenAI
from pydantic import BaseModel, Field

app = FastAPI(title="App Builder Bot")


class Prompt(BaseModel):
    prompt: str = Field(min_length=8, max_length=4000)


@app.get("/", response_class=HTMLResponse)
def home() -> str:
    return (Path(__file__).parent / "static" / "index.html").read_text()


@app.post("/api/generate")
def generate(body: Prompt) -> dict[str, str]:
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise HTTPException(status_code=503, detail="Set OPENAI_API_KEY on the server first.")
    try:
        client = OpenAI(api_key=api_key)
        response = client.chat.completions.create(
            model=os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
            messages=[
                {"role": "system", "content": "Generate a safe, self-contained Flutter lib/main.dart for the user's app idea. Return only Dart source code, no markdown. Do not include secrets or claim that the code was compiled."},
                {"role": "user", "content": body.prompt},
            ],
            max_tokens=5000,
        )
        code = response.choices[0].message.content or ""
        return {"file": "lib/main.dart", "code": code}
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Generation request failed: {exc.__class__.__name__}") from exc
