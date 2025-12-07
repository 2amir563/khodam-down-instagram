#!/bin/bash

# Ultimate Instagram Telegram Bot Installer
# Uses browser automation and HTML parsing

set -e

echo "=========================================="
echo "Ultimate Instagram Bot Installer"
echo "=========================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_info() { echo -e "${YELLOW}[i]${NC} $1"; }

# Step 1: Update system
log_info "Step 1: Updating system..."
apt-get update -y
apt-get upgrade -y

# Step 2: Install Python and dependencies
log_info "Step 2: Installing Python and Chrome..."
apt-get install -y python3 python3-pip python3-venv git curl wget unzip

# Install Chrome for selenium (optional)
apt-get install -y chromium-chromedriver || true

# Step 3: Create directory
log_info "Step 3: Creating bot directory..."
INSTALL_DIR="/opt/instagram_bot"
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# Step 4: Create virtual environment
log_info "Step 4: Creating virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Step 5: Install Python packages
log_info "Step 5: Installing Python packages..."
pip install --upgrade pip
pip install python-telegram-bot==20.7 requests beautifulsoup4 lxml html5lib

# Try to install selenium (optional)
pip install selenium webdriver-manager || log_error "Selenium installation failed (optional)"

# Step 6: Get Telegram Bot Token
log_info "Step 6: Setting up Telegram Bot..."
echo ""
echo "=========================================="
echo "TELEGRAM BOT TOKEN"
echo "=========================================="
echo "Get token from @BotFather on Telegram"
echo "Your current token: 8502213708:AAud0o3wEjhWKNPqXjY5AoNIi6fEQiL4tf4"
echo "=========================================="
echo ""

read -p "Enter your Telegram Bot Token [press Enter to use default]: " TELEGRAM_TOKEN

if [ -z "$TELEGRAM_TOKEN" ]; then
    TELEGRAM_TOKEN="8502213708:AAud0o3wEjhWKNPqXjY5AoNIi6fEQiL4tf4"
    log_info "Using default token: ${TELEGRAM_TOKEN:0:10}..."
fi

