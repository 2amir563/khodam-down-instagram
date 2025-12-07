#!/bin/bash

# Instagram Telegram Bot - Complete Install Script
# Save this as install.sh and run: bash install.sh

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

# Step 1: Update system
print_info "Step 1: Updating system packages..."
apt-get update -y
apt-get upgrade -y

# Step 2: Install Python
print_info "Step 2: Installing Python..."
apt-get install -y python3 python3-pip python3-venv git curl wget

# Step 3: Create directory
print_info "Step 3: Creating bot directory..."
INSTALL_DIR="/opt/instagram_bot"
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# Step 4: Create virtual environment
print_info "Step 4: Creating Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Step 5: Install packages
print_info "Step 5: Installing Python packages..."
pip install --upgrade pip
pip install python-telegram-bot==20.7 instaloader==4.11.0 requests beautifulsoup4

# Step 6: Get bot token
print_info "Step 6: Setting up bot configuration..."
echo ""
echo "=========================================="
echo "TELEGRAM BOT TOKEN"
echo "=========================================="
echo "Get token from @BotFather on Telegram"
echo "Example: 1234567890:ABCdefGHIjklMnOpQRstUVwxyz"
echo "=========================================="
echo ""

read -p "Enter your Telegram Bot Token: " BOT_TOKEN

if [ -z "$BOT_TOKEN" ]; then
    print_error "Token cannot be empty!"
    exit 1
fi

# Step 7: Create .env file
echo "TELEGRAM_BOT_TOKEN=$BOT_TOKEN" > .env
chmod 600 .env

# Step 8: Create bot.py
print_info "Step 8: Creating bot.py..."
cat > bot.py << 'BOTPY'
#!/usr/bin/env python3
# Instagram Telegram Bot
# Extracts text from Instagram links

import os
import sys
import json
import logging
import tempfile
import re
import requests
from datetime import datetime
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes

# Setup logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO,
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('/var/log/instagram_bot.log')
    ]
)
logger = logging.getLogger(__name__)

# Get bot token
TOKEN = os.getenv('TELEGRAM_BOT_TOKEN')
if not TOKEN:
    logger.error("Bot token not found!")
    print("ERROR: Please set TELEGRAM_BOT_TOKEN in .env file")
    sys.exit(1)

