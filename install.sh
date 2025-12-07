#!/bin/bash

# --- Section 1: Configuration ---
echo "## 🤖 Instagram Downloader Bot (With Caption) - Auto Setup (V20+ Fix) ##"
echo "---"

# Get Bot Token from user
read -p "Please enter your Telegram bot token (e.g., 123456:ABC-DEF): " BOT_TOKEN

# --- Section 2: Install Prerequisites and VENV Setup ---
echo "---"
echo "🛠️ Installing system prerequisites (Python3, pip, venv, dev tools)..."

# Install Python3, pip, venv and dev tools for compilation (improving instaloader robustness)
sudo apt update > /dev/null 2>&1
sudo apt install -y python3 python3-pip python3-venv git python3-dev > /dev/null 2>&1

# Create and activate a virtual environment (VENV) for reliable dependency handling
echo "⚙️ Setting up virtual environment..."
python3 -m venv bot_env
source bot_env/bin/activate

# --- Section 3: Install Libraries inside VENV ---
echo "📚 Installing Python libraries (instaloader and python-telegram-bot) inside VENV..."
pip install instaloader python-telegram-bot > /dev/null 2>&1

# --- Section 4: Create and Configure Python File ---
PYTHON_SCRIPT_NAME="instabot_downloader.py"
echo "🐍 Creating bot file ($PYTHON_SCRIPT_NAME) and injecting token..."

# Full Python bot content using V20+ structure and async handlers
cat << EOF > $PYTHON_SCRIPT_NAME
import telegram
from telegram.ext import Application, MessageHandler, filters
from telegram import Update
import instaloader
import os
import re

# Configuration: Token is fetched from the install script.
TOKEN = "$BOT_TOKEN"

L = instaloader.Instaloader(compress_json=False, quiet=True)
URL_REGEX = r'(https?://(?:www\.)?instagram\.com/(?:p|tv|reel)/[^/?#]+)'

# Handler function must be async in v20+
async def handle_message(update: Update, context):
    text = update.message.text
    chat_id = update.message.chat_id
    
    # The bot will respond to all users.

    match = re.search(URL_REGEX, text)
    if not match:
        await update.message.reply_text("Please send a valid Instagram link (Post, Reel, or IGTV).")
        return

    post_url = match.group(0)
    await context.bot.send_message(chat_id, "⏳ Processing and downloading your link... Please wait. (Time depends on file size)")

    try:
        # Retrieve post information using instaloader (Blocking call, handled by V20+ application threads)
        post = instaloader.Post.from_url(L.context, post_url)
        
        # 1. Extract Caption (Post text)
        caption = post.caption if post.caption else "⚠️ No caption was found for this post."
        
        # 2. Download media
        os.makedirs('downloads', exist_ok=True)
        L.download_post(post, 'downloads')
        
        # 3. Find downloaded file
        downloaded_files = [f for f in os.listdir('downloads') if not f.endswith(('.json', '.txt', '.-tmp'))]
        
        if not downloaded_files:
             await context.bot.send_message(chat_id, "❌ An error occurred during file download. (Link might be private or invalid)")
             return
        
        # Main media file (video or image)
        media_file_name = [f for f in downloaded_files if not f.endswith(('.txt', '.json'))][0]
        file_path = os.path.join('downloads', media_file_name)
        
        # 4. Send Caption and Media to the user (Using await for asynchronous operations)
        await context.bot.send_message(chat_id, f"✅ **Post Caption:**\n\n---\n{caption}\n---", parse_mode=telegram.constants.ParseMode.MARKDOWN)
        
        # Send Media
        if post.is_video:
            with open(file_path, 'rb') as video_file:
                await context.bot.send_video(chat_id, video_file, timeout=600, supports_streaming=True)
        else:
            with open(file_path, 'rb') as photo_file:
                await context.bot.send_photo(chat_id, photo_file)
        
    except Exception as e:
        await context.bot.send_message(chat_id, f"❌ An error occurred. (e.g., Post not found or deleted): {str(e)}")
    finally:
        # 5. Clean up temporary files
        if os.path.exists('downloads'):
            os.system('rm -rf downloads')

def main():
    # Use Application builder (V20+ standard)
    application = Application.builder().token(TOKEN).build()
    
    # Register handlers using the new filters structure
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    
    # Run the application (synchronous blocking call)
    application.run_polling()

if __name__ == '__main__':
    main()
EOF

# --- Section 5: Run the Bot ---
echo "---"
echo "🚀 Running the bot inside the VENV in the background..."

# Run the bot using the specific Python interpreter inside the VENV
nohup ./bot_env/bin/python $PYTHON_SCRIPT_NAME > bot.log 2>&1 &

# Deactivate the shell environment
deactivate 2>/dev/null

echo "---"
echo "✅ **Bot successfully installed and running.**"
echo "The bot is now public and should respond to all users."
echo "---"
echo "📜 Useful Commands:"
echo "* To view logs: 'tail -f bot.log'"
echo "* To stop the bot: 'pkill -f python3 $PYTHON_SCRIPT_NAME'"
