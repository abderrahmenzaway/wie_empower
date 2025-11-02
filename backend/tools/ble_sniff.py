# BLE sniffer for PiIrr- devices using bleak (Windows friendly)
# Usage:
#   pip install bleak
#   python tools/ble_sniff.py
# Optional:
#   set NAME_PREFIX=PiIrr-
#   set COMPANY_ID=0xFFFF

import asyncio
import os
from datetime import datetime
from bleak import BleakScanner

NAME_PREFIX = os.environ.get("NAME_PREFIX", "PiIrr-")
COMPANY_ID = int(os.environ.get("COMPANY_ID", "0xFFFF"), 16)


def log(*args):
    ts = datetime.utcnow().isoformat()
    print(f"[BLE {ts}]", *args, flush=True)


def parse_ascii_or_binary(mfg: bytes):
    humidity = None
    t_ms = None
    try:
        s = mfg.decode("utf-8", errors="ignore").lower()
        import re
        h = re.search(r"(?:h|humidity)\s*[:=]\s*([0-9]+(?:\.[0-9]+)?)", s)
        if h:
            humidity = float(h.group(1))
        t = re.search(r"(?:\bt\b|pump_?time(?:ms)?)\s*[:=]\s*([0-9]+)", s)
        if t:
            t_ms = int(t.group(1))
    except Exception:
        pass

    if humidity is None or t_ms is None:
        if len(mfg) >= 6:
            hraw = mfg[0] | (mfg[1] << 8)
            humidity = hraw / 100.0 if humidity is None else humidity
            traw = mfg[2] | (mfg[3] << 8) | (mfg[4] << 16) | (mfg[5] << 24)
            t_ms = traw if t_ms is None else t_ms
    return humidity, t_ms


async def main():
    log("Starting scan...")

    def detection_callback(device, advertisement_data):
        name = advertisement_data.local_name or ""
        if NAME_PREFIX and not name.startswith(NAME_PREFIX):
            return
        # bleak exposes manufacturer_data as dict[int, bytes]
        md = advertisement_data.manufacturer_data or {}
        has_company = COMPANY_ID in md
        if not has_company and not md:
            return
        payload = md.get(COMPANY_ID)
        if not payload:
            # If not keyed, try first entry anyway
            if md:
                payload = next(iter(md.values()))
        if not payload:
            return
        humidity, t_ms = parse_ascii_or_binary(payload)
        pump = "ON" if (t_ms and t_ms > 0) else "OFF"
        log(f"Device={name} RSSI={advertisement_data.rssi}")
        if humidity is not None:
            log(f"  humidity={humidity}")
        if t_ms is not None:
            log(f"  t_ms={t_ms} -> pump={pump}")

    scanner = BleakScanner(detection_callback)
    await scanner.start()
    try:
        # run forever (Ctrl+C to stop)
        while True:
            await asyncio.sleep(5)
    except KeyboardInterrupt:
        pass
    finally:
        await scanner.stop()


if __name__ == "__main__":
    asyncio.run(main())
