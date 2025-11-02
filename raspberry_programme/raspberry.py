"""
Raspberry Pi TCP server for Arduino/ESP8266 soil moisture system.

This script acts as a TCP server listening on a fixed IP and port. It's
designed to work with the 'zone_programm.ino' sketch.

**IMPORTANT PI SETUP:**
Your Raspberry Pi must be configured as a Wi-Fi Access Point with the
following settings for the Arduino to connect:
  - SSID:     YourPiSSID
  - Password: YourPiPassword
  - Static IP: 192.168.4.1

Usage (on Raspberry Pi):
  python3 raspberry.py
"""

import argparse
import logging
import socket
import threading
import time
import glob
import os
import importlib.util
import asyncio
import uuid
import sys
import struct

# Optional BLE (server) support — guarded import so script still runs when unavailable
BLE_AVAILABLE = False
BLE_IMPORT_ERROR = ""
try:
    from bleak import BleakServer  # Not available in many Bleak versions
    from bleak import BleakGATTService, BleakGATTCharacteristic
    BLE_AVAILABLE = True
except Exception as _ble_e:
    BLE_IMPORT_ERROR = str(_ble_e)
    BLE_AVAILABLE = False

# Optional Windows BLE Advertisement publisher (works on Windows laptops)
BLE_ADV_AVAILABLE = False
BLE_ADV_IMPORT_ERROR = ""
try:
    from winrt.windows.devices.bluetooth.advertisement import (
        BluetoothLEAdvertisementPublisher,
        BluetoothLEManufacturerData,
        BluetoothLEAdvertisementFlags,
    )
    from winrt.windows.storage.streams import DataWriter
    BLE_ADV_AVAILABLE = True
except Exception as _adv_e:
    BLE_ADV_IMPORT_ERROR = str(_adv_e)
    BLE_ADV_AVAILABLE = False

# --- AI Model Configuration ---
# Path to your irrigation model module and the trained model file
MODULE_PATH = r"c:\Users\User\OneDrive\Desktop\wie\raspberry_programme\model_maa\import requests.py"
MODEL_PATH = r"c:\Users\User\OneDrive\Desktop\wie\raspberry_programme\model_maa\crop_water_requirement_model (1).pkl"

# Inputs for the model
GOVERNORATE = "ZAGHOUAN"
CROP_TYPE = "TOMATO"

# --- Global variable to hold the latest temperature reading ---
current_temperature_c = None
temp_lock = threading.Lock()

# --- Globals for BLE ---
# Using a lock to ensure thread-safe updates to BLE data
ble_lock = threading.Lock()
ble_plant_type = CROP_TYPE  # Set from model config
ble_humidity = 0
ble_pump_state = "OFF"
ble_pump_time_ms = 0

# Define UUIDs for our custom BLE service and characteristics
# Using standard Environmental Sensing service UUID for base
IRRIGATION_SERVICE_UUID = uuid.UUID("0000181A-0000-1000-8000-00805f9b34fb")
# Custom characteristics
PLANT_TYPE_CHAR_UUID = uuid.UUID("00002A00-0000-1000-8000-00805f9b34fb") # Standard UUID for Device Name
HUMIDITY_CHAR_UUID = uuid.UUID("00002A6F-0000-1000-8000-00805f9b34fb")   # Standard UUID for Humidity
PUMP_STATE_CHAR_UUID = uuid.UUID("00000003-2d8b-4b47-8791-22489487a93b") # Custom UUID for Pump State
PUMP_TIME_CHAR_UUID = uuid.UUID("00000004-2d8b-4b47-8791-22489487a93b")  # Custom UUID for Pump Time (ms)


