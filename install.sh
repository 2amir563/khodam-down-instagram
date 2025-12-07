#!/bin/bash

# Instagram Video Downloader Telegram Bot
# Run: bash <(curl -s https://raw.githubusercontent.com/2amir563/khodam-down-instagram/main/install.sh)

set -e

echo "=========================================="
echo "Instagram Video Downloader Bot Installer"
echo "=========================================="

# Install dependencies
apt-get update -y
apt-get install -y python3 python3-pip ffmpeg

# Create directory
INSTALL_DIR="/opt/instagram_video_bot"
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Python packages
pip install --upgrade pip
pip install yt-dlp python-telegram-bot

# Get bot token
echo ""
echo "=========================================="
echo "TELEGRAM BOT TOKEN"
echo "=========================================="
echo "Get token from @BotFather on Telegram"
echo "=========================================="
echo ""

read -p "Enter your Telegram Bot Token: " BOT_TOKEN

# Create config
echo "TOKEN = '$BOT_TOKEN'" > config.py

# Create bot.py
cat > bot.py << 'BOT_EOF'
#!/usr/bin/env python3
"""
Instagram Video Downloader Telegram Bot
Simple and working version
"""

import os
import sys
import logging
import tempfile
import time
from datetime import datetime

import yt_dlp
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes

# Load config
try:
    sys.path.append(os.path.dirname(os.path.abspath(__file__)))
    from config import TOKEN
except ImportError:
    print("ERROR: config.py not found!")
    sys.exit(1)

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command"""
    await update.message.reply_text(
        "🎬 *Instagram Video Downloader*\n\n"
        "ارسال کنید: لینک اینستاگرام\n"
        "دریافت کنید: ویدیو\n\n"
        "_مثال لینک:_\n"
        "https://www.instagram.com/reel/DNThWFaopCk/",
        parse_mode='Markdown'
    )

async def help_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /help command"""
    await update.message.reply_text(
        "📖 فقط لینک اینستاگرام بفرستید.\n"
        "ربات ویدیو را دانلود و ارسال می‌کند."
    )

def download_instagram_video(url):
    """Download Instagram video using yt-dlp"""
    try:
        # Create temp directory
        temp_dir = tempfile.mkdtemp(prefix="instagram_")
        output_template = os.path.join(temp_dir, '%(title)s.%(ext)s')
        
        # yt-dlp options for Instagram
        ydl_opts = {
            'format': 'best',
            'outtmpl': output_template,
            'quiet': True,
            'no_warnings': True,
            'extract_flat': False,
            'merge_output_format': 'mp4',
            'postprocessors': [{
                'key': 'FFmpegVideoConvertor',
                'preferedformat': 'mp4',
            }],
            'http_headers': {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                'Accept-Language': 'en-US,en;q=0.5',
                'Accept-Encoding': 'gzip, deflate',
            }
        }
        
        logger.info(f"Downloading: {url}")
        
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=True)
            filename = ydl.prepare_filename(info)
            
            # Find the actual downloaded file
            if not os.path.exists(filename):
                # Look for any video file in temp directory
                for file in os.listdir(temp_dir):
                    if file.endswith(('.mp4', '.webm', '.mkv')):
                        filename = os.path.join(temp_dir, file)
                        break
            
            if os.path.exists(filename):
                file_size = os.path.getsize(filename)
                return {
                    'success': True,
                    'filename': filename,
                    'title': info.get('title', 'Instagram Video'),
                    'duration': info.get('duration', 0),
                    'file_size': file_size,
                    'temp_dir': temp_dir
                }
            else:
                return {'success': False, 'error': 'File not found after download'}
                
    except Exception as e:
        logger.error(f"Download error: {e}")
        return {'success': False, 'error': str(e)}

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle incoming messages"""
    url = update.message.text.strip()
    
    # Check if it's Instagram link
    if 'instagram.com' not in url and 'instagr.am' not in url:
        await update.message.reply_text("لطفاً لینک اینستاگرام بفرستید.")
        return
    
    # Send processing message
    msg = await update.message.reply_text("⏳ در حال دانلود ویدیو...")
    
    try:
        # Download video
        result = download_instagram_video(url)
        
        if not result['success']:
            await msg.edit_text(f"❌ خطا: {result['error']}")
            return
        
        # Send video
        file_size_mb = result['file_size'] / (1024 * 1024)
        
        with open(result['filename'], 'rb') as video_file:
            await update.message.reply_video(
                video=video_file,
                caption=f"📹 {result['title'][:50]}\n"
                       f"⏱️ {result['duration']}s | 💾 {file_size_mb:.1f}MB",
                supports_streaming=True
            )
        
        await msg.edit_text("✅ ویدیو ارسال شد!")
        
        # Cleanup
        try:
            import shutil
            shutil.rmtree(result['temp_dir'])
        except:
            pass
            
    except Exception as e:
        logger.error(f"Error: {e}")
        await msg.edit_text(f"❌ خطا: {str(e)[:100]}")

async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle errors"""
    logger.error(f"Error: {context.error}")

def main():
    """Start the bot"""
    print(f"Starting bot with token: {TOKEN[:10]}...")
    
    app = Application.builder().token(TOKEN).build()
    
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("help", help_cmd))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    app.add_error_handler(error_handler)
    
    print("Bot running...")
    app.run_polling()

if __name__ == "__main__":
    main()
BOT_EOF

# Create systemd service
cat > /etc/systemd/system/instagram-bot.service << SERVICE_EOF
[Unit]
Description=Instagram Video Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$INSTALL_DIR/venv/bin"
ExecStart=$INSTALL_DIR/venv/bin/python3 $INSTALL_DIR/bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# Start the bot
systemctl daemon-reload
systemctl enable instagram-bot.service
systemctl start instagram-bot.service

# Check status
sleep 3
systemctl status instagram-bot.service --no-pager

echo ""
echo "=========================================="
echo "✅ Installation Complete!"
echo "=========================================="
echo ""
echo "Usage:"
echo "1. Open Telegram"
echo "2. Find your bot"
echo "3. Send /start"
echo "4. Send Instagram link"
echo "5. Receive video"
echo ""
echo "Example link:"
echo "https://www.instagram.com/reel/DNThWFaopCk/"
echo ""
