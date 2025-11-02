import 'package:flutter/material.dart';
import 'package:application/services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final res = await ApiService.getProfile();
    if (mounted) {
      if (res['success'] == true) {
        final u = res['data'] as Map<String, dynamic>;
        _nameController.text = (u['name'] ?? '').toString();
        _emailController.text = (u['email'] ?? '').toString();
        _phoneController.text = (u['phone'] ?? '').toString();
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final payload = {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
    };
    final res = await ApiService.updateProfile(payload);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ البيانات'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر حفظ البيانات'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildField(
                      label: 'الاسم',
                      controller: _nameController,
                      icon: Icons.person,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'الاسم مطلوب'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      label: 'البريد الإلكتروني',
                      controller: _emailController,
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'البريد مطلوب'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      label: 'الهاتف',
                      controller: _phoneController,
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: const Icon(Icons.save),
                        label: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('حفظ'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
