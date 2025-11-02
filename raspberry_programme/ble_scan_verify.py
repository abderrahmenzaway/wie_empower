"""
BLE scanner to verify the Windows advertisement from raspberry.py.

It looks for devices whose local name starts with 'PiIrr-' and/or that
carry Manufacturer Data with company ID 0xFFFF. It decodes the custom
payload we broadcast:

struct '<HIB' (little-endian):
- humidity: uint16 (0..65535)
- pump_time_ms: uint32
- pump_state: uint8 (0=OFF, 1=ON)

Run with the same virtual environment:
  .venv\Scripts\python.exe ble_scan_verify.py
"""
import asyncio
import struct
from typing import Optional

from bleak import BleakScanner

TARGET_NAME_PREFIX = "PiIrr-"
MANUFACTURER_ID = 0xFFFF


def decode_payload(data: bytes) -> Optional[tuple[int, int, str]]:
    """Decode <HIB payload -> (humidity, pump_time_ms, pump_state)."""
    try:
        humidity, pump_time_ms, pump_state = struct.unpack("<HIB", data)
        return humidity, pump_time_ms, pump_state
    except Exception:
        return None


def fmt_state(val: int) -> str:
    return "ON" if val == 1 else "OFF"


async def scan_once(timeout: float = 10.0) -> None:
    print("Scanning for BLE advertisements...")

    seen = set()

    def callback(device, adv_data):
        name = adv_data.local_name or device.name or ""
        mfg = adv_data.manufacturer_data or {}

        # Filter by name prefix or manufacturer id
        if not (name.startswith(TARGET_NAME_PREFIX) or (MANUFACTURER_ID in mfg)):
            return

        key = (device.address, adv_data.local_name)
        if key in seen:
            return
        seen.add(key)

        payload = mfg.get(MANUFACTURER_ID)
        decoded = decode_payload(payload) if payload else None

        print("\nDevice:")
        print(f"  Address : {device.address}")
        print(f"  RSSI    : {adv_data.rssi}")
        print(f"  Name    : {name}")

        if decoded:
            humidity, pump_time_ms, pump_state = decoded
            print("  Manufacturer ID 0xFFFF payload:")
            print(f"    humidity     : {humidity}")
            print(f"    pump_time_ms : {pump_time_ms}")
            print(f"    pump_state   : {fmt_state(pump_state)} ({pump_state})")
        else:
            if payload:
                print(f"  Manufacturer ID 0xFFFF payload (raw hex): {payload.hex()}")
            else:
                print("  No manufacturer payload with 0xFFFF found on this packet.")

    scanner = BleakScanner(detection_callback=callback)
    async with scanner:
        await asyncio.sleep(timeout)

    if not seen:
        print("\nNo matching advertisements seen. If you're advertising from the same laptop,\nWindows may not report its own advertisements to the scanner. Try scanning\nfrom your phone with nRF Connect or run this script on another device.")


if __name__ == "__main__":
    asyncio.run(scan_once(12.0))
