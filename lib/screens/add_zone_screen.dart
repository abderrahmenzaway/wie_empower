import 'package:flutter/material.dart';
import 'package:application/services/api_service.dart';

class AddZoneScreen extends StatefulWidget {
  const AddZoneScreen({super.key});

  @override
  State<AddZoneScreen> createState() => _AddZoneScreenState();
}

class _AddZoneScreenState extends State<AddZoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  double _threshold = 60;
  bool _isSubmitting = false;
  String _plantType = 'خضار';

  final List<Map<String, dynamic>> _plantOptions = const [
    {'label': 'خضار', 'icon': Icons.local_florist},
    {'label': 'أشجار', 'icon': Icons.park},
    {'label': 'زهور', 'icon': Icons.filter_vintage},
    {'label': 'حبوب', 'icon': Icons.grass},
    {'label': 'أخرى', 'icon': Icons.spa},
  ];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final payload = {
      'name': _nameController.text.trim(),
      'moistureThreshold': _threshold.toInt(),
      'plantType': _plantType,
    };

    final res = await ApiService.createZone(payload);

    setState(() => _isSubmitting = false);

    if (res['success'] == true) {
      if (mounted) Navigator.pop(context, true);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'فشل إنشاء المنطقة'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة منطقة')),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم المنطقة',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.grass),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                ),
                const SizedBox(height: 20),
                const Text(
                  'نوع النبات',
                  style: TextStyle(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    itemBuilder: (context, index) {
                      final item = _plantOptions[index];
                      final selected = _plantType == item['label'];
                      return GestureDetector(
                        onTap: () => setState(
                          () => _plantType = item['label'] as String,
                        ),
                        child: Container(
                          width: 120,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: selected ? Colors.green : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green, width: 2),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                item['icon'] as IconData,
                                color: selected ? Colors.white : Colors.green,
                                size: 28,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item['label'] as String,
                                style: TextStyle(
                                  color: selected ? Colors.white : Colors.green,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemCount: _plantOptions.length,
                  ),
                ),
                // Removed moisture threshold slider from UI as requested.
                // We still keep an internal default threshold value to send to backend.
                const Spacer(),
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: const Icon(Icons.check),
                    label: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('حفظ', style: TextStyle(fontSize: 20)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