# Step 7: Create the bot file
log_info "Step 7: Creating bot.py..."
cat > bot.py << 'BOTPY'
#!/usr/bin/env python3
"""
Instagram Telegram Bot - Ultimate Version
Uses multiple reliable methods to extract Instagram content
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
from urllib.parse import urlparse, quote, unquote

import requests
from bs4 import BeautifulSoup
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('/var/log/instagram_bot.log')
    ]
)
logger = logging.getLogger(__name__)

# Telegram Bot Token
TELEGRAM_TOKEN = os.getenv('TELEGRAM_TOKEN', '8502213708:AAud0o3wEjhWKNPqXjY5AoNIi6fEQiL4tf4')

class InstagramExtractor:
    """Advanced Instagram content extractor using multiple techniques"""
    
    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9,fa;q=0.8',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
            'Sec-Fetch-Dest': 'document',
            'Sec-Fetch-Mode': 'navigate',
            'Sec-Fetch-Site': 'none',
            'Sec-Fetch-User': '?1',
            'Cache-Control': 'max-age=0',
        })
        
        # List of user agents to rotate
        self.user_agents = [
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/121.0',
            'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        ]
    
    def rotate_user_agent(self):
        """Rotate user agent to avoid detection"""
        self.session.headers['User-Agent'] = random.choice(self.user_agents)
    
    def extract_shortcode(self, url):
        """Extract shortcode from Instagram URL"""
        # Clean URL
        url = url.strip()
        if not url.startswith('http'):
            url = 'https://' + url
        
        patterns = [
            r'(?:https?://)?(?:www\.)?instagram\.com/(?:p|reel|tv)/([a-zA-Z0-9_-]+)',
            r'(?:https?://)?(?:www\.)?instagr\.am/(?:p|reel|tv)/([a-zA-Z0-9_-]+)',
            r'instagram\.com/(?:p|reel|tv)/([a-zA-Z0-9_-]+)'
        ]
        
        for pattern in patterns:
            match = re.search(pattern, url, re.IGNORECASE)
            if match:
                shortcode = match.group(1)
                logger.info(f"Extracted shortcode: {shortcode}")
                return shortcode
        
        logger.warning(f"Could not extract shortcode from: {url}")
        return None
    
    def method1_direct_html_parsing(self, url):
        """Method 1: Direct HTML parsing with advanced techniques"""
        try:
            self.rotate_user_agent()
            
            # Add delay to seem more human
            time.sleep(random.uniform(1, 3))
            
            response = self.session.get(url, timeout=20)
            response.raise_for_status()
            
            html = response.text
            soup = BeautifulSoup(html, 'html.parser')
            
            # Try to find JSON-LD data (most reliable)
            json_ld_scripts = soup.find_all('script', type='application/ld+json')
            for script in json_ld_scripts:
                try:
                    data = json.loads(script.string.strip())
                    result = self._parse_json_ld(data, url)
                    if result:
                        result['method'] = 'json_ld'
                        return result, None
                except:
                    continue
            
            # Try to find Instagram's internal data
            script_patterns = [
                r'window\.__additionalDataLoaded\s*\([^,]+,(.*?)\);',
                r'window\._sharedData\s*=\s*(.*?);</script>',
                r'"caption":"(.*?)"',
                r'"edge_media_to_caption":{"edges":\[(.*?)\]',
            ]
            
            for pattern in script_patterns:
                matches = re.findall(pattern, html, re.DOTALL)
                for match in matches:
                    try:
                        if pattern.startswith('"caption"'):
                            # Simple caption extraction
                            caption = match
                            if caption:
                                result = {
                                    'url': url,
                                    'caption': self._clean_text(caption),
                                    'method': 'regex_caption'
                                }
                                return result, None
                        else:
                            # Try to parse as JSON
                            data = json.loads(match.strip())
                            result = self._parse_internal_data(data, url)
                            if result:
                                result['method'] = 'internal_data'
                                return result, None
                    except:
                        continue
            
            # Extract meta tags
            result = self._extract_meta_tags(soup, url)
            if result:
                result['method'] = 'meta_tags'
                return result, None
            
            # Extract all text content (fallback)
            result = self._extract_all_text(soup, url)
            if result:
                result['method'] = 'all_text'
                return result, None
            
            return None, "No extractable data found in HTML"
            
        except Exception as e:
            logger.error(f"HTML parsing error: {e}")
            return None, str(e)
    
    def method2_public_api_endpoints(self, shortcode):
        """Method 2: Try various public API endpoints"""
        endpoints = [
            f"https://www.instagram.com/p/{shortcode}/?__a=1&__d=dis",
            f"https://www.instagram.com/p/{shortcode}/?__a=1",
            f"https://i.instagram.com/api/v1/media/{shortcode}/info/",
            f"https://www.instagram.com/graphql/query/?shortcode={shortcode}",
            f"https://api.instagram.com/oembed/?url=https://www.instagram.com/p/{shortcode}/",
        ]
        
        for endpoint in endpoints:
            try:
                self.rotate_user_agent()
                time.sleep(random.uniform(0.5, 1.5))
                
                response = self.session.get(endpoint, timeout=15)
                
                if response.status_code == 200:
                    try:
                        data = response.json()
                        result = self._parse_api_response(data, endpoint)
                        if result:
                            result['method'] = f'api_{endpoints.index(endpoint)}'
                            return result, None
                    except:
                        # Maybe it's HTML, not JSON
                        continue
                        
            except Exception as e:
                logger.debug(f"Endpoint {endpoint} failed: {e}")
                continue
        
        return None, "All API endpoints failed"
    
    def method3_external_services(self, url):
        """Method 3: Use external services and proxies"""
        services = [
            {
                'name': 'iframely',
                'url': f'https://iframe.ly/api/oembed?url={quote(url)}&api_key=8d12d504c41e7f431fb0935c',
                'parser': lambda d: self._parse_iframely(d, url)
            },
            {
                'name': 'microlink',
                'url': f'https://api.microlink.io?url={quote(url)}',
                'parser': lambda d: self._parse_microlink(d, url)
            },
            {
                'name': 'mercury',
                'url': f'https://mercury.postlight.com/parser?url={quote(url)}',
                'parser': lambda d: self._parse_mercury(d, url)
            },
        ]
        
        for service in services:
            try:
                response = self.session.get(service['url'], timeout=15)
                if response.status_code == 200:
                    data = response.json()
                    result = service['parser'](data)
                    if result:
                        result['method'] = f'service_{service["name"]}'
                        return result, None
            except Exception as e:
                logger.debug(f"Service {service['name']} failed: {e}")
                continue
        
        return None, "External services failed"
    
    def method4_simple_scraping(self, url):
        """Method 4: Simple but effective text scraping"""
        try:
            self.rotate_user_agent()
            
            response = self.session.get(url, timeout=15)
            html = response.text
            
            # Extract title
            title_match = re.search(r'<title[^>]*>(.*?)</title>', html, re.IGNORECASE | re.DOTALL)
            title = self._clean_html(title_match.group(1)) if title_match else ""
            
            # Extract all text content (brute force)
            soup = BeautifulSoup(html, 'html.parser')
            
            # Remove scripts and styles
            for script in soup(["script", "style", "meta", "link"]):
                script.decompose()
            
            # Get all text
            all_text = soup.get_text(separator=' ', strip=True)
            
            # Find Instagram-specific patterns
            patterns = [
                r'(@[a-zA-Z0-9_.]+)',  # Usernames
                r'(#[a-zA-Z0-9_]+)',   # Hashtags
                r'(https?://[^\s]+)',  # URLs
            ]
            
            extracted = {}
            for pattern in patterns:
                matches = re.findall(pattern, all_text)
                if matches:
                    key = 'usernames' if '@' in pattern else ('hashtags' if '#' in pattern else 'urls')
                    extracted[key] = list(set(matches))[:10]  # Limit to 10
            
            # Take first 2000 chars of text
            main_text = all_text[:2000] + ('...' if len(all_text) > 2000 else '')
            
            result = {
                'url': url,
                'title': title,
                'text_content': main_text,
                'extracted_elements': extracted,
                'char_count': len(all_text),
                'word_count': len(all_text.split())
            }
            
            return result, None
            
        except Exception as e:
            logger.error(f"Simple scraping error: {e}")
            return None, str(e)
    
    def _parse_json_ld(self, data, url):
        """Parse JSON-LD structured data"""
        result = {'url': url}
        
        if isinstance(data, dict):
            result.update({
                'title': data.get('name', data.get('headline', '')),
                'description': data.get('description', ''),
                'author': data.get('author', {}).get('name', '') if isinstance(data.get('author'), dict) else data.get('author', ''),
                'publisher': data.get('publisher', {}).get('name', '') if isinstance(data.get('publisher'), dict) else '',
                'date_published': data.get('datePublished', ''),
                'date_modified': data.get('dateModified', ''),
                'image': data.get('image', {}).get('url', '') if isinstance(data.get('image'), dict) else data.get('image', ''),
                'keywords': data.get('keywords', ''),
            })
        elif isinstance(data, list):
            # Handle list of JSON-LD objects
            for item in data:
                if isinstance(item, dict):
                    temp_result = self._parse_json_ld(item, url)
                    if temp_result:
                        return temp_result
        
        # Clean empty values
        result = {k: v for k, v in result.items() if v}
        return result if any(result.values()) else None
    
    def _parse_internal_data(self, data, url):
        """Parse Instagram's internal data structures"""
        result = {'url': url}
        
        # Try different Instagram data structures
        paths = [
            ['graphql', 'shortcode_media'],
            ['items', 0],
            ['media'],
            ['data', 'shortcode_media'],
        ]
        
        for path in paths:
            try:
                current = data
                for key in path:
                    if isinstance(key, int) and isinstance(current, list) and len(current) > key:
                        current = current[key]
                    elif isinstance(current, dict) and key in current:
                        current = current[key]
                    else:
                        raise KeyError
                
                # Found Instagram media data
                if isinstance(current, dict):
                    # Extract caption
                    caption_paths = [
                        ['edge_media_to_caption', 'edges', 0, 'node', 'text'],
                        ['caption', 'text'],
                        ['caption'],
                        ['edge_media_to_caption', 'edges', 0, 'node', 'text'],
                    ]
                    
                    for cpath in caption_paths:
                        try:
                            ccurrent = current
                            for ckey in cpath:
                                if isinstance(ckey, int) and isinstance(ccurrent, list) and len(ccurrent) > ckey:
                                    ccurrent = ccurrent[ckey]
                                elif isinstance(ccurrent, dict) and ckey in ccurrent:
                                    ccurrent = ccurrent[ckey]
                                else:
                                    raise KeyError
                            
                            if ccurrent:
                                result['caption'] = self._clean_text(str(ccurrent))
                                break
                        except:
                            continue
                    
                    # Extract other info
                    result.update({
                        'username': current.get('owner', {}).get('username', ''),
                        'full_name': current.get('owner', {}).get('full_name', ''),
                        'likes': current.get('edge_media_preview_like', {}).get('count', 
                                 current.get('like_count', 
                                 current.get('edge_liked_by', {}).get('count', 0))),
                        'comments': current.get('edge_media_to_comment', {}).get('count',
                                   current.get('comment_count', 0)),
                        'is_video': current.get('is_video', False),
                        'video_url': current.get('video_url', ''),
                        'display_url': current.get('display_url', ''),
                        'timestamp': current.get('taken_at_timestamp', 0),
                    })
                    
                    return result
                    
            except:
                continue
        
        return None
    
    def _extract_meta_tags(self, soup, url):
        """Extract meta tags from HTML"""
        result = {'url': url}
        
        # Open Graph tags
        og_tags = {
            'title': 'og:title',
            'description': 'og:description',
            'image': 'og:image',
            'url': 'og:url',
            'type': 'og:type',
            'site_name': 'og:site_name',
        }
        
        for key, prop in og_tags.items():
            tag = soup.find('meta', property=prop)
            if tag and tag.get('content'):
                result[key] = tag['content']
        
        # Twitter cards
        twitter_tags = {
            'twitter:title': 'twitter_title',
            'twitter:description': 'twitter_description',
            'twitter:image': 'twitter_image',
        }
        
        for prop, key in twitter_tags.items():
            tag = soup.find('meta', attrs={'name': prop})
            if tag and tag.get('content'):
                result[key] = tag['content']
        
        # Regular meta tags
        meta_desc = soup.find('meta', attrs={'name': 'description'})
        if meta_desc and meta_desc.get('content'):
            result['meta_description'] = meta_desc['content']
        
        # Title tag
        title_tag = soup.find('title')
        if title_tag and title_tag.string:
            result['html_title'] = self._clean_html(title_tag.string)
        
        # Clean empty values
        result = {k: v for k, v in result.items() if v}
        return result if any(result.values()) else None
    
    def _extract_all_text(self, soup, url):
        """Extract all readable text from page"""
        # Remove unwanted elements
        for element in soup(["script", "style", "meta", "link", "noscript"]):
            element.decompose()
        
        # Get all text
        text = soup.get_text(separator='\n', strip=True)
        
        # Clean and filter text
        lines = [line.strip() for line in text.split('\n') if line.strip()]
        lines = [line for line in lines if len(line) > 10]  # Remove very short lines
        
        if lines:
            return {
                'url': url,
                'all_text': '\n'.join(lines[:50]),  # Limit to 50 lines
                'line_count': len(lines),
                'total_chars': len(text)
            }
        
        return None
    
    def _parse_api_response(self, data, endpoint):
        """Generic API response parser"""
        result = {}
        
        # Try to extract based on endpoint type
        if 'oembed' in endpoint:
            result.update({
                'title': data.get('title', ''),
                'author_name': data.get('author_name', ''),
                'author_url': data.get('author_url', ''),
                'thumbnail_url': data.get('thumbnail_url', ''),
                'html': data.get('html', ''),
            })
        elif 'graphql' in str(data):
            # Instagram GraphQL response
            result = self._parse_internal_data(data, endpoint)
        
        return result if any(result.values()) else None
    
    def _parse_iframely(self, data, url):
        """Parse Iframely response"""
        return {
            'url': url,
            'title': data.get('meta', {}).get('title', ''),
            'description': data.get('meta', {}).get('description', ''),
            'html': data.get('html', ''),
            'thumbnail': data.get('thumbnail', {}).get('url', ''),
        }
    
    def _parse_microlink(self, data, url):
        """Parse Microlink response"""
        return {
            'url': url,
            'title': data.get('data', {}).get('title', ''),
            'description': data.get('data', {}).get('description', ''),
            'author': data.get('data', {}).get('author', ''),
            'publisher': data.get('data', {}).get('publisher', ''),
            'image': data.get('data', {}).get('image', {}).get('url', ''),
        }
    
    def _parse_mercury(self, data, url):
        """Parse Mercury Web Parser response"""
        return {
            'url': url,
            'title': data.get('title', ''),
            'content': data.get('content', ''),
            'excerpt': data.get('excerpt', ''),
            'author': data.get('author', ''),
            'date_published': data.get('date_published', ''),
            'lead_image_url': data.get('lead_image_url', ''),
            'dek': data.get('dek', ''),
            'direction': data.get('direction', ''),
        }
    
    def _clean_text(self, text):
        """Clean and normalize text"""
        if not text:
            return ""
        
        # Decode Unicode escapes
        if '\\u' in text:
            try:
                text = text.encode().decode('unicode_escape')
            except:
                pass
        
        # Replace common escapes
        replacements = {
            '\\n': '\n',
            '\\t': '\t',
            '\\r': '\r',
            '\\"': '"',
            "\\'": "'",
        }
        
        for old, new in replacements.items():
            text = text.replace(old, new)
        
        # Remove extra whitespace
        text = ' '.join(text.split())
        
        return text.strip()
    
    def _clean_html(self, text):
        """Clean HTML entities"""
        if not text:
            return ""
        
        replacements = {
            '&amp;': '&',
            '&lt;': '<',
            '&gt;': '>',
            '&quot;': '"',
            '&#39;': "'",
            '&nbsp;': ' ',
        }
        
        for entity, char in replacements.items():
            text = text.replace(entity, char)
        
        return text.strip()
    
    def extract_content(self, instagram_url):
        """Main extraction method - tries all techniques"""
        logger.info(f"Starting extraction for: {instagram_url}")
        
        # Clean URL
        if not instagram_url.startswith('http'):
            instagram_url = 'https://' + instagram_url
        
        # Extract shortcode for API methods
        shortcode = self.extract_shortcode(instagram_url)
        
        # Try all methods in sequence
        methods = [
            ("Direct HTML Parsing", lambda: self.method1_direct_html_parsing(instagram_url)),
            ("Simple Text Scraping", lambda: self.method4_simple_scraping(instagram_url)),
        ]
        
        # Add API methods if we have shortcode
        if shortcode:
            methods.insert(1, ("Public APIs", lambda: self.method2_public_api_endpoints(shortcode)))
        
        # Add external services
        methods.append(("External Services", lambda: self.method3_external_services(instagram_url)))
        
        results = []
        
        for method_name, method_func in methods:
            logger.info(f"Trying {method_name}...")
            try:
                data, error = method_func()
                
                if data:
                    logger.info(f"✓ {method_name} succeeded")
                    
                    # Ensure URL is included
                    if 'url' not in data:
                        data['url'] = instagram_url
                    
                    # Ensure shortcode is included if we have it
                    if shortcode and 'shortcode' not in data:
                        data['shortcode'] = shortcode
                    
                    results.append((method_name, data, None))
                    
                    # If we got good data, return it
                    if self._is_good_result(data):
                        return data, None
                else:
                    logger.warning(f"✗ {method_name} failed: {error}")
                    results.append((method_name, None, error))
                    
            except Exception as e:
                logger.error(f"✗ {method_name} error: {e}")
                results.append((method_name, None, str(e)))
            
            # Small delay between methods
            time.sleep(random.uniform(0.5, 1.5))
        
        # If we have any results, return the best one
        if results:
            # Find the best result
            for method_name, data, error in results:
                if data and self._is_acceptable_result(data):
                    logger.info(f"Using result from {method_name}")
                    return data, None
            
            # Return first result with data
            for method_name, data, error in results:
                if data:
                    logger.info(f"Falling back to result from {method_name}")
                    return data, None
        
        return None, "All extraction methods failed. Instagram may be blocking automated access."
    
    def _is_good_result(self, data):
        """Check if result has substantial content"""
        text_fields = ['caption', 'description', 'text_content', 'title', 'content']
        
        for field in text_fields:
            if field in data and data[field] and len(str(data[field])) > 20:
                return True
        
        return False
    
    def _is_acceptable_result(self, data):
        """Check if result has any useful content"""
        if not data:
            return False
        
        # Check for any non-empty field
        for value in data.values():
            if isinstance(value, str) and value.strip():
                return True
            elif isinstance(value, (int, float)) and value:
                return True
            elif isinstance(value, (list, dict)) and value:
                return True
        
        return False

