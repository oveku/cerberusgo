# Raspberry Pi 3B + Adafruit PiTFT 3.5" - Installation Guide

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Hardware Assembly](#hardware-assembly)
3. [Initial Raspberry Pi Setup](#initial-raspberry-pi-setup)
4. [Display Driver Installation](#display-driver-installation)
5. [Touchscreen Configuration](#touchscreen-configuration)
6. [Display Configuration](#display-configuration)
7. [Testing and Verification](#testing-and-verification)
8. [Optional Configurations](#optional-configurations)

---

## Prerequisites

### Hardware Required
- Raspberry Pi 3 Model B
- Adafruit PiTFT 3.5" Resistive Touchscreen
- MicroSD card (16GB or larger, Class 10 recommended)
- 5V 2.5A power supply (official Raspberry Pi adapter recommended)
- USB keyboard and mouse (for initial setup)
- HDMI monitor (for initial setup)
- Ethernet cable or Wi-Fi connection

### Software Required
- Raspberry Pi OS (32-bit, Lite or Desktop)
- Balena Etcher or Raspberry Pi Imager
- SSH client (PuTTY for Windows, or native terminal for Linux/Mac)

### Time Required
- Hardware assembly: 10-15 minutes
- Software installation: 30-60 minutes
- Configuration and testing: 15-30 minutes

---

## Hardware Assembly

### Step 1: Prepare the Raspberry Pi
1. Power off your Raspberry Pi completely
2. Disconnect all cables and peripherals
3. Place the Pi on a clean, static-free surface

### Step 2: Inspect the PiTFT Display
1. Examine the 40-pin female header on the bottom of the PiTFT
2. Check for any bent or damaged pins
3. Locate the GPIO pin 1 marker (usually a square pad or label)

### Step 3: Align and Connect
1. Align the PiTFT's 40-pin header with the Raspberry Pi's GPIO pins
2. Ensure pin 1 on the display matches pin 1 on the Pi (corner near SD card)
3. Gently but firmly press the display onto the GPIO header
4. Verify all 40 pins are properly seated

### Step 4: Secure the Display (Optional but Recommended)
1. Use 11mm nylon standoffs or spacers
2. Install at all four mounting holes
3. Secure with M2.5 screws
4. Do not overtighten; hand-tight is sufficient

### Step 5: Visual Inspection
- All pins should be fully inserted
- Display should be parallel to the Pi board
- No visible gaps between header and socket
- Check that no pins are bent or exposed

### Safety Notes
- Handle by the edges to avoid touching components
- Ground yourself before handling to prevent ESD damage
- Never connect/disconnect while powered on

---

## Initial Raspberry Pi Setup

### Step 1: Flash Raspberry Pi OS
1. Download Raspberry Pi OS from [raspberrypi.org/software](https://www.raspberrypi.org/software/)
   - Recommended: Raspberry Pi OS (32-bit) with desktop
   - Alternative: Raspberry Pi OS Lite for headless setup
2. Flash to microSD card using Raspberry Pi Imager or Balena Etcher
3. Enable SSH (optional for headless setup):
   - Create empty file named `ssh` in boot partition
4. Configure Wi-Fi (optional for headless setup):
   - Create `wpa_supplicant.conf` in boot partition

**wpa_supplicant.conf example:**
```
country=US
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="YOUR_WIFI_SSID"
    psk="YOUR_WIFI_PASSWORD"
    key_mgmt=WPA-PSK
}
```

### Step 2: First Boot
1. Insert microSD card into Raspberry Pi
2. Connect HDMI monitor, keyboard, and mouse
3. Connect power supply
4. Wait for system to boot (1-2 minutes)
5. Follow on-screen setup wizard (if using Desktop version)

### Step 3: Update System
```bash
sudo apt update
sudo apt upgrade -y
```

This may take 10-30 minutes depending on connection speed.

### Step 4: Enable SPI Interface
```bash
sudo raspi-config
```

Navigate to:
- **3 Interface Options** → **P4 SPI** → **Yes** → **OK** → **Finish**

Or enable via command line:
```bash
sudo raspi-config nonint do_spi 0
```

### Step 5: Reboot
```bash
sudo reboot
```

---

## Display Driver Installation

### Method 1: Adafruit Easy Install Script (Recommended)

#### Step 1: Download the Script
```bash
cd ~
wget https://raw.githubusercontent.com/adafruit/Raspberry-Pi-Installer-Scripts/master/adafruit-pitft.sh
chmod +x adafruit-pitft.sh
```

#### Step 2: Run the Installer
```bash
sudo ./adafruit-pitft.sh
```

#### Step 3: Follow Prompts
1. Select display type: **4** (PiTFT 3.5" resistive touch)
2. Select rotation:
   - **1** - 90 degrees (landscape, USB ports on right)
   - **2** - 180 degrees (portrait, USB ports on top)
   - **3** - 270 degrees (landscape, USB ports on left)
   - **4** - 0 degrees (portrait, USB ports on bottom)
3. Choose console output:
   - **Y** - Display console on PiTFT
   - **N** - Keep console on HDMI
4. HDMI mirror (FBCP):
   - **Y** - Mirror HDMI to PiTFT (useful for desktop)
   - **N** - Use PiTFT as separate display
5. Reboot when prompted

### Method 2: Manual Installation

#### Step 1: Install Required Packages
```bash
sudo apt-get install -y python3-pip python3-pil python3-numpy
sudo pip3 install --upgrade adafruit-python-shell
```

#### Step 2: Configure Device Tree Overlay
Edit `/boot/config.txt`:
```bash
sudo nano /boot/config.txt
```

Add at the end:
```ini
# Enable SPI
dtparam=spi=on

# PiTFT 3.5" Display Configuration
dtoverlay=pitft35-resistive,rotate=90,speed=32000000,fps=30
```

**Rotation values:**
- `rotate=0` - Portrait (default)
- `rotate=90` - Landscape (USB right)
- `rotate=180` - Portrait inverted
- `rotate=270` - Landscape inverted (USB left)

#### Step 3: Configure Console (Optional)
Edit `/boot/cmdline.txt`:
```bash
sudo nano /boot/cmdline.txt
```

Add to the end of the line (do not add new lines):
```
fbcon=map:10 fbcon=font:VGA8x8
```

#### Step 4: Reboot
```bash
sudo reboot
```

---

## Touchscreen Configuration

### Step 1: Verify Touch Device
After reboot, check that the touch device is detected:
```bash
ls /dev/input/
```

You should see devices like `event0`, `event1`, etc.

Identify the touch device:
```bash
cat /proc/bus/input/devices | grep -A 5 "STMPE"
```

### Step 2: Test Raw Touch Input
```bash
sudo apt-get install -y evtest
sudo evtest /dev/input/event0
```

(Replace `event0` with your actual touch device)

Touch the screen and verify that events are registered.

### Step 3: Install Calibration Tools
```bash
sudo apt-get install -y xinput-calibrator
```

### Step 4: Calibrate Touchscreen (X11 Environment)
If running X11 desktop:
```bash
DISPLAY=:0 xinput_calibrator
```

Follow on-screen instructions to touch the calibration points.

The output will show configuration to add to:
`/etc/X11/xorg.conf.d/99-calibration.conf`

**Example calibration file:**
```bash
sudo mkdir -p /etc/X11/xorg.conf.d
sudo nano /etc/X11/xorg.conf.d/99-calibration.conf
```

```
Section "InputClass"
    Identifier "calibration"
    MatchProduct "stmpe-ts"
    Option "Calibration" "3800 200 200 3800"
    Option "SwapAxes" "1"
EndSection
```

### Step 5: Calibrate for Framebuffer (tslib)
For non-X11 applications:
```bash
sudo apt-get install -y tslib libts-bin
sudo TSLIB_FBDEVICE=/dev/fb1 TSLIB_TSDEVICE=/dev/input/event0 ts_calibrate
```

Results are saved to `/etc/pointercal`.

---

## Display Configuration

### Configure X11 to Use PiTFT

#### Method 1: Set as Primary Display
Create `/usr/share/X11/xorg.conf.d/99-fbdev.conf`:
```bash
sudo nano /usr/share/X11/xorg.conf.d/99-fbdev.conf
```

Add:
```
Section "Device"
    Identifier "Adafruit PiTFT"
    Driver "fbdev"
    Option "fbdev" "/dev/fb1"
EndSection
```

#### Method 2: Dual Display Setup
Keep HDMI as primary, use PiTFT as secondary.
(Advanced configuration - see Adafruit guides)

### Configure Display Rotation in Software
If you need to change rotation after installation:

Edit `/boot/config.txt`:
```bash
sudo nano /boot/config.txt
```

Modify the `rotate` parameter in the dtoverlay line:
```ini
dtoverlay=pitft35-resistive,rotate=270,speed=32000000,fps=30
```

Reboot after changes:
```bash
sudo reboot
```

### Adjust Backlight Brightness
The backlight is controlled via PWM on GPIO18.

Create a script to adjust brightness:
```bash
sudo nano /usr/local/bin/set-backlight
```

```bash
#!/bin/bash
# Set backlight brightness (0-255)
echo $1 > /sys/class/backlight/soc:backlight/brightness
```

Make executable:
```bash
sudo chmod +x /usr/local/bin/set-backlight
```

Usage:
```bash
sudo /usr/local/bin/set-backlight 128  # 50% brightness
sudo /usr/local/bin/set-backlight 255  # 100% brightness
```

---

## Testing and Verification

### Test 1: Check Framebuffer Device
```bash
ls -l /dev/fb*
```

Should show `/dev/fb0` (HDMI) and `/dev/fb1` (PiTFT).

### Test 2: Display Information
```bash
fbset -fb /dev/fb1
```

Should show 480x320 resolution.

### Test 3: Display Test Pattern
```bash
sudo apt-get install -y fbi
sudo fbi -T 1 -d /dev/fb1 -noverbose -a /usr/share/pixmaps/debian-logo.png
```

### Test 4: Console Output
Switch console to PiTFT:
```bash
con2fbmap 1 1
```

Switch back to HDMI:
```bash
con2fbmap 1 0
```

### Test 5: X11 Display Test
If running desktop environment:
```bash
FRAMEBUFFER=/dev/fb1 startx
```

### Test 6: Touch Response
```bash
sudo evtest /dev/input/event0
```

Touch various points on the screen and verify coordinates.

---

## Optional Configurations

### Install FBCP (Framebuffer Copy) for HDMI Mirroring

#### Step 1: Install cmake and build tools
```bash
sudo apt-get install -y cmake git
```

#### Step 2: Clone and Build
```bash
cd ~
git clone https://github.com/tasanakorn/rpi-fbcp
cd rpi-fbcp
mkdir build
cd build
cmake ..
make
sudo install fbcp /usr/local/bin/fbcp
```

#### Step 3: Auto-start FBCP
```bash
sudo nano /etc/rc.local
```

Add before `exit 0`:
```bash
/usr/local/bin/fbcp &
```

### Configure Auto-Login to Console
```bash
sudo raspi-config
```

Navigate to: **1 System Options** → **S5 Boot / Auto Login** → **B2 Console Autologin**

### Install Python Libraries for Display Development
```bash
sudo apt-get install -y python3-pip python3-pil python3-numpy
sudo pip3 install pygame
sudo apt-get install -y python3-rpi.gpio
```

### Install Useful Tools
```bash
# Image viewing
sudo apt-get install -y fbi fim

# System monitoring
sudo apt-get install -y htop

# Screen capture
sudo apt-get install -y scrot

# Video playback (omxplayer for framebuffer)
sudo apt-get install -y omxplayer
```

### Performance Optimization

#### Reduce GPU Memory (if not using HDMI)
Edit `/boot/config.txt`:
```bash
sudo nano /boot/config.txt
```

Add:
```ini
gpu_mem=16
```

#### Disable Unused Services
```bash
# Disable Bluetooth if not needed
sudo systemctl disable bluetooth
sudo systemctl disable hciuart

# Disable WiFi if using Ethernet
sudo systemctl disable wpa_supplicant
```

### Create Custom Boot Splash
Replace boot text with custom image:
```bash
sudo apt-get install -y fbi
```

Create `/etc/systemd/system/splashscreen.service`:
```ini
[Unit]
Description=Splash Screen
DefaultDependencies=no
After=local-fs.target

[Service]
ExecStart=/usr/bin/fbi -d /dev/fb1 -T 1 -noverbose -a /home/pi/splash.png
StandardInput=tty
StandardOutput=tty

[Install]
WantedBy=sysinit.target
```

Enable:
```bash
sudo systemctl enable splashscreen
```

---

## Next Steps

1. Review the troubleshooting guide: `docs/guides/TROUBLESHOOTING.md`
2. Explore Python examples for touch interfaces
3. Configure auto-start for your applications
4. Set up remote access (VNC/SSH)
5. Develop custom applications for the display

## Related Documentation

- Hardware specifications: `docs/hardware/`
- Configuration templates: `config/`
- Setup scripts: `scripts/`
- Usage guides: `docs/guides/`

---

## Quick Reference Commands

```bash
# Check SPI status
ls /dev/spi*

# Check framebuffer
ls /dev/fb*

# Check display info
fbset -fb /dev/fb1

# Check touch device
evtest /dev/input/event0

# Reboot
sudo reboot

# Edit boot config
sudo nano /boot/config.txt

# View system logs
dmesg | grep -i tft
journalctl -xe
```

---

## Installation Checklist

- [ ] Hardware properly connected
- [ ] Raspberry Pi OS installed and updated
- [ ] SPI interface enabled
- [ ] Display drivers installed
- [ ] Display showing output
- [ ] Touch device detected
- [ ] Touch calibration completed
- [ ] Test applications working
- [ ] Auto-start configured (if desired)
- [ ] Documentation reviewed

---

**Installation Guide Version**: 1.0  
**Last Updated**: October 2, 2025  
**Tested On**: Raspberry Pi OS (Bullseye), Raspberry Pi 3 Model B
