import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// BLE-based BluetoothService
/// - Scans for a device advertising name like "PiIrr-<type>" and/or manufacturer data company 0xFFFF.
/// - Parses Manufacturer Data payload every ~2s to extract humidity and t (pump_time_ms).
/// - t == 0  => ensure pump OFF; t > 0 => turn pump ON now and OFF after t ms.
/// - Exposes streams: humidityStream, pumpStateStream.
/// - Sends manual commands "pump.state(on/off)" via a configurable GATT write characteristic.
class BluetoothService {
  BluetoothService._();
  static final BluetoothService instance = BluetoothService._();

  // Configure GATT endpoints (replace these with the laptop's actual UUIDs)
  // Data service containing humidity / pump_state / pump_time_ms
  static const String dataServiceUuid = '0000ffaa-0000-1000-8000-00805f9b34fb';
  static const String humidityCharUuid = '0000faa1-0000-1000-8000-00805f9b34fb';
  static const String pumpStateCharUuid =
      '0000faa2-0000-1000-8000-00805f9b34fb';
  static const String pumpTimeCharUuid = '0000faa3-0000-1000-8000-00805f9b34fb';
  // Control service/characteristic for manual commands
  static const String controlServiceUuid =
      '0000ffff-0000-1000-8000-00805f9b34fb';
  static const String controlCharUuid = '0000ff01-0000-1000-8000-00805f9b34fb';

  final _humidityCtrl = StreamController<double>.broadcast();
  final _pumpStateCtrl = StreamController<bool>.broadcast();
  Stream<double> get humidityStream => _humidityCtrl.stream;
  Stream<bool> get pumpStateStream => _pumpStateCtrl.stream;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _controlChar;
  BluetoothCharacteristic? _humidityChar;
  BluetoothCharacteristic? _pumpStateChar;
  BluetoothCharacteristic? _pumpTimeChar;
  bool _pumpOn = false;
  Timer? _autoOffTimer;
  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _scanning = false;
  bool _initializing = false;
  // Logging removed as per request; visualization happens in-app only.

  Future<void> _ensurePermissions() async {
    if (!Platform.isAndroid) return;
    final perms = <Permission>[
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse, // for < Android 12
    ];
    await perms.request();
  }

  /// Start BLE scanning. It will auto-parse manufacturer data with companyId 0xFFFF
  /// and handle t/humidity updates. Optionally filters by name prefix.
  Future<void> startScan({String namePrefix = 'PiIrr-'}) async {
    if (kIsWeb) return; // BLE Web not supported in this app
    if (_scanning) return;
    await _ensurePermissions();

    _scanning = true;
    // Start scan
    FlutterBluePlus.startScan(timeout: const Duration(minutes: 10));
    _scanSub = FlutterBluePlus.scanResults.listen(
      (results) {
        for (final r in results) {
          final name = r.device.platformName;
          final md =
              r.advertisementData.manufacturerData; // Map<int, List<int>>

          if (namePrefix.isNotEmpty && !(name).startsWith(namePrefix)) {
            continue;
          }
          if (md.containsKey(0xFFFF)) {
            final bytes = md[0xFFFF]!;
            _handleManufacturerPayload(bytes);
            _device ??= r.device;
            // Attempt to connect & subscribe once we found a matching device
            if (!_initializing) {
              _connectAndInit(r.device);
            }
          }
        }
      },
      onError: (e) {
        // silent
        _scanning = false;
      },
      onDone: () {
        _scanning = false;
      },
    );
  }