# Create extractor instance
extractor = InstagramExtractor()

# Telegram Bot Handlers
async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command"""
    welcome = """
🤖 *Instagram Content Extractor Bot - ULTIMATE VERSION*

I use advanced techniques to extract content from Instagram when other methods fail.

*How I work:*
1. I analyze the Instagram page HTML directly
2. I extract all readable text content
3. I find captions, descriptions, and metadata
4. I send you everything I can find

*Just send me any Instagram link!*

*Commands:*
/start - Show this message
/help - Get help
/test - Test with example link
/status - Bot status

*Examples of links I accept:*
• https://www.instagram.com/p/CvC9FkHNrJI/
• https://instagram.com/reel/Cxample123
• instagram.com/tv/ABC123DEF/
"""
    await update.message.reply_text(welcome, parse_mode='Markdown')

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /help command"""
    help_text = """
📖 *Help & Troubleshooting*

*What I extract:*
- All visible text from the page
- Post captions and descriptions
- Usernames and hashtags
- Any metadata I can find
- Page titles and content

*Why other bots fail but I work:*
- I don't rely on Instagram's API
- I read the page like a human browser
- I use multiple extraction techniques
- I fall back to raw text scraping

*If extraction fails:*
1. Make sure the link is correct
2. Try a different Instagram post
3. The account might be private
4. Instagram might be temporarily blocking

*Pro tip:* I work best with public posts that have text content.
"""
    await update.message.reply_text(help_text, parse_mode='Markdown')

