/*
  BLE Sniffer for PiIrr- devices
  - Prints humidity and pump_time_ms from Manufacturer Data (companyId 0xFFFF)
  - Optionally connects and reads GATT characteristics if you extend it later

  Usage:
    npm install
    npm run ble:sniff

  Env vars (optional):
    NAME_PREFIX=PiIrr-        # filter by name prefix
    COMPANY_ID=0xFFFF         # manufacturer company id in hex
*/

console.log('[ble_sniff.js] This tool is deprecated. Use the Flutter app UI for visualization.');
console.log('Note: The Node BLE dependency was removed to avoid Windows build tooling issues.');
process.exit(0);
