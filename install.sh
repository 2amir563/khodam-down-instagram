#!/bin/bash

# Instagram Telegram Bot - Simple & Working Version
# Run this on your Linux server

set -e

echo "=========================================="
echo "Instagram Telegram Bot Installer"
echo "=========================================="

# Update system
apt-get update
apt-get install -y python3 python3-pip git curl

# Create directory
mkdir -p /root/instagram_bot
cd /root/instagram_bot

# Install required packages
pip3 install python-telegram-bot==20.7 requests beautifulsoup4

# Create bot.py
cat > bot.py << 'EOF'
#!/usr/bin/env python3
"""
Instagram Telegram Bot
Send Instagram link, get JSON file
"""

import os
import json
import logging
import tempfile
import re
import time
from datetime import datetime

import requests
from bs4 import BeautifulSoup
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes

# Setup logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# Your Telegram Bot Token
TOKEN = "8502213708:AAud0o3wEjhWKNPqXjY5AoNIi6fEQiL4tf4"

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command"""
    await update.message.reply_text(
        "📱 *Instagram Bot*\n\n"
        "ارسال کنید لینک اینستاگرام\n"
        "دریافت کنید فایل JSON\n\n"
        "_Just send me any Instagram link_",
        parse_mode='Markdown'
    )

async def help_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /help command"""
    await update.message.reply_text(
        "❓ *راهنما*\n\n"
        "1. لینک اینستاگرام را کپی کنید\n"
        "2. برای ربات ارسال کنید\n"
        "3. فایل JSON دریافت کنید\n\n"
        "مثال لینک:\n"
        "https://www.instagram.com/p/ABC123/\n"
        "https://instagram.com/reel/XYZ456/",
        parse_mode='Markdown'
    )

def get_instagram_data(url):
    """Get data from Instagram link"""
    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
        
        # Clean URL
        if not url.startswith('http'):
            url = 'https://' + url
        
        logger.info(f"Fetching: {url}")
        response = requests.get(url, headers=headers, timeout=15)
        html = response.text
        
        soup = BeautifulSoup(html, 'html.parser')
        
        # Extract basic info
        data = {
            'url': url,
            'timestamp': datetime.now().isoformat(),
            'status_code': response.status_code,
            'content_length': len(html)
        }
        
        # Get title
        title_tag = soup.find('title')
        if title_tag:
            data['title'] = title_tag.text.strip()
        
        # Get meta description
        meta_desc = soup.find('meta', attrs={'name': 'description'})
        if meta_desc and meta_desc.get('content'):
            data['description'] = meta_desc['content']
        
        # Get Open Graph data
        og_title = soup.find('meta', property='og:title')
        if og_title and og_title.get('content'):
            data['og_title'] = og_title['content']
        
        og_desc = soup.find('meta', property='og:description')
        if og_desc and og_desc.get('content'):
            data['og_description'] = og_desc['content']
        
        og_image = soup.find('meta', property='og:image')
        if og_image and og_image.get('content'):
            data['og_image'] = og_image['content']
        
        # Extract text content
        for script in soup(["script", "style"]):
            script.decompose()
        
        text = soup.get_text()
        lines = [line.strip() for line in text.split('\n') if line.strip()]
        data['text_content'] = '\n'.join(lines[:50])  # First 50 lines
        
        # Extract shortcode from URL
        shortcode_match = re.search(r'instagram\.com/(?:p|reel|tv)/([^/?]+)', url)
        if shortcode_match:
            data['shortcode'] = shortcode_match.group(1)
        
        # Extract usernames and hashtags from text
        usernames = re.findall(r'@([a-zA-Z0-9_.]+)', text)
        hashtags = re.findall(r'#([a-zA-Z0-9_]+)', text)
        
        if usernames:
            data['mentions'] = list(set(usernames))[:10]
        if hashtags:
            data['hashtags'] = list(set(hashtags))[:10]
        
        data['success'] = True
        return data
        
    except Exception as e:
        logger.error(f"Error: {e}")
        return {
            'success': False,
            'url': url,
            'error': str(e),
            'timestamp': datetime.now().isoformat()
        }

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle incoming Instagram links"""
    user_text = update.message.text.strip()
    
    # Check if it's Instagram link
    if 'instagram.com' not in user_text and 'instagr.am' not in user_text:
        await update.message.reply_text("لطفاً لینک اینستاگرام ارسال کنید.")
        return
    
    # Send processing message
    msg = await update.message.reply_text("در حال پردازش لینک...")
    
    try:
        # Get data
        data = get_instagram_data(user_text)
        
        if not data.get('success', False):
            await msg.edit_text("خطا در دریافت اطلاعات. لینک را بررسی کنید.")
            return
        
        # Create JSON file
        json_str = json.dumps(data, indent=2, ensure_ascii=False, default=str)
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False, encoding='utf-8') as f:
            f.write(json_str)
            temp_file = f.name
        
        # Send file
        with open(temp_file, 'rb') as file:
            await update.message.reply_document(
                document=file,
                filename=f"instagram_{data.get('shortcode', 'data')}_{int(time.time())}.json",
                caption=f"📁 فایل JSON\nلینک: {user_text[:50]}..."
            )
        
        # Cleanup
        import os
        os.unlink(temp_file)
        
        await msg.edit_text("✅ فایل JSON ارسال شد.")
        
    except Exception as e:
        logger.error(f"Error: {e}")
        await msg.edit_text(f"خطا: {str(e)[:100]}")

async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle errors"""
    logger.error(f"Error: {context.error}")

def main():
    """Start the bot"""
    print("Starting Instagram Bot...")
    print(f"Token: {TOKEN[:10]}...")
    
    app = Application.builder().token(TOKEN).build()
    
    # Add handlers
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("help", help_cmd))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    
    # Error handler
    app.add_error_handler(error_handler)
    
    print("Bot is running. Press Ctrl+C to stop.")
    app.run_polling()

if __name__ == "__main__":
    main()
EOF

# Make executable
chmod +x bot.py

# Create systemd service
cat > /etc/systemd/system/instagram-bot.service << EOF
[Unit]
Description=Instagram Telegram Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/instagram_bot
ExecStart=/usr/bin/python3 /root/instagram_bot/bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
systemctl daemon-reload
systemctl enable instagram-bot.service
systemctl start instagram-bot.service

# Check status
sleep 3
echo "Checking service status..."
systemctl status instagram-bot.service --no-pager

echo ""
echo "=========================================="
echo "✅ نصب کامل شد!"
echo "=========================================="
echo ""
echo "دستورات مدیریت:"
echo "systemctl status instagram-bot"
echo "systemctl restart instagram-bot"
echo "journalctl -u instagram-bot -f"
echo ""
echo "ربات را در تلگرام تست کنید:"
echo "1. به ربات مراجعه کنید"
echo "2. دستور /start را بفرستید"
echo "3. یک لینک اینستاگرام ارسال کنید"
echo "4. فایل JSON دریافت کنید"
echo ""
echo "مثال لینک:"
echo "https://www.instagram.com/p/CvC9FkHNrJI/"
echo ""
EOF

# Run the installer
chmod +x install.sh
./install.sh
