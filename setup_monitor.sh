#!/bin/bash
# setup_monitor.sh - Setup script for Internet Connection Monitor

set -e

echo "🌐 Heimdall Internet Connection Monitor Setup 🌐"
echo "=============================================="

# Check if running as root on VPS
if [[ "$1" == "--vps" ]]; then
    echo "Setting up VPS with Node.js server..."

    # Check for Node.js
    if ! command -v node &> /dev/null; then
        echo "📦 Installing Node.js..."

        # Install Node.js using NodeSource repository
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs

        echo "✅ Node.js $(node --version) installed"
    else
        echo "✅ Node.js $(node --version) found"
    fi

    # Check for npm
    if ! command -v npm &> /dev/null; then
        echo "❌ npm is required but not found"
        exit 1
    fi

    # Create application directory
    APP_DIR="/opt/internet-monitor"
    sudo mkdir -p "$APP_DIR"
    sudo mkdir -p "$APP_DIR/public"

    # Set ownership
    sudo chown -R $USER:$USER "$APP_DIR"

    echo "📁 Created application directory: $APP_DIR"
    echo "📝 Upload your server files to: $APP_DIR"
    echo "📝 Upload index.html to: $APP_DIR/public/"

    # Install PM2 for process management
    sudo npm install -g pm2
    echo "✅ PM2 installed for process management"

    # Create systemd service for PM2
    pm2 startup systemd -u $USER --hp /home/$USER

    # Setup nginx reverse proxy
    if command -v nginx &> /dev/null; then
        cat << EOF | sudo tee /etc/nginx/sites-available/internet-monitor
