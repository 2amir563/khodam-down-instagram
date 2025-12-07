#!/bin/bash
# Complete Instagram Bot Installation Script
# Run: bash <(curl -s https://raw.githubusercontent.com/2amir563/khodam-down-instagram/main/install.sh)

set -e

echo "🚀 Complete Instagram Bot Installation"
echo "======================================"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_green() { echo -e "${GREEN}[✓]${NC} $1"; }
print_red() { echo -e "${RED}[✗]${NC} $1"; }
print_blue() { echo -e "${BLUE}[i]${NC} $1"; }

# Install directory
INSTALL_DIR="/opt/instagram-bot"

# Step 0: Stop any running bot
print_blue "0. Stopping any running bot..."
pkill -f "python.*instagram_bot.py" 2>/dev/null || true
rm -rf "$INSTALL_DIR" 2>/dev/null || true

# Step 1: Update system
print_blue "1. Updating system packages..."
apt-get update -y
apt-get upgrade -y

# Step 2: Install system dependencies
print_blue "2. Installing system dependencies..."
apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    git \
    curl \
    wget \
    ffmpeg \
    nano \
    cron \
    build-essential \
    libssl-dev \
    libffi-dev \
    libjpeg-dev \
    libpng-dev \
    zlib1g-dev

# Step 3: Create directory
print_blue "3. Creating installation directory..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Step 4: Create virtual environment
print_blue "4. Creating virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Step 5: Upgrade pip and setuptools
print_blue "5. Upgrading pip and setuptools..."
pip install --upgrade pip setuptools wheel

# Step 6: Install Python packages
print_blue "6. Installing Python packages..."
pip install --no-cache-dir \
    Pillow==10.3.0 \
    python-telegram-bot==20.7 \
    instagrapi==1.18.1 \
    yt-dlp==2025.11.12 \
    requests==2.32.5 \
    beautifulsoup4==4.12.3 \
    lxml==5.2.1

# Step 7: Create instagram_bot.py
print_blue "7. Creating bot.py with error handling..."
cat > bot.py << 'BOTPYEOF'
#!/usr/bin/env python3
"""
Instagram Download Bot for Telegram
Simple version without complex Instagram login
"""

import os
import json
import logging
import asyncio
import threading
import time
from datetime import datetime, timedelta
from pathlib import Path
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes
import yt_dlp
import requests
import re

