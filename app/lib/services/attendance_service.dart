import 'package:app/services/api_client.dart';

class AttendanceService {
  static final AttendanceService _instance = AttendanceService._internal();
  final ApiClient _apiClient = ApiClient();

  // Singleton factory
  factory AttendanceService() => _instance;

  AttendanceService._internal();

  // Get all attendance records (admin only)
  Future<Map<String, dynamic>> getAllAttendance({
    int page = 1,
    int limit = 50,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
    String? studentId,
    String? type,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (date != null) {
        queryParams['date'] = date.toIso8601String().split('T')[0];
      }
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String().split('T')[0];
      }
      if (studentId != null) {
        queryParams['student'] = studentId;
      }
      if (type != null) {
        queryParams['type'] = type;
      }

      final response = await _apiClient.request(
        method: 'GET',
        path: '/attendance',
        queryParameters: queryParams,
      );

      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching attendance: $e',
      };
    }
  }

  // Get today's attendance summary (admin only)
  Future<Map<String, dynamic>> getTodayAttendance() async {
    try {
      final response = await _apiClient.request(
        method: 'GET',
        path: '/attendance/today',
      );

      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching today\'s attendance: $e',
      };
    }
  }

  // Get attendance by student ID (admin and parent can access)
  Future<Map<String, dynamic>> getAttendanceByStudent({
    required String studentId,
    int page = 1,
    int limit = 50,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
    String? type,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (date != null) {
        queryParams['date'] = date.toIso8601String().split('T')[0];
      }
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String().split('T')[0];
      }
      if (type != null) {
        queryParams['type'] = type;
      }

      final response = await _apiClient.request(
        method: 'GET',
        path: '/attendance/student/$studentId',
        queryParameters: queryParams,
      );

      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching student attendance: $e',
      };
    }
  }

  // Create attendance record (from ESP32)
  Future<Map<String, dynamic>> createAttendance({
    required String time,
    required String type,
    required String studentId,
    DateTime? date,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'time': time,
        'type': type,
        'student': studentId,
      };

      if (date != null) {
        data['date'] = date.toIso8601String();
      }

      final response = await _apiClient.request(
        method: 'POST',
        path: '/attendance',
        data: data,
      );

      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error creating attendance: $e',
      };
    }
  }
}
