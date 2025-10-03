# Raspberry Pi 3 Model B - Technical Specifications

## Overview
The Raspberry Pi 3 Model B is a credit-card sized single-board computer developed by the Raspberry Pi Foundation. Released in February 2016, it was the third generation of the Raspberry Pi series.

## Processor
- **SoC**: Broadcom BCM2837
- **CPU**: 1.2GHz 64-bit quad-core ARM Cortex-A53 (ARMv8)
- **Architecture**: ARMv8-A (64-bit)
- **Instruction Set**: ARM, Thumb-2
- **GPU**: Broadcom VideoCore IV @ 400MHz
  - OpenGL ES 2.0
  - Hardware-accelerated OpenVG
  - 1080p30 H.264 high-profile decode
  - Capable of 1Gpixel/s, 1.5Gtexel/s or 24GFLOPs

## Memory
- **RAM**: 1GB LPDDR2 SDRAM @ 900MHz
- **Shared with GPU**: Yes (configurable split)

## Storage
- **Primary**: MicroSD card slot (supports SDXC)
- **Boot**: Boots from microSD card
- **No onboard storage**: All storage is external

## Connectivity

### Wireless
- **Wi-Fi**: 802.11n (2.4GHz only)
  - BCM43438 wireless chip
  - Speeds up to 150 Mbps
- **Bluetooth**: Bluetooth 4.1 (BLE - Bluetooth Low Energy)

### Wired
- **Ethernet**: 10/100 Mbps Ethernet (RJ45 jack)
  - Connected via USB 2.0 hub internally
  - Maximum throughput ~95 Mbps due to USB 2.0 limitation

### USB
- **4x USB 2.0 ports**
- Maximum combined throughput shared across all USB devices and Ethernet

## Video Output
- **HDMI**: Full-size HDMI port
  - Supports up to 1920×1200 resolution
  - HDMI 1.3 & 1.4 compliant
- **Composite**: 3.5mm TRRS jack (combined with audio)
  - PAL and NTSC output

## Audio Output
- **3.5mm jack**: 4-pole stereo output and composite video
- **HDMI**: Digital audio output via HDMI
- **No audio input**: No built-in microphone or line-in

## GPIO (General Purpose Input/Output)
- **40-pin GPIO header**: 2×20 pins
  - 26x GPIO pins
  - 2x 5V power pins
  - 2x 3.3V power pins
  - 8x Ground pins
  - 2x ID_SC and ID_SD (reserved for HAT identification)

### GPIO Pin Functions
- **SPI**: 2 channels (SPI0, SPI1)
  - **SPI0**: GPIO 7-11 (CE0, CE1, MISO, MOSI, SCLK)
  - **SPI1**: GPIO 16-21
- **I2C**: 1 channel (I2C1)
  - GPIO 2-3 (SDA, SCL)
- **UART**: 1 channel (UART0)
  - GPIO 14-15 (TXD, RXD)
- **PWM**: 2 channels
  - GPIO 12, 13, 18, 19

## Power
- **Input**: 5V DC via Micro USB port
- **Recommended PSU**: 2.5A (12.5W) minimum
- **Typical Power Consumption**: 
  - Idle: ~260mA (1.3W)
  - Under load: ~730mA (3.7W)
  - Max: ~1.4A (7W) with peripherals
- **Power over Ethernet (PoE)**: Not supported (requires PoE HAT)

## Physical Specifications
- **Dimensions**: 85.60mm × 56.5mm × 17mm
- **Weight**: 45g
- **Form Factor**: Credit card size
- **Mounting**: 4 mounting holes (2.5mm diameter)

## Operating Conditions
- **Operating Temperature**: 0-50°C (ambient)
- **Storage Temperature**: -20 to 60°C
- **Humidity**: 0-95% RH (non-condensing)

## Operating System Support
- **Primary**: Raspberry Pi OS (formerly Raspbian)
  - Debian-based Linux distribution
  - 32-bit and 64-bit versions available
- **Others**: 
  - Ubuntu (including Ubuntu Server)
  - LibreELEC / OSMC (media center)
  - RetroPie (gaming)
  - Windows 10 IoT Core
  - Various other Linux distributions

## Additional Features
- **Camera Interface (CSI)**: 15-pin MIPI Camera Serial Interface
- **Display Interface (DSI)**: 15-pin Display Serial Interface
- **LED Indicators**:
  - PWR (red): Power status
  - ACT (green): SD card activity

## GPIO Pin Layout for Adafruit PiTFT 3.5"

The Adafruit PiTFT uses the following GPIO pins:

### SPI Interface (Display Communication)
- **GPIO 10 (MOSI)**: Data from Pi to display
- **GPIO 9 (MISO)**: Data from display to Pi
- **GPIO 11 (SCLK)**: SPI clock
- **GPIO 8 (CE0)**: Chip select for display
- **GPIO 7 (CE1)**: Chip select for touchscreen controller

### Control Pins
- **GPIO 25**: Display data/command select (D/C)
- **GPIO 24**: Display reset (optional, can use software reset)
- **GPIO 18**: PWM for backlight control

### Touch Controller (STMPE610)
- Uses SPI interface via CE1 (GPIO 7)
- **GPIO 17**: Touch interrupt (IRQ)

### Power
- **5V**: Power supply for display backlight
- **3.3V**: Logic level and touchscreen controller
- **GND**: Multiple ground connections

## Compatibility Notes
- The Pi 3B uses a 64-bit processor but most distributions run in 32-bit mode for compatibility
- Heat sink recommended for sustained high-load applications
- Quality power supply essential to prevent undervoltage issues (look for the rainbow square icon)
- USB ports share bandwidth; high-speed USB devices may impact Ethernet performance

## Known Limitations
- Wi-Fi is 2.4GHz only (no 5GHz support)
- Ethernet limited to 100Mbps and shares USB 2.0 bandwidth
- No native analog input (requires ADC HAT or module)
- No real-time clock (requires RTC HAT or internet time sync)
- Single video output in use at a time (HDMI OR Composite, not both)

## Revision Information
- **Model**: Raspberry Pi 3 Model B
- **Revision Code**: a02082 or a22082
- **Release Date**: February 2016
- **Successor**: Raspberry Pi 3 Model B+ (March 2018)

## Resources
- [Official Raspberry Pi 3B Product Page](https://www.raspberrypi.org/products/raspberry-pi-3-model-b/)
- [Raspberry Pi GPIO Pinout](https://pinout.xyz/)
- [BCM2837 Datasheet](https://www.raspberrypi.org/documentation/hardware/raspberrypi/bcm2837/README.md)
