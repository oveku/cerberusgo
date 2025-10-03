# CerberusGo Pi Configuration Helper Script
# This script helps transfer and execute the configuration script on the Raspberry Pi

# Load environment variables from .env
. "$PSScriptRoot\Load-DotEnv.ps1"

param(
    [string]$PiIP = $env:PRODUCTION_IP,
    [string]$PiUser = $env:PI_USERNAME,
    [string]$PiPassword = $env:PI_PASSWORD
)

if (-not $PiIP -or $PiIP -eq "192.168.1.XXX") {
    Write-Error "Please configure your .env file with PRODUCTION_IP"
    Write-Host "Copy .env.example to .env and set your Raspberry Pi's IP address." -ForegroundColor Yellow
    exit 1
}

$ScriptPath = Join-Path $PSScriptRoot "configure-cerberusgo-pi.sh"
$RemoteScriptPath = "/home/pi/configure-cerberusgo-pi.sh"

Write-Host "CerberusGo Pi Configuration Helper" -ForegroundColor Green
Write-Host "===================================" -ForegroundColor Green
Write-Host ""

# Check if the bash script exists
if (-not (Test-Path $ScriptPath)) {
    Write-Error "Configuration script not found: $ScriptPath"
    Write-Host "Please ensure configure-cerberusgo-pi.sh is in the scripts directory"
    exit 1
}

Write-Host "Configuration details:" -ForegroundColor Yellow
Write-Host "  Pi IP: $PiIP" -ForegroundColor Gray
Write-Host "  Pi User: $PiUser" -ForegroundColor Gray
Write-Host "  Script: $ScriptPath" -ForegroundColor Gray
Write-Host ""

# Function to execute SSH commands
function Invoke-SSHCommand {
    param(
        [string]$Command,
        [string]$Description
    )
    
    Write-Host "Executing: $Description" -ForegroundColor Cyan
    Write-Host "Command: $Command" -ForegroundColor Gray
    
    # Use plink if available, otherwise use ssh
    if (Get-Command plink -ErrorAction SilentlyContinue) {
        # PuTTY plink version
        $fullCommand = "echo y | plink -ssh -l $PiUser -pw $PiPassword $PiIP `"$Command`""
    } else {
        # OpenSSH version (requires sshpass or manual password entry)
        $fullCommand = "ssh $PiUser@$PiIP `"$Command`""
    }
    
    Write-Host "Running: $fullCommand" -ForegroundColor DarkGray
    Invoke-Expression $fullCommand
}

# Function to transfer file via SCP
function Copy-FileToPI {
    param(
        [string]$LocalPath,
        [string]$RemotePath,
        [string]$Description
    )
    
    Write-Host "Transferring: $Description" -ForegroundColor Cyan
    
    if (Get-Command pscp -ErrorAction SilentlyContinue) {
        # PuTTY pscp version
        $scpCommand = "echo y | pscp -pw $PiPassword `"$LocalPath`" $PiUser@${PiIP}:$RemotePath"
    } else {
        # OpenSSH scp version
        $scpCommand = "scp `"$LocalPath`" $PiUser@${PiIP}:$RemotePath"
    }
    
    Write-Host "Running: $scpCommand" -ForegroundColor DarkGray
    Invoke-Expression $scpCommand
}

try {
    Write-Host "Step 1: Testing SSH connection..." -ForegroundColor Yellow
    Invoke-SSHCommand -Command "echo 'SSH connection successful'" -Description "Test SSH connectivity"
    
    Write-Host "`nStep 2: Transferring configuration script..." -ForegroundColor Yellow
    Copy-FileToPI -LocalPath $ScriptPath -RemotePath $RemoteScriptPath -Description "Configuration script"
    
    Write-Host "`nStep 3: Making script executable..." -ForegroundColor Yellow
    Invoke-SSHCommand -Command "chmod +x $RemoteScriptPath" -Description "Make script executable"
    
    Write-Host "`nStep 4: Ready to execute configuration..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "The script has been transferred successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Choose how to proceed:" -ForegroundColor Yellow
    Write-Host "1. Run the script interactively (recommended)" -ForegroundColor Gray
    Write-Host "2. Connect to SSH manually" -ForegroundColor Gray
    Write-Host "3. Exit and run manually later" -ForegroundColor Gray
    Write-Host ""
    
    $choice = Read-Host "Enter your choice (1-3)"
    
    switch ($choice) {
        "1" {
            Write-Host "`nExecuting configuration script..." -ForegroundColor Green
            Write-Host "Note: This will run interactively - you may need to answer prompts" -ForegroundColor Yellow
            Write-Host ""
            
            # Execute the script
            if (Get-Command plink -ErrorAction SilentlyContinue) {
                $interactiveCommand = "plink -ssh -l $PiUser -pw $PiPassword $PiIP -t `"$RemoteScriptPath`""
            } else {
                $interactiveCommand = "ssh -t $PiUser@$PiIP `"$RemoteScriptPath`""
            }
            
            Write-Host "Running: $interactiveCommand" -ForegroundColor DarkGray
            Invoke-Expression $interactiveCommand
        }
        
        "2" {
            Write-Host "`nConnecting to SSH..." -ForegroundColor Green
            Write-Host "Once connected, run: $RemoteScriptPath" -ForegroundColor Yellow
            
            if (Get-Command plink -ErrorAction SilentlyContinue) {
                $sshCommand = "plink -ssh -l $PiUser -pw $PiPassword $PiIP"
            } else {
                $sshCommand = "ssh $PiUser@$PiIP"
            }
            
            Invoke-Expression $sshCommand
        }
        
        "3" {
            Write-Host "`nScript ready for manual execution:" -ForegroundColor Green
            Write-Host "SSH command: ssh $PiUser@$PiIP" -ForegroundColor Gray
            Write-Host "Script path: $RemoteScriptPath" -ForegroundColor Gray
            Write-Host "Run command: $RemoteScriptPath" -ForegroundColor Gray
        }
        
        default {
            Write-Host "Invalid choice. Exiting..." -ForegroundColor Red
        }
    }
    
} catch {
    Write-Error "Error occurred: $_"
    Write-Host ""
    Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
    Write-Host "1. Ensure the Pi is powered on and connected to network" -ForegroundColor Gray
    Write-Host "2. Verify the IP address is correct: $PiIP" -ForegroundColor Gray
    Write-Host "3. Check if SSH is enabled on the Pi" -ForegroundColor Gray
    Write-Host "4. Install PuTTY tools (plink, pscp) for easier automation" -ForegroundColor Gray
    Write-Host "   Download from: https://www.putty.org/" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Configuration script features:" -ForegroundColor Green
Write-Host "- Updates system packages" -ForegroundColor Gray
Write-Host "- Configures OpenSSH server securely" -ForegroundColor Gray
Write-Host "- Sets up SSH key authentication" -ForegroundColor Gray
Write-Host "- Configures static IP ($PiIP)" -ForegroundColor Gray
Write-Host "- Changes default password" -ForegroundColor Gray
Write-Host "- Sets hostname to 'cerberusgo'" -ForegroundColor Gray
Write-Host "- Enables SPI for PiTFT display" -ForegroundColor Gray
Write-Host "- Tests all configurations" -ForegroundColor Gray