# --- BLE Server Implementation ---
if BLE_AVAILABLE:
    class IrrigationService(BleakGATTService):
        """
        Custom BLE Service for the Irrigation System.
        """
        def __init__(self):
            super().__init__(IRRIGATION_SERVICE_UUID)

            # Plant Type Characteristic (Read-only)
            self.add_characteristic(
                BleakGATTCharacteristic(
                    PLANT_TYPE_CHAR_UUID,
                    ["read"],
                )
            )
            # Humidity Characteristic (Read-only with notifications)
            self.add_characteristic(
                BleakGATTCharacteristic(
                    HUMIDITY_CHAR_UUID,
                    ["read", "notify"],
                )
            )
            # Pump State Characteristic (Read-only with notifications)
            self.add_characteristic(
                BleakGATTCharacteristic(
                    PUMP_STATE_CHAR_UUID,
                    ["read", "notify"],
                )
            )

            # Pump Time (ms) Characteristic (Read-only with notifications)
            self.add_characteristic(
                BleakGATTCharacteristic(
                    PUMP_TIME_CHAR_UUID,
                    ["read", "notify"],
                )
            )

    async def run_ble_server(stop_event):
        """
        Initializes and runs the BLE GATT server.
        """
        service = IrrigationService()
        # The advertised name is set here
        server_name = "Pi-Irrigation"
        
        # Correctly initialize BleakServer with keyword arguments
        async with BleakServer(services=[service], advertisement_data={"local_name": server_name}) as server:
            logging.info(f"BLE Server '{server_name}' running with service {service.uuid}")
            
            while not stop_event.is_set():
                # Get the latest data in a thread-safe way
                with ble_lock:
                    humidity_val = ble_humidity
                    pump_state_val = ble_pump_state
                    plant_type_val = ble_plant_type
                    pump_time_val = ble_pump_time_ms

                # Get characteristic handles
                plant_type_char = service.get_characteristic(PLANT_TYPE_CHAR_UUID)
                humidity_char = service.get_characteristic(HUMIDITY_CHAR_UUID)
                pump_state_char = service.get_characteristic(PUMP_STATE_CHAR_UUID)
                pump_time_char = service.get_characteristic(PUMP_TIME_CHAR_UUID)

                # Update characteristic values. Bleak handles the sending.
                # For standard characteristics, data format may be important.
                # Humidity (uint16, 0.01% steps)
                humidity_ble_format = int(humidity_val * 100).to_bytes(2, 'little')
                
                # Use the characteristic's write_value method to update
                await server.write_gatt_char(plant_type_char.uuid, plant_type_val.encode('utf-8'))
                await server.write_gatt_char(humidity_char.uuid, humidity_ble_format)
                await server.write_gatt_char(pump_state_char.uuid, pump_state_val.encode('utf-8'))
                await server.write_gatt_char(pump_time_char.uuid, str(pump_time_val).encode('utf-8'))
                
                # Notify subscribers of changes
                if server.is_connected:
                    try:
                        await server.notify_gatt_char(humidity_char.uuid)
                        await server.notify_gatt_char(pump_state_char.uuid)
                        await server.notify_gatt_char(pump_time_char.uuid)
                    except Exception as e:
                        logging.warning(f"Could not notify BLE client: {e}")

                # Wait before next update
                await asyncio.sleep(2)
                
            logging.info("BLE Server shutting down.")

    def ble_server_thread(stop_event):
        """
        Wrapper to run the asyncio BLE server in its own thread.
        """
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            loop.run_until_complete(run_ble_server(stop_event))
        finally:
            loop.close()