class InstagramExtractor:
    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
        })
    
    def extract_shortcode(self, url):
        """Extract shortcode from Instagram URL"""
        patterns = [
            r'(?:https?://)?(?:www\.)?instagram\.com/(?:p|reel|tv)/([^/?]+)',
            r'(?:https?://)?(?:www\.)?instagr\.am/(?:p|reel|tv)/([^/?]+)'
        ]
        
        for pattern in patterns:
            match = re.search(pattern, url)
            if match:
                return match.group(1)
        return None
    
    def extract_from_web(self, url):
        """Extract data from Instagram page"""
        try:
            logger.info(f"Fetching URL: {url}")
            response = self.session.get(url, timeout=15)
            response.raise_for_status()
            
            html = response.text
            
            # Try to find JSON-LD data
            json_ld_pattern = r'<script type="application/ld\+json">(.*?)</script>'
            json_ld_matches = re.findall(json_ld_pattern, html, re.DOTALL)
            
            for json_str in json_ld_matches:
                try:
                    data = json.loads(json_str.strip())
                    if isinstance(data, dict) and ('@type' in data or 'name' in data):
                        return self._parse_json_ld(data, url)
                except json.JSONDecodeError:
                    continue
            
            # Try to find meta tags
            return self._parse_meta_tags(html, url)
            
        except requests.RequestException as e:
            logger.error(f"Request error: {e}")
            return None, f"Network error: {str(e)}"
        except Exception as e:
            logger.error(f"Extraction error: {e}")
            return None, f"Extraction failed: {str(e)}"
    
    def _parse_json_ld(self, data, url):
        """Parse JSON-LD data"""
        result = {
            'url': url,
            'title': data.get('name', ''),
            'description': data.get('description', ''),
            'author': data.get('author', {}).get('name', '') if isinstance(data.get('author'), dict) else data.get('author', ''),
            'date': data.get('datePublished', ''),
            'image': data.get('image', {}).get('url', '') if isinstance(data.get('image'), dict) else data.get('image', '')
        }
        return result, None
    
    def _parse_meta_tags(self, html, url):
        """Parse meta tags from HTML"""
        from bs4 import BeautifulSoup
        
        soup = BeautifulSoup(html, 'html.parser')
        
        result = {'url': url}
        
        # Get title
        title_tag = soup.find('title')
        if title_tag:
            result['title'] = title_tag.text.strip()
        
        # Get meta description
        meta_desc = soup.find('meta', attrs={'name': 'description'})
        if meta_desc and meta_desc.get('content'):
            result['description'] = meta_desc['content']
        
        # Get OG tags
        og_title = soup.find('meta', property='og:title')
        if og_title and og_title.get('content'):
            result['title'] = og_title['content']
        
        og_desc = soup.find('meta', property='og:description')
        if og_desc and og_desc.get('content'):
            result['description'] = og_desc['content']
        
        og_image = soup.find('meta', property='og:image')
        if og_image and og_image.get('content'):
            result['image'] = og_image['content']
        
        # Try to find caption in script tags
        script_pattern = r'"caption":"(.*?)"'
        caption_match = re.search(script_pattern, html)
        if caption_match:
            caption = caption_match.group(1)
            # Clean caption
            caption = caption.encode().decode('unicode_escape').replace('\\n', '\n')
            result['caption'] = caption
        
        if 'title' in result or 'description' in result or 'caption' in result:
            return result, None
        else:
            return None, "No extractable data found"
    
    def get_post_info(self, url):
        """Main method to get post info"""
        # Clean URL
        if not url.startswith('http'):
            url = 'https://' + url
        
        # Extract data
        data, error = self.extract_from_web(url)
        
        if error:
            # Try alternative method - use public API
            return self._try_alternative_method(url)
        
        return data, error
    
    def _try_alternative_method(self, url):
        """Try alternative method to get data"""
        try:
            # Use a public Instagram API
            shortcode = self.extract_shortcode(url)
            if not shortcode:
                return None, "Invalid Instagram URL"
            
            api_url = f"https://www.instagram.com/p/{shortcode}/?__a=1&__d=dis"
            response = self.session.get(api_url, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                # Parse the response (structure may vary)
                if 'graphql' in data and 'shortcode_media' in data['graphql']:
                    media = data['graphql']['shortcode_media']
                    result = {
                        'url': url,
                        'shortcode': shortcode,
                        'username': media['owner']['username'],
                        'caption': media['edge_media_to_caption']['edges'][0]['node']['text'] if media['edge_media_to_caption']['edges'] else '',
                        'likes': media['edge_media_preview_like']['count'],
                        'comments': media['edge_media_to_comment']['count'],
                        'is_video': media['is_video'],
                        'timestamp': media['taken_at_timestamp']
                    }
                    return result, None
        except Exception as e:
            logger.error(f"Alternative method failed: {e}")
        
        return None, "Failed to extract data from Instagram"

# Create extractor
extractor = InstagramExtractor()

# Telegram bot handlers
async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command"""
    welcome = """
🤖 *Instagram Content Extractor Bot*

Send me any Instagram link and I'll extract:
• Post text/caption
• Description
• Metadata
• And more!

*Commands:*
/start - Show this message
/help - Get help
/info - Bot information

*Just send me an Instagram link to begin!*
"""
    await update.message.reply_text(welcome, parse_mode='Markdown')

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /help command"""
    help_text = """
📖 *How to use this bot:*

1. Copy an Instagram link (post, reel, or video)
2. Paste it here
3. I'll extract all text content

*Supported links:*
• https://instagram.com/p/XXXXX
• https://instagram.com/reel/XXXXX
• https://instagram.com/tv/XXXXX

*Note:* Only public content can be extracted.
"""
    await update.message.reply_text(help_text, parse_mode='Markdown')

async def info_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /info command"""
    info_text = f"""
📊 *Bot Information*

• Version: 2.0
• Method: Web extraction
• Status: Active
• Time: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}

