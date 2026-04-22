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

#### ✅ GitHub Configuration

No GitHub Secrets are required for this workflow. GitHub automatically provides `GITHUB_TOKEN` with sufficient permissions.

**GitHub Actions Workflow**:

1.  On every push to `main` branch
2.  Image is automatically built for **ARM64 architecture**
3.  Pushed to private GitHub Container Registry: `ghcr.io/your-username/heimdall-monitor:latest`
4.  Dokploy will automatically detect and pull updated image

#### ✅ Dokploy Setup

1.  In Dokploy create new "Docker Image" application
2.  Use image: `ghcr.io/your-username/heimdall-monitor:latest`
3.  Enable **Auto Deploy**
4.  Create volume mount: `internet_logs_data` → `/app/internet_logs`
5.  Expose port: `3000`

**Dokploy Environment Variables**:
| Variable | Default | Description |
|----------|---------|-------------|
| `NODE_ENV` | `production` | Runtime environment |
| `PORT` | `3000` | Server port |
| `LOCATION_NAME` | `Home Connection Monitor` | Monitor location display name |
| `TZ` | `UTC` | Server timezone |

**Deploy**:

```bash
# Push to main branch
git push origin main
# GitHub Actions builds and publishes container image
# Dokploy automatically updates deployment
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

#### ✅ Dashboard Server (Dokploy)

These variables are set **in Dokploy** for the dashboard container:

```env
NODE_ENV=production
PORT=3000
TZ=UTC
LOCATION_NAME="Home Network"
```

#### ⚠️ Local Monitor Service (your home machine)

These variables are only for the local monitoring service that runs at your home location. **DO NOT set these in Dokploy**:

```env
PING_INTERVAL=30
SPEEDTEST_INTERVAL=300
UPLOAD_INTERVAL=120
VPS_UPLOAD_ENABLED=true
VPS_HOST=your-vps-ip
VPS_USER=root
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
