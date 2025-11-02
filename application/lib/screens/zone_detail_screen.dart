import 'package:flutter/material.dart';
import 'dart:async';
import 'package:application/services/api_service.dart';
import 'package:application/services/bluetooth_service.dart';

class ZoneDetailScreen extends StatefulWidget {
  final String zoneName;
  final String? zoneId;

  const ZoneDetailScreen({super.key, required this.zoneName, this.zoneId});

  @override
  State<ZoneDetailScreen> createState() => _ZoneDetailScreenState();
}

class _ZoneDetailScreenState extends State<ZoneDetailScreen> {
  bool isWatering = false;
  double moistureLevel = 65;
  bool isLoading = true;
  String lastWatered = 'منذ ساعتين';
  bool pumpActive = false;

  // Timer for watering simulation
  Timer? _wateringTimer;
  int _elapsedSeconds = 0;
  double _initialMoisture = 65;

  // Bluetooth subscriptions
  StreamSubscription<double>? _humSub;
  StreamSubscription<bool>? _pumpSub;

  @override
  void initState() {
    super.initState();
    if (widget.zoneId != null) {
      _loadZoneData();
    } else {
      setState(() => isLoading = false);
    }

    // Listen for Bluetooth updates (humidity and pump state)
    _humSub = BluetoothService.instance.humidityStream.listen((h) {
      if (!mounted) return;
      setState(() => moistureLevel = h);
    });
    _pumpSub = BluetoothService.instance.pumpStateStream.listen((on) {
      if (!mounted) return;
      setState(() {
        pumpActive = on;
        isWatering = on;
        if (on) lastWatered = 'الآن';
      });
    });
  }

  Future<void> _loadZoneData() async {
    if (widget.zoneId == null) return;

    setState(() => isLoading = true);
    final zoneData = await ApiService.getZone(widget.zoneId!);

    if (zoneData != null && mounted) {
      setState(() {
        isWatering = (zoneData['wateringStatus']?['isRunning'] ?? false);
        moistureLevel = (zoneData['moistureLevel'] ?? 65).toDouble();
        pumpActive =
            (zoneData['connectedPump'] != null) &&
            (zoneData['connectedPump']['status'] == 'Active');

        // Calculate last watered time
        if (zoneData['wateringStatus']?['lastWatered'] != null) {
          final lastWateredDate = DateTime.parse(
            zoneData['wateringStatus']['lastWatered'],
          );
          final difference = DateTime.now().difference(lastWateredDate);

          if (difference.inHours < 1) {
            lastWatered = 'منذ ${difference.inMinutes} دقيقة';
          } else if (difference.inHours < 24) {
            lastWatered = 'منذ ${difference.inHours} ساعة';
          } else {
            lastWatered = 'منذ ${difference.inDays} يوم';
          }
        }

        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  void _startWateringSimulation() {
    // Save initial moisture level
    _initialMoisture = moistureLevel;
    _elapsedSeconds = 0;

    // Start timer that updates every second
    _wateringTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _elapsedSeconds++;
        // Increase moisture by ~1% every 3 seconds (simulate watering effect)
        // Max increase is 30% over time
        double increase = (_elapsedSeconds / 3).clamp(0, 30);
        moistureLevel = (_initialMoisture + increase).clamp(0, 100);

        // Send update to backend every 5 seconds
        if (_elapsedSeconds % 5 == 0 && widget.zoneId != null) {
          ApiService.updateZone(widget.zoneId!, {
            'moistureLevel': moistureLevel,
          });
        }
      });
    });
  }

  void _stopWateringSimulation() {
    _wateringTimer?.cancel();
    _wateringTimer = null;
    _elapsedSeconds = 0;

    // Send final moisture level to backend
    if (widget.zoneId != null) {
      ApiService.updateZone(widget.zoneId!, {'moistureLevel': moistureLevel});
    }
  }

  String _formatElapsedTime() {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleWatering() async {
    // Optimistic UI: toggle immediately (no page refresh), then confirm with server
    final newState = !isWatering;

    setState(() {
      isWatering = newState;
      // reflect on the pump card instantly
      pumpActive = newState;
      // optional: update last watered label when starting
      if (newState) {
        lastWatered = 'الآن';
        _startWateringSimulation();
      } else {
        _stopWateringSimulation();
      }
    });

    // Send Bluetooth manual command immediately
    unawaited(BluetoothService.instance.sendPumpState(newState));

    if (widget.zoneId == null) return; // demo only

    final success = await ApiService.toggleWatering(widget.zoneId!);

    if (!success && mounted) {
      // Revert on failure
      setState(() {
        isWatering = !newState;
        pumpActive = !newState;
        _stopWateringSimulation();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تغيير حالة الري'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newState ? 'تم بدء الري' : 'تم إيقاف الري'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _wateringTimer?.cancel();
    _humSub?.cancel();
    _pumpSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.zoneName,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
        actions: [
          if (widget.zoneId != null)
            IconButton(
              tooltip: 'حذف',
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
                size: 26,
              ),
              onPressed: _confirmAndDelete,
            ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Soil Moisture Card
                    _buildCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.water_drop,
                                    color: Colors.blue,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'رطوبة التربة',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'مستوى جيد',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Text(
                              '${moistureLevel.toInt()}%',
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              moistureLevel >= 60
                                  ? 'النباتات لديها ماء كافٍ'
                                  : moistureLevel >= 40
                                  ? 'مستوى الرطوبة متوسط'
                                  : 'تحتاج إلى الري قريبًا',
                              style: TextStyle(
                                fontSize: 16,
                                color: moistureLevel >= 60
                                    ? Colors.green
                                    : moistureLevel >= 40
                                    ? Colors.orange
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Watering Control Card
                    _buildCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            const Text(
                              'التحكم في الري',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                color: isWatering
                                    ? Colors.green.shade50
                                    : Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.power_settings_new,
                                color: isWatering ? Colors.green : Colors.grey,
                                size: 70,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              isWatering ? 'الري يعمل' : 'الري متوقف',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: isWatering ? Colors.green : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: ElevatedButton(
                                onPressed: _toggleWatering,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isWatering
                                      ? Colors.red
                                      : Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  isWatering ? 'أوقف الري' : 'ابدأ الري',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            if (isWatering && _elapsedSeconds > 0) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.timer,
                                      color: Colors.blue.shade700,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _formatElapsedTime(),
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Pump Status Card
                    _buildCard(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: pumpActive
                                    ? Colors.green.shade50
                                    : Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.published_with_changes,
                                color: pumpActive ? Colors.green : Colors.grey,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'حالة المضخة',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  pumpActive ? 'شغالة' : 'متوقفة',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: pumpActive
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Last Watered Card
                    _buildCard(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.cyan.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.history,
                                color: Colors.cyan,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'آخر ري',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  lastWatered,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Future<void> _confirmAndDelete() async {
    if (widget.zoneId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('حذف المنطقة'),
          content: const Text(
            'هل أنت متأكد أنك تريد حذف هذه المنطقة؟ هذا الإجراء لا يمكن التراجع عنه.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('حذف', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    // Show a small progress indicator while deleting
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
      ),
    );

    final success = await ApiService.deleteZone(widget.zoneId!);

    if (mounted) Navigator.of(context).pop(); // close progress

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف المنطقة'),
            backgroundColor: Colors.green,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(true); // pop detail, flag refresh
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر حذف المنطقة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
