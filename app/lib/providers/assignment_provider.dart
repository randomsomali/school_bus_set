import 'package:flutter/foundation.dart';
import 'package:app/services/assignment_service.dart';

class AssignmentProvider with ChangeNotifier {
  final AssignmentService _assignmentService = AssignmentService();

  List<Map<String, dynamic>> _assignments = [];
  bool _isLoading = false;
  bool _isUpdating = false;
  String? _error;

  // Getters
  List<Map<String, dynamic>> get assignments => _assignments;
  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  String? get error => _error;

  // Load staff assignments
  Future<void> loadAssignments() async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _assignmentService.getMyAssignments();

      if (response['success']) {
        _assignments = List<Map<String, dynamic>>.from(response['data'] ?? []);
      } else {
        _setError(response['message'] ?? 'Failed to load assignments');
        _assignments = [];
      }
    } catch (e) {
      _setError('Error loading assignments: $e');
      _assignments = [];
    } finally {
      _setLoading(false);
    }
  }

  // Get assignment by ID
  Future<Map<String, dynamic>?> getAssignmentById(int assignmentId) async {
    try {
      final response = await _assignmentService.getAssignmentById(assignmentId);

      if (response['success']) {
        return response['data'];
      } else {
        _setError(response['message'] ?? 'Failed to load assignment details');
        return null;
      }
    } catch (e) {
      _setError('Error loading assignment details: $e');
      return null;
    }
  }

  // Complete an assignment
  Future<bool> completeAssignment(int assignmentId) async {
    _setUpdating(true);
    _clearError();

    try {
      final response =
          await _assignmentService.completeAssignment(assignmentId);

      if (response['success']) {
        // Update local data
        await loadAssignments();
        return true;
      } else {
        _setError(response['message'] ?? 'Failed to complete assignment');
        return false;
      }
    } catch (e) {
      _setError('Error completing assignment: $e');
      return false;
    } finally {
      _setUpdating(false);
    }
  }

  // Get filtered assignments by status
  List<Map<String, dynamic>> getFilteredAssignments(String status) {
    if (status == 'all') {
      return _assignments;
    } else {
      return _assignments
          .where((assignment) => assignment['status'] == status)
          .toList();
    }
  }

  // State management helpers
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setUpdating(bool updating) {
    _isUpdating = updating;
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