# Setup logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO,
    handlers=[
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class SimpleInstagramBot:
    def __init__(self):
        self.config = self.load_config()
        self.token = self.config['telegram']['token']
        self.admin_ids = self.config['telegram'].get('admin_ids', [])
        
        # Bot state
        self.is_paused = False
        self.paused_until = None
        
        # Create directories
        self.download_dir = Path(self.config.get('download_dir', 'downloads'))
        self.download_dir.mkdir(exist_ok=True)
        
        # Start auto cleanup
        self.start_auto_cleanup()
        
        logger.info("🤖 Simple Instagram Bot initialized")
        print(f"✅ Token: {self.token[:15]}...")
    
    def load_config(self):
        """Load configuration"""
        config_file = 'config.json'
        if os.path.exists(config_file):
            with open(config_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        
        # Default config
        config = {
            'telegram': {
                'token': 'YOUR_BOT_TOKEN_HERE',
                'admin_ids': [],
                'max_file_size': 2000
            },
            'download_dir': 'downloads',
            'auto_cleanup_minutes': 2
        }
        
        with open(config_file, 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=4, ensure_ascii=False)
        
        return config
    
    def start_auto_cleanup(self):
        """Start auto cleanup thread"""
        def cleanup_worker():
            while True:
                try:
                    self.cleanup_old_files()
                    time.sleep(60)
                except Exception as e:
                    logger.error(f"Cleanup error: {e}")
                    time.sleep(60)
        
        thread = threading.Thread(target=cleanup_worker, daemon=True)
        thread.start()
        logger.info("🧹 Auto cleanup started")
    
    def cleanup_old_files(self):
        """Cleanup files older than 2 minutes"""
        cutoff_time = time.time() - (2 * 60)
        files_deleted = 0
        
        for file_path in self.download_dir.glob('*'):
            if file_path.is_file():
                file_age = time.time() - file_path.stat().st_mtime
                if file_age > (2 * 60):
                    try:
                        file_path.unlink()
                        files_deleted += 1
                    except Exception as e:
                        logger.error(f"Error deleting {file_path}: {e}")
        
        if files_deleted > 0:
            logger.info(f"Cleaned {files_deleted} old files")
    
    def extract_instagram_links(self, html_content):
        """Extract Instagram media links from HTML"""
        patterns = [
            r'"display_url":"(https://[^"]+)"',
            r'"video_url":"(https://[^"]+)"',
            r'src="(https://[^"]+instagram[^"]+)"',
            r'property="og:image" content="(https://[^"]+)"',
            r'property="og:video" content="(https://[^"]+)"'
        ]
        
        links = []
        for pattern in patterns:
            matches = re.findall(pattern, html_content)
            links.extend(matches)
        
        # Filter unique links
        unique_links = []
        seen = set()
        for link in links:
            if link not in seen:
                seen.add(link)
                unique_links.append(link)
        
        return unique_links
    
    async def download_instagram(self, url):
        """Download Instagram content using yt-dlp"""
        try:
            ydl_opts = {
                'format': 'best',
                'quiet': True,
                'no_warnings': True,
                'extract_flat': False,
                'outtmpl': str(self.download_dir / '%(title).100s.%(ext)s'),
                'cookiefile': 'cookies.txt' if os.path.exists('cookies.txt') else None,
            }
            
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=True)
                
                # Get downloaded files
                files = []
                if 'entries' in info:  # Playlist/album
                    for entry in info['entries']:
                        if entry:
                            filename = ydl.prepare_filename(entry)
                            if os.path.exists(filename):
                                files.append(filename)
                else:  # Single media
                    filename = ydl.prepare_filename(info)
                    if os.path.exists(filename):
                        files.append(filename)
                
                return files, info.get('title', 'Instagram Media')
                
        except Exception as e:
            logger.error(f"Download error: {e}")
            return None, str(e)
    
    async def download_with_requests(self, url):
        """Fallback download method"""
        try:
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
            
            response = requests.get(url, headers=headers, timeout=30, stream=True)
            response.raise_for_status()
            
            # Get filename
            if 'content-disposition' in response.headers:
                content_disposition = response.headers['content-disposition']
                filename = re.findall('filename="?([^"]+)"?', content_disposition)
                if filename:
                    filename = filename[0]
                else:
                    filename = f"instagram_{int(time.time())}.mp4"
            else:
                filename = f"instagram_{int(time.time())}.mp4"
            
            # Clean filename
            filename = re.sub(r'[^\w\-_. ]', '_', filename)
            if len(filename) > 100:
                filename = filename[:100]
            
            filepath = self.download_dir / filename
            
            # Download
            with open(filepath, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
            
            return [str(filepath)], "Instagram Media"
            
        except Exception as e:
            logger.error(f"Requests download error: {e}")
            return None, str(e)
    
    async def start_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Handle /start command"""
        user = update.effective_user
        
        welcome = f"""
Hello {user.first_name}! 👋

🤖 **Simple Instagram Download Bot**

📥 **Supported Content:**
✅ Instagram Posts
✅ Instagram Reels
✅ Instagram Videos
✅ Instagram Photos
✅ Other platforms via yt-dlp

🎯 **How to use:**
1. Send any Instagram link
2. Bot will download the media
3. Receive it in Telegram

⚡ **Features:**
• Simple and fast
• No Instagram login required for public content
• Auto cleanup every 2 minutes
• Supports multiple file types

🛠️ **Commands:**
/start - This menu
/help - Help guide
/status - Bot status (admin)
/clean - Clean all files (admin)

💡 **Files auto deleted after 2 minutes**
"""
        
        await update.message.reply_text(welcome, parse_mode='Markdown')
        logger.info(f"User {user.id} started bot")
    
    async def handle_message(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Handle text messages"""
        text = update.message.text
        user = update.effective_user
        
        logger.info(f"Message from {user.first_name}: {text[:50]}")
        
        if text.startswith(('http://', 'https://')):
            if 'instagram.com' in text.lower():
                await update.message.reply_text("📥 Downloading Instagram content...")
                
                # Try yt-dlp first
                files, title = await self.download_instagram(text)
                
                if not files:
                    # Fallback to requests method
                    await update.message.reply_text("🔄 Trying alternative method...")
                    files, title = await self.download_with_requests(text)
                
                if files:
                    await update.message.reply_text(f"✅ Downloaded {len(files)} file(s)\n📤 Uploading...")
                    
                    for filepath in files:
                        try:
                            file_size = os.path.getsize(filepath) / (1024 * 1024)
                            max_size = self.config['telegram']['max_file_size']
                            
                            if file_size > max_size:
                                await update.message.reply_text(f"❌ File too large: {file_size:.1f}MB")
                                os.remove(filepath)
                                continue
                            
                            with open(filepath, 'rb') as f:
                                if filepath.endswith(('.mp4', '.avi', '.mkv', '.mov', '.webm')):
                                    await update.message.reply_video(
                                        video=f,
                                        caption=f"📹 {title[:50]}\nSize: {file_size:.1f}MB",
                                        supports_streaming=True
                                    )
                                elif filepath.endswith(('.jpg', '.jpeg', '.png', '.gif', '.webp')):
                                    await update.message.reply_photo(
                                        photo=f,
                                        caption=f"🖼️ {title[:50]}\nSize: {file_size:.1f}MB"
                                    )
                                else:
                                    await update.message.reply_document(
                                        document=f,
                                        caption=f"📄 {title[:50]}\nSize: {file_size:.1f}MB"
                                    )
                            
                            # Schedule deletion
                            self.schedule_file_deletion(filepath)
                            
                        except Exception as e:
                            logger.error(f"Error sending file: {e}")
                            await update.message.reply_text(f"❌ Error sending file: {str(e)[:100]}")
                    
                    await update.message.reply_text(f"✅ All files sent successfully!")
                    
                else:
                    await update.message.reply_text(f"❌ Download failed. Error: {title}")
            
            else:
                # Other URLs
                await update.message.reply_text("📥 Downloading with yt-dlp...")
                files, title = await self.download_instagram(text)
                
                if files:
                    for filepath in files:
                        await self.send_file(update, filepath, title)
                else:
                    await update.message.reply_text(f"❌ Download failed: {title}")
        
        else:
            await update.message.reply_text(
                "Please send a valid URL starting with http:// or https://\n\n"
                "📸 **Instagram Examples:**\n"
                "• https://instagram.com/p/...\n"
                "• https://instagram.com/reel/...\n"
                "• https://instagram.com/tv/..."
            )
    
    async def send_file(self, update: Update, filepath, title):
        """Send file with appropriate method"""
        try:
            file_size = os.path.getsize(filepath) / (1024 * 1024)
            max_size = self.config['telegram']['max_file_size']
            
            if file_size > max_size:
                await update.message.reply_text(f"❌ File too large: {file_size:.1f}MB")
                os.remove(filepath)
                return
            
            with open(filepath, 'rb') as f:
                if filepath.endswith(('.mp4', '.avi', '.mkv', '.mov', '.webm')):
                    await update.message.reply_video(
                        video=f,
                        caption=f"📹 {title[:100]}\nSize: {file_size:.1f}MB",
                        supports_streaming=True
                    )
                elif filepath.endswith(('.mp3', '.m4a', '.wav', '.ogg')):
                    await update.message.reply_audio(
                        audio=f,
                        caption=f"🎵 {title[:100]}\nSize: {file_size:.1f}MB"
                    )
                elif filepath.endswith(('.jpg', '.jpeg', '.png', '.gif')):
                    await update.message.reply_photo(
                        photo=f,
                        caption=f"🖼️ {title[:100]}\nSize: {file_size:.1f}MB"
                    )
                else:
                    await update.message.reply_document(
                        document=f,
                        caption=f"📄 {title[:100]}\nSize: {file_size:.1f}MB"
                    )
            
            await update.message.reply_text(f"✅ Download complete! ({file_size:.1f}MB)")
            
            # Schedule deletion
            self.schedule_file_deletion(filepath)
            
        except Exception as e:
            logger.error(f"Send file error: {e}")
            await update.message.reply_text(f"❌ Error: {str(e)[:100]}")
    
    def schedule_file_deletion(self, filepath):
        """Schedule file deletion after 2 minutes"""
        def delete_later():
            time.sleep(120)
            if os.path.exists(filepath):
                try:
                    os.remove(filepath)
                    logger.info(f"Auto deleted: {os.path.basename(filepath)}")
                except:
                    pass
        
        threading.Thread(target=delete_later, daemon=True).start()
    
    async def help_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        await update.message.reply_text(
            "📖 **Help Guide**\n\n"
            "Send any Instagram link to download:\n"
            "• Posts, Reels, Videos, Photos\n\n"
            "Other platforms also supported via yt-dlp\n\n"
            "Files auto deleted after 2 minutes",
            parse_mode='Markdown'
        )
    
    async def status_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        user = update.effective_user
        if user.id not in self.admin_ids and self.admin_ids:
            await update.message.reply_text("⛔ Admin only!")
            return
        
        files = list(self.download_dir.glob('*'))
        total_size = sum(f.stat().st_size for f in files if f.is_file()) / (1024 * 1024)
        
        status = f"""
📊 **Bot Status**

✅ Bot is running
📁 Files in cache: {len(files)}
💾 Cache size: {total_size:.1f}MB
👤 Your ID: {user.id}
"""
        
        await update.message.reply_text(status, parse_mode='Markdown')
    
    async def clean_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        user = update.effective_user
        if user.id not in self.admin_ids and self.admin_ids:
            await update.message.reply_text("⛔ Admin only!")
            return
        
        files = list(self.download_dir.glob('*'))
        count = len(files)
        
        for f in files:
            try:
                f.unlink()
            except:
                pass
        
        await update.message.reply_text(f"🧹 Cleaned {count} files")
    
    def run(self):
        """Run the bot"""
        print("=" * 50)
        print("🤖 Simple Instagram Download Bot")
        print("=" * 50)
        
        if not self.token or self.token == 'YOUR_BOT_TOKEN_HERE':
            print("❌ ERROR: Configure token in config.json")
            print("Edit config.json and set your Telegram bot token")
            return
        
        print(f"✅ Token: {self.token[:15]}...")
        print("✅ Bot ready!")
        print("📱 Send Instagram link to download")
        print("=" * 50)
        
        app = Application.builder().token(self.token).build()
        
        app.add_handler(CommandHandler("start", self.start_command))
        app.add_handler(CommandHandler("help", self.help_command))
        app.add_handler(CommandHandler("status", self.status_command))
        app.add_handler(CommandHandler("clean", self.clean_command))
        app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, self.handle_message))
        
        app.run_polling()

