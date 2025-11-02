const express = require('express');
const router = express.Router();
const Sensor = require('../models/Sensor');
const auth = require('../middleware/auth');

// Get all sensors for user
router.get('/', auth, async (req, res) => {
  try {
    const sensors = await Sensor.find({ userId: req.userId }).populate('zoneId');
    res.json({ success: true, sensors });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
});

// Get sensor by ID
router.get('/:id', auth, async (req, res) => {
  try {
    const sensor = await Sensor.findOne({ _id: req.params.id, userId: req.userId }).populate('zoneId');
    
    if (!sensor) {
      return res.status(404).json({ success: false, message: 'Sensor not found' });
    }

    res.json({ success: true, sensor });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
});

// Create new sensor
router.post('/', auth, async (req, res) => {
  try {
    const sensor = new Sensor({
      ...req.body,
      userId: req.userId
    });
    await sensor.save();

    req.app.get('io').emit('sensor_created', sensor);

    res.status(201).json({ success: true, sensor });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
});

// Update sensor reading
router.post('/:id/reading', auth, async (req, res) => {
  try {
    const sensor = await Sensor.findOne({ _id: req.params.id, userId: req.userId });
    
    if (!sensor) {
      return res.status(404).json({ success: false, message: 'Sensor not found' });
    }

    sensor.currentValue = req.body.value;
    sensor.lastReading = new Date();
    sensor.readings.push({
      timestamp: new Date(),
      value: req.body.value
    });

    // Keep only last 100 readings
    if (sensor.readings.length > 100) {
      sensor.readings = sensor.readings.slice(-100);
    }

    await sensor.save();

    req.app.get('io').emit('sensor_reading', { sensorId: sensor._id, value: req.body.value });

    res.json({ success: true, sensor });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
});

// Delete sensor
router.delete('/:id', auth, async (req, res) => {
  try {
    const sensor = await Sensor.findOneAndDelete({ _id: req.params.id, userId: req.userId });
    
    if (!sensor) {
      return res.status(404).json({ success: false, message: 'Sensor not found' });
    }

    req.app.get('io').emit('sensor_deleted', { id: req.params.id });

    res.json({ success: true, message: 'Sensor deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
});

module.exports = router;
