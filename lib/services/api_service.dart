import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'http://localhost:5000/api';
  static String? _token;

  // Authentication
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Login failed'};
      }
    } catch (e) {
      print('Login error: $e');
      return {'success': false, 'message': 'Connection error'};
    }
  }

  // Profile
  static Future<Map<String, dynamic>> getProfile() async {
    if (_token == null) return {'success': false, 'message': 'Not logged in'};
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['user'] ?? data};
      }
      return {'success': false, 'message': response.body};
    } catch (e) {
      print('Get profile error: $e');
      return {'success': false, 'message': 'Connection error'};
    }
  }

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> profile,
  ) async {
    if (_token == null) return {'success': false, 'message': 'Not logged in'};
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode(profile),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['user'] ?? data};
      }
      return {'success': false, 'message': response.body};
    } catch (e) {
      print('Update profile error: $e');
      return {'success': false, 'message': 'Connection error'};
    }
  }

  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Registration failed'};
      }
    } catch (e) {
      print('Register error: $e');
      return {'success': false, 'message': 'Connection error'};
    }
  }

  // Zones
  static Future<List<dynamic>> getZones() async {
    if (_token == null) return [];
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/zones'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['zones'] ?? [];
      }
      return [];
    } catch (e) {
      print('Get zones error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getZone(String id) async {
    if (_token == null) return null;
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/zones/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['zone'];
      }
      return null;
    } catch (e) {
      print('Get zone error: $e');
      return null;
    }
  }

  static Future<bool> toggleWatering(String zoneId) async {
    if (_token == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/zones/$zoneId/toggle'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) return true;
      return false;
    } catch (e) {
      print('Toggle watering error: $e');
      return false;
    }
  }

  static Future<bool> updateZone(
    String zoneId,
    Map<String, dynamic> data,
  ) async {
    if (_token == null) return false;
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/zones/$zoneId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode(data),
      );
      if (response.statusCode == 200) return true;
      return false;
    } catch (e) {
      print('Update zone error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> createZone(
    Map<String, dynamic> zoneData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/zones'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode(zoneData),
      );

      if (response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false};
    } catch (e) {
      print('Create zone error: $e');
      return {'success': false};
    }
  }

  static Future<bool> deleteZone(String zoneId) async {
    if (_token == null) return false;
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/zones/$zoneId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      // Accept 200 OK or 204 No Content as success
      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      }
      return false;
    } catch (e) {
      print('Delete zone error: $e');
      return false;
    }
  }

  // Dashboard Stats
  static Future<List<dynamic>> getDashboardStats() async {
    if (_token == null) return [];
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/dashboard/stats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return [];
      }
    } catch (e) {
      print('Error getting dashboard stats: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> getSettings() async {
    if (_token == null) return {};
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/settings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      print('Get settings error: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> updateSettings(
    Map<String, dynamic> settings,
  ) async {
    if (_token == null) return {'success': false, 'message': 'Not logged in'};
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/settings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode(settings),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Failed to update settings: ${response.body}',
        };
      }
    } catch (e) {
      print('Error updating settings: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }

  static void logout() {
    _token = null;
  }

  static bool get isLoggedIn => _token != null;

  static String? get token => _token;
}
