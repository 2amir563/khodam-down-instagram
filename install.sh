#!/bin/bash

# Instagram Telegram Bot with RapidAPI
# Most reliable method for Instagram data extraction

set -e

echo "=========================================="
echo "Instagram Bot Installer with RapidAPI"
echo "=========================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Functions
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_info() { echo -e "${YELLOW}[i]${NC} $1"; }

# Step 1: Update system
log_info "Step 1: Updating system..."
apt-get update -y
apt-get upgrade -y

# Step 2: Install Python
log_info "Step 2: Installing Python..."
apt-get install -y python3 python3-pip python3-venv git curl

# Step 3: Create directory
log_info "Step 3: Creating bot directory..."
INSTALL_DIR="/opt/instagram_bot"
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# Step 4: Create virtual environment
log_info "Step 4: Creating virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Step 5: Install packages
log_info "Step 5: Installing Python packages..."
pip install --upgrade pip
pip install python-telegram-bot==20.7 requests

# Step 6: Get Telegram Bot Token
log_info "Step 6: Setting up Telegram Bot..."
echo ""
echo "=========================================="
echo "TELEGRAM BOT TOKEN"
echo "=========================================="
echo "Get token from @BotFather on Telegram"
echo "Example: 1234567890:ABCdefGHIjklMnOpQRstUVwxyz"
echo "=========================================="
echo ""

read -p "Enter your Telegram Bot Token: " TELEGRAM_TOKEN

if [ -z "$TELEGRAM_TOKEN" ]; then
    log_error "Telegram token cannot be empty!"
    exit 1
fi

# Step 7: Get RapidAPI Key (Optional but recommended)
log_info "Step 7: Setting up RapidAPI (Optional but recommended)..."
echo ""
echo "=========================================="
echo "RAPIDAPI KEY (OPTIONAL)"
echo "=========================================="
echo "For best results, get a free API key from:"
echo "1. Go to: https://rapidapi.com/rockapi/api/instagram-scraper"
echo "2. Sign up for free account"
echo "3. Subscribe to 'Instagram Scraper' API"
echo "4. Copy your X-RapidAPI-Key"
echo "5. Press Enter to skip if you don't have API key"
echo "=========================================="
echo ""

read -p "Enter your RapidAPI Key (or press Enter to skip): " RAPIDAPI_KEY

# Step 8: Create config file
log_info "Step 8: Creating configuration file..."
cat > config.py << CONFIG
#!/usr/bin/env python3
# Configuration file

# Telegram Bot Token
TELEGRAM_TOKEN = "$TELEGRAM_TOKEN"

# RapidAPI Configuration (Optional)
RAPIDAPI_KEY = "$RAPIDAPI_KEY"
RAPIDAPI_HOST = "instagram-scraper-api2.p.rapidapi.com"

# Alternative APIs (free)
INSTAGRAM_API_URL = "https://www.instagram.com/graphql/query/"
INSTAGRAM_WEB_URL = "https://www.instagram.com/"

# Bot settings
MAX_RETRIES = 3
TIMEOUT = 30
LOG_LEVEL = "INFO"
CONFIG

# Step 9: Create main bot file
log_info "Step 9: Creating main bot file..."
cat > bot.py << 'BOTPY'
#!/usr/bin/env python3
"""
Instagram Telegram Bot
Uses multiple methods to extract Instagram content
"""

import os
import sys
import json
import logging
import tempfile
import re
import time
import random
from datetime import datetime
from urllib.parse import urlparse, quote

import requests
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes

# Import configuration
try:
    from config import (
        TELEGRAM_TOKEN,
        RAPIDAPI_KEY,
        RAPIDAPI_HOST,
        INSTAGRAM_API_URL,
        INSTAGRAM_WEB_URL,
        MAX_RETRIES,
        TIMEOUT,
        LOG_LEVEL
    )
