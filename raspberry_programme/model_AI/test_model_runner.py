import importlib.util
import os

# Path to the module file
module_path = r"C:\Users\User\OneDrive\Desktop\wie\raspberry_programme\model_maa\import requests.py"

# Path to the model file
model_path = r"C:\Users\User\OneDrive\Desktop\wie\raspberry_programme\model_maa\crop_water_requirement_model (1).pkl"

# Dynamically import the module
spec = importlib.util.spec_from_file_location("irrigation_module", module_path)
irrigation_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(irrigation_module)

# Define the inputs for the end-to-end function
governorate = "ZAGHOUAN"
crop_type = "TOMATO"
temp_from_arduino = 35.3
soil_moisture_sensor = 25.0

# Run the end-to-end prediction and print the result
try:
    water_requirement = irrigation_module.get_prediction_from_sensors(
        model_path,
        governorate,
        crop_type,
        temp_from_arduino,
        soil_moisture_sensor
    )
    print(f"Predicted Water Requirement from sensors: {water_requirement}")

    # Now, calculate the pump activation time for the predicted water requirement
    pump_activation_time_ms = irrigation_module.calculate_pump_activation_time(water_requirement)
    print(f"Calculated Pump Activation Time: {pump_activation_time_ms} ms")
except FileNotFoundError as e:
    print(f"Error: {e}")
except RuntimeError as e:
    print(f"Error: {e}")
except Exception as e:
    print(f"An unexpected error occurred: {e}")
