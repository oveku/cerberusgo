# CerberusGo

> Raspberry Pi 3B + Adafruit PiTFT 3.5" Clock & Weather Display

A complete project for setting up a Raspberry Pi 3B with an Adafruit PiTFT 3.5" resistive touchscreen as a standalone clock and weather station. Features automatic startup, direct framebuffer rendering, and real-time weather updates.

![Raspberry Pi 3B](https://img.shields.io/badge/Raspberry%20Pi-3B-C51A4A?logo=raspberry-pi)
![Python](https://img.shields.io/badge/Python-3.11-3776AB?logo=python)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Features

✅ **Clock Display** - Large, readable time display updating every second  
✅ **Weather Station** - Real-time weather for any location (default: Sandnes, Norway)  
✅ **Auto-Start** - Launches automatically on boot  
✅ **Direct Framebuffer** - No X server required, efficient rendering  
✅ **Free Weather API** - Uses Open-Meteo (no API key needed)  
✅ **Fully Documented** - Complete setup guides and troubleshooting  

## Hardware Requirements

- **Raspberry Pi 3 Model B** (1GB RAM)
- **Adafruit PiTFT 3.5" Resistive Touchscreen** (480x320, GPIO connection)
- **MicroSD Card** (16GB+ recommended)
- **Power Supply** (5V 2.5A minimum)
- **WiFi Connection** (for weather updates)

## Quick Start

### 1. Hardware Setup

1. Install Raspberry Pi OS (Bookworm or later) on SD card
2. Connect PiTFT to GPIO pins (see [hardware docs](docs/hardware/))
3. Boot Raspberry Pi and configure WiFi

### 2. Display Configuration

Add to `/boot/firmware/config.txt`:
```ini
dtparam=spi=on
dtoverlay=pitft35-resistive,rotate=270,speed=32000000,fps=30
```

Edit `/boot/firmware/cmdline.txt` - add:
```
fbcon=map:00 fbcon=font:VGA8x8
```

### 3. Install Clock & Weather App

```bash
# Clone repository
git clone https://github.com/yourusername/cerberusgo.git
cd cerberusgo

# Install dependencies (already included in Raspberry Pi OS)
sudo apt install -y python3-pil fbi

# Fix line endings if needed
sed -i 's/\r$//' src/clock_weather_fbi.py
chmod +x src/clock_weather_fbi.py

# Copy files to home directory
cp src/clock_weather_fbi.py ~/
cp config/clock-weather-fb.service ~/clock-weather.service

# Install systemd service
sudo mv ~/clock-weather.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable clock-weather.service
sudo systemctl start clock-weather.service
```

### 4. Verify

```bash
# Check service status
sudo systemctl status clock-weather

# View logs
sudo journalctl -u clock-weather -f
```

Your display should now show the clock and weather!

## Display Shows

- **Time**: HH:MM:SS format (updates every second)
- **Date**: Full date display
- **Location**: City name
- **Temperature**: Current temperature in Celsius
- **Weather**: Description (Clear, Rain, Snow, etc.)
- **Humidity**: Percentage
- **Wind Speed**: km/h
- **Last Update**: Timestamp of weather fetch

## Customization

### Change Location

Edit `~/clock_weather_fbi.py`:

```python
LOCATION = "Your City, Region"
LATITUDE = 58.8516   # Your latitude
LONGITUDE = 5.7351   # Your longitude
```

Restart service:
```bash
sudo systemctl restart clock-weather
```

### Change Colors

Modify color values (RGB):

```python
BG_COLOR = (26, 26, 46)        # Background
TEXT_COLOR = (234, 234, 234)   # Text
ACCENT_COLOR = (22, 199, 154)  # Accent
```

### Change Update Frequency

Default: Clock updates every 1 second, weather every 10 minutes

```python
time.sleep(1)              # Clock update interval
if weather_counter >= 600:  # Weather (600 = 10 minutes)
```

## Project Structure

```
cerberusgo/
├── src/                          # Source code
│   ├── clock_weather_fbi.py      # Main clock/weather app (WORKING)
│   ├── clock_weather.py          # Tkinter version (legacy)
│   └── simple-display-test.py    # Display testing
├── scripts/                      # Setup and utility scripts
│   ├── configure-cerberusgo-pi.sh
│   ├── scan-network.ps1
│   ├── deploy-pi-config.ps1
│   └── test-touch.sh
├── config/                       # Configuration files
│   ├── clock-weather-fb.service  # Systemd service
│   ├── xorg.conf.pitft          # X11 config (optional)
│   └── cmdline.txt.example       # Boot parameters example
├── docs/                         # Documentation
│   ├── hardware/                 # Hardware specifications
│   ├── setup/                    # Installation guides
│   └── guides/                   # Usage guides
├── tools/                        # Development tools
├── README.md                     # This file
├── CLOCK_WEATHER_FINAL.md        # Detailed clock app documentation
└── .gitignore                    # Git ignore rules
```

## Documentation

- **[Clock & Weather Final Guide](CLOCK_WEATHER_FINAL.md)** - Complete app documentation
- **[Display Configuration](DISPLAY_WORKING.md)** - Display setup details
- **[Hardware: Raspberry Pi 3B](docs/hardware/RASPBERRY_PI_3B.md)** - Pi specifications
- **[Hardware: PiTFT 3.5"](docs/hardware/ADAFRUIT_TFT_35.md)** - Display specifications
- **[Installation Guide](docs/setup/INSTALLATION.md)** - Detailed setup instructions
- **[Troubleshooting](docs/guides/TROUBLESHOOTING.md)** - Common issues and solutions

## Technical Details

### Display

- **Model**: Adafruit PiTFT 3.5" Resistive Touchscreen
- **Resolution**: 480x320 pixels (landscape)
- **Interface**: SPI (40-pin GPIO)
- **Controller**: HX8357D
- **Touch**: STMPE610 resistive touch controller
- **Rotation**: 270° (connector on left)

### Software

- **OS**: Raspberry Pi OS Bookworm (Debian 12)
- **Python**: 3.11
- **Display Method**: Direct framebuffer using `fbi` (framebuffer image viewer)
- **Weather API**: Open-Meteo (free, no registration)
- **Dependencies**: PIL/Pillow, requests, fbi

### Performance

- **CPU Usage**: ~20% (1 second updates)
- **Memory**: ~36 MB
- **Startup Time**: ~10 seconds after boot
- **Network Usage**: Minimal (weather API every 10 minutes)

## Weather API

Uses **[Open-Meteo](https://open-meteo.com/)** - Free weather API:

- ✅ No API key required
- ✅ No registration needed
- ✅ Reliable and fast
- ✅ WMO standard weather codes
- ✅ Worldwide coverage

## Service Management

```bash
# Check status
sudo systemctl status clock-weather

# Start service
sudo systemctl start clock-weather

# Stop service
sudo systemctl stop clock-weather

# Restart service
sudo systemctl restart clock-weather

# Enable auto-start
sudo systemctl enable clock-weather

# Disable auto-start
sudo systemctl disable clock-weather

# View logs (live)
sudo journalctl -u clock-weather -f

# View recent logs
sudo journalctl -u clock-weather -n 50
```

## Troubleshooting

### Display Not Working

1. **Check framebuffer**:
```bash
fbset -fb /dev/fb0
# Should show: geometry 480 320
```

2. **Test framebuffer directly**:
```bash
sudo dd if=/dev/urandom of=/dev/fb0 bs=153600 count=1
# Should show static on display
```

3. **Verify service is running**:
```bash
sudo systemctl status clock-weather
```

### Weather Not Updating

1. **Check internet connection**:
```bash
ping -c 4 8.8.8.8  # Google DNS
```

2. **Test API**:
```bash
curl "https://api.open-meteo.com/v1/forecast?latitude=58.8516&longitude=5.7351&current=temperature_2m"
```

### Black Screen

1. **Check if process is running**:
```bash
ps aux | grep clock_weather_fbi
```

2. **Check logs for errors**:
```bash
sudo journalctl -u clock-weather -n 50
```

3. **Manually run to see errors**:
```bash
sudo systemctl stop clock-weather
sudo python3 ~/clock_weather_fbi.py
```

More solutions in [Troubleshooting Guide](docs/guides/TROUBLESHOOTING.md).

## Development

### Testing Changes

```bash
# Stop service
sudo systemctl stop clock-weather

# Run manually
python3 ~/clock_weather_fbi.py

# Press Ctrl+C to stop

# If working, restart service
sudo systemctl start clock-weather
```

### Backup Configuration

```bash
# Backup app and service
cp ~/clock_weather_fbi.py ~/clock_weather_fbi.py.backup
sudo cp /etc/systemd/system/clock-weather.service ~/clock-weather.service.backup
```

## Network Configuration

Default network settings:
- **IP**: Configure static IP in your network range (e.g., 192.168.1.XXX)
- **Hostname**: cerberusgo
- **SSH**: Enabled on port 22

To connect:
```bash
ssh pi@YOUR_PI_IP
# Default password: raspberry (change for security!)
```

## Future Enhancements

Potential improvements:

- [ ] Touch interface for settings
- [ ] Multi-screen rotation (system stats, forecasts)
- [ ] Weather icons
- [ ] Temperature graphs
- [ ] Sunrise/sunset times
- [ ] Multi-day forecast
- [ ] Weather alerts
- [ ] Indoor sensor integration

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **Adafruit** - For excellent PiTFT hardware and documentation
- **Open-Meteo** - For free, reliable weather API
- **Raspberry Pi Foundation** - For amazing single-board computers
- **Debian/Raspberry Pi OS** - For solid Linux foundation

## Support

- **Issues**: Use GitHub Issues for bug reports
- **Documentation**: See `docs/` directory
- **Discussions**: Use GitHub Discussions for questions

## Project Status

**Status**: ✅ **Production Ready**

Tested and working on:
- Raspberry Pi 3 Model B
- Raspberry Pi OS Bookworm (Debian 12)
- Adafruit PiTFT 3.5" Resistive Touchscreen

Last updated: October 2025

---

**Made with ❤️ for the maker community**

If you find this project useful, please ⭐ star the repository!
