import 'package:flutter/material.dart';

class ZoneCard extends StatelessWidget {
  final String zoneName;
  final String status;
  final double moistureLevel;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onToggle;
  final bool isToggling;

  const ZoneCard({
    super.key,
    required this.zoneName,
    required this.status,
    required this.moistureLevel,
    required this.onTap,
    this.onDelete,
    this.onToggle,
    this.isToggling = false,
  });

  @override
  Widget build(BuildContext context) {
    bool isActive = status == 'Active';
    final statusLabel = isActive ? 'شغال' : 'متوقف';
    return InkWell(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    zoneName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    tooltip: 'حذف',
                    icon: const Icon(Icons.delete, color: Colors.red, size: 22),
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.green.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: isActive ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('الرطوبة'),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: moistureLevel / 100,
                backgroundColor: Colors.grey[300],
                color: Colors.blue,
              ),
              Text('${moistureLevel.toInt()}%'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isToggling ? null : onToggle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isActive ? Colors.white : Colors.green,
                    foregroundColor: isActive ? Colors.green : Colors.white,
                    side: const BorderSide(color: Colors.green),
                  ),
                  child: isToggling
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.green,
                          ),
                        )
                      : Text(isActive ? 'إيقاف' : 'تشغيل'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
