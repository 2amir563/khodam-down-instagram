#!/bin/bash
# instagram_bot_install.sh - Install Telegram bot for Instagram with caption support
# Run: bash <(curl -s https://raw.githubusercontent.com/2amir563/khodam-down-upload-instagram-youtube-x-facebook/main/instagram_bot_install.sh)

set -e

echo "🎯 Installing Instagram Telegram Bot with Caption Support"
echo "========================================================"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_green() { echo -e "${GREEN}[✓]${NC} $1"; }
print_red() { echo -e "${RED}[✗]${NC} $1"; }
print_blue() { echo -e "${BLUE}[i]${NC} $1"; }

# Install directory
INSTALL_DIR="/opt/instagram-tg-bot"

# Step 1: Cleanup
print_blue "1. Cleaning old installations..."
pkill -f "python.*bot.py" 2>/dev/null || true
rm -rf "$INSTALL_DIR" 2>/dev/null || true
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Step 2: Install dependencies
print_blue "2. Installing system dependencies..."
apt-get update -y
apt-get install -y python3 python3-pip python3-venv git curl wget ffmpeg nano cron

# Step 3: Create virtual environment
print_blue "3. Creating virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Step 4: Install Python packages
print_blue "4. Installing Python packages..."
pip install --upgrade pip
pip install python-telegram-bot==20.7 yt-dlp==2025.11.12 requests==2.32.5

# Step 5: Create bot.py with Instagram caption support
print_blue "5. Creating bot.py with Instagram caption support..."
cat > bot.py << 'BOTPYEOF'
#!/usr/bin/env python3
"""
Telegram Instagram Download Bot with Caption Support
Features:
1. Instagram video download with caption support
2. Original format preservation for direct files
3. Auto cleanup every 2 minutes
4. Pause/Resume functionality
"""

import os
import json
import logging
import asyncio
import threading
import time
import re
from datetime import datetime, timedelta
from pathlib import Path
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, MessageHandler, CallbackQueryHandler, filters, ContextTypes
import yt_dlp
import requests