This bot extracts text content from Instagram links.
"""
    await update.message.reply_text(info_text, parse_mode='Markdown')

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle incoming messages"""
    user_text = update.message.text.strip()
    user_id = update.effective_user.id
    
    logger.info(f"User {user_id} sent: {user_text[:50]}")
    
    # Check if it's an Instagram link
    if 'instagram.com' not in user_text and 'instagr.am' not in user_text:
        await update.message.reply_text(
            "❌ *Please send a valid Instagram link*\n\n"
            "Example: https://www.instagram.com/p/CvC9FkHNrJI/",
            parse_mode='Markdown'
        )
        return
    
    # Send processing message
    processing_msg = await update.message.reply_text("⏳ *Processing your link...*", parse_mode='Markdown')
    
    try:
        # Extract data
        data, error = extractor.get_post_info(user_text)
        
        if error:
            await processing_msg.edit_text(f"❌ *Error:* {error}\n\nPlease try a different link.")
            return
        
        # Format response
        response = await format_response(data)
        
        # Send response
        await processing_msg.edit_text(response, parse_mode='Markdown')
        
        # Send JSON file
        await send_json_file(update, data)
        
        logger.info(f"Successfully processed link for user {user_id}")
        
    except Exception as e:
        logger.error(f"Error in handle_message: {e}")
        await processing_msg.edit_text(f"❌ *Unexpected error:* {str(e)}\n\nPlease try again.")

async def format_response(data):
    """Format data for Telegram response"""
    response = "📷 *Instagram Content Extracted*\n\n"
    
    # Add basic info
    if 'title' in data and data['title']:
        response += f"📌 *Title:* {data['title']}\n"
    
    if 'author' in data and data['author']:
        response += f"👤 *Author:* {data['author']}\n"
    elif 'username' in data and data['username']:
        response += f"👤 *Username:* @{data['username']}\n"
    
    if 'date' in data and data['date']:
        response += f"📅 *Date:* {data['date']}\n"
    elif 'timestamp' in data and data['timestamp']:
        try:
            dt = datetime.fromtimestamp(data['timestamp'])
            response += f"📅 *Date:* {dt.strftime('%Y-%m-%d %H:%M:%S')}\n"
        except:
            pass
    
    if 'likes' in data:
        response += f"❤️ *Likes:* {data['likes']:,}\n"
    
    if 'comments' in data:
        response += f"💬 *Comments:* {data['comments']:,}\n"
    
    if 'is_video' in data:
        response += f"🎥 *Video:* {'Yes' if data['is_video'] else 'No'}\n"
    
    # Add caption/description
    if 'caption' in data and data['caption']:
        caption = data['caption']
        if len(caption) > 800:
            caption = caption[:800] + "..."
        response += f"\n📝 *Caption:*\n{caption}\n"
    elif 'description' in data and data['description']:
        desc = data['description']
        if len(desc) > 800:
            desc = desc[:800] + "..."
        response += f"\n📄 *Description:*\n{desc}\n"
    
    response += f"\n🔗 *URL:* {data.get('url', 'N/A')}"
    
    return response

