import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:application/services/api_service.dart';
import 'package:application/screens/signin_screen.dart';
import 'package:application/screens/profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String temperatureUnit = '°C';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await ApiService.getSettings();
    if (settings.isNotEmpty && mounted) {
      setState(() {
        temperatureUnit = settings['temperatureUnit'] ?? '°C';
      });
      // Enforce Celsius only in backend as well
      if ((settings['temperatureUnit'] ?? '°C') != '°C') {
        await ApiService.updateSettings({'temperatureUnit': '°C'});
      }
    }
  }

  // Temperature unit is forced to °C globally; no interactive toggle needed

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الخروج'),
        content: const Text('هل تريد تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      ApiService.logout();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const SignInScreen()),
        (route) => false,
      );
    }
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
        title: const Text(
          'الإعدادات',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(0),
        children: [
          // User Account Section
          Container(
            color: const Color(0xFFE8F5E9),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: const Text(
              'الحساب',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B5E20),
              ),
            ),
          ),
          _buildCard(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final changed = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
                if (changed == true && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تحديث الملف الشخصي')),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.blue,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الملف الشخصي',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'عرض وتعديل بياناتك',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 20),
                  ],
                ),
              ),
            ),
          ),

          // Preferences Section
          Container(
            color: const Color(0xFFE8F5E9),
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
            child: const Text(
              'التفضيلات',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B5E20),
              ),
            ),
          ),
          _buildKeyValueItem(
            icon: Icons.thermostat_outlined,
            iconColor: Colors.orange,
            title: 'وحدة الحرارة',
            value: '°C',
          ),
          // اللغة: تمت إزالتها لتكون الواجهة بالعربية فقط

          // Help Section
          Container(
            color: const Color(0xFFE8F5E9),
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
            child: const Text(
              'المساعدة والدعم',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B5E20),
              ),
            ),
          ),
          _buildMenuItem(
            icon: Icons.phone_outlined,
            iconColor: Colors.green,
            title: 'اتصل بالدعم',
            onTap: _callSupport,
          ),

          // Action Buttons
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: OutlinedButton.icon(
              onPressed: _handleSignOut,
              icon: const Icon(Icons.logout, color: Colors.green, size: 24),
              label: const Text(
                'تسجيل الخروج',
                style: TextStyle(color: Colors.green, fontSize: 18),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.green, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ),
          const SizedBox(height: 40),
          // Logo and Branding
          Center(
            child: Column(
              children: [
                Image.asset(
                  'assets/images/aquagrow_logo.png',
                  width: 60,
                  height: 60,
                ),
                const SizedBox(height: 12),
                const Text(
                  'مزرعتي',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'نظام ري ذكي للمزرعة',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return _buildCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icon, color: iconColor, size: 28),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 17),
        ),
        subtitle: subtitle != null
            ? Text(subtitle, style: const TextStyle(fontSize: 15))
            : null,
        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
        onTap: onTap,
      ),
    );
  }

  Widget _buildKeyValueItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return _buildCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Icon(icon, color: iconColor, size: 28),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 17),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _callSupport() async {
    const phoneNumber = '+21671256331';
    // محاولة الاتصال عبر نسخ الرقم (آمن لكل المنصات).
    // ملاحظة: على الهاتف، النقر على روابط "tel:" يفتح الاتصال مباشرة.
    // يمكننا إضافة الاتصال المباشر لاحقًا إن لزم.
    await Clipboard.setData(const ClipboardData(text: phoneNumber));
    if (mounted) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'اتصل بالدعم',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SelectableText(
                phoneNumber,
                style: const TextStyle(fontSize: 20, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              const Text('تم نسخ الرقم تلقائيًا. استخدمه في تطبيق الاتصال.'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('حسناً'),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
