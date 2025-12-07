#!/bin/bash

# Telegram Instagram Downloader Bot - Simple Version
# No Callback Data Issues

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logo
show_logo() {
    clear
    echo -e "${BLUE}"
    echo "=============================================="
    echo "   SIMPLE INSTAGRAM DOWNLOADER BOT"
    echo "   NO CALLBACK DATA ISSUES"
    echo "=============================================="
    echo -e "${NC}"
}

# Print functions
print_info() { echo -e "${CYAN}[*] $1${NC}"; }
print_success() { echo -e "${GREEN}[✓] $1${NC}"; }
print_warning() { echo -e "${YELLOW}[!] $1${NC}"; }
print_error() { echo -e "${RED}[✗] $1${NC}"; }

# Install dependencies
install_deps() {
    print_info "Installing system dependencies..."
    
    if command -v apt &> /dev/null; then
        apt update -y
        apt install -y python3 python3-pip python3-venv git curl wget nano
    elif command -v yum &> /dev/null; then
        yum install -y python3 python3-pip git curl wget nano
    elif command -v dnf &> /dev/null; then
        dnf install -y python3 python3-pip git curl wget nano
    else
        print_error "Unsupported OS"
        exit 1
    fi
    
    print_success "System dependencies installed"
}

# Install Python packages
install_python_packages() {
    print_info "Installing Python packages..."
    
    pip3 install --upgrade pip
    pip3 install python-telegram-bot==20.7 yt-dlp requests
    
    print_success "Python packages installed"
}

# Create bot directory
create_bot_dir() {
    print_info "Creating bot directory..."
    
    rm -rf /opt/instagram_bot
    mkdir -p /opt/instagram_bot
    cd /opt/instagram_bot
    
    # Create necessary directories
    mkdir -p downloads logs
    
    print_success "Directory created: /opt/instagram_bot"
}