# Setup logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO,
    handlers=[
        logging.FileHandler('bot.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class InstagramDownloadBot:
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
        
        logger.info("🤖 Instagram Download Bot initialized")
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
    
    def detect_platform(self, url):
        """Detect platform from URL"""
        url_lower = url.lower()
        
        if 'instagram.com' in url_lower:
            return 'instagram'
        else:
            return 'generic'
    
    def get_instagram_caption(self, info):
        """Extract caption from Instagram video info"""
        try:
            caption = ""
            
            # Try different fields for caption
            if 'description' in info and info['description']:
                caption = info['description']
            elif 'title' in info and info['title']:
                caption = info['title']
            elif 'fulltitle' in info and info['fulltitle']:
                caption = info['fulltitle']
            
            # Clean up the caption
            if caption:
                # Remove URLs
                caption = re.sub(r'http\S+', '', caption)
                # Remove extra whitespace
                caption = ' '.join(caption.split())
                # Truncate if too long
                if len(caption) > 1000:
                    caption = caption[:1000] + "..."
            
            return caption
            
        except Exception as e:
            logger.error(f"Error extracting Instagram caption: {e}")
            return ""
    
    async def start_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Handle /start command"""
        user = update.effective_user
        
        if self.is_paused and self.paused_until and datetime.now() < self.paused_until:
            remaining = self.paused_until - datetime.now()
            hours = remaining.seconds // 3600
            minutes = (remaining.seconds % 3600) // 60
            await update.message.reply_text(
                f"⏸️ Bot is paused\nWill resume in: {hours}h {minutes}m"
            )
            return
        
        welcome = f"""
Hello {user.first_name}! 👋

🤖 **Instagram Download Bot with Caption Support**

📥 **Supported Platforms:**
✅ Instagram (downloads video with caption/description)
✅ Direct files (keeps original format)

🎯 **How to use:**
1. Send Instagram link → Downloads video with caption
2. Send direct file → Keeps original format

⚡ **Features:**
• Instagram caption download (text below video)
• Auto cleanup every 2 minutes
• Pause/Resume bot
• Preserves file formats

🛠️ **Commands:**
/start - This menu
/help - Detailed help
/status - Bot status (admin)
/pause [hours] - Pause bot (admin)
/resume - Resume bot (admin)
/clean - Clean files (admin)

💡 **Files auto deleted after 2 minutes**
"""
        
        await update.message.reply_text(welcome, parse_mode='Markdown')
        logger.info(f"User {user.id} started bot")
    
    async def handle_message(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Handle text messages"""
        if self.is_paused and self.paused_until and datetime.now() < self.paused_until:
            remaining = self.paused_until - datetime.now()
            hours = remaining.seconds // 3600
            minutes = (remaining.seconds % 3600) // 60
            await update.message.reply_text(
                f"⏸️ Bot is paused\nWill resume in: {hours}h {minutes}m"
            )
            return
        
        text = update.message.text
        user = update.effective_user
        
        logger.info(f"Message from {user.first_name}: {text[:50]}")
        
        if text.startswith(('http://', 'https://')):
            platform = self.detect_platform(text)
            
            if platform == 'instagram':
                await update.message.reply_text("📥 Downloading Instagram video with caption...")
                await self.process_url(update, text, platform)
            else:
                await update.message.reply_text("📥 Downloading...")
                await self.process_url(update, text, platform)
        
        else:
            await update.message.reply_text(
                "Please send a valid URL starting with http:// or https://\n\n"
                "🌟 **Instagram:** Downloads video with caption/description"
            )
    
    async def process_url(self, update: Update, url, platform):
        """Process URL or direct file"""
        try:
            await update.message.reply_text("📥 Processing...")
            
            # Special handling for Instagram to get caption
            if platform == 'instagram':
                await self.download_instagram_with_caption(update, url)
                return
            
            # For direct files, use direct download
            await self.download_direct_file(update, url)
                    
        except Exception as e:
            logger.error(f"Process URL error: {e}")
            # Fallback to direct download
            await self.download_direct_file(update, url)
    
    async def download_instagram_with_caption(self, update: Update, url):
        """Download Instagram video with caption"""
        try:
            ydl_opts = {
                'format': 'best',
                'quiet': True,
                'outtmpl': str(self.download_dir / '%(title)s.%(ext)s'),
                'no_warnings': True,
            }
            
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                # First get info to extract caption
                info = ydl.extract_info(url, download=False)
                caption = self.get_instagram_caption(info)
                
                # Download
                ydl.download([url])
                filename = ydl.prepare_filename(info)
                
                if os.path.exists(filename):
                    file_size = os.path.getsize(filename) / (1024 * 1024)
                    max_size = self.config['telegram']['max_file_size']
                    
                    if file_size > max_size:
                        os.remove(filename)
                        await update.message.reply_text(f"❌ File too large: {file_size:.1f}MB")
                        return
                    
                    # Prepare caption
                    final_caption = "📷 Instagram Video\n\n"
                    if caption:
                        final_caption += f"{caption}\n\n"
                    final_caption += f"Size: {file_size:.1f}MB"
                    
                    # Send video
                    with open(filename, 'rb') as f:
                        await update.message.reply_video(
                            video=f,
                            caption=final_caption[:1024],
                            supports_streaming=True
                        )
                    
                    await update.message.reply_text(f"✅ Instagram download complete!")
                    
                    # Schedule deletion
                    self.schedule_file_deletion(filename)
                else:
                    await update.message.reply_text("❌ File not found after download")
                    
        except Exception as e:
            logger.error(f"Instagram download error: {e}")
            await update.message.reply_text(f"❌ Instagram error: {str(e)[:100]}")
    
    async def download_direct_file(self, update: Update, url):
        """Download direct file preserving format"""
        try:
            # Get filename
            filename = os.path.basename(url.split('?')[0])
            if not filename:
                filename = f"file_{int(time.time())}"
            
            filepath = self.download_dir / filename
            
            # Download
            await update.message.reply_text("📥 Downloading...")
            response = requests.get(url, stream=True, timeout=60)
            response.raise_for_status()
            
            total_size = int(response.headers.get('content-length', 0))
            
            with open(filepath, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
            
            file_size = os.path.getsize(filepath) / (1024 * 1024)
            max_size = self.config['telegram']['max_file_size']
            
            if file_size > max_size:
                os.remove(filepath)
                await update.message.reply_text(f"❌ File too large: {file_size:.1f}MB")
                return
            
            # Send with correct method
            await self.send_file_with_caption(update, str(filepath), "", "direct")
            
            # Schedule deletion
            self.schedule_file_deletion(str(filepath))
            
        except Exception as e:
            logger.error(f"Direct download error: {e}")
            await update.message.reply_text(f"❌ Download error: {str(e)[:100]}")
    
    async def send_file_with_caption(self, update: Update, filepath, caption, platform):
        """Send file with appropriate method and caption"""
        try:
            file_size = os.path.getsize(filepath) / (1024 * 1024)
            filename = os.path.basename(filepath)
            
            with open(filepath, 'rb') as f:
                # Prepare base caption
                base_caption = ""
                if platform == 'instagram' and caption:
                    base_caption = f"📷 Instagram Video\n\n{caption}\n\n"
                elif caption:
                    base_caption = f"{caption}\n\n"
                
                final_caption = f"{base_caption}Size: {file_size:.1f}MB"
                
                # Determine file type and send
                if filepath.endswith(('.mp3', '.m4a', '.wav', '.ogg', '.opus')):
                    await update.message.reply_audio(
                        audio=f,
                        caption=final_caption[:1024],
                        title=filename[:50]
                    )
                elif filepath.endswith(('.mp4', '.avi', '.mkv', '.mov', '.webm')):
                    await update.message.reply_video(
                        video=f,
                        caption=final_caption[:1024],
                        supports_streaming=True
                    )
                elif filepath.endswith(('.jpg', '.jpeg', '.png', '.gif', '.bmp')):
                    await update.message.reply_photo(
                        photo=f,
                        caption=final_caption[:1024]
                    )
                else:
                    await update.message.reply_document(
                        document=f,
                        caption=final_caption[:1024]
                    )
            
            await update.message.reply_text(f"✅ Download complete! ({file_size:.1f}MB)")
            
        except Exception as e:
            logger.error(f"Send file error: {e}")
            # Fallback to simple document
            with open(filepath, 'rb') as f:
                await update.message.reply_document(
                    document=f,
                    caption=f"📄 {filename}\nSize: {file_size:.1f}MB"
                )
    
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
    
    # Other commands...
    async def help_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        await update.message.reply_text(
            "📖 **Help**\n\n"
            "Send Instagram link → Downloads video with caption\n"
            "Send other links → Auto download\n"
            "Files auto deleted after 2 minutes",
            parse_mode='Markdown'
        )
    
    async def status_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        user = update.effective_user
        if user.id not in self.admin_ids:
            await update.message.reply_text("⛔ Admin only!")
            return
        
        files = list(self.download_dir.glob('*'))
        total_size = sum(f.stat().st_size for f in files if f.is_file()) / (1024 * 1024)
        
        await update.message.reply_text(
            f"📊 **Status**\n\n"
            f"✅ Bot active\n"
            f"📁 Files: {len(files)}\n"
            f"💾 Size: {total_size:.1f}MB\n"
            f"👤 Your ID: {user.id}",
            parse_mode='Markdown'
        )
    
    async def pause_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        user = update.effective_user
        if user.id not in self.admin_ids:
            await update.message.reply_text("⛔ Admin only!")
            return
        
        hours = 1
        if context.args:
            try:
                hours = int(context.args[0])
            except:
                hours = 1
        
        self.is_paused = True
        self.paused_until = datetime.now() + timedelta(hours=hours)
        
        await update.message.reply_text(
            f"⏸️ Bot paused for {hours} hour(s)\n"
            f"Resume at: {self.paused_until.strftime('%H:%M')}"
        )
    
    async def resume_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        user = update.effective_user
        if user.id not in self.admin_ids:
            await update.message.reply_text("⛔ Admin only!")
            return
        
        self.is_paused = False
        self.paused_until = None
        await update.message.reply_text("▶️ Bot resumed!")
    
    async def clean_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        user = update.effective_user
        if user.id not in self.admin_ids:
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
        print("🤖 Instagram Download Bot")
        print("🎯 Caption download enabled")
        print("=" * 50)
        
        if not self.token or self.token == 'YOUR_BOT_TOKEN_HERE':
            print("❌ ERROR: Configure token in config.json")
            return
        
        print(f"✅ Token: {self.token[:15]}...")
        
        app = Application.builder().token(self.token).build()
        
        app.add_handler(CommandHandler("start", self.start_command))
        app.add_handler(CommandHandler("help", self.help_command))
        app.add_handler(CommandHandler("status", self.status_command))
        app.add_handler(CommandHandler("pause", self.pause_command))
        app.add_handler(CommandHandler("resume", self.resume_command))
        app.add_handler(CommandHandler("clean", self.clean_command))
        app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, self.handle_message))
        
        print("✅ Bot ready!")
        print("📱 Send Instagram link to test caption download")
        print("=" * 50)
        
        app.run_polling()

def main():
    try:
        bot = InstagramDownloadBot()
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

# Step 6: Create config.json
print_blue "6. Creating config.json..."
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

# Step 7: Create management script
print_blue "7. Creating management script..."
cat > manage.sh << 'MANAGEEOF'
#!/bin/bash
# manage.sh - Instagram bot management

cd "$(dirname "$0")"

case "$1" in
    start)
        echo "🚀 Starting Instagram Bot..."
        source venv/bin/activate
        > bot.log
        nohup python bot.py >> bot.log 2>&1 &
        echo $! > bot.pid
        echo "✅ Bot started (PID: $(cat bot.pid))"
        echo "📝 Logs: tail -f bot.log"
        echo ""
        echo "🎯 Features:"
        echo "   • Instagram video download with caption"
        echo "   • Preserves original file formats"
        echo "   • Auto cleanup every 2 minutes"
        ;;
    stop)
        echo "🛑 Stopping bot..."
        if [ -f "bot.pid" ]; then
            kill $(cat bot.pid) 2>/dev/null
            rm -f bot.pid
            echo "✅ Bot stopped"
        else
            echo "⚠️ Bot not running"
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
        if [ -f "bot.pid" ] && ps -p $(cat bot.pid) > /dev/null 2>&1; then
            echo "✅ Bot running (PID: $(cat bot.pid))"
            echo "📝 Recent logs:"
            tail -5 bot.log 2>/dev/null || echo "No logs"
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
            echo "No log file"
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
    import telegram, yt_dlp, requests
    print('✅ All imports OK')
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
    if token == 'YOUR_BOT_TOKEN_HERE':
        print('❌ Token not configured!')
    else:
        print(f'✅ Token: {token[:15]}...')
        print(f'✅ Max size: {config[\"telegram\"][\"max_file_size\"]}MB')