async def send_json_file(update, data):
    """Send JSON file with complete data"""
    try:
        json_str = json.dumps(data, indent=2, ensure_ascii=False, default=str)
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False, encoding='utf-8') as f:
            f.write(json_str)
            temp_path = f.name
        
        # Determine filename
        if 'shortcode' in data:
            filename = f"instagram_{data['shortcode']}.json"
        else:
            filename = "instagram_data.json"
        
        with open(temp_path, 'rb') as f:
            await update.message.reply_document(
                document=f,
                filename=filename,
                caption="📁 *Complete data in JSON format*",
                parse_mode='Markdown'
            )
        
        # Cleanup
        os.unlink(temp_path)
        
    except Exception as e:
        logger.error(f"Error sending JSON file: {e}")
        await update.message.reply_text("⚠️ *Note:* Could not create JSON file.")

async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle errors"""
    logger.error(f"Update {update} caused error: {context.error}")
    try:
        await update.message.reply_text("❌ An error occurred. Please try again.")
    except:
        pass

def main():
    """Main function to run the bot"""
    print("🤖 Starting Instagram Telegram Bot...")
    print(f"🔑 Token: {TOKEN[:10]}...")
    
    try:
        # Create application
        application = Application.builder().token(TOKEN).build()
        
        # Add handlers
        application.add_handler(CommandHandler("start", start_command))
        application.add_handler(CommandHandler("help", help_command))
        application.add_handler(CommandHandler("info", info_command))
        application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
        
        # Error handler
        application.add_error_handler(error_handler)
        
        # Start bot
        print("✅ Bot is starting...")
        print("📝 Check logs: tail -f /var/log/instagram_bot.log")
        print("🛑 Press Ctrl+C to stop")
        
        application.run_polling(allowed_updates=Update.ALL_TYPES)
        
    except Exception as e:
        logger.error(f"Failed to start bot: {e}")
        print(f"❌ Failed to start bot: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
BOTPY

# Make executable
chmod +x bot.py

# Step 9: Create log directory
print_info "Step 9: Creating log directory..."
mkdir -p /var/log/instagram_bot
chmod 755 /var/log/instagram_bot

# Step 10: Create systemd service
print_info "Step 10: Creating systemd service..."
cat > /etc/systemd/system/instagram-bot.service << EOF
[Unit]
Description=Instagram Telegram Bot
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$INSTALL_DIR/venv/bin"
EnvironmentFile=$INSTALL_DIR/.env
ExecStart=$INSTALL_DIR/venv/bin/python3 $INSTALL_DIR/bot.py
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=instagram-bot

[Install]
WantedBy=multi-user.target
EOF

# Step 11: Start the service
print_info "Step 11: Starting bot service..."
systemctl daemon-reload
systemctl enable instagram-bot.service
systemctl start instagram-bot.service

# Wait and check status
sleep 3

# Step 12: Verify installation
print_info "Step 12: Verifying installation..."
if systemctl is-active --quiet instagram-bot.service; then
    print_success "✅ Bot service is running!"
else
    print_error "❌ Service failed to start. Checking logs..."
    journalctl -u instagram-bot.service --no-pager -n 20
fi

# Final instructions
echo ""
echo "=========================================="
echo "✅ INSTALLATION COMPLETE!"
echo "=========================================="
echo ""
echo "📁 Installation directory: $INSTALL_DIR"
echo "🔧 Config file: $INSTALL_DIR/.env"
echo "📝 Main script: $INSTALL_DIR/bot.py"
echo "📊 Log file: /var/log/instagram_bot.log"
echo ""
echo "🔍 QUICK COMMANDS:"
echo "• Check status: systemctl status instagram-bot"
echo "• View logs: journalctl -u instagram-bot -f"
echo "• View log file: tail -f /var/log/instagram_bot.log"
echo "• Restart bot: systemctl restart instagram-bot"
echo "• Stop bot: systemctl stop instagram-bot"
echo ""
echo "🤖 TELEGRAM USAGE:"
echo "1. Open Telegram"
echo "2. Find your bot (ask @BotFather for username)"
echo "3. Send /start command"
echo "4. Send an Instagram link"
echo ""
echo "=========================================="
echo "Need help? Check logs for errors."
echo "=========================================="
