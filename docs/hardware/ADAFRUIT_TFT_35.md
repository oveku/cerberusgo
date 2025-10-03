# Adafruit PiTFT 3.5" Resistive Touchscreen - Technical Specifications

## Overview
The Adafruit PiTFT 3.5" is a resistive touchscreen display designed specifically for Raspberry Pi. It connects directly to the 40-pin GPIO header and provides a compact display solution with touch input.

## Product Information
- **Product ID**: 2441 (with resistive touch)
- **Manufacturer**: Adafruit Industries
- **Type**: TFT LCD with resistive touchscreen
- **Interface**: SPI (Serial Peripheral Interface)

## Display Specifications

### Screen
- **Size**: 3.5 inches (diagonal)
- **Resolution**: 480 × 320 pixels
- **Aspect Ratio**: 3:2 (landscape orientation)
- **Pixel Density**: ~165 PPI
- **Technology**: TFT (Thin Film Transistor) LCD
- **Color Depth**: 18-bit (262,144 colors)
- **Viewing Angle**: 160° typical

### Display Controller
- **Chip**: HX8357D
- **Interface**: SPI (4-wire serial)
- **Maximum SPI Speed**: 32 MHz (typically runs at 16-32 MHz)
- **Frame Rate**: ~20-50 FPS depending on update method

### Backlight
- **Type**: LED backlight
- **Control**: PWM via GPIO18
- **Power**: 5V supply
- **Current Draw**: ~100-120mA at full brightness
- **Dimmable**: Yes, via PWM

## Touchscreen Specifications

### Touch Technology
- **Type**: 4-wire resistive touch
- **Controller**: STMPE610
- **Interface**: SPI
- **Touch Points**: Single touch (no multi-touch)
- **Pressure Sensitivity**: Yes (resistive technology)

### Touch Controller (STMPE610)
- **Resolution**: 12-bit (4096 × 4096 theoretical)
- **Sampling Rate**: Configurable, typically 80-100 Hz
- **Interrupt**: Available on GPIO17
- **Power**: 3.3V

### Touch Characteristics
- **Activation Force**: Low to medium pressure required
- **Accuracy**: ±2-3 pixels after calibration
- **Stylus Compatible**: Yes (stylus, fingernail, or finger)
- **Glove Compatible**: Yes (with sufficient pressure)

## Physical Specifications

### Dimensions
- **PCB Size**: Matches Raspberry Pi form factor (85.6mm × 56.5mm)
- **Total Height**: ~18mm including display and components
- **Screen Active Area**: ~71mm × 48mm
- **Weight**: ~50g

### Mounting
- **Connection**: Stacks on 40-pin GPIO header
- **Mounting Holes**: Uses Raspberry Pi mounting holes
- **Standoffs**: Required for secure mounting (typically 11mm)

## Electrical Specifications

