#!/bin/bash

# CerberusGo Raspberry Pi Configuration Script
# This script configures OpenSSH server, authentication, and static IP
# Run with: chmod +x configure-cerberusgo-pi.sh && ./configure-cerberusgo-pi.sh

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables - Load from .env file if available
# Default values (will be overwritten if .env exists)
STATIC_IP="${PRODUCTION_IP:-192.168.1.XXX}"
GATEWAY="${GATEWAY_IP:-192.168.1.1}"
DNS_SERVERS="${DNS_PRIMARY:-8.8.8.8} ${DNS_SECONDARY:-8.8.4.4}"
HOSTNAME="${PI_HOSTNAME:-cerberusgo}"

# Try to load .env file from parent directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

if [ -f "$ENV_FILE" ]; then
    echo -e "${GREEN}Loading configuration from .env file...${NC}"
    # Export variables from .env
    export $(grep -v '^#' "$ENV_FILE" | xargs)
    # Update variables from .env
    STATIC_IP="${PRODUCTION_IP:-$STATIC_IP}"
    GATEWAY="${GATEWAY_IP:-$GATEWAY}"
    DNS_SERVERS="${DNS_PRIMARY:-8.8.8.8} ${DNS_SECONDARY:-8.8.4.4}"
    HOSTNAME="${PI_HOSTNAME:-$HOSTNAME}"
else
    echo -e "${YELLOW}Warning: .env file not found. Using default/manual values.${NC}"
    echo -e "${YELLOW}For easier configuration, copy .env.example to .env and configure it.${NC}"
fi

echo -e "${BLUE}=== CerberusGo Raspberry Pi Configuration Script ===${NC}"
echo -e "${YELLOW}This script will configure:${NC}"
echo "1. Update system packages"
echo "2. Install Adafruit PiTFT 3.5\" drivers"
echo "3. Static IP address ($STATIC_IP) for WiFi"
echo "4. Set hostname to $HOSTNAME"
echo "5. Enable SPI for PiTFT"
echo ""

# Function to prompt for yes/no
prompt_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    read -p "$prompt" response
    response=${response:-$default}
    
    case "$response" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        *) return 1 ;;
    esac
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        echo -e "${RED}Error: This script should NOT be run as root${NC}"
        echo "Run as the pi user and it will use sudo when needed"
        exit 1
    fi
}

# Function to update system packages
update_system() {
    echo -e "${BLUE}=== Updating System Packages ===${NC}"
    sudo apt update
    sudo apt upgrade -y
    echo -e "${GREEN}✓ System packages updated${NC}"
    echo ""
}

# Function to install Adafruit PiTFT drivers
install_pitft_drivers() {
    echo -e "${BLUE}=== Installing Adafruit PiTFT 3.5\" Drivers ===${NC}"
    
    # Install required packages
    echo "Installing required packages..."
    sudo apt install -y python3 python3-pip git cmake
    
    # Install kernel module
    echo "Installing fbcp-ili9341 for smooth display performance..."
    cd ~
    
    # Install device tree overlay for PiTFT 3.5"
    echo "Configuring device tree overlay..."
    
    # Add PiTFT overlay to /boot/firmware/config.txt (or /boot/config.txt)
    CONFIG_FILE="/boot/firmware/config.txt"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        CONFIG_FILE="/boot/config.txt"
    fi
    
    # Check if dtoverlay is already configured
    if ! grep -q "dtoverlay=pitft35-resistive" "$CONFIG_FILE"; then
        echo "Adding PiTFT device tree overlay to $CONFIG_FILE..."
        sudo bash -c "cat >> $CONFIG_FILE << 'DTEOF'

# PiTFT 3.5\" Display Configuration
dtoverlay=pitft35-resistive,rotate=90,speed=32000000,fps=30
DTEOF"
        echo -e "${GREEN}✓ Device tree overlay configured${NC}"
    else
        echo "PiTFT overlay already configured"
    fi
    
    # Install framebuffer tools
    echo "Installing framebuffer utilities..."
    sudo apt install -y fbi fbset
    
    # Install touch tools
    echo "Installing touchscreen utilities..."
    sudo apt install -y evtest libts-bin || echo "Some touch utilities not available, continuing..."
    
    echo -e "${GREEN}✓ PiTFT drivers installation completed${NC}"
    echo -e "${YELLOW}Note: Reboot required for display to work${NC}"
    echo ""
}