def main():
    try:
        bot = SimpleInstagramBot()
        bot.run()
    except KeyboardInterrupt:
        print("\n🛑 Bot stopped")
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    main()
BOTPYEOF

# Step 8: Create config.json
print_blue "8. Creating config.json..."
cat > config.json << 'CONFIGEOF'
{
    "telegram": {
        "token": "YOUR_BOT_TOKEN_HERE",
        "admin_ids": [],
        "max_file_size": 2000
    },
    "download_dir": "downloads",
    "auto_cleanup_minutes": 2
}
CONFIGEOF

# Step 9: Create management script
print_blue "9. Creating management script..."
cat > manage.sh << 'MANAGEEOF'
#!/bin/bash
# manage.sh - Instagram bot management

cd "$(dirname "$0")"

case "$1" in
    start)
        echo "🚀 Starting Instagram Bot..."
        source venv/bin/activate
        > bot.log 2>/dev/null
        nohup python bot.py >> bot.log 2>&1 &
        echo $! > bot.pid 2>/dev/null
        echo "✅ Bot started (PID: $(cat bot.pid 2>/dev/null))"
        echo "📝 Logs: tail -f bot.log"
        echo ""
        echo "📸 Bot Features:"
        echo "   • Download Instagram posts, reels, videos"
        echo "   • Simple and fast"
        echo "   • No Instagram login required"
        echo "   • Auto cleanup every 2 minutes"
        ;;
    stop)
        echo "🛑 Stopping bot..."
        if [ -f "bot.pid" ]; then
            kill $(cat bot.pid) 2>/dev/null
            rm -f bot.pid
            echo "✅ Bot stopped"
        else
            echo "⚠️ Bot not running or already stopped"
        fi
        ;;
    restart)
        echo "🔄 Restarting..."
        ./manage.sh stop
        sleep 2
        ./manage.sh start
        ;;
    status)
        echo "📊 Bot Status:"
        if [ -f "bot.pid" ] && ps -p $(cat bot.pid 2>/dev/null) > /dev/null 2>&1; then
            echo "✅ Bot running (PID: $(cat bot.pid))"
            echo "📝 Recent logs:"
            tail -5 bot.log 2>/dev/null || echo "No logs yet"
        else
            echo "❌ Bot not running"
            [ -f "bot.pid" ] && rm -f bot.pid
        fi
        ;;
    logs)
        echo "📝 Bot logs:"
        if [ -f "bot.log" ]; then
            if [ "$2" = "-f" ]; then
                tail -f bot.log
            else
                tail -50 bot.log
            fi
        else
            echo "No log file found"
        fi
        ;;
    config)
        echo "⚙️ Editing config..."
        nano config.json
        echo "💡 Restart after editing: ./manage.sh restart"
        ;;
    test)
        echo "🔍 Testing..."
        source venv/bin/activate
        
        echo "1. Testing imports..."
        python3 -c "
