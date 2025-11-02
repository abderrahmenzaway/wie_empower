const express = require('express');
const router = express.Router();
const axios = require('axios');
const auth = require('../middleware/auth');

// Get current weather
router.get('/current', auth, async (req, res) => {
  try {
    const { city = 'Tunis' } = req.query;
    const apiKey = process.env.OPENWEATHER_API_KEY;
    
    const response = await axios.get(
      `https://api.openweathermap.org/data/2.5/weather?q=${city}&appid=${apiKey}&units=metric`
    );

    res.json({ success: true, weather: response.data });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      message: 'Failed to fetch weather data',
      error: error.message 
    });
  }
});

// Get weather forecast
router.get('/forecast', auth, async (req, res) => {
  try {
    const { city = 'Tunis' } = req.query;
    const apiKey = process.env.OPENWEATHER_API_KEY;
    
    const response = await axios.get(
      `https://api.openweathermap.org/data/2.5/forecast?q=${city}&appid=${apiKey}&units=metric`
    );

    res.json({ success: true, forecast: response.data });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      message: 'Failed to fetch forecast data',
      error: error.message 
    });
  }
});

module.exports = router;
