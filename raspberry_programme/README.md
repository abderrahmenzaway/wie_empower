# Raspberry Pi ↔ Arduino/ESP8266 Moisture Sensor System

This project contains the code for a Raspberry Pi to act as a controller for an Arduino-based soil moisture sensing system. The Pi runs a TCP server, and the Arduino (with an ESP8266) connects to it as a client to send sensor data and receive pump commands.

## Communication Protocol

1.  **Arduino (Client)** connects to the Raspberry Pi's Wi-Fi network.
2.  Arduino sends the average soil moisture reading (an integer as a string, e.g., "350") to the Pi server.
3.  **Raspberry Pi (Server)** reads the value.
4.  If the value is below a `DRY_THRESHOLD` (e.g., 200), the Pi sends back a single byte representing the desired pump duration in milliseconds (e.g., `250`).
5.  If the soil is moist, the Pi sends back a `0` byte.
6.  The Arduino receives the byte and runs the pump for that duration.
7.  The connection is kept alive for continuous monitoring.

## Raspberry Pi Setup

### 1. Configure as a Wi-Fi Access Point

Your Raspberry Pi **must** be set up as a Wi-Fi Access Point (AP) so the Arduino can connect to it directly.

-   **SSID**: `YourPiSSID`
-   **Password**: `YourPiPassword`
-   **Static IP Address**: `192.168.4.1`

You can achieve this using `raspi-config`, `nmcli`, or by manually configuring `hostapd` and `dnsmasq`.

### 2. Run the Server Script

Once the Pi is running as an AP, run the Python server script.

```bash
# Navigate to the directory
cd /path/to/your/raspberry_programme

# Run the server
python3 raspberry.py
```

-   The server will start and listen on `192.168.4.1:8000`.
-   Use the `-v` flag for more detailed logs: `python3 raspberry.py -v`.
-   Press `Ctrl+C` to stop the server.

## Arduino Setup

1.  **Library**: Ensure you have the `WiFiEspAT` library installed in your Arduino IDE.
2.  **Wiring**:
    -   ESP8266 connected to Arduino pins 0 (RX) and 1 (TX).
    -   Soil moisture sensors on A3, A4, A5.
    -   Pump relay on pin 2.
3.  **Code**:
    -   Open `zone_programm.ino`.
    -   **Crucially, update the Wi-Fi credentials** to match your Pi's AP:
        ```cpp
        const char* WIFI_SSID = "YourPiSSID";
        const char* WIFI_PASS = "YourPiPassword";
        ```
    -   Upload the sketch to your Arduino.

## How It Works

-   `raspberry.py`: A simple, single-file TCP server that listens for one or more Arduino clients. It runs a separate thread for each client to handle its messages.
-   `zone_programm.ino`: The Arduino sketch that reads sensors, connects to the Pi's Wi-Fi, sends data, and waits for a command. The logic to run the pump based on a local threshold (`seuil`) is bypassed when connected to the Pi.
