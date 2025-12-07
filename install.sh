cd /root
cat > install_new.sh << 'EOF'
#!/bin/bash

echo "Instagram Bot Installer with Token Setup"
echo "========================================"

# Install requirements
apt-get update
apt-get install -y python3 python3-pip
pip3 install python-telegram-bot

# Create directory
mkdir -p /root/instagram_bot_new
cd /root/instagram_bot_new

# Get token
echo ""
echo "Enter your Telegram Bot Token:"
echo "(Get it from @BotFather on Telegram)"
read TOKEN

if [ -z "$TOKEN" ]; then
    echo "Error: Token is required!"
    exit 1
fi

# Create config file
echo "TELEGRAM_TOKEN = '$TOKEN'" > config.py

# Create bot
cat > bot.py << 'BOTPY'
import os
import sys
import json
import tempfile
from datetime import datetime

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

try:
    from config import TELEGRAM_TOKEN
except:
    print("ERROR: config.py not found or invalid")
    sys.exit(1)

from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("✅ ربات نصب شد!\nلینک اینستاگرام بفرستید.")

async def handle_link(update: Update, context: ContextTypes.DEFAULT_TYPE):
    url = update.message.text.strip()
    
    if "instagram.com" not in url:
        await update.message.reply_text("❌ لطفاً فقط لینک اینستاگرام بفرستید.")
        return
    
    msg = await update.message.reply_text("⏳ در حال ایجاد فایل...")
    
    try:
        # Create data
        data = {
            "instagram_url": url,
            "received_at": datetime.now().isoformat(),
            "telegram_user_id": update.effective_user.id,
            "telegram_username": update.effective_user.username,
            "message": "این فایل حاوی لینک اینستاگرام شماست",
            "note": "ربات توسط کاربر اجرا شده است"
        }
        
        # Create JSON
        json_str = json.dumps(data, indent=2, ensure_ascii=False)
        
        # Save to temp file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False, encoding='utf-8') as f:
            f.write(json_str)
            temp_file = f.name
        
        # Send file
        with open(temp_file, 'rb') as f:
            await update.message.reply_document(
                document=f,
                filename=f"instagram_link_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json",
                caption=f"📁 فایل لینک اینستاگرام\n{url[:50]}..."
            )
        
        os.unlink(temp_file)
        await msg.edit_text("✅ فایل ارسال شد.")
        
    except Exception as e:
        await msg.edit_text(f"❌ خطا: {str(e)}")

def main():
    print(f"Starting bot with token: {TELEGRAM_TOKEN[:10]}...")
    app = Application.builder().token(TELEGRAM_TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_link))
    print("Bot is running. Press Ctrl+C to stop.")
    app.run_polling()

if __name__ == "__main__":
    main()
BOTPY

# Create start script
cat > start.sh << 'START'
#!/bin/bash
cd /root/instagram_bot_new
python3 bot.py
START

chmod +x start.sh bot.py

# Start bot in screen
screen -dmS instagram_bot python3 bot.py

echo ""
echo "✅ Installation complete!"
echo ""
echo "Your bot is running."
echo "Token: $TOKEN"
echo ""
echo "To manage bot:"
echo "  screen -r instagram_bot  # View bot"
echo "  Ctrl+A, D                # Detach from screen"
echo "  screen -list             # List screens"
echo ""
echo "To change token later:"
echo "  nano /root/instagram_bot_new/config.py"
echo "  screen -XS instagram_bot quit"
echo "  screen -dmS instagram_bot python3 /root/instagram_bot_new/bot.py"
EOF

chmod +x install_new.sh
./install_new.sh
