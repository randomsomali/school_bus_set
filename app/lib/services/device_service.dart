import 'package:app/services/api_client.dart';

class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  final ApiClient _apiClient = ApiClient();

  // Singleton factory
  factory DeviceService() => _instance;

  DeviceService._internal();

  // Get current device data
  Future<Map<String, dynamic>> getDeviceData() async {
    try {
      final response = await _apiClient.request(
        method: 'GET',
        path: '/device',
      );

      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching device data: $e',
      };
    }
  }

  // Update device data (for ESP32)
  Future<Map<String, dynamic>> updateDeviceData({
    required double temperature,
    required double humidity,
    required int gasSensor,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _apiClient.request(
        method: 'PUT',
        path: '/device',
        data: {
          'temperature': temperature,
          'humidity': humidity,
          'gasSensor': gasSensor,
          'latitude': latitude,
          'longitude': longitude,
        },
      );

      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error updating device data: $e',
      };
    }
  }
}