except ImportError:
    # Default configuration
    TELEGRAM_TOKEN = os.getenv('TELEGRAM_TOKEN', '')
    RAPIDAPI_KEY = os.getenv('RAPIDAPI_KEY', '')
    RAPIDAPI_HOST = "instagram-scraper-api2.p.rapidapi.com"
    INSTAGRAM_API_URL = "https://www.instagram.com/graphql/query/"
    INSTAGRAM_WEB_URL = "https://www.instagram.com/"
    MAX_RETRIES = 3
    TIMEOUT = 30
    LOG_LEVEL = "INFO"

# Setup logging
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('/var/log/instagram_bot.log')
    ]
)
logger = logging.getLogger(__name__)

class InstagramAPI:
    """Handles Instagram data extraction using multiple methods"""
    
    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
        })
        
        # If RapidAPI key is provided
        if RAPIDAPI_KEY:
            self.rapidapi_headers = {
                'x-rapidapi-key': RAPIDAPI_KEY,
                'x-rapidapi-host': RAPIDAPI_HOST
            }
            logger.info("RapidAPI key is configured")
        else:
            self.rapidapi_headers = None
            logger.warning("RapidAPI key not configured. Using alternative methods.")
    
    def extract_shortcode(self, url):
        """Extract shortcode from Instagram URL"""
        patterns = [
            r'(?:https?://)?(?:www\.)?instagram\.com/(?:p|reel|tv)/([^/?]+)',
            r'(?:https?://)?(?:www\.)?instagr\.am/(?:p|reel|tv)/([^/?]+)',
            r'instagram\.com/(?:p|reel|tv)/([^/?]+)'
        ]
        
        url = url.strip()
        for pattern in patterns:
            match = re.search(pattern, url, re.IGNORECASE)
            if match:
                shortcode = match.group(1).split('?')[0].split('#')[0]
                logger.info(f"Extracted shortcode: {shortcode}")
                return shortcode
        
        logger.error(f"Could not extract shortcode from URL: {url}")
        return None
    
    def method1_rapidapi(self, shortcode):
        """Method 1: Use RapidAPI (most reliable)"""
        if not self.rapidapi_headers:
            return None, "RapidAPI key not configured"
        
        try:
            url = f"https://{RAPIDAPI_HOST}/v1/post_info"
            params = {"shortcode": shortcode}
            
            response = self.session.get(
                url,
                headers=self.rapidapi_headers,
                params=params,
                timeout=TIMEOUT
            )
            
            if response.status_code == 200:
                data = response.json()
                
                if data.get('status') == 'success':
                    post = data.get('data', {})
                    
                    result = {
                        'method': 'rapidapi',
                        'shortcode': shortcode,
                        'username': post.get('owner', {}).get('username', ''),
                        'full_name': post.get('owner', {}).get('full_name', ''),
                        'caption': post.get('caption', {}).get('text', ''),
                        'likes': post.get('like_count', 0),
                        'comments': post.get('comment_count', 0),
                        'is_video': post.get('is_video', False),
                        'video_url': post.get('video_url', ''),
                        'image_url': post.get('image_url', ''),
                        'timestamp': post.get('taken_at_timestamp', 0),
                        'url': f"https://www.instagram.com/p/{shortcode}/"
                    }
                    
                    logger.info(f"RapidAPI success for {shortcode}")
                    return result, None
            
            return None, f"RapidAPI failed: {response.status_code}"
            
        except Exception as e:
            logger.error(f"RapidAPI error: {e}")
            return None, str(e)
    
    def method2_public_api(self, shortcode):
        """Method 2: Use Instagram's public GraphQL API"""
        try:
            # This is a public query ID that might work
            query_params = {
                'shortcode': shortcode,
                'child_comment_count': 3,
                'fetch_comment_count': 40,
                'parent_comment_count': 24,
                'has_threaded_comments': True
            }
            
            # Try different endpoints
            endpoints = [
                f"https://www.instagram.com/p/{shortcode}/?__a=1&__d=dis",
                f"https://www.instagram.com/p/{shortcode}/?__a=1",
                f"https://i.instagram.com/api/v1/media/{shortcode}/info/"
            ]
            
            for endpoint in endpoints:
                try:
                    response = self.session.get(endpoint, timeout=TIMEOUT)
                    
                    if response.status_code == 200:
                        data = response.json()
                        
                        # Try different response structures
                        result = self._parse_api_response(data, shortcode)
                        if result:
                            result['method'] = 'public_api'
                            logger.info(f"Public API success for {shortcode}")
                            return result, None
                            
                except Exception as e:
                    logger.debug(f"Endpoint {endpoint} failed: {e}")
                    continue
            
            return None, "Public API methods failed"
            
        except Exception as e:
            logger.error(f"Public API error: {e}")
            return None, str(e)
    
    def _parse_api_response(self, data, shortcode):
        """Parse different Instagram API response structures"""
        result = {
            'shortcode': shortcode,
            'url': f"https://www.instagram.com/p/{shortcode}/"
        }
        
        # Structure 1: Standard Instagram response
        if 'graphql' in data and 'shortcode_media' in data['graphql']:
            media = data['graphql']['shortcode_media']
            
            result.update({
                'username': media.get('owner', {}).get('username', ''),
                'full_name': media.get('owner', {}).get('full_name', ''),
                'caption': media.get('edge_media_to_caption', {}).get('edges', [{}])[0].get('node', {}).get('text', ''),
                'likes': media.get('edge_media_preview_like', {}).get('count', 0),
                'comments': media.get('edge_media_to_comment', {}).get('count', 0),
                'is_video': media.get('is_video', False),
                'video_url': media.get('video_url', ''),
                'image_url': media.get('display_url', ''),
                'timestamp': media.get('taken_at_timestamp', 0)
            })
            return result
        
        # Structure 2: Alternative Instagram response
        elif 'items' in data and len(data['items']) > 0:
            item = data['items'][0]
            
            result.update({
                'username': item.get('user', {}).get('username', ''),
                'full_name': item.get('user', {}).get('full_name', ''),
                'caption': item.get('caption', {}).get('text', '') if item.get('caption') else '',
                'likes': item.get('like_count', 0),
                'comments': item.get('comment_count', 0),
                'is_video': item.get('media_type', 1) == 2,
                'image_url': item.get('image_versions2', {}).get('candidates', [{}])[0].get('url', ''),
                'timestamp': item.get('taken_at', 0)
            })
            return result
        
        # Structure 3: Another possible structure
        elif 'media' in data:
            media = data['media']
            
            result.update({
                'username': media.get('owner', {}).get('username', ''),
                'caption': media.get('caption', ''),
                'likes': media.get('like_count', 0),
                'comments': media.get('comment_count', 0),
                'is_video': media.get('is_video', False),
                'timestamp': media.get('taken_at', 0)
            })
            return result
        
        return None
    
    def method3_web_scraping(self, url):
        """Method 3: Web scraping as fallback"""
        try:
            response = self.session.get(url, timeout=TIMEOUT)
            html = response.text
            
            # Look for JSON-LD data
            json_ld_pattern = r'<script type="application/ld\+json">(.*?)</script>'
            json_ld_matches = re.findall(json_ld_pattern, html, re.DOTALL | re.IGNORECASE)
            
            for json_str in json_ld_matches:
                try:
                    data = json.loads(json_str.strip())
                    if '@type' in data:
                        result = {
                            'method': 'web_scraping',
                            'url': url,
                            'title': data.get('name', ''),
                            'description': data.get('description', ''),
                            'author': data.get('author', {}).get('name', '') if isinstance(data.get('author'), dict) else data.get('author', ''),
                            'image': data.get('image', ''),
                            'date': data.get('datePublished', '')
                        }
                        
                        # Extract shortcode from URL
                        shortcode = self.extract_shortcode(url)
                        if shortcode:
                            result['shortcode'] = shortcode
                        
                        logger.info(f"Web scraping success for {url}")
                        return result, None
                        
                except json.JSONDecodeError:
                    continue
            
            # Look for meta tags
            meta_title = re.search(r'<meta property="og:title" content="(.*?)"', html)
            meta_desc = re.search(r'<meta property="og:description" content="(.*?)"', html)
            
            if meta_title or meta_desc:
                result = {
                    'method': 'web_scraping_meta',
                    'url': url,
                    'title': meta_title.group(1) if meta_title else '',
                    'description': meta_desc.group(1) if meta_desc else ''
                }
                
                shortcode = self.extract_shortcode(url)
                if shortcode:
                    result['shortcode'] = shortcode
                
                logger.info(f"Meta tag scraping success for {url}")
                return result, None
            
            return None, "No extractable data found in page"
            
        except Exception as e:
            logger.error(f"Web scraping error: {e}")
            return None, str(e)
    
    def method4_alternative_service(self, url):
        """Method 4: Use alternative Instagram data services"""
        try:
            # Try different public services
            services = [
                {
                    'url': f'https://api.instagram.com/oembed/?url={quote(url)}',
                    'parser': lambda d: {
                        'method': 'oembed',
                        'title': d.get('title', ''),
                        'author_name': d.get('author_name', ''),
                        'author_url': d.get('author_url', ''),
                        'thumbnail_url': d.get('thumbnail_url', ''),
                        'html': d.get('html', '')
                    }
                },
                {
                    'url': f'https://publish.twitter.com/oembed?url={quote(url)}',
                    'parser': lambda d: {
                        'method': 'twitter_oembed',
                        'html': d.get('html', ''),
                        'author_name': d.get('author_name', '')
                    }
                }
            ]
            
            for service in services:
                try:
                    response = self.session.get(service['url'], timeout=10)
                    if response.status_code == 200:
                        data = response.json()
                        result = service['parser'](data)
                        result['url'] = url
                        
                        shortcode = self.extract_shortcode(url)
                        if shortcode:
                            result['shortcode'] = shortcode
                        
                        logger.info(f"Alternative service success: {service['url']}")
                        return result, None
                        
                except Exception as e:
                    logger.debug(f"Service failed: {service['url']} - {e}")
                    continue
            
            return None, "Alternative services failed"
            
        except Exception as e:
            logger.error(f"Alternative service error: {e}")
            return None, str(e)
    
    def get_post_info(self, instagram_url):
        """Main method to get post info using all available methods"""
        logger.info(f"Processing URL: {instagram_url}")
        
        # Clean URL
        if not instagram_url.startswith('http'):
            instagram_url = 'https://' + instagram_url
        
        # Extract shortcode
        shortcode = self.extract_shortcode(instagram_url)
        if not shortcode:
            return None, "Invalid Instagram URL. Please send a valid post/reel link."
        
        # Try methods in order of reliability
        methods = [
            ("RapidAPI", lambda: self.method1_rapidapi(shortcode)),
            ("Public API", lambda: self.method2_public_api(shortcode)),
            ("Web Scraping", lambda: self.method3_web_scraping(instagram_url)),
            ("Alternative Service", lambda: self.method4_alternative_service(instagram_url))
        ]
        
        for method_name, method_func in methods:
            logger.info(f"Trying {method_name}...")
            data, error = method_func()
            
            if data:
                logger.info(f"{method_name} succeeded!")
                return data, None
            
            logger.warning(f"{method_name} failed: {error}")
            time.sleep(1)  # Small delay between methods
        
        return None, "All extraction methods failed. Instagram may have blocked access."

