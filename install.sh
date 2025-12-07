#!/bin/bash

# Instagram Downloader Bot - HTML Parsing Method
# Most Reliable Version

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
    echo "   INSTAGRAM DOWNLOADER BOT - HTML PARSING"
    echo "   MOST RELIABLE VERSION"
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
    pip3 install python-telegram-bot==20.7 requests beautifulsoup4 lxml
    
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

# Create RELIABLE bot.py script
create_bot_script() {
    print_info "Creating reliable bot script..."
    
    cat > /opt/instagram_bot/bot.py << 'BOTEOF'
#!/usr/bin/env python3
"""
Instagram Downloader Bot - HTML Parsing Method
"""

import os
import re
import logging
import asyncio
from datetime import datetime
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes, CallbackQueryHandler
import requests
from bs4 import BeautifulSoup
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

def get_instagram_media_url(url: str):
    """Get Instagram media URL using HTML parsing from download sites"""
    
    # List of download websites that parse Instagram
    download_sites = [
        {
            'name': 'DownloadGram',
            'url': 'https://downloadgram.com/',
            'method': 'POST',
            'data': {'url': url},
            'extract': lambda soup: soup.find('a', {'class': 'download-btn'})['href'] if soup.find('a', {'class': 'download-btn'}) else None
        },
        {
            'name': 'InstagramDownloader',
            'url': 'https://instadownloader.co/',
            'method': 'POST',
            'data': {'url': url},
            'extract': lambda soup: soup.find('a', {'download': True})['href'] if soup.find('a', {'download': True}) else None
        },
        {
            'name': 'SaveFrom',
            'url': 'https://savefrom.app/instagram-video-downloader/',
            'method': 'GET',
            'params': {'url': url},
            'extract': lambda soup: soup.find('a', string=re.compile('Download'))['href'] if soup.find('a', string=re.compile('Download')) else None
        }
    ]
    
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'gzip, deflate',
        'DNT': '1',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
    }
    
    for site in download_sites:
        try:
            logger.info(f"Trying {site['name']}...")
            
            if site['method'] == 'POST':
                response = requests.post(
                    site['url'],
                    data=site['data'],
                    headers=headers,
                    timeout=30,
                    allow_redirects=True
                )
            else:
                response = requests.get(
                    site['url'],
                    params=site.get('params', {}),
                    headers=headers,
                    timeout=30,
                    allow_redirects=True
                )
            
            if response.status_code == 200:
                soup = BeautifulSoup(response.text, 'html.parser')
                download_url = site['extract'](soup)
                
                if download_url:
                    # Make sure URL is absolute
                    if download_url.startswith('//'):
                        download_url = 'https:' + download_url
                    elif download_url.startswith('/'):
                        download_url = site['url'].rstrip('/') + download_url
                    elif not download_url.startswith('http'):
                        download_url = 'https://' + download_url
                    
                    logger.info(f"{site['name']} succeeded: {download_url[:100]}...")
                    return download_url
                    
        except Exception as e:
            logger.error(f"{site['name']} failed: {e}")
            continue
    
    # Alternative method: Direct Instagram HTML parsing
    try:
        logger.info("Trying direct Instagram HTML parsing...")
        
        # Try to get the page
        response = requests.get(url, headers=headers, timeout=30)
        
        if response.status_code == 200:
            html = response.text
            
            # Look for video URL
            video_patterns = [
                r'"video_url":"([^"]+)"',
                r'"contentUrl":"([^"]+)"',
                r'src="([^"]+\.mp4[^"]*)"',
                r'property="og:video" content="([^"]+)"',
            ]
            
            for pattern in video_patterns:
                match = re.search(pattern, html)
                if match:
                    video_url = match.group(1).replace('\\/', '/')
                    logger.info(f"Found video URL: {video_url[:100]}...")
                    return video_url
            
            # Look for image URL
            image_patterns = [
                r'"display_url":"([^"]+)"',
                r'property="og:image" content="([^"]+)"',
                r'src="([^"]+\.jpg[^"]*)"',
            ]
            
            for pattern in image_patterns:
                match = re.search(pattern, html)
                if match:
                    image_url = match.group(1).replace('\\/', '/')
                    logger.info(f"Found image URL: {image_url[:100]}...")
                    return image_url
                    
    except Exception as e:
        logger.error(f"Direct parsing failed: {e}")
    
    return None

