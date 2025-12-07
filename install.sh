#!/bin/bash

# Instagram Video Downloader Telegram Bot
# Run: bash <(curl -s https://raw.githubusercontent.com/2amir563/khodam-down-instagram/main/install.sh)

set -e

echo "=========================================="
echo "Instagram Video Downloader Bot Installer"
echo "=========================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Functions
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${YELLOW}[i]${NC} $1"; }

# Step 1: Install dependencies
print_info "Step 1: Installing system dependencies..."
apt-get update -y
apt-get install -y python3 python3-pip python3-venv git curl wget ffmpeg

# Step 2: Create directory
print_info "Step 2: Creating installation directory..."
INSTALL_DIR="/opt/instagram_video_bot"
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# Step 3: Create virtual environment
print_info "Step 3: Creating Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Step 4: Install Python packages
print_info "Step 4: Installing Python packages..."
pip install --upgrade pip
pip install yt-dlp==2025.11.12 python-telegram-bot==20.7 requests beautifulsoup4

# Step 5: Get Telegram Bot Token
print_info "Step 5: Setting up Telegram Bot..."
echo ""
echo "=========================================="
echo "TELEGRAM BOT TOKEN"
echo "=========================================="
echo "To get your bot token:"
echo "1. Open Telegram"
echo "2. Search for @BotFather"
echo "3. Send /newbot command"
echo "4. Follow the instructions"
echo "5. Copy the token"
echo "=========================================="
echo ""

read -p "Enter your Telegram Bot Token: " BOT_TOKEN

if [ -z "$BOT_TOKEN" ]; then
    print_error "Token cannot be empty!"
    exit 1
fi

# Create config file
cat > config.py << EOF
# Telegram Bot Configuration
TELEGRAM_TOKEN = "$BOT_TOKEN"

# Download settings
DOWNLOAD_DIR = "downloads"
MAX_FILE_SIZE = 2000  # MB
TIMEOUT = 30
EOF

# Step 6: Create the bot
print_info "Step 6: Creating bot.py..."
cat > bot.py << 'EOF'
#!/usr/bin/env python3
"""
Instagram Video Downloader Telegram Bot
Downloads and sends Instagram videos
"""

import os
import sys
import json
import logging
import tempfile
import re
import time
from datetime import datetime
from pathlib import Path

import yt_dlp
import requests
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes

# Add current directory to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Load configuration
try:
    from config import TELEGRAM_TOKEN, DOWNLOAD_DIR, MAX_FILE_SIZE, TIMEOUT
