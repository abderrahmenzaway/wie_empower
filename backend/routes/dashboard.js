const express = require('express');
const router = express.Router();
const Zone = require('../models/Zone');
const Sensor = require('../models/Sensor');
const Pump = require('../models/Pump');
const auth = require('../middleware/auth');

// Get dashboard statistics
router.get('/stats', auth, async (req, res) => {
  try {
    const zones = await Zone.find({ userId: req.userId });
    const sensors = await Sensor.find({ userId: req.userId });
    const pumps = await Pump.find({ userId: req.userId });

    const activeZones = zones.filter(z => z.status === 'Active').length;
    const onlineSensors = sensors.filter(s => s.status === 'Online').length;
    const activePumps = pumps.filter(p => p.status === 'Active').length;

    // Calculate total energy consumption
    const totalEnergyToday = pumps.reduce((sum, p) => sum + (p.energyConsumption?.today || 0), 0);
    const totalEnergyWeek = pumps.reduce((sum, p) => sum + (p.energyConsumption?.week || 0), 0);

    // Calculate total water consumption
    const totalWaterToday = pumps.reduce((sum, p) => sum + (p.waterOutput?.today || 0), 0);
    const totalWaterWeek = pumps.reduce((sum, p) => sum + (p.waterOutput?.week || 0), 0);

    res.json({
      success: true,
      stats: {
        zones: {
          total: zones.length,
          active: activeZones,
          inactive: zones.length - activeZones
        },
        sensors: {
          total: sensors.length,
          online: onlineSensors,
          offline: sensors.length - onlineSensors
        },
        pumps: {
          total: pumps.length,
          active: activePumps
        },
        energy: {
          today: totalEnergyToday,
          week: totalEnergyWeek
        },
        water: {
          today: totalWaterToday,
          week: totalWaterWeek
        }
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
});

// Get energy consumption data
router.get('/energy', auth, async (req, res) => {
  try {
    const pumps = await Pump.find({ userId: req.userId });
    
    // Mock hourly data for chart
    const hourlyData = Array.from({ length: 24 }, (_, i) => ({
      hour: i,
      consumption: Math.random() * 5 + 1
    }));

    res.json({
      success: true,
      data: {
        current: pumps.reduce((sum, p) => sum + (p.energyConsumption?.current || 0), 0),
        today: pumps.reduce((sum, p) => sum + (p.energyConsumption?.today || 0), 0),
        hourly: hourlyData
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
});

// Get water consumption data
router.get('/water', auth, async (req, res) => {
  try {
    const pumps = await Pump.find({ userId: req.userId });
    
    // Mock hourly data for chart
    const hourlyData = Array.from({ length: 24 }, (_, i) => ({
      hour: i,
      consumption: Math.random() * 30 + 10
    }));

    res.json({
      success: true,
      data: {
        current: pumps.reduce((sum, p) => sum + (p.waterOutput?.current || 0), 0),
        today: pumps.reduce((sum, p) => sum + (p.waterOutput?.today || 0), 0),
        hourly: hourlyData
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
});

module.exports = router;
