# Internet Monitor Service Setup

## 🔧 Portable Service Installation

This service setup removes hard-coded paths and improves security through proper systemd configuration.

## 📁 Files

- `internet-monitor-template.service` - Template service file
- `install-service.sh` - Automatic installation script  
- `uninstall-service.sh` - Removal script
- `.env` - Environment configuration

## 🚀 Installation

### Quick Install (Current User)
```bash
./install-service.sh
```

### Custom Install
```bash
# Install for specific user and directory
./install-service.sh username /path/to/monitor/directory
```

## ⚙️ Configuration

Edit `.env` file:
```bash
PING_INTERVAL=5
SPEEDTEST_INTERVAL=300
UPLOAD_INTERVAL=120
LOCATION_NAME="Your Network Name"
NODE_ENV=production
PORT=3000
```

## 🔐 Security Features

The service includes security hardening:

- **NoNewPrivileges**: Prevents privilege escalation
- **ProtectSystem**: Read-only system directories
- **ProtectHome**: Read-only home directories (except working dir)
- **ReadWritePaths**: Only logs directory writable
- **PrivateTmp**: Isolated temporary directory
- **Resource limits**: Memory (256MB) and file handles (1024)

## 📊 Service Management

```bash
# Start service
sudo systemctl start internet-monitor-$USER

# Stop service
sudo systemctl stop internet-monitor-$USER

# Enable auto-start on boot
sudo systemctl enable internet-monitor-$USER

# View status
sudo systemctl status internet-monitor-$USER

# View logs
sudo journalctl -u internet-monitor-$USER -f
```

## 🗑️ Uninstallation

```bash
./uninstall-service.sh
```

## 🌐 Portability Benefits

1. **No hard-coded paths** - Works in any directory
2. **User-specific** - Multiple users can run separate instances
3. **Environment-driven** - Configuration via `.env` file
4. **Secure by default** - Minimal permissions and sandboxing
5. **Resource limited** - Prevents resource exhaustion

## 📝 Example Multi-User Setup

```bash
# Install for user 'alice'
sudo -u alice ./install-service.sh alice /home/alice/monitoring

# Install for user 'bob'  
sudo -u bob ./install-service.sh bob /home/bob/internet-monitor

# Each runs independently with their own configuration
```