  Future<void> stopScan() async {
    await _scanSub?.cancel();
    _scanSub = null;
    _scanning = false;
    try {
      FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  void _handleManufacturerPayload(List<int> bytes) {
    try {
      // Try ASCII first: e.g., "H:58.2;T:5000"
      final asString = utf8.decode(bytes, allowMalformed: true);
      double? humidity;
      int? tMs;

      final lower = asString.toLowerCase();
      final hMatch =
          RegExp(r'h\s*[:=]\s*([0-9]+(?:\.[0-9]+)?)').firstMatch(lower) ??
          RegExp(r'humidity\s*[:=]\s*([0-9]+(?:\.[0-9]+)?)').firstMatch(lower);
      final tMatch =
          RegExp(r'\bt\s*[:=]\s*([0-9]+)').firstMatch(lower) ??
          RegExp(r'(pump_)?time(ms)?\s*[:=]\s*([0-9]+)').firstMatch(lower);

      if (hMatch != null) {
        final g = hMatch.groupCount >= 1 ? hMatch.group(1) : null;
        if (g != null) humidity = double.tryParse(g);
      }
      if (tMatch != null) {
        // last group captures the number
        final g = tMatch.group(tMatch.groupCount);
        if (g != null) tMs = int.tryParse(g);
      }

      // If ASCII parse failed, try binary format fallback:
      if (humidity == null || tMs == null) {
        // Assume: [uint16 humidity_x100][uint32 t_ms] little-endian = 2 + 4 = 6 bytes
        if (bytes.length >= 6) {
          final hRaw = bytes[0] | (bytes[1] << 8);
          humidity ??= hRaw / 100.0;
          final tRaw =
              bytes[2] | (bytes[3] << 8) | (bytes[4] << 16) | (bytes[5] << 24);
          tMs ??= tRaw;
        }
      }

      if (humidity != null) {
        _humidityCtrl.add(humidity);
      }
      if (tMs != null) {
        _handleTValue(tMs);
      }
    } catch (e) {
      // silent
    }
  }

  Future<void> _connectAndInit(BluetoothDevice d) async {
    if (_initializing) return;
    _initializing = true;
    try {
      // Stop scanning to save power; we already found our device
      await stopScan();
      await d.connect(timeout: const Duration(seconds: 8));

      _device = d;
      // Discover services and find required characteristics
      final services = await d.discoverServices();
      for (final s in services) {
        final suuid = s.uuid.toString().toLowerCase();
        if (suuid == dataServiceUuid) {
          for (final c in s.characteristics) {
            final cuuid = c.uuid.toString().toLowerCase();
            if (cuuid == humidityCharUuid) _humidityChar = c;
            if (cuuid == pumpStateCharUuid) _pumpStateChar = c;
            if (cuuid == pumpTimeCharUuid) _pumpTimeChar = c;
          }
        }
        if (suuid == controlServiceUuid) {
          for (final c in s.characteristics) {
            if (c.uuid.toString().toLowerCase() == controlCharUuid) {
              _controlChar = c;
            }
          }
        }
      }

      // Subscribe to notifications if available
      Future<void> tryNotify(
        BluetoothCharacteristic? c,
        void Function(List<int>) handler,
      ) async {
        if (c == null) return;
        try {
          await c.setNotifyValue(true);
          c.onValueReceived.listen(
            handler,
            onError: (e) {
              // silent
            },
          );
          // Also do an initial read
          final v = await c.read();
          handler(v);
        } catch (e) {
          // silent
        }
      }

      await tryNotify(_humidityChar, (v) {
        final h = _parseHumidityBytes(v);
        if (h != null) {
          _humidityCtrl.add(h);
        }
      });

      await tryNotify(_pumpStateChar, (v) {
        final s = _parseAscii(v).toUpperCase();
        if (s == 'ON') {
          _setPumpState(true, source: 'char:pump_state');
        } else if (s == 'OFF') {
          _setPumpState(false, source: 'char:pump_state');
        }
      });

      await tryNotify(_pumpTimeChar, (v) {
        final t = _parseInt(v);
        if (t != null) {
          _handleTValue(t);
        }
      });
    } catch (e) {
      // silent
    } finally {
      _initializing = false;
    }
  }

  String _parseAscii(List<int> v) {
    try {
      return utf8.decode(v, allowMalformed: true).trim();
    } catch (_) {
      return '';
    }
  }

  double? _parseHumidityBytes(List<int> bytes) {
    // Prefer ASCII double, else 2-byte uint16/100
    final s = _parseAscii(bytes);
    final d = double.tryParse(s);
    if (d != null) return d;
    if (bytes.length >= 2) {
      final raw = bytes[0] | (bytes[1] << 8);
      return raw / 100.0;
    }
    return null;
  }

  int? _parseInt(List<int> bytes) {
    final s = _parseAscii(bytes);
    final i = int.tryParse(s);
    if (i != null) return i;
    if (bytes.length >= 4) {
      return bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
    }
    return null;
  }

  void _handleTValue(int tMs) {
    _autoOffTimer?.cancel();
    if (tMs <= 0) {
      _setPumpState(false, source: 't=0');
      return;
    }
    _setPumpState(true, source: 't>0');
    _autoOffTimer = Timer(Duration(milliseconds: tMs), () {
      _setPumpState(false, source: 'auto-off');
    });
  }

  // Public API for manual user toggle
  Future<void> sendPumpState(bool on) async {
    await _writeControl(on ? 'pump.state(on)' : 'pump.state(off)');
    _setPumpState(on, source: 'manual');
  }

  void _setPumpState(bool on, {String? source}) {
    _pumpOn = on;
    _pumpStateCtrl.add(_pumpOn);
  }

  Future<void> _writeControl(String text) async {
    try {
      if (_device == null) return;
      // Connect if needed
      await _device!.connect(timeout: const Duration(seconds: 8));

      // Discover characteristic once
      _controlChar ??= await _findControlChar(_device!);
      if (_controlChar == null) {
        return;
      }

      final bytes = utf8.encode(text);
      await _controlChar!.write(bytes, withoutResponse: true);
    } catch (e) {
      // silent
    }
  }

  Future<BluetoothCharacteristic?> _findControlChar(BluetoothDevice d) async {
    final services = await d.discoverServices();
    for (final s in services) {
      if (s.uuid.toString().toLowerCase() == controlServiceUuid) {
        for (final c in s.characteristics) {
          if (c.uuid.toString().toLowerCase() == controlCharUuid) {
            return c;
          }
        }
      }
    }
    return null;
  }

  Future<void> autoConnect({String namePrefix = 'PiIrr-'}) async {
    // For compatibility with previous call sites; start scanning
    await startScan(namePrefix: namePrefix);
  }

  Future<void> dispose() async {
    await stopScan();
    _autoOffTimer?.cancel();
    await _humidityCtrl.close();
    await _pumpStateCtrl.close();
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
    _controlChar = null;
  }
}
