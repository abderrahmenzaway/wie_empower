import 'package:flutter/material.dart';
import 'dart:async';
import 'package:application/screens/signin_screen.dart';
import 'package:application/services/bluetooth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Start BLE scanning for devices named like "PiIrr-<type>" in the background
    BluetoothService.instance.autoConnect(namePrefix: 'PiIrr-');
    Timer(
      const Duration(seconds: 3),
      () => Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (BuildContext context) => const SignInScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/aquagrow_logo.png',
              width: 200,
              height: 200,
            ),
            const SizedBox(height: 24),
            const Text(
              'HYDRAFARM',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Smart Farm Irrigation',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
