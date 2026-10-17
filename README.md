# Smart Irrigation with AI (WIE Empower Hackathon)

🏆 **3rd place** at the WIE Empower national hackathon.

A smart irrigation system that decides **when and how much to water** a crop. Soil moisture sensors on an Arduino send readings over Wi-Fi to a Raspberry Pi, which combines them with the temperature and the local weather forecast, asks a machine learning model how much water the crop needs, and sends back how long to run the pump.

▶️ [Watch the demo](docs/demo.mp4)

## How it works

```
3 soil moisture sensors ──► Arduino + ESP8266 ──── Wi-Fi (TCP) ────► Raspberry Pi
                                  ▲                                     │
                                  │                     DS18B20 temperature (1-Wire)
                                  │                     Open-Meteo weather forecast
                                  │                                     │
                                  │                     AI model: water needed (L)
                                  │                                     │
                                  └──── pump time (ms) ◄── litres ÷ pump flow rate
                                  │
                              relay ──► water pump
```

1. The Arduino averages its **3 soil moisture sensors** and sends the value to the Pi over Wi-Fi.
2. The Pi reads the **air temperature** (DS18B20) and the **weather** for the farm's location from the Open-Meteo API: current conditions and rain expected in the next 6 hours.
3. The readings are turned into the model's input features: crop type, soil state (dry / humid / wet), climate region, temperature range and weather condition (normal / sunny / windy / rainy).
4. A **Random Forest regression model** (scikit-learn) predicts the crop's water requirement in litres.
5. The litres are converted into a **pump time in milliseconds** using the pump's flow rate, and sent back to the Arduino, which runs the pump for that time.

If the model or the temperature is unavailable, the server falls back to a simple rule based on how dry the soil is, so the plants are still watered.

### Watering rules

[`irrigation_model.py`](raspberry_pi/ai_model/irrigation_model.py) also contains a full irrigation cycle (`run_irrigation_cycle`) that adds a rule layer on top of the model (`decide_watering`). It skips watering when:
- more than 3 mm of rain is expected in the next 6 hours,
- the soil is already saturated (≥ 70 %),
- the crop was watered less than 6 hours ago,
- the daily water limit for the season is reached,
- it is midday (12:00 to 16:00, high evaporation), unless the soil is critically dry.

The server currently sends the model's prediction directly; plugging this rule layer into the server is the natural next step.

## Repository layout

```
raspberry_pi/
  irrigation_server.py      TCP server: receives readings, runs the model, sends pump commands
  ai_model/
    irrigation_model.py     feature preparation, weather API, model prediction, watering rules
    crop_water_model.pkl    trained Random Forest model (scikit-learn)
    test_model_runner.py    runs one prediction end to end, without hardware
  mock_arduino_client.py    simulates the Arduino to test the server on a PC
  ble_scan_verify.py        optional: checks the Bluetooth Low Energy status broadcast
  requirements.txt
arduino/soil_moisture_node/
  soil_moisture_node.ino    reads the sensors, talks to the Pi over Wi-Fi, drives the pump relay
hardware/                   wiring diagrams (Fritzing): Arduino side and Raspberry Pi side
docs/demo.mp4               demo video
```

## Run it

### Test on a PC (no hardware)

```bash
pip install -r raspberry_pi/requirements.txt

python raspberry_pi/ai_model/test_model_runner.py      # one AI prediction
python raspberry_pi/irrigation_server.py -v            # start the server (terminal 1)
python raspberry_pi/mock_arduino_client.py             # fake Arduino (terminal 2)
```

### On the real system

1. **Raspberry Pi**: set it up as a Wi-Fi access point with the static IP `192.168.4.1`, enable 1-Wire for the DS18B20, then:
   ```bash
   pip install -r raspberry_pi/requirements.txt
   python3 raspberry_pi/irrigation_server.py
   ```
   Set `HOST = "192.168.4.1"` in `irrigation_server.py` (it is `127.0.0.1` for local testing). The farm settings are at the top of the file: `GOVERNORATE` (e.g. `ZAGHOUAN`) and `CROP_TYPE` (e.g. `TOMATO`).
2. **Arduino**: install the `WiFiEspAT` library, put the Pi's Wi-Fi name and password in `soil_moisture_node.ino`, and upload.
   Wiring: ESP8266 on pins 0 / 1, soil moisture sensors on A3, A4 and A5, pump relay on pin 2.

## Protocol

| Direction | Message |
|---|---|
| Arduino → Pi | average soil moisture reading, as text (e.g. `350`) |
| Pi → Arduino | pump time in milliseconds, as text followed by a newline (e.g. `2500\n`); `0` means no watering |

## Tech

Python, scikit-learn (Random Forest), pandas, Open-Meteo API, TCP sockets, Raspberry Pi, DS18B20 (1-Wire), Arduino, ESP8266 (Wi-Fi), Fritzing
