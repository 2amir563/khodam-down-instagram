#!/bin/bash

# Instagram Telegram Bot - Complete Installation Script
# For fresh Linux servers
# GitHub: https://github.com/2amir563/khodam-down-instagram

set -e

echo "=========================================="
echo "Instagram Telegram Bot - Fresh Server Install"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    echo -e "${GREEN}[+]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[!]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_warning "Not running as root. Some operations might require sudo."
    print_warning "If you have issues, run: sudo su"
fi

# Step 1: System Update
print_status "Step 1/9: Updating system packages..."
apt-get update -y
apt-get upgrade -y

# Step 2: Install Basic Dependencies
print_status "Step 2/9: Installing basic dependencies..."
apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    git \
    curl \
    wget \
    nano \
    screen \
    htop \
    ufw \
    ca-certificates \
    gnupg \
    lsb-release

# Step 3: Install Python 3.9 if not available
print_status "Step 3/9: Ensuring Python 3.9+ is available..."
PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
echo "Current Python version: $PYTHON_VERSION"

# Check if Python version is sufficient
if [[ "$PYTHON_VERSION" < "3.9" ]]; then
    print_warning "Python version is below 3.9, installing Python 3.9..."
    apt-get install -y software-properties-common
    add-apt-repository -y ppa:deadsnakes/ppa
    apt-get update
    apt-get install -y python3.9 python3.9-venv python3.9-dev
    # Set python3 to point to python3.9
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1
fi

# Step 4: Create Project Directory
print_status "Step 4/9: Creating project directory..."
INSTALL_DIR="/opt/instagram_bot"
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# Step 5: Create Virtual Environment
print_status "Step 5/9: Creating Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Step 6: Install Python Packages
print_status "Step 6/9: Installing Python packages..."
pip install --upgrade pip setuptools wheel

# Create requirements.txt
cat > requirements.txt << 'EOF'
python-telegram-bot[job-queue]==20.7
instaloader==4.11.0
aiohttp==3.9.1
beautifulsoup4==4.12.2
requests==2.31.0
pillow==10.1.0
python-dotenv==1.0.0
EOF

pip install -r requirements.txt

# Verify installations
print_status "Verifying installations..."
python3 -c "import telegram; print('✓ python-telegram-bot installed')"
python3 -c "import instaloader; print('✓ instaloader installed')"
python3 -c "import aiohttp; print('✓ aiohttp installed')"

# Step 7: Create Bot Configuration File
print_status "Step 7/9: Creating bot configuration..."

# Get bot token
echo ""
echo "=========================================="
echo "BOT TOKEN SETUP"
echo "=========================================="
echo ""
echo "To get your Telegram Bot Token:"
echo "1. Open Telegram"
echo "2. Search for @BotFather"
echo "3. Send /newbot command"
echo "4. Follow instructions"
echo "5. Copy the token you receive"
echo ""
echo "Example token: 1234567890:ABCdefGHIjklMnOpQRstUVwxyz"
echo ""

while true; do
    read -p "Enter your Telegram Bot Token: " BOT_TOKEN
    
    if [[ -z "$BOT_TOKEN" ]]; then
        print_error "Token cannot be empty. Please try again."
        continue
    fi
    
    if [[ ! "$BOT_TOKEN" =~ ^[0-9]{8,10}:[a-zA-Z0-9_-]{35}$ ]]; then
        print_warning "Token format looks incorrect. Make sure it's like: 1234567890:ABCdefGHIjklMnOpQRstUVwxyz"
        read -p "Are you sure this is correct? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            break
        fi
    else
        break
    fi
done

# Create environment file
cat > .env << EOF
TELEGRAM_BOT_TOKEN=$BOT_TOKEN
LOG_LEVEL=INFO
MAX_RETRIES=3
TIMEOUT=30
EOF

chmod 600 .env

