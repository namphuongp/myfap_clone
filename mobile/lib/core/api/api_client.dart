import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiClient {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api',
  );
  final _storage = const FlutterSecureStorage();
  final _client = http.Client();
  String? _token;

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
      final response = await http.Response.fromStream(
        await _client.send(request),
      ).timeout(const Duration(seconds: 15));
      final dynamic data = response.body.isEmpty
          ? null
          : jsonDecode(response.body);
      if (response.statusCode >= 400) {
        throw ApiException(
          data is Map
              ? data['message']?.toString() ?? 'Yêu cầu thất bại'
              : 'Yêu cầu thất bại',
        );
      }
      return data;
    } on TimeoutException {
      throw ApiException('Kết nối quá thời gian');
    } on http.ClientException {
      throw ApiException(
        'Không kết nối được API. Kiểm tra server và API_BASE_URL',
      );
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
    return data['user'] as Map<String, dynamic>;
  }

  Future<void> logout() async {
    await request('POST', '/auth/logout');
    _token = null;
    await _storage.delete(key: 'myfap_token');
  }

  void dispose() => _client.close();
}
