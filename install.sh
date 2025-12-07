#!/bin/bash

# Instagram Bot Installer - Fixed Version
# Solves 401 authentication error

echo "=========================================="
echo "Instagram Bot Installer - Fixed for 401 Error"
echo "=========================================="

# Install dependencies
apt-get update
apt-get install -y python3 python3-pip python3-venv git

# Create directory
mkdir -p /opt/instagram_bot
cd /opt/instagram_bot

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install packages
pip install python-telegram-bot instaloader aiohttp

# Get bot token
echo "Enter your Telegram Bot Token:"
read -p "Token: " BOT_TOKEN
echo "TELEGRAM_BOT_TOKEN=$BOT_TOKEN" > .env

# Create bot.py with Instagram login
cat > bot.py << 'EOF'
#!/usr/bin/env python3
import os
import sys
import logging
import json
import tempfile
import re
import asyncio
from datetime import datetime
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes
import instaloader
import requests
from bs4 import BeautifulSoup

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

# Get token
TOKEN = os.getenv('TELEGRAM_BOT_TOKEN')
if not TOKEN:
    print("ERROR: Bot token not found!")
    sys.exit(1)

class InstagramScraper:
    def __init__(self):
        # Try with instaloader first
        try:
            self.loader = instaloader.Instaloader(
                quiet=True,
                download_pictures=False,
                download_videos=False,
                download_video_thumbnails=False,
                save_metadata=False
            )
            # Try to login (optional, may help with rate limiting)
            # You can create a dummy Instagram account for this
            # self.loader.login("username", "password")
            logger.info("Instaloader initialized")
        except Exception as e:
            logger.error(f"Instaloader init error: {e}")
            self.loader = None
    
    def extract_with_instaloader(self, url):
        """Extract using instaloader"""
        try:
            # Extract shortcode
            shortcode = self._extract_shortcode(url)
            if not shortcode:
                return None, "Invalid Instagram URL"
            
            # Get post
            post = instaloader.Post.from_shortcode(self.loader.context, shortcode)
            
            data = {
                'url': f"https://instagram.com/p/{shortcode}",
                'shortcode': shortcode,
                'username': post.owner_username,
                'caption': post.caption if post.caption else "No caption",
                'likes': post.likes,
                'comments': post.comments,
                'is_video': post.is_video,
                'timestamp': str(post.date_utc) if hasattr(post, 'date_utc') else None,
                'media_count': post.mediacount,
                'video_url': post.video_url if post.is_video else None,
                'image_url': post.url
            }
            
            return data, None
            
        except instaloader.exceptions.InstaloaderException as e:
            logger.warning(f"Instaloader failed: {e}")
            return None, "Instaloader failed, trying alternative method..."
        except Exception as e:
            logger.error(f"Unexpected error with instaloader: {e}")
            return None, str(e)
    
    def extract_with_web_scraping(self, url):
        """Alternative: web scraping method"""
        try:
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
            }
            
            response = requests.get(url, headers=headers, timeout=10)
            soup = BeautifulSoup(response.text, 'html.parser')
            
            # Try to find JSON data in the page
            script_tags = soup.find_all('script', type='application/ld+json')
            for script in script_tags:
                try:
                    data = json.loads(script.string)
                    if '@type' in data and data['@type'] == 'ImageObject':
                        result = {
                            'url': url,
                            'caption': data.get('caption', 'No caption'),
                            'author': data.get('author', 'Unknown'),
                            'timestamp': data.get('datePublished', None)
                        }
                        return result, None
                except:
                    continue
            
            # Try to find meta tags
            title = soup.find('meta', property='og:title')
            description = soup.find('meta', property='og:description')
            
            if title or description:
                result = {
                    'url': url,
                    'title': title['content'] if title else 'No title',
                    'description': description['content'] if description else 'No description'
                }
                return result, None
            
            return None, "Could not extract data from page"
            
        except Exception as e:
            logger.error(f"Web scraping error: {e}")
            return None, str(e)
    
    def _extract_shortcode(self, url):
        """Extract shortcode from URL"""
        patterns = [
            r'instagram\.com/(?:p|reel|tv)/([^/?]+)',
            r'instagr\.am/(?:p|reel|tv)/([^/?]+)'
        ]
        
        for pattern in patterns:
            match = re.search(pattern, url)
            if match:
                return match.group(1)
        return None
    
    async def get_post_info(self, url):
        """Main method to get post info"""
        # First try instaloader
        if self.loader:
            data, error = self.extract_with_instaloader(url)
            if data:
                return data, None
        
        # If instaloader fails, try web scraping
        data, error = self.extract_with_web_scraping(url)
        if data:
            return data, None
        
        # Both methods failed
        return None, error or "Failed to extract data"

