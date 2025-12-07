#!/bin/bash

# Instagram Downloader Bot with Instagram API Support
# Fixed Authentication Issue

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
    echo "   INSTAGRAM DOWNLOADER BOT - WORKING VERSION"
    echo "   WITH INSTAGRAM API SUPPORT"
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
        apt install -y python3 python3-pip python3-venv git curl wget nano chromium-chromedriver
    elif command -v yum &> /dev/null; then
        yum install -y python3 python3-pip git curl wget nano chromedriver
    elif command -v dnf &> /dev/null; then
        dnf install -y python3 python3-pip git curl wget nano chromedriver
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
    pip3 install python-telegram-bot==20.7 yt-dlp requests beautifulsoup4 instaloader
    
    print_success "Python packages installed"
}

# Create bot directory
create_bot_dir() {
    print_info "Creating bot directory..."
    
    rm -rf /opt/instagram_bot
    mkdir -p /opt/instagram_bot
    cd /opt/instagram_bot
    
    # Create necessary directories
    mkdir -p downloads logs cookies
    
    print_success "Directory created: /opt/instagram_bot"
}

# Create WORKING bot.py script
create_bot_script() {
    print_info "Creating working Instagram bot script..."
    
    cat > /opt/instagram_bot/bot.py << 'BOTEOF'
#!/usr/bin/env python3
"""
Instagram Downloader Bot - Working Version with Multiple Methods
"""

import os
import re
import logging
import subprocess
import asyncio
from datetime import datetime
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes, CallbackQueryHandler
from typing import Dict
import requests
import json

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

# User session storage
user_sessions = {}

def is_instagram_url(url: str) -> bool:
    """Check if URL is from Instagram"""
    patterns = [
        r'instagram\.com/p/',
        r'instagram\.com/reel/',
        r'instagram\.com/tv/',
        r'instagram\.com/stories/',
        r'instagram\.com/tv/',
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

def extract_shortcode(url: str) -> str:
    """Extract shortcode from Instagram URL"""
    patterns = [
        r'instagram\.com/p/([^/?]+)',
        r'instagram\.com/reel/([^/?]+)',
        r'instagram\.com/tv/([^/?]+)',
    ]
    
    for pattern in patterns:
        match = re.search(pattern, url.lower())
        if match:
            return match.group(1)
    return ""

def download_instagram_media(url: str, output_path: str) -> bool:
    """Download Instagram media using multiple methods"""
    
    methods = [
        # Method 1: yt-dlp with cookies
        lambda: download_with_ytdlp(url, output_path),
        # Method 2: Instagram API
        lambda: download_with_api(url, output_path),
        # Method 3: Direct download
        lambda: download_direct(url, output_path),
    ]
    
    for i, method in enumerate(methods, 1):
        logger.info(f"Trying method {i} for {url}")
        try:
            if method():
                logger.info(f"Method {i} succeeded")
                return True
        except Exception as e:
            logger.error(f"Method {i} failed: {e}")
    
    return False

def download_with_ytdlp(url: str, output_path: str) -> bool:
    """Download using yt-dlp"""
    try:
        cmd = [
            'yt-dlp',
            '-f', 'best',
            '-o', output_path,
            '--no-warnings',
            '--no-check-certificate',
            '--cookies-from-browser', 'chrome',
            url
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        
        if result.returncode == 0:
            # Check if file was created
            output_pattern = output_path.replace('%(ext)s', '*')
            import glob
            files = glob.glob(output_pattern)
            return len(files) > 0
        
        return False
    except:
        return False

def download_with_api(url: str, output_path: str) -> bool:
    """Download using Instagram API (public endpoints)"""
    try:
        # Extract shortcode
        shortcode = extract_shortcode(url)
        if not shortcode:
            return False
        
        # Try to get from public API
        api_url = f"https://www.instagram.com/p/{shortcode}/?__a=1&__d=dis"
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }
        
        response = requests.get(api_url, headers=headers, timeout=30)
        
        if response.status_code == 200:
            data = response.json()
            
            # Extract media URLs from response
            media_urls = []
            
            # Try different response formats
            try:
                # Format 1
                if 'graphql' in data:
                    media = data['graphql']['shortcode_media']
                    if media['is_video']:
                        media_urls.append(media['video_url'])
                    else:
                        if 'display_url' in media:
                            media_urls.append(media['display_url'])
                        # Check for carousel
                        if 'edge_sidecar_to_children' in media:
                            for edge in media['edge_sidecar_to_children']['edges']:
                                node = edge['node']
                                if node['is_video']:
                                    media_urls.append(node['video_url'])
                                else:
                                    media_urls.append(node['display_url'])
                
                # Format 2
                elif 'items' in data:
                    for item in data['items']:
                        if 'video_versions' in item:
                            media_urls.append(item['video_versions'][0]['url'])
                        elif 'image_versions2' in item:
                            media_urls.append(item['image_versions2']['candidates'][0]['url'])
            except:
                pass
            
            # Download first media
            if media_urls:
                media_url = media_urls[0]
                response = requests.get(media_url, headers=headers, timeout=30)
                if response.status_code == 200:
                    # Determine file extension
                    if 'video' in media_url or '.mp4' in media_url:
                        ext = 'mp4'
                    else:
                        ext = 'jpg'
                    
                    actual_path = output_path.replace('%(ext)s', ext)
                    with open(actual_path, 'wb') as f:
                        f.write(response.content)
                    return True
        
        return False
    except Exception as e:
        logger.error(f"API download error: {e}")
        return False

def download_direct(url: str, output_path: str) -> bool:
    """Try direct download methods"""
    try:
        # Method 1: Use savefrom.net API
        savefrom_url = f"https://api.savefrom.net/v1/source/instagram"
        payload = {
            'url': url
        }
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
        
        response = requests.post(savefrom_url, data=payload, headers=headers, timeout=30)
        
        if response.status_code == 200:
            data = response.json()
            if 'url' in data:
                media_url = data['url']
                response = requests.get(media_url, headers=headers, timeout=30)
                if response.status_code == 200:
                    # Determine extension
                    content_type = response.headers.get('content-type', '')
                    if 'video' in content_type or 'mp4' in media_url:
                        ext = 'mp4'
                    else:
                        ext = 'jpg'
                    
                    actual_path = output_path.replace('%(ext)s', ext)
                    with open(actual_path, 'wb') as f:
                        f.write(response.content)
                    return True
        
        # Method 2: Use instagram-scraper
        try:
            cmd = [
                'python3', '-c', """
import requests
import re
import sys

url = sys.argv[1]
headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
}

try:
    response = requests.get(url, headers=headers)
    html = response.text
    
    # Find video URL
    video_match = re.search(r'"video_url":"([^"]+)"', html)
    if video_match:
        print(video_match.group(1))
        sys.exit(0)
    
    # Find image URL
    image_match = re.search(r'"display_url":"([^"]+)"', html)
    if image_match:
        print(image_match.group(1))
        sys.exit(0)
    
    sys.exit(1)
except:
    sys.exit(1)
                """,
                url
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            if result.returncode == 0:
                media_url = result.stdout.strip()
                response = requests.get(media_url, headers=headers, timeout=30)
                if response.status_code == 200:
                    ext = 'mp4' if 'video' in media_url else 'jpg'
                    actual_path = output_path.replace('%(ext)s', ext)
                    with open(actual_path, 'wb') as f:
                        f.write(response.content)
                    return True
        except:
            pass
        
        return False
    except Exception as e:
        logger.error(f"Direct download error: {e}")
        return False

async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command"""
    user = update.effective_user
    
    text = f"""
📱 *Instagram Downloader Bot*

👋 Hello {user.first_name}!

I can download content from Instagram.

✅ *Supported content:*
• Posts (Photos & Videos)
• Reels (Short videos)
• IGTV (Long videos)

⚠️ *Important:*
• Posts must be PUBLIC
• Stories not supported
• Private accounts won't work

🔗 *How to use:*
1. Send me an Instagram link
2. I'll download it for you
3. Receive your file

*Example links:*
• https://www.instagram.com/p/ABC123/
• https://www.instagram.com/reel/XYZ456/
    """
    
    await update.message.reply_text(text, parse_mode='Markdown')

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /help command"""
    text = """
🤖 *Bot Help Guide*

📌 *How to download:*
1. Copy Instagram link
2. Send it to this bot
3. Wait for download
4. Receive the file

🎯 *Tips for success:*
• Use PUBLIC Instagram posts only
• Reels work best
• Videos may take longer
• Large files might fail

🔧 *Troubleshooting:*
If download fails:
1. Check if post is public
2. Try a different post
3. Wait and try again
4. Contact support

📞 *Support:*
For help, check logs or contact administrator.
    """
    
    await update.message.reply_text(text, parse_mode='Markdown')

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle incoming Instagram links"""
    user_id = update.effective_user.id
    url = update.message.text.strip()
    
    # Clean URL
    if not url.startswith(('http://', 'https://')):
        url = 'https://' + url
    
    # Validate URL
    if not is_instagram_url(url):
        await update.message.reply_text("❌ Please send a valid Instagram URL\n\nExample: https://www.instagram.com/p/ABC123/")
        return
    
    # Store in session
    user_sessions[user_id] = url
    
    # Show options
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
        f"📱 *Instagram Link Received*\n\n`{url[:50]}...`\n\nSelect download option:",
        parse_mode='Markdown',
        reply_markup=reply_markup
    )

async def handle_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle callback queries"""
    query = update.callback_query
    await query.answer()
    
    user_id = query.from_user.id
    callback_data = query.data
    
    # Get URL from session
    if user_id not in user_sessions:
        await query.edit_message_text("❌ Session expired. Please send the link again.")
        return
    
    url = user_sessions[user_id]
    
    if callback_data == "download_best":
        await download_content(query, context, url, "best")
    elif callback_data == "download_video":
        await download_content(query, context, url, "video")
    elif callback_data == "download_photo":
        await download_content(query, context, url, "photo")
    else:
        await query.edit_message_text("❌ Invalid option")

async def download_content(query, context, url: str, quality: str):
    """Download Instagram content"""
    user_id = query.from_user.id
    message = query.message
    
    await message.edit_text("🔍 Processing Instagram link...")
    
    try:
        # Create download directory
        os.makedirs('/opt/instagram_bot/downloads', exist_ok=True)
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"{timestamp}_{user_id}"
        output_path = f"/opt/instagram_bot/downloads/{filename}.%(ext)s"
        
        # Show downloading message
        await message.edit_text("⬇️ Downloading from Instagram...\n\nThis may take a moment.")
        
        # Download using multiple methods
        success = download_instagram_media(url, output_path)
        
        if not success:
            await message.edit_text("❌ Failed to download. Possible reasons:\n\n1. Post is private\n2. Instagram blocked the request\n3. Try a different post\n4. The link might be invalid")
            return
        
        # Find downloaded file
        downloaded_files = []
        for ext in ['mp4', 'jpg', 'jpeg', 'png', 'webm', 'mkv']:
            file_path = f"/opt/instagram_bot/downloads/{filename}.{ext}"
            if os.path.exists(file_path):
                downloaded_files.append(file_path)
        
        if not downloaded_files:
            await message.edit_text("❌ File downloaded but not found")
            return
        
        file_path = downloaded_files[0]
        file_size = os.path.getsize(file_path)
        
        # Check file size
        if file_size > 2000 * 1024 * 1024:
            await message.edit_text("❌ File too large for Telegram (max 2GB)")
            os.remove(file_path)
            return
        
        # Send file
        await message.edit_text(f"📤 Sending file ({format_size(file_size)})...")
        
        with open(file_path, 'rb') as f:
            if file_path.endswith(('.mp4', '.webm', '.mkv')):
                await context.bot.send_video(
                    chat_id=user_id,
                    video=f,
                    caption=f"✅ Instagram Video Downloaded\n📦 Size: {format_size(file_size)}",
                    supports_streaming=True
                )
            elif file_path.endswith(('.jpg', '.jpeg', '.png', '.webp')):
                await context.bot.send_photo(
                    chat_id=user_id,
                    photo=f,
                    caption=f"✅ Instagram Photo Downloaded\n📦 Size: {format_size(file_size)}"
                )
            else:
                await context.bot.send_document(
                    chat_id=user_id,
                    document=f,
                    caption=f"✅ Instagram Media Downloaded\n📦 Size: {format_size(file_size)}"
                )
        
        # Cleanup
        try:
            os.remove(file_path)
        except:
            pass
        
        await message.edit_text(f"✅ Download complete!\n📦 File size: {format_size(file_size)}")
        
    except Exception as e:
        logger.error(f"Download error: {str(e)}")
        await message.edit_text(f"❌ Error: {str(e)[:150]}\n\nTry again or use a different link.")

async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle errors"""
    logger.error(f"Error: {context.error}")
    
    try:
        await update.message.reply_text("⚠️ An error occurred. Please try again with a different link.")
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
    print("⚠️ NOTE: Only PUBLIC Instagram posts work")
    
    app.run_polling()

if __name__ == '__main__':
    main()
BOTEOF
    
    chmod +x /opt/instagram_bot/bot.py
    print_success "Working bot script created"
}

# Create cookies directory and sample
create_cookies() {
    print_info "Setting up cookies directory..."
    
    # Create sample cookies file
    cat > /opt/instagram_bot/README_COOKIES.md << 'COOKIEEOF'
# Instagram Cookies Setup

For better Instagram download success, you can add cookies:

## Method 1: Export from Browser
1. Install "Get cookies.txt" extension in Chrome/Firefox
2. Login to Instagram in browser
3. Export cookies as `cookies.txt`
4. Place in `/opt/instagram_bot/cookies/` directory

## Method 2: Manual Setup (Optional)
The bot will work without cookies, but success rate may be lower.

## Method 3: Use API Method
The bot uses multiple fallback methods if cookies aren't available.
COOKIEEOF
    
    print_success "Cookies setup created"
}

# Create environment file
create_env_file() {
    print_info "Creating environment file..."
    
    cat > /opt/instagram_bot/.env.example << ENVEOF
# Telegram Bot Token from @BotFather
# Example: 1234567890:ABCdefGhIJKlmNoPQRsTUVwxyZ
BOT_TOKEN=your_bot_token_here

# Instagram credentials (optional, for better results)
# INSTAGRAM_USERNAME=your_username
# INSTAGRAM_PASSWORD=your_password

# Download directory
DOWNLOAD_DIR=/opt/instagram_bot/downloads

# Cookies directory
COOKIES_DIR=/opt/instagram_bot/cookies
ENVEOF
    
    print_success "Environment file created"
}

# Create service file
create_service_file() {
    print_info "Creating systemd service..."
    
    cat > /etc/systemd/system/instagram-bot.service << SERVICEEOF
[Unit]
Description=Instagram Downloader Bot with Multiple Methods
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
ReadWritePaths=/opt/instagram_bot/downloads /opt/instagram_bot/logs /opt/instagram_bot/cookies /tmp
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
        pip3 install --upgrade pip python-telegram-bot yt-dlp requests
        
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
        python3 -c "import telegram, yt_dlp, requests, json; print('✅ Python packages OK')"
        
        echo ""
        echo "2. Testing yt-dlp..."
        yt-dlp --version
        
        echo ""
        echo "3. Testing requests..."
        python3 -c "import requests; print(f'✅ Requests version: {requests.__version__}')"
        
        echo ""
        echo "4. Testing service..."
        systemctl is-active instagram-bot &>/dev/null && echo "✅ Service is running" || echo "⚠️ Service is not running"
        
        echo ""
        echo "5. Testing internet connection..."
        curl -s --connect-timeout 5 https://www.instagram.com > /dev/null && echo "✅ Instagram accessible" || echo "⚠️ Cannot access Instagram"
        
        echo ""
        echo "✅ All tests completed"
        ;;
    clean)
        echo "🧹 Cleaning downloads..."
        rm -rf /opt/instagram_bot/downloads/*
        echo "✅ Cleaned downloads"
        ;;
    cookies)
        echo "🍪 Cookies Information:"
        echo ""
        echo "For better Instagram download results, you can add cookies:"
        echo "1. Install 'Get cookies.txt' browser extension"
        echo "2. Login to Instagram in browser"
        echo "3. Export cookies as cookies.txt"
        echo "4. Place in /opt/instagram_bot/cookies/"
        echo ""
        echo "Current cookies directory:"
        ls -la /opt/instagram_bot/cookies/ 2>/dev/null || echo "No cookies directory"
        ;;
    *)
        echo "🤖 Instagram Downloader Bot"
        echo "Version: 2.0 | Working with Multiple Methods"
        echo ""
        echo "Usage: \$0 {start|stop|restart|status|logs|setup|config|update|test|clean|cookies}"
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
        echo "  cookies   - Show cookies info"
        echo ""
        echo "Quick Start:"
        echo "  1. instagram-bot setup"
        echo "  2. instagram-bot config  (add your token)"
        echo "  3. instagram-bot start"
        echo "  4. Send PUBLIC Instagram links to bot"
        echo ""
        echo "Features:"
        echo "  • Multiple download methods"
        echo "  • Public Instagram posts support"
        echo "  • Photo and video downloads"
        echo "  • Simple interface"
        echo "  • No callback data issues"
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
    echo "   INSTAGRAM BOT INSTALLATION COMPLETE!"
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
    echo "4. ${GREEN}Test installation:${NC}"
    echo "   instagram-bot test"
    echo ""
    echo "5. ${GREEN}Start bot:${NC}"
    echo "   instagram-bot start"
    echo ""
    echo "6. ${GREEN}Test with a link:${NC}"
    echo "   • Find a PUBLIC Instagram post"
    echo "   • Copy the link"
    echo "   • Send to your bot"
    echo ""
    
    echo -e "${YELLOW}🔧 IMPORTANT NOTES:${NC}"
    echo "• ${GREEN}Only PUBLIC Instagram posts work${NC}"
    echo "• ${GREEN}Private accounts/reels won't work${NC}"
    echo "• ${GREEN}Stories are not supported${NC}"
    echo "• ${GREEN}For better results, add cookies${NC} (see: instagram-bot cookies)"
    echo ""
    
    echo -e "${YELLOW}⚡ TEST LINKS (Public posts):${NC}"
    echo "• https://www.instagram.com/p/CzqF8qYMMkP/"
    echo "• https://www.instagram.com/reel/CzqF8qYMMkP/"
    echo "• https://www.instagram.com/tv/CzqF8qYMMkP/"
    echo ""
    
    echo -e "${GREEN}✅ Bot is ready! Start with 'instagram-bot start'${NC}"
    echo ""
    
    echo -e "${CYAN}📞 SUPPORT:${NC}"
    echo "View logs: instagram-bot logs"
    echo "Check status: instagram-bot status"
    echo "Update: instagram-bot update"
    echo "Clean: instagram-bot clean"
    echo "Cookies info: instagram-bot cookies"
}

# Main installation
main() {
    show_logo
    print_info "Starting Instagram Bot installation..."
    
    install_deps
    install_python_packages
    create_bot_dir
    create_bot_script
    create_cookies
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
