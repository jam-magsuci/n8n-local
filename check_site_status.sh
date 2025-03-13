#!/bin/bash

# Script to check website status every 5 minutes
# Usage: ./check_site_status.sh <domain>

# Check if domain is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <domain>"
    echo "Example: $0 https://example.com"
    exit 1
fi

DOMAIN=$1
LOG_FILE="site_status.log"
DOCKER_RESTART_LOG="docker_restart.log"
RESTART_IN_PROGRESS=false

echo "Starting site monitoring for $DOMAIN"
echo "Press Ctrl+C to stop"
echo "Logs will be displayed here and saved to $LOG_FILE"

# Create or clear log files
> "$LOG_FILE"
> "$DOCKER_RESTART_LOG"

# Function to restart Docker containers
restart_docker() {
    if [ "$RESTART_IN_PROGRESS" = true ]; then
        echo "Docker restart already in progress, skipping..."
        return
    fi
    
    RESTART_IN_PROGRESS=true
    restart_timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    restart_message="$restart_timestamp - ALERT: Restarting Docker containers..."
    echo "$restart_message"
    echo "$restart_message" >> "$DOCKER_RESTART_LOG"
    
    # Stop Docker containers
    echo "Stopping Docker containers..."
    docker compose down >> "$DOCKER_RESTART_LOG" 2>&1
    
    # Wait for containers to stop completely
    echo "Waiting for containers to stop completely..."
    sleep 10
    
    # Start Docker containers
    echo "Starting Docker containers..."
    docker compose up -d >> "$DOCKER_RESTART_LOG" 2>&1
    
    # Wait for containers to initialize
    echo "Waiting for containers to initialize..."
    sleep 20
    
    complete_timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    complete_message="$complete_timestamp - INFO: Docker containers restarted."
    echo "$complete_message"
    echo "$complete_message" >> "$DOCKER_RESTART_LOG"
    
    RESTART_IN_PROGRESS=false
}

# Function to check site status
check_site() {
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Get HTTP status code using curl
    # -s for silent mode, -o /dev/null to discard output, -w to get status code
    # -m 10 to set timeout to 10 seconds
    status_code=$(curl -s -o /dev/null -w "%{http_code}" -m 10 "$DOMAIN")
    
    # Check if status code is 5xx (server error) or connection failed (000)
    if [[ $status_code =~ ^5[0-9][0-9]$ ]] || [[ $status_code == "000" ]]; then
        message="$timestamp - ALERT: Site unreachable! Status code: $status_code"
        echo "$message"
        echo "$message" >> "$LOG_FILE"
        
        # Restart Docker containers when site is down
        restart_docker
    else
        message="$timestamp - INFO: Site is online. Status code: $status_code"
        echo "$message"
        echo "$message" >> "$LOG_FILE"
    fi
}

# Main loop
while true; do
    check_site
    sleep 2  # Sleep for 2 seconds
done