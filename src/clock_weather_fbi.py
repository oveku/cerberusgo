#!/usr/bin/env python3
"""
Clock + Weather Display using fbi (framebuffer image viewer)
Generates PNG images and displays them on the PiTFT
"""

from PIL import Image, ImageDraw, ImageFont
import requests
from datetime import datetime
import time
import subprocess
import os
import signal

# Configuration
LOCATION = "Sandnes, Rogaland"
LATITUDE = 58.8516
LONGITUDE = 5.7351

SCREEN_WIDTH = 480
SCREEN_HEIGHT = 320
BG_COLOR = (26, 26, 46)
TEXT_COLOR = (234, 234, 234)
ACCENT_COLOR = (22, 199, 154)

weather_data = {
    'temperature': '--',
    'description': 'Loading...',
    'humidity': '--',
    'wind_speed': '--',
    'last_update': ''
}

fbi_process = None


def fetch_weather():
    """Fetch weather from Open-Meteo API"""
    global weather_data
    try:
        response = requests.get(
            "https://api.open-meteo.com/v1/forecast",
            params={
                'latitude': LATITUDE,
                'longitude': LONGITUDE,
                'current': 'temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code',
                'timezone': 'Europe/Oslo'
            },
            timeout=10
        )
        data = response.json()
        current = data.get('current', {})
        
        codes = {
            0: 'Clear', 1: 'Mainly clear', 2: 'Partly cloudy', 3: 'Overcast',
            45: 'Fog', 51: 'Light drizzle', 53: 'Drizzle', 55: 'Dense drizzle',
            61: 'Light rain', 63: 'Rain', 65: 'Heavy rain',
            71: 'Light snow', 73: 'Snow', 75: 'Heavy snow',
            80: 'Rain showers', 85: 'Snow showers', 95: 'Thunderstorm'
        }
        
        weather_data = {
            'temperature': f"{current.get('temperature_2m', '--')}",
            'description': codes.get(current.get('weather_code', 0), 'Unknown'),
            'humidity': f"{current.get('relative_humidity_2m', '--')}",
            'wind_speed': f"{current.get('wind_speed_10m', '--')}",
            'last_update': datetime.now().strftime("%H:%M")
        }
    except Exception as e:
        print(f"Weather error: {e}")


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
    
    # Time
    time_str = now.strftime("%H:%M:%S")
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
        f"Wind: {weather_data['wind_speed']} km/h"
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
    """Display image using fbi"""
    global fbi_process
    
    # Save image
    img.save(filename)
    
    # Kill existing fbi
    if fbi_process:
        try:
            fbi_process.kill()
        except:
            pass
    
    # Display with fbi
    fbi_process = subprocess.Popen([
        'fbi', '-T', '1', '-d', '/dev/fb0', '-noverbose', '-a', filename
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def cleanup(signum, frame):
    """Cleanup on exit"""
    global fbi_process
    if fbi_process:
        fbi_process.kill()
    # Clear screen
    subprocess.run(['sudo', 'dd', 'if=/dev/zero', 'of=/dev/fb0'], 
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    exit(0)


def main():
    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)
    
    # Initial weather fetch
    print("Fetching weather...")
    fetch_weather()
    
    weather_counter = 0
    
    print("Starting clock display...")
    while True:
        try:
            # Update weather every 10 minutes (600 seconds)
            if weather_counter >= 600:
                print("Updating weather...")
                fetch_weather()
                weather_counter = 0
            
            # Create and display image
            img = create_display_image()
            display_image(img)
            
            # Wait 1 second
            time.sleep(1)
            weather_counter += 1
            
        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"Error: {e}")
            time.sleep(1)
    
    cleanup(None, None)


if __name__ == "__main__":
    main()
