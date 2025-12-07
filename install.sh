#!/bin/bash

# Instagram Telegram Bot - Simple Version
# Save this as install.sh on GitHub
# Run: bash <(curl -s https://raw.githubusercontent.com/2amir563/khodam-down-instagram/main/install.sh)

set -e

echo "=========================================="
echo "Instagram Telegram Bot Installer"
echo "=========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Functions
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${YELLOW}[i]${NC} $1"; }

# Step 1: Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_info "Running as non-root user, using sudo for system commands"
    SUDO="sudo"
else
    SUDO=""
fi

# Step 2: Update and install dependencies
print_info "Step 1: Updating system packages..."
$SUDO apt-get update -y
$SUDO apt-get upgrade -y

print_info "Step 2: Installing Python and dependencies..."
$SUDO apt-get install -y python3 python3-pip python3-venv git curl wget

# Step 3: Create installation directory
print_info "Step 3: Creating installation directory..."
INSTALL_DIR="/opt/instagram_bot"
$SUDO mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# Step 4: Create virtual environment
print_info "Step 4: Creating Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Step 5: Install Python packages
print_info "Step 5: Installing required Python packages..."
pip install --upgrade pip
pip install python-telegram-bot==20.7 requests beautifulsoup4 lxml

# Step 6: Create bot configuration
print_info "Step 6: Creating bot configuration..."

# Ask for Telegram Bot Token
echo ""
echo "=========================================="
echo "TELEGRAM BOT TOKEN SETUP"
echo "=========================================="
echo "To get your bot token:"
echo "1. Open Telegram"
echo "2. Search for @BotFather"
echo "3. Send /newbot command"
echo "4. Follow the instructions"
echo "5. Copy the token (looks like: 1234567890:ABCdefGHIjklMnOpQRstUVwxyz)"
echo "=========================================="
echo ""

read -p "Enter your Telegram Bot Token: " BOT_TOKEN

# Validate token format
if [ -z "$BOT_TOKEN" ]; then
    print_error "Token cannot be empty!"
    exit 1
fi

if [[ ! "$BOT_TOKEN" =~ ^[0-9]{8,10}:[a-zA-Z0-9_-]{35}$ ]]; then
    print_info "Warning: Token format looks unusual, but continuing anyway..."
fi

# Create config file
cat > config.json << EOF
{
    "telegram_token": "$BOT_TOKEN",
    "admin_ids": [],
    "log_file": "/var/log/instagram_bot.log",
    "temp_dir": "/tmp/instagram_bot"
}
EOF

# Step 7: Create the main bot file
print_info "Step 7: Creating bot.py..."
cat > bot.py << 'EOF'
#!/usr/bin/env python3
"""
Instagram Telegram Bot
Send Instagram link → Get JSON file
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

import requests
from bs4 import BeautifulSoup
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes

# Load configuration
CONFIG_FILE = "config.json"
if os.path.exists(CONFIG_FILE):
    with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
        config = json.load(f)
    TOKEN = config.get('telegram_token', '')
else:
    print(f"ERROR: Config file {CONFIG_FILE} not found!")
    sys.exit(1)

if not TOKEN:
    print("ERROR: Telegram token not found in config!")
    sys.exit(1)

# Setup logging
LOG_FILE = config.get('log_file', '/var/log/instagram_bot.log')
Path(LOG_FILE).parent.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE, encoding='utf-8'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class InstagramBot:
    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept-Encoding': 'gzip, deflate, br',
        })
        logger.info("Instagram Bot initialized")
    
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
    
    def get_instagram_data(self, url):
        """Get data from Instagram link"""
        try:
            logger.info(f"Processing URL: {url}")
            
            # Clean URL
            if not url.startswith('http'):
                url = 'https://' + url
            
            response = self.session.get(url, timeout=15)
            response.raise_for_status()
            
            html = response.text
            soup = BeautifulSoup(html, 'html.parser')
            
            # Extract data
            data = {
                'url': url,
                'timestamp': datetime.now().isoformat(),
                'status_code': response.status_code,
                'content_length': len(html),
                'success': True
            }
            
            # Extract shortcode
            shortcode = self.extract_shortcode(url)
            if shortcode:
                data['shortcode'] = shortcode
                data['instagram_url'] = f"https://www.instagram.com/p/{shortcode}/"
            
            # Extract title
            title_tag = soup.find('title')
            if title_tag:
                data['title'] = title_tag.text.strip()
            
            # Extract meta description
            meta_desc = soup.find('meta', attrs={'name': 'description'})
            if meta_desc and meta_desc.get('content'):
                data['description'] = meta_desc['content']
            
            # Extract Open Graph data
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
            for script in soup(["script", "style", "noscript"]):
                script.decompose()
            
            text = soup.get_text(separator='\n', strip=True)
            lines = [line for line in text.split('\n') if line.strip()]
            data['text_content'] = '\n'.join(lines[:20])  # First 20 lines
            
            # Extract mentions and hashtags
            all_text = ' '.join(lines)
            mentions = re.findall(r'@([a-zA-Z0-9_.]+)', all_text)
            hashtags = re.findall(r'#([a-zA-Z0-9_]+)', all_text)
            
            if mentions:
                data['mentions'] = list(set(mentions))[:10]
            if hashtags:
                data['hashtags'] = list(set(hashtags))[:10]
            
            logger.info(f"Successfully extracted data from {url}")
            return data
            
        except Exception as e:
            logger.error(f"Error extracting data: {e}")
            return {
                'success': False,
                'url': url,
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            }

# Create bot instance
bot = InstagramBot()

# Telegram handlers
async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command"""
    welcome_text = """
🤖 *Instagram Telegram Bot*

ارسال کنید: لینک اینستاگرام
دریافت کنید: فایل JSON

🎯 *نحوه استفاده:*
1. لینک اینستاگرام را کپی کنید
2. برای ربات ارسال کنید
3. فایل JSON دریافت کنید

🔗 *مثال لینک:*
• https://www.instagram.com/p/ABC123/
• https://instagram.com/reel/XYZ456/
• https://instagram.com/tv/DEF789/

📊 *اطلاعات استخراج شده:*
• متن و توضیحات پست
• اطلاعات متا
• منشن‌ها و هشتگ‌ها
• لینک‌های تصویر

💡 *توجه:* فقط پست‌های عمومی قابل استخراج هستند.
"""
    await update.message.reply_text(welcome_text, parse_mode='Markdown')
    logger.info(f"User {update.effective_user.id} started the bot")

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /help command"""
    help_text = """