async def test_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /test command with example"""
    example_url = "https://www.instagram.com/p/CvC9FkHNrJI/"
    await update.message.reply_text(f"🔍 Testing with example link: {example_url}")
    
    # Simulate processing
    processing_msg = await update.message.reply_text("⏳ Testing extraction...")
    
    try:
        data, error = extractor.extract_content(example_url)
        
        if error:
            await processing_msg.edit_text(f"❌ Test failed: {error}")
        else:
            # Show what we found
            found_items = []
            for key, value in data.items():
                if isinstance(value, str) and value:
                    found_items.append(f"• {key}: {value[:50]}...")
                elif value:
                    found_items.append(f"• {key}: {type(value).__name__}")
            
            if found_items:
                response = "✅ Test successful! Found:\n" + "\n".join(found_items[:10])
                if len(found_items) > 10:
                    response += f"\n... and {len(found_items) - 10} more items"
            else:
                response = "⚠️ Test completed but no data extracted"
            
            await processing_msg.edit_text(response)
            
    except Exception as e:
        await processing_msg.edit_text(f"❌ Test error: {str(e)}")

async def status_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /status command"""
    status = f"""
📊 *Bot Status Report*

✅ Bot is running
🕐 Server time: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
🔧 Version: Ultimate 2.0
🔄 Methods available: 4
📈 Uptime: Active

*Extraction techniques:*
1. Direct HTML parsing
2. Public API endpoints
3. External services
4. Raw text scraping

*Ready to extract!* Send me an Instagram link.
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
            "I need an Instagram link to work. Examples:\n"
            "• `https://www.instagram.com/p/CvC9FkHNrJI/`\n"
            "• `https://instagram.com/reel/Cxample123`\n"
            "• `instagram.com/tv/ABC123DEF/`\n\n"
            "Just copy and paste any Instagram link here!",
            parse_mode='Markdown'
        )
        return
    
    # Send processing message
    processing_msg = await update.message.reply_text(
        "⏳ *Processing your Instagram link...*\n"
        "This may take 10-30 seconds as I analyze the page.\n"
        "I'm using advanced techniques to extract content...",
        parse_mode='Markdown'
    )
    
    try:
        # Extract content
        start_time = time.time()
        data, error = extractor.extract_content(user_text)
        elapsed_time = time.time() - start_time
        
        if error:
            await processing_msg.edit_text(
                f"❌ *Extraction completed but failed*\n\n"
                f"⏱️ Time taken: {elapsed_time:.1f}s\n"
                f"📛 Error: {error}\n\n"
                f"*What you can try:*\n"
                f"1. Try a different Instagram link\n"
                f"2. Make sure the account is public\n"
                f"3. Try again in a few minutes\n"
                f"4. Use /test to check if I'm working\n\n"
                f"*Technical details:*\n"
                f"I tried 4 different methods but Instagram\n"
                f"is blocking automated access to this post.",
                parse_mode='Markdown'
            )
            return
        
        # Format response
        response = format_extraction_response(data, elapsed_time)
        
        # Send response
        await processing_msg.edit_text(response, parse_mode='Markdown')
        
        # Send JSON file with complete data
        await send_json_data(update, data)
        
        logger.info(f"Successfully processed link for user {user_id} in {elapsed_time:.1f}s")
        
    except Exception as e:
        logger.error(f"Error in handle_message: {e}", exc_info=True)
        await processing_msg.edit_text(
            f"❌ *Unexpected error during extraction*\n\n"
            f"Error: {str(e)[:200]}\n\n"
            f"Please try again or use /test to check.",
            parse_mode='Markdown'
        )

def format_extraction_response(data, elapsed_time):
    """Format extraction results for Telegram"""
    response = f"""
