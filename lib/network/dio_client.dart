import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

typedef TokenReader = String? Function();
typedef SessionWriter =
    Future<void> Function(String accessToken, String? refreshToken);

/// Shared HTTP client for the HRMS v1 API.
///
/// Auth headers, silent refresh, the `{success, data}` envelope, 304 replay,
/// and debug logging live in interceptors so every screen goes through the
/// same request path.
class HrDio {
  static Dio create({
    required String baseUrl,
    required TokenReader readToken,
    required TokenReader readRefreshToken,
    required SessionWriter onRefreshed,
    required VoidCallback onUnauthorized,
  }) {
    final dio = Dio(_options(baseUrl));
    dio.interceptors.addAll([
      AuthInterceptor(readToken: readToken),
      RefreshInterceptor(
        dio: dio,
        baseUrl: baseUrl,
        readToken: readToken,
        readRefreshToken: readRefreshToken,
        onRefreshed: onRefreshed,
        onUnauthorized: onUnauthorized,
      ),
      ResponseCacheInterceptor(),
      EnvelopeInterceptor(),
      if (kDebugMode) LogInterceptor(requestBody: true, responseBody: true),
    ]);
    return dio;
  }

  static BaseOptions _options(String baseUrl) => BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
    headers: const {'Accept': 'application/json'},
    contentType: Headers.jsonContentType,
    validateStatus: (code) => code != null && code < 400,
  );
}

/// Reads `hrms_rt` from `Set-Cookie` headers.
String? refreshCookie(Headers headers) {
  for (final line in headers['set-cookie'] ?? const <String>[]) {
    final match = RegExp(r'(?:^|;\s*)hrms_rt=([^;]*)').firstMatch(line);
    final value = match?.group(1);
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

class AuthInterceptor extends Interceptor {
  final TokenReader readToken;
  AuthInterceptor({required this.readToken});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = readToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

/// Access tokens live 15 minutes. On a 401 this rotates the refresh cookie
/// once and replays the request; concurrent failures share one refresh.
class RefreshInterceptor extends QueuedInterceptor {
  final Dio dio;
  final String baseUrl;
  final TokenReader readToken;
  final TokenReader readRefreshToken;
  final SessionWriter onRefreshed;
  final VoidCallback onUnauthorized;

  RefreshInterceptor({
    required this.dio,
    required this.baseUrl,
    required this.readToken,
    required this.readRefreshToken,
    required this.onRefreshed,
    required this.onUnauthorized,
  });

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final sent = request.headers['Authorization']?.toString();
    final isAuthCall = const {
      '/auth/login',
      '/auth/refresh',
      '/auth/logout',
    }.contains(request.path);
    if (err.response?.statusCode != 401 || sent == null || isAuthCall) {
      return handler.next(err);
    }
    if (request.extra['retried'] == true) {
      onUnauthorized();
      return handler.next(err);
    }
    final current = readToken();
    final alreadyRefreshed =
        current != null && current.isNotEmpty && sent != 'Bearer $current';
    if (!alreadyRefreshed && !await _refresh()) {
      onUnauthorized();
      return handler.next(err);
    }
    try {
      request.extra['retried'] = true;
      request.headers['Authorization'] = 'Bearer ${readToken()}';
      handler.resolve(await dio.fetch<dynamic>(request));
    } on DioException catch (again) {
      handler.next(again);
    }
  }

  Future<bool> _refresh() async {
    final cookie = readRefreshToken();
    if (cookie == null || cookie.isEmpty) return false;
    final plain = Dio(HrDio._options(baseUrl));
    try {
      final response = await plain.post<dynamic>(
        '/auth/refresh',
        data: const <String, dynamic>{},
        options: Options(headers: {'Cookie': 'hrms_rt=$cookie'}),
      );
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      final token = data is Map ? data['accessToken']?.toString() : null;
      if (token == null || token.isEmpty) return false;
      await onRefreshed(token, refreshCookie(response.headers) ?? cookie);
      return true;
    } catch (_) {
      return false;
    } finally {
      plain.close();
    }
  }
}

/// Unwraps `{success: true, data: …}` so callers read `data` directly, and
/// lifts `{success: false, error: {message}}` into the Dio error message.
class EnvelopeInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final body = response.data;
    if (body is Map && body.containsKey('success') && body['success'] == true) {
      response.data = body['data'];
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final body = err.response?.data;
    final error = body is Map ? body['error'] : null;
    final message = error is Map ? error['message']?.toString() : null;
    if (message != null && message.isNotEmpty) {
      return handler.next(err.copyWith(message: message));
    }
    handler.next(err);
  }
}

/// Replays the last JSON body when the server answers 304 Not Modified.
class ResponseCacheInterceptor extends Interceptor {
  final Map<String, String> _bodies = {};
  final Map<String, String> _etags = {};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method.toUpperCase() == 'GET') {
      final etag = _etags[_key(options)];
      if (etag != null) options.headers['If-None-Match'] = etag;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final key = _key(response.requestOptions);
    if (response.statusCode == 304) {
      final saved = _bodies[key];
      if (saved != null) {
        response.data = jsonDecode(saved);
        response.statusCode = 200;
      }
    } else if (response.requestOptions.method.toUpperCase() == 'GET' &&
        response.statusCode == 200 &&
        response.data != null) {
      try {
        _bodies[key] = response.data is String
            ? response.data as String
            : jsonEncode(response.data);
      } catch (_) {}
      final etag = response.headers.value('etag');
      if (etag != null && etag.isNotEmpty) _etags[key] = etag;
    }
    handler.next(response);
  }

  String _key(RequestOptions options) => options.uri.toString();
}
