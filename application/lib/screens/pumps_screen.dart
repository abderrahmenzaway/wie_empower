import 'package:flutter/material.dart';

class PumpsScreen extends StatelessWidget {
  const PumpsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zone 1 Pumps')),
      body: ListView.builder(
        itemCount: 1,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.power),
              title: const Text('Main Irrigation Pump'),
              subtitle: const Text('Active - Online'),
              trailing: Switch(value: true, onChanged: (val) {}),
            ),
          );
        },
      ),
    );
  }
}
