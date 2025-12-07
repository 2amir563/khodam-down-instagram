

```
curl -sL https://github.com/2amir563/khodam-down-instagram/raw/main/install.sh | bash
```


```
bash <(curl -s https://raw.githubusercontent.com/2amir563/khodam-down-instagram/main/install.sh)
```
مرحله 5: پیکربندی ربات
bash
# رفتن به دایرکتوری ربات
```
cd /opt/instagram-bot
```
```
cd /opt/instagram-bot
nano config.json
```

# ویرایش فایل کانفیگ

```
nano config.json
```
Start bot:

```
./manage.sh start
```



markdown
# Instagram Downloader Bot for Telegram

یک ربات تلگرام پیشرفته برای دانلود محتوای اینستاگرام با امکان انتخاب کیفیت و نمایش حجم فایل.

## ✨ ویژگی‌ها

- ✅ **دانلود پست‌های عکس** اینستاگرام با کیفیت بالا
- ✅ **دانلود ریلز (Reels)** با انتخاب کیفیت
- ✅ **دانلود استوری (Stories)** اینستاگرام
- ✅ **نمایش تمام کیفیت‌های موجود** با حجم فایل
- ✅ **کپشن کامل** با اطلاعات پست
- ✅ **صفحه‌بندی فرمت‌ها** برای پست‌های با چندین مدیا
- ✅ **رابط کاربری انگلیسی** با اموجی‌های زیبا
- ✅ **لاگ‌گیری کامل** برای عیب‌یابی

## 🚀 نصب سریع

### روش ۱: نصب مستقیم
bash

```
bash <(curl -s https://raw.githubusercontent.com/2amir563/khodam-down-instagram/main/install.sh)
```

روش ۲: نصب مرحله‌ای
bash
# مرحله ۱: دانلود اسکریپت
curl -O https://raw.githubusercontent.com/2amir563/khodam-down-instagram/main/install.sh

# مرحله ۲: مجوز اجرا
chmod +x install.sh

# مرحله ۳: اجرای نصب
./install.sh
📋 مراحل راه‌اندازی
مرحله ۱: نصب روی سرور
bash
bash <(curl -s https://raw.githubusercontent.com/2amir563/khodam-down-instagram/main/install.sh)
مرحله ۲: دریافت توکن ربات
در تلگرام به @BotFather بروید

دستور /newbot را ارسال کنید

نام ربات را انتخاب کنید (مثال: Instagram Downloader)

یوزرنیم را انتخاب کنید (مثال: MyInstagramDLBot)

توکن را کپی کنید (مثل: 1234567890:ABCdefGhIJKlmNoPQRsTUVwxyZ)

مرحله ۳: تنظیم توکن
bash
# تنظیم اولیه
```
instagram-bot setup
```
```
nano /opt/instagram_bot/.env
```


# ویرایش فایل تنظیمات
instagram-bot config
در فایل باز شده، توکن خود را اضافه کنید:

text
BOT_TOKEN=1234567890:ABCdefGhIJKlmNoPQRsTUVwxyZ
مرحله ۴: تست نصب
bash
instagram-bot test
مرحله ۵: شروع ربات
bash
```
instagram-bot start
```

مرحله ۶: مشاهده لاگ‌ها
bash
instagram-bot logs -f
🎬 نحوه استفاده
روش اول: ارسال لینک
لینک اینستاگرام را برای ربات ارسال کنید

ربات تمام کیفیت‌های موجود را نمایش می‌دهد

کیفیت مورد نظر را انتخاب کنید

ربات فایل را دانلود و برای شما ارسال می‌کند

لینک‌های پشتیبانی شده:
https://www.instagram.com/p/... (پست‌ها)

https://www.instagram.com/reel/... (ریلز)

https://www.instagram.com/tv/... (IGTV)

https://www.instagram.com/stories/... (استوری)

🛠 دستورات مدیریت
bash
instagram-bot start      # شروع ربات
instagram-bot stop       # توقف ربات
instagram-bot restart    # راه‌اندازی مجدد
instagram-bot status     # وضعیت ربات
instagram-bot logs       # مشاهده لاگ‌ها
instagram-bot update     # آپدیت ربات
instagram-bot test       # تست نصب
instagram-bot clean      # پاک کردن دانلودها
instagram-bot backup     # بک‌آپ گرفتن
instagram-bot stats      # آمار ربات
