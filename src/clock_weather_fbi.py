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

# Display configuration
WEATHER_DISPLAY_TIME = 20  # seconds
ADVISOR_DISPLAY_TIME = 10  # seconds
FORECAST_DISPLAY_TIME = 10  # seconds
TOTAL_CYCLE_TIME = WEATHER_DISPLAY_TIME + ADVISOR_DISPLAY_TIME + FORECAST_DISPLAY_TIME

# Joke API configuration
JOKE_API_URL = "https://official-joke-api.appspot.com/random_joke"
JOKE_UPDATE_INTERVAL = 1800  # 30 minutes in seconds

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
    'last_update': '',
    'forecast': {}  # Will store hourly forecast data
}

# Clothing advisor data
clothing_advice = {
    'recommendation': 'Loading advice...',
    'reason': 'Analyzing weather...',
    'last_update': ''
}

# Joke data
joke_data = {
    'setup': 'Loading joke...',
    'punchline': '',
    'last_update': 0
}

fbi_process = None
running = True
weather_failures = 0
last_weather_update = 0
last_joke_update = 0
display_start_time = 0
show_advisor_screen = False


def analyze_forecast(hourly_data):
    """Analyze hourly forecast data for clothing recommendations"""
    if not hourly_data:
        return {}
    
    temps = hourly_data.get('temperature_2m', [])
    precip = hourly_data.get('precipitation_probability', [])
    codes = hourly_data.get('weather_code', [])
    
    # Analyze next 12 hours (or available data)
    analysis_hours = min(12, len(temps))
    
    analysis = {
        'temp_range': (min(temps[:analysis_hours]),
                       max(temps[:analysis_hours])) if temps else (0, 0),
        'rain_chance': max(precip[:analysis_hours]) if precip else 0,
        'rain_hours': sum(1 for p in precip[:analysis_hours]
                          if p > 30) if precip else 0,
        'weather_codes': codes[:analysis_hours] if codes else []
    }
    
    return analysis


def update_clothing_advice():
    """Generate clothing recommendations based on weather forecast"""
    global clothing_advice
    
    forecast = weather_data.get('forecast', {})
    current_temp = float(weather_data.get('temperature', 0) or 0)
    
    if not forecast:
        clothing_advice = {
            'recommendation': 'Check weather manually',
            'reason': 'Weather forecast unavailable',
            'last_update': datetime.now().strftime("%H:%M")
        }
        return
    
    temp_min, temp_max = forecast.get('temp_range',
                                       (current_temp, current_temp))
    rain_chance = forecast.get('rain_chance', 0)
    rain_hours = forecast.get('rain_hours', 0)
    
    # Generate recommendation based on conditions
    recommendations = []
    reasons = []
    
    # Temperature recommendations
    if temp_max > 25:
        recommendations.append("Light clothing")
        reasons.append(f"High of {temp_max:.0f}°C")
    elif temp_max > 15:
        recommendations.append("Light jacket")
        reasons.append(f"Mild weather ({temp_max:.0f}°C)")
    elif temp_max > 5:
        recommendations.append("Warm jacket")
        reasons.append(f"Cool weather ({temp_max:.0f}°C)")
    else:
        recommendations.append("Winter coat")
        reasons.append(f"Cold weather ({temp_max:.0f}°C)")
    
    # Rain recommendations
    if rain_chance > 70 or rain_hours >= 3:
        recommendations.append("Raincoat + umbrella")
        reasons.append(f"{rain_chance}% rain chance")
    elif rain_chance > 40:
        recommendations.append("Umbrella")
        reasons.append(f"{rain_chance}% rain chance")
    
    # Wind recommendations
    wind_speed = weather_data.get('wind_speed', '--')
    if wind_speed != '--' and float(wind_speed) > 8:
        recommendations.append("Windproof layer")
        reasons.append(f"Windy ({wind_speed} m/s)")
    
    # Temperature change recommendations
    temp_diff = temp_max - temp_min
    if temp_diff > 10:
        recommendations.append("Layers for temp changes")
        reasons.append(f"{temp_diff:.0f}°C temperature swing")
    
    clothing_advice = {
        'recommendation': (" • ".join(recommendations[:3])
                          if recommendations else "Dress comfortably"),
        'reason': (" • ".join(reasons[:2])
                  if reasons else "Normal weather conditions"),
        'last_update': datetime.now().strftime("%H:%M")
    }


