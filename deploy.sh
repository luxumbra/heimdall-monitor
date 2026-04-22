#!/bin/bash
# Heimdall Monitor Deployment Script
# This script deploys the monitoring system to a remote server

set -e

echo "=========================================="
echo "Heimdall Monitor Deployment"
echo "=========================================="

# Check if running on VPS
if [ "$1" == "--vps" ]; then
    echo "Deploying to VPS..."
    
    # Install dependencies
    echo "Installing dependencies..."
    apt-get update
    apt-get install -y docker.io docker-compose
    
    # Start Docker
    systemctl start docker
    systemctl enable docker
    
    # Deploy with Docker Compose
    echo "Deploying with Docker Compose..."
    docker-compose -f docker-compose.vps.yml up -d
    
    echo "Deployment complete! Access the dashboard at:"
    echo "  http://<your-server-ip>:3000"
    exit 0
fi

# Local deployment
echo "Starting local deployment..."

# Test Python monitor
echo "Testing Python monitor..."
python3 internet_monitor.py --ping-interval 5 --speedtest-interval 60 &
MONITOR_PID=$!

# Start Node.js dashboard
echo "Starting Node.js dashboard..."
npm start &
DASHBOARD_PID=$!

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo "Dashboard: http://localhost:3000"
echo "API Status: http://localhost:3000/api/status"
echo ""
echo "Processes running:"
echo "  - Monitor (PID: $MONITOR_PID)"
echo "  - Dashboard (PID: $DASHBOARD_PID)"
echo ""
echo "To stop: pkill -f internet_monitor.py && pkill -f 'node server.js'"
echo "To run in background: nohup ./deploy.sh &"

# Keep script running if called directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    wait
fi