# Create API instance
instagram_api = InstagramAPI()

# Telegram Bot Functions
async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command"""
    welcome = """
🤖 *Instagram Content Extractor Bot*

I can extract text and information from Instagram posts, reels, and videos.

*How to use:*
1. Send me any Instagram link
2. I'll extract all available text content
3. You'll receive a summary + JSON file

*Supported links:*
• Posts: https://instagram.com/p/...
• Reels: https://instagram.com/reel/...
• Videos: https://instagram.com/tv/...

*Commands:*
/start - Show this message
/help - Get detailed help
/status - Check bot status

*Just send me a link to begin!*
"""
    await update.message.reply_text(welcome, parse_mode='Markdown')
    logger.info(f"User {update.effective_user.id} started the bot")

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /help command"""
    help_text = """
📖 *Detailed Help Guide*

*What I extract:*
• Post caption/text
• Username and profile info
• Likes and comments count
• Post date and time
• Media type (image/video)
• Any available metadata

*Best practices:*
1. Use public Instagram links
2. Avoid very recent posts (may not be indexed yet)
3. If one method fails, try a different link

*Troubleshooting:*
• If extraction fails, I'll try multiple methods
• Some private/business accounts may not work
• Instagram occasionally blocks automated access

*For best results:* Get a free API key from RapidAPI.com
"""
    await update.message.reply_text(help_text, parse_mode='Markdown')

