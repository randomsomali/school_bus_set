import 'package:app/services/api_client.dart';

class AssignmentService {
  static final AssignmentService _instance = AssignmentService._internal();
  final ApiClient _apiClient = ApiClient();

  // Singleton factory
  factory AssignmentService() => _instance;

  AssignmentService._internal();

  // Get staff's assignments
  Future<Map<String, dynamic>> getMyAssignments() async {
    try {
      final response = await _apiClient.request(
        method: 'GET',
        path: '/assignments/my',
      );

      print('DEBUG - Assignments response: $response');
      return response;
    } catch (e) {
      print('DEBUG - Failed to load assignments: $e');
      return {
        'success': false,
        'message': 'Failed to load assignments: $e',
        'data': [],
      };
    }
  }

  // Get assignment details by ID
  Future<Map<String, dynamic>> getAssignmentById(int assignmentId) async {
    try {
      final response = await _apiClient.request(
        method: 'GET',
        path: '/assignments/$assignmentId',
      );

      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to load assignment details: $e',
        'data': null,
      };
    }
  }

  // Update assignment status (for staff to mark as completed)
  Future<Map<String, dynamic>> updateAssignmentStatus(
      int assignmentId, String status) async {
    try {
      final response = await _apiClient.request(
        method: 'PUT',
        path: '/assignments/my/$assignmentId',
        data: {'status': status},
      );

      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update assignment status: $e',
      };
    }
  }

  // Helper method to complete an assignment
  Future<Map<String, dynamic>> completeAssignment(int assignmentId) async {
    return await updateAssignmentStatus(assignmentId, 'completed');
  }
}
