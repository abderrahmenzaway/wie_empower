"""
Mock Arduino Client for testing the raspberry.py server on a local machine.

This script simulates the behavior of the Arduino/ESP8266 by:
1. Connecting to the TCP server.
2. Sending a simulated soil moisture value.
3. Waiting for and printing the server's response (pump command).
4. Repeating this process every 10 seconds.
"""
import socket
import time
import random

# The server's address and port (must match raspberry.py)
HOST = "127.0.0.1"
PORT = 8000

def run_mock_client():
    """Connects to the server and sends simulated data."""
    print("--- Mock Arduino Client Started ---")
    print(f"Attempting to connect to server at {HOST}:{PORT}...")

    while True:
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.connect((HOST, PORT))
                print("\n[Connected to server]")

                # Simulate a soil moisture value (e.g., a random value between 0 and 100)
                moisture_value = random.randint(0, 100)
                print(f"Sending simulated moisture value: {moisture_value}")

                # Send the data, ensuring it's a string followed by a newline
                s.sendall(f"{moisture_value}\n".encode('utf-8'))

                # Wait for the response from the server
                response = s.recv(1024).decode('utf-8').strip()
                print(f"Received pump command from server: {response} ms")

        except ConnectionRefusedError:
            print("Connection refused. Is the raspberry.py server running?")
        except Exception as e:
            print(f"An error occurred: {e}")
        
        # Wait for a few seconds before sending the next reading
        print("---------------------------------")
        time.sleep(11)

if __name__ == "__main__":
    run_mock_client()
