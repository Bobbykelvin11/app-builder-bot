from __future__ import annotations

import os

from openai import OpenAI
from telegram import Update
from telegram.ext import Application, CommandHandler, ContextTypes, MessageHandler, filters


async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    await update.message.reply_text("Send me an app idea and I’ll generate a Flutter lib/main.dart starter. Keep prompts under 4000 characters.")


async def generate(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    prompt = (update.message.text or "").strip()
    if len(prompt) < 8 or len(prompt) > 4000:
        await update.message.reply_text("Please send an app idea between 8 and 4000 characters.")
        return
    try:
        client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])
        result = client.chat.completions.create(
            model=os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
            messages=[
                {"role": "system", "content": "Generate safe, self-contained Flutter lib/main.dart source. Return Dart code only. Do not include secrets."},
                {"role": "user", "content": prompt},
            ],
            max_tokens=3500,
        )
        code = result.choices[0].message.content or "No code returned."
        # Telegram messages have size limits; send generated source as a text document.
        from io import BytesIO
        document = BytesIO(code.encode("utf-8"))
        document.name = "main.dart"
        await update.message.reply_document(document=document, caption="Generated starter source (not compiled).")
    except Exception as exc:
        await update.message.reply_text(f"Generation failed ({exc.__class__.__name__}). Check the bot's server configuration.")


def main() -> None:
    token = os.getenv("TELEGRAM_BOT_TOKEN")
    if not token or not os.getenv("OPENAI_API_KEY"):
        raise SystemExit("Set TELEGRAM_BOT_TOKEN and OPENAI_API_KEY environment variables.")
    application = Application.builder().token(token).build()
    application.add_handler(CommandHandler("start", start))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, generate))
    application.run_polling()


if __name__ == "__main__":
    main()
