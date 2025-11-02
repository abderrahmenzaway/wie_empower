const mongoose = require('mongoose');

const pumpSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true
  },
  status: {
    type: String,
    enum: ['Active', 'Inactive', 'Maintenance', 'Error'],
    default: 'Inactive'
  },
  flowRate: {
    type: Number,
    default: 0
  },
  pressure: {
    type: Number,
    default: 0
  },
  energyConsumption: {
    current: Number,
    today: Number,
    week: Number,
    month: Number
  },
  waterOutput: {
    current: Number,
    today: Number,
    week: Number,
    month: Number
  },
  operatingHours: {
    type: Number,
    default: 0
  },
  zoneId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Zone'
  },
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  lastMaintenance: Date,
  nextMaintenance: Date,
  createdAt: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('Pump', pumpSchema);
