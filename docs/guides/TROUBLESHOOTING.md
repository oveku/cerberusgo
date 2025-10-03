# Troubleshooting Guide - Adafruit PiTFT 3.5" on Raspberry Pi 3B

## Table of Contents
1. [Display Issues](#display-issues)
2. [Touchscreen Issues](#touchscreen-issues)
3. [Performance Issues](#performance-issues)
4. [Boot Issues](#boot-issues)
5. [Software Issues](#software-issues)
6. [Diagnostic Commands](#diagnostic-commands)

---

## Display Issues

### Display Shows White/Blank Screen

**Symptoms**: Display backlight is on but screen is white or blank.

**Possible Causes**:
- Incorrect SPI configuration
- Driver not loaded
- Wrong device tree overlay
- Power supply issue

**Solutions**:
1. Check SPI is enabled:
   ```bash
   lsmod | grep spi
   sudo raspi-config  # Enable SPI in Interface Options
   ```

2. Verify device tree overlay in `/boot/config.txt`:
   ```bash
   cat /boot/config.txt | grep pitft
   ```
   Should contain: `dtoverlay=pitft35-resistive,rotate=90,speed=32000000,fps=30`

3. Check kernel messages:
   ```bash
   dmesg | grep -i tft
   dmesg | grep -i fb
   ```

4. Verify framebuffer exists:
   ```bash
   ls -l /dev/fb1
   ```

5. Test with known good image:
   ```bash
   sudo fbi -T 1 -d /dev/fb1 -noverbose -a /usr/share/pixmaps/debian-logo.png
   ```

### Display Not Detected (/dev/fb1 Missing)

**Symptoms**: Only `/dev/fb0` exists, no `/dev/fb1`.

**Solutions**:
1. Ensure SPI is enabled:
   ```bash
   ls /dev/spi*
   ```
   Should show `/dev/spidev0.0` and `/dev/spidev0.1`

2. Check device tree overlay is loaded:
   ```bash
   sudo dtoverlay -l
   ```
   Should list `pitft35-resistive`

3. Manually load overlay (testing):
   ```bash
   sudo dtoverlay pitft35-resistive rotate=90
   ```

4. Check for conflicting overlays in `/boot/config.txt`

5. Verify hardware connection - reseat the display

### Display Has Wrong Orientation

**Symptoms**: Display is rotated incorrectly.

**Solutions**:
1. Edit `/boot/config.txt`:
   ```bash
   sudo nano /boot/config.txt
   ```

2. Change rotate parameter:
   - `rotate=0` - Portrait (USB bottom)
   - `rotate=90` - Landscape (USB right)
   - `rotate=180` - Portrait inverted (USB top)
   - `rotate=270` - Landscape inverted (USB left)

3. Reboot:
   ```bash
   sudo reboot
   ```

### Display Flickers or Shows Artifacts

**Symptoms**: Display shows screen tearing, flickering, or graphical artifacts.

**Solutions**:
1. Reduce SPI speed in `/boot/config.txt`:
   ```ini
   dtoverlay=pitft35-resistive,rotate=90,speed=16000000,fps=25
   ```

2. Lower frame rate:
   ```ini
   dtoverlay=pitft35-resistive,rotate=90,speed=32000000,fps=20
   ```

3. Check power supply - use official 2.5A adapter

4. Check for overheating - add heat sink if needed

### Backlight Not Working

**Symptoms**: Display shows content but is very dim or black.

**Solutions**:
1. Check backlight control:
   ```bash
   ls /sys/class/backlight/
   ```

2. Manually set brightness:
   ```bash
   echo 255 | sudo tee /sys/class/backlight/soc\:backlight/brightness
   ```

3. Verify GPIO18 connection (backlight PWM pin)

4. Check 5V power supply to display

### Colors Look Wrong

**Symptoms**: Colors are inverted, washed out, or incorrect.

**Solutions**:
1. Check color depth in framebuffer:
   ```bash
   fbset -fb /dev/fb1
   ```

2. Try different color format in application code

3. Update display drivers:
   ```bash
   sudo apt update
   sudo apt upgrade
   ```

---

## Touchscreen Issues

### Touch Not Working at All

**Symptoms**: No touch response, no input events.

**Solutions**:
1. Check touch device exists:
   ```bash
   ls /dev/input/
   cat /proc/bus/input/devices | grep -A 5 STMPE
   ```

2. Test raw input:
   ```bash
   sudo evtest /dev/input/event0
   ```
   (Replace event0 with actual device)

3. Verify STMPE driver loaded:
   ```bash
   lsmod | grep stmpe
   ```

4. Check device tree configuration includes touch support

5. Verify GPIO17 connection (touch IRQ pin)

### Touch Coordinates Inverted or Wrong

**Symptoms**: Touch works but coordinates are inverted or incorrect.

**Solutions**:
1. Recalibrate touchscreen:
   ```bash
   DISPLAY=:0 xinput_calibrator
   ```

2. Check rotation matches display rotation

3. Edit `/etc/X11/xorg.conf.d/99-calibration.conf`:
   ```ini
   Section "InputClass"
       Identifier "calibration"
       MatchProduct "stmpe-ts"
       Option "Calibration" "3800 200 200 3800"
       Option "SwapAxes" "1"
   EndSection
   ```

4. For framebuffer apps, recalibrate with tslib:
   ```bash
   sudo TSLIB_FBDEVICE=/dev/fb1 TSLIB_TSDEVICE=/dev/input/event0 ts_calibrate
   ```

### Touch Requires Too Much Pressure

**Symptoms**: Need to press very hard for touch to register.

**Solutions**:
1. This is normal for resistive touchscreens
2. Calibrate to improve sensitivity
3. Use stylus instead of finger
4. Adjust touch threshold in driver (advanced)

### Touch Drift or Inaccuracy

**Symptoms**: Touch position drifts over time or is inconsistent.

**Solutions**:
1. Recalibrate touchscreen
2. Clean screen surface
3. Check for electrical interference
4. Verify proper grounding
5. Update to latest kernel

### Ghost Touches

**Symptoms**: Random touch events without touching screen.

**Solutions**:
1. Check for electrical noise/interference
2. Improve power supply quality
3. Add ferrite beads to cables
4. Ground the system properly
5. Check for physical damage to touchscreen

---

## Performance Issues

### Slow Display Updates

**Symptoms**: Display refresh is sluggish or laggy.

**Solutions**:
1. Increase SPI speed in `/boot/config.txt`:
   ```ini
   dtoverlay=pitft35-resistive,rotate=90,speed=40000000,fps=30
   ```
   (Don't exceed 48000000)

2. Optimize your code - use partial updates

3. Reduce color depth if possible

4. Disable FBCP if not needed

5. Use direct framebuffer access instead of X11

### High CPU Usage

**Symptoms**: CPU usage very high when display is active.

**Solutions**:
1. If using FBCP, this is expected (30-50% CPU)
2. Disable FBCP if not mirroring HDMI:
   ```bash
   sudo killall fbcp
   ```

3. Use static displays instead of video

4. Reduce frame rate:
   ```ini
   dtoverlay=pitft35-resistive,rotate=90,speed=32000000,fps=20
   ```

5. Optimize application code

### System Slow Overall

**Symptoms**: Entire system feels slow with display attached.

**Solutions**:
1. Ensure adequate power supply (2.5A minimum)

2. Check for undervoltage:
   ```bash
   vcgencmd get_throttled
   ```
   Result should be `0x0`

3. Monitor temperature:
   ```bash
   vcgencmd measure_temp
   ```
   Add heat sink if over 70°C

4. Disable unnecessary services:
   ```bash
   sudo systemctl disable bluetooth
   ```

5. Reduce GPU memory if not using HDMI:
   ```ini
   gpu_mem=16
   ```

---

## Boot Issues

### Raspberry Pi Won't Boot with Display Attached

**Symptoms**: Pi boots without display but not with it connected.

**Solutions**:
1. Check power supply - use 2.5A or higher

2. Test without display overlay:
   - Edit `/boot/config.txt`
   - Comment out: `#dtoverlay=pitft35-resistive...`
   - Reboot to verify Pi works
   - Uncomment and try again

3. Check for short circuits in GPIO connection

4. Try different SPI settings (lower speed)

### Boot Hangs on Rainbow Screen

**Symptoms**: Display shows rainbow test pattern and stops.

**Solutions**:
1. SD card or boot configuration issue

2. Check `/boot/cmdline.txt` for syntax errors

3. Verify `/boot/config.txt` syntax

4. Try fresh SD card with new OS image

### Console Not Showing on Display

**Symptoms**: Display works but boot messages don't appear.

**Solutions**:
1. Edit `/boot/cmdline.txt`:
   ```bash
   sudo nano /boot/cmdline.txt
   ```

2. Add at end of line (no newlines):
   ```
   fbcon=map:10 fbcon=font:VGA8x8
   ```

3. Reboot:
   ```bash
   sudo reboot
   ```

4. Manually switch console:
   ```bash
   con2fbmap 1 1
   ```

### Display Works but System Won't Boot to Desktop

**Symptoms**: Console works but X11 won't start.

**Solutions**:
1. Check X11 configuration:
   ```bash
   cat /var/log/Xorg.0.log
   ```

2. Remove conflicting X11 configs:
   ```bash
   sudo rm /etc/X11/xorg.conf
   ```

3. Verify framebuffer config:
   ```bash
   ls /usr/share/X11/xorg.conf.d/
   ```

4. Start X11 manually to see errors:
   ```bash
   FRAMEBUFFER=/dev/fb1 startx
   ```

---

## Software Issues

### Python Script Won't Display on PiTFT

**Symptoms**: Python pygame or PIL script shows on HDMI, not PiTFT.

**Solutions**:
1. Set environment variable:
   ```bash
   FRAMEBUFFER=/dev/fb1 python3 your_script.py
   ```

2. In Python code:
   ```python
   import os
   os.environ['SDL_FBDEV'] = '/dev/fb1'
   os.environ['SDL_VIDEODRIVER'] = 'fbcon'
   ```

3. For pygame, initialize display explicitly:
   ```python
   os.environ["SDL_FBDEV"] = "/dev/fb1"
   pygame.init()
   screen = pygame.display.set_mode((480, 320))
   ```

### X11 Application Not Using Touch Input

**Symptoms**: Touch works in terminal but not in X11 apps.

**Solutions**:
1. Verify calibration file exists:
   ```bash
   cat /etc/X11/xorg.conf.d/99-calibration.conf
   ```

2. Check xinput:
   ```bash
   DISPLAY=:0 xinput list
   ```

3. Recalibrate:
   ```bash
   DISPLAY=:0 xinput_calibrator
   ```

4. Restart X11:
   ```bash
   sudo systemctl restart lightdm
   ```

### FBCP Not Working

**Symptoms**: FBCP installed but not mirroring HDMI to PiTFT.

**Solutions**:
1. Check if running:
   ```bash
   ps aux | grep fbcp
   ```

2. Start manually:
   ```bash
   /usr/local/bin/fbcp &
   ```

3. Check for errors:
   ```bash
   /usr/local/bin/fbcp
   ```
   (runs in foreground)

4. Verify both framebuffers exist:
   ```bash
   ls /dev/fb*
   ```

5. Rebuild with correct settings:
   ```bash
   cd ~/rpi-fbcp/build
   cmake ..
   make
   sudo install fbcp /usr/local/bin/fbcp
   ```

---

## Diagnostic Commands

### Check Hardware Detection
```bash
# List SPI devices
ls /dev/spi*

# List framebuffers
ls /dev/fb*

# List input devices
ls /dev/input/

# Detailed input devices
cat /proc/bus/input/devices

# Check loaded modules
lsmod | grep -E "spi|fb|stmpe"

# Device tree overlays
sudo dtoverlay -l
```

### Check Display Status
```bash
# Framebuffer info
fbset -fb /dev/fb1

# Display kernel messages
dmesg | grep -i tft
dmesg | grep -i fb
dmesg | grep -i spi

# Check for errors
journalctl -xe | grep -i tft
```

### Check Configuration Files
```bash
# Boot config
cat /boot/config.txt | grep -E "spi|tft|display"

# Boot command line
cat /boot/cmdline.txt

# X11 config
ls /etc/X11/xorg.conf.d/
ls /usr/share/X11/xorg.conf.d/
```

### Test Commands
```bash
# Test display with image
sudo fbi -T 1 -d /dev/fb1 -noverbose -a /path/to/image.png

# Test touch input
sudo evtest /dev/input/event0

# Switch console to PiTFT
con2fbmap 1 1

# Switch console back to HDMI
con2fbmap 1 0

# Check system performance
vcgencmd measure_temp
vcgencmd get_throttled
vcgencmd measure_clock arm
```

### Power and Performance
```bash
# Check undervoltage
vcgencmd get_throttled
# 0x0 = good
# 0x50000 = throttled due to undervoltage

# Check temperature
vcgencmd measure_temp

# Check CPU frequency
vcgencmd measure_clock arm

# Monitor resources
htop
```

---

## Getting Help

### Before Asking for Help
1. Check all connections are secure
2. Verify power supply is adequate (2.5A+)
3. Update all software: `sudo apt update && sudo apt upgrade`
4. Review Adafruit forums for similar issues
5. Collect diagnostic information (see above)

### Useful Information to Provide
- Raspberry Pi model
- Raspberry Pi OS version: `cat /etc/os-release`
- Kernel version: `uname -a`
- Display model and revision
- Contents of `/boot/config.txt`
- Output of `dmesg | grep -i tft`
- Photo of hardware setup
- Exact error messages

### Resources
- [Adafruit Forums](https://forums.adafruit.com/viewforum.php?f=47)
- [Adafruit PiTFT Guide](https://learn.adafruit.com/adafruit-pitft-3-dot-5-touch-screen-for-raspberry-pi)
- [Raspberry Pi Forums](https://www.raspberrypi.org/forums/)
- [GitHub - fbtft](https://github.com/notro/fbtft)

---

## Common Error Messages

### "no such file or directory: /dev/fb1"
- Display driver not loaded
- SPI not enabled
- Check device tree overlay in `/boot/config.txt`

### "cannot open /dev/input/eventX: Permission denied"
- Need sudo for raw input access
- Or add user to input group: `sudo usermod -a -G input pi`

### "Failed to open framebuffer device"
- Check framebuffer exists: `ls /dev/fb1`
- Check permissions
- Try with sudo

### "XIO: fatal IO error"
- X11 server issue
- Check X11 logs: `/var/log/Xorg.0.log`
- Verify DISPLAY variable

---

**Troubleshooting Guide Version**: 1.0  
**Last Updated**: October 2, 2025