def fetch_joke():
    """Fetch a random joke from the internet"""
    global joke_data, last_joke_update
    
    try:
        logger.info("Fetching joke...")
        response = session.get(
            JOKE_API_URL,
            timeout=(CONNECT_TIMEOUT, READ_TIMEOUT)
        )
        response.raise_for_status()
        data = response.json()
        
        joke_data = {
            'setup': data.get('setup', 'Why did the weather app break?'),
            'punchline': data.get('punchline',
                                 'It had too many cloud storage issues!'),
            'last_update': time.time()
        }
        
        # Update the global last_joke_update timestamp
        last_joke_update = time.time()
        
        logger.info("Joke fetched successfully")
        
    except Exception as e:
        logger.warning(f"Failed to fetch joke: {e}")
        # Use a fallback weather-related joke
        joke_data = {
            'setup': 'What do you call a grumpy meteorologist?',
            'punchline': 'A person with a stormy disposition!',
            'last_update': time.time()
        }
        # Still update the timestamp even for fallback
        last_joke_update = time.time()


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
                'current': ('temperature_2m,relative_humidity_2m,'
                           'wind_speed_10m,weather_code'),
                'hourly': ('temperature_2m,precipitation_probability,'
                          'wind_speed_10m,weather_code'),
                'forecast_days': 1,
                'timezone': 'Europe/Oslo'
            },
            timeout=(CONNECT_TIMEOUT, READ_TIMEOUT)
        )
        response.raise_for_status()
        data = response.json()
        current = data.get('current', {})
        hourly = data.get('hourly', {})
        
        # Weather code descriptions
        codes = {
            0: 'Clear sky', 1: 'Mainly clear', 2: 'Partly cloudy',
            3: 'Overcast', 45: 'Foggy', 48: 'Rime fog',
            51: 'Light drizzle', 53: 'Drizzle', 55: 'Dense drizzle',
            61: 'Slight rain', 63: 'Rain', 65: 'Heavy rain',
            71: 'Slight snow', 73: 'Snow', 75: 'Heavy snow',
            77: 'Snow grains', 80: 'Rain showers', 81: 'Rain showers',
            82: 'Heavy rain showers', 85: 'Snow showers',
            86: 'Heavy snow showers', 95: 'Thunderstorm',
            96: 'Thunderstorm + hail', 99: 'Heavy thunderstorm'
        }
        
        weather_code = current.get('weather_code', 0)
        
        # Convert wind speed from km/h to m/s (divide by 3.6)
        wind_kmh = current.get('wind_speed_10m', 0)
        wind_ms = round(wind_kmh / 3.6, 1) if wind_kmh != 0 else '--'
        
        # Analyze forecast for clothing recommendations
        forecast_analysis = analyze_forecast(hourly)
        
        weather_data = {
            'temperature': f"{current.get('temperature_2m', '--')}",
            'description': codes.get(weather_code, 'Unknown'),
            'humidity': f"{current.get('relative_humidity_2m', '--')}",
            'wind_speed': f"{wind_ms}",
            'last_update': datetime.now().strftime("%H:%M"),
            'forecast': forecast_analysis,
            'hourly_raw': hourly  # Store raw hourly data for forecast screen
        }
        
        # Reset failure counter and update timestamp
        weather_failures = 0
        last_weather_update = time.time()
        
        # Update clothing advice based on new weather data
        update_clothing_advice()
        
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


