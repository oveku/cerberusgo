# PiTFT Display Configuration

## Current Settings

**Date Updated**: October 3, 2025  
**Display**: Adafruit PiTFT 3.5" Resistive Touchscreen

### Active Configuration

```ini
# In /boot/firmware/config.txt
dtparam=spi=on
dtoverlay=pitft35-resistive,rotate=270,speed=32000000,fps=30
```

### Display Specifications

- **Physical Resolution**: 480x320 pixels (landscape orientation)
- **Current Rotation**: 270 degrees
- **Effective Resolution**: 320x480 pixels (portrait orientation after rotation)
- **Framebuffer Device**: /dev/fb1
- **Touch Device**: /dev/input/eventX
- **SPI Speed**: 32 MHz
- **Refresh Rate**: 30 FPS

### Rotation Reference

The display can be rotated in 90-degree increments:

| Rotation | Orientation | Resolution | Notes |
|----------|-------------|------------|-------|
| 0° | Landscape (normal) | 480x320 | Connector at top |
| 90° | Portrait (right) | 320x480 | Connector on right |
| 180° | Landscape (inverted) | 480x320 | Connector at bottom |
| 270° | Portrait (left) | 320x480 | ✅ **CURRENT** - Connector on left |

### Console Configuration

```ini
# In /boot/firmware/cmdline.txt
fbcon=map:10 fbcon=font:VGA8x8
```

- `fbcon=map:10` - Maps console to fb1 (the TFT)
- `fbcon=font:VGA8x8` - Uses smaller font for better readability

### GPIO Pin Mapping

| Function | GPIO Pin | SPI Signal |
|----------|----------|------------|
| MOSI | GPIO 10 | SPI0 MOSI |
| MISO | GPIO 9 | SPI0 MISO |
| SCLK | GPIO 11 | SPI0 SCLK |
| CE0 | GPIO 8 | SPI0 CE0 |
| DC (Data/Command) | GPIO 25 | - |
| Reset | GPIO 24 | - |
| Backlight PWM | GPIO 18 | - |
| Touch IRQ | GPIO 17 | - |

## Quick Commands

### Display Information
```bash
# Check framebuffer devices
ls -la /dev/fb*

# Get framebuffer info
fbset -fb /dev/fb1

# Get detailed info
cat /sys/class/graphics/fb1/virtual_size
cat /sys/class/graphics/fb1/stride
```

### Test Display
```bash
# Display an image
fbi -T 1 -d /dev/fb1 -noverbose -a image.png

# Clear display (fill with black)
sudo dd if=/dev/zero of=/dev/fb1 bs=1M

# Fill with white
tr '\000' '\377' < /dev/zero | sudo dd of=/dev/fb1 bs=1M count=1

# Display test pattern
sudo cat /dev/urandom > /dev/fb1
```

### Test Touch
```bash
# List input devices
cat /proc/bus/input/devices | grep -A 5 "Touch"

# Test touch input (choose correct event number)
evtest /dev/input/event0

# Calibrate touchscreen (if needed)
TSLIB_FBDEVICE=/dev/fb1 TSLIB_TSDEVICE=/dev/input/event0 ts_calibrate
```

### Python Display Example
```python
from PIL import Image, ImageDraw, ImageFont

# Create 320x480 image (portrait after 270° rotation)
img = Image.new('RGB', (320, 480), color='black')
draw = ImageDraw.Draw(img)

# Draw some text
draw.text((10, 10), "CerberusGo", fill='white')

# Draw a rectangle
draw.rectangle([50, 50, 270, 430], outline='red', width=3)

# Display on TFT
img.save('/dev/fb1')
```

## Troubleshooting

### Display not working
```bash
# Check if fb1 exists
ls /dev/fb1

# Check SPI devices
ls /dev/spi*

# Check kernel messages
dmesg | grep -i "spi\|fb\|pitft"

# Verify config
cat /boot/firmware/config.txt | grep -i "spi\|pitft"
```

### Wrong resolution
The physical display is 480x320, but after 270° rotation it appears as 320x480 (portrait).

```bash
# Check current resolution
fbset -fb /dev/fb1

# Should show:
# geometry 320 480 320 480 16
```

### Touch not responding
```bash
# Find touch device
evtest

# Check device tree
dtoverlay -l | grep pitft

# Reload device tree (without reboot)
sudo dtoverlay -r pitft35-resistive
sudo dtoverlay pitft35-resistive rotate=270
```

### Backlight control
```bash
# Backlight is on GPIO 18
# Check current state
cat /sys/class/backlight/*/brightness

# Adjust brightness (0-255)
echo 128 | sudo tee /sys/class/backlight/*/brightness
```

## Configuration Files

### Primary Config
- **Path**: `/boot/firmware/config.txt`
- **Backup**: `/boot/firmware/config.txt.backup`

### Boot Parameters  
- **Path**: `/boot/firmware/cmdline.txt`
- **Backup**: `/boot/firmware/cmdline.txt.backup`

### Touch Calibration (if created)
- **Path**: `/etc/X11/xorg.conf.d/99-calibration.conf`

## Change Rotation

To change rotation, edit `/boot/firmware/config.txt`:

```bash
sudo nano /boot/firmware/config.txt

# Find the line:
dtoverlay=pitft35-resistive,rotate=270,speed=32000000,fps=30

# Change rotate value to: 0, 90, 180, or 270
# Save and reboot

sudo reboot
```

## Performance Tuning

### Increase SPI Speed
```ini
# Current: speed=32000000 (32 MHz)
# Can try: speed=48000000 (48 MHz) for faster refresh
# Max stable: speed=64000000 (64 MHz)
```

### Increase FPS
```ini
# Current: fps=30
# Can try: fps=60 for smoother updates
```

### Example optimized config
```ini
dtoverlay=pitft35-resistive,rotate=270,speed=48000000,fps=60
```

**Note**: Higher speeds may cause display instability. Test thoroughly.

## Resources

- **Project Docs**: `docs/hardware/ADAFRUIT_TFT_35.md`
- **Setup Guide**: `docs/setup/INSTALLATION.md`
- **Troubleshooting**: `docs/guides/TROUBLESHOOTING.md`
- **Test Scripts**: `scripts/test-display.sh`, `scripts/test-touch.sh`

---

**Last Updated**: October 3, 2025  
**Status**: ✅ Working - Rotation set to 270° (portrait, connector on left)  
**Resolution**: 320x480 (portrait orientation)