# Create SIMPLE bot.py script
create_bot_script() {
    print_info "Creating simple Instagram bot script..."
    
    cat > /opt/instagram_bot/bot.py << 'BOTEOF'
#!/usr/bin/env python3
"""
SIMPLE Instagram Downloader Bot - No Callback Data Issues
"""

import os
import json
import logging
import subprocess
import re
import asyncio
from datetime import datetime
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes, CallbackQueryHandler
from typing import Dict, List

# Setup logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO,
    handlers=[
        logging.FileHandler('/opt/instagram_bot/logs/bot.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Bot token
BOT_TOKEN = os.getenv('BOT_TOKEN', '')

# Simple session storage
user_data = {}

def is_instagram_url(url: str) -> bool:
    """Check if URL is from Instagram"""
    patterns = [
        r'instagram\.com/p/',
        r'instagram\.com/reel/',
        r'instagram\.com/tv/',
        r'instagram\.com/stories/',
    ]
    
    url_lower = url.lower()
    for pattern in patterns:
        if re.search(pattern, url_lower):
            return True
    return False

def format_size(bytes_size: int) -> str:
    """Format bytes to human readable size"""
    if bytes_size == 0:
        return "Unknown"
    
    for unit in ['B', 'KB', 'MB', 'GB']:
        if bytes_size < 1024.0:
            return f"{bytes_size:.1f} {unit}"
        bytes_size /= 1024.0
    return f"{bytes_size:.1f} TB"

async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command"""
    user = update.effective_user
    
    text = f"""
📱 *Instagram Downloader Bot*

👋 Hello {user.first_name}!

Send me an Instagram link and I'll download it for you.

🔗 *Supported:*
• Posts (instagram.com/p/...)
• Reels (instagram.com/reel/...)
• IGTV (instagram.com/tv/...)
• Stories (instagram.com/stories/...)

⚡ *How to use:*
1. Send Instagram link
2. I'll download it
3. Receive your file

✅ *Note:* Only public posts work
    """
    
    await update.message.reply_text(text, parse_mode='Markdown')

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /help command"""
    text = """
🤖 *Bot Help*

📌 *How to download:*
1. Copy Instagram link
2. Send it to me
3. I'll download it
4. You'll receive the file

⚠️ *Important:*
• Only public posts work
• Max file size: 2GB
• Videos may take time to download

🔗 *Example links:*
• https://www.instagram.com/p/ABC123/
• https://www.instagram.com/reel/XYZ456/
• https://www.instagram.com/stories/username/123456789/
    """
    
    await update.message.reply_text(text, parse_mode='Markdown')

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle incoming messages - SIMPLE VERSION"""
    user_id = update.effective_user.id
    url = update.message.text.strip()
    
    if not is_instagram_url(url):
        await update.message.reply_text("❌ Please send a valid Instagram URL")
        return
    
    # Store URL in user data (simple approach)
    user_data[user_id] = {'url': url, 'time': datetime.now().timestamp()}
    
    # Show simple options
    keyboard = [
        [
            InlineKeyboardButton("🎬 Download Video", callback_data="download_video"),
            InlineKeyboardButton("📸 Download Photo", callback_data="download_photo")
        ],
        [
            InlineKeyboardButton("🎯 Best Quality", callback_data="download_best")
        ]
    ]
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(
        "📱 Instagram link received!\n\nSelect download option:",
        reply_markup=reply_markup
    )

async def handle_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle callback queries - SUPER SIMPLE"""
    query = update.callback_query
    await query.answer()
    
    user_id = query.from_user.id
    callback_data = query.data
    
    # Get stored URL
    if user_id not in user_data:
        await query.edit_message_text("❌ Session expired. Please send the link again.")
        return
    
    url = user_data[user_id]['url']
    
    if callback_data == "download_best":
        await download_best_simple(query, context, url)
    elif callback_data == "download_video":
        await download_video_simple(query, context, url)
    elif callback_data == "download_photo":
        await download_photo_simple(query, context, url)
    else:
        await query.edit_message_text("❌ Invalid option")

async def download_best_simple(query, context, url: str):
    """Download best quality - SIMPLE"""
    user_id = query.from_user.id
    message = query.message
    
    await message.edit_text("⬇️ Downloading best quality...")
    
    try:
        # Clean URL
        if not url.startswith(('http://', 'https://')):
            url = 'https://' + url
        
        # Create download directory
        os.makedirs('/opt/instagram_bot/downloads', exist_ok=True)
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"{timestamp}_{user_id}"
        
        # Simple download command
        cmd = [
            'yt-dlp',
            '-f', 'best',
            '-o', f'/opt/instagram_bot/downloads/{filename}.%(ext)s',
            '--no-warnings',
            '--no-check-certificate',
            '--socket-timeout', '30',
            url
        ]
        
        logger.info(f"Downloading {url[:50]}...")
        
        # Run download
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        stdout, stderr = await process.communicate()
        
        if process.returncode != 0:
            error_msg = stderr.decode()[:200]
            logger.error(f"Download failed: {error_msg}")
            
            # Try alternative
            await message.edit_text("🔄 Trying alternative method...")
            
            cmd = [
                'yt-dlp',
                '-S', 'res:720',
                '-o', f'/opt/instagram_bot/downloads/{filename}.%(ext)s',
                '--no-warnings',
                url
            ]
            
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await process.communicate()
            
            if process.returncode != 0:
                await message.edit_text("❌ Download failed. The post might be private or unavailable.")
                return
        
        # Find downloaded file
        file_path = None
        for file in os.listdir('/opt/instagram_bot/downloads'):
            if file.startswith(filename):
                file_path = f'/opt/instagram_bot/downloads/{file}'
                break
        
        if not file_path or not os.path.exists(file_path):
            await message.edit_text("❌ File not found after download")
            return
        
        file_size = os.path.getsize(file_path)
        
        # Check size
        if file_size > 2000 * 1024 * 1024:
            await message.edit_text("❌ File too large for Telegram")
            os.remove(file_path)
            return
        
        # Send file
        with open(file_path, 'rb') as f:
            if file_path.endswith(('.jpg', '.jpeg', '.png', '.webp')):
                await context.bot.send_photo(
                    chat_id=user_id,
                    photo=f,
                    caption=f"✅ Downloaded ({format_size(file_size)})"
                )
            elif file_path.endswith(('.mp4', '.mkv', '.webm')):
                await context.bot.send_video(
                    chat_id=user_id,
                    video=f,
                    caption=f"✅ Downloaded ({format_size(file_size)})",
                    supports_streaming=True
                )
            else:
                await context.bot.send_document(
                    chat_id=user_id,
                    document=f,
                    caption=f"✅ Downloaded ({format_size(file_size)})"
                )
        
        # Cleanup
        try:
            os.remove(file_path)
        except:
            pass
        
        await message.edit_text(f"✅ Download complete! ({format_size(file_size)})")
        
    except Exception as e:
        logger.error(f"Download error: {str(e)}")
        await message.edit_text(f"❌ Error: {str(e)[:100]}")

async def download_video_simple(query, context, url: str):
    """Download video - SIMPLE"""
    user_id = query.from_user.id
    message = query.message
    
    await message.edit_text("🎬 Downloading video...")
    
    try:
        if not url.startswith(('http://', 'https://')):
            url = 'https://' + url
        
        os.makedirs('/opt/instagram_bot/downloads', exist_ok=True)
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"{timestamp}_{user_id}"
        
        # Try to get video
        cmd = [
            'yt-dlp',
            '-f', 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]',
            '-o', f'/opt/instagram_bot/downloads/{filename}.%(ext)s',
            '--no-warnings',
            '--merge-output-format', 'mp4',
            url
        ]
        
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        stdout, stderr = await process.communicate()
        
        if process.returncode != 0:
            # Try simpler
            cmd = [
                'yt-dlp',
                '-f', 'best[ext=mp4]',
                '-o', f'/opt/instagram_bot/downloads/{filename}.%(ext)s',
                '--no-warnings',
                url
            ]
            
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await process.communicate()
            
            if process.returncode != 0:
                await message.edit_text("❌ Could not download video")
                return
        
        # Find and send file
        file_path = f'/opt/instagram_bot/downloads/{filename}.mp4'
        if not os.path.exists(file_path):
            for file in os.listdir('/opt/instagram_bot/downloads'):
                if file.startswith(filename) and file.endswith(('.mp4', '.mkv', '.webm')):
                    file_path = f'/opt/instagram_bot/downloads/{file}'
                    break
        
        if os.path.exists(file_path):
            file_size = os.path.getsize(file_path)
            
            if file_size > 2000 * 1024 * 1024:
                await message.edit_text("❌ Video too large")
                os.remove(file_path)
                return
            
            with open(file_path, 'rb') as f:
                await context.bot.send_video(
                    chat_id=user_id,
                    video=f,
                    caption=f"✅ Video downloaded ({format_size(file_size)})",
                    supports_streaming=True
                )
            
            try:
                os.remove(file_path)
            except:
                pass
            
            await message.edit_text(f"✅ Video downloaded! ({format_size(file_size)})")
        else:
            await message.edit_text("❌ Video not found")
        
    except Exception as e:
        logger.error(f"Video error: {str(e)}")
        await message.edit_text(f"❌ Error: {str(e)[:100]}")

async def download_photo_simple(query, context, url: str):
    """Download photo - SIMPLE"""
    user_id = query.from_user.id
    message = query.message
    
    await message.edit_text("📸 Downloading photo...")
    
    try:
        if not url.startswith(('http://', 'https://')):
            url = 'https://' + url
        
        os.makedirs('/opt/instagram_bot/downloads', exist_ok=True)
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"{timestamp}_{user_id}"
        
        # Try to get photo
        cmd = [
            'yt-dlp',
            '-f', 'best[ext=jpg]/best[ext=jpeg]/best[ext=png]',
            '-o', f'/opt/instagram_bot/downloads/{filename}.%(ext)s',
            '--no-warnings',
            url
        ]
        
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        stdout, stderr = await process.communicate()
        
        if process.returncode != 0:
            await message.edit_text("❌ Could not download photo")
            return
        
        # Find and send photo
        file_path = None
        for ext in ['.jpg', '.jpeg', '.png', '.webp']:
            test_path = f'/opt/instagram_bot/downloads/{filename}{ext}'
            if os.path.exists(test_path):
                file_path = test_path
                break
        
        if file_path and os.path.exists(file_path):
            file_size = os.path.getsize(file_path)
            
            with open(file_path, 'rb') as f:
                await context.bot.send_photo(
                    chat_id=user_id,
                    photo=f,
                    caption=f"✅ Photo downloaded ({format_size(file_size)})"
                )
            
            try:
                os.remove(file_path)
            except:
                pass
            
            await message.edit_text(f"✅ Photo downloaded! ({format_size(file_size)})")
        else:
            await message.edit_text("❌ Photo not found")
        
    except Exception as e:
        logger.error(f"Photo error: {str(e)}")
        await message.edit_text(f"❌ Error: {str(e)[:100]}")

async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle errors"""
    logger.error(f"Error: {context.error}")
    
    try:
        await update.message.reply_text("⚠️ An error occurred. Please try again.")
    except:
        pass

def main():
    """Main function"""
    if not BOT_TOKEN:
        print("❌ ERROR: BOT_TOKEN not set")
        print("Please add your bot token to /opt/instagram_bot/.env")
        exit(1)
    
    # Create application
    app = Application.builder().token(BOT_TOKEN).build()
    
    # Add handlers
    app.add_handler(CommandHandler("start", start_command))
    app.add_handler(CommandHandler("help", help_command))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    app.add_handler(CallbackQueryHandler(handle_callback))
    app.add_error_handler(error_handler)
    
    print("🤖 Instagram Bot starting...")
    print(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("✅ Bot ready to receive Instagram links")
    print("⚠️ NOTE: This is a SIMPLE version without quality selection")
    
    app.run_polling()

if __name__ == '__main__':
    main()
BOTEOF
    
    chmod +x /opt/instagram_bot/bot.py
    print_success "Simple bot script created"
}

# Create environment file
create_env_file() {
    print_info "Creating environment file..."
    
    cat > /opt/instagram_bot/.env.example << ENVEOF
# Telegram Bot Token from @BotFather
# Example: 1234567890:ABCdefGhIJKlmNoPQRsTUVwxyZ
BOT_TOKEN=your_bot_token_here

# Download directory
DOWNLOAD_DIR=/opt/instagram_bot/downloads
ENVEOF
    
    print_success "Environment file created"
}

# Create service file
create_service_file() {
    print_info "Creating systemd service..."
    
    cat > /etc/systemd/system/instagram-bot.service << SERVICEEOF
[Unit]
Description=Simple Instagram Downloader Bot
After=network.target
Requires=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/instagram_bot
EnvironmentFile=/opt/instagram_bot/.env
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=PYTHONUNBUFFERED=1
ExecStart=/usr/bin/python3 /opt/instagram_bot/bot.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Security
NoNewPrivileges=true
ReadWritePaths=/opt/instagram_bot/downloads /opt/instagram_bot/logs /tmp
PrivateTmp=true

[Install]
WantedBy=multi-user.target
SERVICEEOF
    
    systemctl daemon-reload
    print_success "Service file created"
}

# Create control script
create_control_script() {
    print_info "Creating control script..."
    
    cat > /usr/local/bin/instagram-bot << CONTROLEOF
#!/bin/bash

case "\$1" in
    start)
        if [ ! -f /opt/instagram_bot/.env ]; then
            echo "❌ Please setup bot first: instagram-bot setup"
            exit 1
        fi
        
        systemctl start instagram-bot
        echo "✅ Instagram Bot started"
        echo "📋 Check status: instagram-bot status"
        echo "📊 View logs: instagram-bot logs"
        ;;
    stop)
        systemctl stop instagram-bot
        echo "🛑 Bot stopped"
        ;;
    restart)
        systemctl restart instagram-bot
        echo "🔄 Bot restarted"
        ;;
    status)
        systemctl status instagram-bot --no-pager -l
        ;;
    logs)
        if [ "\$2" = "-f" ]; then
            journalctl -u instagram-bot -f
        else
            journalctl -u instagram-bot --no-pager -n 50
        fi
        ;;
    setup)
        echo "📝 Setting up Instagram Bot..."
        
        if [ ! -f /opt/instagram_bot/.env ]; then
            cp /opt/instagram_bot/.env.example /opt/instagram_bot/.env
            echo ""
            echo "📋 Created .env file at /opt/instagram_bot/.env"
            echo ""
            echo "🔑 Follow these steps to get BOT_TOKEN:"
            echo "1. Open Telegram"
            echo "2. Search for @BotFather"
            echo "3. Send /newbot"
            echo "4. Choose bot name (e.g., Instagram Downloader)"
            echo "5. Choose username (must end with 'bot', e.g., MyInstagramDLBot)"
            echo "6. Copy the token (looks like: 1234567890:ABCdefGhIJKlmNoPQRsTUVwxyZ)"
            echo ""
            echo "✏️ Edit config file:"
            echo "   nano /opt/instagram_bot/.env"
            echo ""
            echo "📁 Or use: instagram-bot config"
        else
            echo "✅ .env file already exists"
            echo "✏️ Edit it: instagram-bot config"
        fi
        ;;
    config)
        nano /opt/instagram_bot/.env
        ;;
    update)
        echo "🔄 Updating Instagram Bot..."
        echo "Updating Python packages..."
        pip3 install --upgrade pip python-telegram-bot yt-dlp
        
        echo "Updating yt-dlp..."
        yt-dlp -U
        
        echo "Restarting bot..."
        systemctl restart instagram-bot
        
        echo "✅ Bot updated successfully"
        ;;
    test)
        echo "🧪 Testing Instagram Bot installation..."
        echo ""
        
        echo "1. Testing Python packages..."
        python3 -c "import telegram, yt_dlp; print('✅ Python packages OK')"
        
        echo ""
        echo "2. Testing yt-dlp..."
        yt-dlp --version
        
        echo ""
        echo "3. Testing service..."
        systemctl is-active instagram-bot &>/dev/null && echo "✅ Service is running" || echo "⚠️ Service is not running"
        
        echo ""
        echo "4. Testing directories..."
        ls -la /opt/instagram_bot/
        
        echo ""
        echo "✅ All tests completed"
        ;;
    clean)
        echo "🧹 Cleaning downloads..."
        rm -rf /opt/instagram_bot/downloads/*
        echo "✅ Cleaned downloads"
        ;;
    *)
        echo "🤖 Simple Instagram Downloader Bot"
        echo "Version: 1.0 | Simple & Stable"
        echo ""
        echo "Usage: \$0 {start|stop|restart|status|logs|setup|config|update|test|clean}"
        echo ""
        echo "Commands:"
        echo "  start     - Start bot"
        echo "  stop      - Stop bot"
        echo "  restart   - Restart bot"
        echo "  status    - Check status"
        echo "  logs      - View logs (add -f to follow)"
        echo "  setup     - First-time setup"
        echo "  config    - Edit configuration"
        echo "  update    - Update bot and packages"
        echo "  test      - Run tests"
        echo "  clean     - Clean downloads"
        echo ""
        echo "Quick Start:"
        echo "  1. instagram-bot setup"
        echo "  2. instagram-bot config  (add your token)"
        echo "  3. instagram-bot start"
        echo "  4. Send Instagram links to your bot"
        echo ""
        echo "Features:"
        echo "  • Simple interface"
        echo "  • No callback data issues"
        echo "  • Download posts, reels, stories"
        echo "  • Best quality auto-select"
        ;;
esac
CONTROLEOF
    
    chmod +x /usr/local/bin/instagram-bot
    print_success "Control script created"
}

# Show completion message
show_completion() {
    echo ""
    echo -e "${GREEN}=============================================="
    echo "   SIMPLE INSTAGRAM BOT INSTALLATION COMPLETE!"
    echo "=============================================="
    echo -e "${NC}"
    
    echo -e "\n${YELLOW}🚀 NEXT STEPS:${NC}"
    echo "1. ${GREEN}Setup bot:${NC}"
    echo "   instagram-bot setup"
    echo ""
    echo "2. ${GREEN}Get Bot Token from @BotFather:${NC}"
    echo "   • Open Telegram"
    echo "   • Search for @BotFather"
    echo "   • Send /newbot"
    echo "   • Choose name and username"
    echo "   • Copy token"
    echo ""
    echo "3. ${GREEN}Configure bot:${NC}"
    echo "   instagram-bot config"
    echo "   • Add your BOT_TOKEN"
    echo ""
    echo "4. ${GREEN}Start bot:${NC}"
    echo "   instagram-bot start"
    echo ""
    echo "5. ${GREEN}Monitor logs:${NC}"
    echo "   instagram-bot logs -f"
    echo ""
    
    echo -e "${YELLOW}🎯 HOW TO USE:${NC}"
    echo "1. Send Instagram link to bot"
    echo "2. Choose: Video, Photo, or Best Quality"
    echo "3. Bot downloads and sends file"
    echo ""
    
    echo -e "${GREEN}✅ Bot is ready! Start with 'instagram-bot start'${NC}"
    echo ""
    
    echo -e "${CYAN}📞 SUPPORT:${NC}"
    echo "View logs: instagram-bot logs"
    echo "Check status: instagram-bot status"
    echo "Update: instagram-bot update"
    echo "Clean: instagram-bot clean"
}

# Main installation
main() {
    show_logo
    print_info "Starting Simple Instagram Bot installation..."
    
    install_deps
    install_python_packages
    create_bot_dir
    create_bot_script
    create_env_file
    create_service_file
    create_control_script
    
    # Create log files
    touch /opt/instagram_bot/logs/bot.log
    chmod 666 /opt/instagram_bot/logs/bot.log
    
    show_completion
}

# Run installation
main "$@"