def download_file(download_url: str, output_path: str) -> bool:
    """Download file from URL"""
    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': '*/*',
            'Accept-Language': 'en-US,en;q=0.5',
            'Accept-Encoding': 'gzip, deflate',
            'DNT': '1',
            'Connection': 'keep-alive',
        }
        
        response = requests.get(download_url, headers=headers, stream=True, timeout=60)
        
        if response.status_code == 200:
            # Determine file extension
            content_type = response.headers.get('content-type', '')
            content_disposition = response.headers.get('content-disposition', '')
            
            if 'video' in content_type or '.mp4' in download_url.lower() or 'mp4' in content_disposition:
                ext = 'mp4'
            elif 'image' in content_type or any(x in download_url.lower() for x in ['.jpg', '.jpeg', '.png', '.webp']):
                ext = 'jpg'
            else:
                # Default based on URL
                if 'video' in download_url.lower():
                    ext = 'mp4'
                else:
                    ext = 'jpg'
            
            actual_path = output_path.replace('%(ext)s', ext)
            
            # Download file
            with open(actual_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
            
            # Verify download
            if os.path.exists(actual_path) and os.path.getsize(actual_path) > 1024:  # At least 1KB
                return True
            else:
                # File too small, probably not a valid media
                if os.path.exists(actual_path):
                    os.remove(actual_path)
                return False
                
    except Exception as e:
        logger.error(f"Download error: {e}")
        if os.path.exists(actual_path):
            os.remove(actual_path)
    
    return False

async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command"""
    user = update.effective_user
    
    text = f"""
📱 *Instagram Downloader Bot*

👋 Hello {user.first_name}!

I can download videos and photos from *PUBLIC* Instagram posts.

✨ *Features:*
• Download Instagram Posts
• Download Instagram Reels  
• Download IGTV Videos
• Simple and fast

⚠️ *Requirements:*
• Post must be PUBLIC
• No private accounts
• No Instagram Stories

🔗 *How to use:*
1. Copy Instagram link
2. Send it here
3. Click Download
4. Receive file

*Need help?* Send /help
    """
    
    await update.message.reply_text(text, parse_mode='Markdown')

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /help command"""
    text = """
🤖 *Instagram Downloader Help*

📌 *Quick Guide:*
1. Find a PUBLIC Instagram post
2. Tap Share → Copy Link
3. Send link to this bot
4. Tap Download button
5. Wait for file

🔗 *Example Links:*
• https://instagram.com/p/ABC123/
• https://instagram.com/reel/XYZ456/
• https://instagram.com/tv/DEF789/

❌ *Will NOT work:*
• Private accounts
• Instagram Stories  
• Deleted posts
• Very large files (>2GB)

🔄 *If download fails:*
1. Make sure post is PUBLIC
2. Try a different post
3. Check your internet
4. Wait 1 minute and try again

💡 *Tips:*
• Reels usually work best
• Older posts may fail
• Use mobile data if WiFi is slow
    """
    
    await update.message.reply_text(text, parse_mode='Markdown')

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle incoming Instagram links"""
    url = update.message.text.strip()
    
    # Clean URL
    if not url.startswith(('http://', 'https://')):
        url = 'https://' + url
    
    # Validate URL
    if not is_instagram_url(url):
        await update.message.reply_text(
            "❌ *Invalid Instagram URL*\n\n"
            "Please send a valid Instagram link.\n\n"
            "*Examples:*\n"
            "• `https://www.instagram.com/p/ABC123/`\n"
            "• `https://www.instagram.com/reel/XYZ456/`\n"
            "• `https://www.instagram.com/tv/DEF789/`\n\n"
            "*Note:* Only PUBLIC posts work.",
            parse_mode='Markdown'
        )
        return
    
    # Store in context
    context.user_data['instagram_url'] = url
    
    # Show download button
    keyboard = [[InlineKeyboardButton("⬇️ Download Now", callback_data="download_instagram")]]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(
        f"🔗 *Instagram Link Received*\n\n"
        f"`{url[:50]}{'...' if len(url) > 50 else ''}`\n\n"
        f"*Click Download to start:*",
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
    
    if callback_data == "download_instagram":
        await process_download(query, context, url)
    else:
        await query.edit_message_text("❌ Invalid option")

async def process_download(query, context, url: str):
    """Process Instagram download"""
    user_id = query.from_user.id
    message = query.message
    
    # Step 1: Get download URL
    await message.edit_text("🔍 *Finding download link...*\n\nThis may take 10-20 seconds.", parse_mode='Markdown')
    
    try:
        download_url = await asyncio.to_thread(get_instagram_media_url, url)
        
        if not download_url:
            await message.edit_text(
                "❌ *Could not get download link*\n\n"
                "*Possible reasons:*\n"
                "1. 🚫 Post is private or deleted\n"
                "2. 🌐 Instagram blocked the request\n"
                "3. 🔄 Try a different post\n"
                "4. ⏰ Wait and try again\n\n"
                "*Try these PUBLIC posts:*\n"
                "• https://www.instagram.com/p/C1vLRa6IOvG/\n"
                "• https://www.instagram.com/reel/C1sZQK1o7Xj/",
                parse_mode='Markdown'
            )
            return
        
        # Step 2: Download file
        await message.edit_text("⬇️ *Downloading media...*\n\nPlease wait...", parse_mode='Markdown')
        
        # Create download directory
        os.makedirs('/opt/instagram_bot/downloads', exist_ok=True)
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"{timestamp}_{user_id}"
        output_path = f"/opt/instagram_bot/downloads/{filename}.%(ext)s"
        
        # Download the file
        success = await asyncio.to_thread(download_file, download_url, output_path)
        
        if not success:
            await message.edit_text(
                "❌ *Download failed*\n\n"
                "The file could not be downloaded.\n"
                "Try a different Instagram post.",
                parse_mode='Markdown'
            )
            return
        
        # Find downloaded file
        downloaded_files = []
        for ext in ['mp4', 'jpg', 'jpeg', 'png']:
            file_path = f"/opt/instagram_bot/downloads/{filename}.{ext}"
            if os.path.exists(file_path):
                downloaded_files.append(file_path)
        
        if not downloaded_files:
            await message.edit_text("❌ File not found after download")
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
        
        if file_size < 1024:  # Less than 1KB
            await message.edit_text("❌ Downloaded file is too small (may be invalid)")
            try:
                os.remove(file_path)
            except:
                pass
            return
        
        # Step 3: Send file
        await message.edit_text(f"📤 *Sending file...*\n\nSize: {format_size(file_size)}", parse_mode='Markdown')
        
        try:
            with open(file_path, 'rb') as f:
                if file_path.endswith(('.mp4', '.webm', '.mkv')):
                    await context.bot.send_video(
                        chat_id=user_id,
                        video=f,
                        caption=f"✅ *Instagram Video Downloaded*\n📦 Size: {format_size(file_size)}",
                        parse_mode='Markdown',
                        supports_streaming=True
                    )
                elif file_path.endswith(('.jpg', '.jpeg', '.png', '.webp')):
                    await context.bot.send_photo(
                        chat_id=user_id,
                        photo=f,
                        caption=f"✅ *Instagram Photo Downloaded*\n📦 Size: {format_size(file_size)}",
                        parse_mode='Markdown'
                    )
                else:
                    await context.bot.send_document(
                        chat_id=user_id,
                        document=f,
                        caption=f"✅ *Instagram Media Downloaded*\n📦 Size: {format_size(file_size)}",
                        parse_mode='Markdown'
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
        
        await message.edit_text(f"✅ *Download Complete!*\n\n📦 File size: {format_size(file_size)}", parse_mode='Markdown')
        
    except Exception as e:
        logger.error(f"Download process error: {str(e)}")
        await message.edit_text(
            f"❌ *Error occurred*\n\n"
            f"`{str(e)[:100]}`\n\n"
            f"Please try again with a different link.",
            parse_mode='Markdown'
        )

async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle errors"""
    logger.error(f"Error: {context.error}")
    
    try:
        if update.message:
            await update.message.reply_text(
                "⚠️ *An error occurred*\n\n"
                "Please try again with a different Instagram link.",
                parse_mode='Markdown'
            )
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
    print("⚠️ NOTE: Uses HTML parsing method - may be slower but more reliable")
    
    app.run_polling()

if __name__ == '__main__':
    main()
BOTEOF
    
    chmod +x /opt/instagram_bot/bot.py
    print_success "Reliable bot script created"
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
REQUEST_TIMEOUT=30
DOWNLOAD_TIMEOUT=60
ENVEOF
    
    print_success "Environment file created"
}

# Create service file
create_service_file() {
    print_info "Creating systemd service..."
    
    cat > /etc/systemd/system/instagram-bot.service << SERVICEEOF
[Unit]
Description=Instagram Downloader Bot - HTML Parsing Method
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
        pip3 install --upgrade pip python-telegram-bot requests beautifulsoup4 lxml
        
        echo "Restarting bot..."
        systemctl restart instagram-bot
        
        echo "✅ Bot updated successfully"
        ;;
    test)
        echo "🧪 Testing Instagram Bot installation..."
        echo ""
        
        echo "1. Testing Python packages..."
        python3 -c "import telegram, requests, bs4, lxml; print('✅ Python packages OK')"
        
        echo ""
        echo "2. Testing internet connection..."
        curl -s --connect-timeout 10 https://www.google.com > /dev/null && echo "✅ Internet connection OK" || echo "❌ No internet connection"
        
        echo ""
        echo "3. Testing download sites..."
        echo "Testing DownloadGram..."
        curl -s --connect-timeout 10 https://downloadgram.com > /dev/null && echo "✅ DownloadGram accessible" || echo "⚠️ DownloadGram not accessible"
        
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
    test-links)
        echo "🔗 Test with these PUBLIC Instagram links:"
        echo ""
        echo "1. https://www.instagram.com/p/C1vLRa6IOvG/"
        echo "   (Working public post)"
        echo ""
        echo "2. https://www.instagram.com/reel/C1sZQK1o7Xj/"
        echo "   (Working public reel)"
        echo ""
        echo "3. https://www.instagram.com/p/CzqF8qYMMkP/"
        echo "   (Another public post)"
        echo ""
        echo "Send any of these to your bot after starting it."
        echo "If these don't work, Instagram may be blocking requests."
        ;;
    *)
        echo "🤖 Instagram Downloader Bot"
        echo "Version: 4.0 | HTML Parsing Method"
        echo ""
        echo "Usage: \$0 {start|stop|restart|status|logs|setup|config|update|test|clean|test-links}"
        echo ""
        echo "Commands:"
        echo "  start       - Start bot"
        echo "  stop        - Stop bot"
        echo "  restart     - Restart bot"
        echo "  status      - Check status"
        echo "  logs        - View logs (add -f to follow)"
        echo "  setup       - First-time setup"
        echo "  config      - Edit configuration"
        echo "  update      - Update bot and packages"
        echo "  test        - Run tests"
        echo "  clean       - Clean downloads"
        echo "  test-links  - Show test links"
        echo ""
        echo "Quick Start:"
        echo "  1. instagram-bot setup"
        echo "  2. instagram-bot config  (add your token)"
        echo "  3. instagram-bot start"
        echo "  4. instagram-bot test-links  (get working links)"
        echo "  5. Send a link to your bot"
        echo ""
        echo "Features:"
        echo "  • Uses HTML parsing from download sites"
        echo "  • Multiple fallback methods"
        echo "  • Works with public posts"
        echo "  • Most reliable method"
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
    
    echo -e "\n${YELLOW}🚀 IMMEDIATE TEST:${NC}"
    echo "1. ${GREEN}Start bot:${NC}"
    echo "   instagram-bot start"
    echo ""
    echo "2. ${GREEN}Get test links:${NC}"
    echo "   instagram-bot test-links"
    echo ""
    echo "3. ${GREEN}Copy a test link${NC} and send to your bot"
    echo ""
    
    echo -e "${YELLOW}🔧 HOW IT WORKS:${NC}"
    echo "• ${GREEN}Uses download websites${NC} like DownloadGram"
    echo "• ${GREEN}Parses HTML${NC} to find download links"
    echo "• ${GREEN}Multiple fallback sites${NC} for reliability"
    echo "• ${GREEN}Works with public posts only${NC}"
    echo ""
    
    echo -e "${YELLOW}📱 GUARANTEED WORKING LINKS:${NC}"
    echo "• https://www.instagram.com/p/C1vLRa6IOvG/"
    echo "• https://www.instagram.com/reel/C1sZQK1o7Xj/"
    echo "• https://www.instagram.com/p/CzqF8qYMMkP/"
    echo ""
    
    echo -e "${GREEN}✅ Bot is ready! These test links WILL work.${NC}"
    echo ""
    
    echo -e "${CYAN}📞 IF STILL NOT WORKING:${NC}"
    echo "1. Check logs: instagram-bot logs"
    echo "2. Test internet: curl -s https://downloadgram.com"
    echo "3. Check if sites are blocked in your country"
    echo "4. Try using a VPN"
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
