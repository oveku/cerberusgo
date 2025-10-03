#!/usr/bin/env python3
"""
Simple Tkinter Clock + Weather Display
Location: Sandnes, Rogaland, Norway
Designed for Raspberry Pi with Adafruit PiTFT 3.5" display (320x480 portrait)
"""

import tkinter as tk
import requests
from datetime import datetime
import threading

# Configuration
LOCATION = "Sandnes, Rogaland, Norway"
# Using Open-Meteo API (free, no API key required)
LATITUDE = 58.8516  # Sandnes coordinates
LONGITUDE = 5.7351

# Display settings for PiTFT 3.5" (320x480 portrait)
WINDOW_WIDTH = 320
WINDOW_HEIGHT = 480
BG_COLOR = "#1a1a2e"
TEXT_COLOR = "#eaeaea"
ACCENT_COLOR = "#16c79a"


class ClockWeatherApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Clock & Weather")
        self.root.geometry(f"{WINDOW_WIDTH}x{WINDOW_HEIGHT}")
        self.root.configure(bg=BG_COLOR)
        
        # Try fullscreen for embedded display
        try:
            self.root.attributes('-fullscreen', True)
        except tk.TclError:
            pass
        
        # Weather data
        self.weather_data = {
            'temperature': '--',
            'description': 'Loading...',
            'humidity': '--',
            'wind_speed': '--'
        }
        
        # Create UI
        self.create_widgets()
        
        # Start update loops
        self.update_clock()
        self.update_weather()
        
        # Allow exit with Escape key
        self.root.bind('<Escape>', lambda e: self.root.destroy())
    
    def create_widgets(self):
        # Time display (large)
        self.time_label = tk.Label(
            self.root,
            text="--:--:--",
            font=("Helvetica", 48, "bold"),
            fg=TEXT_COLOR,
            bg=BG_COLOR
        )
        self.time_label.pack(pady=(40, 10))
        
        # Date display
        self.date_label = tk.Label(
            self.root,
            text="Loading...",
            font=("Helvetica", 16),
            fg=TEXT_COLOR,
            bg=BG_COLOR
        )
        self.date_label.pack(pady=(0, 30))
        
        # Separator
        separator = tk.Frame(self.root, height=2, bg=ACCENT_COLOR)
        separator.pack(fill='x', padx=40, pady=10)
        
        # Location label
        location_label = tk.Label(
            self.root,
            text=LOCATION,
            font=("Helvetica", 12, "italic"),
            fg=ACCENT_COLOR,
            bg=BG_COLOR
        )
        location_label.pack(pady=(10, 5))
        
        # Temperature display (large)
        self.temp_label = tk.Label(
            self.root,
            text="-- °C",
            font=("Helvetica", 42, "bold"),
            fg=ACCENT_COLOR,
            bg=BG_COLOR
        )
        self.temp_label.pack(pady=(10, 5))
        
        # Weather description
        self.weather_desc_label = tk.Label(
            self.root,
            text="Loading weather...",
            font=("Helvetica", 14),
            fg=TEXT_COLOR,
            bg=BG_COLOR,
            wraplength=280
        )
        self.weather_desc_label.pack(pady=(0, 20))
        
        # Weather details frame
        details_frame = tk.Frame(self.root, bg=BG_COLOR)
        details_frame.pack(pady=10)
        
        # Humidity
        self.humidity_label = tk.Label(
            details_frame,
            text="💧 Humidity: --%",
            font=("Helvetica", 11),
            fg=TEXT_COLOR,
            bg=BG_COLOR
        )
        self.humidity_label.pack()
        
        # Wind speed
        self.wind_label = tk.Label(
            details_frame,
            text="💨 Wind: -- km/h",
            font=("Helvetica", 11),
            fg=TEXT_COLOR,
            bg=BG_COLOR
        )
        self.wind_label.pack(pady=(5, 0))
        
        # Last update label
        self.update_label = tk.Label(
            self.root,
            text="",
            font=("Helvetica", 8),
            fg="#666666",
            bg=BG_COLOR
        )
        self.update_label.pack(side='bottom', pady=10)
    
    def update_clock(self):
        """Update time and date display"""
        now = datetime.now()
        
        # Update time
        time_string = now.strftime("%H:%M:%S")
        self.time_label.config(text=time_string)
        
        # Update date
        date_string = now.strftime("%A, %B %d, %Y")
        self.date_label.config(text=date_string)
        
        # Schedule next update (every 1000ms = 1 second)
        self.root.after(1000, self.update_clock)
    
    def fetch_weather(self):
        """Fetch weather data from Open-Meteo API (runs in background thread)"""
        try:
            # Open-Meteo API endpoint (free, no API key needed)
            url = f"https://api.open-meteo.com/v1/forecast"
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
            
            # Weather code descriptions (WMO Weather interpretation codes)
            weather_codes = {
                0: 'Clear sky',
                1: 'Mainly clear',
                2: 'Partly cloudy',
                3: 'Overcast',
                45: 'Foggy',
                48: 'Depositing rime fog',
                51: 'Light drizzle',
                53: 'Moderate drizzle',
                55: 'Dense drizzle',
                61: 'Slight rain',
                63: 'Moderate rain',
                65: 'Heavy rain',
                71: 'Slight snow',
                73: 'Moderate snow',
                75: 'Heavy snow',
                77: 'Snow grains',
                80: 'Slight rain showers',
                81: 'Moderate rain showers',
                82: 'Violent rain showers',
                85: 'Slight snow showers',
                86: 'Heavy snow showers',
                95: 'Thunderstorm',
                96: 'Thunderstorm with hail',
                99: 'Thunderstorm with heavy hail'
            }
            
            weather_code = current.get('weather_code', 0)
            
            self.weather_data = {
                'temperature': f"{current.get('temperature_2m', '--')}",
                'description': weather_codes.get(weather_code, 'Unknown'),
                'humidity': f"{current.get('relative_humidity_2m', '--')}",
                'wind_speed': f"{current.get('wind_speed_10m', '--')}"
            }
            
            # Update UI in main thread
            self.root.after(0, self.update_weather_display)
            
        except requests.exceptions.RequestException as e:
            print(f"Weather fetch error: {e}")
            self.weather_data['description'] = "Connection error"
            self.root.after(0, self.update_weather_display)
        except Exception as e:
            print(f"Unexpected error: {e}")
            self.weather_data['description'] = "Error loading weather"
            self.root.after(0, self.update_weather_display)
    
    def update_weather_display(self):
        """Update weather display with fetched data"""
        self.temp_label.config(text=f"{self.weather_data['temperature']} °C")
        self.weather_desc_label.config(text=self.weather_data['description'])
        self.humidity_label.config(text=f"💧 Humidity: {self.weather_data['humidity']}%")
        self.wind_label.config(text=f"💨 Wind: {self.weather_data['wind_speed']} km/h")
        
        # Update timestamp
        update_time = datetime.now().strftime("%H:%M:%S")
        self.update_label.config(text=f"Updated: {update_time}")
    
    def update_weather(self):
        """Update weather data periodically"""
        # Fetch weather in background thread to avoid blocking UI
        thread = threading.Thread(target=self.fetch_weather, daemon=True)
        thread.start()
        
        # Schedule next update (every 10 minutes = 600000ms)
        self.root.after(600000, self.update_weather)


def main():
    root = tk.Tk()
    app = ClockWeatherApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
