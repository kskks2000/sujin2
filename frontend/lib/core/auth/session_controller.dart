import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';

class AuthUserProfile {
  const AuthUserProfile({
    required this.id,
    required this.tenantId,
    required this.tenantCode,
    required this.email,
    required this.fullName,
    required this.roleName,
  });

  final String id;
  final String tenantId;
  final String tenantCode;
  final String email;
  final String fullName;
  final String roleName;

  factory AuthUserProfile.fromJson(Map<String, dynamic> json) {
    return AuthUserProfile(
      id: '${json['id']}',
      tenantId: '${json['tenant_id']}',
      tenantCode: '${json['tenant_code']}',
      email: '${json['email']}',
      fullName: '${json['full_name']}',
      roleName: '${json['role_name']}',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'tenant_code': tenantCode,
      'email': email,
      'full_name': fullName,
      'role_name': roleName,
    };
  }

  String get roleLabel {
    switch (roleName) {
      case 'admin':
        return '관리자';
      case 'ops_manager':
        return '운영 관리자';
      case 'dispatcher':
        return '배차 담당';
      default:
        return roleName;
    }
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.expiresIn,
    required this.user,
  });

  final String accessToken;
  final int expiresIn;
  final AuthUserProfile user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: '${json['access_token']}',
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 0,
      user: AuthUserProfile.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  AuthSession copyWith({
    String? accessToken,
    int? expiresIn,
    AuthUserProfile? user,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      expiresIn: expiresIn ?? this.expiresIn,
      user: user ?? this.user,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'expires_in': expiresIn,
      'user': user.toJson(),
    };
  }
}

class SessionController extends ChangeNotifier {
  SessionController._(this._preferences);

  static const _storageKey = 'sujin_tms_session';
  static late SessionController instance;

  final SharedPreferences _preferences;
  final ApiClient _client = ApiClient();
  AuthSession? _session;

  static Future<SessionController> bootstrap() async {
    final preferences = await SharedPreferences.getInstance();
    final controller = SessionController._(preferences);
    instance = controller;
    ApiClient.accessTokenProvider = () => controller._session?.accessToken;
    ApiClient.onUnauthorized = controller.expireSession;
    await controller._restoreSession();
    return controller;
  }

  AuthSession? get session => _session;
  bool get isAuthenticated => _session != null;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final payload = await _client.login(
      email: email.trim(),
      password: password,
    );
    _session = AuthSession.fromJson(payload);
    await _persistSession();
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await _client.logout();
    } catch (_) {}
    await expireSession();
  }

  Future<void> expireSession() async {
    _session = null;
    await _preferences.remove(_storageKey);
    notifyListeners();
  }

  Future<void> _restoreSession() async {
    final raw = _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _session = AuthSession.fromJson(decoded);
      final me = await _client.fetchCurrentUser();
      _session = _session?.copyWith(
        user: AuthUserProfile.fromJson(me['user'] as Map<String, dynamic>),
      );
      await _persistSession();
    } catch (_) {
      _session = null;
      await _preferences.remove(_storageKey);
    }
  }

  Future<void> _persistSession() async {
    final session = _session;
    if (session == null) {
      await _preferences.remove(_storageKey);
      return;
    }
    await _preferences.setString(_storageKey, jsonEncode(session.toJson()));
  }
}