📖 *راهنمای استفاده*

*چه لینک‌هایی پشتیبانی می‌شود:*
✅ پست عکس: instagram.com/p/...
✅ رییل: instagram.com/reel/...
✅ ویدیو: instagram.com/tv/...

*چه اطلاعاتی استخراج می‌شود:*
• متن اصلی پست
• توضیحات متا
• لینک تصویر اصلی
• منشن‌ها و هشتگ‌ها
• اطلاعات فنی

*اگر خطا دریافت کردید:*
1. مطمئن شوید لینک درست است
2. اطمینان حاصل کنید پست عمومی است
3. اینترنت سرور را چک کنید
4. دوباره امتحان کنید

*برای شروع:* یک لینک اینستاگرام ارسال کنید!
"""
    await update.message.reply_text(help_text, parse_mode='Markdown')

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle incoming messages"""
    user_id = update.effective_user.id
    user_text = update.message.text.strip()
    
    logger.info(f"User {user_id} sent: {user_text[:50]}")
    
    # Check if it's an Instagram link
    if not ('instagram.com' in user_text or 'instagr.am' in user_text):
        await update.message.reply_text(
            "❌ *لینک اینستاگرام نیست*\n\n"
            "لطفاً فقط لینک اینستاگرام ارسال کنید.\n"
            "مثال: https://www.instagram.com/p/ABC123/",
            parse_mode='Markdown'
        )
        return
    
    # Send processing message
    msg = await update.message.reply_text("⏳ *در حال پردازش لینک...*", parse_mode='Markdown')
    
    try:
        # Get data from Instagram
        data = bot.get_instagram_data(user_text)
        
        if not data.get('success', False):
            error_msg = data.get('error', 'Unknown error')
            await msg.edit_text(
                f"❌ *خطا در استخراج اطلاعات*\n\n"
                f"خطا: {error_msg[:100]}\n\n"
                f"لطفاً لینک را بررسی کنید و دوباره امتحان کنید.",
                parse_mode='Markdown'
            )
            return
        
        # Create JSON file
        json_str = json.dumps(data, indent=2, ensure_ascii=False, default=str)
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False, encoding='utf-8') as f:
            f.write(json_str)
            temp_file = f.name
        
        # Determine filename
        shortcode = data.get('shortcode', 'instagram')
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"instagram_{shortcode}_{timestamp}.json"
        
        # Send file
        with open(temp_file, 'rb') as file:
            await update.message.reply_document(
                document=file,
                filename=filename,
                caption=f"📁 *فایل اطلاعات اینستاگرام*\n\n"
                       f"🔗 لینک: {data['url'][:50]}...\n"
                       f"🕐 زمان: {datetime.now().strftime('%H:%M:%S')}\n"
                       f"📊 حجم داده: {len(json_str):,} کاراکتر",
                parse_mode='Markdown'
            )
        
        # Cleanup temp file
        os.unlink(temp_file)
        
        # Send success message
        await msg.edit_text(
            f"✅ *فایل ارسال شد!*\n\n"
            f"📊 *خلاصه اطلاعات:*\n"
            f"• کد پست: {data.get('shortcode', 'نامشخص')}\n"
            f"• عنوان: {data.get('title', data.get('og_title', 'نامشخص'))[:50]}...\n"
            f"• توضیحات: {len(data.get('description', data.get('og_description', '')))} کاراکتر\n"
            f"• منشن‌ها: {len(data.get('mentions', []))}\n"
            f"• هشتگ‌ها: {len(data.get('hashtags', []))}\n\n"
            f"📁 فایل JSON شامل تمام اطلاعات است.",
            parse_mode='Markdown'
        )
        
        logger.info(f"Successfully sent file for user {user_id}")
        
    except Exception as e:
        logger.error(f"Error in handle_message: {e}", exc_info=True)
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
    """Main function to run the bot"""
    print("=" * 50)
    print("🤖 Instagram Telegram Bot")
    print("=" * 50)
    print(f"Token: {TOKEN[:10]}...")
    print(f"Log file: {LOG_FILE}")
    print("=" * 50)
    
    try:
        # Create application
        application = Application.builder().token(TOKEN).build()
        
        # Add handlers
        application.add_handler(CommandHandler("start", start_command))
        application.add_handler(CommandHandler("help", help_command))
        application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
        
        # Add error handler
        application.add_error_handler(error_handler)
        
        # Start bot
        print("✅ Bot is starting...")
        print("📱 Open Telegram and send /start to your bot")
        print("🛑 Press Ctrl+C to stop")
        print("=" * 50)
        
        application.run_polling(allowed_updates=Update.ALL_TYPES)
        
    except Exception as e:
        logger.error(f"Failed to start bot: {e}", exc_info=True)
        print(f"❌ Failed to start bot: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF

# Step 8: Create startup script
print_info "Step 8: Creating startup script..."
cat > start.sh << 'EOF'
#!/bin/bash
# Startup script for Instagram Bot

cd "$(dirname "$0")"

# Activate virtual environment
source venv/bin/activate

# Run the bot
python3 bot.py
EOF

chmod +x start.sh bot.py

# Step 9: Create systemd service
print_info "Step 9: Creating systemd service..."
cat > instagram-bot.service << EOF
[Unit]
Description=Instagram Telegram Bot
After=network.target
Wants=network-online.target

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
SyslogIdentifier=instagram-bot

[Install]
WantedBy=multi-user.target
EOF

# Install the service
$SUDO cp instagram-bot.service /etc/systemd/system/
$SUDO systemctl daemon-reload
$SUDO systemctl enable instagram-bot.service

# Step 10: Start the service
print_info "Step 10: Starting bot service..."
$SUDO systemctl start instagram-bot.service

# Wait a moment and check status
sleep 3

# Step 11: Verify installation
print_info "Step 11: Verifying installation..."
SERVICE_STATUS=$($SUDO systemctl is-active instagram-bot.service)

if [ "$SERVICE_STATUS" = "active" ]; then
    print_success "✅ Bot service is running successfully!"
else
    print_error "❌ Service failed to start!"
    echo ""
    echo "Checking logs..."
    $SUDO journalctl -u instagram-bot.service --no-pager -n 20
    echo ""
    print_info "Trying to start manually for debugging..."
    cd $INSTALL_DIR
    source venv/bin/activate
    python3 bot.py || echo "Manual start failed"
fi

# Step 12: Final instructions
echo ""
echo "=========================================="
echo "✅ INSTALLATION COMPLETE!"
echo "=========================================="
echo ""
echo "📁 Installation directory: $INSTALL_DIR"
echo "⚙️ Configuration file: $INSTALL_DIR/config.json"
echo "🤖 Bot file: $INSTALL_DIR/bot.py"
echo "📊 Log file: /var/log/instagram_bot.log"
echo ""
echo "🔧 Management commands:"
echo "  sudo systemctl status instagram-bot"
echo "  sudo systemctl restart instagram-bot"
echo "  sudo systemctl stop instagram-bot"
echo "  sudo journalctl -u instagram-bot -f"
echo ""
echo "🤖 Telegram usage:"
echo "1. Open Telegram"
echo "2. Search for your bot (ask @BotFather for username)"
echo "3. Send /start command"
echo "4. Send any Instagram link"
echo "5. Receive JSON file with all data"
echo ""
echo "🔗 Example Instagram links:"
echo "  https://www.instagram.com/p/CvC9FkHNrJI/"
echo "  https://instagram.com/reel/Cxample123/"
echo "  https://instagram.com/tv/ABC123DEF/"
echo ""
echo "💡 Tip: You can edit config.json to add admin IDs:"
echo '  "admin_ids": [YOUR_TELEGRAM_ID]'
echo ""
echo "=========================================="
echo "Need help? Check logs:"
echo "sudo journalctl -u instagram-bot -n 50"
echo "=========================================="

# Test the bot token
echo ""
print_info "Testing bot connection..."
sleep 2
curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getMe" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if data.get('ok'):
        print('✅ Bot is connected to Telegram!')
        print(f'   Bot username: @{data[\"result\"][\"username\"]}')
        print(f'   Bot name: {data[\"result\"][\"first_name\"]}')
    else:
        print('❌ Bot connection failed!')
        print(f'   Error: {data.get(\"description\", \"Unknown error\")}')
except Exception as e:
    print(f'❌ Test error: {e}')
"
echo ""
