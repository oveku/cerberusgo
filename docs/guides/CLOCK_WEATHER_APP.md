# Clock & Weather Application

## Overview

Simple Tkinter-based clock and weather display designed for the Raspberry Pi with Adafruit PiTFT 3.5" display. Shows current time, date, and weather conditions for Sandnes, Rogaland, Norway.

## Features

- **Large Clock Display**: Shows current time (HH:MM:SS) and date
- **Weather Information**: 
  - Current temperature
  - Weather description (clear, cloudy, rain, etc.)
  - Humidity percentage
  - Wind speed
- **Automatic Updates**:
  - Clock updates every second
  - Weather updates every 10 minutes
- **Optimized Display**: Designed for 320x480 portrait orientation (PiTFT 3.5")
- **Free API**: Uses Open-Meteo API (no API key required)

## Installation

### 1. Install Required Packages

```bash
# Install pip if not already installed
sudo apt install python3-pip -y

# Install required Python packages
pip3 install tkinter requests pillow
```

Note: `tkinter` is usually pre-installed on Raspberry Pi OS, but this ensures it's available.

### 2. Upload the Script to Raspberry Pi

From your Windows machine:

```powershell
# Upload the script (replace <YOUR_PI_IP> with your Pi's IP address)
scp src/clock_weather.py pi@<YOUR_PI_IP>:~/

# Or upload to a specific directory
scp src/clock_weather.py pi@<YOUR_PI_IP>:~/projects/
```

### 3. Make the Script Executable

```bash
ssh pi@<YOUR_PI_IP>
chmod +x ~/clock_weather.py
```

## Usage

### Running from SSH (X11 Display)

If you want to run on the PiTFT display while connected via SSH:

```bash
# Set display to use PiTFT framebuffer
export DISPLAY=:0

# Run the application
python3 ~/clock_weather.py
```

### Running from Console

If logged into the Pi locally (on the PiTFT display):

```bash
# Install X server for framebuffer (if not already installed)
sudo apt install xserver-xorg-video-fbdev xinit -y

# Start X server on framebuffer
startx ~/clock_weather.py
```

### Auto-start on Boot

To automatically start the clock/weather app when the Pi boots:

1. Create a systemd service:

```bash
sudo nano /etc/systemd/system/clock-weather.service
```

2. Add the following content:

```ini
[Unit]
Description=Clock and Weather Display
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=pi
Environment=DISPLAY=:0
ExecStartPre=/bin/sleep 10
ExecStart=/usr/bin/python3 /home/pi/clock_weather.py
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

3. Enable and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable clock-weather.service
sudo systemctl start clock-weather.service
```

4. Check status:

```bash
sudo systemctl status clock-weather.service
```

## Configuration

### Change Location

Edit the coordinates in `clock_weather.py`:

```python
# Configuration
LOCATION = "Your City, Region, Country"
LATITUDE = 58.8516   # Change to your latitude
LONGITUDE = 5.7351   # Change to your longitude
```

To find coordinates:
- Use [OpenStreetMap](https://www.openstreetmap.org/)
- Search for your location
- Right-click and select "Show address" to see coordinates

### Adjust Display Size

If not using the PiTFT 3.5" display, adjust these values:

```python
# Display settings
WINDOW_WIDTH = 320   # Your display width
WINDOW_HEIGHT = 480  # Your display height
```

### Change Colors

Customize the color scheme:

```python
BG_COLOR = "#1a1a2e"      # Background color (dark blue)
TEXT_COLOR = "#eaeaea"    # Text color (light gray)
ACCENT_COLOR = "#16c79a"  # Accent color (teal)
```

### Weather Update Frequency

Change how often weather updates (default: 10 minutes):

```python
# In update_weather() method
self.root.after(600000, self.update_weather)  # 600000ms = 10 minutes
```

## Weather API

This application uses the **Open-Meteo API**, which is:
- ✅ **Free** - No API key required
- ✅ **No registration** needed
- ✅ **Reliable** - High availability
- ✅ **Comprehensive** - WMO standard weather codes

Weather codes interpreted:
- 0: Clear sky ☀️
- 1-3: Clear to overcast 🌤️
- 45-48: Fog 🌫️
- 51-55: Drizzle 🌦️
- 61-65: Rain 🌧️
- 71-77: Snow ❄️
- 80-82: Rain showers 🌧️
- 85-86: Snow showers 🌨️
- 95-99: Thunderstorm ⛈️

## Troubleshooting

### Display Not Showing

If the app runs but doesn't show on the PiTFT:

1. Check X server is configured for framebuffer:

```bash
# Create X11 config for fbdev
sudo nano /etc/X11/xorg.conf.d/99-fbdev.conf
```

Add:

```
Section "Device"
  Identifier "myfb"
  Driver "fbdev"
  Option "fbdev" "/dev/fb0"
EndSection
```

2. Restart X server or reboot

### Weather Not Loading

1. Check internet connection:

```bash
ping -c 4 8.8.8.8  # Test internet connectivity
```

2. Test API directly:

```bash
curl "https://api.open-meteo.com/v1/forecast?latitude=58.8516&longitude=5.7351&current=temperature_2m"
```

3. Check firewall isn't blocking requests

### Font Issues

If fonts look wrong, install additional fonts:

```bash
sudo apt install fonts-dejavu fonts-liberation -y
```

### Exit the Application

- Press `Escape` key
- Or: `Ctrl+C` in terminal if running from command line
- Or: `sudo systemctl stop clock-weather.service` if running as service

## Testing on Windows

You can test the application on your Windows machine before deploying:

1. Install Python 3 (if not already installed)
2. Install dependencies:

```powershell
pip install requests pillow
```

3. Run the script:

```powershell
python src\clock_weather.py
```

Note: The display will open in a window on Windows rather than fullscreen.

## Screen Layout

```
┌─────────────────────────┐
│                         │
│       14:23:45          │  ← Large time display
│  Friday, October 3      │  ← Date
│                         │
│  ───────────────────    │  ← Separator
│                         │
│  Sandnes, Rogaland...   │  ← Location
│                         │
│        18 °C            │  ← Temperature (large)
│    Partly cloudy        │  ← Weather description
│                         │
│  💧 Humidity: 65%       │  ← Humidity
│  💨 Wind: 12 km/h       │  ← Wind speed
│                         │
│                         │
│  Updated: 14:23:00      │  ← Last update time
└─────────────────────────┘
```

## Files

- `src/clock_weather.py` - Main application script
- `docs/guides/CLOCK_WEATHER_APP.md` - This documentation

## Next Steps

1. Install dependencies on Pi
2. Upload script to Pi
3. Test the application
4. Optionally set up auto-start on boot
5. Customize colors/layout as desired

## Resources

- [Open-Meteo API Documentation](https://open-meteo.com/en/docs)
- [Tkinter Documentation](https://docs.python.org/3/library/tkinter.html)
- [WMO Weather Codes](https://www.nodc.noaa.gov/archive/arc0021/0002199/1.1/data/0-data/HTML/WMO-CODE/WMO4677.HTM)