# Function to configure static IP for WiFi
configure_static_ip() {
    echo -e "${BLUE}=== Configuring Static IP Address for WiFi ===${NC}"
    
    # Check if using NetworkManager or dhcpcd
    if systemctl is-active --quiet NetworkManager; then
        echo "System uses NetworkManager"
        echo "Configuring static IP using nmcli..."
        
        # Get the current WiFi connection name
        WIFI_CONN=$(nmcli -t -f NAME,TYPE connection show | grep wireless | head -n1 | cut -d: -f1)
        
        if [[ -n "$WIFI_CONN" ]]; then
            echo "Found WiFi connection: $WIFI_CONN"
            sudo nmcli connection modify "$WIFI_CONN" ipv4.addresses "$STATIC_IP/24"
            sudo nmcli connection modify "$WIFI_CONN" ipv4.gateway "$GATEWAY"
            sudo nmcli connection modify "$WIFI_CONN" ipv4.dns "$DNS_SERVERS"
            sudo nmcli connection modify "$WIFI_CONN" ipv4.method manual
            echo -e "${GREEN}✓ Static IP configured for WiFi via NetworkManager: $STATIC_IP${NC}"
        else
            echo -e "${YELLOW}⚠ No WiFi connection found. Skipping WiFi static IP configuration.${NC}"
        fi
        
    elif [[ -f /etc/dhcpcd.conf ]]; then
        echo "System uses dhcpcd"
        # Backup dhcpcd.conf
        if [[ ! -f /etc/dhcpcd.conf.backup ]]; then
            sudo cp /etc/dhcpcd.conf /etc/dhcpcd.conf.backup
            echo "Backed up original dhcpcd.conf"
        fi
        
        # Remove any existing static IP configuration for wlan0
        sudo sed -i '/^interface wlan0/,/^$/d' /etc/dhcpcd.conf
        
        # Add static IP configuration for WiFi
        echo "Adding static IP configuration for wlan0..."
        cat << EOF | sudo tee -a /etc/dhcpcd.conf > /dev/null

# CerberusGo Static IP Configuration for WiFi
interface wlan0
static ip_address=$STATIC_IP/24
static routers=$GATEWAY
static domain_name_servers=$DNS_SERVERS
EOF
        echo -e "${GREEN}✓ Static IP configured for WiFi via dhcpcd: $STATIC_IP${NC}"
    else
        echo -e "${YELLOW}⚠ Neither NetworkManager nor dhcpcd found. Manual configuration may be required.${NC}"
    fi
    
    echo -e "${YELLOW}Note: Network will restart after all configurations are complete${NC}"
    echo ""
}

# Function to change default password
change_password() {
    echo -e "${BLUE}=== Password Configuration ===${NC}"
    echo "Keeping default password as requested"
    echo -e "${YELLOW}⚠ Remember to change password manually if needed for security${NC}"
    echo ""
}

# Function to set hostname
set_hostname() {
    echo -e "${BLUE}=== Setting Hostname ===${NC}"
    
    current_hostname=$(hostname)
    if [[ "$current_hostname" != "$HOSTNAME" ]]; then
        echo "Changing hostname from '$current_hostname' to '$HOSTNAME'"
        echo "$HOSTNAME" | sudo tee /etc/hostname > /dev/null
        sudo sed -i "s/127.0.1.1.*$current_hostname/127.0.1.1\t$HOSTNAME/" /etc/hosts
        echo -e "${GREEN}✓ Hostname set to $HOSTNAME${NC}"
        echo -e "${YELLOW}Note: Hostname change will take effect after reboot${NC}"
    else
        echo "Hostname is already set to $HOSTNAME"
    fi
    echo ""
}