def create_advisor_image():
    """Create the clothing advisor display image with joke"""
    img = Image.new('RGB', (SCREEN_WIDTH, SCREEN_HEIGHT), BG_COLOR)
    draw = ImageDraw.Draw(img)
    
    try:
        font_title = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 24)
        font_text = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 16)
        font_small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 12)
        font_joke = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 14)
    except:
        font_title = font_text = font_small = font_joke = ImageFont.load_default()
    
    y = 20
    
    # Title
    title = "What to Wear Today"
    bbox = draw.textbbox((0, 0), title, font=font_title)
    x = (SCREEN_WIDTH - (bbox[2] - bbox[0])) // 2
    draw.text((x, y), title, font=font_title, fill=ACCENT_COLOR)
    y += bbox[3] - bbox[1] + 20
    
    # Separator
    draw.line([(30, y), (SCREEN_WIDTH - 30, y)], fill=ACCENT_COLOR, width=2)
    y += 25
    
    # Clothing recommendation
    recommendation = clothing_advice['recommendation']
    # Wrap text for better display
    words = recommendation.split()
    lines = []
    current_line = []
    
    for word in words:
        test_line = ' '.join(current_line + [word])
        bbox = draw.textbbox((0, 0), test_line, font=font_text)
        if bbox[2] - bbox[0] > SCREEN_WIDTH - 40:  # Leave 20px margin on each side
            if current_line:
                lines.append(' '.join(current_line))
                current_line = [word]
            else:
                lines.append(word)
        else:
            current_line.append(word)
    
    if current_line:
        lines.append(' '.join(current_line))
    
    # Draw recommendation lines
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font_text)
        x = (SCREEN_WIDTH - (bbox[2] - bbox[0])) // 2
        draw.text((x, y), line, font=font_text, fill=TEXT_COLOR)
        y += bbox[3] - bbox[1] + 8
    
    y += 10
    
    # Reason
    reason_text = f"Because: {clothing_advice['reason']}"
    words = reason_text.split()
    lines = []
    current_line = []
    
    for word in words:
        test_line = ' '.join(current_line + [word])
        bbox = draw.textbbox((0, 0), test_line, font=font_small)
        if bbox[2] - bbox[0] > SCREEN_WIDTH - 40:
            if current_line:
                lines.append(' '.join(current_line))
                current_line = [word]
            else:
                lines.append(word)
        else:
            current_line.append(word)
    
    if current_line:
        lines.append(' '.join(current_line))
    
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font_small)
        x = (SCREEN_WIDTH - (bbox[2] - bbox[0])) // 2
        draw.text((x, y), line, font=font_small, fill=(150, 150, 150))
        y += bbox[3] - bbox[1] + 6
    
    y += 30
    
    # Separator for joke section
    draw.line([(30, y), (SCREEN_WIDTH - 30, y)], fill=(100, 100, 100), width=1)
    y += 20
    
    # Joke section
    joke_title = "😄 Daily Smile"
    bbox = draw.textbbox((0, 0), joke_title, font=font_text)
    x = (SCREEN_WIDTH - (bbox[2] - bbox[0])) // 2
    draw.text((x, y), joke_title, font=font_text, fill=ACCENT_COLOR)
    y += bbox[3] - bbox[1] + 15
    
    # Joke setup
    setup = joke_data['setup']
    words = setup.split()
    lines = []
    current_line = []
    
    for word in words:
        test_line = ' '.join(current_line + [word])
        bbox = draw.textbbox((0, 0), test_line, font=font_joke)
        if bbox[2] - bbox[0] > SCREEN_WIDTH - 40:
            if current_line:
                lines.append(' '.join(current_line))
                current_line = [word]
            else:
                lines.append(word)
        else:
            current_line.append(word)
    
    if current_line:
        lines.append(' '.join(current_line))
    
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font_joke)
        x = (SCREEN_WIDTH - (bbox[2] - bbox[0])) // 2
        draw.text((x, y), line, font=font_joke, fill=TEXT_COLOR)
        y += bbox[3] - bbox[1] + 6
    
    y += 8
    
    # Joke punchline
    punchline = joke_data['punchline']
    words = punchline.split()
    lines = []
    current_line = []
    
    for word in words:
        test_line = ' '.join(current_line + [word])
        bbox = draw.textbbox((0, 0), test_line, font=font_joke)
        if bbox[2] - bbox[0] > SCREEN_WIDTH - 40:
            if current_line:
                lines.append(' '.join(current_line))
                current_line = [word]
            else:
                lines.append(word)
        else:
            current_line.append(word)
    
    if current_line:
        lines.append(' '.join(current_line))
    
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font_joke)
        x = (SCREEN_WIDTH - (bbox[2] - bbox[0])) // 2
        draw.text((x, y), line, font=font_joke, fill=(200, 200, 200))
        y += bbox[3] - bbox[1] + 6
    
    # Update info at bottom
    update_str = f"Advice: {clothing_advice['last_update']}"
    bbox = draw.textbbox((0, 0), update_str, font=font_small)
    x = (SCREEN_WIDTH - (bbox[2] - bbox[0])) // 2
    draw.text((x, SCREEN_HEIGHT - 25), update_str, font=font_small, fill=(100, 100, 100))
    
    return img


