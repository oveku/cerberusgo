#!/bin/bash
# System monitoring and hang detection script for CerberusGo
# This script monitors the clock-weather application and system resources

LOG_FILE="/tmp/cerberusgo_monitor.log"
MAX_MEMORY_MB=512
MAX_CPU_PERCENT=80
CHECK_INTERVAL=60  # seconds

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

check_service_status() {
    local service_name="$1"
    if systemctl is-active --quiet "$service_name"; then
        return 0
    else
        return 1
    fi
}

get_service_memory() {
    local service_name="$1"
    systemctl show "$service_name" --property=MemoryCurrent | cut -d= -f2
}

get_service_cpu() {
    local service_name="$1"
    # Get PID of the service
    local pid=$(systemctl show "$service_name" --property=MainPID | cut -d= -f2)
    if [ "$pid" != "0" ] && [ "$pid" != "" ]; then
        ps -p "$pid" -o %cpu --no-headers 2>/dev/null | tr -d ' '
    else
        echo "0"
    fi
}

restart_service_if_needed() {
    local service_name="$1"
    local reason="$2"
    
    log_message "WARNING: $service_name - $reason. Restarting service..."
    systemctl restart "$service_name"
    
    # Wait a moment and check if restart was successful
    sleep 5
    if check_service_status "$service_name"; then
        log_message "INFO: $service_name restarted successfully"
    else
        log_message "ERROR: Failed to restart $service_name"
    fi
}

check_system_resources() {
    # Check available memory
    local available_mem=$(free -m | awk 'NR==2{printf "%d", $7}')
    if [ "$available_mem" -lt 50 ]; then
        log_message "WARNING: Low system memory: ${available_mem}MB available"
    fi
    
    # Check disk space
    local disk_usage=$(df / | awk 'NR==2{print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 90 ]; then
        log_message "WARNING: High disk usage: ${disk_usage}%"
    fi
    
    # Check system load
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local load_int=$(echo "$load_avg" | cut -d. -f1)
    if [ "$load_int" -gt 2 ]; then
        log_message "WARNING: High system load: $load_avg"
    fi
}

monitor_service() {
    local service_name="$1"
    
    if ! check_service_status "$service_name"; then
        log_message "ERROR: $service_name is not running"
        return 1
    fi
    
    # Check memory usage
    local memory_bytes=$(get_service_memory "$service_name")
    if [ "$memory_bytes" != "" ] && [ "$memory_bytes" != "0" ]; then
        local memory_mb=$((memory_bytes / 1024 / 1024))
        if [ "$memory_mb" -gt "$MAX_MEMORY_MB" ]; then
            restart_service_if_needed "$service_name" "Memory usage too high: ${memory_mb}MB"
            return 1
        fi
    fi
    
    # Check CPU usage
    local cpu_percent=$(get_service_cpu "$service_name")
    if [ "$cpu_percent" != "" ] && [ "$cpu_percent" != "0" ]; then
        local cpu_int=$(echo "$cpu_percent" | cut -d. -f1)
        if [ "$cpu_int" -gt "$MAX_CPU_PERCENT" ]; then
            restart_service_if_needed "$service_name" "CPU usage too high: ${cpu_percent}%"
            return 1
        fi
    fi
    
    # Check if log file indicates hangs
    local log_errors=$(journalctl -u "$service_name" --since="5 minutes ago" | grep -i "error\|timeout\|hang\|freeze" | wc -l)
    if [ "$log_errors" -gt 5 ]; then
        restart_service_if_needed "$service_name" "Multiple errors detected in logs"
        return 1
    fi
    
    log_message "INFO: $service_name is healthy (Memory: ${memory_mb:-0}MB, CPU: ${cpu_percent:-0}%)"
    return 0
}

# Main monitoring loop
main() {
    log_message "INFO: Starting CerberusGo monitoring"
    
    while true; do
        # Check system resources
        check_system_resources
        
        # Monitor clock-weather services
        for service in "clock-weather" "clock-weather-fb"; do
            if systemctl list-unit-files | grep -q "$service.service"; then
                monitor_service "$service"
            fi
        done
        
        # Clean old log entries (keep last 1000 lines)
        if [ -f "$LOG_FILE" ]; then
            local line_count=$(wc -l < "$LOG_FILE")
            if [ "$line_count" -gt 1000 ]; then
                tail -1000 "$LOG_FILE" > "${LOG_FILE}.tmp"
                mv "${LOG_FILE}.tmp" "$LOG_FILE"
            fi
        fi
        
        sleep "$CHECK_INTERVAL"
    done
}

# Handle signals
trap 'log_message "INFO: Monitoring stopped"; exit 0' SIGTERM SIGINT

# Start monitoring
main