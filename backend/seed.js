const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
require('dotenv').config();

// Import models
const User = require('./models/User');
const Zone = require('./models/Zone');
const Sensor = require('./models/Sensor');
const Pump = require('./models/Pump');

async function seedDatabase() {
  try {
    // Connect to MongoDB
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('✅ MongoDB connected');

    // Clear existing data
    await User.deleteMany({});
    await Zone.deleteMany({});
    await Sensor.deleteMany({});
    await Pump.deleteMany({});
    console.log('🗑️  Cleared existing data');

    // Create a test user
    const user = await User.create({
      name: 'Test User',
      email: 'test@hydrafarm.com',
      password: 'password123',
      farmInfo: {
        name: 'My Farm',
        location: 'Tunis, Tunisia',
      },
    });
    console.log('👤 Created test user:', user.email);

    // Create sensors
    const moistureSensor1 = await Sensor.create({
      userId: user._id,
      name: 'Moisture Sensor 1',
      type: 'Soil Moisture',
      status: 'Online',
      batteryLevel: 85,
      currentValue: 26,
      unit: '%',
      lastReading: new Date(),
    });

    const moistureSensor2 = await Sensor.create({
      userId: user._id,
      name: 'Moisture Sensor 2',
      type: 'Soil Moisture',
      status: 'Online',
      batteryLevel: 92,
      currentValue: 29,
      unit: '%',
      lastReading: new Date(),
    });

    const moistureSensor3 = await Sensor.create({
      userId: user._id,
      name: 'Moisture Sensor 3',
      type: 'Soil Moisture',
      status: 'Online',
      batteryLevel: 78,
      currentValue: 22,
      unit: '%',
      lastReading: new Date(),
    });

    console.log('📡 Created sensors');

    // Create pumps
    const pump1 = await Pump.create({
      userId: user._id,
      name: 'Main Pump 1',
      status: 'Active',
      flowRate: 50,
      pressure: 2.5,
      energyConsumption: {
        current: 120,
        today: 1200,
        week: 8400,
        month: 36000,
      },
      waterOutput: {
        current: 50,
        today: 500,
        week: 3500,
        month: 15000,
      },
      operatingHours: 240,
    });

    const pump2 = await Pump.create({
      userId: user._id,
      name: 'Main Pump 2',
      status: 'Inactive',
      flowRate: 45,
      pressure: 2.3,
      energyConsumption: {
        current: 0,
        today: 800,
        week: 5600,
        month: 24000,
      },
      waterOutput: {
        current: 0,
        today: 450,
        week: 3150,
        month: 13500,
      },
      operatingHours: 200,
    });

    const pump3 = await Pump.create({
      userId: user._id,
      name: 'Main Pump 3',
      status: 'Active',
      flowRate: 55,
      pressure: 2.7,
      energyConsumption: {
        current: 130,
        today: 1300,
        week: 9100,
        month: 39000,
      },
      waterOutput: {
        current: 55,
        today: 550,
        week: 3850,
        month: 16500,
      },
      operatingHours: 260,
    });

    console.log('💧 Created pumps');

    // Create zones
    const zone1 = await Zone.create({
      userId: user._id,
      name: 'بصل',
      plantType: 'Vegetables',
      moistureLevel: 26,
      moistureThreshold: 60,
      wateringStatus: {
        isRunning: true,
        lastWatered: new Date(Date.now() - 2 * 60 * 60 * 1000), // 2 hours ago
      },
      connectedSensors: [moistureSensor1._id],
      connectedPump: pump1._id,
      wateringHistory: [
        {
          date: new Date(Date.now() - 2 * 60 * 60 * 1000),
          duration: 30,
          amount: 100,
        },
      ],
    });

    const zone2 = await Zone.create({
      userId: user._id,
      name: 'طماطم',
      plantType: 'Fruit',
      moistureLevel: 29,
      moistureThreshold: 50,
      wateringStatus: {
        isRunning: false,
        lastWatered: new Date(Date.now() - 5 * 60 * 60 * 1000), // 5 hours ago
      },
      connectedSensors: [moistureSensor2._id],
      connectedPump: pump2._id,
      wateringHistory: [
        {
          date: new Date(Date.now() - 5 * 60 * 60 * 1000),
          duration: 30,
          amount: 120,
        },
      ],
    });

    const zone3 = await Zone.create({
      userId: user._id,
      name: 'نعناع',
      plantType: 'Vegetables',
      moistureLevel: 22,
      moistureThreshold: 70,
      wateringStatus: {
        isRunning: true,
        lastWatered: new Date(Date.now() - 1 * 60 * 60 * 1000), // 1 hour ago
      },
      connectedSensors: [moistureSensor3._id],
      connectedPump: pump3._id,
      wateringHistory: [
        {
          date: new Date(Date.now() - 1 * 60 * 60 * 1000),
          duration: 30,
          amount: 90,
        },
      ],
    });

    console.log('🌱 Created zones');

    console.log('\n✅ Database seeded successfully!');
    console.log('\n📋 Test credentials:');
    console.log('   Email: test@hydrafarm.com');
    console.log('   Password: password123');
    console.log('\n🌾 Created zones:');
    console.log('   - بصل (26% moisture, watering)');
    console.log('   - طماطم (29% moisture, idle)');
    console.log('   - نعناع (22% moisture, watering)');

    mongoose.connection.close();
    process.exit(0);
  } catch (error) {
    console.error('❌ Error seeding database:', error);
    process.exit(1);
  }
}

seedDatabase();
