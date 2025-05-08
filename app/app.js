const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');

// Load environment variables
dotenv.config();

// Create Express app
const app = express();

// Enable CORS for all routes
app.use(cors());

// Initialize server port
const PORT = process.env.PORT;

// Basic health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', message: 'Service is running' });
});

// Main Hello World endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Hello World from AWS EC2!',
    timestamp: new Date().toISOString(),
    serverInfo: {
      hostname: require('os').hostname(),
      platform: process.platform,
      nodeVersion: process.version
    }
  });
});

// Start the server
app.listen(PORT, () => {
  console.log(`Hello World API listening on port ${PORT}`);
});