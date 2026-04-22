# Heimdall Monitor - Deployment Guide

## Overview
This guide covers deployment of Heimdall Monitor to monitor your HOME internet connection from a Dokploy-managed VPS using GitHub Actions.

## Architecture
```
[Your Home Network] ← (monitored locally) → [Your VPS] → [Web Dashboard]
```

**Important**: The monitoring scripts run on YOUR local machine and upload data to the VPS for dashboard display. This monitors your home connection, NOT the VPS connection.

## Quick Start

### 1. Deploy Dashboard to VPS
```bash
# Using Docker Compose
docker-compose -f docker-compose.yml up -d

# Or use Dokploy deployment (see below)
```

### 2. Configure Local Monitoring
```bash
# Enable VPS upload in monitor_config.ini
# Or set environment variables
```

### 3. Start Monitoring
```bash
# Run locally
python3 internet_monitor.py
```

### 4. Access Dashboard
```
http://<your-vps-ip>:3000
```

## Deployment Methods

### Method 1: GitHub Actions + Dokploy (Recommended)

**Setup GitHub Secrets**:
- `DOKPLOY_HOST`: VPS IP address
- `DOKPLOY_USERNAME`: SSH username
- `DOKPLOY_SSH_KEY`: SSH private key
- `DOKPLOY_PORT`: SSH port (22)

**Deploy**:
```bash
# Push to main branch
git push origin main
# GitHub Actions auto-deploys
```

### Method 2: Direct Docker Compose

```bash
# Deploy dashboard
docker-compose up -d
```

### Method 3: Dokploy API

```bash
# Deploy via Dokploy API
curl -X POST "https://your-dokploy.com/api/apps/create" \
  -H "Authorization: Bearer YOUR_KEY" \
  -d '{"name": "monitor", ...}'
```

## Configuration

### Environment Variables
```env
NODE_ENV=production
PORT=3000
PING_INTERVAL=30
SPEEDTEST_INTERVAL=300
UPLOAD_INTERVAL=120
LOCATION_NAME="Home Network"
```

### Monitor Config (monitor_config.ini)
```ini
[VPS]
enabled = true
hostname = your-server.com
username = your-user
key_file = ~/.ssh/id_rsa
remote_directory = /opt/internet-monitor/logs
```

## What Gets Monitored

✅ **From Your Home**:
- Ping to DNS servers (8.8.8.8, 1.1.1.1)
- HTTP connectivity tests
- Speed tests (download/upload)
- Disconnect events
- Historical statistics

❌ **NOT Monitored**:
- VPS performance
- External networks

## Data Flow

```
[Local] → (SCP) → [VPS] → [Dashboard]
  ↓
internet_monitor.py
  ↓
Uploads CSV files
  ↓
Secure transfer
```

## Troubleshooting

**Dashboard not accessible**:
```bash
# Check container
docker ps | grep internet-monitor

# View logs
docker logs internet-monitor-dashboard
```

**Upload failures**:
```bash
# Check SSH key permissions
chmod 600 ~/.ssh/id_rsa

# Test SSH connection
ssh -i ~/.ssh/id_rsa user@vps-ip
```

## Maintenance

**Update monitoring**:
```bash
git add .
git commit -m "Update"
git push origin main
```

**View logs**:
```bash
# Application logs
docker logs internet-monitor-dashboard

# CSV data
cat internet_logs/*.csv
```
