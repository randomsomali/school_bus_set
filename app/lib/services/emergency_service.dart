import 'package:app/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:location/location.dart';
import 'dart:convert';

class EmergencyService {
  static final EmergencyService _instance = EmergencyService._internal();
  final ApiClient _apiClient = ApiClient();

  // Singleton factory
  factory EmergencyService() => _instance;

  EmergencyService._internal();

  // Get client's emergencies
  Future<Map<String, dynamic>> getClientEmergencies() async {
    try {
      final response = await _apiClient.request(
        method: 'GET',
        path: '/emergencies/my',
      );
      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to load emergencies: $e',
        'data': [],
      };
    }
  }

  // Get emergency statistics
  Future<Map<String, dynamic>> getEmergencyStatistics() async {
    try {
      final response = await _apiClient.request(
        method: 'GET',
        path: '/emergencies/my/stats',
      );
      return response;
    } catch (e) {
      // If endpoint doesn't exist or fails, try to calculate stats from emergencies
      try {
        final emergenciesResponse = await getClientEmergencies();
        if (emergenciesResponse['success'] &&
            emergenciesResponse['data'] != null) {
          final List<dynamic> emergencies = emergenciesResponse['data'];

          int pending = 0;
          int assigned = 0;
          int completed = 0;

          for (var emergency in emergencies) {
            switch (emergency['status']) {
              case 'pending':
                pending++;
                break;
              case 'assigned':
                assigned++;
                break;
              case 'completed':
                completed++;
                break;
            }
          }

          return {
            'success': true,
            'data': {
              'total': emergencies.length,
              'pending': pending,
              'assigned': assigned,
              'completed': completed,
            }
          };
        } else {
          return {
            'success': false,
            'message': 'Failed to calculate statistics',
            'data': {
              'total': 0,
              'pending': 0,
              'assigned': 0,
              'completed': 0,
            }
          };
        }
      } catch (e) {
        return {
          'success': false,
          'message': 'Failed to load statistics: $e',
          'data': {
            'total': 0,
            'pending': 0,
            'assigned': 0,
            'completed': 0,
          }
        };
      }
    }
  }

  // Create new emergency
  Future<Map<String, dynamic>> reportEmergency({
    required String description,
    required String level,
    String? address,
    double? lat,
    double? lng,
  }) async {
    try {
      // Get client data from SharedPreferences for authentication
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('userData');

      if (userDataString == null) {
        return {
          'success': false,
          'message': 'User data not found. Please log in again.',
        };
      }

      final userData = jsonDecode(userDataString) as Map<String, dynamic>;

      // Debug: Print user data to check structure
      print('DEBUG - User data from SharedPreferences: $userData');

      // The ID could be stored under different properties depending on the user type
      final clientId = userData['id'] ?? userData['client_id'];
      if (clientId == null) {
        return {
          'success': false,
          'message': 'Client ID not found. Please log in again.',
        };
      }

      print('DEBUG - Using client ID: $clientId');

      // Create the request data with provided values
      final Map<String, dynamic> data = {
        'client_id': clientId,
        'description': description,
        'level': level,
      };

      // Use provided location data if available
      if (address != null) data['address'] = address;
      if (lat != null) data['lat'] = lat;
      if (lng != null) data['lng'] = lng;

      // If no location is provided (null values), try to get current location first
      if (lat == null || lng == null) {
        // Try to get current device location
        print('DEBUG - Location missing, attempting to get current location');
        final locationResult = await getCurrentLocation();
        if (locationResult['success'] && locationResult['data'] != null) {
          data['lat'] = locationResult['data']['lat'];
          data['lng'] = locationResult['data']['lng'];
          print(
              'DEBUG - Using current device location: ${data['lat']}, ${data['lng']}');
        }
        // If location service fails, fall back to user profile data
        else if (userData['lat'] != null && userData['lng'] != null) {
          data['lat'] = double.tryParse(userData['lat'].toString());
          data['lng'] = double.tryParse(userData['lng'].toString());
          print(
              'DEBUG - Falling back to user profile location data: ${data['lat']}, ${data['lng']}');
        }
      }

      // If address is still missing, use from user data
      if (!data.containsKey('address') && userData['address'] != null) {
        data['address'] = userData['address'];
        print('DEBUG - Using address from user profile: ${data['address']}');
      }

      // Debug: Print request data
      print('DEBUG - Emergency report request data: $data');

      final response = await _apiClient.request(
        method: 'POST',
        path: '/emergencies/report',
        data: data,
      );

      // Debug: Print response
      print('DEBUG - Emergency report response: $response');

      return response;
    } catch (e) {
      print('DEBUG - Emergency report error: $e');
      return {
        'success': false,
        'message': 'Failed to report emergency: $e',
      };
    }
  }

  // Get current location
  Future<Map<String, dynamic>> getCurrentLocation() async {
    try {
      Location location = Location();
      bool serviceEnabled;
      PermissionStatus permissionGranted;
      LocationData locationData;

      // Check if location service is enabled
      serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          return {
            'success': false,
            'message': 'Location services are disabled',
          };
        }
      }

      // Check location permission
      permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          return {
            'success': false,
            'message': 'Location permission not granted',
          };
        }
      }

      // Get current location
      locationData = await location.getLocation();

      return {
        'success': true,
        'data': {
          'lat': locationData.latitude,
          'lng': locationData.longitude,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get location: $e',
      };
    }
  }

  // Helper method to populate location data if missing
  Future<bool> _populateLocationData() async {
    try {
      final locationResult = await getCurrentLocation();
      return locationResult['success'];
    } catch (e) {
      return false;
    }
  }
}
