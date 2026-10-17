import requests
from datetime import datetime
import pytz
import pandas as pd
import pickle
import os
try:
    import joblib
except ImportError:
    joblib = None

class TunisiaIrrigationSystem:
    """
    Smart irrigation system for Tunisia
    Tailored for your specific model's input requirements
    """
    
    def __init__(self, governorate="ZAGHOUAN", crop_type="TOMATO"):
        """
        Initialize for your Tunisian farm
        
        Args:
            governorate: Your governorate
            crop_type: What you're growing (manual input)
        """
        self.governorate = governorate.upper()
        self.crop_type = crop_type.upper()
        
        # Tunisia locations with MODEL-SPECIFIC regions
        self.locations = {
            "TUNIS": {
                "lat": 36.8065, 
                "lon": 10.1815, 
                "region": "SEMI HUMID",  # Coastal, moderate humidity
                "altitude": 10
            },
            "ZAGHOUAN": {
                "lat": 36.4028,
                "lon": 10.1433,
                "region": "SEMI ARID",   # Inland, less humid
                "altitude": 200,
                "notes": "زغوان - wheat, olives, citrus"
            },
            "SOUSSE": {
                "lat": 35.8256,
                "lon": 10.6411,
                "region": "SEMI HUMID",  # Coastal
                "altitude": 5
            },
            "SFAX": {
                "lat": 34.7406,
                "lon": 10.7603,
                "region": "SEMI ARID",   # Drier coast
                "altitude": 5
            },
            "KAIROUAN": {
                "lat": 35.6781,
                "lon": 10.0963,
                "region": "SEMI ARID",   # Inland
                "altitude": 120
            },
            "BIZERTE": {
                "lat": 37.2746,
                "lon": 9.8739,
                "region": "HUMID",       # Northern coast, wettest
                "altitude": 5
            },
            "NABEUL": {
                "lat": 36.4561,
                "lon": 10.7376,
                "region": "SEMI HUMID",  # Coastal
                "altitude": 10
            },
            "GABES": {
                "lat": 33.8815,
                "lon": 10.0982,
                "region": "DESERT",      # Southern, very dry
                "altitude": 5
            },
            "TOZEUR": {
                "lat": 33.9197,
                "lon": 8.1338,
                "region": "DESERT",      # Sahara
                "altitude": 90
            },
        }
        
        self.location = self.locations.get(
            self.governorate, 
            self.locations["ZAGHOUAN"]  # Default to your location
        )
        
        # Tunisia timezone
        self.tz = pytz.timezone('Africa/Tunis')
        
        # Watering tracking
        self.last_watering = None
        self.daily_water_total = 0
        self.last_reset_day = datetime.now(self.tz).day
        
        # Soil moisture thresholds (for decisions, not model input)
        self.MOISTURE_CRITICAL = 15
        self.MOISTURE_DRY_THRESHOLD = 30
        self.MOISTURE_ADEQUATE = 45
        self.MOISTURE_WET_THRESHOLD = 65
        
        # Seasonal daily water limits (liters)
        self.season_limits = {
            "SUMMER": 20,
            "AUTUMN": 12,
            "WINTER": 6,
            "SPRING": 15
        }
    
    # ========================================================================
    # TEMPERATURE CONVERSION (From Arduino sensor)
    # ========================================================================
    
    def classify_temperature(self, temp_celsius):
        """
        Convert Arduino temperature to MODEL format
        
        Args:
            temp_celsius: Temperature from Arduino (float)
        
        Returns:
            str: One of "10-20", "20-30", "30-40", "40-50"
        
        Model accepts ONLY: 10-20, 20-30, 30-40, 40-50
        """
        if temp_celsius < 10:
            return "10-20"  # Clamp to minimum model range
        elif temp_celsius < 20:
            return "10-20"
        elif temp_celsius < 30:
            return "20-30"
        elif temp_celsius < 40:
            return "30-40"
        elif temp_celsius < 50:
            return "40-50"
        else:
            return "40-50"  # Clamp to maximum model range
    
    # ========================================================================
    # WEATHER CONDITION (From API)
    # ========================================================================
    
    def get_tunisia_weather(self):
        """
        Get weather from Open-Meteo API for Tunisia
        """
        url = "https://api.open-meteo.com/v1/forecast"
        params = {
            "latitude": self.location["lat"],
            "longitude": self.location["lon"],
            "current": [
                "temperature_2m",
                "relative_humidity_2m",
                "precipitation",
                "weather_code",
                "wind_speed_10m"
            ],
            "hourly": "precipitation",
            "forecast_days": 1,
            "timezone": "Africa/Tunis"
        }
        
        try:
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            data = response.json()
            
            current = data['current']
            next_6h_rain = sum(data['hourly']['precipitation'][:6])
            
            return {
                "temperature_api": current['temperature_2m'],  # Backup if Arduino fails
                "humidity": current['relative_humidity_2m'],
                "precipitation": current['precipitation'],
                "precipitation_6h": next_6h_rain,
                "weather_code": current['weather_code'],
                "wind_speed": current['wind_speed_10m']
            }
        except Exception as e:
            print(f"⚠️ Weather API Error: {e}")
            return None
    
    def classify_weather_condition(self, weather_data):
        """
        Convert weather API data to MODEL format
        
        Model accepts ONLY: NORMAL, SUNNY, WINDY, RAINY
        
        Args:
            weather_data: Dict from get_tunisia_weather()
        
        Returns:
            str: One of "NORMAL", "SUNNY", "WINDY", "RAINY"
        """
        if not weather_data:
            return "NORMAL"  # Default fallback
        
        precipitation = weather_data['precipitation']
        weather_code = weather_data['weather_code']
        wind_speed = weather_data['wind_speed']
        
        # Priority 1: RAINY (any precipitation)
        if precipitation > 0.5:  # More than 0.5mm = rainy
            return "RAINY"
        
        # Priority 2: WINDY (strong wind)
        if wind_speed > 7:  # More than 7 m/s = windy
            return "WINDY"
        
        # Priority 3: SUNNY (clear sky)
        # Weather code 0 = clear sky
        if weather_code == 0:
            return "SUNNY"
        
        # Priority 4: NORMAL (everything else)
        # Includes: partly cloudy, overcast, fog, etc.
        return "NORMAL"
    
    # ========================================================================
    # SOIL TYPE - MULTIPLE APPROACHES
    # ========================================================================
    
   
    
    def classify_soil_type_method2_sensor(self, soil_moisture_percent):
        """
        METHOD 2: DYNAMIC - Based on current moisture reading
        
        Model accepts: DRY, HUMID, WET
        
        ⚠️ PROBLEM: This changes constantly!
        Your model might expect SOIL TYPE to be a static property
        (sandy vs clay), not current moisture state.
        
        Args:
            soil_moisture_percent: Current reading (0-100%)
        
        Returns:
            str: One of "DRY", "HUMID", "WET"
        """
        if soil_moisture_percent < 30:
            return "DRY"
        elif soil_moisture_percent < 65:
            return "HUMID"  # Normal/medium moisture
        else:
            return "WET"
    
    def classify_soil_type_method3_historical(self, soil_moisture_history):
        """
        METHOD 3: BEHAVIORAL - Based on soil drying pattern
        
        Test once: Water soil to 70%, wait 24h, measure again
        
        Fast drying (< 30% after 24h) = Sandy = "DRY"
        Medium drying (30-50% after 24h) = Loamy = "HUMID"
        Slow drying (> 50% after 24h) = Clay = "WET"
        
        Args:
            soil_moisture_history: List of readings over 24h
        
        Returns:
            str: One of "DRY", "HUMID", "WET"
        """
        if len(soil_moisture_history) < 2:
            return "HUMID"  # Default
        
        initial = soil_moisture_history[0]
        after_24h = soil_moisture_history[-1]
        
        moisture_drop = initial - after_24h
        
        # Fast drainage
        if moisture_drop > 40:
            return "DRY"  # Sandy soil
        # Slow drainage
        elif moisture_drop < 20:
            return "WET"  # Clay soil
        # Medium drainage
        else:
            return "HUMID"  # Loamy soil
    
    def classify_soil_type_method4_lookup(self):
        """
        METHOD 4: GEOGRAPHIC LOOKUP
        
        Based on known soil types in Tunisia regions
        
        Returns:
            str: One of "DRY", "HUMID", "WET"
        """
        soil_map = {
            "ZAGHOUAN": "HUMID",    # Loamy agricultural soil
            "TUNIS": "HUMID",       # Mixed
            "BIZERTE": "WET",       # Clay-rich northern soils
            "KAIROUAN": "DRY",      # Sandy inland
            "GABES": "DRY",         # Sandy desert
            "TOZEUR": "DRY",        # Sandy desert
            "SFAX": "DRY",          # Sandy coastal
            "SOUSSE": "HUMID",      # Mixed coastal
            "NABEUL": "HUMID",      # Agricultural
        }
        
        return soil_map.get(self.governorate, "HUMID")
    
    # ========================================================================
    # RECOMMENDED: HYBRID APPROACH
    # ========================================================================
    
    def classify_soil_type_recommended(self, soil_moisture_percent):
        """
        RECOMMENDED: Hybrid approach
        
        Use STATIC soil type (geographic/physical test)
        BUT override to WET if sensor shows saturation
        
        This makes sense because:
        - Soil physical type doesn't change (sandy/loamy/clay)
        - But after heavy rain, even sandy soil becomes WET temporarily
        
        Args:
            soil_moisture_percent: Current sensor reading
        
        Returns:
            str: One of "DRY", "HUMID", "WET"
        """
        # Base soil type for your region (static)
        base_soil_type = self.classify_soil_type_method4_lookup()
        
        # Override if sensor shows saturation
        if soil_moisture_percent > 70:
            return "WET"  # Saturated regardless of soil type
        
        # Override if sensor shows extreme dryness
        elif soil_moisture_percent < 20:
            return "DRY"  # Very dry regardless of base type
        
        # Otherwise use base type
        else:
            return base_soil_type
    
    # ========================================================================
    # MAIN MODEL INPUT GENERATION
    # ========================================================================
    
    def generate_model_input(self, temp_from_arduino, soil_moisture_sensor):
        """
        Generate complete model input from your sensor data
        
        Args:
            temp_from_arduino: Temperature from Arduino sensor (°C)
            soil_moisture_sensor: Soil moisture from sensor (%)
        
        Returns:
            dict: Ready for your model
        """
        # Get weather data
        weather = self.get_tunisia_weather()
        
        # Generate each input in MODEL format
        model_input = {
            "CROP_TYPE": self.crop_type,  # Manual input (you set)
            
            "SOIL_TYPE": self.classify_soil_type_method2_sensor(
                soil_moisture_sensor
            ),  # One of: DRY, HUMID, WET
            
            "REGION": self.location["region"],  # One of: DESERT, SEMI ARID, SEMI HUMID, HUMID
            
            "TEMPERATURE": self.classify_temperature(
                temp_from_arduino
            ),  # One of: 10-20, 20-30, 30-40, 40-50
            
            "WEATHER_CONDITION": self.classify_weather_condition(
                weather
            )  # One of: NORMAL, SUNNY, WINDY, RAINY
        }
        
        # Extra data for decision-making (not for model)
        context = {
            "exact_temp": temp_from_arduino,
            "exact_moisture": soil_moisture_sensor,
            "humidity": weather['humidity'] if weather else 60,
            "rain_forecast_6h": weather['precipitation_6h'] if weather else 0,
            "wind_speed": weather['wind_speed'] if weather else 0,
            "season": self.get_current_season(),
            "timestamp": datetime.now(self.tz)
        }
        
        return model_input, context
    
    def format_for_model(self, model_input):
        """
        Format as CSV string for your model
        
        Args:
            model_input: Dict from generate_model_input()
        
        Returns:
            str: "CROP_TYPE,SOIL_TYPE,REGION,TEMPERATURE,WEATHER_CONDITION"
        
        Example: "TOMATO,HUMID,SEMI ARID,20-30,SUNNY"
        """
        return (
            f"{model_input['CROP_TYPE']},"
            f"{model_input['SOIL_TYPE']},"
            f"{model_input['REGION']},"
            f"{model_input['TEMPERATURE']},"
            f"{model_input['WEATHER_CONDITION']}"
        )
    
    # ========================================================================
    # HELPER FUNCTIONS
    # ========================================================================
    
    def get_current_season(self):
        """Get current season in Tunisia"""
        month = datetime.now(self.tz).month
        
        if month in [6, 7, 8, 9]:
            return "SUMMER"
        elif month in [10, 11]:
            return "AUTUMN"
        elif month in [12, 1, 2]:
            return "WINTER"
        else:
            return "SPRING"
    
    # ========================================================================
    # WATERING DECISION LOGIC
    # ========================================================================
    
    def decide_watering(self, model_water_requirement, soil_moisture, context):
        """
        Decide if/how much to water based on model + sensor + context
        
        Args:
            model_water_requirement: Liters predicted by model
            soil_moisture: Current sensor reading (%)
            context: Extra data from generate_model_input()
        
        Returns:
            (bool, float, str): (should_water, amount, reason)
        """
        tunisia_time = context['timestamp']
        current_hour = tunisia_time.hour
        season = context['season']
        rain_forecast = context['rain_forecast_6h']
        
        # Reset daily counter at midnight
        if tunisia_time.day != self.last_reset_day:
            self.daily_water_total = 0
            self.last_reset_day = tunisia_time.day
        
        # Rule 1: Daily limit reached
        season_max = self.season_limits[season]
        if self.daily_water_total >= season_max:
            return False, 0, f"❌ Daily limit reached ({season_max}L)"
        
        # Rule 2: Rain expected
        if rain_forecast > 3:
            return False, 0, f"❌ Rain expected ({rain_forecast:.1f}mm)"
        
        # Rule 3: Soil saturated
        if soil_moisture >= 70:
            return False, 0, f"❌ Soil saturated ({soil_moisture}%)"
        
        # Rule 4: Too soon since last watering
        if self.last_watering:
            hours_since = (tunisia_time - self.last_watering).total_seconds() / 3600
            if hours_since < 6:
                return False, 0, f"❌ Watered {hours_since:.1f}h ago"
        
        # Rule 5: Avoid midday watering (high evaporation)
        if 12 <= current_hour <= 16:
            if soil_moisture > self.MOISTURE_CRITICAL:
                return False, 0, "❌ Midday - wait for evening"
        
        # Rule 6: Critical dry - emergency
        if soil_moisture < self.MOISTURE_CRITICAL:
            amount = min(model_water_requirement * 0.8, season_max - self.daily_water_total)
            return True, amount, f"🚨 CRITICAL ({soil_moisture}%)"
        
        # Rule 7: Dry soil - water needed
        if soil_moisture < self.MOISTURE_DRY_THRESHOLD:
            amount = min(model_water_requirement * 0.7, season_max - self.daily_water_total)
            return True, amount, f"⚠️ Dry soil ({soil_moisture}%)"
        
        # Rule 8: Preventive watering
        if soil_moisture < self.MOISTURE_ADEQUATE:
            if model_water_requirement > 7:
                amount = min(model_water_requirement * 0.3, season_max - self.daily_water_total)
                return True, amount, "✅ Preventive watering"
        
        # Rule 9: All good
        return False, 0, f"✅ Soil OK ({soil_moisture}%)"
    
    # ========================================================================
    # MAIN CYCLE
    # ========================================================================
    
    def run_irrigation_cycle(self, temp_arduino, soil_moisture_sensor):
        """
        Complete irrigation cycle - run every 6 hours
        
        Args:
            temp_arduino: Temperature from Arduino (°C)
            soil_moisture_sensor: Moisture from sensor (%)
        
        Returns:
            (bool, float): (watered, amount_liters)
        """
        print("\n" + "="*70)
        print(f"🇹🇳 Smart Irrigation System - {self.governorate} (زغوان)")
        print(f"⏰ Time: {datetime.now(self.tz).strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🌱 Crop: {self.crop_type}")
        print("="*70)
        
        # Generate model input
        model_input, context = self.generate_model_input(
            temp_arduino,
            soil_moisture_sensor
        )
        
        # Display sensor data
        print(f"\n📊 Sensor Data:")
        print(f"   🌡️  Temperature: {temp_arduino}°C")
        print(f"   💧 Soil Moisture: {soil_moisture_sensor}%")
        print(f"   💨 Humidity: {context['humidity']}%")
        print(f"   🌧️  Rain forecast (6h): {context['rain_forecast_6h']}mm")
        print(f"   💨 Wind: {context['wind_speed']} m/s")
        
        # Display model input
        print(f"\n🤖 Model Input:")
        model_string = self.format_for_model(model_input)
        print(f"   {model_string}")
        print(f"\n   Breakdown:")
        for key, value in model_input.items():
            print(f"   - {key}: {value}")
        
        # TODO: Call your actual model here
        # For now, simulate
        # model_prediction = your_model.predict(model_string)
        model_prediction = 8.5  # Placeholder
        
        print(f"\n🎯 Model Prediction: {model_prediction:.2f} liters")
        
        # Make decision
        should_water, amount, reason = self.decide_watering(
            model_prediction,
            soil_moisture_sensor,
            context
        )
        
        print(f"\n💡 Decision: {reason}")
        
        if should_water:
            print(f"💦 WATERING: {amount:.2f} liters")
            print(f"📈 Daily total: {self.daily_water_total + amount:.2f}L / {self.season_limits[context['season']]}L")
            
            self.last_watering = context['timestamp']
            self.daily_water_total += amount
            
            # TODO: Activate pump
            # self.activate_pump(amount)
            
            return True, amount
        else:
            print(f"⏸️  No watering needed")
            return False, 0


