#!/bin/bash
set -e

# Internet Monitor Entrypoint Script
# Runs both Python monitoring and Node.js dashboard

echo "🌐 Starting Internet Monitor Container..."

# Set default environment variables
export PING_INTERVAL="${PING_INTERVAL:-30}"
export SPEEDTEST_INTERVAL="${SPEEDTEST_INTERVAL:-3600}"
export UPLOAD_INTERVAL="${UPLOAD_INTERVAL:-300}"
export LOCATION_NAME="${LOCATION_NAME:-Docker Monitor}"
export NODE_ENV="${NODE_ENV:-production}"
export PORT="${PORT:-3000}"

echo "📊 Configuration:"
echo "  - Ping interval: ${PING_INTERVAL}s"
echo "  - Speed test interval: ${SPEEDTEST_INTERVAL}s"
echo "  - Upload interval: ${UPLOAD_INTERVAL}s"
echo "  - Location: ${LOCATION_NAME}"
echo "  - Web dashboard port: ${PORT}"

# Create logs directory if it doesn't exist
mkdir -p /app/internet_logs

# Function to handle shutdown
shutdown() {
    echo "🛑 Shutting down services..."

    # Kill Python monitor if running
    if [ ! -z "$PYTHON_PID" ] && kill -0 $PYTHON_PID 2>/dev/null; then
        echo "📵 Stopping Python monitor (PID: $PYTHON_PID)..."
        kill -TERM $PYTHON_PID
        wait $PYTHON_PID 2>/dev/null || true
    fi

    # Kill Node.js server if running
    if [ ! -z "$NODE_PID" ] && kill -0 $NODE_PID 2>/dev/null; then
        echo "🌐 Stopping Node.js server (PID: $NODE_PID)..."
        kill -TERM $NODE_PID
        wait $NODE_PID 2>/dev/null || true
    fi

    echo "✅ Shutdown complete"
    exit 0
}

# Set up signal handlers
trap shutdown SIGTERM SIGINT

# Test speedtest CLI availability
echo "🚀 Testing speedtest CLI..."
if speedtest --version > /dev/null 2>&1; then
    echo "✅ Speedtest CLI is available"
else
    echo "❌ Warning: Speedtest CLI not available"
fi

# Start Python monitoring script in background
echo "📡 Starting Python internet monitor..."
python3 internet_monitor.py \
    --ping-interval "${PING_INTERVAL}" \
    --speedtest-interval "${SPEEDTEST_INTERVAL}" \
    --upload-interval "${UPLOAD_INTERVAL}" \
    --log-dir "/app/internet_logs" &

PYTHON_PID=$!
echo "📡 Python monitor started (PID: $PYTHON_PID)"

# Give Python script time to initialize
sleep 3

# Start Node.js web dashboard in background
echo "🌐 Starting Node.js web dashboard..."
npm start &

NODE_PID=$!
echo "🌐 Node.js server started (PID: $NODE_PID)"

# Wait for Node.js server to be ready
echo "⏳ Waiting for web dashboard to be ready..."
for i in {1..30}; do
    if curl -f http://localhost:${PORT}/health > /dev/null 2>&1; then
        echo "✅ Web dashboard is ready at http://localhost:${PORT}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Web dashboard failed to start"
        shutdown
        exit 1
    fi
    sleep 1
done

echo "🚀 Internet Monitor is fully operational!"
echo "📊 Web Dashboard: http://localhost:${PORT}"
echo "📁 Logs directory: /app/internet_logs"

# Keep the container running and wait for signals
wait $NODE_PID