📷 *Instagram Content Extraction Complete!*

⏱️ *Time taken:* {elapsed_time:.1f} seconds
🔧 *Method used:* {data.get('method', 'Multiple techniques').replace('_', ' ').title()}
🔗 *URL:* {data.get('url', 'N/A')}
"""

    # Add shortcode if available
    if 'shortcode' in data:
        response += f"🆔 *Shortcode:* {data['shortcode']}\n"
    
    # Add title
    for title_key in ['title', 'html_title', 'twitter:title', 'og:title']:
        if title_key in data and data[title_key]:
            response += f"📌 *Title:* {data[title_key][:200]}\n"
            break
    
    # Add author/username
    for author_key in ['username', 'author', 'author_name', 'full_name']:
        if author_key in data and data[author_key]:
            response += f"👤 *Author:* {data[author_key]}\n"
            break
    
    # Add main content
    content_keys = ['caption', 'description', 'text_content', 'content', 'meta_description']
    for content_key in content_keys:
        if content_key in data and data[content_key]:
            content = str(data[content_key])
            if len(content) > 500:
                content = content[:500] + "...\n[Content truncated - see JSON file for full text]"
            
            response += f"\n📝 *Content:*\n{content}\n"
            break
    
    # Add likes/comments if available
    if 'likes' in data and data['likes']:
        response += f"❤️ *Likes:* {data['likes']:,}\n"
    
    if 'comments' in data and data['comments']:
        response += f"💬 *Comments:* {data['comments']:,}\n"
    
    # Add image/video info
    if 'is_video' in data:
        response += f"🎥 *Video:* {'Yes' if data['is_video'] else 'No'}\n"
    
    for media_key in ['video_url', 'display_url', 'image', 'thumbnail']:
        if media_key in data and data[media_key]:
            response += f"🖼️ *Media URL:* {data[media_key][:100]}...\n"
            break
    
    # Add timestamp if available
    if 'timestamp' in data and data['timestamp']:
        try:
            dt = datetime.fromtimestamp(int(data['timestamp']))
            response += f"📅 *Posted:* {dt.strftime('%Y-%m-%d %H:%M:%S')}\n"
        except:
            pass
    
    # Add statistics
    response += f"\n📊 *Extraction statistics:*\n"
    response += f"• Data fields extracted: {len(data)}\n"
    
    text_fields = [k for k, v in data.items() if isinstance(v, str) and v]
    response += f"• Text fields: {len(text_fields)}\n"
    
    char_count = sum(len(str(v)) for v in data.values() if isinstance(v, str))
    response += f"• Total characters: {char_count:,}\n"
    
    response += "\n📁 *A JSON file with complete data is attached below*"
    
    return response

async def send_json_data(update, data):
    """Send JSON file with complete extracted data"""
    try:
        # Prepare JSON data
        json_str = json.dumps(data, indent=2, ensure_ascii=False, default=str)
        
        # Create temporary file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False, encoding='utf-8') as f:
            f.write(json_str)
            temp_file = f.name
        
        # Determine filename
        shortcode = data.get('shortcode', 'instagram_data')
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"instagram_{shortcode}_{timestamp}.json"
        
        # Send file
        with open(temp_file, 'rb') as f:
            await update.message.reply_document(
                document=f,
                filename=filename,
                caption="📁 *Complete Instagram data in JSON format*\nAll extracted fields are included.",
                parse_mode='Markdown'
            )
        
        # Cleanup
        os.unlink(temp_file)
        
    except Exception as e:
        logger.error(f"Error sending JSON file: {e}")
        await update.message.reply_text(
            "⚠️ *Note:* Could not create JSON file, but text content was sent above.",
            parse_mode='Markdown'
        )

async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle bot errors"""
    logger.error(f"Bot error: {context.error}", exc_info=True)
    
    try:
        await update.message.reply_text(
            "❌ *An unexpected error occurred*\n\n"
            "The bot encountered an error. Please try again.\n"
            "If the problem persists, use /test to check bot status."
        )
    except:
        pass

