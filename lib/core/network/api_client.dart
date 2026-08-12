import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../config/app_config.dart';

/// API 统一响应包装
class ApiResponse {
  const ApiResponse({
    required this.code,
    this.data,
    this.message,
    this.raw,
  });

  final int code;
  final dynamic data;
  final String? message;
  final Response? raw;

  bool get isSuccess => code == AppConfig.codeSuccess;
  bool get isUnauthorized => code == AppConfig.codeUnauthorized;

  factory ApiResponse.fromResponse(Response res) {
    final data = res.data;
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      return ApiResponse(
        code: (m['code'] as num?)?.toInt() ?? -1,
        data: m['data'],
        message: m['message'] as String?,
        raw: res,
      );
    }
    return ApiResponse(code: -1, raw: res);
  }
}

/// API 异常
class ApiException implements Exception {
  const ApiException(this.message, {this.code, this.type = ApiErrorType.unknown});
  final String message;
  final int? code;
  final ApiErrorType type;

  @override
  String toString() => 'ApiException($type, $code): $message';
}

enum ApiErrorType { network, timeout, unauthorized, parse, unknown, rateLimited }

/// dio 单例封装
/// - Cookie 拦截器注入认证
/// - 重试拦截器：网络错误/超时/429 自动重试
/// - 连接池配置提升并发能力
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  Dio? _dio;
  Dio get dio => _dio!;

  String _cookie = '';
  String get cookie => _cookie;

  /// 初始化 dio（幂等：已初始化时只更新 cookie）
  void init({String cookie = ''}) {
    _cookie = cookie;
    if (_dio != null) {
      updateCookie(cookie);
      return;
    }
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBase,
        connectTimeout: const Duration(milliseconds: AppConfig.connectTimeout),
        receiveTimeout: const Duration(milliseconds: AppConfig.receiveTimeout),
        sendTimeout: const Duration(milliseconds: AppConfig.connectTimeout),
        responseType: ResponseType.json,
        headers: {
          'Accept': 'application/json, text/plain, */*',
          'Referer': '${AppConfig.apiBase}/',
        },
      ),
    );

    // Cookie 拦截器
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_cookie.isNotEmpty) {
            options.headers['Cookie'] = _cookie;
          }
          handler.next(options);
        },
      ),
    );

    // 重试拦截器：网络错误/超时/429 自动重试 2 次，指数退避
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (e, handler) async {
          final retryCount = (e.requestOptions.extra['retryCount'] as int?) ?? 0;
          final shouldRetry = _isRetryable(e) && retryCount < AppConfig.maxRetry;

          if (shouldRetry) {
            final delay = Duration(
              milliseconds: AppConfig.retryBaseDelay * (1 << retryCount),
            );
            await Future.delayed(delay);
            e.requestOptions.extra['retryCount'] = retryCount + 1;
            try {
              final res = await dio.fetch(e.requestOptions);
              handler.resolve(res);
              return;
            } catch (err) {
              handler.next(err is DioException ? err : e);
              return;
            }
          }
          handler.next(e);
        },
      ),
    );

    // 连接池配置
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.connectionTimeout =
            const Duration(milliseconds: AppConfig.connectTimeout);
        client.idleTimeout = const Duration(seconds: 60);
        client.maxConnectionsPerHost = AppConfig.maxConcurrency;
        return client;
      },
    );
  }

  bool _isRetryable(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return true;
    }
    if (e.type == DioExceptionType.badResponse) {
      final code = e.response?.statusCode ?? 0;
      // 429 限流 / 5xx 服务端错误可重试
      return code == 429 || (code >= 500 && code < 600);
    }
    return false;
  }

  /// 更新 Cookie
  void updateCookie(String cookie) {
    _cookie = cookie;
  }

  // ========== 通用请求方法 ==========

  Future<ApiResponse> _get(
    String path, {
    Map<String, dynamic>? query,
    int timeout = AppConfig.receiveTimeout,
  }) async {
    try {
      final res = await dio.get(
        path,
        queryParameters: query,
        options: Options(receiveTimeout: Duration(milliseconds: timeout)),
      );
      return ApiResponse.fromResponse(res);
    } on DioException catch (e) {
      throw _wrapDioError(e);
    } catch (e) {
      throw ApiException('请求失败: $e', type: ApiErrorType.unknown);
    }
  }

  ApiException _wrapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException('请求超时', type: ApiErrorType.timeout);
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code == 401) {
          return const ApiException('登录失效', type: ApiErrorType.unauthorized);
        }
        if (code == 429) {
          return const ApiException('请求被限流', type: ApiErrorType.rateLimited);
        }
        return ApiException('HTTP $code', type: ApiErrorType.network);
      default:
        return ApiException('网络错误: ${e.message}', type: ApiErrorType.network);
    }
  }

  // ========== 业务 API ==========

  Future<ApiResponse> fetchTasks({required int pageNum, int pageSize = AppConfig.taskPageSize}) {
    return _get(
      '/data/api/v1/collect/tasks',
      query: {'page_num': pageNum, 'page_size': pageSize},
    );
  }

  Future<ApiResponse> fetchJobs({
    required int taskId,
    required int pageNum,
    int pageSize = AppConfig.jobPageSize,
  }) {
    return _get(
      '/data/api/v1/collect/task/job',
      query: {
        'task_id': taskId,
        'page_num': pageNum,
        'page_size': pageSize,
      },
    );
  }

  Future<ApiResponse> fetchEpisodes({
    required int taskId,
    required int jobId,
    required int pageNum,
    int pageSize = AppConfig.epPageSize,
    bool onlyStatus9 = true,
    bool withStatusCount = true,
  }) {
    final query = <String, dynamic>{
      'page_num': pageNum,
      'page_size': pageSize,
    };
    if (onlyStatus9) {
      query['status[]'] = 9;
    }
    if (withStatusCount) {
      query['with_status_count'] = 'true';
    }
    return _get(
      '/data/api/v1/collect/tasks/$taskId/jobs/$jobId/episodes',
      query: query,
    );
  }

  Future<ApiResponse> fetchEpisodeReviewData(int episodeId) {
    return _get(
      '/data/api/v1/collect/review/data/$episodeId',
      timeout: 5000,
    );
  }

  Future<ApiResponse> fetchResources(int taskId) {
    return _get(
      '/data/api/v1/collect/task/resource/all',
      query: {'task_id': taskId},
      timeout: 8000,
    );
  }

  Future<ApiResponse> fetchJobAssignmentStat(int jobId) {
    return _get(
      '/data/api/v1/collect/task/job/assignment/stat',
      query: {'job_id': jobId, 'page_num': 1, 'page_size': 10},
      timeout: 5000,
    );
  }

  static String buildEpisodeCheckUrl({
    required int taskId,
    required int jobId,
    required int episodeId,
  }) {
    return '${AppConfig.apiBase}/data/collection/tasks/$taskId/jobs/$jobId/episodes/$episodeId/check';
  }

  static String buildPreviewUrl({
    required int taskId,
    required int jobId,
    required int assignmentId,
    required String collectorName,
  }) {
    final encoded = Uri.encodeComponent(collectorName);
    return '${AppConfig.apiBase}/data/collection/episode/preview'
        '?assignmentId=$assignmentId&taskId=$taskId&collectorName=$encoded&jobId=$jobId';
  }
}

/// 解析 list 字段（兼容 Map 包装的 list 和裸 list）
List<T> parseList<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) {
  if (data is Map) {
    final list = data['list'];
    if (list is List) {
      return list
          .whereType<Map>()
          .map((m) => fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }
  }
  if (data is List) {
    return data
        .whereType<Map>()
        .map((m) => fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }
  return [];
}