# ============================================================================
# USAGE EXAMPLE
# ============================================================================

def main():
    # Initialize for Zaghouan
    farm = TunisiaIrrigationSystem(
        governorate="ZAGHOUAN",
        crop_type="TOMATO"  # Change to your crop
    )
    
    # Simulate sensor readings (replace with actual sensors)
    temperature_from_arduino = 25.3  # °C from your Arduino
    soil_moisture_from_sensor = 35.0  # % from your moisture sensor
    
    # Run irrigation cycle
    watered, amount = farm.run_irrigation_cycle(
        temperature_from_arduino,
        soil_moisture_from_sensor
    )
    
    if watered:
        print(f"\n✅ Watered {amount:.2f} liters")
    else:
        print(f"\n⏸️  Skipped watering")


if __name__ == "__main__":
    main()


def black_box(governorate, crop_type, temp_from_arduino, soil_moisture_sensor):
    """
    Black-box wrapper that uses the TunisiaIrrigationSystem to produce the
    model-ready outputs in a single call.

    Inputs:
        governorate (str): Governorate name (e.g. "ZAGHOUAN")
        crop_type (str): Crop name (e.g. "TOMATO")
        temp_from_arduino (float): Temperature in °C from Arduino
        soil_moisture_sensor (float): Soil moisture percent (0-100)

    Returns:
        tuple: (soil_type, region, temperature_bucket, weather_condition)
            - soil_type: one of "DRY", "HUMID", "WET"
            - region: one of "DESERT", "SEMI ARID", "SEMI HUMID", "HUMID"
            - temperature_bucket: one of "10-20", "20-30", "30-40", "40-50"
            - weather_condition: one of "NORMAL", "SUNNY", "WINDY", "RAINY"
    """

    farm = TunisiaIrrigationSystem(governorate=governorate, crop_type=crop_type)

    # Use existing code path to build the model input (will also call weather API)
    model_input, _ = farm.generate_model_input(temp_from_arduino, soil_moisture_sensor)

    soil_type = model_input.get('SOIL_TYPE')
    region = model_input.get('REGION')
    temperature_bucket = model_input.get('TEMPERATURE')
    weather_condition = model_input.get('WEATHER_CONDITION')

    return soil_type, region, temperature_bucket, weather_condition