def main():
    """Main function to run the bot"""
    print("=" * 60)
    print("🤖 ULTIMATE INSTAGRAM TELEGRAM BOT")
    print("=" * 60)
    print(f"🔑 Telegram Token: {TELEGRAM_TOKEN[:10]}...")
    print("🔧 Version: Ultimate 2.0 (HTML Parsing + Multiple Methods)")
    print("📝 Log file: /var/log/instagram_bot.log")
    print("=" * 60)
    
    try:
        # Create Telegram application
        application = Application.builder().token(TELEGRAM_TOKEN).build()
        
        # Add command handlers
        application.add_handler(CommandHandler("start", start_command))
        application.add_handler(CommandHandler("help", help_command))
        application.add_handler(CommandHandler("test", test_command))
        application.add_handler(CommandHandler("status", status_command))
        application.add_handler(CommandHandler("info", status_command))
        
        # Add message handler for Instagram links
        application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
        
        # Add error handler
        application.add_error_handler(error_handler)
        
        # Start the bot
        print("✅ Bot is starting...")
        print("🔄 Ready to receive Instagram links!")
        print("🛑 Press Ctrl+C to stop")
        print("=" * 60)
        
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

# Step 8: Create log directory
log_info "Step 8: Creating log directory..."
mkdir -p /var/log/instagram_bot
chmod 755 /var/log/instagram_bot