except ImportError:
    print("ERROR: config.py not found!")
    sys.exit(1)

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('bot.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class InstagramDownloader:
    def __init__(self):
        self.download_dir = Path(DOWNLOAD_DIR)
        self.download_dir.mkdir(exist_ok=True)
        
        # yt-dlp options for Instagram
        self.ydl_opts = {
            'quiet': True,
            'no_warnings': True,
            'extract_flat': False,
            'format': 'best',
            'outtmpl': str(self.download_dir / '%(title).100s.%(ext)s'),
            'merge_output_format': 'mp4',
            'postprocessors': [{
                'key': 'FFmpegVideoConvertor',
                'preferedformat': 'mp4',
            }],
            'http_headers': {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
                'Accept-Language': 'en-US,en;q=0.9',
                'Accept-Encoding': 'gzip, deflate, br',
                'Referer': 'https://www.instagram.com/',
            }
        }
        
        logger.info("Instagram Downloader initialized")
    
    def extract_shortcode(self, url):
        """Extract shortcode from Instagram URL"""
        patterns = [
            r'(?:https?://)?(?:www\.)?instagram\.com/(?:p|reel|tv)/([a-zA-Z0-9_-]+)',
            r'(?:https?://)?(?:www\.)?instagr\.am/(?:p|reel|tv)/([a-zA-Z0-9_-]+)'
        ]
        
        for pattern in patterns:
            match = re.search(pattern, url, re.IGNORECASE)
            if match:
                return match.group(1)
        return None
    
    def get_video_info(self, url):
        """Get video information without downloading"""
        try:
            ydl_opts = {
                'quiet': True,
                'no_warnings': True,
                'extract_flat': False,
                'skip_download': True,
            }
            
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=False)
                
                result = {
                    'title': info.get('title', 'Instagram Video'),
                    'duration': info.get('duration', 0),
                    'uploader': info.get('uploader', ''),
                    'upload_date': info.get('upload_date', ''),
                    'view_count': info.get('view_count', 0),
                    'like_count': info.get('like_count', 0),
                    'comment_count': info.get('comment_count', 0),
                    'formats': [],
                    'success': True
                }
                
                # Get available formats
                if 'formats' in info:
                    for fmt in info['formats']:
                        if fmt.get('vcodec') != 'none':  # Only video formats
                            result['formats'].append({
                                'format_id': fmt.get('format_id'),
                                'ext': fmt.get('ext', 'mp4'),
                                'resolution': fmt.get('resolution', 'N/A'),
                                'filesize': fmt.get('filesize', 0),
                                'filesize_mb': fmt.get('filesize', 0) / (1024 * 1024) if fmt.get('filesize') else 0,
                                'format_note': fmt.get('format_note', '')
                            })
                
                return result
                
        except Exception as e:
            logger.error(f"Error getting video info: {e}")
            return {'success': False, 'error': str(e)}
    
    def download_video(self, url, format_id='best'):
        """Download Instagram video"""
        try:
            # Update format if specified
            ydl_opts = self.ydl_opts.copy()
            ydl_opts['format'] = format_id
            
            logger.info(f"Downloading {url} with format {format_id}")
            
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=True)
                filename = ydl.prepare_filename(info)
                
                # Check if file exists
                if os.path.exists(filename):
                    file_size = os.path.getsize(filename)
                    file_size_mb = file_size / (1024 * 1024)
                    
                    if file_size_mb > MAX_FILE_SIZE:
                        os.remove(filename)
                        return {
                            'success': False,
                            'error': f'File too large: {file_size_mb:.1f}MB > {MAX_FILE_SIZE}MB'
                        }
                    
                    return {
                        'success': True,
                        'filename': filename,
                        'title': info.get('title', 'Instagram Video'),
                        'duration': info.get('duration', 0),
                        'file_size': file_size,
                        'file_size_mb': file_size_mb,
                        'extension': os.path.splitext(filename)[1]
                    }
                else:
                    return {'success': False, 'error': 'File not found after download'}
                    
        except Exception as e:
            logger.error(f"Download error: {e}")
            return {'success': False, 'error': str(e)}
    
    def cleanup_old_files(self):
        """Cleanup files older than 10 minutes"""
        cutoff_time = time.time() - (10 * 60)
        
        for file_path in self.download_dir.glob('*'):
            if file_path.is_file():
                file_age = time.time() - file_path.stat().st_mtime
                if file_age > (10 * 60):
                    try:
                        file_path.unlink()
                        logger.info(f"Cleaned up: {file_path.name}")
                    except Exception as e:
                        logger.error(f"Error cleaning {file_path}: {e}")

# Create downloader instance
downloader = InstagramDownloader()

# Telegram handlers
async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command"""
    welcome = """
🎬 *Instagram Video Downloader Bot*

ارسال کنید: لینک اینستاگرام
دریافت کنید: ویدیو با کیفیت بالا

✅ *پشتیبانی از:*
• رییل‌ها (reel)
• پست‌های ویدیویی
• استوری‌ها (اگر عمومی باشند)

⚡ *ویژگی‌ها:*
• دانلود مستقیم با بهترین کیفیت
• تبدیل به فرمت MP4
• ارسال در تلگرام
• پشتیبانی از لینک‌های مختلف

🔗 *مثال لینک:*
https://www.instagram.com/reel/DNThWFaopCk/
https://instagram.com/p/ABC123/
https://instagram.com/tv/XYZ456/

