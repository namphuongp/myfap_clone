import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class ApiClient {
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
    return kIsWeb ? 'http://localhost:3000/api' : 'http://10.0.2.2:3000/api';
  }

  final FlutterSecureStorage _storage;
  final http.Client _client;
  String? _token;
  ApiClient({http.Client? client, FlutterSecureStorage? storage})
    : _client = client ?? http.Client(),
      _storage = storage ?? const FlutterSecureStorage();

  Future<dynamic> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    try {
      final request = http.Request(method, Uri.parse('$baseUrl$path'));
      request.headers['Content-Type'] = 'application/json';
      if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
      if (body != null) request.body = jsonEncode(body);
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 15));
      final dynamic data = response.body.isEmpty
          ? null
          : jsonDecode(response.body);
      if (response.statusCode >= 400) {
        throw ApiException(
          data is Map
              ? data['message']?.toString() ?? 'Yêu cầu thất bại'
              : 'Yêu cầu thất bại',
          statusCode: response.statusCode,
        );
      }
      return data;
    } on TimeoutException {
      throw ApiException('Kết nối quá thời gian');
    } on http.ClientException {
      throw ApiException('Không kết nối được máy chủ');
    } on FormatException {
      throw ApiException('Phản hồi máy chủ không hợp lệ');
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await request('POST', '/auth/login', {
      'email': email,
      'password': password,
    }) as Map<String, dynamic>;
    _token = data['accessToken'] as String;
    try {
      await _storage.write(key: 'myfap_token', value: _token);
    } catch (_) {
      try {
        await request('POST', '/auth/logout');
      } finally {
        _token = null;
      }
      throw ApiException('Không thể lưu phiên đăng nhập an toàn');
    }
    return Map<String, dynamic>.from(data['user'] as Map);
  }

  Future<void> clearLocalSession() async {
    _token = null;
    try {
      await _storage.delete(key: 'myfap_token');
    } catch (_) {
      // Token đã thu hồi ở máy chủ; lỗi xóa kho cục bộ không được chặn đăng xuất.
    }
  }

  Future<void> logout() async {
    try {
      await request('POST', '/auth/logout');
    } on ApiException catch (error) {
      if (error.statusCode != 401) rethrow;
    }
    await clearLocalSession();
  }

  void dispose() => _client.close();
}
