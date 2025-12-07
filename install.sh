#!/usr/bin/env python3
import os
import re
import json
import requests
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes

TOKEN = "8502213708:AAud0o3wEjhWKNPqXjY5AoNIi6fEQiL4tf4"

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("🤖 Send me an Instagram link!")

async def handle_link(update: Update, context: ContextTypes.DEFAULT_TYPE):
    url = update.message.text
    
    if "instagram.com" not in url:
        await update.message.reply_text("❌ Please send an Instagram link")
        return
    
    await update.message.reply_text("⏳ Processing...")
    
    try:
        # Method 1: Try to get basic info from page
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
        
        response = requests.get(url, headers=headers, timeout=10)
        
        # Extract title
        import re
        title_match = re.search(r'<title>(.*?)</title>', response.text)
        title = title_match.group(1) if title_match else "No title"
        
        # Extract description
        desc_match = re.search(r'"caption":"(.*?)"', response.text)
        description = desc_match.group(1) if desc_match else "No description"
        
        # Clean up text
        if '\\u' in description:
            description = description.encode().decode('unicode_escape')
        
        # Prepare response
        response_text = f"""
📷 Instagram Link Info:

🔗 URL: {url}
📌 Title: {title}

📝 Content:
{description[:1000] + '...' if len(description) > 1000 else description}
        """
        
        await update.message.reply_text(response_text)
        
    except Exception as e:
        await update.message.reply_text(f"❌ Error: {str(e)}")

def main():
    app = Application.builder().token(TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_link))
    print("Bot starting...")
    app.run_polling()

if __name__ == "__main__":
    main()
