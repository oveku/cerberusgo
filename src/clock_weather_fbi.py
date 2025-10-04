#!/usr/bin/env python3
"""
Clock + Weather Display using fbi (framebuffer image viewer)
Generates PNG images and displays them on the PiTFT
Fixed version with proper error handling and resource management
"""

from PIL import Image, ImageDraw, ImageFont
import requests
from datetime import datetime
import time
import subprocess
import os
import signal
import logging
import sys
import atexit
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

# Logging configuration
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/tmp/clock_weather_fbi.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Configuration
LOCATION = "Sandnes, Rogaland"
LATITUDE = 58.8516
LONGITUDE = 5.7351

# Network configuration
MAX_RETRIES = 3
CONNECT_TIMEOUT = 5
READ_TIMEOUT = 10
WEATHER_UPDATE_INTERVAL = 600  # 10 minutes in seconds
MAX_WEATHER_FAILURES = 5

# Display settings (landscape for FBI)
SCREEN_WIDTH = 480
SCREEN_HEIGHT = 320
BG_COLOR = (26, 26, 46)
TEXT_COLOR = (234, 234, 234)
ACCENT_COLOR = (22, 199, 154)

# Create session with connection pooling and retries
session = requests.Session()
retry_strategy = Retry(
    total=MAX_RETRIES,
    backoff_factor=1,
    status_forcelist=[429, 500, 502, 503, 504],
)
adapter = HTTPAdapter(
    max_retries=retry_strategy,
    pool_connections=1,
    pool_maxsize=1
)
session.mount("http://", adapter)
session.mount("https://", adapter)

# Global state
weather_data = {
    'temperature': '--',
    'description': 'Loading...',
    'humidity': '--',
    'wind_speed': '--',
    'last_update': ''
}

fbi_process = None
running = True
weather_failures = 0
last_weather_update = 0


def fetch_weather():
    """Fetch weather from Open-Meteo API with proper error handling"""
    global weather_data, weather_failures, last_weather_update
    
    try:
        logger.info("Fetching weather data...")
        
        response = session.get(
            "https://api.open-meteo.com/v1/forecast",
            params={
                'latitude': LATITUDE,
                'longitude': LONGITUDE,
                'current': 'temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code',
                'timezone': 'Europe/Oslo'
            },
            timeout=(CONNECT_TIMEOUT, READ_TIMEOUT)
        )
        response.raise_for_status()
        data = response.json()
        current = data.get('current', {})
        
        # Weather code descriptions
        codes = {
            0: 'Clear sky', 1: 'Mainly clear', 2: 'Partly cloudy', 3: 'Overcast',
            45: 'Foggy', 48: 'Rime fog', 51: 'Light drizzle', 53: 'Drizzle', 
            55: 'Dense drizzle', 61: 'Slight rain', 63: 'Rain', 65: 'Heavy rain',
            71: 'Slight snow', 73: 'Snow', 75: 'Heavy snow', 77: 'Snow grains',
            80: 'Rain showers', 81: 'Rain showers', 82: 'Heavy rain showers',
            85: 'Snow showers', 86: 'Heavy snow showers', 95: 'Thunderstorm',
            96: 'Thunderstorm + hail', 99: 'Heavy thunderstorm'
        }
        
        weather_code = current.get('weather_code', 0)
        
        # Convert wind speed from km/h to m/s (divide by 3.6)
        wind_kmh = current.get('wind_speed_10m', 0)
        wind_ms = round(wind_kmh / 3.6, 1) if wind_kmh != 0 else '--'
        
        weather_data = {
            'temperature': f"{current.get('temperature_2m', '--')}",
            'description': codes.get(weather_code, 'Unknown'),
            'humidity': f"{current.get('relative_humidity_2m', '--')}",
            'wind_speed': f"{wind_ms}",
            'last_update': datetime.now().strftime("%H:%M")
        }
        
        # Reset failure counter and update timestamp
        weather_failures = 0
        last_weather_update = time.time()
        logger.info("Weather data fetched successfully")
        
    except requests.exceptions.Timeout as e:
        weather_failures += 1
        logger.error(f"Weather fetch timeout (failure {weather_failures}/{MAX_WEATHER_FAILURES}): {e}")
        weather_data['description'] = "Connection timeout"
    
    except requests.exceptions.RequestException as e:
        weather_failures += 1
        logger.error(f"Weather fetch error (failure {weather_failures}/{MAX_WEATHER_FAILURES}): {e}")
        weather_data['description'] = "Connection error"
    
    except Exception as e:
        weather_failures += 1
        logger.error(f"Unexpected weather error (failure {weather_failures}/{MAX_WEATHER_FAILURES}): {e}")
        weather_data['description'] = "Error loading weather"


