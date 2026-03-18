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

class ActorLocationOption {
  const ActorLocationOption({
    required this.id,
    required this.name,
    this.code,
  });

  final String id;
  final String name;
  final String? code;

  factory ActorLocationOption.fromJson(Map<String, dynamic> json) {
    return ActorLocationOption(
      id: '${json['id']}',
      name: '${json['name']}',
      code: json['code']?.toString(),
    );
  }

  String get label {
    final trimmedCode = code?.trim();
    if (trimmedCode == null || trimmedCode.isEmpty) {
      return name;
    }
    return '$name · $trimmedCode';
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
  static const _actorLocationKey = 'sujin_tms_actor_location_id';
  static const _defaultActorLocationCodes = ['SEOUL_HQ', 'ICHEON_DC'];
  static late SessionController instance;

  final SharedPreferences _preferences;
  final ApiClient _client = ApiClient();
  AuthSession? _session;
  List<ActorLocationOption> _actorLocations = const [];
  String? _actorLocationId;
  bool _loadingActorLocations = false;

  static Future<SessionController> bootstrap() async {
    final preferences = await SharedPreferences.getInstance();
    final controller = SessionController._(preferences);
    instance = controller;
    ApiClient.accessTokenProvider = () => controller._session?.accessToken;
    ApiClient.actorLocationIdProvider = () => controller._actorLocationId;
    ApiClient.tenantCodeProvider = () => controller._session?.user.tenantCode;
    ApiClient.onUnauthorized = controller.expireSession;
    await controller._restoreSession();
    return controller;
  }

  AuthSession? get session => _session;
  bool get isAuthenticated => _session != null;
  List<ActorLocationOption> get actorLocations =>
      List.unmodifiable(_actorLocations);
  String? get actorLocationId => _actorLocationId;
  bool get isLoadingActorLocations => _loadingActorLocations;
  ActorLocationOption? get selectedActorLocation {
    final actorLocationId = _actorLocationId;
    if (actorLocationId == null || actorLocationId.isEmpty) {
      return null;
    }
    for (final option in _actorLocations) {
      if (option.id == actorLocationId) {
        return option;
      }
    }
    return null;
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final payload = await _client.login(
      email: email.trim(),
      password: password,
    );
    _session = AuthSession.fromJson(payload);
    await _syncActorLocations();
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
    _actorLocations = const [];
    _actorLocationId = null;
    _loadingActorLocations = false;
    await _preferences.remove(_storageKey);
    await _preferences.remove(_actorLocationKey);
    notifyListeners();
  }

  Future<void> selectActorLocation(String locationId) async {
    final normalizedId = locationId.trim();
    if (normalizedId.isEmpty) {
      return;
    }
    if (_actorLocations.every((option) => option.id != normalizedId)) {
      return;
    }
    _actorLocationId = normalizedId;
    await _preferences.setString(_actorLocationKey, normalizedId);
    notifyListeners();
  }

  Future<void> refreshActorLocations() async {
    await _syncActorLocations(notify: true);
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
      await _syncActorLocations();
      await _persistSession();
    } catch (_) {
      _session = null;
      _actorLocations = const [];
      _actorLocationId = null;
      await _preferences.remove(_storageKey);
      await _preferences.remove(_actorLocationKey);
    }
  }

  Future<void> _syncActorLocations({bool notify = false}) async {
    if (_session == null) {
      _actorLocations = const [];
      _actorLocationId = null;
      await _preferences.remove(_actorLocationKey);
      return;
    }

    _loadingActorLocations = true;
    if (notify) {
      notifyListeners();
    }
    try {
      final payload = await _client.fetchMasterSnapshot();
      final locationItems = (payload['locations'] as List?) ?? const [];
      final locations = locationItems
          .map(
            (item) => ActorLocationOption.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);
      final storedActorLocationId = _preferences.getString(_actorLocationKey);
      _actorLocations = locations;
      _actorLocationId = _resolveActorLocationId(
        locations,
        storedActorLocationId,
      );

      if (_actorLocationId == null) {
        await _preferences.remove(_actorLocationKey);
      } else {
        await _preferences.setString(_actorLocationKey, _actorLocationId!);
      }
    } finally {
      _loadingActorLocations = false;
      if (notify) {
        notifyListeners();
      }
    }
  }

  String? _resolveActorLocationId(
    List<ActorLocationOption> locations,
    String? storedActorLocationId,
  ) {
    if (locations.isEmpty) {
      return null;
    }

    final preferredIds = <String>[
      if (_actorLocationId != null) _actorLocationId!,
      if (storedActorLocationId != null && storedActorLocationId.isNotEmpty)
        storedActorLocationId,
    ];

    for (final preferredId in preferredIds) {
      for (final location in locations) {
        if (location.id == preferredId) {
          return preferredId;
        }
      }
    }

    for (final code in _defaultActorLocationCodes) {
      for (final location in locations) {
        if (location.code?.trim() == code) {
          return location.id;
        }
      }
    }

    return locations.first.id;
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
