#!/bin/bash

# Simple Instagram Telegram Bot Installer
# For fresh Linux servers
# Run as root

echo "=========================================="
echo "Simple Instagram Bot Installer"
echo "=========================================="

# Update system
apt-get update
apt-get upgrade -y

# Install Python
apt-get install -y python3 python3-pip python3-venv git

# Create directory
mkdir -p /opt/instagram_bot
cd /opt/instagram_bot

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install requirements
pip install python-telegram-bot instaloader

# Create .env file
echo "Please enter your Telegram Bot Token from @BotFather:"
read -p "Token: " BOT_TOKEN

echo "TELEGRAM_BOT_TOKEN=$BOT_TOKEN" > .env

# Create bot.py
cat > bot.py << 'EOF'
#!/usr/bin/env python3
import os
import sys
import logging
import json
import tempfile
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes
import instaloader

# Setup logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# Get token
TOKEN = os.getenv('TELEGRAM_BOT_TOKEN')
if not TOKEN:
    print("ERROR: Bot token not found!")
    print("Please set TELEGRAM_BOT_TOKEN environment variable")
    sys.exit(1)

# Initialize instaloader
loader = instaloader.Instaloader(quiet=True)

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("🤖 Send me an Instagram link (post/reel/video) and I'll extract the content for you!")

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("📖 Just send me any Instagram link and I'll extract the text and information.")

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    text = update.message.text
    
    # Check if it's an Instagram link
    if 'instagram.com' not in text and 'instagr.am' not in text:
        await update.message.reply_text("❌ Please send a valid Instagram link")
        return
    
    await update.message.reply_text("⏳ Processing...")
    
    try:
        # Extract shortcode
        import re
        match = re.search(r'instagram\.com/(?:p|reel|tv)/([^/]+)', text)
        if not match:
            await update.message.reply_text("❌ Could not extract post ID from link")
            return
        
        shortcode = match.group(1)
        
        # Get post
        post = instaloader.Post.from_shortcode(loader.context, shortcode)
        
        # Prepare data
        data = {
            'url': f"https://instagram.com/p/{shortcode}",
            'username': post.owner_username,
            'caption': post.caption if post.caption else "No caption",
            'likes': post.likes,
            'comments': post.comments,
            'is_video': post.is_video,
            'timestamp': str(post.date_utc) if hasattr(post, 'date_utc') else None
        }
        
        # Send response
        response = f"""
📷 Instagram Post Info:

👤 Username: @{data['username']}
❤️ Likes: {data['likes']}
💬 Comments: {data['comments']}
🎥 Video: {'Yes' if data['is_video'] else 'No'}
📅 Date: {data['timestamp']}

📝 Caption:
{data['caption']}
        """
        
        await update.message.reply_text(response)
        
        # Send JSON file
        json_data = json.dumps(data, indent=2)
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            f.write(json_data)
            temp_file = f.name
        
        with open(temp_file, 'rb') as file:
            await update.message.reply_document(
                document=file,
                filename=f"instagram_{shortcode}.json",
                caption="📁 JSON file with all data"
            )
        
        os.unlink(temp_file)
        
    except Exception as e:
        logger.error(f"Error: {e}")
        await update.message.reply_text(f"❌ Error: {str(e)}")

def main():
    # Create application
    application = Application.builder().token(TOKEN).build()
    
    # Add handlers
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CommandHandler("help", help_command))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    
    # Start bot
    print("Starting bot...")
    application.run_polling()

if __name__ == '__main__':
    main()
EOF

# Make executable
chmod +x bot.py

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

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
systemctl daemon-reload
systemctl enable instagram-bot
systemctl start instagram-bot

echo ""
echo "=========================================="
echo "✅ Installation Complete!"
echo "=========================================="
echo ""
echo "Check status: systemctl status instagram-bot"
echo "View logs: journalctl -u instagram-bot -f"
echo ""
echo "Go to Telegram and send /start to your bot!"
