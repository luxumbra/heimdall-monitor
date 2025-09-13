#!/bin/bash
# Install Internet Monitor Service
# Usage: ./install-service.sh [username] [working_directory]
#
# Parameters:
#   username (optional): User to run service as (defaults to current user)
#   working_directory (optional): Directory containing internet_monitor.py (defaults to script's directory)
#
# Examples:
#   ./install-service.sh                    # Use current user and auto-detect directory
#   ./install-service.sh alice              # Run as 'alice', auto-detect directory  
#   ./install-service.sh alice /opt/monitor # Run as 'alice' in /opt/monitor

set -e

# Get parameters
MONITOR_USER="${1:-$USER}"
# Auto-detect the directory where this script and internet_monitor.py are located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_WORKING_DIR="${2:-$SCRIPT_DIR}"

echo "🔧 Installing Internet Monitor Service"
echo "======================================"
echo "User: $MONITOR_USER"
echo "Working Directory: $MONITOR_WORKING_DIR"
echo ""

# Validate inputs
if [[ ! -f "$MONITOR_WORKING_DIR/internet_monitor.py" ]]; then
    echo "❌ Error: internet_monitor.py not found in $MONITOR_WORKING_DIR"
    exit 1
fi

if [[ ! -f "$MONITOR_WORKING_DIR/.env" ]]; then
    echo "❌ Error: .env file not found in $MONITOR_WORKING_DIR"
    echo "Please create .env file with monitor configuration"
    exit 1
fi

# Check if user exists
if ! id "$MONITOR_USER" &>/dev/null; then
    echo "❌ Error: User '$MONITOR_USER' does not exist"
    exit 1
fi

# Create service file from template
echo "📝 Creating service file..."
SERVICE_FILE="/tmp/internet-monitor-$MONITOR_USER.service"

sed "s|\${MONITOR_USER}|$MONITOR_USER|g; s|\${MONITOR_WORKING_DIR}|$MONITOR_WORKING_DIR|g" \
    internet-monitor-template.service > "$SERVICE_FILE"

# Install service
SERVICE_NAME="internet-monitor-$MONITOR_USER"
echo "📦 Installing service as $SERVICE_NAME..."

sudo cp "$SERVICE_FILE" "/etc/systemd/system/$SERVICE_NAME.service"
sudo systemctl daemon-reload

# Clean up
rm "$SERVICE_FILE"

echo "✅ Service installed successfully!"
echo ""
echo "Commands:"
echo "  Start:   sudo systemctl start $SERVICE_NAME"
echo "  Stop:    sudo systemctl stop $SERVICE_NAME"
echo "  Enable:  sudo systemctl enable $SERVICE_NAME"
echo "  Status:  sudo systemctl status $SERVICE_NAME"
echo "  Logs:    sudo journalctl -u $SERVICE_NAME -f"
echo ""
echo "The service will:"
echo "  - Run as user: $MONITOR_USER"
echo "  - Work in directory: $MONITOR_WORKING_DIR"  
echo "  - Use configuration from: $MONITOR_WORKING_DIR/.env"
echo "  - Write logs to: $MONITOR_WORKING_DIR/internet_logs/"
echo ""

# Offer to start service
read -p "Start the service now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Starting service..."
    sudo systemctl start "$SERVICE_NAME"
    sudo systemctl enable "$SERVICE_NAME"
    echo "✅ Service started and enabled!"
    
    # Show status
    echo ""
    echo "📊 Service Status:"
    sudo systemctl status "$SERVICE_NAME" --no-pager
fi