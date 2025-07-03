import 'package:app/services/api_client.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  final ApiClient _apiClient = ApiClient();

  // Singleton factory
  factory UserService() => _instance;

  UserService._internal();

  // Get all users (admin only)
  Future<Map<String, dynamic>> getAllUsers() async {
    try {
      final response = await _apiClient.request(
        method: 'GET',
        path: '/users',
      );

      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching users: $e',
      };
    }
  }

  // Get a single user by ID (admin only)
  Future<Map<String, dynamic>> getUserById(String userId) async {
    try {
      final response = await _apiClient.request(
        method: 'GET',
        path: '/users/$userId',
      );

      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching user: $e',
      };
    }
  }

  // Create a new user (admin only)
  Future<Map<String, dynamic>> createUser({
    required String phone,
    required String password,
    required String role,
  }) async {
    try {
      final response = await _apiClient.request(
        method: 'POST',
        path: '/users',
        data: {
          'phone': phone,
          'password': password,
          'role': role,
        },
      );

      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error creating user: $e',
      };
    }
  }

  // Update a user (admin only)
  Future<Map<String, dynamic>> updateUser({
    required String userId,
    String? phone,
    String? password,
    String? role,
  }) async {
    try {
      final Map<String, dynamic> data = {};
      if (phone != null) data['phone'] = phone;
      if (password != null) data['password'] = password;
      if (role != null) data['role'] = role;

      final response = await _apiClient.request(
        method: 'PUT',
        path: '/users/$userId',
        data: data,
      );

      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error updating user: $e',
      };
    }
  }

  // Delete a user (admin only)
  Future<Map<String, dynamic>> deleteUser(String userId) async {
    try {
      final response = await _apiClient.request(
        method: 'DELETE',
        path: '/users/$userId',
      );

      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error deleting user: $e',
      };
    }
  }
}
