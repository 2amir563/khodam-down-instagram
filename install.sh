#!/bin/bash

# Telegram Instagram Video/Photo Downloader Bot Installer
# Fixed Callback Data Version

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
    echo "   INSTAGRAM DOWNLOADER BOT - FIXED VERSION"
    echo "   CALLBACK DATA LIMIT ISSUE RESOLVED"
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
        apt install -y python3 python3-pip python3-venv git curl wget nano jq ffmpeg
    elif command -v yum &> /dev/null; then
        yum install -y python3 python3-pip git curl wget nano jq ffmpeg
    elif command -v dnf &> /dev/null; then
        dnf install -y python3 python3-pip git curl wget nano jq ffmpeg
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
    pip3 install python-telegram-bot==20.7 yt-dlp requests
    
    print_success "Python packages installed"
}

# Create bot directory
create_bot_dir() {
    print_info "Creating bot directory..."
    
    rm -rf /opt/instagram_bot
    mkdir -p /opt/instagram_bot
    cd /opt/instagram_bot
    
    # Create necessary directories
    mkdir -p downloads temp logs
    
    print_success "Directory created: /opt/instagram_bot"
}

# Create fixed bot.py script
create_bot_script() {
    print_info "Creating fixed Instagram bot script..."
    
    cat > /opt/instagram_bot/bot.py << 'BOTEOF'
#!/usr/bin/env python3
"""
Instagram Downloader Bot with Fixed Callback Data Issue
"""

import os
import json
import logging
import subprocess
import re
import asyncio
import hashlib
from datetime import datetime
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes, CallbackQueryHandler
from typing import Dict, List, Tuple, Optional
import tempfile

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

# User data storage with session management
user_sessions: Dict[int, Dict] = {}
url_to_id: Dict[str, str] = {}
id_counter = 0

def get_url_id(url: str) -> str:
    """Generate a short ID for URL to avoid long callback data"""
    global id_counter
    if url not in url_to_id:
        # Generate hash for URL
        url_hash = hashlib.md5(url.encode()).hexdigest()[:8]
        url_to_id[url] = f"{id_counter:04d}_{url_hash}"
        id_counter += 1
    return url_to_id[url]

def get_url_from_id(url_id: str) -> Optional[str]:
    """Get URL from stored ID"""
    for url, stored_id in url_to_id.items():
        if stored_id == url_id:
            return url
    return None

def is_instagram_url(url: str) -> bool:
    """Check if URL is from Instagram"""
    patterns = [
        r'(https?://)?(www\.)?instagram\.com/p/',
        r'(https?://)?(www\.)?instagram\.com/reel/',
        r'(https?://)?(www\.)?instagram\.com/tv/',
        r'(https?://)?(www\.)?instagram\.com/stories/',
    ]
    
    url_lower = url.lower()
    for pattern in patterns:
        if re.search(pattern, url_lower):
            return True
    return False

def format_size(bytes_size: int) -> str:
    """Format bytes to human readable size"""
    if bytes_size == 0:
        return "N/A"
    
    for unit in ['B', 'KB', 'MB', 'GB']:
        if bytes_size < 1024.0:
            return f"{bytes_size:.1f} {unit}"
        bytes_size /= 1024.0
    return f"{bytes_size:.1f} TB"

def get_instagram_media_info(url: str) -> Tuple[List[Dict], Dict]:
    """
    Get available media formats for an Instagram post
    Returns: (formats_list, media_info)
    """
    try:
        # Clean and validate URL
        if not url.startswith(('http://', 'https://')):
            url = 'https://' + url
        
        logger.info(f"Getting media info for URL: {url[:100]}...")
        
        # Create a temporary file for JSON output
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as tmp:
            tmp_path = tmp.name
        
        try:
            # Try using yt-dlp for Instagram
            cmd = [
                'yt-dlp',
                '--dump-json',
                '--no-warnings',
                '--skip-download',
                '--no-check-certificate',
                '--socket-timeout', '30',
                '--retries', '2',
                '-o', tmp_path,
                url
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            
            if result.returncode == 0:
                # Read the JSON output
                with open(tmp_path, 'r') as f:
                    output = f.read()
                
                if output:
                    return parse_ytdlp_output(output, url)
            
            logger.warning(f"yt-dlp failed, trying with cookies: {result.stderr[:200]}")
            
            # Try with cookies from browser
            cmd = [
                'yt-dlp',
                '--dump-json',
                '--no-warnings',
                '--skip-download',
                '--cookies-from-browser', 'chrome',
                '--no-check-certificate',
                '-o', tmp_path,
                url
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            
            if result.returncode == 0:
                with open(tmp_path, 'r') as f:
                    output = f.read()
                
                if output:
                    return parse_ytdlp_output(output, url)
            
            return [], {}
            
        finally:
            # Clean up temporary file
            try:
                os.unlink(tmp_path)
            except:
                pass
                
    except Exception as e:
        logger.error(f"Error getting media info: {str(e)}")
        return [], {}

def parse_ytdlp_output(output: str, url: str) -> Tuple[List[Dict], Dict]:
    """Parse yt-dlp output for Instagram media"""
    try:
        media_info = json.loads(output)
        
        formats = []
        
        # Extract available formats
        for fmt in media_info.get('formats', []):
            format_id = fmt.get('format_id', '')
            ext = fmt.get('ext', '')
            vcodec = fmt.get('vcodec', 'none')
            acodec = fmt.get('acodec', 'none')
            
            # Calculate file size
            filesize = fmt.get('filesize')
            filesize_approx = fmt.get('filesize_approx')
            
            if filesize:
                size = filesize
            elif filesize_approx:
                size = filesize_approx
            else:
                size = 0
            
            # Determine media type
            if vcodec != 'none' and acodec != 'none':
                media_type = 'video'
                icon = '🎬'
            elif vcodec != 'none':
                media_type = 'video_only'
                icon = '📹'
            elif acodec != 'none':
                media_type = 'audio'
                icon = '🎵'
            else:
                media_type = 'photo'
                icon = '📸'
            
            # Get resolution
            height = fmt.get('height')
            width = fmt.get('width')
            
            if height and width:
                resolution = f"{width}x{height}"
            elif height:
                resolution = f"{height}p"
            else:
                resolution = fmt.get('format_note', 'Photo')
            
            # Get fps
            fps = fmt.get('fps')
            fps_str = f"{int(fps)}fps" if fps else ""
            
            format_data = {
                'id': format_id,
                'ext': ext.upper(),
                'resolution': resolution,
                'fps': fps_str,
                'size': size,
                'type': media_type,
                'icon': icon,
                'height': height,
                'width': width,
                'quality': fmt.get('quality', 0)
            }
            
            formats.append(format_data)
        
        # Remove duplicates and sort
        unique_formats = {}
        for fmt in formats:
            key = (fmt['resolution'], fmt['ext'], fmt['type'])
            if key not in unique_formats or fmt['size'] > unique_formats[key]['size']:
                unique_formats[key] = fmt
        
        formats = list(unique_formats.values())
        
        # Sort by type and quality
        def sort_key(fmt):
            type_order = {'photo': 0, 'video': 1, 'video_only': 2, 'audio': 3}
            return (type_order.get(fmt['type'], 4), -fmt.get('height', 0), -fmt.get('quality', 0))
        
        formats.sort(key=sort_key)
        
        # Extract media info
        info = {
            'title': media_info.get('title', 'Instagram Media')[:200],
            'description': media_info.get('description', '')[:300],
            'uploader': media_info.get('uploader', 'Instagram User')[:100],
            'duration': media_info.get('duration', 0),
            'view_count': media_info.get('view_count', 0),
            'like_count': media_info.get('like_count', 0),
            'timestamp': media_info.get('timestamp', 0),
            'thumbnail': media_info.get('thumbnail', ''),
            'webpage_url': url
        }
        
        return formats, info
        
    except json.JSONDecodeError as e:
        logger.error(f"JSON decode error: {e}")
        return [], {}

def create_media_keyboard(formats: List[Dict], url_id: str, page: int = 0) -> InlineKeyboardMarkup:
    """Create keyboard with media options - using short URL ID"""
    items_per_page = 6  # Reduced for safety
    start_idx = page * items_per_page
    end_idx = start_idx + items_per_page
    
    keyboard = []
    
    # Add formats for current page
    for fmt in formats[start_idx:end_idx]:
        format_id = fmt['id']
        resolution = fmt['resolution']
        ext = fmt['ext']
        size = format_size(fmt['size'])
        icon = fmt['icon']
        media_type = fmt['type']
        
        # Create button text (shorter)
        button_text = f"{icon} {resolution}"
        
        if size != "N/A":
            button_text += f" - {size}"
        
        # Ensure button text is not too long
        if len(button_text) > 30:
            button_text = button_text[:27] + "..."
        
        # Short callback data
        callback_data = f"dl:{format_id}:{url_id}:{media_type[:3]}:{page}"
        
        # Ensure callback data is within Telegram limits (max 64 bytes)
        if len(callback_data.encode()) > 60:
            # Truncate format_id if necessary
            format_id_short = format_id[:10]
            callback_data = f"dl:{format_id_short}:{url_id}:{media_type[:1]}:{page}"
        
        keyboard.append([InlineKeyboardButton(button_text, callback_data=callback_data)])
    
    # Add navigation buttons if needed
    nav_buttons = []
    
    if page > 0:
        nav_buttons.append(InlineKeyboardButton("⬅️", callback_data=f"nav:{page-1}:{url_id}"))
    
    if end_idx < len(formats):
        nav_buttons.append(InlineKeyboardButton("➡️", callback_data=f"nav:{page+1}:{url_id}"))
    
    if nav_buttons:
        keyboard.append(nav_buttons)
    
    # Add quick action buttons with short callback data
    keyboard.append([
        InlineKeyboardButton("🎯 Best", callback_data=f"bst:{url_id}"),
        InlineKeyboardButton("📸 Photo", callback_data=f"pho:{url_id}")
    ])
    
    keyboard.append([InlineKeyboardButton("❌ Cancel", callback_data="cancel")])
    
    return InlineKeyboardMarkup(keyboard)

def create_caption(media_info: Dict, file_size: str, quality: str = "") -> str:
    """Create caption for media"""
    title = media_info.get('title', 'Instagram Media')
    uploader = media_info.get('uploader', 'Instagram User')
    description = media_info.get('description', '')
    timestamp = media_info.get('timestamp', 0)
    
    # Format date
    if timestamp:
        date_str = datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d')
    else:
        date_str = ""
    
    # Truncate description if too long
    if len(description) > 150:
        description = description[:147] + "..."
    
    # Create caption
    caption = f"📱 *{title}*\n\n"
    
    if uploader and uploader != 'Instagram User':
        caption += f"👤 *Posted by:* {uploader}\n"
    
    if quality:
        caption += f"📊 *Quality:* {quality}\n"
    
    caption += f"📦 *Size:* {file_size}\n"
    
    if date_str:
        caption += f"📅 *Posted:* {date_str}\n"
    
    if description:
        caption += f"\n📝 *Description:*\n{description}\n"
    
    caption += f"\n✅ Downloaded via @InstagramDownloaderBot"
    
    # Ensure caption is within Telegram limits
    if len(caption) > 1024:
        caption = caption[:1020] + "..."
    
    return caption

async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command"""
    user = update.effective_user
    
    text = f"""
📱 *Instagram Downloader Bot*

👋 Hello {user.first_name}!

I can download photos and videos from Instagram.

✨ *Features:*
• Download Instagram posts
• Download Instagram Reels
• Download Instagram Stories
• Multiple quality options
• See file sizes before download

📌 *How to use:*
1. Send me an Instagram link
2. I'll show available formats
3. Select your preferred quality
4. Receive your file

🔗 *Supported URLs:*
• instagram.com/p/... (Posts)
• instagram.com/reel/... (Reels)
• instagram.com/tv/... (IGTV)
• instagram.com/stories/... (Stories)

⚡ *Commands:*
/start - Show this message
/help - Help information
    """
    
    await update.message.reply_text(text, parse_mode='Markdown')

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /help command"""
    text = """
🤖 *Instagram Bot Help*

📌 *How to download:*
1. Send an Instagram link
2. I'll analyze available formats
3. Choose quality from list
4. Wait for download
5. Receive your file

🎯 *Media Types:*
• 📸 Photos
• 🎬 Videos
• 📹 Video only
• 🎵 Audio only

📊 *File Sizes:*
All formats show estimated file size

⚡ *Quick Actions:*
• 🎯 Best - Download best quality
• 📸 Photo - Download photo only

⚠️ *Notes:*
• Max file size: 2GB
• Public posts only
• May not work with private accounts
    """
    
    await update.message.reply_text(text, parse_mode='Markdown')

async def show_formats(update: Update, context: ContextTypes.DEFAULT_TYPE, url: str):
    """Show available formats for a URL"""
    if not is_instagram_url(url):
        if update.message:
            await update.message.reply_text("❌ Please send a valid Instagram URL")
        return
    
    message = None
    if update.message:
        message = await update.message.reply_text("🔍 Analyzing Instagram media...")
    elif update.callback_query:
        message = await update.callback_query.message.reply_text("🔍 Analyzing Instagram media...")
    
    try:
        # Clean URL
        if not url.startswith(('http://', 'https://')):
            url = 'https://' + url
        
        formats, media_info = get_instagram_media_info(url)
        
        if not formats:
            await message.edit_text("❌ No formats found. Make sure the Instagram post is public.")
            return
        
        # Generate short URL ID
        url_id = get_url_id(url)
        
        # Store in user session
        user_id = update.effective_user.id
        user_sessions[user_id] = {
            'url': url,
            'formats': formats,
            'media_info': media_info,
            'url_id': url_id
        }
        
        # Create info message
        title = media_info.get('title', 'Instagram Media')[:80]
        uploader = media_info.get('uploader', 'Instagram User')[:40]
        
        # Count media types
        photo_count = sum(1 for f in formats if f['type'] == 'photo')
        video_count = sum(1 for f in formats if f['type'] == 'video')
        
        info_text = f"""
📱 *Media Analysis Complete!*

📄 *Title:* {title}
👤 *Posted by:* {uploader}
🔢 *Formats:* {len(formats)} total
📸 *Photos:* {photo_count} | 🎬 *Videos:* {video_count}

*Select your preferred quality:*
        """
        
        # Create keyboard with short URL ID
        keyboard = create_media_keyboard(formats, url_id, 0)
        
        await message.edit_text(info_text, parse_mode='Markdown', reply_markup=keyboard)
        
    except Exception as e:
        logger.error(f"Error in show_formats: {e}")
        await message.edit_text(f"❌ Error: {str(e)[:150]}")

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle incoming messages"""
    message = update.message
    url = message.text.strip()
    
    if not is_instagram_url(url):
        await message.reply_text("❌ Please send a valid Instagram URL")
        return
    
    await show_formats(update, context, url)

async def handle_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle callback queries"""
    query = update.callback_query
    await query.answer()
    
    callback_data = query.data
    user_id = query.from_user.id
    
    logger.info(f"Callback received: {callback_data}")
    
    # Handle cancel
    if callback_data == "cancel":
        await query.edit_message_text("❌ Cancelled")
        return
    
    # Handle navigation
    if callback_data.startswith('nav:'):
        try:
            _, page_str, url_id = callback_data.split(':', 2)
            page = int(page_str)
            
            # Get URL from ID
            url = get_url_from_id(url_id)
            if not url:
                await query.edit_message_text("❌ Session expired. Please send the link again.")
                return
            
            # Get formats
            formats, _ = get_instagram_media_info(url)
            
            if not formats:
                await query.edit_message_text("❌ No formats found")
                return
            
            keyboard = create_media_keyboard(formats, url_id, page)
            await query.edit_message_reply_markup(reply_markup=keyboard)
        except Exception as e:
            logger.error(f"Navigation error: {e}")
            await query.edit_message_text("❌ Error")
        return
    
    # Handle best quality
    elif callback_data.startswith('bst:'):
        try:
            _, url_id = callback_data.split(':', 1)
            url = get_url_from_id(url_id)
            if not url:
                await query.edit_message_text("❌ Session expired")
                return
            
            await download_best(query, context, url)
        except Exception as e:
            logger.error(f"Best quality error: {e}")
            await query.edit_message_text("❌ Error")
        return
    
    # Handle photo only
    elif callback_data.startswith('pho:'):
        try:
            _, url_id = callback_data.split(':', 1)
            url = get_url_from_id(url_id)
            if not url:
                await query.edit_message_text("❌ Session expired")
                return
            
            await download_photo(query, context, url)
        except Exception as e:
            logger.error(f"Photo error: {e}")
            await query.edit_message_text("❌ Error")
        return
    
    # Handle format selection
    elif callback_data.startswith('dl:'):
        try:
            parts = callback_data.split(':')
            if len(parts) >= 4:
                format_id = parts[1]
                url_id = parts[2]
                media_type = parts[3]
                
                url = get_url_from_id(url_id)
                if not url:
                    await query.edit_message_text("❌ Session expired")
                    return
                
                await download_media(query, context, url, format_id, media_type)
            else:
                await query.edit_message_text("❌ Invalid selection")
        except Exception as e:
            logger.error(f"Download error: {e}")
            await query.edit_message_text("❌ Error")
        return
    
    else:
        await query.edit_message_text("❌ Invalid action")

async def download_media(query, context, url: str, format_id: str, media_type: str):
    """Download specific media format"""
    user_id = query.from_user.id
    message = query.message
    
    # Update message
    await message.edit_text("⬇️ Downloading...")
    
    try:
        # Get media info for caption
        formats, media_info = get_instagram_media_info(url)
        
        # Find the specific format
        selected_format = None
        for fmt in formats:
            if fmt['id'].startswith(format_id) or format_id.startswith(fmt['id']):
                selected_format = fmt
                break
        
        if not selected_format:
            # Try with best format
            format_id = 'best'
        
        # Create download directory
        os.makedirs('/opt/instagram_bot/downloads', exist_ok=True)
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"{timestamp}_{user_id}"
        
        # Download using yt-dlp with timeout
        cmd = [
            'timeout', '300', 'yt-dlp',
            '-f', format_id,
            '-o', f'/opt/instagram_bot/downloads/{filename}.%(ext)s',
            '--no-warnings',
            '--no-check-certificate',
            '--socket-timeout', '30',
            '--retries', '2',
            url
        ]
        
        logger.info(f"Downloading {url[:50]}...")
        
        # Start download
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        stdout, stderr = await process.communicate()
        
        if process.returncode != 0:
            error_msg = stderr.decode()[:200]
            logger.error(f"Download failed: {error_msg}")
            
            # Try with best format
            cmd = [
                'timeout', '300', 'yt-dlp',
                '-f', 'best',
                '-o', f'/opt/instagram_bot/downloads/{filename}.%(ext)s',
                '--no-warnings',
                url
            ]
            
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await process.communicate()
            
            if process.returncode != 0:
                await message.edit_text("❌ Download failed. Try another link.")
                return
        
        # Find downloaded file
        downloaded_files = []
        for file in os.listdir('/opt/instagram_bot/downloads'):
            if file.startswith(filename):
                file_path = f'/opt/instagram_bot/downloads/{file}'
                if os.path.exists(file_path):
                    downloaded_files.append(file_path)
        
        if not downloaded_files:
            await message.edit_text("❌ File not found after download")
            return
        
        file_path = downloaded_files[0]
        file_size = os.path.getsize(file_path)
        
        # Check file size
        if file_size > 2000 * 1024 * 1024:
            await message.edit_text("❌ File too large for Telegram")
            os.remove(file_path)
            return
        
        # Create caption
        quality = "Best" if format_id == 'best' else selected_format['resolution'] if selected_format else "Standard"
        caption = create_caption(media_info, format_size(file_size), quality)
        
        # Send file based on type
        with open(file_path, 'rb') as f:
            if file_path.endswith(('.jpg', '.jpeg', '.png', '.webp')):
                await context.bot.send_photo(
                    chat_id=user_id,
                    photo=f,
                    caption=caption,
                    parse_mode='Markdown'
                )
            elif file_path.endswith(('.mp4', '.mkv', '.webm')):
                await context.bot.send_video(
                    chat_id=user_id,
                    video=f,
                    caption=caption,
                    parse_mode='Markdown',
                    supports_streaming=True
                )
            else:
                await context.bot.send_document(
                    chat_id=user_id,
                    document=f,
                    caption=caption,
                    parse_mode='Markdown'
                )
        
        # Cleanup
        try:
            os.remove(file_path)
        except:
            pass
        
        await message.edit_text(f"✅ Download complete! ({format_size(file_size)})")
        
    except Exception as e:
        logger.error(f"Download error: {str(e)}")
        await message.edit_text(f"❌ Error: {str(e)[:150]}")

async def download_best(query, context, url: str):
    """Download best quality"""
    user_id = query.from_user.id
    message = query.message
    
    await message.edit_text("🎯 Downloading best quality...")
    
    try:
        # Get media info for caption
        formats, media_info = get_instagram_media_info(url)
        
        # Create download directory
        os.makedirs('/opt/instagram_bot/downloads', exist_ok=True)
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"{timestamp}_{user_id}"
        
        # Download best quality
        cmd = [
            'timeout', '300', 'yt-dlp',
            '-f', 'best',
            '-o', f'/opt/instagram_bot/downloads/{filename}.%(ext)s',
            '--no-warnings',
            '--no-check-certificate',
            url
        ]
        
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        stdout, stderr = await process.communicate()
        
        if process.returncode != 0:
            await message.edit_text("❌ Download failed")
            return
        
        # Send file
        file_path = None
        for file in os.listdir('/opt/instagram_bot/downloads'):
            if file.startswith(filename):
                file_path = f'/opt/instagram_bot/downloads/{file}'
                break
        
        if file_path and os.path.exists(file_path):
            file_size = os.path.getsize(file_path)
            
            # Check file size
            if file_size > 2000 * 1024 * 1024:
                await message.edit_text("❌ File too large")
                os.remove(file_path)
                return
            
            # Create caption
            caption = create_caption(media_info, format_size(file_size), "Best Quality")
            
            with open(file_path, 'rb') as f:
                if file_path.endswith(('.jpg', '.jpeg', '.png', '.webp')):
                    await context.bot.send_photo(
                        chat_id=user_id,
                        photo=f,
                        caption=caption,
                        parse_mode='Markdown'
                    )
                else:
                    await context.bot.send_video(
                        chat_id=user_id,
                        video=f,
                        caption=caption,
                        parse_mode='Markdown',
                        supports_streaming=True
                    )
            
            try:
                os.remove(file_path)
            except:
                pass
            
            await message.edit_text(f"✅ Download complete! ({format_size(file_size)})")
        else:
            await message.edit_text("❌ File not found")
        
    except Exception as e:
        logger.error(f"Best quality error: {str(e)}")
        await message.edit_text(f"❌ Error: {str(e)[:150]}")

async def download_photo(query, context, url: str):
    """Download photo only"""
    user_id = query.from_user.id
    message = query.message
    
    await message.edit_text("📸 Downloading photo...")
    
    try:
        # Get media info for caption
        formats, media_info = get_instagram_media_info(url)
        
        # Create download directory
        os.makedirs('/opt/instagram_bot/downloads', exist_ok=True)
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"{timestamp}_{user_id}"
        
        # Try to download best photo
        cmd = [
            'timeout', '300', 'yt-dlp',
            '-f', 'best[ext=jpg]/best[ext=jpeg]/best[ext=png]',
            '-o', f'/opt/instagram_bot/downloads/{filename}.%(ext)s',
            '--no-warnings',
            '--no-check-certificate',
            url
        ]
        
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        stdout, stderr = await process.communicate()
        
        if process.returncode != 0:
            await message.edit_text("❌ Download failed")
            return
        
        # Send file
        file_path = None
        for ext in ['.jpg', '.jpeg', '.png', '.webp']:
            test_path = f'/opt/instagram_bot/downloads/{filename}{ext}'
            if os.path.exists(test_path):
                file_path = test_path
                break
        
        if file_path and os.path.exists(file_path):
            file_size = os.path.getsize(file_path)
            
            # Create caption
            caption = create_caption(media_info, format_size(file_size), "Photo")
            
            with open(file_path, 'rb') as f:
                await context.bot.send_photo(
                    chat_id=user_id,
                    photo=f,
                    caption=caption,
                    parse_mode='Markdown'
                )
            
            try:
                os.remove(file_path)
            except:
                pass
            
            await message.edit_text(f"✅ Download complete! ({format_size(file_size)})")
        else:
            await message.edit_text("❌ Photo not found")
        
    except Exception as e:
        logger.error(f"Photo error: {str(e)}")
        await message.edit_text(f"❌ Error: {str(e)[:150]}")

async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle errors"""
    logger.error(f"Error: {context.error}")
    
    try:
        if update.callback_query:
            await update.callback_query.message.reply_text("⚠️ An error occurred. Please try again.")
        elif update.message:
            await update.message.reply_text("⚠️ An error occurred. Please try again.")
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
    
    app.run_polling()

if __name__ == '__main__':
    main()
BOTEOF
    
    chmod +x /opt/instagram_bot/bot.py
    print_success "Fixed Instagram bot script created"
}

# Create environment file
create_env_file() {
    print_info "Creating environment file..."
    
    cat > /opt/instagram_bot/.env.example << ENVEOF
# Telegram Bot Token from @BotFather
# Example: 1234567890:ABCdefGhIJKlmNoPQRsTUVwxyZ
BOT_TOKEN=your_bot_token_here

# Maximum file size in bytes (Telegram limit is 2GB)
MAX_FILE_SIZE=2000000000

# Allowed user IDs (comma separated)
# Leave empty to allow all users
ALLOWED_USERS=

# Download directory
DOWNLOAD_DIR=/opt/instagram_bot/downloads

# Temp directory
TEMP_DIR=/tmp/instagram_bot
ENVEOF
    
    print_success "Environment file created"
}

# Create service file
create_service_file() {
    print_info "Creating systemd service..."
    
    cat > /etc/systemd/system/instagram-bot.service << SERVICEEOF
[Unit]
Description=Instagram Downloader Bot - Fixed Callback Data
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
        pip3 install --upgrade pip python-telegram-bot yt-dlp
        
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
        python3 -c "import telegram, yt_dlp, json; print('✅ Python packages OK')"
        
        echo ""
        echo "2. Testing yt-dlp..."
        yt-dlp --version
        
        echo ""
        echo "3. Testing service..."
        systemctl is-active instagram-bot &>/dev/null && echo "✅ Service is running" || echo "⚠️ Service is not running"
        
        echo ""
        echo "4. Testing directories..."
        ls -la /opt/instagram_bot/
        
        echo ""
        echo "✅ All tests completed"
        ;;
    clean)
        echo "🧹 Cleaning downloads..."
        rm -rf /opt/instagram_bot/downloads/*
        rm -rf /opt/instagram_bot/temp/*
        echo "✅ Cleaned downloads and temp"
        ;;
    backup)
        echo "💾 Backing up bot..."
        BACKUP_DIR="/opt/instagram_bot_backup_\$(date +%Y%m%d_%H%M%S)"
        mkdir -p "\$BACKUP_DIR"
        cp -r /opt/instagram_bot/* "\$BACKUP_DIR"/
        echo "✅ Backup created: \$BACKUP_DIR"
        ;;
    stats)
        echo "📊 Bot Statistics:"
        echo ""
        echo "Downloads folder:"
        du -sh /opt/instagram_bot/downloads
        echo ""
        echo "Log file size:"
        du -sh /opt/instagram_bot/logs/* 2>/dev/null || echo "No logs yet"
        echo ""
        echo "Service status:"
        systemctl status instagram-bot --no-pager -l | grep -A 3 "Active:"
        ;;
    *)
        echo "🤖 Instagram Downloader Bot"
        echo "Version: 1.1 | Fixed Callback Data Issue"
        echo ""
        echo "Usage: \$0 {start|stop|restart|status|logs|setup|config|update|test|clean|backup|stats}"
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
        echo "  backup    - Create backup"
        echo "  stats     - Show statistics"
        echo ""
        echo "Quick Start:"
        echo "  1. instagram-bot setup"
        echo "  2. instagram-bot config  (add your token)"
        echo "  3. instagram-bot start"
        echo "  4. instagram-bot logs -f"
        echo ""
        echo "Features:"
        echo "  • Instagram posts, reels, stories"
        echo "  • Fixed callback data limit issue"
        echo "  • Quality selection"
        echo "  • Photo and video support"
        echo "  • Captions with media info"
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
    echo "   • Copy token (looks like: 1234567890:ABCdefGhIJKlmNoPQRsTUVwxyZ)"
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
    echo "6. ${GREEN}Monitor logs:${NC}"
    echo "   instagram-bot logs -f"
    echo ""
    
    echo -e "${YELLOW}🔧 FIXED ISSUES:${NC}"
    echo "• ${GREEN}Button_data_invalid error${NC} - Callback data now within Telegram limits"
    echo "• ${GREEN}Short URL IDs${NC} - Using hash instead of full URLs"
    echo "• ${GREEN}Simplified callback data${NC} - Shorter format identifiers"
    echo "• ${GREEN}Timeout protection${NC} - Prevents hanging downloads"
    echo ""
    
    echo -e "${YELLOW}⚡ QUICK START:${NC}"
    echo "1. Send Instagram link to bot"
    echo "2. Bot shows available formats"
    echo "3. Select quality"
    echo "4. Bot downloads and sends file"
    echo ""
    
    echo -e "${GREEN}✅ Bot is ready! Start with 'instagram-bot start'${NC}"
    echo ""
    
    echo -e "${CYAN}📞 SUPPORT:${NC}"
    echo "View logs: instagram-bot logs"
    echo "Check status: instagram-bot status"
    echo "Update bot: instagram-bot update"
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