### Power Requirements
- **Operating Voltage**: 5V (from Pi's 5V pins)
- **Logic Level**: 3.3V
- **Current Consumption**:
  - Display: ~100-120mA (backlight at full brightness)
  - Touch Controller: ~5mA
  - Total: ~125mA maximum

### GPIO Pin Usage

#### SPI0 (Display)
- **GPIO 10 (MOSI/SDA)**: Serial data out (Pi to display)
- **GPIO 9 (MISO)**: Serial data in (display to Pi)
- **GPIO 11 (SCLK/SCL)**: Serial clock
- **GPIO 8 (CE0)**: Chip enable for display
- **GPIO 25**: Data/Command (D/C) signal
- **GPIO 24**: Reset (RST) - optional

#### SPI1 (Touch Controller)
- **GPIO 7 (CE1)**: Chip enable for STMPE610
- **GPIO 17**: Touch interrupt (IRQ)

#### Backlight Control
- **GPIO 18**: PWM for backlight dimming

#### Power Pins
- **5V**: Connected to Pi's 5V pins (2)
- **3.3V**: Connected to Pi's 3.3V pin
- **GND**: Connected to Pi's ground pins (multiple)

### Pin Passthrough
- **All GPIO pins**: Available on top header (female)
- **Allows**: Stacking additional HATs/shields on top

## Software Requirements

### Kernel Modules
- **fbtft**: Framebuffer driver for small TFT displays
- **fbtft_device**: Device-specific driver configuration
- **stmpe-ts**: Touchscreen driver for STMPE610

### Device Tree Overlays
- **pitft35-resistive**: Standard overlay for this display
- **Located**: `/boot/overlays/pitft35-resistive.dtbo`

### Framebuffer Device
- **Device Node**: `/dev/fb1` (fb0 is HDMI)
- **Console**: Can be mapped to display
- **X11**: Requires configuration to use fb1

## Display Modes

### Console Mode
- **Text Console**: 53 columns × 30 rows (6×8 font)
- **Boot Messages**: Can be shown on display
- **Configuration**: `/boot/cmdline.txt` modification

### Framebuffer Mode
- **Direct Drawing**: Applications can write to `/dev/fb1`
- **Libraries**: SDL, pygame, PIL/Pillow support
- **Performance**: Good for static or slow-updating content

### FBCP (Framebuffer Copy)
- **Purpose**: Mirrors HDMI output to PiTFT
- **Performance**: ~20-30 FPS
- **Use Case**: Running standard desktop on small display
- **CPU Usage**: ~30-50% of one core

### X11 Mode
- **Desktop Environment**: Full X11 desktop on TFT
- **Configuration**: `/etc/X11/xorg.conf.d/99-fbdev.conf`
- **Window Manager**: LXDE, Openbox, or lightweight WMs recommended

## Performance Characteristics

### Display Refresh
- **Full Screen Update**: ~20-50ms (depending on method)
- **Partial Update**: Supported by driver
- **DMA**: Not available, SPI transfers use CPU

### Touch Response
- **Latency**: 10-20ms typical
- **Polling Rate**: Configurable, default ~80Hz
- **Calibration**: Required for accurate touch input

## Supported Operating Systems
- **Raspberry Pi OS** (Buster, Bullseye)
- **Ubuntu** (with kernel module compilation)
- **RetroPie** (with display configuration)
- **LibreELEC/OSMC** (limited support)

## Installation Methods

### 1. Adafruit Script (Easiest)
```bash
wget https://raw.githubusercontent.com/adafruit/Raspberry-Pi-Installer-Scripts/master/adafruit-pitft.sh
sudo bash adafruit-pitft.sh
```

### 2. Manual Installation
- Enable SPI interface
- Install kernel modules
- Configure device tree overlay
- Set up touchscreen calibration
- Configure display rotation

### 3. Custom Kernel Compilation
- For latest kernels or custom configurations
- Build fbtft and stmpe drivers
- Install device tree overlays

## Compatibility

### Raspberry Pi Models
- **Supported**:
  - Raspberry Pi 1 Model B+
  - Raspberry Pi 2 Model B
  - Raspberry Pi 3 Model B / B+
  - Raspberry Pi 4 Model B (with adapters)
  - Raspberry Pi Zero / Zero W / Zero 2 W
- **Not Supported**:
  - Original Raspberry Pi Model A/B (26-pin header)

### Kernel Versions
- **Recommended**: Linux 4.19+ (with fbtft in mainline)
- **Supported**: Linux 4.4 and later
- **Legacy**: Custom kernels for older versions

## Configuration Files

### Boot Configuration (`/boot/config.txt`)
```ini
dtparam=spi=on
dtoverlay=pitft35-resistive,rotate=90,speed=32000000,fps=30
```

### Display Rotation
- **rotate=0**: Portrait (USB ports on bottom)
- **rotate=90**: Landscape (USB ports on right)
- **rotate=180**: Portrait inverted (USB ports on top)
- **rotate=270**: Landscape inverted (USB ports on left)

### Console Configuration (`/boot/cmdline.txt`)
Add: `fbcon=map:10 fbcon=font:VGA8x8`

## Touch Calibration

### Tools
- **xinput_calibrator**: For X11 environments
- **evtest**: For testing raw touch events
- **ts_calibrate**: For tslib-based systems

### Calibration Data
- Stored in `/etc/pointercal` (tslib)
- Or in X11 configuration files
- Required for accurate touch mapping

## Common Use Cases

### 1. System Status Display
- Show CPU, memory, network stats
- Temperature monitoring
- Service status

### 2. Control Panel
- Button-based interface
- Settings adjustment
- System control

### 3. Media Player
- Video playback (limited resolution)
- Music player interface
- Album art display

### 4. Retro Gaming
- Emulation stations
- Portable gaming console
- Touch-based games

### 5. IoT Dashboard
- Sensor data display
- Home automation control
- Alert notifications

## Limitations

### Performance
- **SPI Bandwidth**: Limited refresh rate
- **CPU Usage**: Significant for FBCP mode
- **No Hardware Acceleration**: GPU not used for TFT

### Touch
- **Single Touch Only**: No multi-touch/gestures
- **Pressure Required**: Not suitable for light-touch interfaces
- **Drift**: May require recalibration over time

### Resolution
- **Low Resolution**: 480×320 limits detail
- **Small Text**: Can be hard to read
- **No HD Content**: Not suitable for high-res video

## Troubleshooting

### Display Not Working
- Check SPI enabled in `raspi-config`
- Verify correct overlay in `/boot/config.txt`
- Check connections and power supply
- Test with `ls /dev/fb1`

### Touch Not Responding
- Verify device: `ls /dev/input/event*`
- Test with `evtest`
- Check calibration
- Ensure STMPE driver loaded

### White Screen
- Check backlight connection
- Verify display initialization
- Test different SPI speeds
- Check for kernel module errors

### Slow Performance
- Reduce SPI speed
- Lower FPS setting
- Use direct framebuffer instead of FBCP
- Optimize application code

## Resources

### Official Documentation
- [Adafruit PiTFT Setup Guide](https://learn.adafruit.com/adafruit-pitft-3-dot-5-touch-screen-for-raspberry-pi)
- [Adafruit PiTFT Forum](https://forums.adafruit.com/viewforum.php?f=47)
- [GitHub - Adafruit PiTFT Scripts](https://github.com/adafruit/Raspberry-Pi-Installer-Scripts)

### Datasheets
- [HX8357D Display Controller](http://www.adafruit.com/datasheets/HX8357-D_DS_April2012.pdf)
- [STMPE610 Touch Controller](https://www.st.com/resource/en/datasheet/stmpe610.pdf)

### Community Projects
- [PiTFT Examples on GitHub](https://github.com/adafruit/adafruit-pi-cam)
- [Framebuffer Examples](https://github.com/notro/fbtft/wiki)

## Warranty and Support
- Standard Adafruit product warranty
- Community support via forums
- Adafruit support for hardware issues
- Open-source drivers (fbtft)

## Product Variants
- **PiTFT Plus 3.5"**: Includes GPIO buttons
- **PiTFT Capacitive**: Capacitive touch version
- **2.8" and 2.4"**: Smaller versions available
- **3.5" Without Touch**: Display-only version
