import 'package:flutter/material.dart';
import 'package:application/screens/zone_detail_screen.dart';
import 'package:application/screens/add_zone_screen.dart';
import 'package:application/screens/settings_screen.dart';
import 'package:application/widgets/weather_card.dart';
import 'package:application/widgets/zone_card.dart';
import 'package:application/services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> zones = [];
  bool isLoading = true;
  final Set<String> _togglingIds = {};

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  Future<void> _loadZones() async {
    setState(() => isLoading = true);
    final loadedZones = await ApiService.getZones();
    setState(() {
      zones = loadedZones;
      isLoading = false;
    });
  }

  Future<void> _confirmDeleteZone(String zoneId, String zoneName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المنطقة'),
        content: Text(
          'هل تريد حذف "$zoneName"؟ لا يمكن التراجع عن هذا الإجراء.',
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
      ),
    );

    if (confirmed != true) return;

    // Optional small progress overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
      ),
    );

    final success = await ApiService.deleteZone(zoneId);

    if (mounted) Navigator.of(context).pop();

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف "$zoneName"'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadZones();
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

  Future<void> _toggleZone(String zoneId) async {
    // Optimistic UI update: flip wateringStatus.isRunning locally
    final index = zones.indexWhere((z) => z['_id'] == zoneId);
    if (index == -1) return;

    final current = zones[index]['wateringStatus']?['isRunning'] == true;
    setState(() {
      _togglingIds.add(zoneId);
      zones[index]['wateringStatus'] =
          (zones[index]['wateringStatus'] ?? <String, dynamic>{});
      zones[index]['wateringStatus']['isRunning'] = !current;
    });

    final success = await ApiService.toggleWatering(zoneId);

    if (!mounted) return;

    setState(() {
      _togglingIds.remove(zoneId);
      if (!success) {
        // Revert on failure
        zones[index]['wateringStatus']['isRunning'] = current;
      }
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تغيير حالة المضخة'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/aquagrow_logo.png',
              width: 32,
              height: 32,
            ),
            const SizedBox(width: 12),
            const Text('مزرعتي', style: TextStyle(fontSize: 22)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, size: 28),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WeatherCard(),
            const SizedBox(height: 24),
            const Text(
              'مناطق المزرعة',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
                ),
              )
            else if (zones.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.grass_outlined,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد مناطق',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'تواصل مع الدعم لإضافة مناطق',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: zones.map((zone) {
                  // Use wateringStatus.isRunning as the source of truth for button and badge
                  final isRunning =
                      (zone['wateringStatus'] != null &&
                      (zone['wateringStatus']['isRunning'] == true));
                  final moisture =
                      (zone['moistureLevel'] ?? zone['currentMoisture'] ?? 0)
                          .toDouble();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: ZoneCard(
                      zoneName: zone['name'] ?? 'منطقة غير معروفة',
                      status: isRunning ? 'Active' : 'Inactive',
                      moistureLevel: moisture,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ZoneDetailScreen(
                              zoneName: zone['name'] ?? 'منطقة غير معروفة',
                              zoneId: zone['_id'],
                            ),
                          ),
                        ).then((_) => _loadZones());
                      },
                      onDelete: () {
                        final id = zone['_id'];
                        if (id != null) {
                          _confirmDeleteZone(id, zone['name'] ?? 'منطقة');
                        }
                      },
                      onToggle: () {
                        final id = zone['_id'];
                        if (id != null) {
                          _toggleZone(id);
                        }
                      },
                      isToggling: _togglingIds.contains(zone['_id']),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddZoneScreen()),
          );
          if (added == true) {
            _loadZones();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('إضافة منطقة'),
      ),
    );
  }
}