else:
    def _ble_adv_build_payload() -> bytes:
        """Build a compact manufacturer payload: [hum_lo, hum_hi, pump_time(4 bytes LE), state(1)]."""
        with ble_lock:
            hum = int(ble_humidity) & 0xFFFF
            ptime = int(ble_pump_time_ms) & 0xFFFFFFFF
            state = 1 if ble_pump_state == "ON" else 0
            # Pack little-endian: H I B
            return struct.pack('<HIB', hum, ptime, state)

    def _ble_windows_advertiser_thread(stop_event: threading.Event):
        if not BLE_ADV_AVAILABLE or sys.platform != 'win32':
            logging.warning(
                "BLE advertising not available on this platform. bleak server error: %s; adv import error: %s",
                BLE_IMPORT_ERROR,
                BLE_ADV_IMPORT_ERROR,
            )
            while not stop_event.is_set():
                time.sleep(1)
            return

        publisher = BluetoothLEAdvertisementPublisher()
        # Keep the advertisement minimal; avoid setting local_name which can cause E_INVALIDARG on some Windows stacks
        try:
            publisher.advertisement.flags = (
                BluetoothLEAdvertisementFlags.GENERAL_DISCOVERABLE_MODE
                | BluetoothLEAdvertisementFlags.BR_EDR_NOT_SUPPORTED
            )
        except Exception:
            pass

        # Start with an initial payload
        def _update_payload():
            md_list = publisher.advertisement.manufacturer_data
            md_list.clear()
            payload = _ble_adv_build_payload()
            writer = DataWriter()
            # write_bytes expects a bytes-like object
            writer.write_bytes(payload)
            # Use a generic, non-reserved company identifier to avoid stack rejections
            md = BluetoothLEManufacturerData(0x1234, writer.detach_buffer())
            md_list.append(md)

        _update_payload()

        try:
            publisher.start()
            logging.info("BLE Advertising started (Windows publisher)")
        except Exception as e:
            logging.warning("Failed to start BLE advertising: %s", e)
            while not stop_event.is_set():
                time.sleep(1)
            return

        # Periodically refresh payload with latest values
        try:
            while not stop_event.is_set():
                _update_payload()
                time.sleep(2)
        finally:
            try:
                publisher.stop()
            except Exception:
                pass
            logging.info("BLE Advertising stopped")

    # Expose a unified name so the rest of the app can start "BLE" thread
    def ble_server_thread(stop_event: threading.Event):
        _ble_windows_advertiser_thread(stop_event)

# Dynamically import the irrigation module
try:
    spec = importlib.util.spec_from_file_location("irrigation_module", MODULE_PATH)
    irrigation_module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(irrigation_module)
    logging.info("Successfully loaded AI model module.")
except FileNotFoundError:
    logging.error("AI model module not found at %s", MODULE_PATH)
    irrigation_module = None
except Exception as e:
    logging.error("Failed to load AI model module: %s", e)
    irrigation_module = None


# --- Configuration ---
HOST = "127.0.0.1"  # IP for the Pi to listen on (localhost for testing)
PORT = 8000          # Port for the Pi to listen on
DRY_THRESHOLD = 400     # Start watering if sensor value is BELOW this.

# --------------------------- Logging setup ---------------------------------
def setup_logging(verbosity: int) -> None:
    level = logging.INFO if verbosity > 0 else logging.WARNING
    logging.basicConfig(
        level=level,
        format="[%(asctime)s] %(levelname)s: %(message)s",
        datefmt="%H:%M:%S",
    )

# ------------------------ Server Logic -------------------------------------

def find_temp_sensor() -> str | None:
    """Finds the path to the 1-Wire sensor's data file."""
    # On non-Linux systems, this path won't exist.
    if not sys.platform.startswith('linux'):
        logging.info("Not on Linux. Skipping real temperature sensor search.")
        return None
    try:
        # The base directory for 1-Wire devices
        base_dir = '/sys/bus/w1/devices/'
        # Find the folder starting with '28-' which is the family code for DS18B20
        device_folder = glob.glob(base_dir + '28*')[0]
        return device_folder + '/w1_slave'
    except IndexError:
        logging.error("DS18B20 sensor not found. Check wiring and 1-Wire config.")
        return None

def read_temp(sensor_path: str) -> float | None:
    """Reads the temperature from the sensor file."""
    try:
        with open(sensor_path, 'r') as f:
            lines = f.readlines()
        
        # Check for a valid reading
        if not lines or 'YES' not in lines[0]:
            return None
        
        # Find the temperature line and extract the value
        temp_pos = lines[1].find('t=')
        if temp_pos != -1:
            temp_string = lines[1][temp_pos + 2:]
            temp_c = float(temp_string) / 1000.0
            return temp_c
    except (IOError, IndexError):
        logging.warning("Could not read from sensor at %s", sensor_path)
        return None

