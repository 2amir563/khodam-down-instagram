#!/bin/bash

# Instagram Telegram Bot Installer
# Single-file installation script
# GitHub: https://github.com/2amir563/khodam-down-instagram

set -e

echo "=========================================="
echo "Instagram Telegram Bot Installer"
echo "=========================================="

# Get current user
CURRENT_USER=$(whoami)
echo "Current user: $CURRENT_USER"
echo ""

# Update system packages
echo "[1/10] Updating system packages..."
apt-get update -y
apt-get upgrade -y

# Install Python and pip if not installed
echo "[2/10] Installing Python and required system packages..."
apt-get install -y python3 python3-pip python3-venv git curl wget

# Create project directory in current user's home
echo "[3/10] Creating project directory..."
PROJECT_DIR="/root/instagram-bot"
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

# Create virtual environment
echo "[4/10] Creating Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Upgrade pip
echo "[5/10] Upgrading pip..."
pip install --upgrade pip

# Create bot.py file
echo "[6/10] Creating bot.py..."
cat > bot.py << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import logging
import asyncio
import aiohttp
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes
import instaloader
import json
import re
import tempfile

# Add current directory to path for imports
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Setup logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO,
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('/tmp/instagram_bot.log')
    ]
)
logger = logging.getLogger(__name__)

# Instagram downloader class
class InstagramDownloader:
    def __init__(self):
        try:
            self.loader = instaloader.Instaloader(
                download_pictures=False,
                download_videos=False,
                download_video_thumbnails=False,
                save_metadata=False,
                compress_json=False,
                quiet=True
            )
            logger.info("Instaloader initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize Instaloader: {e}")
            raise
        
    async def extract_content(self, url):
        """Extract content from Instagram link"""
        try:
            logger.info(f"Extracting content from URL: {url}")
            
            # Extract shortcode from URL
            shortcode = self._extract_shortcode(url)
            if not shortcode:
                logger.error(f"Could not extract shortcode from URL: {url}")
                return None, "Invalid Instagram URL"
            
            logger.info(f"Extracted shortcode: {shortcode}")
            
            # Get post
            post = instaloader.Post.from_shortcode(self.loader.context, shortcode)
            
            # Collect information
            content_info = {
                'url': url,
                'shortcode': shortcode,
                'caption': post.caption if post.caption else '',
                'owner': post.owner_username,
                'likes': post.likes,
                'comments': post.comments,
                'timestamp': post.date_utc.isoformat() if hasattr(post, 'date_utc') else '',
                'media_count': post.mediacount,
                'is_video': post.is_video,
                'video_url': post.video_url if post.is_video else None,
                'image_urls': []
            }
            
            # Collect image URLs
            if post.mediacount > 0:
                for node in post.get_sidecar_nodes():
                    if node.is_video:
                        content_info['image_urls'].append(node.video_url)
                    else:
                        content_info['image_urls'].append(node.display_url)
            
            logger.info(f"Successfully extracted content for shortcode: {shortcode}")
            return content_info, None
            
        except instaloader.exceptions.InstaloaderException as e:
            logger.error(f"Instaloader error: {e}")
            return None, f"Instagram error: {str(e)}"
        except Exception as e:
            logger.error(f"Error extracting content: {e}", exc_info=True)
            return None, f"Error: {str(e)}"
    
    def _extract_shortcode(self, url):
        """Extract shortcode from Instagram URL"""
        patterns = [
            r'instagram\.com/p/([^/?#]+)',
            r'instagram\.com/reel/([^/?#]+)',
            r'instagram\.com/tv/([^/?#]+)',
            r'instagr\.am/p/([^/?#]+)'
        ]
        
        for pattern in patterns:
            match = re.search(pattern, url)
            if match:
                return match.group(1)
        return None

# Get bot token from environment or file
def get_bot_token():
    """Get bot token from environment variable or .env file"""
    # Try environment variable first
    token = os.getenv('TELEGRAM_BOT_TOKEN')
    
    if token and token != 'YOUR_BOT_TOKEN_HERE':
        return token
    
    # Try .env file
    env_file = os.path.join(os.path.dirname(__file__), '.env')
    if os.path.exists(env_file):
        try:
            with open(env_file, 'r') as f:
                for line in f:
                    if line.startswith('TELEGRAM_BOT_TOKEN='):
                        token = line.split('=', 1)[1].strip()
                        if token and token != 'YOUR_BOT_TOKEN_HERE':
                            return token
        except Exception as e:
            logger.error(f"Error reading .env file: {e}")
    
    return None

# Settings
TOKEN = get_bot_token()
if not TOKEN:
    logger.error("Bot token not found! Please set TELEGRAM_BOT_TOKEN environment variable or create .env file")
    print("ERROR: Bot token not found!")
    print("Please set your bot token in one of these ways:")
    print("1. Create .env file with: TELEGRAM_BOT_TOKEN=your_token_here")
    print("2. Export environment variable: export TELEGRAM_BOT_TOKEN=your_token_here")
    print("3. Edit bot.py and set TOKEN variable directly")
    sys.exit(1)