def predict_water_requirement(model_path, crop_type, soil_type, region, temperature, weather_condition):
    """
    Loads the model, preprocesses inputs using one-hot encoding, and predicts water requirement.
    """
    if not os.path.exists(model_path):
        raise FileNotFoundError(f"Model file not found at: {model_path}")

    # Load the model using joblib or pickle
    model = None
    try:
        if joblib:
            model = joblib.load(model_path)
        else:
            with open(model_path, 'rb') as f:
                model = pickle.load(f)
    except Exception as e:
        try:
            with open(model_path, 'rb') as f:
                model = pickle.load(f)
        except Exception as pickle_e:
            raise RuntimeError(f"Failed to load model with both joblib and pickle. Error: {pickle_e}")

    # Create a sample input DataFrame with all columns initialized to 0
    sample_input = pd.DataFrame({
        'CROP TYPE_BEAN': [0], 'CROP TYPE_CABBAGE': [0], 'CROP TYPE_CITRUS': [0],
        'CROP TYPE_COTTON': [0], 'CROP TYPE_MAIZE': [0], 'CROP TYPE_MELON': [0],
        'CROP TYPE_MUSTARD': [0], 'CROP TYPE_ONION': [0], 'CROP TYPE_POTATO': [0],
        'CROP TYPE_RICE': [0], 'CROP TYPE_SOYABEAN': [0], 'CROP TYPE_SUGARCANE': [0],
        'CROP TYPE_TOMATO': [0], 'CROP TYPE_WHEAT': [0], 'SOIL TYPE_HUMID': [0],
        'SOIL TYPE_WET': [0], 'REGION_HUMID': [0], 'REGION_SEMI ARID': [0],
        'REGION_SEMI HUMID': [0], 'TEMPERATURE_20-30': [0], 'TEMPERATURE_30-40': [0],
        'TEMPERATURE_40-50': [0], 'WEATHER CONDITION_RAINY': [0],
        'WEATHER CONDITION_SUNNY': [0], 'WEATHER CONDITION_WINDY': [0],
    })

    # One-hot encode the inputs
    crop_col = f'CROP TYPE_{crop_type.upper()}'
    if crop_col in sample_input.columns:
        sample_input[crop_col] = 1

    soil_col = f'SOIL TYPE_{soil_type.upper()}'
    if soil_col in sample_input.columns:
        sample_input[soil_col] = 1

    region_col = f'REGION_{region.upper()}'
    if region_col in sample_input.columns:
        sample_input[region_col] = 1

    temp_col = f'TEMPERATURE_{temperature}'
    if temp_col in sample_input.columns:
        sample_input[temp_col] = 1

    weather_col = f'WEATHER CONDITION_{weather_condition.upper()}'
    if weather_col in sample_input.columns:
        sample_input[weather_col] = 1

    # Make the prediction
    prediction = model.predict(sample_input)
    return prediction[0]


