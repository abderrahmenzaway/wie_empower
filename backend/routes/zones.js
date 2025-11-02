const express = require('express');
const router = express.Router();
const Zone = require('../models/Zone');
const auth = require('../middleware/auth');

// Get all zones for user
router.get('/', auth, async (req, res) => {
  try {
    const zones = await Zone.find({ userId: req.userId })
      .populate('connectedSensors')
      .populate('connectedPump');
    res.json({ success: true, zones });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
});

// Get zone by ID
router.get('/:id', auth, async (req, res) => {
  try {
    const zone = await Zone.findOne({ _id: req.params.id, userId: req.userId })
      .populate('connectedSensors')
      .populate('connectedPump');
    
    if (!zone) {
      return res.status(404).json({ success: false, message: 'Zone not found' });
    }

    res.json({ success: true, zone });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
});

// Create new zone
router.post('/', auth, async (req, res) => {
  try {
    const zone = new Zone({
      ...req.body,
      userId: req.userId
    });
    await zone.save();

    // Emit socket event
    req.app.get('io').emit('zone_created', zone);

    res.status(201).json({ success: true, zone });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
});

// Update zone
router.put('/:id', auth, async (req, res) => {
  try {
    const zone = await Zone.findOneAndUpdate(
      { _id: req.params.id, userId: req.userId },
      req.body,
      { new: true }
    );

    if (!zone) {
      return res.status(404).json({ success: false, message: 'Zone not found' });
    }

    // Emit socket event
    req.app.get('io').emit('zone_updated', zone);

    res.json({ success: true, zone });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
});

// Toggle zone watering
router.post('/:id/toggle', auth, async (req, res) => {
  try {
    const zone = await Zone.findOne({ _id: req.params.id, userId: req.userId });
    
    if (!zone) {
      return res.status(404).json({ success: false, message: 'Zone not found' });
    }

    zone.wateringStatus.isRunning = !zone.wateringStatus.isRunning;
    if (zone.wateringStatus.isRunning) {
      zone.wateringStatus.lastWatered = new Date();
    }
    zone.status = zone.wateringStatus.isRunning ? 'Active' : 'Inactive';
    
    await zone.save();

    // Emit socket event
    req.app.get('io').emit('zone_toggle', zone);

    res.json({ success: true, zone });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
});

// Delete zone
router.delete('/:id', auth, async (req, res) => {
  try {
    const zone = await Zone.findOneAndDelete({ _id: req.params.id, userId: req.userId });
    
    if (!zone) {
      return res.status(404).json({ success: false, message: 'Zone not found' });
    }

    // Emit socket event
    req.app.get('io').emit('zone_deleted', { id: req.params.id });

    res.json({ success: true, message: 'Zone deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
});

module.exports = router;
