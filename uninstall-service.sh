#!/bin/bash
# Uninstall Internet Monitor Service
# Usage: ./uninstall-service.sh [username]

set -e

# Get parameters  
MONITOR_USER="${1:-$USER}"
SERVICE_NAME="internet-monitor-$MONITOR_USER"

echo "🗑️  Uninstalling Internet Monitor Service"
echo "========================================"
echo "Service: $SERVICE_NAME"
echo ""

# Check if service exists
if ! systemctl list-units --full -a | grep -Fq "$SERVICE_NAME.service"; then
    echo "ℹ️  Service $SERVICE_NAME not found - nothing to uninstall"
    exit 0
fi

# Stop and disable service
echo "🛑 Stopping service..."
sudo systemctl stop "$SERVICE_NAME" 2>/dev/null || true
sudo systemctl disable "$SERVICE_NAME" 2>/dev/null || true

# Remove service file
echo "📦 Removing service file..."
sudo rm -f "/etc/systemd/system/$SERVICE_NAME.service"
sudo systemctl daemon-reload

echo "✅ Service uninstalled successfully!"
echo ""
echo "Note: Log files in internet_logs/ directory are preserved"