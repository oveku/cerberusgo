# Manual SSH Configuration Instructions

## Quick Setup Commands

### 1. Connect to Raspberry Pi
```bash
ssh pi@<YOUR_PI_IP>  # Use your Pi's current IP address
# Default password: raspberry
```

### 2. Transfer the configuration script
From your Windows machine, copy the script to the Pi:
```powershell
# Option A: Use the PowerShell helper script
.\scripts\deploy-pi-config.ps1 -PiIP <YOUR_PI_IP>

# Option B: Manual transfer (if you have scp/pscp)
scp .\scripts\configure-cerberusgo-pi.sh pi@<YOUR_PI_IP>:/home/pi/
```

### 3. Run the configuration script on the Pi
```bash
# Make executable and run
chmod +x configure-cerberusgo-pi.sh
./configure-cerberusgo-pi.sh
```

## What the script does:

1. **Updates system packages**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. **Configures OpenSSH server**
   - Installs openssh-server if needed
   - Configures secure SSH settings
   - Enables and starts SSH service

3. **Sets up SSH authentication**
   - Generates SSH key pair
   - Configures authorized_keys
   - Shows public key for remote access

4. **Configures static IP (example: 192.168.1.XXX)**
   ```bash
   # Adds to /etc/dhcpcd.conf:
   interface eth0
   static ip_address=192.168.1.XXX/24  # Replace XXX with your desired IP
   static routers=192.168.1.1          # Your router's IP
   static domain_name_servers=8.8.8.8 8.8.4.4  # Google DNS or your preferred
   ```

5. **Changes default password**
   - Prompts to change 'pi' user password from default 'raspberry'

6. **Sets hostname to 'cerberusgo'**
   ```bash
   echo "cerberusgo" | sudo tee /etc/hostname
   ```

7. **Enables SPI for PiTFT display**
   ```bash
   echo "dtparam=spi=on" | sudo tee -a /boot/config.txt
   ```

8. **Tests configuration**
   - Verifies SSH service is running
   - Checks static IP is active
   - Tests internet connectivity

## Manual Configuration (if script fails)

### Configure SSH manually:
```bash
# Install SSH if needed
sudo apt install -y openssh-server

# Enable and start SSH
sudo systemctl enable ssh
sudo systemctl start ssh

# Check status
sudo systemctl status ssh
```

### Configure static IP manually:
```bash
# Backup current config
sudo cp /etc/dhcpcd.conf /etc/dhcpcd.conf.backup

# Edit dhcpcd.conf
sudo nano /etc/dhcpcd.conf

# Add these lines at the end (update with your network settings):
interface eth0
static ip_address=192.168.1.XXX/24  # Change XXX to your desired IP
static routers=192.168.1.1           # Your router's IP
static domain_name_servers=8.8.8.8 8.8.4.4  # Google DNS

# Restart networking
sudo systemctl restart dhcpcd
```

### Generate SSH keys manually:
```bash
# Generate key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa

# Set up authorized_keys
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Display public key
cat ~/.ssh/id_rsa.pub
```

### Change password manually:
```bash
sudo passwd pi
```

### Set hostname manually:
```bash
# Set hostname
echo "cerberusgo" | sudo tee /etc/hostname

# Update hosts file
sudo sed -i 's/127.0.1.1.*raspberrypi/127.0.1.1\tcerberusgo/' /etc/hosts

# Apply immediately (or reboot)
sudo hostnamectl set-hostname cerberusgo
```

## After Configuration

1. **Test SSH connection** from Windows:
   ```powershell
   ssh pi@<YOUR_PI_IP>
   ```

2. **Update router** to reserve your chosen static IP for this device

3. **Reboot Pi** to ensure all changes take effect:
   ```bash
   sudo reboot
   ```

4. **Test PiTFT setup** (after reboot):
   ```bash
   # Check SPI is available
   ls /dev/spi*

   # Should see: /dev/spidev0.0  /dev/spidev0.1
   ```

## Troubleshooting

### SSH connection issues:
```bash
# Check SSH service
sudo systemctl status ssh

# Check SSH configuration
sudo sshd -t

# View SSH logs
sudo journalctl -u ssh
```

### Network issues:
```bash
# Check current IP
hostname -I

# Check network configuration
cat /etc/dhcpcd.conf

# Restart networking
sudo systemctl restart dhcpcd
```

### Check services:
```bash
# All important services
sudo systemctl status ssh
sudo systemctl status dhcpcd
```