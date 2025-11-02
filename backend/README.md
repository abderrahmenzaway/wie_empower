# HYDRAFARM Backend API

Complete backend API for the HYDRAFARM Smart Farm Irrigation Management System.

## Features

- **Authentication & Authorization** (JWT)
- **User Management**
- **Zone Management** (Irrigation zones)
- **Sensor Management** (Soil moisture, temperature, etc.)
- **Pump Control**
- **Notifications System**
- **Weather Integration** (OpenWeatherMap API)
- **Real-time Updates** (Socket.IO)
- **Dashboard Statistics**

## Installation

1. Install dependencies:
```bash
npm install
```

2. Create a `.env` file with your configuration:
```
PORT=5000
MONGODB_URI=mongodb://localhost:27017/hydrafarm
JWT_SECRET=your_secret_key
OPENWEATHER_API_KEY=your_api_key
NODE_ENV=development
```

3. Make sure MongoDB is running

4. Start the server:
```bash
# Development mode with auto-reload
npm run dev

# Production mode
npm start
```

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login user
- `GET /api/auth/profile` - Get user profile

### Zones
- `GET /api/zones` - Get all zones
- `GET /api/zones/:id` - Get zone by ID
- `POST /api/zones` - Create new zone
- `PUT /api/zones/:id` - Update zone
- `POST /api/zones/:id/toggle` - Toggle watering
- `DELETE /api/zones/:id` - Delete zone

### Sensors
- `GET /api/sensors` - Get all sensors
- `GET /api/sensors/:id` - Get sensor by ID
- `POST /api/sensors` - Create new sensor
- `POST /api/sensors/:id/reading` - Add sensor reading
- `DELETE /api/sensors/:id` - Delete sensor

### Pumps
- `GET /api/pumps` - Get all pumps
- `GET /api/pumps/:id` - Get pump by ID
- `POST /api/pumps` - Create new pump
- `PUT /api/pumps/:id` - Update pump
- `DELETE /api/pumps/:id` - Delete pump

### Notifications
- `GET /api/notifications` - Get all notifications
- `POST /api/notifications` - Create notification
- `PUT /api/notifications/:id/read` - Mark as read
- `PUT /api/notifications/read-all` - Mark all as read
- `DELETE /api/notifications/:id` - Delete notification
- `DELETE /api/notifications` - Clear all notifications

### Weather
- `GET /api/weather/current?city=Tunis` - Get current weather
- `GET /api/weather/forecast?city=Tunis` - Get weather forecast

### Dashboard
- `GET /api/dashboard/stats` - Get dashboard statistics
- `GET /api/dashboard/energy` - Get energy consumption data
- `GET /api/dashboard/water` - Get water consumption data

### Settings
- `GET /api/settings` - Get user settings
- `PUT /api/settings` - Update user settings
- `PUT /api/settings/farm` - Update farm information

## Socket.IO Events

### Emitted Events
- `zone_created` - New zone created
- `zone_updated` - Zone updated
- `zone_deleted` - Zone deleted
- `zone_toggle` - Zone watering toggled
- `sensor_created` - New sensor created
- `sensor_reading` - New sensor reading
- `sensor_deleted` - Sensor deleted
- `pump_created` - New pump created
- `pump_updated` - Pump updated
- `pump_deleted` - Pump deleted
- `new_notification` - New notification

## Database Models

### User
- Authentication credentials
- Account type (Administrator/User/Viewer)
- Preferences (dark mode, units, language)
- Farm information

### Zone
- Zone name and status
- Moisture level and threshold
- Watering mode and status
- Humidity and watering history
- Predicted schedule
- Connected sensors and pump

### Sensor
- Sensor type and status
- Battery level
- Current value and readings
- Zone association

### Pump
- Pump status
- Flow rate and pressure
- Energy consumption
- Water output
- Maintenance schedule

### Notification
- Type (System/Maintenance/Operational/Weather)
- Title and message
- Severity level
- Read status

## Testing

You can test the API using tools like:
- Postman
- cURL
- Thunder Client (VS Code extension)

Example login request:
```bash
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password123"}'
```

## License

MIT
