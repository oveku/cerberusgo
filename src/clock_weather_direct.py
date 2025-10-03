#!/usr/bin/env python3
"""
Simple Direct Framebuffer Clock + Weather Display
Location: Sandnes, Rogaland, Norway
Draws directly to /dev/fb0 using PIL - No X server or pygame needed
"""

import mmap
import struct
from PIL import Image, ImageDraw, ImageFont
import requests
from datetime import datetime
import threading
import time

# Configuration
LOCATION = "Sandnes, Rogaland, Norway"
LATITUDE = 58.8516
LONGITUDE = 5.7351

# Display settings for PiTFT 3.5" (320x480 portrait)
SCREEN_WIDTH = 320
SCREEN_HEIGHT = 480
BG_COLOR = (26, 26, 46)        # Dark blue
TEXT_COLOR = (234, 234, 234)   # Light gray
ACCENT_COLOR = (22, 199, 154)  # Teal


class FramebufferDisplay:
    def __init__(self):
        # Open framebuffer
        self.fb = open('/dev/fb0', 'rb+')
        self.fbmem = mmap.mmap(self.fb.fileno(), 0)
        
        # Create PIL image (RGB mode for 16-bit display)
        self.image = Image.new('RGB', (SCREEN_WIDTH, SCREEN_HEIGHT), BG_COLOR)
        self.draw = ImageDraw.Draw(self.image)
        
        # Load fonts (using default PIL font)
        try:
            self.font_time = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 56)
            self.font_date = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 18)
            self.font_location = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 14)
            self.font_temp = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 48)
            self.font_desc = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 16)
            self.font_details = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 14)
            self.font_small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 10)
        except:
            # Fallback to default font if TrueType not available
            self.font_time = ImageFont.load_default()
            self.font_date = ImageFont.load_default()
            self.font_location = ImageFont.load_default()
            self.font_temp = ImageFont.load_default()
            self.font_desc = ImageFont.load_default()
            self.font_details = ImageFont.load_default()
            self.font_small = ImageFont.load_default()
        
        # Weather data
        self.weather_data = {
            'temperature': '--',
            'description': 'Loading...',
            'humidity': '--',
            'wind_speed': '--',
            'last_update': ''
        }
        
        # Control
        self.running = True
        
        # Start weather thread
        self.weather_thread = threading.Thread(target=self.weather_loop, daemon=True)
        self.weather_thread.start()
    
    def weather_loop(self):
        """Background weather updates"""
        while self.running:
            self.fetch_weather()
            time.sleep(600)  # Update every 10 minutes
    
    def fetch_weather(self):
        """Fetch weather from Open-Meteo API"""
        try:
            url = "https://api.open-meteo.com/v1/forecast"
            params = {
                'latitude': LATITUDE,
                'longitude': LONGITUDE,
                'current': 'temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code',
                'timezone': 'Europe/Oslo'
            }
            
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            data = response.json()
            
            current = data.get('current', {})
            
            weather_codes = {
                0: 'Clear sky', 1: 'Mainly clear', 2: 'Partly cloudy', 3: 'Overcast',
                45: 'Foggy', 48: 'Rime fog', 51: 'Light drizzle', 53: 'Drizzle',
                55: 'Dense drizzle', 61: 'Slight rain', 63: 'Rain', 65: 'Heavy rain',
                71: 'Slight snow', 73: 'Snow', 75: 'Heavy snow', 77: 'Snow grains',
                80: 'Rain showers', 81: 'Rain showers', 82: 'Heavy rain showers',
                85: 'Snow showers', 86: 'Heavy snow showers', 95: 'Thunderstorm',
                96: 'Thunderstorm + hail', 99: 'Heavy thunderstorm'
            }
            
            weather_code = current.get('weather_code', 0)
            
            self.weather_data = {
                'temperature': f"{current.get('temperature_2m', '--')}",
                'description': weather_codes.get(weather_code, 'Unknown'),
                'humidity': f"{current.get('relative_humidity_2m', '--')}",
                'wind_speed': f"{current.get('wind_speed_10m', '--')}",
                'last_update': datetime.now().strftime("%H:%M:%S")
            }
            
        except Exception as e:
            print(f"Weather fetch error: {e}")
            self.weather_data['description'] = "Connection error"
    
    def draw_text_centered(self, text, font, color, y):
        """Draw centered text"""
        bbox = self.draw.textbbox((0, 0), text, font=font)
        text_width = bbox[2] - bbox[0]
        x = (SCREEN_WIDTH - text_width) // 2
        self.draw.text((x, y), text, font=font, fill=color)
        return y + (bbox[3] - bbox[1]) + 5
    
    def update_display(self):
        """Render the display"""
        # Clear image
        self.draw.rectangle([(0, 0), (SCREEN_WIDTH, SCREEN_HEIGHT)], fill=BG_COLOR)
        
        # Get current time
        now = datetime.now()
        
        # Draw time
        time_str = now.strftime("%H:%M:%S")
        y_pos = self.draw_text_centered(time_str, self.font_time, TEXT_COLOR, 25)
        
        # Draw date
        date_str = now.strftime("%A, %B %d")
        y_pos = self.draw_text_centered(date_str, self.font_date, TEXT_COLOR, y_pos)
        
        # Draw separator
        y_pos += 15
        self.draw.line([(40, y_pos), (SCREEN_WIDTH - 40, y_pos)], fill=ACCENT_COLOR, width=2)
        y_pos += 20
        
        # Draw location
        y_pos = self.draw_text_centered(LOCATION, self.font_location, ACCENT_COLOR, y_pos)
        
        # Draw temperature
        y_pos += 10
        temp_str = f"{self.weather_data['temperature']} C"
        y_pos = self.draw_text_centered(temp_str, self.font_temp, ACCENT_COLOR, y_pos)
        
        # Draw weather description
        y_pos = self.draw_text_centered(self.weather_data['description'], 
                                        self.font_desc, TEXT_COLOR, y_pos)
        
        # Draw details
        y_pos += 20
        humidity_str = f"Humidity: {self.weather_data['humidity']}%"
        y_pos = self.draw_text_centered(humidity_str, self.font_details, TEXT_COLOR, y_pos)
        
        wind_str = f"Wind: {self.weather_data['wind_speed']} km/h"
        y_pos = self.draw_text_centered(wind_str, self.font_details, TEXT_COLOR, y_pos + 5)
        
        # Draw last update
        if self.weather_data['last_update']:
            update_str = f"Updated: {self.weather_data['last_update']}"
            self.draw_text_centered(update_str, self.font_small, (100, 100, 100), SCREEN_HEIGHT - 20)
        
        # Convert to 16-bit RGB565 and write to framebuffer
        self.write_to_fb()
    
    def write_to_fb(self):
        """Write image to framebuffer in RGB565 format"""
        # Convert to RGB565
        rgb_image = self.image.convert('RGB')
        pixels = rgb_image.load()
        
        # Write to framebuffer
        self.fbmem.seek(0)
        for y in range(SCREEN_HEIGHT):
            for x in range(SCREEN_WIDTH):
                r, g, b = pixels[x, y]
                # Convert to RGB565
                rgb565 = ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)
                # Write as little-endian 16-bit value
                self.fbmem.write(struct.pack('H', rgb565))
    
    def run(self):
        """Main loop"""
        try:
            while self.running:
                self.update_display()
                time.sleep(1)  # Update once per second
        except KeyboardInterrupt:
            print("Stopping...")
        finally:
            self.running = False
            self.fbmem.close()
            self.fb.close()


if __name__ == "__main__":
    display = FramebufferDisplay()
    display.run()
