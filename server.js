// server.js - Node.js server for Internet Connection Monitor
const express = require('express');
const fs = require('fs').promises;
const path = require('path');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static('public')); // Serve static files from public directory

// Utility functions
function parseCSV(csvText) {
    const lines = csvText.trim().split('\n');
    if (lines.length < 2) return [];

    const headers = lines[0].split(',').map(h => h.trim());
    const data = [];

    for (let i = 1; i < lines.length; i++) {
        const values = lines[i].split(',');
        const row = {};
        headers.forEach((header, index) => {
            row[header] = values[index] ? values[index].trim() : '';
        });
        data.push(row);
    }

    return data;
}

async function readCSVFile(filename) {
    try {
        const fullPath = path.join('internet_logs', filename);
        const csvText = await fs.readFile(fullPath, 'utf8');
        return parseCSV(csvText);
    } catch (error) {
        console.warn(`Could not read ${filename} from internet_logs:`, error.message);
        return [];
    }
}

async function readJSONFile(filename) {
    try {
        const fullPath = path.join('internet_logs', filename);
        const jsonText = await fs.readFile(fullPath, 'utf8');
        return JSON.parse(jsonText);
    } catch (error) {
        console.warn(`Could not read ${filename} from internet_logs:`, error.message);
        return {};
    }
}

function getRecentData(data, hours = 24) {
    const cutoff = Date.now() - (hours * 60 * 60 * 1000);
    return data.filter(row => {
        const timestamp = new Date(row.timestamp).getTime();
        return timestamp >= cutoff;
    });
}

function calculateUptime(connectivityData) {
    if (connectivityData.length === 0) return 100;

    const successful = connectivityData.filter(row => row.status === 'connected').length;
    return (successful / connectivityData.length) * 100;
}

function getDisconnectEvents(eventsData, hours = 24) {
    const cutoff = Date.now() - (hours * 60 * 60 * 1000);
    return eventsData.filter(row =>
        row.event_type === 'disconnect' &&
        new Date(row.timestamp).getTime() >= cutoff
    );
}