MAX_MESSAGE_LENGTH = 4096  # Telegram message length limit

# Create downloader object
downloader = InstagramDownloader()

# /start command
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Send welcome message"""
    welcome_message = """
🤖 Welcome to Instagram Content Extractor Bot!

Send me an Instagram post link (post, reel, or video) and I will extract all text content and information for you.

Commands:
/start - Show this message
/help - Show help information

⚠️ Note: This bot only extracts publicly available content.
    """
    await update.message.reply_text(welcome_message)

# /help command
async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Send help information"""
    help_message = """
📖 How to use this bot:

1. Send me any Instagram post link
2. I will extract:
   • Post caption/text
   • Owner username
   • Likes count
   • Comments count
   • Timestamp
   • Media URLs
   • And other metadata

Supported links:
• Posts: https://www.instagram.com/p/XXXXX/
• Reels: https://www.instagram.com/reel/XXXXX/
• Videos: https://www.instagram.com/tv/XXXXX/

⚠️ Limitations:
• Private accounts cannot be accessed
• Some content might be restricted
    """
    await update.message.reply_text(help_message)

# Process Instagram link
async def handle_instagram_link(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Process Instagram link"""
    user_message = update.message.text
    
    # Check if message contains Instagram link
    if not any(domain in user_message.lower() for domain in ['instagram.com', 'instagr.am']):
        await update.message.reply_text("❌ Please send a valid Instagram link.")
        return
    
    # Send processing message
    processing_msg = await update.message.reply_text("⏳ Processing your Instagram link...")
    
    try:
        # Extract content
        content_info, error = await asyncio.wait_for(
            downloader.extract_content(user_message),
            timeout=30
        )
        
        if error:
            await processing_msg.edit_text(f"❌ Error: {error}")
            return
        
        # Create response
        response = format_response(content_info)
        
        # Send response
        await send_response(update, context, response, content_info)
        
        await processing_msg.delete()
        
    except asyncio.TimeoutError:
        await processing_msg.edit_text("❌ Request timeout. Please try again.")
        logger.error(f"Timeout processing URL: {user_message}")
    except Exception as e:
        logger.error(f"Error in handle_instagram_link: {e}", exc_info=True)
        await processing_msg.edit_text(f"❌ An error occurred: {str(e)}")

def format_response(content_info):
    """Format response"""
    response = f"""
📷 Instagram Content Extracted Successfully!

🔗 URL: {content_info['url']}
👤 Owner: @{content_info['owner']}
❤️ Likes: {content_info['likes']:,}
💬 Comments: {content_info['comments']:,}
📅 Date: {content_info['timestamp']}
📊 Media Count: {content_info['media_count']}
🎥 Is Video: {'Yes' if content_info['is_video'] else 'No'}

📝 Caption/Text:
{content_info['caption'] if content_info['caption'] else 'No caption available'}

🔗 Media URLs:
"""
    
    # Add video URL
    if content_info['is_video'] and content_info['video_url']:
        response += f"\n🎥 Video URL: {content_info['video_url']}"
    
    # Add image URLs
    for i, img_url in enumerate(content_info['image_urls'], 1):
        response += f"\n🖼️ Image {i}: {img_url}"
    
    return response

async def send_response(update, context, response, content_info):
    """Send response to user"""
    # Send text
    if len(response) > MAX_MESSAGE_LENGTH:
        # If text is too long, split it
        parts = [response[i:i+MAX_MESSAGE_LENGTH] for i in range(0, len(response), MAX_MESSAGE_LENGTH)]
        for part in parts:
            await update.message.reply_text(part)
    else:
        await update.message.reply_text(response)
    
    # Create and send JSON file containing information
    await send_json_file(update, content_info)

async def send_json_file(update, content_info):
    """Send JSON file containing information"""
    try:
        # Create JSON file
        json_data = json.dumps(content_info, indent=2, ensure_ascii=False)
        
        # Save to temporary file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False, encoding='utf-8') as f:
            f.write(json_data)
            temp_file_path = f.name
        
        # Send file
        with open(temp_file_path, 'rb') as file:
            await update.message.reply_document(
                document=file,
                filename=f"instagram_{content_info['shortcode']}.json",
                caption="📁 JSON file containing all extracted information"
            )
        
        # Delete temporary file
        os.unlink(temp_file_path)
        
    except Exception as e:
        logger.error(f"Error sending JSON file: {e}")
        await update.message.reply_text("⚠️ Could not create JSON file, but text content was sent.")

# Error handler
async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle bot errors"""
    logger.error(f"Update {update} caused error {context.error}", exc_info=True)
    
    try:
        await update.message.reply_text("❌ An error occurred. Please try again later.")
    except:
        pass

# Main function
def main():
    """Main function to start the bot"""
    try:
        logger.info("=" * 50)
        logger.info("Starting Instagram Telegram Bot")
        logger.info("=" * 50)
        
        # Create application
        application = Application.builder().token(TOKEN).build()
        
        # Add handlers
        application.add_handler(CommandHandler("start", start))
        application.add_handler(CommandHandler("help", help_command))
        application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_instagram_link))
        
        # Add error handler
        application.add_error_handler(error_handler)
        
        # Start bot
        bot_username = application.bot.username
        print("=" * 50)
        print("🤖 Instagram Telegram Bot")
        print("=" * 50)
        print(f"Bot Token: {TOKEN[:10]}...")
        print(f"Bot Username: @{bot_username}")
        print(f"Log file: /tmp/instagram_bot.log")
        print("=" * 50)
        print("Starting bot...")
        print("Press Ctrl+C to stop")
        print("=" * 50)
        
        logger.info(f"Bot started with username: @{bot_username}")
        
        # Start polling
        application.run_polling(
            allowed_updates=Update.ALL_TYPES,
            drop_pending_updates=True
        )
        
    except Exception as e:
        logger.error(f"Failed to start bot: {e}", exc_info=True)
        print(f"ERROR: Failed to start bot: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
EOF

# Create requirements.txt file
echo "[7/10] Creating requirements.txt..."
cat > requirements.txt << 'EOF'
python-telegram-bot[job-queue]==20.7
instaloader==4.11.0
aiohttp==3.9.1
EOF

# Install Python dependencies
echo "[8/10] Installing Python dependencies..."
pip install -r requirements.txt

# Make bot.py executable
chmod +x bot.py

# Setup bot token
echo "[9/10] Setting up bot configuration..."
echo ""
echo "=========================================="
echo "Bot Configuration"
echo "=========================================="
echo ""

# Check if running as root
if [ "$CURRENT_USER" = "root" ]; then
    USER_HOME="/root"
else
    USER_HOME="/home/$CURRENT_USER"
fi

# Get bot token
read -p "Enter your Telegram Bot Token (from @BotFather): " BOT_TOKEN

if [ -z "$BOT_TOKEN" ] || [ "$BOT_TOKEN" = "YOUR_BOT_TOKEN_HERE" ]; then
    echo "⚠️  WARNING: No valid token provided!"
    echo "You MUST set the bot token manually."
    echo ""
    echo "Create .env file:"
    echo "echo 'TELEGRAM_BOT_TOKEN=your_token_here' > $PROJECT_DIR/.env"
    echo ""
    echo "Or set environment variable:"
    echo "export TELEGRAM_BOT_TOKEN=your_token_here"
else
    # Create .env file
    echo "TELEGRAM_BOT_TOKEN=$BOT_TOKEN" > .env
    chmod 600 .env
    echo "✅ Bot token saved to .env file"
fi

# Create systemd service file
echo "[10/10] Creating systemd service file..."
cat > bot.service << EOF
[Unit]
Description=Instagram Telegram Bot
After=network.target
Wants=network.target

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$PROJECT_DIR
Environment="PATH=$PROJECT_DIR/venv/bin"
EnvironmentFile=$PROJECT_DIR/.env
ExecStart=$PROJECT_DIR/venv/bin/python3 $PROJECT_DIR/bot.py
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=instagram-bot

# Security
NoNewPrivileges=true
ProtectSystem=strict
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# Setup complete
echo ""
echo "=========================================="
echo "✅ Installation completed successfully!"
echo "=========================================="
echo ""
echo "📁 Project location: $PROJECT_DIR"
echo ""
echo "📝 Quick Start Guide:"
echo ""
echo "1. First, test the bot manually:"
echo "   cd $PROJECT_DIR"
echo "   source venv/bin/activate"
echo "   python3 bot.py"
echo ""
echo "2. If manual test works, set up as service:"
echo "   sudo cp $PROJECT_DIR/bot.service /etc/systemd/system/"
echo "   sudo systemctl daemon-reload"
echo "   sudo systemctl enable bot.service"
echo "   sudo systemctl start bot.service"
echo ""
echo "3. Check bot status:"
echo "   sudo systemctl status bot.service"
echo ""
echo "4. View logs:"
echo "   sudo journalctl -u bot.service -f"
echo "   OR"
echo "   tail -f /tmp/instagram_bot.log"
echo ""
echo "🔧 Troubleshooting:"
echo "   • Check token: cat $PROJECT_DIR/.env"
echo "   • Test dependencies: python3 -c \"import instaloader; print('OK')\""
echo "   • Check Python version: python3 --version"
echo ""
echo "=========================================="
echo "🤖 Bot Setup Instructions:"
echo "=========================================="
echo ""
echo "1. Open Telegram"
echo "2. Search for your bot username"
echo "3. Send /start command"
echo "4. Send an Instagram link to test"
echo ""
echo "Need help? Check logs:"
echo "tail -f /tmp/instagram_bot.log"
echo "=========================================="
