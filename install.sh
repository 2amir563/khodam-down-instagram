#!/bin/bash

# Instagram Telegram Bot Installer
# Single-file installation script for bot.py, requirements.txt, and service setup
# GitHub: https://github.com/2amir563/khodam-down-instagram

set -e

echo "=========================================="
echo "Instagram Telegram Bot Installer"
echo "=========================================="

# Update system packages
echo "[1/10] Updating system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y

# Install Python and pip if not installed
echo "[2/10] Installing Python and required system packages..."
sudo apt-get install -y python3 python3-pip python3-venv git curl wget

# Create project directory
echo "[3/10] Creating project directory..."
mkdir -p ~/instagram-bot
cd ~/instagram-bot

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
import logging
import asyncio
import aiohttp
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes
import instaloader
import json
from urllib.parse import urlparse
import re
import tempfile

# Setup logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# Instagram downloader class
class InstagramDownloader:
    def __init__(self):
        self.loader = instaloader.Instaloader(
            download_pictures=False,
            download_videos=False,
            download_video_thumbnails=False,
            save_metadata=False,
            compress_json=False
        )
        
    async def extract_content(self, url):
        """Extract content from Instagram link"""
        try:
            # Extract shortcode from URL
            shortcode = self._extract_shortcode(url)
            if not shortcode:
                return None, "Invalid Instagram URL"
            
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
                'timestamp': post.date_utc.isoformat(),
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
            
            return content_info, None
            
        except Exception as e:
            logger.error(f"Error extracting content: {e}")
            return None, str(e)
    
    def _extract_shortcode(self, url):
        """Extract shortcode from Instagram URL"""
        patterns = [
            r'instagram\.com/p/([^/?#]+)',
            r'instagram\.com/reel/([^/?#]+)',
            r'instagram\.com/tv/([^/?#]+)'
        ]
        
        for pattern in patterns:
            match = re.search(pattern, url)
            if match:
                return match.group(1)
        return None

# Settings
TOKEN = os.getenv('TELEGRAM_BOT_TOKEN', 'YOUR_BOT_TOKEN_HERE')
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
        content_info, error = await downloader.extract_content(user_message)
        
        if error:
            await processing_msg.edit_text(f"❌ Error: {error}")
            return
        
        # Create response
        response = format_response(content_info)
        
        # Send response
        await send_response(update, context, response, content_info)
        
        await processing_msg.delete()
        
    except Exception as e:
        logger.error(f"Error in handle_instagram_link: {e}")
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
    logger.error(f"Update {update} caused error {context.error}")
    
    try:
        await update.message.reply_text("❌ An error occurred. Please try again later.")
    except:
        pass

# Main function
def main():
    """Main function to start the bot"""
    # Create application
    application = Application.builder().token(TOKEN).build()
    
    # Add handlers
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CommandHandler("help", help_command))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_instagram_link))
    
    # Add error handler
    application.add_error_handler(error_handler)
    
    # Start bot
    print("🤖 Bot is starting...")
    print(f"✅ Bot is running! Visit https://t.me/{(application.bot.username)} to interact with it.")
    
    # Start polling
    application.run_polling(allowed_updates=Update.ALL_TYPES)

if __name__ == '__main__':
    main()
EOF

# Create requirements.txt file
echo "[7/10] Creating requirements.txt..."
cat > requirements.txt << 'EOF'
python-telegram-bot==20.7
instaloader==4.11.0
aiohttp==3.9.1
EOF

# Install Python dependencies
echo "[8/10] Installing Python dependencies..."
pip install -r requirements.txt

# Make bot.py executable
chmod +x bot.py

# Create systemd service file
echo "[9/10] Creating systemd service file..."
cat > bot.service << EOF
[Unit]
Description=Instagram Telegram Bot
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/home/$USER/instagram-bot
Environment="PATH=/home/$USER/instagram-bot/venv/bin"
ExecStart=/home/$USER/instagram-bot/venv/bin/python3 /home/$USER/instagram-bot/bot.py
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=instagram-bot

[Install]
WantedBy=multi-user.target
EOF

# Setup bot token
echo "[10/10] Setting up bot configuration..."
echo ""
echo "=========================================="
echo "Bot Configuration"
echo "=========================================="
echo ""
echo "To get your Telegram Bot Token:"
echo "1. Open Telegram and search for @BotFather"
echo "2. Send /newbot command"
echo "3. Follow instructions to create a new bot"
echo "4. Copy the token you receive"
echo ""
read -p "Enter your Telegram Bot Token: " BOT_TOKEN

if [ -z "$BOT_TOKEN" ]; then
    echo "⚠️  No token provided. You need to manually add it later."
    echo "Edit bot.py and replace 'YOUR_BOT_TOKEN_HERE' with your token"
else
    # Create environment file
    echo "TELEGRAM_BOT_TOKEN=$BOT_TOKEN" > .env
    
    # Update bot.service with token
    sed -i "s|User=\$USER|User=$USER|g" bot.service
    sed -i "s|WorkingDirectory=/home/\$USER/instagram-bot|WorkingDirectory=/home/$USER/instagram-bot|g" bot.service
    sed -i "s|Environment=\"PATH=/home/\$USER/instagram-bot/venv/bin\"|Environment=\"PATH=/home/$USER/instagram-bot/venv/bin\"\nEnvironment=\"TELEGRAM_BOT_TOKEN=$BOT_TOKEN\"|g" bot.service
    sed -i "s|ExecStart=/home/\$USER/instagram-bot/venv/bin/python3|ExecStart=/home/$USER/instagram-bot/venv/bin/python3|g" bot.service
fi

# Setup complete
echo ""
echo "=========================================="
echo "✅ Installation completed successfully!"
echo "=========================================="
echo ""
echo "📁 Project location: /home/$USER/instagram-bot"
echo ""
echo "To start the bot manually:"
echo "cd /home/$USER/instagram-bot"
echo "source venv/bin/activate"
echo "python3 bot.py"
echo ""
echo "📋 To run as a system service:"
echo "sudo cp /home/$USER/instagram-bot/bot.service /etc/systemd/system/"
echo "sudo systemctl daemon-reload"
echo "sudo systemctl enable bot.service"
echo "sudo systemctl start bot.service"
echo "sudo systemctl status bot.service"
echo ""
echo "📊 To view logs:"
echo "sudo journalctl -u bot.service -f"
echo ""
echo "🔧 To stop the bot:"
echo "sudo systemctl stop bot.service"
echo ""
echo "=========================================="
echo "🤖 Bot is ready! Open Telegram and start"
echo "chatting with your bot."
echo "=========================================="
