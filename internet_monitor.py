#!/usr/bin/env python3
"""
Internet Connection Monitor
Monitors connectivity, logs disconnects, and runs periodic speed tests
"""

import time
import subprocess
import json
import csv
import logging
from datetime import datetime, timedelta
import requests
import socket
import threading
import schedule
import argparse
from pathlib import Path

class InternetMonitor:
    def __init__(self, log_dir="internet_logs", ping_interval=30, speedtest_interval=3600, upload_interval=300, config_file="monitor_config.ini"):
        self.log_dir = Path(log_dir)
        self.log_dir.mkdir(exist_ok=True)
        self.ping_interval = ping_interval  # seconds
        self.speedtest_interval = speedtest_interval  # seconds
        self.upload_interval = upload_interval
        self.config_file = config_file

        import configparser
        self.config = configparser.ConfigParser()
        config_path = Path(config_file)
        if config_path.exists():
            self.config.read(config_file)
        else:
            # Default config if file doesn't exist
            self.config['VPS'] = {
                'enabled': 'false',
                'hostname': 'your-vps-hostname.com',
                'username': 'your-username',
                'key_file': '~/.ssh/id_rsa',
                'remote_directory': '/opt/internet-monitor',
                'port': '22'
            }
            self.config['MONITOR'] = {
                'location_name': 'Home Network',
                'timezone': 'UTC'
            }
            with open(config_file, 'w') as f:
                self.config.write(f)

        # Setup logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(self.log_dir / 'monitor.log'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)

        # CSV files for structured data
        self.connectivity_log = self.log_dir / 'connectivity.csv'
        self.speedtest_log = self.log_dir / 'speedtest.csv'
        self.events_log = self.log_dir / 'events.csv'

        # Initialize CSV files
        self._init_csv_files()

        # Connection state tracking
        self.is_connected = True
        self.disconnect_start = None
        self.last_successful_ping = datetime.now()

        # Targets for connectivity testing
        self.ping_targets = [
            '8.8.8.8',      # Google DNS
            '1.1.1.1',      # Cloudflare DNS
            '208.67.222.222' # OpenDNS
        ]

        self.http_targets = [
            'https://www.google.com',
            'https://www.cloudflare.com',
            'https://httpbin.org/get'
        ]

    def _init_csv_files(self):
        """Initialize CSV files with headers if they don't exist"""

        # Connectivity log
        if not self.connectivity_log.exists():
            with open(self.connectivity_log, 'w', newline='') as f:
                writer = csv.writer(f)
                writer.writerow(['timestamp', 'status', 'target', 'response_time_ms', 'method'])

        # Speed test log
        if not self.speedtest_log.exists():
            with open(self.speedtest_log, 'w', newline='') as f:
                writer = csv.writer(f)
                writer.writerow(['timestamp', 'download_mbps', 'upload_mbps', 'ping_ms', 'server', 'status'])

        # Events log
        if not self.events_log.exists():
            with open(self.events_log, 'w', newline='') as f:
                writer = csv.writer(f)
                writer.writerow(['timestamp', 'event_type', 'duration_seconds', 'details'])

    def ping_test(self, target):
        """Test connectivity using ping"""
        try:
            # Use stricter ping settings: no DNS resolution, shorter timeout, fail fast
            result = subprocess.run(
                ['ping', '-c', '1', '-W', '3', '-n', target],
                capture_output=True, text=True, timeout=8
            )

            if result.returncode == 0:
                # Extract ping time from output
                output = result.stdout
                if 'time=' in output:
                    ping_time = float(output.split('time=')[1].split()[0])
                    return True, ping_time
                return True, 0
            else:
                self.logger.debug(f"Ping to {target} failed with return code {result.returncode}")
                return False, None
        except subprocess.TimeoutExpired:
            self.logger.debug(f"Ping to {target} timed out")
            return False, None
        except Exception as e:
            self.logger.debug(f"Ping to {target} failed: {e}")
            return False, None

    def http_test(self, url):
        """Test connectivity using HTTP request"""
        try:
            start_time = time.time()
            # Shorter timeout and disable retries for faster failure detection
            response = requests.get(url, timeout=5, allow_redirects=False)
            response_time = (time.time() - start_time) * 1000

            if response.status_code in [200, 301, 302, 303, 307, 308]:
                return True, response_time
            else:
                self.logger.debug(f"HTTP test to {url} returned status {response.status_code}")
                return False, None
        except requests.exceptions.RequestException as e:
            self.logger.debug(f"HTTP test to {url} failed: {e}")
            return False, None
        except Exception as e:
            self.logger.debug(f"HTTP test to {url} failed: {e}")
            return False, None

    def test_connectivity(self):
        """Comprehensive connectivity test"""
        results = []
        successful_tests = 0
        total_tests = 0

        # Test ping connectivity
        for target in self.ping_targets:
            success, response_time = self.ping_test(target)
            results.append({
                'timestamp': datetime.now().isoformat(),
                'status': 'connected' if success else 'disconnected',
                'target': target,
                'response_time_ms': response_time,
                'method': 'ping'
            })
            total_tests += 1
            if success:
                successful_tests += 1

        # Test HTTP connectivity
        for target in self.http_targets:
            success, response_time = self.http_test(target)
            results.append({
                'timestamp': datetime.now().isoformat(),
                'status': 'connected' if success else 'disconnected',
                'target': target,
                'response_time_ms': response_time,
                'method': 'http'
            })
            total_tests += 1
            if success:
                successful_tests += 1

        # Consider connected if more than 50% of tests pass
        connected = successful_tests > (total_tests * 0.5)
        
        # Debug logging for connectivity status
        self.logger.debug(f"Connectivity test: {successful_tests}/{total_tests} tests passed, overall status: {'connected' if connected else 'disconnected'}")

        # Log results
        with open(self.connectivity_log, 'a', newline='') as f:
            writer = csv.writer(f)
            for result in results:
                writer.writerow([
                    result['timestamp'],
                    result['status'],
                    result['target'],
                    result['response_time_ms'],
                    result['method']
                ])

        # Handle connection state changes
        self._handle_connection_state(connected)

        return connected

    def _handle_connection_state(self, connected):
        """Handle connection state changes and log events"""
        now = datetime.now()

        if connected and not self.is_connected:
            # Connection restored
            if self.disconnect_start:
                duration = (now - self.disconnect_start).total_seconds()
                self.logger.warning(f"Connection restored after {duration:.1f} seconds")

                # Log disconnect event
                with open(self.events_log, 'a', newline='') as f:
                    writer = csv.writer(f)
                    writer.writerow([
                        self.disconnect_start.isoformat(),
                        'disconnect',
                        duration,
                        f"Disconnected from {self.disconnect_start} to {now}"
                    ])

            self.is_connected = True
            self.disconnect_start = None
            self.last_successful_ping = now

        elif not connected and self.is_connected:
            # Connection lost
            self.logger.error("Internet connection lost!")
            self.is_connected = False
            self.disconnect_start = now

        elif connected:
            # Still connected, update last successful ping
            self.last_successful_ping = now

    def run_speedtest(self):
        """Run speed test using speedtest CLI (Ookla) or speedtest-cli fallback"""
        try:
            self.logger.info("Running speed test...")

            # Prefer new Ookla speedtest CLI
            cmd = ['speedtest', '--format=json']
            try:
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
                if result.returncode == 0:
                    data = json.loads(result.stdout)
                    # Ookla JSON structure 
                    download_mbps = data.get('download', {}).get('bandwidth', 0) / 1_000_000
                    upload_mbps = data.get('upload', {}).get('bandwidth', 0) / 1_000_000
                    ping_ms = data.get('ping', {}).get('latency', 0)
                    server = f"{data.get('server', {}).get('name', 'Unknown')} - {data.get('server', {}).get('location', '')}"

                else:
                    # Fallback to deprecated speedtest-cli
                    cmd = ['speedtest-cli', '--json']
                    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
                    if result.returncode == 0:
                        data = json.loads(result.stdout)
                        download_mbps = data['download'] / 1_000_000
                        upload_mbps = data['upload'] / 1_000_000
                        ping_ms = data['ping']
                        server = f"{data['server']['sponsor']} - {data['server']['name']}"
                    else:
                        raise Exception("Both speedtest CLIs failed")

            except FileNotFoundError:
                # Try fallback if primary not found
                cmd = ['speedtest-cli', '--json']
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
                if result.returncode == 0:
                    data = json.loads(result.stdout)
                    download_mbps = data['download'] / 1_000_000
                    upload_mbps = data['upload'] / 1_000_000
                    ping_ms = data['ping']
                    server = f"{data['server']['sponsor']} - {data['server']['name']}"
                else:
                    raise Exception("speedtest CLI not found. Install with: curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash && sudo apt-get install speedtest")

            self.logger.info(f"Speed test: {download_mbps:.1f} Mbps down, {upload_mbps:.1f} Mbps up, {ping_ms:.1f}ms ping")

            # Log to CSV
            with open(self.speedtest_log, 'a', newline='') as f:
                writer = csv.writer(f)
                writer.writerow([
                    datetime.now().isoformat(),
                    download_mbps,
                    upload_mbps,
                    ping_ms,
                    server,
                    'success'
                ])

            return True

        except Exception as e:
            self.logger.error(f"Speed test error: {str(e)}")

            # Log failure
            with open(self.speedtest_log, 'a', newline='') as f:
                writer = csv.writer(f)
                writer.writerow([
                    datetime.now().isoformat(),
                    None, None, None, None,
                    f'failed: {str(e)}'
                ])

            return False

    def generate_report(self):
        """Generate a summary report"""
        try:
            report_file = self.log_dir / f'report_{datetime.now().strftime("%Y%m%d_%H%M%S")}.txt'

            with open(report_file, 'w') as f:
                f.write("Internet Connection Monitoring Report\n")
                f.write("=" * 50 + "\n")
                f.write(f"Generated: {datetime.now()}\n\n")

                # Analyze connectivity data
                if self.connectivity_log.exists():
                    with open(self.connectivity_log, 'r') as csvfile:
                        reader = csv.DictReader(csvfile)
                        connectivity_data = list(reader)

                    total_tests = len(connectivity_data)
                    failed_tests = len([r for r in connectivity_data if r['status'] == 'disconnected'])
                    success_rate = ((total_tests - failed_tests) / total_tests * 100) if total_tests > 0 else 0

                    f.write(f"Connectivity Summary:\n")
                    f.write(f"- Total tests: {total_tests}\n")
                    f.write(f"- Failed tests: {failed_tests}\n")
                    f.write(f"- Success rate: {success_rate:.1f}%\n\n")

                # Analyze disconnection events
                if self.events_log.exists():
                    with open(self.events_log, 'r') as csvfile:
                        reader = csv.DictReader(csvfile)
                        events_data = list(reader)

                    disconnects = [e for e in events_data if e['event_type'] == 'disconnect']

                    if disconnects:
                        total_downtime = sum(float(d['duration_seconds']) for d in disconnects)
                        avg_disconnect_duration = total_downtime / len(disconnects)

                        f.write(f"Disconnection Summary:\n")
                        f.write(f"- Total disconnections: {len(disconnects)}\n")
                        f.write(f"- Total downtime: {total_downtime:.1f} seconds ({total_downtime/60:.1f} minutes)\n")
                        f.write(f"- Average disconnect duration: {avg_disconnect_duration:.1f} seconds\n\n")

                # Analyze speed test data
                if self.speedtest_log.exists():
                    with open(self.speedtest_log, 'r') as csvfile:
                        reader = csv.DictReader(csvfile)
                        speedtest_data = list(reader)

                    successful_tests = [s for s in speedtest_data if s['status'] == 'success']

                    if successful_tests:
                        download_speeds = [float(s['download_mbps']) for s in successful_tests]
                        upload_speeds = [float(s['upload_mbps']) for s in successful_tests]

                        f.write(f"Speed Test Summary:\n")
                        f.write(f"- Total speed tests: {len(speedtest_data)}\n")
                        f.write(f"- Successful tests: {len(successful_tests)}\n")
                        f.write(f"- Average download: {sum(download_speeds)/len(download_speeds):.1f} Mbps\n")
                        f.write(f"- Average upload: {sum(upload_speeds)/len(upload_speeds):.1f} Mbps\n")
                        f.write(f"- Min download: {min(download_speeds):.1f} Mbps\n")
                        f.write(f"- Max download: {max(download_speeds):.1f} Mbps\n")

            self.logger.info(f"Report generated: {report_file}")
            return report_file

        except Exception as e:
            self.logger.error(f"Failed to generate report: {e}")
            return None

    def upload_logs(self):
        """Upload log files to VPS via SCP"""
        if not self.config.getboolean('VPS', 'enabled', fallback=False):
            return

        try:
            import subprocess
            import os

            hostname = self.config.get('VPS', 'hostname')
            username = self.config.get('VPS', 'username')
            key_file = Path(self.config.get('VPS', 'key_file')).expanduser()
            remote_dir = self.config.get('VPS', 'remote_directory')

            self.logger.info(f"Uploading logs to {username}@{hostname}:{remote_dir}...")

            # Create remote directory if it doesn't exist
            ssh_cmd = ['ssh', '-i', str(key_file), f'{username}@{hostname}', f'mkdir -p {remote_dir}']
            subprocess.run(ssh_cmd, check=True, capture_output=True)

            # Upload CSV files using SCP
            csv_files = ['connectivity.csv', 'speedtest.csv', 'events.csv']
            for csv_file in csv_files:
                local_path = self.log_dir / csv_file
                if local_path.exists():
                    scp_cmd = ['scp', '-i', str(key_file), str(local_path), f'{username}@{hostname}:{remote_dir}/']
                    subprocess.run(scp_cmd, check=True, capture_output=True)
                    self.logger.debug(f"Uploaded {csv_file}")
                else:
                    self.logger.debug(f"{csv_file} not found locally")

            # Upload latest report if exists
            report_files = list(self.log_dir.glob('report_*.txt'))
            if report_files:
                latest_report = max(report_files, key=lambda x: x.stat().st_mtime)
                scp_cmd = ['scp', '-i', str(key_file), str(latest_report), f'{username}@{hostname}:{remote_dir}/']
                subprocess.run(scp_cmd, check=True, capture_output=True)
                self.logger.debug(f"Uploaded report: {latest_report.name}")

            self.logger.info("Log upload completed successfully")

        except subprocess.CalledProcessError as e:
            self.logger.error(f"SCP upload failed: {e.stderr.decode() if e.stderr else str(e)}")
        except Exception as e:
            self.logger.error(f"Log upload failed: {str(e)}")

    def run_monitor(self):
        """Main monitoring loop"""
        self.logger.info("Starting Internet connection monitor...")
        self.logger.info(f"Ping interval: {self.ping_interval} seconds")
        self.logger.info(f"Speed test interval: {self.speedtest_interval} seconds")
        self.logger.info(f"Upload interval: {self.upload_interval} seconds (VPS enabled: {self.config.getboolean('VPS', 'enabled', fallback=False)})")
        self.logger.info(f"Logs directory: {self.log_dir}")

        # Schedule periodic tasks
        schedule.every(self.speedtest_interval).seconds.do(self.run_speedtest)

        if self.config.getboolean('VPS', 'enabled', fallback=False):
            schedule.every(self.upload_interval).seconds.do(self.upload_logs)

        # Initial speed test
        self.run_speedtest()

        try:
            while True:
                # Test connectivity
                self.test_connectivity()

                # Run scheduled tasks
                schedule.run_pending()

                # Wait for next check
                time.sleep(self.ping_interval)

        except KeyboardInterrupt:
            self.logger.info("Monitoring stopped by user")
            self.generate_report()