// API Routes
app.get('/api/status', async (req, res) => {
    try {
        // Load data files
        const [connectivity, speedtest, events, metadata] = await Promise.all([
            readCSVFile('connectivity.csv'),
            readCSVFile('speedtest.csv'),
            readCSVFile('events.csv'),
            readJSONFile('metadata.json')
        ]);

        // Get recent data
        const recentConnectivity = getRecentData(connectivity, 24);
        const recentSpeedtest = getRecentData(speedtest, 24);
        const recentEvents = getDisconnectEvents(events, 24);

        // Get most recent data timestamp from any CSV file
        const getLatestTimestamp = (datasets) => {
            let latest = null;
            for (const dataset of datasets) {
                if (dataset.length > 0) {
                    const timestamp = new Date(dataset[dataset.length - 1].timestamp);
                    if (!latest || timestamp > latest) {
                        latest = timestamp;
                    }
                }
            }
            return latest ? latest.toISOString() : new Date().toISOString();
        };

        // Format uptime as hours:minutes:seconds
        const formatUptime = (seconds) => {
            const hrs = Math.floor(seconds / 3600);
            const mins = Math.floor((seconds % 3600) / 60);
            const secs = Math.floor(seconds % 60);
            return `${hrs}:${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
        };

        // Calculate statistics
        const stats = {
            connection_status: 'unknown',
            uptime: formatUptime(process.uptime()), // Formatted server uptime
            uptime_raw: process.uptime(), // Raw seconds for calculations
            uptime_24h: calculateUptime(recentConnectivity), // Connection uptime percentage
            disconnects_24h: recentEvents.length,
            avg_download_speed: 0,
            avg_upload_speed: 0,
            min_download_speed: 0,
            max_download_speed: 0,
            last_update: getLatestTimestamp([connectivity, speedtest, events]), // Real data timestamp
            location: metadata.location || 'Unknown',
            total_tests_24h: recentConnectivity.length,
            successful_tests_24h: recentConnectivity.filter(r => r.status === 'connected').length
        };

        // Determine current connection status
        const recentTests = recentConnectivity.slice(-5); // Last 5 tests
        const hasRecentConnection = recentTests.some(test => test.status === 'connected');
        stats.connection_status = hasRecentConnection ? 'online' : 'offline';

        // Calculate average speeds
        const successfulSpeedtests = recentSpeedtest.filter(row => row.status === 'success');
        if (successfulSpeedtests.length > 0) {
            const downloadSpeeds = successfulSpeedtests.map(row => parseFloat(row.download_mbps));
            const uploadSpeeds = successfulSpeedtests.map(row => parseFloat(row.upload_mbps));

            stats.avg_download_speed = downloadSpeeds.reduce((a, b) => a + b, 0) / downloadSpeeds.length;
            stats.avg_upload_speed = uploadSpeeds.reduce((a, b) => a + b, 0) / uploadSpeeds.length;
            stats.min_download_speed = Math.min(...downloadSpeeds);
            stats.max_download_speed = Math.max(...downloadSpeeds);
        }

        res.json({
            status: 'success',
            stats,
            data_counts: {
                connectivity: connectivity.length,
                speedtest: speedtest.length,
                events: events.length
            }
        });

    } catch (error) {
        console.error('Error in /api/status:', error);
        res.status(500).json({
            status: 'error',
            message: error.message
        });
    }
});

app.get('/api/connectivity', async (req, res) => {
    try {
        const hours = parseInt(req.query.hours) || 24;
        const limit = parseInt(req.query.limit) || 1000;

        const connectivity = await readCSVFile('connectivity.csv');
        const recentData = getRecentData(connectivity, hours)
            .slice(-limit)
            .map(row => ({
                timestamp: row.timestamp,
                status: row.status,
                target: row.target,
                response_time_ms: parseFloat(row.response_time_ms) || null,
                method: row.method
            }));

        res.json({
            status: 'success',
            data: recentData,
            total_records: recentData.length
        });

    } catch (error) {
        console.error('Error in /api/connectivity:', error);
        res.status(500).json({
            status: 'error',
            message: error.message
        });
    }
});

app.get('/api/speedtest', async (req, res) => {
    try {
        const hours = parseInt(req.query.hours) || 24;
        const limit = parseInt(req.query.limit) || 100;

        const speedtest = await readCSVFile('speedtest.csv');
        const recentData = getRecentData(speedtest, hours)
            .slice(-limit)
            .filter(row => row.status === 'success')
            .map(row => ({
                timestamp: row.timestamp,
                download_mbps: parseFloat(row.download_mbps),
                upload_mbps: parseFloat(row.upload_mbps),
                ping_ms: parseFloat(row.ping_ms),
                server: row.server
            }));

        res.json({
            status: 'success',
            data: recentData,
            total_records: recentData.length
        });

    } catch (error) {
        console.error('Error in /api/speedtest:', error);
        res.status(500).json({
            status: 'error',
            message: error.message
        });
    }
});

app.get('/api/events', async (req, res) => {
    try {
        const hours = parseInt(req.query.hours) || 24;
        const limit = parseInt(req.query.limit) || 50;

        const events = await readCSVFile('events.csv');
        const recentEvents = getRecentData(events, hours)
            .filter(row => row.event_type === 'disconnect')
            .slice(-limit)
            .map(row => ({
                timestamp: row.timestamp,
                event_type: row.event_type,
                duration_seconds: parseFloat(row.duration_seconds),
                details: row.details
            }))
            .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

        res.json({
            status: 'success',
            data: recentEvents,
            total_records: recentEvents.length
        });

    } catch (error) {
        console.error('Error in /api/events:', error);
        res.status(500).json({
            status: 'error',
            message: error.message
        });
    }
});

// Aggregated hourly data for charts
app.get('/api/hourly-stats', async (req, res) => {
    try {
        const hours = parseInt(req.query.hours) || 24;

        const connectivity = await readCSVFile('connectivity.csv');
        const recentData = getRecentData(connectivity, hours);

        // Group by hour
        const hourlyStats = {};
        const now = new Date();

        // Initialize all hours
        for (let i = hours - 1; i >= 0; i--) {
            const hourStart = new Date(now.getTime() - i * 60 * 60 * 1000);
            const hourKey = hourStart.toISOString().substring(0, 13) + ':00:00.000Z';
            hourlyStats[hourKey] = {
                timestamp: hourKey,
                hour: hourStart.getHours(),
                total_tests: 0,
                successful_tests: 0,
                success_rate: 100
            };
        }

        // Populate with actual data
        recentData.forEach(row => {
            const timestamp = new Date(row.timestamp);
            const hourKey = new Date(timestamp.getFullYear(), timestamp.getMonth(),
                timestamp.getDate(), timestamp.getHours()).toISOString();

            if (hourlyStats[hourKey]) {
                hourlyStats[hourKey].total_tests++;
                if (row.status === 'connected') {
                    hourlyStats[hourKey].successful_tests++;
                }
            }
        });

        // Calculate success rates
        Object.values(hourlyStats).forEach(hour => {
            if (hour.total_tests > 0) {
                hour.success_rate = (hour.successful_tests / hour.total_tests) * 100;
            }
        });

        res.json({
            status: 'success',
            data: Object.values(hourlyStats).sort((a, b) =>
                new Date(a.timestamp) - new Date(b.timestamp)
            )
        });

    } catch (error) {
        console.error('Error in /api/hourly-stats:', error);
        res.status(500).json({
            status: 'error',
            message: error.message
        });
    }
});

// Health check endpoints
app.get('/health', (req, res) => {
    res.status(200).send('OK');
});

app.get('/api/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        version: require('./package.json').version
    });
});

// Serve the main dashboard
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error('Unhandled error:', err);
    res.status(500).json({
        status: 'error',
        message: 'Internal server error'
    });
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({
        status: 'error',
        message: 'Endpoint not found'
    });
});

// Start server
app.listen(PORT, () => {
    console.log(`🚀 Internet Monitor Server running on port ${PORT}`);
    console.log(`📊 Dashboard: http://localhost:${PORT}`);
    console.log(`🔌 API: http://localhost:${PORT}/api/status`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('🛑 Shutting down gracefully...');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('🛑 Shutting down gracefully...');
    process.exit(0);
});