async def status_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /status command"""
    status = f"""
📊 *Bot Status Report*

✅ Bot is running
🕐 Server time: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
🔑 RapidAPI: {'Configured' if RAPIDAPI_KEY else 'Not configured'}
🔄 Methods available: 4
📈 Uptime: Active

*Usage tips:*
• Send any Instagram link to test
• Results may vary based on Instagram's restrictions
"""
    await update.message.reply_text(status, parse_mode='Markdown')

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle incoming Instagram links"""
    user_id = update.effective_user.id
    user_text = update.message.text.strip()
    
    logger.info(f"User {user_id} sent: {user_text[:100]}")
    
    # Check if it's an Instagram link
    if not ('instagram.com' in user_text or 'instagr.am' in user_text):
        await update.message.reply_text(
            "❌ *Please send a valid Instagram link*\n\n"
            "I only work with Instagram links. Examples:\n"
            "• https://www.instagram.com/p/CvC9FkHNrJI/\n"
            "• https://instagram.com/reel/Cxample123\n"
            "• instagram.com/tv/ABC123DEF/",
            parse_mode='Markdown'
        )
        return
    
    # Send processing message
    processing_msg = await update.message.reply_text(
        "⏳ *Processing your Instagram link...*\n"
        "This may take 10-20 seconds as I try multiple methods.",
        parse_mode='Markdown'
    )
    
    try:
        # Extract data
        data, error = instagram_api.get_post_info(user_text)
        
        if error:
            await processing_msg.edit_text(
                f"❌ *Extraction failed*\n\n"
                f"Error: {error}\n\n"
                f"*Possible reasons:*\n"
                f"• The account is private\n"
                f"• Instagram is blocking access\n"
                f"• The link is invalid\n"
                f"• Try a different link",
                parse_mode='Markdown'
            )
            return
        
        # Format and send response
        response = format_instagram_response(data)
        await processing_msg.edit_text(response, parse_mode='Markdown')
        
        # Send JSON file
        await send_json_response(update, data)
        
        logger.info(f"Successfully processed link for user {user_id}")
        
    except Exception as e:
        logger.error(f"Error processing message: {e}", exc_info=True)
        await processing_msg.edit_text(
            f"❌ *Unexpected error*\n\n"
            f"Error: {str(e)}\n\n"
            f"Please try again or contact support.",
            parse_mode='Markdown'
        )