📌 فقط لینک اینستاگرام ارسال کنید!
"""
    await update.message.reply_text(welcome, parse_mode='Markdown')
    logger.info(f"User {update.effective_user.id} started bot")

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /help command"""
    help_text = """
📖 *راهنمای استفاده*

*نحوه کار:*
1. لینک اینستاگرام را کپی کنید
2. برای ربات ارسال کنید
3. ربات ویدیو را دانلود و ارسال می‌کند

*محدودیت‌ها:*
• حداکثر حجم: 2000 مگابایت
• فقط ویدیوهای عمومی
• ممکن است برخی پست‌ها دانلود نشوند

*اگر خطا داد:*
1. مطمئن شوید لینک درست است
2. پست عمومی باشد
3. اینترنت سرور را چک کنید
4. دوباره امتحان کنید

*تست ربات:* یک لینک اینستاگرام ارسال کنید!
"""
    await update.message.reply_text(help_text, parse_mode='Markdown')

async def handle_instagram_link(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle Instagram links"""
    user_id = update.effective_user.id
    url = update.message.text.strip()
    
    logger.info(f"User {user_id} sent: {url}")
    
    # Check if it's Instagram link
    if 'instagram.com' not in url and 'instagr.am' not in url:
        await update.message.reply_text(
            "❌ *لینک اینستاگرام نیست*\n\n"
            "لطفاً فقط لینک اینستاگرام ارسال کنید.\n"
            "مثال: https://www.instagram.com/reel/DNThWFaopCk/",
            parse_mode='Markdown'
        )
        return
    
    # Send processing message
    msg = await update.message.reply_text(
        "⏳ *در حال پردازش لینک...*\n"
        "دریافت اطلاعات ویدیو...",
        parse_mode='Markdown'
    )
    
    try:
        # Get video info first
        video_info = downloader.get_video_info(url)
        
        if not video_info.get('success'):
            await msg.edit_text(
                f"❌ *خطا در دریافت اطلاعات*\n\n"
                f"خطا: {video_info.get('error', 'Unknown error')}\n\n"
                f"مطمئن شوید لینک درست است و ویدیو عمومی باشد.",
                parse_mode='Markdown'
            )
            return
        
        # Update message
        await msg.edit_text(
            f"✅ *اطلاعات دریافت شد*\n\n"
            f"📹 عنوان: {video_info['title'][:50]}...\n"
            f"⏱️ مدت: {video_info['duration']} ثانیه\n"
            f"👤 آپلودر: {video_info['uploader'] or 'نامشخص'}\n\n"
            f"⏳ *در حال دانلود ویدیو...*",
            parse_mode='Markdown'
        )
        
        # Download video
        result = downloader.download_video(url)
        
        if not result.get('success'):
            await msg.edit_text(
                f"❌ *خطا در دانلود*\n\n"
                f"خطا: {result.get('error', 'Unknown error')}\n\n"
                f"لطفاً دوباره امتحان کنید.",
                parse_mode='Markdown'
            )
            return
        
        # Update message
        file_size = result['file_size_mb']
        await msg.edit_text(
            f"✅ *ویدیو دانلود شد*\n\n"
            f"📁 نام فایل: {os.path.basename(result['filename'])}\n"
            f"💾 حجم: {file_size:.1f} MB\n"
            f"⏱️ مدت: {result['duration']} ثانیه\n\n"
            f"📤 *در حال آپلود به تلگرام...*",
            parse_mode='Markdown'
        )
        
        # Send video
        with open(result['filename'], 'rb') as video_file:
            await update.message.reply_video(
                video=video_file,
                caption=f"📹 {result['title'][:50]}\n"
                       f"⏱️ مدت: {result['duration']} ثانیه\n"
                       f"💾 حجم: {file_size:.1f} MB\n"
                       f"🕐 زمان: {datetime.now().strftime('%H:%M:%S')}",
                supports_streaming=True,
                parse_mode='Markdown'
            )
        
        # Final message
        await msg.edit_text(
            f"🎉 *ویدیو ارسال شد!*\n\n"
            f"✅ دانلود و آپلود موفق\n"
            f"📊 حجم: {file_size:.1f} MB\n"
            f"⏱️ مدت: {result['duration']} ثانیه\n"
            f"📁 فرمت: MP4\n\n"
            f"💡 فایل به‌صورت خودکار پاک می‌شود.",
            parse_mode='Markdown'
        )
        
        logger.info(f"Successfully sent video for user {user_id}")
        
        # Schedule cleanup
        def cleanup_file():
            time.sleep(300)  # 5 minutes
            if os.path.exists(result['filename']):
                try:
                    os.remove(result['filename'])
                    logger.info(f"Cleaned up: {result['filename']}")
                except:
                    pass
        
        import threading
        threading.Thread(target=cleanup_file, daemon=True).start()
        
    except Exception as e:
        logger.error(f"Error in handle_instagram_link: {e}", exc_info=True)
        await msg.edit_text(
            f"❌ *خطای غیرمنتظره*\n\n"
            f"خطا: {str(e)[:100]}\n\n"
            f"لطفاً دوباره امتحان کنید.",
            parse_mode='Markdown'
        )

async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle errors"""
    logger.error(f"Update {update} caused error {context.error}", exc_info=True)
    
    try:
        await update.message.reply_text(
            "❌ *خطا در پردازش*\n\n"
            "یک خطای غیرمنتظره رخ داده است.\n"
            "لطفاً دوباره امتحان کنید."
        )
    except:
        pass

def main():
    """Start the bot"""
    print("=" * 60)
    print("🎬 Instagram Video Downloader Telegram Bot")
    print("=" * 60)
    print(f"Token: {TELEGRAM_TOKEN[:10]}...")
    print(f"Download dir: {DOWNLOAD_DIR}")
    print(f"Max file size: {MAX_FILE_SIZE}MB")
    print("=" * 60)
    
    # Run cleanup
    downloader.cleanup_old_files()
    
    try:
        # Create application
        application = Application.builder().token(TELEGRAM_TOKEN).build()
        
        # Add handlers
        application.add_handler(CommandHandler("start", start_command))
        application.add_handler(CommandHandler("help", help_command))
        application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_instagram_link))
        
        # Add error handler
        application.add_error_handler(error_handler)
        
        # Start bot
        print("✅ Bot is starting...")
        print("📱 Open Telegram and send /start to your bot")
        print("🔗 Send any Instagram link to download video")
        print("🛑 Press Ctrl+C to stop")
        print("=" * 60)
        
        application.run_polling(allowed_updates=Update.ALL_TYPES)
        
    except Exception as e:
        logger.error(f"Failed to start bot: {e}", exc_info=True)
        print(f"❌ Failed to start bot: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF

# Step 7: Create management script
print_info "Step 7: Creating management script..."
cat > manage.sh << 'EOF'
#!/bin/bash
# Instagram Video Bot Management Script

cd "$(dirname "$0")"

case "$1" in
    start)
        echo "🚀 Starting Instagram Video Bot..."
        source venv/bin/activate
        nohup python3 bot.py >> bot.log 2>&1 &
        echo $! > bot.pid
        echo "✅ Bot started (PID: $(cat bot.pid))"
        echo "📝 Logs: tail -f bot.log"
        ;;
    stop)
        echo "🛑 Stopping bot..."
        if [ -f "bot.pid" ]; then
            kill $(cat bot.pid) 2>/dev/null || true
            rm -f bot.pid
            echo "✅ Bot stopped"
        else
            echo "⚠️ Bot not running"
        fi
        ;;
    restart)
        echo "🔄 Restarting bot..."
        ./manage.sh stop
        sleep 2
        ./manage.sh start
        ;;
    status)
        echo "📊 Bot Status:"
        if [ -f "bot.pid" ] && ps -p $(cat bot.pid) > /dev/null 2>&1; then
            echo "✅ Bot running (PID: $(cat bot.pid))"
            echo "📝 Recent logs:"
            tail -10 bot.log
        else
            echo "❌ Bot not running"
            [ -f "bot.pid" ] && rm -f bot.pid
        fi
        ;;
    logs)
        if [ "$2" = "-f" ]; then
            tail -f bot.log
        else
            tail -50 bot.log
        fi
        ;;
    cleanup)
        echo "🧹 Cleaning downloads..."
        rm -rf downloads/*
        echo "✅ Cleaned"
        ;;
    test)
        echo "🔍 Testing..."
        source venv/bin/activate
        python3 -c "
import yt_dlp, telegram, requests
print('✅ All imports OK')
print('Testing Instagram download...')
try:
    ydl = yt_dlp.YoutubeDL({'quiet': True})
    info = ydl.extract_info('https://www.instagram.com/reel/DNThWFaopCk/', download=False)
    print(f'✅ Can access Instagram: {info.get(\"title\", \"OK\")[:50]}...')
except Exception as e:
    print(f'❌ Instagram test failed: {e}')
"
        ;;
    update)
        echo "📦 Updating bot..."
        source venv/bin/activate
        pip install --upgrade yt-dlp python-telegram-bot
        echo "✅ Updated"
        ;;
    *)
        echo "🎬 Instagram Video Bot Management"
        echo "================================"
        echo ""
        echo "Commands:"
        echo "  ./manage.sh start     # Start bot"
        echo "  ./manage.sh stop      # Stop bot"
        echo "  ./manage.sh restart   # Restart bot"
        echo "  ./manage.sh status    # Check status"
        echo "  ./manage.sh logs      # View logs"
        echo "  ./manage.sh cleanup   # Clean downloads"
        echo "  ./manage.sh test      # Test installation"
        echo "  ./manage.sh update    # Update packages"
        echo ""
        echo "Features:"
        echo "  • Download Instagram videos"
        echo "  • Convert to MP4"
        echo "  • Send in Telegram"
        echo "  • Auto cleanup"
        ;;
esac
EOF

chmod +x manage.sh bot.py

# Step 8: Create systemd service
print_info "Step 8: Creating systemd service..."
cat > /etc/systemd/system/instagram-video-bot.service << EOF
[Unit]
Description=Instagram Video Downloader Telegram Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$INSTALL_DIR/venv/bin"
ExecStart=$INSTALL_DIR/venv/bin/python3 $INSTALL_DIR/bot.py
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=instagram-video-bot

[Install]
WantedBy=multi-user.target
EOF

# Step 9: Start the bot
print_info "Step 9: Starting bot service..."
systemctl daemon-reload
systemctl enable instagram-video-bot.service
systemctl start instagram-video-bot.service

# Wait and check
sleep 3

print_info "Step 10: Checking service status..."
if systemctl is-active --quiet instagram-video-bot.service; then
    print_success "✅ Bot service is running!"
else
    print_error "❌ Service failed to start!"
    journalctl -u instagram-video-bot.service --no-pager -n 20
fi

# Final instructions
echo ""
echo "=========================================="
print_success "INSTALLATION COMPLETE!"
echo "=========================================="
echo ""
echo "📁 Directory: $INSTALL_DIR"
echo "🤖 Bot file: bot.py"
echo "⚙️ Config: config.py"
echo "📊 Logs: bot.log"
echo ""
echo "🔧 Management:"
echo "  systemctl status instagram-video-bot"
echo "  systemctl restart instagram-video-bot"
echo "  journalctl -u instagram-video-bot -f"
echo ""
echo "📱 Telegram Usage:"
echo "1. Open Telegram"
echo "2. Find your bot"
echo "3. Send /start"
echo "4. Send Instagram link like:"
echo "   https://www.instagram.com/reel/DNThWFaopCk/"
echo "5. Receive video in Telegram"
echo ""
echo "✨ Features:"
echo "  • Downloads Instagram videos"
echo "  • Converts to MP4"
echo "  • Sends directly in Telegram"
echo "  • Auto cleanup of files"
echo ""
echo "Test with your Instagram link now!"
echo "=========================================="
EOF

## دستور ذخیره در گیتهاب:

1. به این آدرس بروید: https://github.com/2amir563/khodam-down-instagram
2. روی فایل `install.sh` کلیک کنید
3. روی آیکون مداد (Edit) کلیک کنید
4. کد بالا را جایگزین کنید
5. پیام commit: `Add Instagram video downloader bot`
6. Commit changes

## دستور اجرا در سرور:

```bash
bash <(curl -s https://raw.githubusercontent.com/2amir563/khodam-down-instagram/main/install.sh)