def main():
    parser = argparse.ArgumentParser(description='Monitor internet connection and log issues')
    parser.add_argument('--ping-interval', type=int, default=30,
                       help='Seconds between connectivity checks (default: 30)')
    parser.add_argument('--speedtest-interval', type=int, default=3600,
                       help='Seconds between speed tests (default: 3600)')
    parser.add_argument('--upload-interval', type=int, default=300,
                       help='Seconds between VPS uploads (default: 300)')
    parser.add_argument('--log-dir', default='internet_logs',
                       help='Directory for log files (default: internet_logs)')
    parser.add_argument('--config', default='monitor_config.ini',
                       help='Configuration file (default: monitor_config.ini)')
    parser.add_argument('--report', action='store_true',
                       help='Generate report from existing logs and exit')
    parser.add_argument('--setup-vps', action='store_true',
                       help='Enable VPS uploads in config')

    args = parser.parse_args()

    monitor = InternetMonitor(
        log_dir=args.log_dir,
        ping_interval=args.ping_interval,
        speedtest_interval=args.speedtest_interval,
        upload_interval=args.upload_interval,
        config_file=args.config
    )

    if args.setup_vps:
        # Enable VPS uploads
        monitor.config.set('VPS', 'enabled', 'true')
        with open(args.config, 'w') as f:
            monitor.config.write(f)
        print(f"VPS uploads enabled. Edit {args.config} with your server details.")
        return

    if args.report:
        monitor.generate_report()
    else:
        monitor.run_monitor()

if __name__ == "__main__":
    main()