def create_display_image():
    """Create the clock/weather display image"""
    img = Image.new('RGB', (SCREEN_WIDTH, SCREEN_HEIGHT), BG_COLOR)
    draw = ImageDraw.Draw(img)
    
    try:
        font_time = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 60)
        font_date = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 20)
        font_temp = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 50)
        font_text = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 16)
        font_small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 12)
    except:
        font_time = font_date = font_temp = font_text = font_small = ImageFont.load_default()
    
    now = datetime.now()
    y = 20
    
    # Time (without seconds)
    time_str = now.strftime("%H:%M")
    bbox = draw.textbbox((0, 0), time_str, font=font_time)
    x = (SCREEN_WIDTH - (bbox[2] - bbox[0])) // 2
    draw.text((x, y), time_str, font=font_time, fill=TEXT_COLOR)
    y += bbox[3] - bbox[1] + 10
    
    # Date
    date_str = now.strftime("%A, %B %d")
    bbox = draw.textbbox((0, 0), date_str, font=font_date)
    x = (SCREEN_WIDTH - (bbox[2] - bbox[0])) // 2
    draw.text((x, y), date_str, font=font_date, fill=TEXT_COLOR)
    y += bbox[3] - bbox[1] + 20
    
    # Separator
    draw.line([(30, y), (SCREEN_WIDTH - 30, y)], fill=ACCENT_COLOR, width=2)
    y += 20
    
    # Location
    bbox = draw.textbbox((0, 0), LOCATION, font=font_small)
    x = (SCREEN_WIDTH - (bbox[2] - bbox[0])) // 2
    draw.text((x, y), LOCATION, font=font_small, fill=ACCENT_COLOR)
    y += bbox[3] - bbox[1] + 15
    
    # Temperature
    temp_str = f"{weather_data['temperature']}°C"
    bbox = draw.textbbox((0, 0), temp_str, font=font_temp)
    x = (SCREEN_WIDTH - (bbox[2] - bbox[0])) // 2
    draw.text((x, y), temp_str, font=font_temp, fill=ACCENT_COLOR)
    y += bbox[3] - bbox[1] + 10
    
    # Weather description
    desc = weather_data['description']
    bbox = draw.textbbox((0, 0), desc, font=font_text)
    x = (SCREEN_WIDTH - (bbox[2] - bbox[0])) // 2
    draw.text((x, y), desc, font=font_text, fill=TEXT_COLOR)
    y += bbox[3] - bbox[1] + 25
    
    # Details
    details = [
        f"Humidity: {weather_data['humidity']}%",
        f"Wind: {weather_data['wind_speed']} m/s"
    ]
    for detail in details:
        bbox = draw.textbbox((0, 0), detail, font=font_text)
        x = (SCREEN_WIDTH - (bbox[2] - bbox[0])) // 2
        draw.text((x, y), detail, font=font_text, fill=TEXT_COLOR)
        y += bbox[3] - bbox[1] + 8
    
    # Last update
    if weather_data['last_update']:
        update_str = f"Weather: {weather_data['last_update']}"
        bbox = draw.textbbox((0, 0), update_str, font=font_small)
        x = (SCREEN_WIDTH - (bbox[2] - bbox[0])) // 2
        draw.text((x, SCREEN_HEIGHT - 25), update_str, font=font_small, fill=(100, 100, 100))
    
    return img