server {
    listen 80;
    server_name _;  # Replace with your domain

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

        echo "📋 Nginx reverse proxy config created."
        echo "   Enable with:"
        echo "   sudo ln -s /etc/nginx/sites-available/internet-monitor /etc/nginx/sites-enabled/"
        echo "   sudo nginx -t && sudo systemctl reload nginx"

        # Remove default nginx site
        echo "   sudo rm -f /etc/nginx/sites-enabled/default"
    fi

    # Setup firewall
    if command -v ufw &> /dev/null; then
        echo "🔥 Configuring firewall..."
        sudo ufw allow 22/tcp    # SSH
        sudo ufw allow 80/tcp    # HTTP
        sudo ufw allow 443/tcp   # HTTPS
        sudo ufw allow 3000/tcp  # Node.js (direct access)
        echo "✅ Firewall configured"
    fi

    echo ""
    echo "🎉 VPS setup complete!"
    echo ""
    echo "Next steps:"
    echo "1. Upload server.js to $APP_DIR/"
    echo "2. Upload package.json to $APP_DIR/"
    echo "3. Upload index.html to $APP_DIR/public/"
    echo "4. cd $APP_DIR && npm install"
    echo "5. pm2 start server.js --name internet-monitor"
    echo "6. pm2 save"
    echo ""

    exit 0
fi

# Local setup
echo "Setting up local monitoring..."

# Check Python version
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed"
    exit 1
fi

echo "✅ Python 3 found"

# Check for pip
if ! command -v pip3 &> /dev/null; then
    echo "❌ pip3 is required but not installed"
    echo "Install with: sudo apt install python3-pip (Ubuntu/Debian)"
    exit 1
fi

echo "✅ pip3 found"

# Check for Node.js (optional for local development)
if command -v node &> /dev/null; then
    echo "✅ Node.js $(node --version) found"
    NODE_AVAILABLE=true
else
    echo "⚠️  Node.js not found (optional for local web server)"
    NODE_AVAILABLE=false
fi

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip3 install --user requests schedule paramiko configparser

# Check for speedtest (Ookla's official CLI)
# Note: This is only needed on the local machine where internet_monitor.py runs
# The Docker container only runs the web server and doesn't need speedtest
if ! command -v speedtest &> /dev/null; then
    echo "📦 Installing Ookla speedtest CLI..."

    # Try different installation methods
    if command -v apt &> /dev/null; then
        curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
        sudo apt-get install -y speedtest
    elif command -v yum &> /dev/null; then
        curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh | sudo bash
        sudo yum install -y speedtest
    else
        echo "⚠️  Please install speedtest CLI manually:"
        echo "   Visit: https://www.speedtest.net/apps/cli"
    fi
fi

# Check for speedtest-cli (deprecated version) as fallback
if ! command -v speedtest-cli &> /dev/null; then
    echo "📦 Installing speedtest-cli (deprecated) as fallback..."

    # Try different installation methods
    if command -v apt &> /dev/null; then
        sudo apt update && sudo apt install -y speedtest-cli
    elif command -v yum &> /dev/null; then
        sudo yum install -y speedtest-cli
    elif command -v brew &> /dev/null; then
        brew install speedtest-cli
    else
        echo "⚠️  Please install speedtest-cli manually:"
        echo "   pip3 install --user speedtest-cli"
        echo "   or visit: https://www.speedtest.net/apps/cli"
    fi
fi

if command -v speedtest &> /dev/null; then
    echo "✅ Ookla speedtest CLI installed"
elif command -v speedtest-cli &> /dev/null; then
    echo "⚠️  Ookla speedtest CLI not found, using deprecated speedtest-cli"
else
    echo "⚠️  No speedtest CLI found, speed tests will fail"
fi

# Create directories
echo "📁 Creating directories..."
mkdir -p internet_logs
mkdir -p public
mkdir -p ~/.ssh

# Generate SSH key if it doesn't exist
if [ ! -f ~/.ssh/id_rsa ]; then
    echo "🔑 Generating SSH key for VPS access..."
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -q
    echo "✅ SSH key generated at ~/.ssh/id_rsa"
    echo "📋 Add this public key to your VPS:"
    echo
    cat ~/.ssh/id_rsa.pub
    echo
    echo "Run this on your VPS:"
    echo "mkdir -p ~/.ssh && echo '$(cat ~/.ssh/id_rsa.pub)' >> ~/.ssh/authorized_keys"
    echo
fi

# Install Node.js dependencies if Node is available
if [ "$NODE_AVAILABLE" = true ] && [ -f "package.json" ]; then
    echo "📦 Installing Node.js dependencies..."
    npm install
    echo "✅ Node.js dependencies installed"
fi

# Create systemd service file for Python monitor
echo "🔧 Creating Python monitor systemd service..."
cat << EOF > internet-monitor.service
[Unit]
Description=Internet Connection Monitor (Python)
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$(pwd)
ExecStart=$(which python3) $(pwd)/internet_monitor.py
Restart=always
RestartSec=10
Environment=PATH=$PATH

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service file for Node.js server
if [ "$NODE_AVAILABLE" = true ]; then
    echo "🔧 Creating Node.js server systemd service..."
    cat << EOF > internet-monitor-server.service
[Unit]
Description=Internet Connection Monitor Web Server (Node.js)
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$(pwd)
ExecStart=$(which node) $(pwd)/server.js
Restart=always
RestartSec=5
Environment=NODE_ENV=production
Environment=PORT=3000

[Install]
WantedBy=multi-user.target
EOF
fi

echo "📋 To install Python monitor as a system service:"
echo "   sudo cp internet-monitor.service /etc/systemd/system/"
echo "   sudo systemctl enable internet-monitor"
echo "   sudo systemctl start internet-monitor"

if [ "$NODE_AVAILABLE" = true ]; then
    echo ""
    echo "📋 To install Node.js server as a system service:"
    echo "   sudo cp internet-monitor-server.service /etc/systemd/system/"
    echo "   sudo systemctl enable internet-monitor-server"
    echo "   sudo systemctl start internet-monitor-server"
fi

# Create config file
echo "⚙️  Creating configuration..."
python3 -c "
import configparser
import os

config = configparser.ConfigParser()
config['VPS'] = {
    'enabled': 'false',
    'hostname': 'your-vps-hostname.com',
    'username': 'your-username',
    'key_file': '~/.ssh/id_rsa',
    'remote_directory': '/home/your-username/internet_logs',
    'port': '22'
}

config['MONITOR'] = {
    'location_name': 'Home Network',
    'timezone': 'UTC'
}

with open('monitor_config.ini', 'w') as f:
    config.write(f)

print('✅ Configuration file created: monitor_config.ini')
"

echo
echo "🎉 Setup complete!"
echo
echo "Next steps:"
echo "1. Edit monitor_config.ini with your VPS details"
echo "2. Test the Python monitor: python3 internet_monitor.py"
echo "3. Enable VPS uploads: python3 internet_monitor.py --setup-vps"

if [ "$NODE_AVAILABLE" = true ]; then
    echo "4. Test the web server locally: npm start"
    echo "5. Access dashboard at: http://localhost:3000"
fi

echo "6. Setup VPS: ./setup_monitor.sh --vps"
echo "7. Install as services (optional)"
echo
echo "For Dokploy deployment:"
echo "1. Ensure you have Docker and Docker Compose installed on your VPS"
echo "2. Copy the following files to your VPS:"
echo "   - Dockerfile"
echo "   - docker-compose.yml"
echo "   - server.js"
echo "   - package.json"
echo "   - public/index.html"
echo "3. Create an internet_logs directory on your VPS: mkdir internet_logs"
echo "4. Run 'docker-compose up -d' on your VPS to start the service"
echo
echo "Important notes about the deployment architecture:"
echo "- The internet_monitor.py script runs locally on your machine (not in Docker)"
echo "- It requires speedtest CLI installation with sudo (handled by this setup script)"
echo "- The Docker container only runs the web server to display monitoring data"
echo "- The local monitor uploads logs to your VPS via SCP"
echo "- The Docker container accesses these logs through volume mapping"
echo
echo "To share log files between the local monitor and Docker container:"
echo "1. The local monitor will upload logs to your VPS via SCP"
echo "2. Configure the internet_monitor.py script to upload logs to the internet_logs directory on your VPS"
echo "3. The Docker container is configured to mount this directory as a volume, making the logs accessible to the web server"
echo
echo "File structure:"
echo "📁 Current directory:"
echo "├── internet_monitor.py    # Python monitoring script"

if [ "$NODE_AVAILABLE" = true ]; then
    echo "├── server.js             # Node.js web server"
    echo "├── package.json          # Node.js dependencies"
fi

echo "├── public/index.html     # Web dashboard"
echo "├── monitor_config.ini    # Configuration file"
echo "├── Dockerfile            # Docker configuration for Node.js server"
echo "├── docker-compose.yml    # Docker Compose configuration for deployment"
echo "└── internet_logs/        # Log files directory"
echo
echo "Happy monitoring! 📊"
