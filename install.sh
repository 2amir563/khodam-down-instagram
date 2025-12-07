#!/bin/bash

# Simple Working Instagram Bot Installer
# This will definitely work!

set -e

echo "=========================================="
echo "Simple Working Instagram Bot Installer"
echo "=========================================="

# Step 1: Install Python
apt-get update
apt-get install -y python3 python3-pip git

# Step 2: Create directory
INSTALL_DIR="/root/instagram_bot"
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# Step 3: Install requirements
pip3 install python-telegram-bot requests beautifulsoup4 lxml

# Step 4: Create the bot
cat > bot.py << 'EOF'
#!/usr/bin/env python3
"""
Simple Instagram Bot that actually works!
"""

import os
import sys
import json
import logging
import re
import time
from datetime import datetime

import requests
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes

# Setup logging to see what's happening
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('/tmp/instagram_bot_debug.log')
    ]
)
logger = logging.getLogger(__name__)

# Your Telegram Bot Token
TOKEN = "8502213708:AAud0o3wEjhWKNPqXjY5AoNIi6fEQiL4tf4"

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command"""
    logger.info(f"User {update.effective_user.id} sent /start")
    await update.message.reply_text(
        "🤖 *Instagram Bot is Working!*\n\n"
        "Send me any Instagram link and I'll extract the text content for you.\n\n"
        "Example links:\n"
        "• https://www.instagram.com/p/CvC9FkHNrJI/\n"
        "• https://instagram.com/reel/Cxample123\n\n"
        "_Just paste a link and see what happens!_",
        parse_mode='Markdown'
    )

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /help command"""
    await update.message.reply_text(
        "📖 *How to use:*\n"
        "1. Copy any Instagram link\n"
        "2. Paste it here\n"
        "3. I'll extract all text content\n\n"
        "That's it! Simple and effective.",
        parse_mode='Markdown'
    )

def extract_instagram_text(url):
    """Extract text from Instagram page"""
    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        }
        
        logger.info(f"Fetching URL: {url}")
        response = requests.get(url, headers=headers, timeout=15)
        html = response.text
        
        # Log first 500 chars of HTML to see what we got
        logger.info(f"HTML preview: {html[:500]}...")
        
        # Extract title
        title_match = re.search(r'<title[^>]*>(.*?)</title>', html, re.IGNORECASE | re.DOTALL)
        title = title_match.group(1).strip() if title_match else "No title found"
        
        # Try to find caption/description
        caption = "No caption found"
        
        # Method 1: Look for JSON-LD
        json_ld_match = re.search(r'<script type="application/ld\+json">(.*?)</script>', html, re.DOTALL)
        if json_ld_match:
            try:
                data = json.loads(json_ld_match.group(1))
                if 'description' in data:
                    caption = data['description']
                elif 'caption' in data:
                    caption = data['caption']
            except:
                pass
        
        # Method 2: Look for meta description
        if caption == "No caption found":
            meta_match = re.search(r'<meta[^>]*name="description"[^>]*content="([^"]*)"', html, re.IGNORECASE)
            if meta_match:
                caption = meta_match.group(1)
        
        # Method 3: Look for og:description
        if caption == "No caption found":
            og_match = re.search(r'<meta[^>]*property="og:description"[^>]*content="([^"]*)"', html, re.IGNORECASE)
            if og_match:
                caption = og_match.group(1)
        
        # Method 4: Extract all text (simple approach)
        if caption == "No caption found" or len(caption) < 20:
            # Remove scripts and styles
            html_clean = re.sub(r'<script[^>]*>.*?</script>', '', html, flags=re.DOTALL | re.IGNORECASE)
            html_clean = re.sub(r'<style[^>]*>.*?</style>', '', html_clean, flags=re.DOTALL | re.IGNORECASE)
            
            # Remove HTML tags
            text = re.sub(r'<[^>]+>', ' ', html_clean)
            
            # Clean up
            text = re.sub(r'\s+', ' ', text).strip()
            
            # Take first 1000 characters
            if len(text) > 100:
                caption = text[:1000] + ("..." if len(text) > 1000 else "")
        
        # Clean the caption
        caption = caption.replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>').replace('&quot;', '"').replace('&#39;', "'")
        
        return {
            'success': True,
            'url': url,
            'title': title,
            'caption': caption,
            'html_length': len(html),
            'caption_length': len(caption)
        }
        
    except Exception as e:
        logger.error(f"Error extracting text: {e}")
        return {
            'success': False,
            'error': str(e),
            'url': url
        }

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle incoming messages"""
    user_id = update.effective_user.id
    text = update.message.text.strip()
    
    logger.info(f"User {user_id} sent message: {text[:50]}")
    
    # Check if it's an Instagram link
    if 'instagram.com' not in text and 'instagr.am' not in text:
        await update.message.reply_text(
            "❌ *Not an Instagram link*\n\n"
            "Please send me an Instagram link like:\n"
            "• https://www.instagram.com/p/...\n"
            "• https://instagram.com/reel/...\n"
            "• https://instagram.com/tv/...",
            parse_mode='Markdown'
        )
        return
    
    # Send processing message
    msg = await update.message.reply_text("⏳ *Processing your link...*", parse_mode='Markdown')
    
    try:
        # Extract text
        result = extract_instagram_text(text)
        
        if not result['success']:
            await msg.edit_text(
                f"❌ *Failed to extract content*\n\n"
                f"Error: {result['error']}\n\n"
                f"Please try a different link.",
                parse_mode='Markdown'
            )
            return
        
        # Prepare response
        response = f"""