def display_image(img, filename='/tmp/clock_display.png'):
    """Display image using fbi with proper error handling"""
    global fbi_process
    
    try:
        # Save image
        img.save(filename)
        logger.debug(f"Image saved to {filename}")
        
        # Kill existing fbi process
        if fbi_process and fbi_process.poll() is None:
            try:
                fbi_process.terminate()
                fbi_process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                fbi_process.kill()
                fbi_process.wait()
            except Exception as e:
                logger.warning(f"Error terminating FBI process: {e}")
        
        # Ensure framebuffer device exists
        if not os.path.exists('/dev/fb0'):
            logger.error("Framebuffer device /dev/fb0 not found")
            return False
        
        # Display with fbi
        fbi_process = subprocess.Popen([
            'fbi', '-T', '1', '-d', '/dev/fb0', '-noverbose', '-a', filename
        ], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        
        # Check if fbi started successfully
        time.sleep(0.1)
        if fbi_process.poll() is not None:
            stderr_output = fbi_process.stderr.read().decode() if fbi_process.stderr else ""
            logger.error(f"FBI failed to start: {stderr_output}")
            return False
        
        return True
        
    except Exception as e:
        logger.error(f"Error displaying image: {e}")
        return False


def cleanup(signum=None, frame=None):
    """Cleanup on exit with proper resource management"""
    global fbi_process, running
    
    logger.info("Shutting down gracefully...")
    running = False
    
    # Kill FBI process
    if fbi_process and fbi_process.poll() is None:
        try:
            fbi_process.terminate()
            fbi_process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            logger.warning("FBI process did not terminate, killing...")
            fbi_process.kill()
            fbi_process.wait()
        except Exception as e:
            logger.error(f"Error terminating FBI process: {e}")
    
    # Close session
    try:
        session.close()
    except Exception as e:
        logger.error(f"Error closing session: {e}")
    
    # Clear framebuffer
    try:
        if os.path.exists('/dev/fb0'):
            subprocess.run(['sudo', 'dd', 'if=/dev/zero', 'of=/dev/fb0', 'bs=1M', 'count=1'], 
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
            logger.info("Framebuffer cleared")
    except Exception as e:
        logger.warning(f"Could not clear framebuffer: {e}")
    
    logger.info("Cleanup completed")
    sys.exit(0)


def should_update_weather():
    """Check if weather should be updated"""
    current_time = time.time()
    time_since_last = current_time - last_weather_update
    
    # Update weather every 10 minutes, or if it's the first time
    if last_weather_update == 0 or time_since_last >= WEATHER_UPDATE_INTERVAL:
        return True
    
    # If there were failures, try again sooner
    if weather_failures > 0 and time_since_last >= 60:  # Retry after 1 minute on failure
        return True
    
    return False


def ensure_fbi_available():
    """Check if FBI is available on the system"""
    try:
        result = subprocess.run(['which', 'fbi'], capture_output=True, text=True)
        if result.returncode == 0:
            logger.info(f"FBI found at: {result.stdout.strip()}")
            return True
        else:
            logger.error("FBI not found. Install with: sudo apt-get install fbi")
            return False
    except Exception as e:
        logger.error(f"Error checking for FBI: {e}")
        return False


def main():
    """Main function with proper error handling and resource management"""
    global running
    
    try:
        logger.info("Starting Clock Weather FBI Application")
        
        # Setup signal handlers
        signal.signal(signal.SIGTERM, cleanup)
        signal.signal(signal.SIGINT, cleanup)
        atexit.register(cleanup)
        
        # Check if FBI is available
        if not ensure_fbi_available():
            logger.error("FBI not available, cannot start display")
            sys.exit(1)
        
        # Check framebuffer access
        if not os.path.exists('/dev/fb0'):
            logger.error("Framebuffer device /dev/fb0 not found")
            sys.exit(1)
        
        # Initial weather fetch
        logger.info("Fetching initial weather data...")
        fetch_weather()
        
        logger.info("Starting main display loop...")
        
        while running:
            try:
                # Update weather if needed
                if should_update_weather():
                    logger.info("Updating weather data...")
                    fetch_weather()
                
                # Create and display image
                img = create_display_image()
                if not display_image(img):
                    logger.warning("Failed to display image, retrying...")
                    time.sleep(2)
                    continue
                
                # Wait 30 seconds to reduce flickering
                time.sleep(30)
                
            except KeyboardInterrupt:
                logger.info("Interrupted by user")
                break
            except Exception as e:
                logger.error(f"Error in main loop: {e}")
                # Continue running unless it's a critical error
                time.sleep(2)
        
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        sys.exit(1)
    finally:
        cleanup()


if __name__ == "__main__":
    main()
