#!/bin/bash

# Instagram Downloader Bot using External API
# Simple and Working Version

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
    echo "   INSTAGRAM DOWNLOADER BOT - API VERSION"
    echo "   USING EXTERNAL DOWNLOAD SERVICES"
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
    pip3 install python-telegram-bot==20.7 requests
    
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

# Create SIMPLE WORKING bot.py script
create_bot_script() {
    print_info "Creating simple working bot script..."
    
    cat > /opt/instagram_bot/bot.py << 'BOTEOF'
#!/usr/bin/env python3
"""
Simple Instagram Downloader Bot using External APIs
"""

import os
import re
import logging
import asyncio
from datetime import datetime
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes, CallbackQueryHandler
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

# External APIs (free services)
APIS = [
    {
        'name': 'SnapInsta',
        'url': 'https://snapinsta.app/action.php',
        'method': 'POST',
        'headers': {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'Origin': 'https://snapinsta.app',
            'Referer': 'https://snapinsta.app/',
            'X-Requested-With': 'XMLHttpRequest'
        },
        'data': lambda url: {'url': url, 'lang': 'en'},
        'extract': lambda data: data.get('medias', [{}])[0].get('url') if data.get('medias') else None
    },
    {
        'name': 'SaveFrom',
        'url': 'https://api.savefrom.net/v1/source/instagram',
        'method': 'POST',
        'headers': {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        },
        'data': lambda url: {'url': url},
        'extract': lambda data: data.get('url')
    },
    {
        'name': 'IGram',
        'url': 'https://igram.io/api/convert',
        'method': 'POST',
        'headers': {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Content-Type': 'application/json'
        },
        'data': lambda url: json.dumps({'url': url}),
        'extract': lambda data: data.get('url') or (data.get('medias', [{}])[0].get('url') if data.get('medias') else None)
    }
]

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

def get_download_url_from_api(url: str):
    """Get download URL from external APIs"""
    for api in APIS:
        try:
            logger.info(f"Trying {api['name']} API...")
            
            if api['method'] == 'POST':
                response = requests.post(
                    api['url'],
                    headers=api['headers'],
                    data=api['data'](url) if isinstance(api['data'](url), dict) else api['data'](url),
                    timeout=30
                )
            else:
                response = requests.get(
                    api['url'],
                    params={'url': url},
                    headers=api['headers'],
                    timeout=30
                )
            
            if response.status_code == 200:
                data = response.json()
                download_url = api['extract'](data)
                
                if download_url:
                    logger.info(f"{api['name']} API succeeded: {download_url[:100]}...")
                    return download_url
                    
        except Exception as e:
            logger.error(f"{api['name']} API failed: {e}")
            continue
    
    return None

def download_instagram_media(download_url: str, output_path: str) -> bool:
    """Download media from URL"""
    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
        
        response = requests.get(download_url, headers=headers, stream=True, timeout=60)
        
        if response.status_code == 200:
            # Determine file extension
            content_type = response.headers.get('content-type', '')
            if 'video' in content_type or '.mp4' in download_url.lower():
                ext = 'mp4'
            elif 'image' in content_type or any(x in download_url.lower() for x in ['.jpg', '.jpeg', '.png']):
                ext = 'jpg'
            else:
                # Default to mp4 for Instagram
                ext = 'mp4'
            
            actual_path = output_path.replace('%(ext)s', ext)
            
            # Download with progress
            total_size = int(response.headers.get('content-length', 0))
            downloaded = 0
            
            with open(actual_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
                        downloaded += len(chunk)
            
            # Verify file was downloaded
            if os.path.exists(actual_path) and os.path.getsize(actual_path) > 0:
                return True
                
    except Exception as e:
        logger.error(f"Download error: {e}")
    
    return False

async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command"""
    user = update.effective_user
    
    text = f"""
📱 *Instagram Downloader Bot*

👋 Hello {user.first_name}!

I can download videos and photos from Instagram.

✅ *What I can download:*
• Instagram Posts (public only)
• Instagram Reels (public only)
• IGTV Videos (public only)

⚠️ *Important Notes:*
• Only PUBLIC posts work
• Private accounts won't work
• Stories are not supported
• Large files may take time

🔗 *How to use:*
1. Copy Instagram link
2. Send it to me
3. I'll download it
4. Receive your file

*Need help?* Send /help
    """
    
    await update.message.reply_text(text, parse_mode='Markdown')

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /help command"""
    text = """
🤖 *Instagram Downloader Help*

📌 *Quick Guide:*
1. Find a PUBLIC Instagram post
2. Copy the link (click Share → Copy Link)
3. Send the link to this bot
4. Wait for download
5. Receive your file

🔗 *Supported Links:*
• https://instagram.com/p/ABC123/ (Posts)
• https://instagram.com/reel/XYZ456/ (Reels)
• https://instagram.com/tv/DEF789/ (IGTV)

❌ *Not Supported:*
• Private accounts
• Instagram Stories
• Very large files (>2GB)

🔄 *If download fails:*
1. Make sure post is PUBLIC
2. Try a different post
3. Check your internet
4. Try again later

📞 *Support:*
For issues, check the logs or contact admin.
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
        await update.message.reply_text(
            "❌ Please send a valid Instagram URL\n\n"
            "*Examples:*\n"
            "• https://www.instagram.com/p/ABC123/\n"
            "• https://www.instagram.com/reel/XYZ456/\n"
            "• https://www.instagram.com/tv/DEF789/",
            parse_mode='Markdown'
        )
        return
    
    # Store in context
    context.user_data['instagram_url'] = url
    
    # Show download button
    keyboard = [[InlineKeyboardButton("⬇️ Download Now", callback_data="download_now")]]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(
        f"🔗 *Link Received*\n\n`{url}`\n\nClick below to download:",
        parse_mode='Markdown',
        reply_markup=reply_markup
    )

async def handle_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle callback queries"""
    query = update.callback_query
    await query.answer()
    
    user_id = query.from_user.id
    callback_data = query.data
    
    # Get URL from context
    url = context.user_data.get('instagram_url')
    
    if not url:
        await query.edit_message_text("❌ No link found. Please send the Instagram link again.")
        return
    
    if callback_data == "download_now":
        await download_instagram(query, context, url)
    else:
        await query.edit_message_text("❌ Invalid option")

async def download_instagram(query, context, url: str):
    """Download Instagram content"""
    user_id = query.from_user.id
    message = query.message
    
    # Step 1: Getting download URL
    await message.edit_text("🔍 Getting download link...")
    
    try:
        # Try to get download URL from APIs
        download_url = get_download_url_from_api(url)
        
        if not download_url:
            await message.edit_text(
                "❌ Could not get download link.\n\n"
                "*Possible reasons:*\n"
                "1. Post is private or deleted\n"
                "2. Instagram blocked the request\n"
                "3. Try a different post\n"
                "4. Link might be invalid\n\n"
                "Try again with a PUBLIC Instagram post."
            )
            return
        
        # Step 2: Downloading file
        await message.edit_text("⬇️ Downloading media...")
        
        # Create download directory
        os.makedirs('/opt/instagram_bot/downloads', exist_ok=True)
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"{timestamp}_{user_id}"
        output_path = f"/opt/instagram_bot/downloads/{filename}.%(ext)s"
        
        # Download the file
        success = download_instagram_media(download_url, output_path)
        
        if not success:
            await message.edit_text("❌ Download failed. The file might be unavailable or too large.")
            return
        
        # Find downloaded file
        downloaded_files = []
        for ext in ['mp4', 'jpg', 'jpeg', 'png']:
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
            try:
                os.remove(file_path)
            except:
                pass
            return
        
        if file_size == 0:
            await message.edit_text("❌ Downloaded file is empty")
            try:
                os.remove(file_path)
            except:
                pass
            return
        
        # Step 3: Sending file
        await message.edit_text(f"📤 Sending file ({format_size(file_size)})...")
        
        try:
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
        except Exception as e:
            logger.error(f"Telegram send error: {e}")
            await message.edit_text(f"❌ Error sending file: {str(e)[:100]}")
            return
        
        # Cleanup
        try:
            os.remove(file_path)
        except:
            pass
        
        await message.edit_text(f"✅ Download complete!\n📦 File size: {format_size(file_size)}")
        
    except Exception as e:
        logger.error(f"Download process error: {str(e)}")
        await message.edit_text(f"❌ Error: {str(e)[:150]}\n\nPlease try again with a different link.")

async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle errors"""
    logger.error(f"Error: {context.error}")
    
    try:
        if update.message:
            await update.message.reply_text("⚠️ An error occurred. Please try again with a different Instagram link.")
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
    print("⚠️ NOTE: Using external APIs for downloading")
    
    app.run_polling()

if __name__ == '__main__':
    main()
BOTEOF
    
    chmod +x /opt/instagram_bot/bot.py
    print_success "Simple working bot script created"
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

# Timeout settings (seconds)
DOWNLOAD_TIMEOUT=60
API_TIMEOUT=30
ENVEOF
    
    print_success "Environment file created"
}

# Create service file
create_service_file() {
    print_info "Creating systemd service..."
    
    cat > /etc/systemd/system/instagram-bot.service << SERVICEEOF
[Unit]
Description=Instagram Downloader Bot using External APIs
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
        pip3 install --upgrade pip python-telegram-bot requests
        
        echo "Restarting bot..."
        systemctl restart instagram-bot
        
        echo "✅ Bot updated successfully"
        ;;
    test)
        echo "🧪 Testing Instagram Bot installation..."
        echo ""
        
        echo "1. Testing Python packages..."
        python3 -c "import telegram, requests, json; print('✅ Python packages OK')"
        
        echo ""
        echo "2. Testing internet connection..."
        curl -s --connect-timeout 10 https://www.google.com > /dev/null && echo "✅ Internet connection OK" || echo "❌ No internet connection"
        
        echo ""
        echo "3. Testing external APIs..."
        echo "Testing SnapInsta API..."
        curl -s --connect-timeout 10 https://snapinsta.app > /dev/null && echo "✅ SnapInsta accessible" || echo "⚠️ SnapInsta not accessible"
        
        echo ""
        echo "4. Testing service..."
        systemctl is-active instagram-bot &>/dev/null && echo "✅ Service is running" || echo "⚠️ Service is not running"
        
        echo ""
        echo "✅ All tests completed"
        ;;
    clean)
        echo "🧹 Cleaning downloads..."
        rm -rf /opt/instagram_bot/downloads/*
        echo "✅ Cleaned downloads"
        ;;
    test-link)
        echo "🔗 Testing with sample Instagram link..."
        echo ""
        echo "Try these PUBLIC Instagram links:"
        echo ""
        echo "1. https://www.instagram.com/p/C1vLRa6IOvG/"
        echo "   (Public post - should work)"
        echo ""
        echo "2. https://www.instagram.com/reel/C1sZQK1o7Xj/"
        echo "   (Public reel - should work)"
        echo ""
        echo "3. https://www.instagram.com/p/CzqF8qYMMkP/"
        echo "   (Public post - should work)"
        echo ""
        echo "Send any of these links to your bot after starting it."
        ;;
    *)
        echo "🤖 Instagram Downloader Bot"
        echo "Version: 3.0 | Using External APIs"
        echo ""
        echo "Usage: \$0 {start|stop|restart|status|logs|setup|config|update|test|clean|test-link}"
        echo ""
        echo "Commands:"
        echo "  start      - Start bot"
        echo "  stop       - Stop bot"
        echo "  restart    - Restart bot"
        echo "  status     - Check status"
        echo "  logs       - View logs (add -f to follow)"
        echo "  setup      - First-time setup"
        echo "  config     - Edit configuration"
        echo "  update     - Update bot and packages"
        echo "  test       - Run tests"
        echo "  clean      - Clean downloads"
        echo "  test-link  - Show test links"
        echo ""
        echo "Quick Start:"
        echo "  1. instagram-bot setup"
        echo "  2. instagram-bot config  (add your token)"
        echo "  3. instagram-bot start"
        echo "  4. instagram-bot test-link  (get test links)"
        echo "  5. Send a PUBLIC Instagram link to bot"
        echo ""
        echo "Features:"
        echo "  • Uses multiple external APIs"
        echo "  • Works with public Instagram posts"
        echo "  • Simple one-click download"
        echo "  • No complex setup needed"
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
    
    echo -e "\n${YELLOW}🚀 QUICK START GUIDE:${NC}"
    echo "1. ${GREEN}Setup bot:${NC}"
    echo "   instagram-bot setup"
    echo ""
    echo "2. ${GREEN}Get Bot Token:${NC}"
    echo "   • Go to @BotFather on Telegram"
    echo "   • Send /newbot"
    echo "   • Follow instructions"
    echo ""
    echo "3. ${GREEN}Configure:${NC}"
    echo "   instagram-bot config"
    echo "   • Add BOT_TOKEN to the file"
    echo ""
    echo "4. ${GREEN}Start bot:${NC}"
    echo "   instagram-bot start"
    echo ""
    echo "5. ${GREEN}Test with sample links:${NC}"
    echo "   instagram-bot test-link"
    echo ""
    
    echo -e "${YELLOW}🔧 HOW IT WORKS:${NC}"
    echo "• ${GREEN}Uses external APIs${NC} to bypass Instagram restrictions"
    echo "• ${GREEN}Multiple fallback services${NC} for reliability"
    echo "• ${GREEN}Simple interface${NC} - just send link and click download"
    echo "• ${GREEN}Works with public posts only${NC}"
    echo ""
    
    echo -e "${YELLOW}📱 TEST WITH THESE LINKS (Public):${NC}"
    echo "• https://www.instagram.com/p/C1vLRa6IOvG/"
    echo "• https://www.instagram.com/reel/C1sZQK1o7Xj/"
    echo "• https://www.instagram.com/p/CzqF8qYMMkP/"
    echo ""
    
    echo -e "${GREEN}✅ Bot is ready! Start with 'instagram-bot start'${NC}"
    echo ""
    
    echo -e "${CYAN}📞 TROUBLESHOOTING:${NC}"
    echo "Test installation: instagram-bot test"
    echo "View logs: instagram-bot logs"
    echo "Check status: instagram-bot status"
    echo "Get test links: instagram-bot test-link"
    echo "Clean downloads: instagram-bot clean"
}

# Main installation
main() {
    show_logo
    print_info "Starting Instagram Bot installation..."
    
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