📷 *Instagram Content Extracted!*

🔗 *URL:* {result['url']}
📌 *Title:* {result['title'][:200]}

📝 *Text Content:*
{result['caption'][:3000]}{'...' if len(result['caption']) > 3000 else ''}

📊 *Stats:*
• Page size: {result['html_length']:,} characters
• Text extracted: {result['caption_length']:,} characters
• Time: {datetime.now().strftime('%H:%M:%S')}
        """
        
        await msg.edit_text(response, parse_mode='Markdown')
        
        # Send as JSON file
        try:
            import tempfile
            json_data = json.dumps(result, indent=2, ensure_ascii=False)
            
            with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False, encoding='utf-8') as f:
                f.write(json_data)
                temp_file = f.name
            
            with open(temp_file, 'rb') as f:
                await update.message.reply_document(
                    document=f,
                    filename="instagram_data.json",
                    caption="📁 JSON file with extracted data"
                )
            
            import os
            os.unlink(temp_file)
            
        except Exception as e:
            logger.error(f"Error sending JSON: {e}")
            # Don't worry if JSON fails
            
        logger.info(f"Successfully processed link for user {user_id}")
        
    except Exception as e:
        logger.error(f"Error in handle_message: {e}")
        await msg.edit_text(
            f"❌ *Error processing link*\n\n"
            f"Error: {str(e)[:200]}\n\n"
            f"Please try again.",
            parse_mode='Markdown'
        )

async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle errors"""
    logger.error(f"Bot error: {context.error}")
    try:
        await update.message.reply_text("❌ An error occurred. Please try again.")
    except:
        pass

def main():
    """Start the bot"""
    print("🤖 Starting Instagram Bot...")
    print(f"🔑 Token: {TOKEN[:10]}...")
    print("📝 Debug log: /tmp/instagram_bot_debug.log")
    print("=" * 50)
    
    try:
        # Create application
        application = Application.builder().token(TOKEN).build()
        
        # Add handlers
        application.add_handler(CommandHandler("start", start))
        application.add_handler(CommandHandler("help", help_command))
        application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
        
        # Add error handler
        application.add_error_handler(error_handler)
        
        # Start
        print("✅ Bot is running! Press Ctrl+C to stop.")
        print("=" * 50)
        
        application.run_polling(allowed_updates=Update.ALL_TYPES)
        
    except Exception as e:
        print(f"❌ Failed to start bot: {e}")
        logger.error(f"Failed to start bot: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF

# Step 5: Create startup script
cat > start_bot.sh << 'EOF'
#!/bin/bash
cd /root/instagram_bot
python3 bot.py
EOF

chmod +x start_bot.sh
chmod +x bot.py

# Step 6: Run the bot in screen session
echo "Starting bot in screen session..."
screen -dmS instagram_bot bash -c "cd /root/instagram_bot && python3 bot.py"

echo ""
echo "=========================================="
echo "✅ Bot installed and started!"
echo "=========================================="
echo ""
echo "To check if bot is running:"
echo "  screen -list"
echo ""
echo "To view bot output:"
echo "  screen -r instagram_bot"
echo ""
echo "To stop bot:"
echo "  1. screen -r instagram_bot"
echo "  2. Press Ctrl+C"
echo "  3. Type: exit"
echo ""
echo "Debug log:"
echo "  tail -f /tmp/instagram_bot_debug.log"
echo ""
echo "Now go to Telegram and send /start to your bot!"
echo "Bot token: 8502213708:AAud0o3wEjhWKNPqXjY5AoNIi6fEQiL4tf4"
echo ""
echo "Quick test command:"
echo "  curl -s 'https://api.telegram.org/bot8502213708:AAud0o3wEjhWKNPqXjY5AoNIi6fEQiL4tf4/getMe'"
echo ""
