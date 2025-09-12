# Multi-stage build for Internet Monitor with Python + Node.js
FROM ubuntu:22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    curl \
    gnupg2 \
    software-properties-common \
    ca-certificates \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 18.x
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs

# Install Ookla Speedtest CLI
RUN curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash \
    && apt-get install -y speedtest

# Install Python dependencies
RUN pip3 install --no-cache-dir \
    requests \
    schedule \
    configparser

# Copy package.json and package-lock.json
COPY package*.json ./

# Install Node.js dependencies
RUN npm ci --only=production

# Copy application files
COPY . .

# Create logs directory
RUN mkdir -p /app/internet_logs

# Make entrypoint script executable
RUN chmod +x entrypoint.sh

# Expose the web dashboard port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Set entrypoint
CMD ["./entrypoint.sh"]
