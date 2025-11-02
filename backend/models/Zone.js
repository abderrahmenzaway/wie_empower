const mongoose = require('mongoose');

const zoneSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true
  },
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  status: {
    type: String,
    enum: ['Active', 'Inactive'],
    default: 'Inactive'
  },
  moistureLevel: {
    type: Number,
    default: 0,
    min: 0,
    max: 100
  },
  moistureThreshold: {
    type: Number,
    default: 30,
    min: 0,
    max: 100
  },
  plantType: {
    type: String,
    trim: true,
  },
  wateringMode: {
    type: String,
    enum: ['Normal Mode', 'Eco Mode', 'Intensive Mode'],
    default: 'Normal Mode'
  },
  wateringStatus: {
    isRunning: {
      type: Boolean,
      default: false
    },
    currentDuration: Number,
    lastWatered: Date,
    manualOverride: {
      type: Boolean,
      default: false
    }
  },
  humidityHistory: [{
    timestamp: Date,
    value: Number
  }],
  wateringHistory: [{
    date: Date,
    duration: Number,
    amount: Number
  }],
  predictedSchedule: [{
    time: String,
    probability: Number
  }],
  connectedSensors: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Sensor'
  }],
  connectedPump: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Pump'
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('Zone', zoneSchema);
