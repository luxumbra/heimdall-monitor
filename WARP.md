# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

Heimdall Monitor is a comprehensive internet connectivity monitoring system with web dashboard, speed testing, and VPS log synchronization. It consists of two main components:

1. **Python monitoring script** (`internet_monitor.py`) - Performs connectivity tests, speed tests, and logs results
2. **Node.js web server** (`server.js`) - Serves API endpoints and dashboard for viewing monitoring data

## Core Architecture

### Data Flow
- Python script tests connectivity every 5-30 seconds using ping and HTTP requests
- Speed tests run periodically using Ookla's speedtest CLI
- All data is logged to CSV files in `internet_logs/` directory
- Node.js server reads these CSV files and serves data via REST API
- Web dashboard displays real-time charts and statistics

### Key Components
- **InternetMonitor class**: Main Python monitoring engine with configurable intervals
- **CSV data storage**: Structured logging to `connectivity.csv`, `speedtest.csv`, `events.csv`
- **Express.js API**: RESTful endpoints for dashboard data consumption
- **Systemd service**: Production deployment with security hardening
- **Docker containers**: Multi-stage builds supporting both local and VPS deployment

## Development Commands

### Local Development
```bash
# Install dependencies
npm install
pip3 install requests schedule configparser

# Install speedtest CLI (Ubuntu/Debian)
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
sudo apt-get install speedtest

# Configuration setup
cp .env.example .env
cp monitor_config.ini.example monitor_config.ini

# Run monitoring script
python3 internet_monitor.py

# Run web dashboard (separate terminal)
npm start
# Or with PM2:
npm run pm2:start
```

### Testing and Debug
```bash
# Run with custom intervals for testing
python3 internet_monitor.py --ping-interval 10 --speedtest-interval 60

# Generate report from existing logs
python3 internet_monitor.py --report

# Check portability (no hard-coded paths)
./test-portability.sh
```

### Docker Development
```bash
# Local Docker setup
docker-compose up -d

# VPS deployment (dashboard only)
docker-compose -f docker-compose.vps.yml up -d

# Check container health
docker-compose ps
```

### Systemd Service (Production)
```bash
# Install service (auto-detects directory and user)
./install-service.sh

# Or specify custom user/directory
./install-service.sh username /path/to/monitor

# Service management
sudo systemctl start internet-monitor-$USER
sudo systemctl enable internet-monitor-$USER
sudo systemctl status internet-monitor-$USER
sudo journalctl -u internet-monitor-$USER -f

# Uninstall
./uninstall-service.sh
```

## Configuration

### Environment Variables (.env)
- `PING_INTERVAL`: Connectivity test frequency (default: 30s)
- `SPEEDTEST_INTERVAL`: Speed test frequency (default: 3600s)
- `UPLOAD_INTERVAL`: VPS upload frequency (default: 300s)
- `LOCATION_NAME`: Network location identifier
- `PORT`: Web dashboard port (default: 3000)

### VPS Configuration (monitor_config.ini)
- VPS sync via SCP using SSH keys
- Configurable hostname, username, key file, remote directory
- Automatic log and report uploads

## API Endpoints

### Primary Endpoints
- `GET /` - Web dashboard interface
- `GET /api/status` - System status and 24h statistics
- `GET /api/connectivity` - Recent connectivity test results
- `GET /api/speedtest` - Speed test data with filtering
- `GET /api/events` - Disconnect events with durations
- `GET /api/hourly-stats` - Aggregated hourly success rates
- `GET /health` - Health check for containers/monitoring

### Query Parameters
- `hours`: Time range filter (default: 24)
- `limit`: Record count limit (connectivity: 1000, speedtest: 100, events: 50)

## Security Features

The systemd service includes comprehensive security hardening:
- Sandboxed execution with `NoNewPrivileges`
- Read-only system and home directory access
- Private temporary directory isolation  
- Resource limits (256MB RAM, 1024 file handles)
- Minimal writable paths (logs directory only)

## File Structure

```
internet-monitor/
├── internet_monitor.py           # Main monitoring script
├── server.js                     # Web dashboard server  
├── public/index.html             # Dashboard frontend
├── install-service.sh            # Portable service installer
├── docker-compose.yml            # Local Docker config
├── docker-compose.vps.yml        # VPS deployment config
├── entrypoint.sh                 # Docker container startup
└── internet_logs/                # Generated data files
    ├── connectivity.csv          # Connection test results
    ├── speedtest.csv             # Speed measurements  
    ├── events.csv                # Disconnect events
    └── monitor.log               # Application logs
```

## Key Design Patterns

### Portability
- No hard-coded paths - works in any directory
- User-specific service names for multi-user deployments
- Environment-driven configuration
- Template-based service file generation

### Data Consistency  
- CSV-based structured logging for reliable data persistence
- Idempotent operations with proper error handling
- Graceful degradation when external services (speedtest) fail
- Comprehensive connectivity testing (ping + HTTP to multiple targets)

### Container Architecture
- Multi-stage Docker builds with both Python and Node.js
- Proper signal handling for graceful shutdowns
- Health checks and resource limits
- Separate VPS deployment mode (dashboard-only)

## Common Issues

1. **Speedtest CLI missing**: Install Ookla speedtest CLI using package manager
2. **Permission denied**: Ensure SSH keys have 600 permissions for VPS uploads  
3. **Service won't start**: Check systemd logs with `journalctl -u internet-monitor-$USER`
4. **Empty dashboard**: Verify CSV files exist in `internet_logs/` directory
5. **AttributeError**: Kill old processes: `pkill -f internet_monitor.py`