# Step 9: Create systemd service
log_info "Step 9: Creating systemd service..."
cat > /etc/systemd/system/instagram-bot.service << EOF
[Unit]
Description=Ultimate Instagram Telegram Bot
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$INSTALL_DIR/venv/bin"
Environment="TELEGRAM_TOKEN=$TELEGRAM_TOKEN"
ExecStart=$INSTALL_DIR/venv/bin/python3 $INSTALL_DIR/bot.py
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=instagram-bot

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict

[Install]
WantedBy=multi-user.target
EOF

# Step 10: Start the service
log_info "Step 10: Starting bot service..."
systemctl daemon-reload
systemctl enable instagram-bot.service
systemctl start instagram-bot.service

# Wait and check status
sleep 5

# Step 11: Verify installation
log_info "Step 11: Verifying installation..."
SERVICE_STATUS=$(systemctl is-active instagram-bot.service)

if [ "$SERVICE_STATUS" = "active" ]; then
    log_success "✅ Bot service is running successfully!"
    
    # Show initial logs
    echo ""
    echo "📊 Initial logs:"
    journalctl -u instagram-bot.service --no-pager -n 3
    
else
    log_error "❌ Service failed to start!"
    echo ""
    echo "🔍 Checking logs for errors..."
    journalctl -u instagram-bot.service --no-pager -n 20
    echo ""
    log_info "Trying to start manually for debugging..."
    cd $INSTALL_DIR
    source venv/bin/activate
    python3 bot.py || echo "Manual start failed"
