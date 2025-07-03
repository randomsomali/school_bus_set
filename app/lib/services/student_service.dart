import 'package:app/services/api_client.dart';

class StudentService {
  static final StudentService _instance = StudentService._internal();
  final ApiClient _apiClient = ApiClient();

  // Singleton factory
  factory StudentService() => _instance;

  StudentService._internal();

  // Get all students (admin only)
  Future<Map<String, dynamic>> getAllStudents() async {
    try {
      final response = await _apiClient.request(
        method: 'GET',
        path: '/students',
      );

      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching students: $e',
      };
    }
  }

  // Get students by parent ID
  Future<Map<String, dynamic>> getStudentsByParent(String parentId) async {
    try {
      final response = await _apiClient.request(
        method: 'GET',
        path: '/students/parent/$parentId',
      );

      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching students: $e',
      };
    }
  }

  // Create a new student (admin only)
  Future<Map<String, dynamic>> createStudent({
    required String name,
    required String parentId,
  }) async {
    try {
      final response = await _apiClient.request(
        method: 'POST',
        path: '/students',
        data: {
          'name': name,
          'parent': parentId,
        },
      );

      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error creating student: $e',
      };
    }
  }

  // Update a student (admin only)
  Future<Map<String, dynamic>> updateStudent({
    required String studentId,
    String? name,
    String? parentId,
  }) async {
    try {
      final Map<String, dynamic> data = {};
      if (name != null) data['name'] = name;
      if (parentId != null) data['parent'] = parentId;

      final response = await _apiClient.request(
        method: 'PUT',
        path: '/students/$studentId',
        data: data,
      );

      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error updating student: $e',
      };
    }
  }

  // Delete a student (admin only)
  Future<Map<String, dynamic>> deleteStudent(String studentId) async {
    try {
      final response = await _apiClient.request(
        method: 'DELETE',
        path: '/students/$studentId',
      );

      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error deleting student: $e',
      };
    }
  }
}