def format_instagram_response(data):
    """Format Instagram data for Telegram response"""
    response = "📷 *Instagram Content Extracted*\n\n"
    
    # Add source method
    if 'method' in data:
        response += f"*Method:* {data['method'].replace('_', ' ').title()}\n"
    
    # Add username/author
    if 'username' in data and data['username']:
        response += f"👤 *Username:* @{data['username']}\n"
    elif 'author_name' in data and data['author_name']:
        response += f"👤 *Author:* {data['author_name']}\n"
    elif 'author' in data and data['author']:
        response += f"👤 *Author:* {data['author']}\n"
    
    # Add full name if available
    if 'full_name' in data and data['full_name']:
        response += f"📛 *Full Name:* {data['full_name']}\n"
    
    # Add likes
    if 'likes' in data:
        response += f"❤️ *Likes:* {data['likes']:,}\n"
    
    # Add comments
    if 'comments' in data:
        response += f"💬 *Comments:* {data['comments']:,}\n"
    
    # Add video info
    if 'is_video' in data:
        response += f"🎥 *Video:* {'Yes' if data['is_video'] else 'No'}\n"
    
    # Add timestamp
    if 'timestamp' in data and data['timestamp']:
        try:
            dt = datetime.fromtimestamp(int(data['timestamp']))
            response += f"📅 *Posted:* {dt.strftime('%Y-%m-%d %H:%M:%S')}\n"
        except:
            response += f"📅 *Timestamp:* {data['timestamp']}\n"
    elif 'date' in data and data['date']:
        response += f"📅 *Date:* {data['date']}\n"
    
    # Add caption/description
    caption = ''
    if 'caption' in data and data['caption']:
        caption = data['caption']
    elif 'description' in data and data['description']:
        caption = data['description']
    elif 'title' in data and data['title']:
        caption = data['title']
    
    if caption:
        # Clean and truncate caption
        caption = caption.strip()
        if len(caption) > 800:
            caption = caption[:800] + "...\n[Text truncated]"
        
        response += f"\n📝 *Caption/Text:*\n{caption}\n"
    
    # Add media URLs if available
    if 'video_url' in data and data['video_url']:
        response += f"\n🎥 *Video URL:* {data['video_url'][:100]}...\n"
    
    if 'image_url' in data and data['image_url']:
        response += f"\n🖼️ *Image URL:* {data['image_url'][:100]}...\n"
    
    if 'thumbnail_url' in data and data['thumbnail_url']:
        response += f"\n🖼️ *Thumbnail:* {data['thumbnail_url'][:100]}...\n"
    
    # Add original URL
    response += f"\n🔗 *Original URL:* {data.get('url', 'N/A')}"
    
    # Add note about JSON file
    response += "\n\n📁 *A JSON file with complete data is attached below*"
    
    return response

