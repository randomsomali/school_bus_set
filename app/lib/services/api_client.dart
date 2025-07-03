// lib/services/api_client.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  late final Dio _dio;

  // Singleton pattern
  factory ApiClient() => _instance;

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl:
          'http://192.168.100.92:6100/api', // Updated for fingerprint system
      validateStatus: (status) => true, // Handle all status codes ourselves
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
    ));

    // Add logging interceptor in debug mode
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
      ));
    }
  }

  void setToken(String token) {
    // Ensure headers are initialized
    _dio.options.headers ??= {};
    // Set with Bearer prefix if not already included
    if (!token.startsWith('Bearer ')) {
      token = 'Bearer $token';
    }
    _dio.options.headers!['Authorization'] = token;
  }

  void clearToken() {
    _dio.options.headers?.remove('Authorization');
  }

  // Generic request method
  Future<Map<String, dynamic>> request({
    required String method,
    required String path,
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await _dio.get(path, queryParameters: queryParameters);
          break;
        case 'POST':
          response = await _dio.post(path,
              data: data, queryParameters: queryParameters);
          break;
        case 'PUT':
          response = await _dio.put(path,
              data: data, queryParameters: queryParameters);
          break;
        case 'PATCH':
          response = await _dio.patch(path,
              data: data, queryParameters: queryParameters);
          break;
        case 'DELETE':
          response = await _dio.delete(path,
              data: data, queryParameters: queryParameters);
          break;
        default:
          throw Exception('Unsupported method: $method');
      }

      // Handle success response
      if (response.statusCode! >= 200 && response.statusCode! < 300) {
        return _processSuccessResponse(response);
      } else {
        return _processErrorResponse(response);
      }
    } on DioException catch (e) {
      return _processDioException(e);
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred: ${e.toString()}',
      };
    }
  }

  // Process successful API response
  Map<String, dynamic> _processSuccessResponse(Response response) {
    if (response.data is Map) {
      final Map<String, dynamic> responseData = response.data;
      return {
        'success': true,
        'data': responseData['data'] ?? responseData,
        'message': responseData['message'] ?? 'Success',
      };
    }

    return {
      'success': true,
      'data': response.data,
      'message': 'Success',
    };
  }

  // Process error response
  Map<String, dynamic> _processErrorResponse(Response response) {
    String errorMessage = 'An error occurred';

    // Check if response is HTML or text
    if (response.headers
            .value(Headers.contentTypeHeader)
            ?.contains('text/html') ==
        true) {
      errorMessage = 'Server returned unexpected response. Please try again.';
    } else if (response.data is Map) {
      // Extract error message from response data
      errorMessage = response.data['message'] ??
          response.data['error'] ??
          'Error ${response.statusCode}';
    } else if (response.data is String) {
      // Use response data as error message
      errorMessage = response.data.toString();
    }

    return {
      'success': false,
      'message': errorMessage,
    };
  }

  // Process Dio exceptions
  Map<String, dynamic> _processDioException(DioException error) {
    String errorMessage;

    if (error.response != null) {
      // Try to extract error message from response
      if (error.response!.data is Map) {
        errorMessage = error.response!.data['message'] ??
            error.response!.data['error'] ??
            _getErrorMessage(error);
      } else if (error.response!.data is String) {
        errorMessage = error.response!.data;
      } else {
        errorMessage = _getErrorMessage(error);
      }
    } else {
      errorMessage = _getErrorMessage(error);
    }

    return {
      'success': false,
      'message': errorMessage,
    };
  }

  // Get error message based on DioException type
  String _getErrorMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Please check your internet connection.';
      case DioExceptionType.connectionError:
        return 'Unable to connect to server. Please check if the server is running.';
      case DioExceptionType.badResponse:
        final response = error.response;
        // Handle HTML responses from server
        if (response != null &&
            response.headers
                    .value(Headers.contentTypeHeader)
                    ?.contains('text/html') ==
                true) {
          return 'Server error occurred. Please contact support.';
        }
        // Handle API error responses
        final statusCode = response?.statusCode;
        if (statusCode == 401) {
          return 'Authentication failed. Please log in again.';
        }
        if (statusCode == 403) {
          return 'Permission denied. You are not authorized to perform this action.';
        }
        if (statusCode == 404) {
          return 'Resource not found. Please check your request.';
        }
        return 'Server error occurred (${statusCode ?? 'unknown'})';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      default:
        return 'An unexpected error occurred. Please try again later.';
    }
  }
}