def create_forecast_image():
    """Create the 24-hour forecast display with temperature graph"""
    img = Image.new('RGB', (SCREEN_WIDTH, SCREEN_HEIGHT), BG_COLOR)
    draw = ImageDraw.Draw(img)
    
    try:
        font_title = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 18)
        font_text = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 14)
        font_small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 11)
        font_tiny = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 9)
    except:
        font_title = font_text = font_small = font_tiny = ImageFont.load_default()
    
    y = 10
    
    # Title
    title = "24-Hour Forecast"
    bbox = draw.textbbox((0, 0), title, font=font_title)
    x = (SCREEN_WIDTH - (bbox[2] - bbox[0])) // 2
    draw.text((x, y), title, font=font_title, fill=ACCENT_COLOR)
    y += bbox[3] - bbox[1] + 10
    
    # Get forecast data
    hourly_data = weather_data.get('hourly_raw', {})
    if not hourly_data:
        error_msg = "Forecast data unavailable"
        bbox = draw.textbbox((0, 0), error_msg, font=font_text)
        x = (SCREEN_WIDTH - (bbox[2] - bbox[0])) // 2
        draw.text((x, y + 50), error_msg, font=font_text, fill=(150, 150, 150))
        return img
    
    # Get hourly data
    temps = hourly_data.get('temperature_2m', [])
    precip = hourly_data.get('precipitation_probability', [])
    wind_speeds = hourly_data.get('wind_speed_10m', [])
    
    if not temps:
        return img
    
    # Use next 24 hours
    hours_to_show = min(24, len(temps))
    temps_display = temps[:hours_to_show]
    precip_display = precip[:hours_to_show] if precip else [0] * hours_to_show
    wind_display = wind_speeds[:hours_to_show] if wind_speeds else [0] * hours_to_show
    
    # Calculate temperature range
    temp_min = min(temps_display)
    temp_max = max(temps_display)
    temp_range = max(temp_max - temp_min, 5)  # Minimum 5 degree range
    
    # Display high/low temps
    temp_info = f"High: {temp_max:.1f}°C    Low: {temp_min:.1f}°C"
    bbox = draw.textbbox((0, 0), temp_info, font=font_text)
    x = (SCREEN_WIDTH - (bbox[2] - bbox[0])) // 2
    draw.text((x, y), temp_info, font=font_text, fill=ACCENT_COLOR)
    y += bbox[3] - bbox[1] + 10
    
    # Graph area setup
    graph_top = y
    graph_bottom = SCREEN_HEIGHT - 80
    graph_height = graph_bottom - graph_top
    
    # Split screen: temperature graph (left), rain/wind (right)
    graph_left = 15
    graph_width = SCREEN_WIDTH // 2 - 20
    separator_x = SCREEN_WIDTH // 2
    right_start = separator_x + 10
    right_width = SCREEN_WIDTH // 2 - 20
    
    # Draw vertical separator
    draw.line([(separator_x, graph_top), (separator_x, graph_bottom)], 
              fill=(80, 80, 80), width=1)
    
    # LEFT SIDE: Temperature Graph
    # Draw temperature line graph
    points = []
    for i, temp in enumerate(temps_display):
        x_pos = graph_left + (i * graph_width // (hours_to_show - 1))
        # Normalize temperature to graph height
        y_pos = graph_bottom - int(((temp - temp_min) / temp_range) * graph_height)
        points.append((x_pos, y_pos))
    
    # Draw the temperature line
    if len(points) > 1:
        draw.line(points, fill=ACCENT_COLOR, width=2)
    
    # Draw points on the line
    for i, (px, py) in enumerate(points):
        # Draw a small circle at each point
        draw.ellipse([px-2, py-2, px+2, py+2], fill=ACCENT_COLOR)
        
        # Show temperature every 4 hours
        if i % 4 == 0:
            temp_label = f"{temps_display[i]:.0f}°"
            bbox = draw.textbbox((0, 0), temp_label, font=font_tiny)
            label_x = px - (bbox[2] - bbox[0]) // 2
            label_y = py - 15 if py > graph_top + 20 else py + 5
            draw.text((label_x, label_y), temp_label, 
                     font=font_tiny, fill=TEXT_COLOR)
    
    # Draw time labels on left (every 6 hours)
    current_hour = datetime.now().hour
    for i in range(0, hours_to_show, 6):
        hour = (current_hour + i) % 24
        hour_label = f"{hour:02d}h"
        x_pos = graph_left + (i * graph_width // (hours_to_show - 1))
        draw.text((x_pos - 10, graph_bottom + 3), hour_label, 
                 font=font_tiny, fill=(150, 150, 150))
    
    # RIGHT SIDE: Rain and Wind bars
    right_y = graph_top
    
    # Headers
    draw.text((right_start, right_y), "Rain", font=font_small, fill=TEXT_COLOR)
    draw.text((right_start + 60, right_y), "Wind", font=font_small, fill=TEXT_COLOR)
    right_y += 18
    
    # Show hourly rain/wind (every 2-3 hours to fit)
    step = max(2, hours_to_show // 12)  # Show ~12 entries
    bar_height = 12
    
    for i in range(0, hours_to_show, step):
        if right_y + bar_height > graph_bottom:
            break
            
        hour = (current_hour + i) % 24
        
        # Hour label
        draw.text((right_start, right_y), f"{hour:02d}h", 
                 font=font_tiny, fill=(150, 150, 150))
        
        # Rain bar (0-100%)
        rain_val = precip_display[i] if i < len(precip_display) else 0
        rain_bar_width = int((rain_val / 100) * 35)
        if rain_bar_width > 0:
            draw.rectangle([right_start + 28, right_y + 1, 
                          right_start + 28 + rain_bar_width, right_y + bar_height - 1],
                         fill=(100, 150, 255))
        draw.text((right_start + 66, right_y), f"{rain_val:.0f}%", 
                 font=font_tiny, fill=TEXT_COLOR)
        
        # Wind indicator (converted to m/s)
        wind_kmh = wind_display[i] if i < len(wind_display) else 0
        wind_ms = wind_kmh / 3.6
        wind_bar_width = int(min(wind_ms / 15, 1) * 35)  # Max 15 m/s
        if wind_bar_width > 0:
            draw.rectangle([right_start + 105, right_y + 1,
                          right_start + 105 + wind_bar_width, right_y + bar_height - 1],
                         fill=(150, 255, 150))
        draw.text((right_start + 143, right_y), f"{wind_ms:.1f}", 
                 font=font_tiny, fill=TEXT_COLOR)
        
        right_y += bar_height + 2
    
    # Update info at bottom
    update_str = f"Updated: {weather_data.get('last_update', '--')}"
    bbox = draw.textbbox((0, 0), update_str, font=font_tiny)
    x = (SCREEN_WIDTH - (bbox[2] - bbox[0])) // 2
    draw.text((x, SCREEN_HEIGHT - 15), update_str, 
             font=font_tiny, fill=(100, 100, 100))
    
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


def should_update_joke():
    """Check if joke should be updated"""
    current_time = time.time()
    time_since_last = current_time - last_joke_update
    
    # Update joke every 30 minutes, or if it's the first time
    if last_joke_update == 0 or time_since_last >= JOKE_UPDATE_INTERVAL:
        return True
    
    return False


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
    global running, display_start_time, show_advisor_screen, last_joke_update
    
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
        
        # Initial joke fetch
        logger.info("Fetching initial joke...")
        fetch_joke()
        
        # Initialize display timing
        display_start_time = time.time()
        show_advisor_screen = False
        
        logger.info("Starting main display loop...")
        
        while running:
            try:
                current_time = time.time()
                
                # Update weather if needed
                if should_update_weather():
                    logger.info("Updating weather data...")
                    fetch_weather()
                
                # Update joke if needed
                if should_update_joke():
                    logger.info("Updating joke...")
                    fetch_joke()
                
                # Determine which screen to show based on timing
                time_in_cycle = ((current_time - display_start_time) %
                                 TOTAL_CYCLE_TIME)
                
                if time_in_cycle < WEATHER_DISPLAY_TIME:
                    # Show weather screen
                    if show_advisor_screen:
                        show_advisor_screen = False
                        logger.debug("Switching to weather display")
                    img = create_display_image()
                elif time_in_cycle < WEATHER_DISPLAY_TIME + ADVISOR_DISPLAY_TIME:
                    # Show advisor screen
                    if not show_advisor_screen:
                        show_advisor_screen = True
                        logger.debug("Switching to advisor display")
                    img = create_advisor_image()
                else:
                    # Show forecast screen
                    if show_advisor_screen:
                        show_advisor_screen = False
                        logger.debug("Switching to forecast display")
                    img = create_forecast_image()
                
                if not display_image(img):
                    logger.warning("Failed to display image, retrying...")
                    time.sleep(2)
                    continue
                
                # Sleep for a short time to avoid excessive updates
                time.sleep(1)
                
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
