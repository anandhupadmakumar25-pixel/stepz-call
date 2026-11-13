import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String _tokenKey = 'auth_token';
  static const String _refreshKey = 'refresh_token';
  static const String _userKey = 'auth_user';

  // Compile-time environment override: flutter build web --dart-define=API_URL=https://stepz-call-api.onrender.com
  static const String _envApiUrl = String.fromEnvironment('API_URL');

  static String get serverOrigin {
    if (_envApiUrl.isNotEmpty) {
      return _envApiUrl.endsWith('/') ? _envApiUrl.substring(0, _envApiUrl.length - 1) : _envApiUrl;
    }
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return 'http://127.0.0.1:8000';
    }
    return 'http://10.224.188.176:8000';
  }

  static String get baseUrl => '$serverOrigin/api/v1';

  static String? resolveMediaUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return null;
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      return rawUrl
          .replaceFirst('http://127.0.0.1:8000', serverOrigin)
          .replaceFirst('http://localhost:8000', serverOrigin)
          .replaceFirst('http://10.0.2.2:8000', serverOrigin);
    }
    if (rawUrl.startsWith('/')) {
      return '$serverOrigin$rawUrl';
    }
    return '$serverOrigin/$rawUrl';
  }

  // Token Management
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveSession(
    String accessToken,
    String refreshToken,
    Map<String, dynamic> user,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, accessToken);
    await prefs.setString(_refreshKey, refreshToken);
    await prefs.setString(_userKey, jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_userKey);
    if (str != null) {
      return jsonDecode(str) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshKey);
    await prefs.remove(_userKey);
  }

  // Headers
  static Future<Map<String, String>> _headers({bool isJson = true}) async {
    final token = await getToken();
    final headers = <String, String>{
      'bypass-tunnel-reminder': 'true',
      'ngrok-skip-browser-warning': 'true',
    };
    if (isJson) {
      headers['Content-Type'] = 'application/json';
      headers['Accept'] = 'application/json';
    }
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // HTTP GET
  static Future<dynamic> get(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _headers();
    final res = await http.get(url, headers: headers);
    return _processResponse(res);
  }

  // HTTP POST
  static Future<dynamic> post(String endpoint, dynamic body) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _headers();
    final res = await http.post(url, headers: headers, body: jsonEncode(body));
    return _processResponse(res);
  }

  // HTTP PATCH
  static Future<dynamic> patch(String endpoint, dynamic body) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _headers();
    final res = await http.patch(url, headers: headers, body: jsonEncode(body));
    return _processResponse(res);
  }

  // HTTP DELETE
  static Future<dynamic> delete(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _headers();
    final res = await http.delete(url, headers: headers);
    return _processResponse(res);
  }

  // HTTP Multipart Upload (for Excel / CSV)
  static Future<dynamic> uploadFile(
    String endpoint,
    List<int> fileBytes,
    String filename,
  ) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final request = http.MultipartRequest('POST', url);
    final headers = await _headers(isJson: false);
    request.headers.addAll(headers);

    request.files.add(
      http.MultipartFile.fromBytes('file', fileBytes, filename: filename),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _processResponse(response);
  }

  // HTTP Multipart Upload with Fields & Optional Audio File Bytes
  static Future<dynamic> uploadRecordingMultipart(
    String endpoint, {
    required Map<String, String> fields,
    List<int>? fileBytes,
    String? filename,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final request = http.MultipartRequest('POST', url);
    final headers = await _headers(isJson: false);
    request.headers.addAll(headers);
    request.fields.addAll(fields);

    if (fileBytes != null && fileBytes.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'audio_file',
          fileBytes,
          filename: filename ?? 'call_recording.m4a',
        ),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _processResponse(response);
  }

  static dynamic _processResponse(http.Response response) {
    dynamic body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      body = response.body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      String errorMessage = 'Request failed with status ${response.statusCode}';
      if (body is Map) {
        if (body.containsKey('message') && body['message'] != null && body['message'].toString().isNotEmpty) {
          errorMessage = body['message'].toString();
        } else if (body.containsKey('detail') && body['detail'] != null && body['detail'].toString().isNotEmpty) {
          errorMessage = body['detail'].toString();
        } else if (body.containsKey('error') && body['error'] != null && body['error'].toString().isNotEmpty) {
          errorMessage = body['error'].toString();
        } else if (body.containsKey('errors')) {
          final errs = body['errors'];
          if (errs is Map) {
            errorMessage = errs.values.map((v) => v is List ? v.join(', ') : v.toString()).join('; ');
          } else {
            errorMessage = errs.toString();
          }
        } else {
          errorMessage = body.values.join(', ');
        }
      }
      if (response.statusCode == 401 && (errorMessage.contains('401') || errorMessage.contains('credentials'))) {
        errorMessage = 'Invalid email or password. Please verify your credentials.';
      }
      throw ApiException(
        errorMessage,
        response.statusCode,
        data: body is Map<String, dynamic> ? body : null,
      );
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final Map<String, dynamic>? data;

  ApiException(this.message, this.statusCode, {this.data});

  @override
  String toString() => message;
}
