#!/bin/bash
set -e

# Heimdall Monitor Dashboard Entrypoint
# Runs ONLY the Node.js web dashboard - monitoring is done locally

echo "🌐 Starting Heimdall Monitor Dashboard Server..."

export NODE_ENV="${NODE_ENV:-production}"
export PORT="${PORT:-3000}"

echo "📊 Configuration:"
echo "  - Web dashboard port: ${PORT}"
echo "  - Environment: ${NODE_ENV}"

# Create logs directory if it doesn't exist
mkdir -p /app/internet_logs

# Function to handle shutdown
shutdown() {
    echo "🛑 Shutting down server..."

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

# Start Node.js web dashboard
echo "🌐 Starting Node.js web dashboard..."
pnpm start &

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
        exit 1
    fi
    sleep 1
done

echo "🚀 Heimdall Monitor Dashboard is running!"
echo "📊 Dashboard: http://localhost:${PORT}"
echo "📁 Logs directory: /app/internet_logs"

# Keep the container running and wait for signals
wait $NODE_PID