def temperature_monitor_thread(sensor_path: str | None, interval_seconds: int = 30):
    """A thread that periodically reads temperature and updates a global variable."""
    global current_temperature_c
    logging.info("Starting temperature monitor thread.")
    
    # If no sensor is found, run in simulation mode
    if sensor_path is None:
        logging.warning("Running temperature monitor in SIMULATION mode.")
        while True:
            with temp_lock:
                current_temperature_c = 25.0  # Simulate a constant 25°C
            logging.debug("Updated global temperature (simulated): %.2f°C", 25.0)
            time.sleep(interval_seconds)

    # If a sensor is found, run in normal mode
    while True:
        temp_c = read_temp(sensor_path)
        if temp_c is not None:
            with temp_lock:
                current_temperature_c = temp_c
            logging.debug("Updated global temperature: %.2f°C", temp_c)
        else:
            logging.warning("Failed to read temperature. Keeping last known value.")
        # Wait for the next reading
        time.sleep(interval_seconds)

def calculate_pump_value(sensor_value: int) -> int:
    """
    Calculates a pump command value (0-100) based on the sensor reading.
    - 100 means max watering (very dry).
    - 0 means no watering (moist enough).
    """
    if sensor_value >= DRY_THRESHOLD:
        # Soil is moist enough, no water needed.
        return 0

    # The soil is dry. Calculate how much water is needed on a scale of 0-100.
    # We use a simple linear mapping: the drier the soil (lower sensor value),
    # the higher the pump value.
    
    # Clamp the value to a minimum of 0 to avoid negative results if sensor is noisy
    clamped_value = max(0, sensor_value)
    
    # Calculate the "dryness" percentage (0% = at threshold, 100% = at reading 0)
    dryness_fraction = (DRY_THRESHOLD - clamped_value) / DRY_THRESHOLD
    
    # Map the dryness fraction to our 0-100 scale
    pump_value = int(dryness_fraction * 100)
    
    # Ensure the value is always within the 0-100 range
    return max(0, min(100, pump_value))


def handle_client(conn: socket.socket, addr: tuple) -> None:
    """
    This function runs in a thread for each connected client.
    """
    logging.info("Client connected: %s", addr)
    buffer = ""
    try:
        while True:
            # Read data from the Arduino
            data = conn.recv(64)
            if not data:
                logging.warning("Client %s disconnected.", addr)
                break

            # The Arduino sends raw numbers as strings, e.g., b'350'
            buffer += data.decode('utf-8', errors='ignore')
            
            # Process buffer for complete numbers
            try:
                soil_moisture_sensor = int(buffer)
                logging.info("<- Received soil moisture: %d from %s", soil_moisture_sensor, addr)
                buffer = "" # Clear buffer after successful parse

                # --- Watering Decision Logic (AI if available, else fallback) ---
                pump_time_ms = 0  # Always define a default
                used_ai = False
                if irrigation_module:
                    with temp_lock:
                        temp_from_pi = current_temperature_c
                    if temp_from_pi is None:
                        logging.warning("Temperature data is not available. Falling back to simple rule.")
                    else:
                        try:
                            # 1. Get water requirement prediction from the model
                            water_req = irrigation_module.get_prediction_from_sensors(
                                MODEL_PATH,
                                GOVERNORATE,
                                CROP_TYPE,
                                temp_from_pi,
                                soil_moisture_sensor
                            )
                            logging.info("AI model predicted water requirement: %s", water_req)

                            # 2. Calculate the pump activation time based on the prediction
                            pump_time_ms = int(irrigation_module.calculate_pump_activation_time(water_req))
                            used_ai = True
                            logging.info("-> AI calculated pump command: %d ms", pump_time_ms)
                        except Exception as e:
                            logging.error("An error occurred during AI model prediction: %s", e)
                if not used_ai:
                    # Fallback to the old logic if the model isn't loaded or usable
                    fallback_percent = calculate_pump_value(soil_moisture_sensor)
                    pump_time_ms = max(pump_time_ms, int(fallback_percent * 100))  # simple ms estimate
                    logging.info("Fallback pump command: %d ms (from %d%%)", pump_time_ms, fallback_percent)

                # Update BLE characteristics with the new data
                with ble_lock:
                    ble_humidity = soil_moisture_sensor
                    ble_pump_state = "ON" if pump_time_ms > 0 else "OFF"
                    ble_pump_time_ms = pump_time_ms

                # Send the command back to the Arduino as a string with a newline
                conn.sendall(f"{pump_time_ms}\n".encode('utf-8'))

            except (ValueError, TypeError):
                # Buffer doesn't contain a full number yet, wait for more data
                logging.debug("Incomplete data in buffer: '%s'", buffer)
                continue
            except Exception:
                logging.exception("Error processing data from %s", addr)

    except ConnectionResetError:
        logging.warning("Connection reset by client %s", addr)
    except Exception:
        logging.exception("An error occurred with client %s", addr)
    finally:
        logging.info("Closing connection for %s", addr)
        conn.close()


