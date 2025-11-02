const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const dotenv = require('dotenv');
const http = require('http');
const socketIo = require('socket.io');

// Load environment variables
dotenv.config();

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE']
  }
});

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Database connection
mongoose.connect(process.env.MONGODB_URI)
.then(() => console.log('✅ MongoDB connected successfully'))
.catch((err) => console.error('❌ MongoDB connection error:', err));

// Socket.IO connection
io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);
  
  socket.on('disconnect', () => {
    console.log('Client disconnected:', socket.id);
  });
});

// Make io accessible to routes
app.set('io', io);

// Import routes
const authRoutes = require('./routes/auth');
const zoneRoutes = require('./routes/zones');
const sensorRoutes = require('./routes/sensors');
const pumpRoutes = require('./routes/pumps');
const notificationRoutes = require('./routes/notifications');
const weatherRoutes = require('./routes/weather');
const dashboardRoutes = require('./routes/dashboard');
const settingsRoutes = require('./routes/settings');

// Use routes
app.use('/api/auth', authRoutes);
app.use('/api/zones', zoneRoutes);
app.use('/api/sensors', sensorRoutes);
app.use('/api/pumps', pumpRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/weather', weatherRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/settings', settingsRoutes);

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    success: true,
    message: '🌱 Welcome to HYDRAFARM API',
    version: '1.0.0',
    endpoints: {
      health: '/api/health',
      auth: '/api/auth',
      zones: '/api/zones',
      sensors: '/api/sensors',
      pumps: '/api/pumps',
      notifications: '/api/notifications',
      weather: '/api/weather',
      dashboard: '/api/dashboard',
      settings: '/api/settings'
    },
    documentation: 'See README.md for API documentation'
  });
});

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    message: 'HYDRAFARM API is running',
    timestamp: new Date().toISOString()
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ 
    success: false, 
    message: 'Something went wrong!',
    error: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ 
    success: false, 
    message: 'Route not found' 
  });
});

const PORT = process.env.PORT || 5000;

server.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📡 Environment: ${process.env.NODE_ENV}`);
});

module.exports = { app, io };