# Function to enable SPI for PiTFT
enable_spi() {
    echo -e "${BLUE}=== Enabling SPI Interface ===${NC}"
    
    # Check if SPI is already enabled
    if grep -q "^dtparam=spi=on" /boot/config.txt; then
        echo "SPI is already enabled"
    else
        echo "Enabling SPI interface..."
        echo "dtparam=spi=on" | sudo tee -a /boot/config.txt > /dev/null
        echo -e "${GREEN}✓ SPI interface enabled${NC}"
        echo -e "${YELLOW}Note: SPI will be available after reboot${NC}"
    fi
    echo ""
}

# Function to display configuration summary
show_summary() {
    echo -e "${BLUE}=== Configuration Summary ===${NC}"
    echo "Hostname: $HOSTNAME"
    echo "Static IP (WiFi): $STATIC_IP"
    echo "Gateway: $GATEWAY"
    echo "DNS: $DNS_SERVERS"
    echo "Current IP: $(hostname -I | awk '{print $1}')"
    echo "PiTFT Drivers: Installed (Adafruit 3.5\" Resistive)"
    echo "SPI: Enabled"
    echo ""
}

# Function to restart services
restart_services() {
    echo -e "${BLUE}=== Restarting Services ===${NC}"
    
    if prompt_yes_no "Restart networking to apply static IP?" "y"; then
        echo "Restarting networking service..."
        if systemctl is-active --quiet NetworkManager; then
            sudo systemctl restart NetworkManager
            sleep 5
        elif systemctl is-active --quiet dhcpcd; then
            sudo systemctl restart dhcpcd
            sleep 5
        else
            echo "Restarting network interface..."
            sudo ip link set wlan0 down
            sleep 2
            sudo ip link set wlan0 up
            sleep 3
        fi
        echo -e "${GREEN}✓ Networking restarted${NC}"
    fi
    
    echo ""
}

# Function to test configuration
test_configuration() {
    echo -e "${BLUE}=== Testing Configuration ===${NC}"
    
    # Test network
    current_ip=$(hostname -I | awk '{print $1}')
    if [[ "$current_ip" == "$STATIC_IP" ]]; then
        echo -e "${GREEN}✓ Static IP is active: $current_ip${NC}"
    else
        echo -e "${YELLOW}⚠ Current IP ($current_ip) differs from configured static IP ($STATIC_IP)${NC}"
        echo "  This may be normal if networking hasn't restarted yet"
    fi
    
    # Test internet connectivity
    if ping -c 1 8.8.8.8 &> /dev/null; then
        echo -e "${GREEN}✓ Internet connectivity working${NC}"
    else
        echo -e "${RED}✗ No internet connectivity${NC}"
    fi
    
    # Check SPI
    if ls /dev/spi* &> /dev/null; then
        echo -e "${GREEN}✓ SPI devices found: $(ls /dev/spi*)${NC}"
    else
        echo -e "${YELLOW}⚠ SPI devices not found (may need reboot)${NC}"
    fi
    
    # Check framebuffer
    if ls /dev/fb1 &> /dev/null; then
        echo -e "${GREEN}✓ Framebuffer /dev/fb1 exists${NC}"
    else
        echo -e "${YELLOW}⚠ Framebuffer /dev/fb1 not found (may need reboot)${NC}"
    fi
    
    echo ""
}

# Main execution
main() {
    check_root
    
    echo -e "${YELLOW}Starting CerberusGo configuration...${NC}"
    echo ""
    
    # Run configuration steps
    update_system
    install_pitft_drivers
    configure_static_ip
    change_password
    set_hostname
    enable_spi
    restart_services
    test_configuration
    show_summary
    
    echo -e "${GREEN}=== Configuration Complete ===${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Update your router to reserve IP $STATIC_IP for this device (WiFi)"
    echo "2. Test SSH connection from another machine"
    echo "3. Reboot to ensure all changes take effect (REQUIRED for PiTFT)"
    echo ""
    
    if prompt_yes_no "Reboot now to apply all changes?" "y"; then
        echo "Rebooting in 5 seconds..."
        sleep 5
        sudo reboot
    else
        echo -e "${YELLOW}⚠ IMPORTANT: You must reboot for PiTFT drivers to work!${NC}"
        echo "Run: sudo reboot"
    fi
}

# Run main function
main "$@"