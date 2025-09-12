#!/bin/bash
# Setup log rotation for Internet Monitor

set -e

echo "🔄 Setting up log rotation for Internet Monitor..."

# Copy logrotate configuration
sudo cp internet-monitor-logrotate /etc/logrotate.d/internet-monitor

# Set proper permissions
sudo chmod 644 /etc/logrotate.d/internet-monitor
sudo chown root:root /etc/logrotate.d/internet-monitor

echo "✅ Log rotation configuration installed"

# Test the configuration
echo "🧪 Testing logrotate configuration..."
sudo logrotate -d /etc/logrotate.d/internet-monitor

echo ""
echo "📋 Log rotation summary:"
echo "  • CSV files: Rotated weekly or when >10MB, keep 8 weeks"
echo "  • Log files: Rotated weekly or when >50MB, keep 4 weeks"  
echo "  • Report files: Rotated monthly, keep 6 months"
echo "  • Old logs are compressed to save space"
echo "  • Current logs remain accessible to the monitor"
echo ""

# Show current disk usage
echo "💾 Current log directory size:"
du -sh internet_logs/

echo ""
echo "✅ Log rotation setup complete!"
echo ""
echo "Manual commands:"
echo "  • Force rotation: sudo logrotate -f /etc/logrotate.d/internet-monitor"
echo "  • Check status: sudo cat /var/lib/logrotate/status | grep internet"
echo "  • View rotated logs: ls -la internet_logs/*.gz"