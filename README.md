# Heimdall Monitor

A comprehensive internet connectivity monitoring system with web dashboard, speed testing, and VPS log synchronization.

## 🚀 Features

- **Real-time Connectivity Monitoring** - Tests connection every 5-30 seconds
- **Speed Testing** - Periodic speed tests using Ookla's speedtest CLI  
- **Disconnect Detection** - Logs outages and calculates uptime statistics
- **Web Dashboard** - Real-time charts and statistics via web interface
- **VPS Sync** - Automatic log upload to remote servers via SCP
- **Multiple Deployment Options** - Systemd service, Docker, or manual
- **Security Hardened** - Sandboxed systemd service with minimal permissions

## 📊 Screenshots

The dashboard shows:
- Connection status and uptime percentage
- Real-time speed test results and trends  
- Disconnect events and duration statistics
- Historical charts and data analysis

## 🛠️ Quick Setup

### 1. Clone and Install Dependencies

```bash
git clone https://github.com/luxumbra/internet-monitor.git
cd internet-monitor
npm install
pip3 install requests schedule configparser
```

### 2. Install Speedtest CLI

```bash
# Ubuntu/Debian
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
sudo apt-get install speedtest

# Other systems: https://www.speedtest.net/apps/cli
```

### 3. Configure

```bash
# Copy example configuration
cp .env.example .env
cp monitor_config.ini.example monitor_config.ini

# Edit configuration files
nano .env
nano monitor_config.ini
```

### 4. Run

```bash
# Run monitoring script
python3 src/monitor/internet_monitor.py

# Run web dashboard (separate terminal)
npm start
# Or run in background with PM2:
npm run pm2:start
```

## 🐳 Docker Deployment

For VPS deployment with Dokploy:

```bash
# Use VPS-specific configuration
docker-compose -f docker-compose.vps.yml up -d
```

## 🔧 Systemd Service Setup

For production deployments:

```bash
# Install as system service (auto-detects directory)
./scripts/install-service.sh

# Or specify user and directory explicitly:
./scripts/install-service.sh username /path/to/monitor

# Manage service
sudo systemctl start internet-monitor-$USER
sudo systemctl enable internet-monitor-$USER
sudo systemctl status internet-monitor-$USER
```

## 📋 Configuration

### Environment Variables (.env)

```bash
PING_INTERVAL=30          # Connectivity test interval (seconds)
SPEEDTEST_INTERVAL=300    # Speed test interval (seconds)  
UPLOAD_INTERVAL=120       # VPS upload interval (seconds)
LOCATION_NAME="Home"      # Network location name
NODE_ENV=production       # Node.js environment
PORT=3000                 # Web dashboard port
```

### VPS Upload (monitor_config.ini)

```ini
[VPS]
enabled = true
hostname = your-server.com
username = your-user
key_file = ~/.ssh/your_key
remote_directory = /opt/internet-monitor/logs
port = 22

[MONITOR]  
location_name = Your Network
timezone = UTC
```

## 📈 Monitoring Data

The system tracks:

- **Connectivity Tests** - Ping and HTTP tests to multiple targets
- **Speed Tests** - Download/upload speeds and latency measurements
- **Disconnect Events** - Outage start/end times and durations
- **Statistics** - Uptime percentages, average speeds, failure rates

## 🔐 Security Features

- **Portable Configuration** - No hard-coded paths, works anywhere
- **Sandboxed systemd service** with minimal permissions
- **Read-only system** and home directory access
- **Private temporary directory**
- **Resource limits** (256MB RAM, 1024 file handles)
- **No privilege escalation** allowed
- **Template configurations** for secure public repository sharing

## 📁 File Structure

```
heimdall-monitor/
├── src/
│   ├── monitor/
│   │   └── internet_monitor.py      # Core monitoring script
│   └── server/
│       ├── server.js                # Web dashboard server
│       └── public/index.html        # Dashboard frontend
├── scripts/
│   ├── install-service.sh           # Portable service installer
│   ├── setup_monitor.sh             # Initial setup script
│   └── test-portability.sh          # Portability verification script
├── config/
│   ├── templates/
│   │   ├── internet-monitor-template.service      # Systemd service template
│   │   ├── internet-monitor-server-template.service # Server service template
│   │   └── internet-monitor-logrotate.example     # Log rotation config
│   ├── .env.example                 # Example environment config
│   └── monitor_config.ini.example   # Example VPS config
├── logs/                            # Generated log files
│   ├── connectivity.csv             # Connection test results
│   ├── speedtest.csv                # Speed test results
│   ├── events.csv                   # Disconnect events
│   └── monitor.log                  # Application logs
├── docs/
│   └── README.md                    # Documentation
├── docker-compose.vps.yml           # VPS Docker config
└── package.json                     # Node.js configuration
```

## 🔄 Log Rotation

Automatic log rotation prevents disk space issues:

```bash
# Setup log rotation
./setup_log_rotation.sh
```

## 📊 API Endpoints

- `GET /` - Web dashboard
- `GET /api/status` - System status and statistics
- `GET /api/connectivity` - Recent connectivity data
- `GET /api/speedtest` - Speed test results
- `GET /api/events` - Disconnect events
- `GET /health` - Health check endpoint

## 🐛 Troubleshooting

### Common Issues

1. **Speedtest not working** - Install Ookla speedtest CLI
2. **Permission denied** - Ensure SSH keys have correct permissions (600)
3. **Service won't start** - Check systemd logs: `sudo journalctl -u internet-monitor-$USER`
4. **Dashboard empty** - Verify CSV files exist in `internet_logs/`
5. **AttributeError** - Kill old running processes: `pkill -f internet_monitor.py`

### Portability Check

```bash
# Verify no hard-coded paths exist
./scripts/test-portability.sh
```

### Debug Mode

```bash
# Run with debug output
python3 src/monitor/internet_monitor.py --ping-interval 10 --speedtest-interval 60
```

## 📜 License

MIT License - See LICENSE file for details

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📞 Support

- Create an issue for bug reports
- Check existing issues for solutions
- Include logs and configuration (sanitized) when reporting problems