def run_tcp_server(host: str, port: int, stop_event: threading.Event):
    """
    Starts the main TCP server and listens for incoming connections.
    """
    server_socket = None
    try:
        server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server_socket.bind((host, port))
        server_socket.listen(5)
        server_socket.settimeout(1.0) # Timeout to allow checking stop_event
        logging.info(f"TCP Server listening on {host}:{port}")

        while not stop_event.is_set():
            try:
                client_socket, addr = server_socket.accept()
                client_handler = threading.Thread(target=handle_client, args=(client_socket, addr), daemon=True)
                client_handler.start()
            except socket.timeout:
                continue # Go back to checking stop_event
    except Exception as e:
        logging.error(f"An error occurred in TCP server: {e}")
    finally:
        if server_socket:
            server_socket.close()
        logging.info("TCP Server has shut down.")

# --------------------------- CLI and main ----------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(description="Raspberry Pi TCP and BLE server for Arduino moisture sensor.")
    parser.add_argument("-v", "--verbose", action="count", default=0, help="Increase logging verbosity (-v)")
    args = parser.parse_args()
    
    setup_logging(args.verbose)

    # --- Start Temperature Monitor ---
    sensor_path = find_temp_sensor()
    # Always start the temperature monitor. If no sensor is present, it runs in SIMULATION mode
    temp_thread = threading.Thread(
        target=temperature_monitor_thread,
        args=(sensor_path,),
        daemon=True
    )
    temp_thread.start()
    
    # --- Start Servers ---
    stop_main_event = threading.Event()

    # Start the BLE server in a separate thread
    ble_thread = threading.Thread(target=ble_server_thread, args=(stop_main_event,), daemon=True)
    ble_thread.start()
    logging.info("BLE server thread started.")

    # Start the TCP server in a separate thread
    tcp_thread = threading.Thread(target=run_tcp_server, args=(HOST, PORT, stop_main_event), daemon=True)
    tcp_thread.start()
    logging.info("TCP server thread started.")

    print(f"Servers started. Listening for Arduino on {HOST}:{PORT}...")
    print(f"Broadcasting BLE as 'Pi-Irrigation'.")
    print("Press Ctrl+C to exit.")

    try:
        # Keep the main thread alive to catch KeyboardInterrupt
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        logging.info("Shutdown signal received.")
    finally:
        logging.info("Shutting down all services...")
        stop_main_event.set() # Signal all threads to stop
        
        # Wait for threads to finish
        if tcp_thread.is_alive():
            tcp_thread.join()
        if ble_thread.is_alive():
            ble_thread.join()
        
        logging.info("All threads closed. Exiting.")
    
    return 0

if __name__ == "__main__":
    # Note: On Windows, running the BLE server might require admin privileges.
    # The asyncio event loop for bleak might not work correctly inside a
    # regular subprocess on Windows, so it's best to run this script directly.
    main()
