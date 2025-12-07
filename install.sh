#!/bin/bash
# instagram_install.sh - Install Instagram bot with quality selection
# Run: bash <(curl -s https://raw.githubusercontent.com/2amir563/khodam-down-upload-instagram-youtube-x-facebook/main/instagram_install.sh)

set -e

echo "📸 Installing Instagram Bot"
echo "==========================="

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

# Step 1: Cleanup
print_blue "1. Cleaning old installations..."
pkill -f "python.*instagram_bot.py" 2>/dev/null || true
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
pip install python-telegram-bot==20.7 yt-dlp==2025.11.12 requests==2.32.5 instagrapi==1.18.1

# Step 5: Create instagram_bot.py
print_blue "5. Creating instagram_bot.py..."
cat > instagram_bot.py << 'BOTPYEOF'
#!/usr/bin/env python3
"""
Instagram Download Bot for Telegram
Features:
1. Download Instagram posts (photos, videos, reels, IGTV)
2. Quality selection for videos
3. Album (carousel) download support
4. Stories download support
5. Auto cleanup every 2 minutes
"""

import os
import json
import logging
import asyncio
import threading
import time
from datetime import datetime, timedelta
from pathlib import Path
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, MessageHandler, CallbackQueryHandler, filters, ContextTypes
from instagrapi import Client
from instagrapi.exceptions import LoginRequired, ClientError
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
        
        # Instagram client
        self.cl = None
        self.is_logged_in = False
        
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
            'instagram': {
                'username': 'YOUR_INSTAGRAM_USERNAME',
                'password': 'YOUR_INSTAGRAM_PASSWORD',
                'session_file': 'session.json'
            },
            'download_dir': 'downloads',
            'auto_cleanup_minutes': 2
        }
        
        with open(config_file, 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=4, ensure_ascii=False)
        
        return config
    
    def login_instagram(self):
        """Login to Instagram"""
        try:
            self.cl = Client()
            
            # Try to load session
            session_file = self.config['instagram']['session_file']
            if os.path.exists(session_file):
                self.cl.load_settings(session_file)
            
            # Login
            username = self.config['instagram']['username']
            password = self.config['instagram']['password']
            
            if username == 'YOUR_INSTAGRAM_USERNAME' or password == 'YOUR_INSTAGRAM_PASSWORD':
                logger.warning("Instagram credentials not configured")
                return False
            
            self.cl.login(username, password)
            
            # Save session
            self.cl.dump_settings(session_file)
            
            self.is_logged_in = True
            logger.info(f"✅ Logged in to Instagram as {username}")
            return True
            
        except Exception as e:
            logger.error(f"Instagram login error: {e}")
            self.is_logged_in = False
            return False
    
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
    
    def extract_instagram_info(self, url):
        """Extract information from Instagram URL"""
        try:
            if not self.is_logged_in:
                if not self.login_instagram():
                    return None
            
            if '/p/' in url or '/reel/' in url or '/tv/' in url:
                # Post, Reel, or IGTV
                media_pk = self.cl.media_pk_from_url(url)
                media_info = self.cl.media_info(media_pk)
                
                return {
                    'type': media_info.media_type,
                    'pk': media_info.pk,
                    'code': media_info.code,
                    'caption': media_info.caption_text if media_info.caption_text else "No caption",
                    'username': media_info.user.username,
                    'thumbnail_url': media_info.thumbnail_url,
                    'resources': []
                }
                
            elif '/stories/' in url:
                # Story
                username = url.split('/stories/')[1].split('/')[0]
                user_id = self.cl.user_id_from_username(username)
                stories = self.cl.user_stories(user_id)
                
                if stories:
                    return {
                        'type': 'story',
                        'username': username,
                        'stories': stories,
                        'count': len(stories)
                    }
            
        except Exception as e:
            logger.error(f"Error extracting info: {e}")
        
        return None
    
    def download_instagram_media(self, url, quality='best'):
        """Download Instagram media"""
        try:
            info = self.extract_instagram_info(url)
            if not info:
                return None
            
            downloads = []
            
            if info['type'] == 1:  # Photo
                # Single photo
                media_pk = info['pk']
                media_info = self.cl.media_info(media_pk)
                
                photo_url = media_info.thumbnail_url or media_info.resources[0].thumbnail_url
                filename = f"{info['username']}_{info['code']}.jpg"
                filepath = self.download_dir / filename
                
                self.download_file(photo_url, filepath)
                downloads.append({
                    'type': 'photo',
                    'path': str(filepath),
                    'caption': info['caption'][:1000]
                })
                
            elif info['type'] == 2:  # Video
                # Video
                media_pk = info['pk']
                media_info = self.cl.media_info(media_pk)
                
                video_url = media_info.video_url
                filename = f"{info['username']}_{info['code']}.mp4"
                filepath = self.download_dir / filename
                
                self.download_file(video_url, filepath)
                downloads.append({
                    'type': 'video',
                    'path': str(filepath),
                    'caption': info['caption'][:1000]
                })
                
            elif info['type'] == 8:  # Album
                # Carousel (multiple media)
                media_pk = info['pk']
                media_info = self.cl.media_info(media_pk)
                
                for idx, resource in enumerate(media_info.resources):
                    if resource.media_type == 1:  # Photo
                        media_url = resource.thumbnail_url
                        ext = 'jpg'
                    else:  # Video
                        media_url = resource.video_url
                        ext = 'mp4'
                    
                    filename = f"{info['username']}_{info['code']}_{idx+1}.{ext}"
                    filepath = self.download_dir / filename
                    
                    self.download_file(media_url, filepath)
                    downloads.append({
                        'type': 'photo' if resource.media_type == 1 else 'video',
                        'path': str(filepath),
                        'caption': info['caption'][:1000] if idx == 0 else None
                    })
            
            elif info['type'] == 'story':
                # Stories
                for idx, story in enumerate(info['stories'][:10]):  # Max 10 stories
                    if story.media_type == 1:  # Photo story
                        media_url = story.thumbnail_url
                        ext = 'jpg'
                    else:  # Video story
                        media_url = story.video_url
                        ext = 'mp4'
                    
                    filename = f"story_{info['username']}_{idx+1}.{ext}"
                    filepath = self.download_dir / filename
                    
                    self.download_file(media_url, filepath)
                    downloads.append({
                        'type': 'photo' if story.media_type == 1 else 'video',
                        'path': str(filepath),
                        'caption': f"Story {idx+1}/{len(info['stories'])}"
                    })
            
            return downloads
            
        except Exception as e:
            logger.error(f"Download error: {e}")
            return None
    
    def download_file(self, url, filepath):
        """Download file from URL"""
        response = requests.get(url, stream=True, timeout=60)
        response.raise_for_status()
        
        with open(filepath, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
    
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

🤖 **Instagram Download Bot**

📥 **Supported Instagram Content:**
✅ Photos (single posts)
✅ Videos (posts, reels)
✅ Albums (carousel posts)
✅ Stories
✅ Reels
✅ IGTV

🎯 **How to use:**
1. Send Instagram post link
2. Bot will download all media
3. Receive files in Telegram

⚡ **Features:**
• High quality downloads
• Album support (multiple files)
• Story download support
• Auto cleanup every 2 minutes
• Caption preservation

🛠️ **Commands:**
/start - This menu
/help - Detailed help
/status - Bot status (admin)
/pause [hours] - Pause bot (admin)
/resume - Resume bot (admin)
/clean - Clean files (admin)

💡 **Files auto deleted after 2 minutes**

⚠️ **Note:** Instagram login required for some content
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
        
        if text.startswith(('http://', 'https://')) and 'instagram.com' in text.lower():
            await update.message.reply_text("🔍 Processing Instagram link...")
            
            # Check Instagram login
            if not self.is_logged_in:
                login_msg = await update.message.reply_text("🔐 Logging into Instagram...")
                if not self.login_instagram():
                    await login_msg.edit_text("❌ Instagram login failed! Check credentials in config.json")
                    return
                await login_msg.edit_text("✅ Logged in successfully!")
            
            # Download media
            status_msg = await update.message.reply_text("📥 Downloading from Instagram...")
            
            try:
                downloads = self.download_instagram_media(text)
                
                if not downloads:
                    await status_msg.edit_text("❌ Failed to download. Possible issues:\n• Private account\n• Login required\n• Invalid link")
                    return
                
                await status_msg.edit_text(f"✅ Downloaded {len(downloads)} item(s)\n📤 Uploading...")
                
                # Send files
                for idx, download in enumerate(downloads):
                    try:
                        file_size = os.path.getsize(download['path']) / (1024 * 1024)
                        max_size = self.config['telegram']['max_file_size']
                        
                        if file_size > max_size:
                            await update.message.reply_text(f"❌ File too large: {file_size:.1f}MB")
                            os.remove(download['path'])
                            continue
                        
                        with open(download['path'], 'rb') as f:
                            if download['type'] == 'photo':
                                await update.message.reply_photo(
                                    photo=f,
                                    caption=download['caption'] if download['caption'] else None
                                )
                            else:  # video
                                await update.message.reply_video(
                                    video=f,
                                    caption=download['caption'] if download['caption'] else None,
                                    supports_streaming=True
                                )
                        
                        # Schedule deletion
                        self.schedule_file_deletion(download['path'])
                        
                    except Exception as e:
                        logger.error(f"Error sending file {idx}: {e}")
                        await update.message.reply_text(f"❌ Error sending file {idx+1}")
                
                await status_msg.edit_text(f"✅ Download complete! Sent {len(downloads)} file(s)")
                
            except Exception as e:
                logger.error(f"Error: {e}")
                await status_msg.edit_text(f"❌ Error: {str(e)[:100]}")
        
        elif text.startswith(('http://', 'https://')):
            # Other URLs
            await update.message.reply_text("📥 Downloading with yt-dlp...")
            await self.download_other_url(update, text)
        
        else:
            await update.message.reply_text(
                "Please send a valid Instagram URL or other media link\n\n"
                "📸 **Instagram Examples:**\n"
                "• https://instagram.com/p/... (post)\n"
                "• https://instagram.com/reel/... (reel)\n"
                "• https://instagram.com/stories/... (story)\n"
                "• https://instagram.com/tv/... (IGTV)"
            )
    
    async def download_other_url(self, update: Update, url):
        """Download other URLs using yt-dlp"""
        try:
            ydl_opts = {
                'format': 'best',
                'quiet': True,
                'outtmpl': str(self.download_dir / '%(title).100s.%(ext)s'),
            }
            
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=True)
                filename = ydl.prepare_filename(info)
                
                if os.path.exists(filename):
                    file_size = os.path.getsize(filename) / (1024 * 1024)
                    max_size = self.config['telegram']['max_file_size']
                    
                    if file_size > max_size:
                        os.remove(filename)
                        await update.message.reply_text(f"❌ File too large: {file_size:.1f}MB")
                        return
                    
                    with open(filename, 'rb') as f:
                        if filename.endswith(('.mp4', '.avi', '.mkv', '.mov')):
                            await update.message.reply_video(
                                video=f,
                                caption=f"📹 {info.get('title', 'Video')[:100]}\nSize: {file_size:.1f}MB",
                                supports_streaming=True
                            )
                        elif filename.endswith(('.mp3', '.m4a')):
                            await update.message.reply_audio(
                                audio=f,
                                caption=f"🎵 {info.get('title', 'Audio')[:100]}\nSize: {file_size:.1f}MB"
                            )
                        else:
                            await update.message.reply_document(
                                document=f,
                                caption=f"📄 {info.get('title', 'File')[:100]}\nSize: {file_size:.1f}MB"
                            )
                    
                    await update.message.reply_text(f"✅ Download complete! ({file_size:.1f}MB)")
                    
                    # Schedule deletion
                    self.schedule_file_deletion(filename)
                    
        except Exception as e:
            logger.error(f"Download error: {e}")
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
    
    # Admin commands
    async def status_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        user = update.effective_user
        if user.id not in self.admin_ids:
            await update.message.reply_text("⛔ Admin only!")
            return
        
        files = list(self.download_dir.glob('*'))
        total_size = sum(f.stat().st_size for f in files if f.is_file()) / (1024 * 1024)
        
        status = f"""
📊 **Bot Status**

✅ Instagram: {'Logged in' if self.is_logged_in else 'Not logged in'}
📁 Files: {len(files)}
💾 Size: {total_size:.1f}MB
⏸️ Paused: {self.is_paused}
👤 Your ID: {user.id}
"""
        
        await update.message.reply_text(status, parse_mode='Markdown')
    
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
    
    async def login_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Login to Instagram manually"""
        user = update.effective_user
        if user.id not in self.admin_ids:
            await update.message.reply_text("⛔ Admin only!")
            return
        
        msg = await update.message.reply_text("🔐 Logging into Instagram...")
        
        if self.login_instagram():
            await msg.edit_text("✅ Successfully logged into Instagram!")
        else:
            await msg.edit_text("❌ Login failed! Check credentials in config.json")
    
    def run(self):
        """Run the bot"""
        print("=" * 50)
        print("🤖 Instagram Download Bot")
        print("=" * 50)
        
        if not self.token or self.token == 'YOUR_BOT_TOKEN_HERE':
            print("❌ ERROR: Configure token in config.json")
            return
        
        print(f"✅ Token: {self.token[:15]}...")
        
        # Try Instagram login
        print("🔐 Attempting Instagram login...")
        if self.login_instagram():
            print("✅ Instagram login successful")
        else:
            print("⚠️ Instagram login failed or not configured")
            print("   Edit config.json to add Instagram credentials")
        
        app = Application.builder().token(self.token).build()
        
        app.add_handler(CommandHandler("start", self.start_command))
        app.add_handler(CommandHandler("status", self.status_command))
        app.add_handler(CommandHandler("pause", self.pause_command))
        app.add_handler(CommandHandler("resume", self.resume_command))
        app.add_handler(CommandHandler("clean", self.clean_command))
        app.add_handler(CommandHandler("login", self.login_command))
        app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, self.handle_message))
        
        print("✅ Bot ready!")
        print("📱 Send Instagram link to download")
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
    "instagram": {
        "username": "YOUR_INSTAGRAM_USERNAME",
        "password": "YOUR_INSTAGRAM_PASSWORD",
        "session_file": "session.json"
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
        nohup python instagram_bot.py >> bot.log 2>&1 &
        echo $! > bot.pid
        echo "✅ Bot started (PID: $(cat bot.pid))"
        echo "📝 Logs: tail -f bot.log"
        echo ""
        echo "📸 Instagram Bot Features:"
        echo "   • Download Instagram posts, reels, stories"
        echo "   • Album (carousel) support"
        echo "   • High quality downloads"
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
    import telegram, instagrapi, yt_dlp, requests
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
    ig_user = config['instagram']['username']
    ig_pass = config['instagram']['password']
    
    if token == 'YOUR_BOT_TOKEN_HERE':
        print('❌ Telegram token not configured!')
    else:
        print(f'✅ Token: {token[:15]}...')
    
    if ig_user == 'YOUR_INSTAGRAM_USERNAME':
        print('⚠️ Instagram username not configured')
    else:
        print(f'✅ IG Username: {ig_user}')
    
    print(f'✅ Max size: {config[\"telegram\"][\"max_file_size\"]}MB')
except Exception as e:
    print(f'❌ Config error: {e}')
"
        ;;
    debug)
        echo "🐛 Debug mode..."
        ./manage.sh stop
        source venv/bin/activate
        python instagram_bot.py
        ;;
    clean)
        echo "🧹 Cleaning..."
        rm -rf downloads/*
        rm -f session.json 2>/dev/null
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
        echo "📸 Instagram Features:"
        echo "  • Download posts, reels, stories"
        echo "  • Album/carousel support"
        echo "  • High quality downloads"
        echo "  • Auto cleanup (2 minutes)"
        echo "  • Instagram login support"
        ;;
esac
MANAGEEOF

chmod +x manage.sh

# Step 8: Create requirements.txt
print_blue "8. Creating requirements.txt..."
cat > requirements.txt << 'REQEOF'
python-telegram-bot==20.7
instagrapi==1.18.1
yt-dlp==2025.11.12
requests==2.32.5
REQEOF

print_green "✅ INSTAGRAM BOT INSTALLATION COMPLETE!"
echo ""
echo "📋 SETUP STEPS:"
echo "================"
echo "1. Configure bot:"
echo "   cd $INSTALL_DIR"
echo "   nano config.json"
echo "   • Replace YOUR_BOT_TOKEN_HERE with Telegram bot token"
echo "   • Add your Telegram ID to admin_ids"
echo "   • Add Instagram username/password (optional but recommended)"
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
echo "   • Send Instagram link → Download content"
echo "   • Send other links → Download with yt-dlp"
echo ""
echo "⚠️ IMPORTANT:"
echo "   • Instagram login needed for private accounts/stories"
echo "   • Files auto-deleted after 2 minutes"
echo "   • Use 2FA Instagram account may need app password"
echo ""
echo "🔧 Troubleshooting:"
echo "   ./manage.sh logs     # Check errors"
echo "   ./manage.sh debug    # Run in foreground"
echo "   ./manage.sh login    # Manual Instagram login (admin)"
echo ""
echo "🚀 Install command for others:"
echo "bash <(curl -s https://raw.githubusercontent.com/2amir563/khodam-down-upload-instagram-youtube-x-facebook/main/instagram_install.sh)"