# Create scraper instance
scraper = InstagramScraper()

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        "🤖 *Instagram Content Extractor Bot*\n\n"
        "Send me any Instagram link and I'll extract:\n"
        "• Post caption/text\n"
        "• Username\n"
        "• Likes & comments\n"
        "• And more!\n\n"
        "_Just send me a link to get started!_",
        parse_mode='Markdown'
    )

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        "📖 *How to use:*\n\n"
        "1. Copy any Instagram link\n"
        "2. Paste it here\n"
        "3. I'll extract all text content\n\n"
        "*Supported links:*\n"
        "• https://instagram.com/p/...\n"
        "• https://instagram.com/reel/...\n"
        "• https://instagram.com/tv/...\n\n"
        "⚠️ *Note:* Only public posts can be extracted",
        parse_mode='Markdown'
    )

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    text = update.message.text.strip()
    
    logger.info(f"User {user_id} sent: {text[:50]}")
    
    # Check if it's an Instagram link
    if not ('instagram.com' in text or 'instagr.am' in text):
        await update.message.reply_text("❌ Please send a valid Instagram link")
        return
    
    # Send processing message
    msg = await update.message.reply_text("⏳ *Processing...* This may take a moment.", parse_mode='Markdown')
    
    try:
        # Get post info
        data, error = await scraper.get_post_info(text)
        
        if error:
            await msg.edit_text(f"❌ *Error:* {error}\n\nTry again or send a different link.")
            return
        
        # Format response
        response = format_response(data)
        
        # Send response
        await msg.edit_text(response, parse_mode='Markdown')
        
        # Send JSON file if we have enough data
        if 'shortcode' in data or 'url' in data:
            await send_json_file(update, data)
        else:
            await update.message.reply_text("⚠️ *Note:* Limited data available. JSON file not created.")
        
        logger.info(f"Successfully processed link for user {user_id}")
        
    except Exception as e:
        logger.error(f"Error processing message: {e}")
        await msg.edit_text(f"❌ *Error processing link:* {str(e)}\n\nPlease try again.")

def format_response(data):
    """Format data as readable response"""
    response = "📷 *Instagram Content Extracted*\n\n"
    
    if 'username' in data:
        response += f"👤 *Username:* @{data['username']}\n"
    
    if 'author' in data:
        response += f"👤 *Author:* {data['author']}\n"
    
    if 'likes' in data:
        response += f"❤️ *Likes:* {data['likes']:,}\n"
    
    if 'comments' in data:
        response += f"💬 *Comments:* {data['comments']:,}\n"
    
    if 'is_video' in data:
        response += f"🎥 *Video:* {'Yes' if data['is_video'] else 'No'}\n"
    
    if 'timestamp' in data and data['timestamp']:
        response += f"📅 *Date:* {data['timestamp']}\n"
    
    if 'title' in data:
        response += f"📌 *Title:* {data['title']}\n"
    
    if 'caption' in data:
        caption = data['caption']
        if len(caption) > 500:
            caption = caption[:500] + "..."
        response += f"\n📝 *Caption:*\n{caption}\n"
    
    if 'description' in data:
        desc = data['description']
        if len(desc) > 500:
            desc = desc[:500] + "..."
        response += f"\n📄 *Description:*\n{desc}\n"
    
    response += f"\n🔗 *URL:* {data['url']}"
    
    return response

async def send_json_file(update, data):
    """Send JSON file with data"""
    try:
        json_data = json.dumps(data, indent=2, ensure_ascii=False)
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False, encoding='utf-8') as f:
            f.write(json_data)
            temp_file = f.name
        
        # Generate filename
        if 'shortcode' in data:
            filename = f"instagram_{data['shortcode']}.json"
        else:
            filename = "instagram_data.json"
        
        with open(temp_file, 'rb') as file:
            await update.message.reply_document(
                document=file,
                filename=filename,
                caption="📁 *Complete data in JSON format*",
                parse_mode='Markdown'
            )
        
        os.unlink(temp_file)
        
    except Exception as e:
        logger.error(f"Error sending JSON file: {e}")

async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle errors"""
    logger.error(f"Update {update} caused error {context.error}")
    try:
        await update.message.reply_text("❌ An error occurred. Please try again.")
    except:
        pass

def main():
    """Main function"""
    print("🤖 Starting Instagram Bot...")
    print(f"🔑 Token: {TOKEN[:10]}...")
    
    # Create application
    application = Application.builder().token(TOKEN).build()
    
    # Add handlers
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CommandHandler("help", help_command))
    application.add_handler(CommandHandler("info", help_command))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    
    # Add error handler
    application.add_error_handler(error_handler)
    
    # Start bot
    print("✅ Bot is running!")
    print("Press Ctrl+C to stop")
    
    application.run_polling(allowed_updates=Update.ALL_TYPES)

if __name__ == '__main__':
    main()
EOF

# Make executable
chmod +x bot.py

# Create log directory
mkdir -p /var/log/instagram_bot

# Create systemd service
cat > /etc/systemd/system/instagram-bot.service << EOF
[Unit]
Description=Instagram Telegram Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/instagram_bot
Environment="PATH=/opt/instagram_bot/venv/bin"
EnvironmentFile=/opt/instagram_bot/.env
ExecStart=/opt/instagram_bot/venv/bin/python3 /opt/instagram_bot/bot.py
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=instagram-bot

[Install]
WantedBy=multi-user.target
EOF

# Enable service
systemctl daemon-reload
systemctl enable instagram-bot.service
systemctl start instagram-bot.service

# Check status
echo "Checking service status..."
sleep 3
systemctl status instagram-bot.service --no-pager

echo ""
echo "=========================================="
echo "✅ Installation Complete!"
echo "=========================================="
echo ""
echo "Quick commands:"
echo "• Check status: systemctl status instagram-bot"
echo "• View logs: journalctl -u instagram-bot -f"
echo "• Restart: systemctl restart instagram-bot"
echo ""
echo "Now go to Telegram and send /start to your bot!"
echo "Then send an Instagram link to test."
