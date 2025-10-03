#!/usr/bin/env python3
"""
Simple Framebuffer Clock + Weather Display (No X11 required)
Location: Sandnes, Rogaland, Norway
Uses pygame with framebuffer - runs directly on PiTFT without X server
"""

import os
import pygame
import requests
from datetime import datetime
import threading
import time

# Force pygame to use framebuffer
os.environ['SDL_VIDEODRIVER'] = 'fbcon'
os.environ['SDL_FBDEV'] = '/dev/fb0'
os.environ['SDL_NOMOUSE'] = '1'

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

class ClockWeatherApp:
    def __init__(self):
        pygame.init()
        
        # Initialize display
        self.screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
        pygame.display.set_caption("Clock & Weather")
        pygame.mouse.set_visible(False)
        
        # Fonts
        self.font_time = pygame.font.Font(None, 70)
        self.font_date = pygame.font.Font(None, 24)
        self.font_location = pygame.font.Font(None, 18)
        self.font_temp = pygame.font.Font(None, 60)
        self.font_desc = pygame.font.Font(None, 20)
        self.font_details = pygame.font.Font(None, 16)
        self.font_small = pygame.font.Font(None, 12)
        
        # Weather data
        self.weather_data = {
            'temperature': '--',
            'description': 'Loading...',
            'humidity': '--',
            'wind_speed': '--',
            'last_update': ''
        }
        
        # Start weather update thread
        self.running = True
        self.weather_thread = threading.Thread(target=self.weather_update_loop, daemon=True)
        self.weather_thread.start()
        
        # Clock
        self.clock = pygame.time.Clock()
    
    def weather_update_loop(self):
        """Background thread for weather updates"""
        while self.running:
            self.fetch_weather()
            # Wait 10 minutes before next update
            time.sleep(600)
    
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
            
            # Weather code descriptions
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
    
    def draw_text(self, text, font, color, x, y, center=False):
        """Helper to draw text"""
        surface = font.render(text, True, color)
        rect = surface.get_rect()
        if center:
            rect.centerx = x
        else:
            rect.x = x
        rect.y = y
        self.screen.blit(surface, rect)
        return rect.bottom
    
    def run(self):
        """Main loop"""
        try:
            while self.running:
                # Handle events
                for event in pygame.event.get():
                    if event.type == pygame.QUIT:
                        self.running = False
                    elif event.type == pygame.KEYDOWN:
                        if event.key == pygame.K_ESCAPE:
                            self.running = False
                
                # Clear screen
                self.screen.fill(BG_COLOR)
                
                # Get current time
                now = datetime.now()
                
                # Draw time (large, centered)
                time_str = now.strftime("%H:%M:%S")
                y_pos = self.draw_text(time_str, self.font_time, TEXT_COLOR, 
                                      SCREEN_WIDTH // 2, 30, center=True)
                
                # Draw date
                date_str = now.strftime("%A, %B %d, %Y")
                y_pos = self.draw_text(date_str, self.font_date, TEXT_COLOR,
                                      SCREEN_WIDTH // 2, y_pos + 10, center=True)
                
                # Draw separator line
                y_pos += 20
                pygame.draw.line(self.screen, ACCENT_COLOR, 
                               (40, y_pos), (SCREEN_WIDTH - 40, y_pos), 2)
                y_pos += 20
                
                # Draw location
                y_pos = self.draw_text(LOCATION, self.font_location, ACCENT_COLOR,
                                      SCREEN_WIDTH // 2, y_pos, center=True)
                
                # Draw temperature (large)
                temp_str = f"{self.weather_data['temperature']} °C"
                y_pos = self.draw_text(temp_str, self.font_temp, ACCENT_COLOR,
                                      SCREEN_WIDTH // 2, y_pos + 15, center=True)
                
                # Draw weather description
                y_pos = self.draw_text(self.weather_data['description'], 
                                      self.font_desc, TEXT_COLOR,
                                      SCREEN_WIDTH // 2, y_pos + 5, center=True)
                
                # Draw weather details
                y_pos += 30
                humidity_str = f"Humidity: {self.weather_data['humidity']}%"
                y_pos = self.draw_text(humidity_str, self.font_details, TEXT_COLOR,
                                      SCREEN_WIDTH // 2, y_pos, center=True)
                
                wind_str = f"Wind: {self.weather_data['wind_speed']} km/h"
                y_pos = self.draw_text(wind_str, self.font_details, TEXT_COLOR,
                                      SCREEN_WIDTH // 2, y_pos + 5, center=True)
                
                # Draw last update
                if self.weather_data['last_update']:
                    update_str = f"Updated: {self.weather_data['last_update']}"
                    self.draw_text(update_str, self.font_small, (100, 100, 100),
                                  SCREEN_WIDTH // 2, SCREEN_HEIGHT - 15, center=True)
                
                # Update display
                pygame.display.flip()
                
                # Control frame rate
                self.clock.tick(1)  # 1 FPS is enough for a clock
                
        finally:
            self.running = False
            pygame.quit()


if __name__ == "__main__":
    app = ClockWeatherApp()
    app.run()
