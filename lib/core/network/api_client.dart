import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient(this._tokenStorage)
    : dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: ApiConfig.connectTimeout,
          receiveTimeout: ApiConfig.receiveTimeout,
          headers: const {'Accept': 'application/json'},
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) async {
          if (kDebugMode) debugPrint('SIDE B API -> ${o.method} ${o.uri}');
          final t = await _tokenStorage.read();
          if (t != null) o.headers['Authorization'] = 'Bearer $t';
          h.next(o);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint(
              'SIDE B API <- ${response.statusCode} ${response.requestOptions.uri}',
            );
          }
          handler.next(response);
        },
        onError: (error, handler) {
          if (kDebugMode) {
            debugPrint(
              'SIDE B API ERROR ${error.type.name} ${error.requestOptions.uri}: ${error.error ?? error.message}',
            );
          }
          handler.next(error);
        },
      ),
    );
  }
  final TokenStorage _tokenStorage;
  final Dio dio;

  Future<dynamic> uploadBytes(String path, List<int> bytes) =>
      _upload(path, bytes, 'PUT');
  Future<dynamic> postBytes(String path, List<int> bytes) =>
      _upload(path, bytes, 'POST');

  Future<dynamic> _upload(String path, List<int> bytes, String method) async {
    try {
      return (await _withKnownHosts(
        () => dio.request<dynamic>(
          path,
          data: Stream<List<int>>.value(bytes),
          options: Options(
            method: method,
            contentType: 'application/octet-stream',
            headers: {Headers.contentLengthHeader: bytes.length},
          ),
        ),
      )).data;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Response<T>> _withKnownHosts<T>(
    Future<Response<T>> Function() request,
  ) async {
    DioException? lastConnectionError;

    for (final baseUrl in ApiConfig.baseUrls) {
      dio.options.baseUrl = baseUrl;
      try {
        return await request();
      } on DioException catch (error) {
        if (error.type != DioExceptionType.connectionError &&
            error.type != DioExceptionType.connectionTimeout &&
            error.type != DioExceptionType.receiveTimeout) {
          rethrow;
        }
        lastConnectionError = error;
      }
    }

    throw lastConnectionError!;
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return (await _withKnownHosts(
        () => dio.get<dynamic>(path, queryParameters: queryParameters),
      )).data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<dynamic> post(String path, {Object? data}) async {
    try {
      return (await _withKnownHosts(() => dio.post<dynamic>(path, data: data)))
          .data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<dynamic> delete(String path) async {
    try {
      return (await _withKnownHosts(() => dio.delete<dynamic>(path))).data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<dynamic> put(String path, {Object? data}) async {
    try {
      return (await _withKnownHosts(() => dio.put<dynamic>(path, data: data)))
          .data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  ApiException _mapError(DioException e) {
    final d = e.response?.data;
    final detail = d is Map<String, dynamic> ? d['detail']?.toString() : null;
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout)
      return const ApiException('El servidor tardÃ³ demasiado en responder.');
    if (e.type == DioExceptionType.connectionError)
      return const ApiException('No fue posible conectar con SIDE B.');
    return ApiException(
      detail ?? 'OcurriÃ³ un error al consultar SIDE B.',
      statusCode: e.response?.statusCode,
    );
  }
}
