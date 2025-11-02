import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherApi {
  // Using a CORS proxy for web compatibility
  static const String apiKey = 'bd5e378503939ddaee76f12ad7a97608';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';

  static Future<Map<String, dynamic>> getCurrentWeather(String city) async {
    try {
      final url = '$_baseUrl/weather?q=$city&appid=$apiKey&units=metric';
      print('Fetching weather from: $url');

      final response = await http
          .get(Uri.parse(url), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Error response: ${response.body}');
        throw Exception('Failed to load weather data: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception in getCurrentWeather: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getForecast(String city) async {
    try {
      final url = '$_baseUrl/forecast?q=$city&appid=$apiKey&units=metric';

      final response = await http
          .get(Uri.parse(url), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load forecast data: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception in getForecast: $e');
      rethrow;
    }
  }
}