def get_prediction_from_sensors(model_path, governorate, crop_type, temp_from_arduino, soil_moisture_sensor):
    """
    A complete end-to-end wrapper that takes raw sensor and config data,
    processes it, and returns the final water requirement prediction.

    Args:
        model_path (str): The full path to the .pkl model file.
        governorate (str): The governorate name (e.g., "ZAGHOUAN").
        crop_type (str): The type of crop (e.g., "TOMATO").
        temp_from_arduino (float): Temperature in °C from the sensor.
        soil_moisture_sensor (float): Soil moisture as a percentage (0-100).

    Returns:
        float: The predicted water requirement.
    """
    # Step 1: Convert raw sensor data to categorical features using the black_box function.
    soil_type, region, temperature, weather_condition = black_box(
        governorate, crop_type, temp_from_arduino, soil_moisture_sensor
    )

    # Step 2: Use the generated features to get the water requirement prediction.
    water_requirement = predict_water_requirement(
        model_path,
        crop_type,
        soil_type,
        region,
        temperature,
        weather_condition
    )

    return water_requirement

def calculate_pump_activation_time(water_volume_liters, pump_flow_rate_lpm=4.0):
    """
    Calculates the required pump activation time in milliseconds to deliver a specific volume of water.

    Args:
        water_volume_liters (float): The desired volume of water to pump, in liters.
        pump_flow_rate_lpm (float, optional): The flow rate of the pump in Liters Per Minute (LPM).
                                             Defaults to 4.0 LPM, a common rate for small 12V DC pumps
                                             used in hobbyist projects.

    Returns:
        int: The calculated activation time in milliseconds. Returns 0 if the volume is zero or negative.

    How to Calibrate 'pump_flow_rate_lpm':
    1. Get a container of a known volume (e.g., a 1-liter bottle).
    2. Time how many seconds it takes for your pump to fill the container.
    3. Calculate the flow rate: flow_rate_lps = volume_liters / time_seconds.
    4. Convert to Liters Per Minute: pump_flow_rate_lpm = flow_rate_lps * 60.
    5. Use this value for more accurate calculations.
    """
    if water_volume_liters <= 0:
        return 0

    # Calculate the time in minutes required to pump the desired volume
    time_in_minutes = water_volume_liters / pump_flow_rate_lpm

    # Convert minutes to milliseconds
    time_in_milliseconds = time_in_minutes * 60 * 1000

    return int(time_in_milliseconds)