async def send_json_response(update, data):
    """Send JSON file with complete data"""
    try:
        # Prepare JSON data
        json_data = json.dumps(data, indent=2, ensure_ascii=False, default=str)
        
        # Create temporary file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False, encoding='utf-8') as f:
            f.write(json_data)
            temp_file = f.name
        
        # Determine filename
        shortcode = data.get('shortcode', 'instagram_data')
        filename = f"instagram_{shortcode}.json"
        
        # Send file
        with open(temp_file, 'rb') as f:
            await update.message.reply_document(
                document=f,
                filename=filename,
                caption="📁 *Complete Instagram data in JSON format*",
                parse_mode='Markdown'
            )
        
        # Cleanup
        os.unlink(temp_file)
        
    except Exception as e:
        logger.error(f"Error sending JSON file: {e}")
        await update.message.reply_text(
            "⚠️ *Note:* Could not create JSON file, but text content was sent.",
            parse_mode='Markdown'
        )

async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle bot errors"""
    logger.error(f"Bot error: {context.error}", exc_info=True)
    
    try:
        await update.message.reply_text(
            "❌ *An error occurred*\n\n"
            "Please try again or contact support."
        )
    except:
        pass

def main():
    """Main function to run the bot"""
    print("🤖 Starting Instagram Telegram Bot...")
    print(f"🔑 Telegram Token: {TELEGRAM_TOKEN[:10]}...")
    
    if RAPIDAPI_KEY:
        print(f"🔑 RapidAPI Key: {RAPIDAPI_KEY[:10]}...")
    else:
        print("⚠️  RapidAPI key not configured. Some methods may not work.")
    
    print("📝 Log file: /var/log/instagram_bot.log")
    print("=" * 50)
    
    try:
        # Create Telegram application
        application = Application.builder().token(TELEGRAM_TOKEN).build()
        
        # Add command handlers
        application.add_handler(CommandHandler("start", start_command))
        application.add_handler(CommandHandler("help", help_command))
        application.add_handler(CommandHandler("status", status_command))
        application.add_handler(CommandHandler("info", status_command))
        
        # Add message handler for Instagram links
        application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
        
        # Add error handler
        application.add_error_handler(error_handler)
        
        # Start the bot
        print("✅ Bot is running! Press Ctrl+C to stop.")
        print("=" * 50)
        
        application.run_polling(allowed_updates=Update.ALL_TYPES)
        
    except Exception as e:
        logger.error(f"Failed to start bot: {e}", exc_info=True)
        print(f"❌ Failed to start bot: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
BOTPY

# Make executable
chmod +x bot.py

# Step 10: Create log directory
log_info "Step 10: Creating log directory..."
mkdir -p /var/log/instagram_bot
chmod 755 /var/log/instagram_bot

# Step 11: Create systemd service
log_info "Step 11: Creating systemd service..."
cat > /etc/systemd/system/instagram-bot.service << EOF
[Unit]
Description=Instagram Telegram Bot with RapidAPI
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

# Environment variables
Environment="TELEGRAM_TOKEN=$TELEGRAM_TOKEN"
Environment="RAPIDAPI_KEY=$RAPIDAPI_KEY"

[Install]
WantedBy=multi-user.target
EOF

# Step 12: Start the service
log_info "Step 12: Starting bot service..."
systemctl daemon-reload
systemctl enable instagram-bot.service
systemctl start instagram-bot.service

# Wait and check status
sleep 5

# Step 13: Verify installation
log_info "Step 13: Verifying installation..."
SERVICE_STATUS=$(systemctl is-active instagram-bot.service)

if [ "$SERVICE_STATUS" = "active" ]; then
    log_success "✅ Bot service is running successfully!"
    
    # Show quick logs
    echo ""
    echo "📊 Recent logs:"
    journalctl -u instagram-bot.service --no-pager -n 5
    
else
    log_error "❌ Service failed to start!"
    echo ""
    echo "🔍 Checking logs for errors..."
    journalctl -u instagram-bot.service --no-pager -n 20
fi

# Final instructions
echo ""
echo "=========================================="
echo "✅ INSTALLATION COMPLETE!"
echo "=========================================="
echo ""
echo "📁 Installation directory: $INSTALL_DIR"
echo "🔧 Config file: $INSTALL_DIR/config.py"
echo "🤖 Main script: $INSTALL_DIR/bot.py"
echo "📊 Log file: /var/log/instagram_bot.log"
echo ""
echo "⚡ QUICK COMMANDS:"
echo "  systemctl status instagram-bot      # Check status"
echo "  journalctl -u instagram-bot -f      # View live logs"
echo "  systemctl restart instagram-bot     # Restart bot"
echo "  systemctl stop instagram-bot        # Stop bot"
echo ""
echo "🔑 IMPORTANT:"
if [ -z "$RAPIDAPI_KEY" ]; then
    echo "⚠️  You didn't configure a RapidAPI key."
    echo "    For best results, get a free key from:"
    echo "    https://rapidapi.com/rockapi/api/instagram-scraper"
    echo "    Then edit: $INSTALL_DIR/config.py"
else
    echo "✅ RapidAPI key is configured."
fi
echo ""
echo "🤖 TELEGRAM USAGE:"
echo "1. Open Telegram"
echo "2. Find your bot"
echo "3. Send /start command"
echo "4. Send any Instagram link"
echo ""
echo "=========================================="
echo "Need help? Check logs: journalctl -u instagram-bot -n 50"
echo "=========================================="

# Test the bot token
echo ""
log_info "Testing bot connection..."
sleep 2
curl -s "https://api.telegram.org/bot${TELEGRAM_TOKEN}/getMe" | python3 -c "
import sys, json;
data = json.load(sys.stdin);
if data.get('ok'):
    print('✅ Bot is connected to Telegram!');
    print(f'🤖 Bot username: @{data[\"result\"][\"username\"]}');
else:
    print('❌ Bot connection failed!');
    print(f'Error: {data}');
"