fi

# Final instructions
echo ""
echo "=========================================="
echo "✅ ULTIMATE INSTAGRAM BOT INSTALLED!"
echo "=========================================="
echo ""
echo "📁 Installation directory: $INSTALL_DIR"
echo "🤖 Main script: $INSTALL_DIR/bot.py"
echo "📊 Log file: /var/log/instagram_bot.log"
echo "🔧 Config: Telegram token is hardcoded in script"
echo ""
echo "⚡ QUICK COMMANDS:"
echo "  systemctl status instagram-bot      # Check status"
echo "  journalctl -u instagram-bot -f      # View live logs"
echo "  tail -f /var/log/instagram_bot.log  # View log file"
echo "  systemctl restart instagram-bot     # Restart bot"
echo ""
echo "🤖 TELEGRAM USAGE:"
echo "1. Open Telegram"
echo "2. Find your bot: @[YourBotUsername]"
echo "3. Send /start command"
echo "4. Send any Instagram link"
echo "5. I'll extract ALL text content from the page"
echo ""
echo "✨ FEATURES:"
echo "• Uses 4 different extraction methods"
echo "• Falls back to raw HTML parsing"
echo "• Extracts all readable text"
echo "• Sends complete JSON file"
echo "• Works when other bots fail"
echo ""
echo "=========================================="
echo "Test with: /test command in Telegram"
echo "=========================================="

# Quick test
echo ""
log_info "Performing quick connection test..."
sleep 2
curl -s "https://api.telegram.org/bot${TELEGRAM_TOKEN}/getMe" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if data.get('ok'):
        print('✅ Telegram connection: SUCCESS')
        print(f'   Bot: @{data[\"result\"][\"username\"]}')
        print(f'   Name: {data[\"result\"][\"first_name\"]}')
    else:
        print('❌ Telegram connection: FAILED')
        print(f'   Error: {data}')
except Exception as e:
    print(f'❌ Test error: {e}')
"