# Create bot.py
cat > bot.py << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Instagram Telegram Bot
Extracts content from Instagram links and sends as text + JSON file
"""

import os
import sys
import logging
import asyncio
import json
import tempfile
import re
from datetime import datetime
from pathlib import Path

# Third-party imports
from telegram import Update
from telegram.ext import (
    Application,
    CommandHandler,
    MessageHandler,
    filters,
    ContextTypes,
)
import instaloader
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
def setup_logging():
    """Setup comprehensive logging"""
    log_dir = Path("/var/log/instagram_bot")
    log_dir.mkdir(exist_ok=True)
    
    log_file = log_dir / "bot.log"
    
    logging.basicConfig(
        level=os.getenv('LOG_LEVEL', 'INFO'),
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_file, encoding='utf-8'),
            logging.StreamHandler(sys.stdout)
        ]
    )
    return logging.getLogger(__name__)

logger = setup_logging()

class InstagramExtractor:
    """Handles Instagram content extraction"""
    
    def __init__(self):
        """Initialize Instagram extractor"""
        try:
            self.loader = instaloader.Instaloader(
                quiet=True,
                download_pictures=False,
                download_videos=False,
                download_video_thumbnails=False,
                save_metadata=False,
                compress_json=False,
                max_connection_attempts=3
            )
            logger.info("Instagram extractor initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize Instagram extractor: {e}")
            raise
    
    def extract_shortcode(self, url: str) -> str:
        """Extract shortcode from Instagram URL"""
        patterns = [
            r'(?:https?://)?(?:www\.)?instagram\.com/(?:p|reel|tv)/([^/?#&]+)',
            r'(?:https?://)?(?:www\.)?instagram\.com/(?:p|reel|tv)/([^/?#&]+)/?',
            r'(?:https?://)?(?:www\.)?instagr\.am/(?:p|reel|tv)/([^/?#&]+)'
        ]
        
        for pattern in patterns:
            match = re.search(pattern, url, re.IGNORECASE)
            if match:
                return match.group(1)
        
        # Try to extract from any instagram URL
        if 'instagram.com' in url:
            parts = url.split('/')
            for i, part in enumerate(parts):
                if part in ['p', 'reel', 'tv'] and i + 1 < len(parts):
                    return parts[i + 1].split('?')[0]
        
        return None
    
    async def get_post_info(self, url: str):
        """Get post information from Instagram"""
        try:
            logger.info(f"Processing URL: {url}")
            
            # Clean URL
            url = url.strip()
            if not url.startswith('http'):
                url = 'https://' + url
            
            # Extract shortcode
            shortcode = self.extract_shortcode(url)
            if not shortcode:
                logger.error(f"Could not extract shortcode from URL: {url}")
                return None, "Invalid Instagram URL. Please send a valid post, reel, or video link."
            
            logger.info(f"Extracted shortcode: {shortcode}")
            
            # Get post using instaloader
            try:
                post = instaloader.Post.from_shortcode(self.loader.context, shortcode)
            except instaloader.exceptions.InstaloaderException as e:
                logger.error(f"Instaloader error: {e}")
                return None, f"Instagram error: {str(e)}"
            
            # Extract post data
            post_data = {
                'url': f"https://www.instagram.com/p/{shortcode}/",
                'shortcode': shortcode,
                'username': post.owner_username,
                'user_id': post.owner_id,
                'caption': post.caption if post.caption else "No caption",
                'caption_hashtags': post.caption_hashtags,
                'caption_mentions': post.caption_mentions,
                'likes': post.likes,
                'comments': post.comments,
                'timestamp': post.date_utc.isoformat() if hasattr(post, 'date_utc') else None,
                'is_video': post.is_video,
                'video_duration': post.video_duration if post.is_video else None,
                'video_view_count': post.video_view_count if post.is_video else None,
                'media_count': post.mediacount,
                'media_urls': [],
                'thumbnail_url': post.url if not post.is_video else post.video_url
            }
            
            # Get media URLs
            if post.mediacount > 1:
                # Sidecar post (multiple media)
                for node in post.get_sidecar_nodes():
                    if node.is_video:
                        post_data['media_urls'].append({
                            'type': 'video',
                            'url': node.video_url,
                            'thumbnail': node.display_url
                        })
                    else:
                        post_data['media_urls'].append({
                            'type': 'image',
                            'url': node.display_url
                        })
            else:
                # Single media post
                if post.is_video:
                    post_data['media_urls'].append({
                        'type': 'video',
                        'url': post.video_url,
                        'thumbnail': post.url
                    })
                else:
                    post_data['media_urls'].append({
                        'type': 'image',
                        'url': post.url
                    })
            
            logger.info(f"Successfully extracted data for post: {shortcode}")
            return post_data, None
            
        except Exception as e:
            logger.error(f"Error getting post info: {e}", exc_info=True)
            return None, f"Error processing Instagram link: {str(e)}"

class TelegramBot:
    """Main Telegram bot class"""
    
    def __init__(self, token: str):
        """Initialize Telegram bot"""
        self.token = token
        self.extractor = InstagramExtractor()
        
        # Create bot application
        self.application = Application.builder().token(token).build()
        
        # Add handlers
        self.setup_handlers()
        
        logger.info("Telegram bot initialized")
    
    def setup_handlers(self):
        """Setup bot command and message handlers"""
        
        # Command handlers
        self.application.add_handler(CommandHandler("start", self.start_command))
        self.application.add_handler(CommandHandler("help", self.help_command))
        self.application.add_handler(CommandHandler("status", self.status_command))
        
        # Message handler for Instagram links
        self.application.add_handler(MessageHandler(
            filters.TEXT & ~filters.COMMAND,
            self.handle_message
        ))
        
        # Error handler
        self.application.add_error_handler(self.error_handler)
    
    async def start_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Handle /start command"""
        welcome_text = """
🌟 *Instagram Content Extractor Bot* 🌟

Send me any Instagram link (post, reel, or video) and I'll extract all the text content and media information for you!

📋 *Available Commands:*
/start - Show this welcome message
/help - Show detailed help
/status - Check bot status

🔗 *Supported Links:*
• Posts: https://instagram.com/p/XXXXX
• Reels: https://instagram.com/reel/XXXXX
• Videos: https://instagram.com/tv/XXXXX

⚠️ *Note:* Only public content can be extracted.
        """
        await update.message.reply_text(welcome_text, parse_mode='Markdown')
        logger.info(f"User {update.effective_user.id} started the bot")
    
    async def help_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Handle /help command"""
        help_text = """
📖 *How to Use This Bot*

1. *Send an Instagram Link*
   Just copy and paste any Instagram link to the bot.

2. *What I Extract:*
   • Post caption/text
   • Username and user ID
   • Likes and comments count
   • Post date and time
   • Media information
   • Video duration (if video)
   • All media URLs

3. *What You Receive:*
   • Formatted text summary
   • JSON file with complete data

4. *Examples of Supported Links:*
