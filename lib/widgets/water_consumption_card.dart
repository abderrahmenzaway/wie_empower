import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class WaterConsumptionCard extends StatelessWidget {
  const WaterConsumptionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.water_drop, color: Colors.blue),
                SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Water Consumption',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('Total Usage', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '280 L',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Row(
              children: [
                Icon(Icons.arrow_downward, color: Colors.green, size: 16),
                Text(
                  '8% less than last period',
                  style: TextStyle(color: Colors.green),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Hourly'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                TextButton(onPressed: () {}, child: const Text('Daily')),
                TextButton(onPressed: () {}, child: const Text('Weekly')),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: const [
                        FlSpot(0, 90),
                        FlSpot(4, 120),
                        FlSpot(8, 270),
                        FlSpot(12, 340),
                        FlSpot(16, 250),
                        FlSpot(20, 180),
                      ],
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
