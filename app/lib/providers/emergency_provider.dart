import 'package:flutter/material.dart';
import 'package:app/services/emergency_service.dart';

class EmergencyProvider extends ChangeNotifier {
  final EmergencyService _emergencyService = EmergencyService();

  bool _isLoading = false;
  bool _isReporting = false;
  String? _error;

  List<Map<String, dynamic>> _emergencies = [];
  Map<String, dynamic> _statistics = {
    'total': 0,
    'pending': 0,
    'assigned': 0,
    'completed': 0,
  };

  // Getters
  bool get isLoading => _isLoading;
  bool get isReporting => _isReporting;
  String? get error => _error;
  List<Map<String, dynamic>> get emergencies => _emergencies;
  Map<String, dynamic> get statistics => _statistics;

  // Load client emergencies
  Future<void> loadEmergencies() async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _emergencyService.getClientEmergencies();

      if (response['success']) {
        _emergencies = List<Map<String, dynamic>>.from(response['data']);
      } else {
        _setError(response['message'] ?? 'Failed to load emergencies');
        _emergencies = [];
      }
    } catch (e) {
      _setError('Error loading emergencies: $e');
      _emergencies = [];
    } finally {
      _setLoading(false);
    }
  }

  // Load emergency statistics
  Future<void> loadStatistics() async {
    try {
      final response = await _emergencyService.getEmergencyStatistics();

      if (response['success']) {
        _statistics = Map<String, dynamic>.from(response['data']);
      } else {
        // Keep current statistics if fail
      }
    } catch (e) {
      // Silently fail, stats are not critical
    }
  }

  // Report a new emergency
  Future<Map<String, dynamic>> reportEmergency({
    required String description,
    required String level,
    String? address,
    double? lat,
    double? lng,
  }) async {
    _setReporting(true);
    _clearError();

    try {
      final response = await _emergencyService.reportEmergency(
        description: description,
        level: level,
        address: address,
        lat: lat,
        lng: lng,
      );

      if (response['success']) {
        // Refresh emergencies and statistics
        await loadEmergencies();
        await loadStatistics();
      } else {
        _setError(response['message'] ?? 'Failed to report emergency');

        // If the error is about missing client_id, provide clearer message
        if (response['message']?.toString().contains('client_id') == true) {
          _setError(
              'User authentication error. Please try logging out and logging back in.');
        }
      }

      return response;
    } catch (e) {
      final errorMsg = 'Error reporting emergency: $e';
      _setError(errorMsg);
      return {
        'success': false,
        'message': errorMsg,
      };
    } finally {
      _setReporting(false);
    }
  }

  // Get filtered emergencies by status
  List<Map<String, dynamic>> getFilteredEmergencies(String status) {
    if (status == 'all') {
      return _emergencies;
    } else {
      return _emergencies
          .where((emergency) => emergency['status'] == status)
          .toList();
    }
  }

  // Get current location
  Future<Map<String, dynamic>> getCurrentLocation() async {
    return await _emergencyService.getCurrentLocation();
  }

  // State management helpers
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setReporting(bool reporting) {
    _isReporting = reporting;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}
