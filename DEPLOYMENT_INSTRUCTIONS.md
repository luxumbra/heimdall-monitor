# Heimdall Monitor - Complete Deployment Instructions

## Understanding the Architecture

This monitoring system has a **split architecture**:
- **Local Machine**: Runs monitoring scripts, captures your HOME connection data
- **VPS**: Hosts the web dashboard, displays the collected data

## Quick Deployment (3 Steps)

### Step 1: Deploy Dashboard to VPS
```bash
# SSH into your VPS
ssh user@your-vps-ip

# Create directory for logs
mkdir -p /opt/internet-monitor/logs

# Deploy Docker dashboard
docker-compose -f docker-compose.yml up -d
```

### Step 2: Configure Local Machine
```bash
# On your local machine (where monitoring happens)
cd /path/to/heimdall-monitor

# Edit configuration
nano monitor_config.ini

# Enable VPS upload and set details
[VPS]
enabled = true
hostname = your-vps.com
username = your-username
key_file = ~/.ssh/id_rsa
remote_directory = /opt/internet-monitor/logs
port = 22

[MONITOR]
location_name = "My Home Network"
```

### Step 3: Start Monitoring
```bash
# Run the monitor (uploads to VPS automatically)
python3 internet_monitor.py
```

## Access Dashboard
Open in browser: `http://<your-vps-ip>:3000`

## Key Points

✅ **What gets monitored**: Your HOME internet connection
✅ **Where data is collected**: On your local machine
✅ **Where data is displayed**: On the VPS dashboard
✅ **Data transfer**: Secure SCP upload to VPS
✅ **Privacy**: All monitoring data stays within your control

## Alternative: Docker on Local Machine

If you prefer running everything locally:
```bash
# No VPS needed
docker-compose up -d

# Access locally
http://localhost:3000
```

This monitors your home connection without any remote server.
