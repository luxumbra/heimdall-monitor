# Multi-stage build for Internet Monitor with Python + Node.js
FROM node:22-bookworm-slim

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Enable corepack for pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    curl \
    ca-certificates \
    iputils-ping \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Install Speedtest CLI if available (optional)
RUN curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash 2>/dev/null || true
RUN apt-get install -y speedtest 2>/dev/null || true

# Install Python dependencies
RUN pip3 install --no-cache-dir \
    requests \
    schedule \
    configparser

# Copy package files
COPY package.json pnpm-lock.yaml ./

# Install Node.js dependencies
RUN pnpm install --frozen-lockfile --prod

# Copy application files
COPY . .

# Make entrypoint script executable
RUN chmod +x entrypoint.sh

# Create logs directory
RUN mkdir -p /app/internet_logs

# Expose the web dashboard port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Set entrypoint
ENTRYPOINT ["./entrypoint.sh"]
