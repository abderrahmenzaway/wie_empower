const express = require('express');
const router = express.Router();
const Pump = require('../models/Pump');
const auth = require('../middleware/auth');

// Get all pumps for user
router.get('/', auth, async (req, res) => {
  try {
    const pumps = await Pump.find({ userId: req.userId }).populate('zoneId');
    res.json({ success: true, pumps });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
});

// Get pump by ID
router.get('/:id', auth, async (req, res) => {
  try {
    const pump = await Pump.findOne({ _id: req.params.id, userId: req.userId }).populate('zoneId');
    
    if (!pump) {
      return res.status(404).json({ success: false, message: 'Pump not found' });
    }

    res.json({ success: true, pump });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
});

// Create new pump
router.post('/', auth, async (req, res) => {
  try {
    const pump = new Pump({
      ...req.body,
      userId: req.userId
    });
    await pump.save();

    req.app.get('io').emit('pump_created', pump);

    res.status(201).json({ success: true, pump });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
});

// Update pump
router.put('/:id', auth, async (req, res) => {
  try {
    const pump = await Pump.findOneAndUpdate(
      { _id: req.params.id, userId: req.userId },
      req.body,
      { new: true }
    );

    if (!pump) {
      return res.status(404).json({ success: false, message: 'Pump not found' });
    }

    req.app.get('io').emit('pump_updated', pump);

    res.json({ success: true, pump });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
});

// Delete pump
router.delete('/:id', auth, async (req, res) => {
  try {
    const pump = await Pump.findOneAndDelete({ _id: req.params.id, userId: req.userId });
    
    if (!pump) {
      return res.status(404).json({ success: false, message: 'Pump not found' });
    }

    req.app.get('io').emit('pump_deleted', { id: req.params.id });

    res.json({ success: true, message: 'Pump deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
});

module.exports = router;
