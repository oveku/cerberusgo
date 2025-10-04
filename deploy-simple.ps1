#!/usr/bin/env powershell
# Deploy CerberusGo hang fixes to Raspberry Pi

# Load environment variables from .env file
. "$PSScriptRoot\scripts\Load-DotEnv.ps1"

$IP = $env:PRODUCTION_IP
$USER = $env:PI_USERNAME
$HOSTNAME = $env:PI_HOSTNAME

if (-not $IP) {
    Write-Error "Environment variables not loaded. Please ensure .env file exists."
    Write-Host "Copy .env.example to .env and configure it with your values." -ForegroundColor Yellow
    exit 1
}

$ErrorActionPreference = "Stop"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "         Deploying CerberusGo Hang Fixes               " -ForegroundColor Cyan  
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Target Server: $IP ($HOSTNAME)" -ForegroundColor Yellow
Write-Host "Username: $USER" -ForegroundColor Yellow
Write-Host ""

# Test connectivity
Write-Host "Testing server connectivity..." -ForegroundColor Green
try {
    ssh -o ConnectTimeout=10 "$USER@$IP" "echo 'Connected successfully'" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "SSH connection failed"
    }
    Write-Host "[OK] Server is reachable" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Cannot connect to server. Please check:" -ForegroundColor Red
    Write-Host "   - Server is powered on and connected" -ForegroundColor Red
    Write-Host "   - IP address is correct in .env file" -ForegroundColor Red
    Write-Host "   - SSH is enabled on the Pi" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Starting deployment process..." -ForegroundColor Blue
Write-Host ""

# Create backup
Write-Host "1. Creating backup of existing files..." -ForegroundColor Yellow
$backupDir = "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
ssh "$USER@$IP" "mkdir -p ~/$backupDir; cp ~/clock_weather*.py ~/$backupDir/ 2>/dev/null; true"
Write-Host "   [OK] Backup created in ~/$backupDir" -ForegroundColor Green

# Deploy Python files
Write-Host "2. Deploying Python application files..." -ForegroundColor Yellow
$pythonFiles = @(
    "src/clock_weather_fbi.py"
)

foreach ($file in $pythonFiles) {
    $fileName = Split-Path $file -Leaf
    Write-Host "   Copying $fileName..." -ForegroundColor Gray
    scp "$PSScriptRoot\$file" "$USER@${IP}:~/$fileName"
    if ($LASTEXITCODE -eq 0) {
        ssh "$USER@$IP" "chmod +x ~/$fileName"
        Write-Host "   [OK] $fileName deployed" -ForegroundColor Green
    } else {
        Write-Host "   [ERROR] Failed to deploy $fileName" -ForegroundColor Red
        exit 1
    }
}

# Deploy service files
Write-Host "3. Deploying service configurations..." -ForegroundColor Yellow
$serviceFiles = @(
    "config/clock-weather-fb.service",
    "config/cerberusgo-monitor.service"
)

foreach ($file in $serviceFiles) {
    $fileName = Split-Path $file -Leaf
    Write-Host "   Copying $fileName..." -ForegroundColor Gray
    scp "$PSScriptRoot\$file" "$USER@${IP}:/tmp/$fileName"
    if ($LASTEXITCODE -eq 0) {
        ssh "$USER@$IP" "sudo mv /tmp/$fileName /etc/systemd/system/$fileName"
        Write-Host "   [OK] $fileName deployed" -ForegroundColor Green
    } else {
        Write-Host "   [ERROR] Failed to deploy $fileName" -ForegroundColor Red
        exit 1
    }
}

# Deploy monitoring script
Write-Host "4. Deploying scripts..." -ForegroundColor Yellow
$scriptFiles = @(
    "scripts/monitor-cerberusgo.sh",
    "scripts/start-clock-weather-fbi.sh"
)

foreach ($script in $scriptFiles) {
    $scriptName = Split-Path $script -Leaf
    Write-Host "   Copying $scriptName..." -ForegroundColor Gray
    scp "$PSScriptRoot\$script" "$USER@${IP}:~/$scriptName"
    if ($LASTEXITCODE -eq 0) {
        ssh "$USER@$IP" "chmod +x ~/$scriptName"
        Write-Host "   [OK] $scriptName deployed" -ForegroundColor Green
    } else {
        Write-Host "   [ERROR] Failed to deploy $scriptName" -ForegroundColor Red
        exit 1
    }
}

# Deploy documentation
Write-Host "5. Deploying documentation..." -ForegroundColor Yellow
scp "$PSScriptRoot\HANG_FIXES_SUMMARY.md" "$USER@${IP}:~/HANG_FIXES_SUMMARY.md"
Write-Host "   [OK] Documentation deployed" -ForegroundColor Green

# Configure services
Write-Host "6. Configuring systemd services..." -ForegroundColor Yellow
ssh "$USER@$IP" "sudo systemctl daemon-reload; sudo systemctl stop clock-weather.service 2>/dev/null; sudo systemctl stop clock-weather-fb.service 2>/dev/null; sudo systemctl enable cerberusgo-monitor.service; sudo systemctl enable clock-weather-fb.service"

if ($LASTEXITCODE -eq 0) {
    Write-Host "   [OK] Services configured" -ForegroundColor Green
} else {
    Write-Host "   [ERROR] Service configuration failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Summary of changes:" -ForegroundColor Cyan
Write-Host "   • Fixed thread accumulation issues" -ForegroundColor White
Write-Host "   • Added network timeout and retry logic" -ForegroundColor White  
Write-Host "   • Implemented proper resource cleanup" -ForegroundColor White
Write-Host "   • Added comprehensive logging" -ForegroundColor White
Write-Host "   • Configured resource limits and monitoring" -ForegroundColor White
Write-Host "   • Created automatic hang detection system" -ForegroundColor White
Write-Host ""

# Ask for reboot confirmation
Write-Host "The server needs to be rebooted to apply all changes." -ForegroundColor Yellow
Write-Host ""
$response = Read-Host "Do you want to reboot the server now? (y/N)"

if ($response -match "^[Yy]") {
    Write-Host ""
    Write-Host "Rebooting server..." -ForegroundColor Blue
    
    # Initiate reboot
    ssh "$USER@$IP" "sudo reboot" 2>$null
    
    Write-Host "[OK] Reboot initiated" -ForegroundColor Green
    Write-Host ""
    Write-Host "The server is rebooting..." -ForegroundColor Yellow
    Write-Host "   This typically takes 2-3 minutes." -ForegroundColor Gray
    Write-Host ""
    Write-Host "After reboot, you can:" -ForegroundColor Cyan
    Write-Host "   • Connect: .\connect-cerberusgo.ps1" -ForegroundColor White
    Write-Host "   • Check status: sudo systemctl status clock-weather-fb" -ForegroundColor White
    Write-Host "   • View logs: tail -f /tmp/clock_weather_fbi.log" -ForegroundColor White
    Write-Host "   • Monitor: sudo journalctl -u cerberusgo-monitor -f" -ForegroundColor White
    
} else {
    Write-Host ""
    Write-Host "[WARNING] Server was NOT rebooted." -ForegroundColor Yellow
    Write-Host "   Please reboot manually when convenient:" -ForegroundColor Gray
    Write-Host "   ssh $USER@$IP 'sudo reboot'" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Quick connection command:" -ForegroundColor Cyan
Write-Host "   .\connect-cerberusgo.ps1" -ForegroundColor White
Write-Host ""