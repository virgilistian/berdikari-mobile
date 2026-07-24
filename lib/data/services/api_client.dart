import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../config/env.dart';

/// Error thrown for any non-2xx API response.
///
/// Maps the Laravel error contract: `message` plus an optional
/// per-field `errors{}` validation bag (HTTP 422).
class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.message,
    this.fieldErrors = const {},
  });

  final int statusCode;

  /// Human-readable message. The API returns Bahasa Indonesia copy;
  /// fallbacks generated client-side must also be Bahasa Indonesia.
  final String message;

  /// Laravel validation bag: field name -> first error message.
  final Map<String, String> fieldErrors;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isValidationError => statusCode == 422;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Signature invoked when any request returns 401 (token expired/revoked).
typedef UnauthorizedCallback = Future<void> Function();

/// Thin wrapper around `package:http` — the single entry point for all
/// Berdikari API traffic. Services (auth, sales, inventory, ...) consume
/// this client; nothing else in the app touches HTTP directly.
class ApiClient {
  ApiClient({
    required this.tokenProvider,
    http.Client? httpClient,
    String? baseUrl,
    this.onUnauthorized,
  })  : _http = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? Env.apiBaseUrl;

  /// Reads the persisted Sanctum token; returns null when logged out.
  final Future<String?> Function() tokenProvider;
  final http.Client _http;
  String _baseUrl;

  /// Invoked on any 401 response. Mutable so it can be wired to
  /// [AuthRepository.clearSession] after both objects exist.
  UnauthorizedCallback? onUnauthorized;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) =>
      _send('GET', path, query: query);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      _send('POST', path, body: body);

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      _send('PUT', path, body: body);

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, String>? query,
  }) =>
      _send('DELETE', path, query: query);

  /// Uploads [file] as multipart form field [fieldName] — the only shape
  /// the file-upload endpoints (product photo, business logo, tax
  /// signature/stamp) accept. Separate from [_send] because a JSON body and
  /// a multipart body are mutually exclusive per request.
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required String fieldName,
    required File file,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Accept'] = 'application/json';
    final token = await tokenProvider();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(await http.MultipartFile.fromPath(fieldName, file.path));

    final response = await http.Response.fromStream(await _http.send(request));

    if (response.statusCode == 401) {
      await onUnauthorized?.call();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _toException(response);
    }
    if (response.body.isEmpty) return const {};

    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
  }

  /// Current API base URL — used to build direct-load URLs for endpoints
  /// (e.g. product photo) that are displayed via `Image.network` rather
  /// than fetched through [get].
  String get baseUrl => _baseUrl;

  /// Headers to attach to an authenticated `Image.network` request against
  /// this API (product photo, etc.) — those endpoints sit behind
  /// `auth:sanctum` just like every JSON route.
  Future<Map<String, String>> authHeaders() async {
    final token = await tokenProvider();
    return token == null ? const {} : {'Authorization': 'Bearer $token'};
  }

  /// Repoints the client at a Remote Config-provided base URL, once fetched.
  /// No-op for an empty value — the compile-time [Env.apiBaseUrl] default
  /// stays in effect until a non-empty override arrives.
  void applyBaseUrlOverride(String baseUrl) {
    if (baseUrl.isEmpty) return;
    _baseUrl = baseUrl;
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );

    final request = http.Request(method, uri);
    request.headers['Accept'] = 'application/json';
    final token = await tokenProvider();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final response = await http.Response.fromStream(await _http.send(request));

    if (response.statusCode == 401) {
      await onUnauthorized?.call();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _toException(response);
    }
    if (response.body.isEmpty) return const {};

    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
  }

  ApiException _toException(http.Response response) {
    String message = 'Terjadi kesalahan. Silakan coba lagi.';
    final fieldErrors = <String, String>{};

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (decoded['message'] is String &&
            (decoded['message'] as String).isNotEmpty) {
          message = decoded['message'] as String;
        }
        final errors = decoded['errors'];
        if (errors is Map<String, dynamic>) {
          for (final entry in errors.entries) {
            final value = entry.value;
            if (value is List && value.isNotEmpty) {
              fieldErrors[entry.key] = value.first.toString();
            } else if (value is String) {
              fieldErrors[entry.key] = value;
            }
          }
        }
      }
    } on FormatException {
      // Non-JSON body (proxy error page, timeout HTML) — keep the fallback.
    }

    return ApiException(
      statusCode: response.statusCode,
      message: message,
      fieldErrors: fieldErrors,
    );
  }

  void close() => _http.close();
}
