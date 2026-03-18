import 'package:dio/dio.dart';

import 'demo_payloads.dart';

class ApiClient {
  static String? Function()? accessTokenProvider;
  static String? Function()? actorLocationIdProvider;
  static String? Function()? tenantCodeProvider;
  static Future<void> Function()? onUnauthorized;

  ApiClient()
      : _dio = Dio(
          BaseOptions(
            baseUrl: const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://localhost:8000/api/v1',
            ),
            connectTimeout: const Duration(seconds: 3),
            receiveTimeout: const Duration(seconds: 5),
            headers: const {'X-Tenant-Code': 'SUJIN'},
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final accessToken = accessTokenProvider?.call();
          if (accessToken != null && accessToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          final tenantCode = tenantCodeProvider?.call();
          if (tenantCode != null && tenantCode.isNotEmpty) {
            options.headers['X-Tenant-Code'] = tenantCode;
          }
          final actorLocationId = actorLocationIdProvider?.call();
          if (actorLocationId != null && actorLocationId.isNotEmpty) {
            options.headers['X-Actor-Location-Id'] = actorLocationId;
          } else {
            options.headers.remove('X-Actor-Location-Id');
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    return _sendMap(
      'POST',
      '/auth/login',
      {
        'email': email,
        'password': password,
      },
      '로그인에 실패했습니다.',
    );
  }

  Future<Map<String, dynamic>> fetchCurrentUser() async {
    return _sendMap('GET', '/auth/me', null, '사용자 정보를 불러오지 못했습니다.');
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } on DioException catch (error) {
      await _handleUnauthorized(error);
    }
  }

  Future<Map<String, dynamic>> fetchDashboardSnapshot() async {
    return _fetchMap('/dashboard/snapshot', DemoPayloads.dashboardSnapshot);
  }

  Future<Map<String, dynamic>> fetchOrders() async {
    return _fetchMap('/orders', DemoPayloads.orders);
  }

  Future<Map<String, dynamic>> fetchMasterSnapshot() async {
    return _fetchMap('/masters/snapshot', () {
      return {
        'organizations': <Map<String, dynamic>>[],
        'locations': <Map<String, dynamic>>[],
        'drivers': <Map<String, dynamic>>[],
        'vehicles': <Map<String, dynamic>>[],
      };
    });
  }

  Future<Map<String, dynamic>> fetchShipments() async {
    return _fetchMap('/shipments', DemoPayloads.shipments);
  }

  Future<Map<String, dynamic>> fetchDispatches() async {
    return _fetchMap('/dispatches', DemoPayloads.dispatches);
  }

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> payload) async {
    return _sendMap('POST', '/orders', payload, '운송오더 등록에 실패했습니다.');
  }

  Future<Map<String, dynamic>> fetchOrderDetail(String orderId) async {
    return _sendMap('GET', '/orders/$orderId', null, '오더 상세 조회에 실패했습니다.');
  }

  Future<Map<String, dynamic>> updateOrder(
    String orderId,
    Map<String, dynamic> payload,
  ) async {
    return _sendMap('PUT', '/orders/$orderId', payload, '운송오더 수정에 실패했습니다.');
  }

  Future<Map<String, dynamic>> _sendMap(
    String method,
    String path,
    Map<String, dynamic>? payload,
    String fallbackMessage,
  ) async {
    try {
      final response = await _dio.request(
        path,
        data: payload,
        options: Options(method: method),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception('응답 형식이 올바르지 않습니다.');
    } on DioException catch (error) {
      await _handleUnauthorized(error);
      final detail = error.response?.data is Map<String, dynamic>
          ? (error.response?.data as Map<String, dynamic>)['detail']
          : null;
      throw Exception(detail?.toString() ?? fallbackMessage);
    }
  }

  Future<Map<String, dynamic>> _fetchMap(
    String path,
    Map<String, dynamic> Function() fallback,
  ) async {
    try {
      final response = await _dio.get(path);
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return fallback();
    } on DioException catch (error) {
      await _handleUnauthorized(error);
      return fallback();
    } catch (_) {
      return fallback();
    }
  }

  Future<void> _handleUnauthorized(DioException error) async {
    final statusCode = error.response?.statusCode;
    if (statusCode == 401 || statusCode == 403) {
      await onUnauthorized?.call();
    }
  }
}
