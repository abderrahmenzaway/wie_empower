const mongoose = require('mongoose');

const sensorSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true
  },
  type: {
    type: String,
    enum: ['Soil Moisture', 'Temperature', 'Humidity', 'pH Level', 'Light'],
    required: true
  },
  status: {
    type: String,
    enum: ['Online', 'Offline', 'Error'],
    default: 'Offline'
  },
  batteryLevel: {
    type: Number,
    min: 0,
    max: 100,
    default: 100
  },
  currentValue: {
    type: Number,
    default: 0
  },
  unit: String,
  zoneId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Zone'
  },
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  readings: [{
    timestamp: Date,
    value: Number
  }],
  lastReading: Date,
  createdAt: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('Sensor', sensorSchema);