try:
    import telegram, yt_dlp, requests, json, re, asyncio
    print('✅ All imports OK')
    print('✅ Python-telegram-bot: OK')
    print('✅ yt-dlp: OK')
    print('✅ Requests: OK')
except Exception as e:
    print(f'❌ Import error: {e}')
"
        
        echo ""
        echo "2. Testing config..."
        python3 -c "
import json
try:
    with open('config.json') as f:
        config = json.load(f)
    
    token = config['telegram']['token']
    max_size = config['telegram']['max_file_size']
    
    if token == 'YOUR_BOT_TOKEN_HERE':
        print('❌ Telegram token not configured!')
        print('   Edit config.json and add your bot token')
    else:
        print(f'✅ Token: {token[:15]}...')
    
    print(f'✅ Max file size: {max_size}MB')
    print('✅ Config test passed')
except Exception as e:
    print(f'❌ Config error: {e}')
"
        
        echo ""
        echo "3. Testing virtual environment..."
        if [ -f "venv/bin/activate" ]; then
            echo "✅ Virtual environment exists"
        else
            echo "❌ Virtual environment not found"
        fi
        ;;
    debug)
        echo "🐛 Debug mode..."
        ./manage.sh stop
        sleep 1
        source venv/bin/activate
        python bot.py
        ;;
    clean)
        echo "🧹 Cleaning..."
        rm -rf downloads/* 2>/dev/null
        echo "✅ Files cleaned"
        ;;
    uninstall)
        echo "🗑️ Uninstalling..."
        echo ""
        read -p "Are you sure? This will remove everything. Type 'YES': " confirm
        if [ "$confirm" = "YES" ]; then
            ./manage.sh stop
            cd /
            rm -rf "$INSTALL_DIR"
            echo "✅ Bot uninstalled"
        else
            echo "❌ Cancelled"
        fi
        ;;
    update)
        echo "🔄 Updating..."
        ./manage.sh stop
        cd "$INSTALL_DIR"
        source venv/bin/activate
        pip install --upgrade yt-dlp python-telegram-bot requests
        echo "✅ Packages updated"
        ./manage.sh start
        ;;
    *)
        echo "🤖 Simple Instagram Bot Management"
        echo "=================================="
        echo ""
        echo "📁 Directory: $INSTALL_DIR"
        echo ""
        echo "📋 Commands:"
        echo "  ./manage.sh start      # Start bot"
        echo "  ./manage.sh stop       # Stop bot"
        echo "  ./manage.sh restart    # Restart bot"
        echo "  ./manage.sh status     # Check status"
        echo "  ./manage.sh logs       # View logs"
        echo "  ./manage.sh config     # Edit config"
        echo "  ./manage.sh test       # Test everything"
        echo "  ./manage.sh debug      # Debug mode"
        echo "  ./manage.sh clean      # Clean files"
        echo "  ./manage.sh update     # Update packages"
        echo "  ./manage.sh uninstall  # Uninstall bot"
        echo ""
        echo "📸 Features:"
        echo "  • Simple Instagram download"
        echo "  • No login required"
        echo "  • Fast and reliable"
        echo "  • Auto cleanup every 2 minutes"
        ;;
esac
MANAGEEOF

chmod +x manage.sh

# Step 10: Create requirements.txt
print_blue "10. Creating requirements.txt..."
cat > requirements.txt << 'REQEOF'
python-telegram-bot==20.7
yt-dlp==2025.11.12
requests==2.32.5
Pillow==10.3.0
REQEOF

# Step 11: Create README
print_blue "11. Creating README..."
cat > README.md << 'READMEEOF'
# Simple Instagram Download Bot

A simple Telegram bot for downloading Instagram content.

## Features
- Download Instagram posts, reels, videos, photos
- No Instagram login required for public content
- Auto cleanup every 2 minutes
- Simple and fast

## Installation
1. Clone or download this repository
2. Configure `config.json` with your bot token
3. Run `./manage.sh start`

## Configuration
Edit `config.json`:
```json
{
    "telegram": {
        "token": "YOUR_BOT_TOKEN_HERE",
        "admin_ids": [123456789],
        "max_file_size": 2000
    }
}