except Exception as e:
    print(f'❌ Config error: {e}')
"
        ;;
    debug)
        echo "🐛 Debug mode..."
        ./manage.sh stop
        source venv/bin/activate
        python bot.py
        ;;
    clean)
        echo "🧹 Cleaning..."
        rm -rf downloads/*
        echo "✅ Files cleaned"
        ;;
    uninstall)
        echo "🗑️ Uninstalling..."
        echo ""
        read -p "Are you sure? Type 'YES': " confirm
        if [ "$confirm" = "YES" ]; then
            ./manage.sh stop
            cd /
            rm -rf "$INSTALL_DIR"
            echo "✅ Bot uninstalled"
        else
            echo "❌ Cancelled"
        fi
        ;;
    autostart)
        echo "⚙️ Setting auto-start..."
        (crontab -l 2>/dev/null | grep -v "$INSTALL_DIR"; 
         echo "@reboot cd $INSTALL_DIR && ./manage.sh start") | crontab -
        echo "✅ Auto-start configured"
        ;;
    *)
        echo "🤖 Instagram Download Bot Management"
        echo "==================================="
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
        echo "  ./manage.sh uninstall  # Uninstall bot"
        echo "  ./manage.sh autostart  # Auto-start on reboot"
        echo ""
        echo "🎯 Features:"
        echo "  • Instagram video download with caption"
        echo "  • Preserves original formats"
        echo "  • Auto cleanup (2 minutes)"
        echo "  • Pause/Resume functionality"
        ;;
esac
MANAGEEOF

chmod +x manage.sh

# Step 8: Create requirements.txt
print_blue "8. Creating requirements.txt..."
cat > requirements.txt << 'REQEOF'
python-telegram-bot==20.7
yt-dlp==2025.11.12
requests==2.32.5
REQEOF

print_green "✅ INSTAGRAM BOT WITH CAPTION SUPPORT INSTALLED!"
echo ""
echo "📋 SETUP STEPS:"
echo "================"
echo "1. Configure bot:"
echo "   cd $INSTALL_DIR"
echo "   nano config.json"
echo "   • Replace YOUR_BOT_TOKEN_HERE with your token"
echo "   • Add your Telegram ID to admin_ids"
echo ""
echo "2. Start bot:"
echo "   ./manage.sh start"
echo ""
echo "3. Test:"
echo "   ./manage.sh test"
echo "   ./manage.sh status"
echo ""
echo "4. In Telegram:"
echo "   • Find your bot"
echo "   • Send /start"
echo "   • Send Instagram link → Downloads video with caption"
echo ""
echo "🌟 FEATURE: Instagram caption download"
echo "   When you send an Instagram video link,"
echo "   the bot will download the video and include"
echo "   the caption/description in the Telegram message!"
echo ""
echo "🔧 Troubleshooting:"
echo "   ./manage.sh logs     # Check errors"
echo "   ./manage.sh debug    # Run in foreground"
echo ""
echo "🚀 Install command for others:"
echo "bash <(curl -s https://raw.githubusercontent.com/2amir563/khodam-down-upload-instagram-youtube-x-facebook/main/instagram_bot_install.sh)"
