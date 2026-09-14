import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elmasa/models/workspace.dart';
import 'package:elmasa/models/app_state.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:elmasa/config/app_config.dart';
import 'package:elmasa/services/security_service.dart';
import 'package:elmasa/main.dart';

class SessionExpiredException implements Exception {
  final String message;
  SessionExpiredException([this.message = 'Session expired']);
  @override
  String toString() => message;
}

class ServerException implements Exception {
  final String message;
  final int statusCode;
  ServerException(this.message, this.statusCode);
  @override
  String toString() => message;
}

class DeviceMismatchException implements Exception {
  final String message;
  DeviceMismatchException([this.message = 'This account is already linked to another device. Please disconnect the old device first.']);
  @override
  String toString() => message;
}

class UserBannedException implements Exception {
  final String message;
  UserBannedException([this.message = 'user_banned_msg']);
  @override
  String toString() => message;
}

class ApiService {
  final _stateKey = 'app_state';
  AppState? _state;
  String? _deviceId;

  static Map<String, dynamic> parseJsonResponse(http.Response response) {
    if (response.body.isEmpty) return {};
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      } else if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      } else if (decoded is List) {
        return {'data': decoded};
      }
      return {'result': decoded};
    } catch (e) {
      debugPrint('⚠️ Non-JSON response body (${response.statusCode}): ${response.body.length > 150 ? response.body.substring(0, 150) : response.body}');
      if (response.body.contains('<html') || response.body.contains('<!DOCTYPE')) {
        throw ServerException('خطأ في السيرفر (${response.statusCode}). Server returned invalid response format.', response.statusCode);
      }
      throw ServerException('استجابة غير متوقعة من السيرفر (${response.statusCode})', response.statusCode);
    }
  }

  static String extractErrorMessage(Map<String, dynamic> data, String defaultMsg) {
    if (data.containsKey('errors') && data['errors'] != null) {
      final errors = data['errors'];
      if (errors is Map) {
        final messages = <String>[];
        errors.forEach((key, value) {
          if (value is List && value.isNotEmpty) {
            messages.add(value.first.toString());
          } else if (value != null && value.toString().isNotEmpty) {
            messages.add(value.toString());
          }
        });
        if (messages.isNotEmpty) return messages.join('\n');
      } else if (errors is List && errors.isNotEmpty) {
        return errors.map((e) => e.toString()).join('\n');
      } else if (errors is String && errors.isNotEmpty) {
        return errors;
      }
    }
    if (data.containsKey('error') && data['error'] != null) {
      final err = data['error'];
      if (err is String && err.isNotEmpty) return err;
      if (err is Map && err.containsKey('message')) return err['message'].toString();
    }
    if (data.containsKey('message') && data['message'] != null) {
      final msg = data['message'].toString();
      if (msg.isNotEmpty && msg != 'The given data was invalid.') return msg;
    }
    return defaultMsg;
  }

  static String? extractAdminColor(dynamic rawJson) {
    if (rawJson == null) return null;
    Map<String, dynamic>? map;
    if (rawJson is Map<String, dynamic>) {
      map = rawJson;
    } else if (rawJson is Map) {
      map = Map<String, dynamic>.from(rawJson);
    } else {
      return null;
    }

    final candidates = <Map<String, dynamic>>[
      map,
      if (map['settings'] is Map) Map<String, dynamic>.from(map['settings']),
      if (map['data'] is Map) Map<String, dynamic>.from(map['data']),
      if (map['site'] is Map) Map<String, dynamic>.from(map['site']),
      if (map['options'] is Map) Map<String, dynamic>.from(map['options']),
      if (map['tenant'] is Map) Map<String, dynamic>.from(map['tenant']),
    ];

    final keys = [
      'theme_color',
      'primary_color',
      'brand_color',
      'color',
      'app_color',
      'site_color',
      'theme_primary_color',
      'accent_color',
      'main_color',
    ];

    for (final c in candidates) {
      for (final key in keys) {
        final val = c[key]?.toString().trim();
        if (val != null && val.isNotEmpty && val != 'null' && val != 'undefined') {
          return val;
        }
      }
    }
    return null;
  }

  Future<void> _checkDeviceSafety() async {
    if (!SecurityService.bypassSecurityChecks) {
      final isSafe = await SecurityService.isDeviceSafe();
      if (!isSafe) {
        debugPrint('❌ Security check failed! Stopping API call.');
        throw Exception('Security violation: Untrusted device environment.');
      }
    }
  }

  Uri _buildUri(String host, String path) {
    String cleanHost = host.replaceAll('http://', '').replaceAll('https://', '');
    final isLocal = cleanHost.contains('localhost') || 
                    cleanHost.contains('10.0.2.2') || 
                    cleanHost.contains('192.168.') || 
                    cleanHost.contains(':3000') || 
                    cleanHost.contains(':8000');
    
    if (isLocal) {
      return Uri.http(cleanHost, path);
    } else {
      return Uri.https(cleanHost, path);
    }
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stateStr = prefs.getString(_stateKey);
    if (stateStr != null) {
      _state = AppState.fromJson(json.decode(stateStr));
    } else {
      _state = AppState(workspaces: []);
    }

    _deviceId = prefs.getString('device_id');
    if (_deviceId == null) {
      _deviceId = const Uuid().v4();
      await prefs.setString('device_id', _deviceId!);
    }
  }

  String get deviceId => _deviceId ?? 'unknown';
  List<Workspace> get workspaces => _state?.workspaces ?? [];
  Workspace? get activeWorkspace {
    if (_state?.activeWorkspaceId == null) return null;
    return _state?.workspaces.firstWhere(
      (w) => w.id == _state!.activeWorkspaceId,
      orElse: () => _state!.workspaces.first,
    );
  }

  Future<void> _saveState() async {
    if (_state != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_stateKey, json.encode(_state!.toJson()));
    }
  }

  Future<void> addWorkspace(Workspace workspace) async {
    if (_state == null) {
      await init();
    }
    final workspaces = List<Workspace>.from(_state!.workspaces);
    workspaces.removeWhere((w) => w.id == workspace.id);
    workspaces.add(workspace);
    _state = AppState(
      workspaces: workspaces,
      activeWorkspaceId: workspace.id,
    );
    await _saveState();
  }

  Future<void> switchWorkspace(String id) async {
    if (_state == null) {
      await init();
    }
    _state = AppState(
      workspaces: _state!.workspaces,
      activeWorkspaceId: id,
    );
    await _saveState();
  }

  Future<void> clearSession() async {
    if (_state == null) return;
    _state = AppState(
      workspaces: _state!.workspaces,
      activeWorkspaceId: null,
    );
    await _saveState();
  }

  Future<void> _handleBannedState() async {
    await clearSession();
    DerasyApp.navigatorKey.currentState?.pushNamedAndRemoveUntil('/banned', (route) => false);
  }

  Future<void> clearAll() async {
    _state = AppState(workspaces: []);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_stateKey);
  }

  Future<void> removeWorkspace(String id) async {
    final workspaces = List<Workspace>.from(_state!.workspaces);
    workspaces.removeWhere((w) => w.id == id);
    
    String? newActiveId = _state?.activeWorkspaceId;
    if (newActiveId == id) {
       newActiveId = workspaces.isNotEmpty ? workspaces.first.id : null;
    }

    _state = AppState(
      workspaces: workspaces,
      activeWorkspaceId: newActiveId,
    );
    await _saveState();
  }

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Workspace? overrideWorkspace,
  }) async {
    await _checkDeviceSafety();
    final workspace = overrideWorkspace ?? activeWorkspace;
    final String host = workspace?.host ?? kSiteHost;

    final uri = _buildUri(host, '/api$path');
    final String siteUrl = 'https://$host';
    final headers = {
      'Accept': 'application/json',
      'site_link': siteUrl,
      'site-link': siteUrl,
      'X-Site-Link': siteUrl,
      if (workspace != null) 'Authorization': 'Bearer ${workspace.token}',
    };

    if (method == 'POST') {
      headers['Content-Type'] = 'application/json';
    }

    http.Response response;
    int retryCount = 0;
    while (true) {
      try {
        if (method == 'POST') {
          debugPrint('>>> POST $uri');
          response = await http.post(uri, headers: headers, body: json.encode(body)).timeout(const Duration(seconds: 20));
        } else {
          debugPrint('>>> GET $uri');
          if (path == '/site-settings') {
            debugPrint('⚙️ [SITE SETTINGS REQ] GET $uri');
            debugPrint('⚙️ [SITE SETTINGS REQ HEADERS] $headers');
          }
          response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));
        }

        // Handle redirects (standard HTTP location header or Next.js JSON redirect)
        if (response.statusCode == 301 || response.statusCode == 302 || response.statusCode == 307 || response.statusCode == 308) {
          try {
            String? redirectUrlStr = response.headers['location'];
            if (redirectUrlStr == null) {
              try {
                final data = json.decode(response.body);
                redirectUrlStr = data['redirect'] ?? data['url'];
              } catch (_) {}
            }
            if (redirectUrlStr != null) {
              final redirectUri = Uri.parse(redirectUrlStr);
              debugPrint('🔄 FOLLOW REDIRECT TO: $redirectUri');
              
              final redirectHeaders = Map<String, String>.from(headers);
              if (method == 'POST') {
                response = await http.post(redirectUri, headers: redirectHeaders, body: json.encode(body)).timeout(const Duration(seconds: 20));
              } else {
                response = await http.get(redirectUri, headers: redirectHeaders).timeout(const Duration(seconds: 20));
              }
              debugPrint('📥 REDIRECT RESPONSE STATUS: ${response.statusCode}');
            }
          } catch (e) {
            debugPrint('Failed to follow redirect in request(): $e');
          }
        }

        break; // Success
      } catch (e) {
        retryCount++;
        if (retryCount >= 3 || method == 'POST') rethrow; // Don't retry POSTs to avoid duplicate actions
        debugPrint('>>> Retry $retryCount due to: $e');
        await Future.delayed(Duration(seconds: retryCount));
      }
    }

    debugPrint('<<< Status: ${response.statusCode}');
    debugPrint('<<< Body: ${response.body}');
    if (path == '/site-settings') {
      debugPrint('⚙️ [SITE SETTINGS RES STATUS] ${response.statusCode}');
      debugPrint('⚙️ [SITE SETTINGS RES BODY] ${response.body}');
    }
    if (response.statusCode == 401) {
      await clearSession();
      throw SessionExpiredException();
    }

    dynamic data;
    try {
      data = json.decode(response.body);
    } catch (e) {
      debugPrint('❌ Failed to decode JSON: ${e.toString()}');
      debugPrint('📄 Response body (first 100 chars): ${response.body.length > 100 ? response.body.substring(0, 100) : response.body}');
      if (response.statusCode == 403) {
        await _handleBannedState();
        throw UserBannedException();
      }
      throw Exception('Invalid server response (not JSON): ${response.body}');
    }

    if (response.statusCode == 403) {
      bool isBan = false;
      if (data is Map) {
        final user = data['user'] as Map<String, dynamic>?;
        if (user != null) {
          final isBanned = user['is_banned'];
          if (isBanned == 1 || isBanned == true || isBanned.toString() == '1' || isBanned.toString().toLowerCase() == 'true') {
            isBan = true;
          }
        }
        final errorRaw = (data['error'] ?? data['message'] ?? '').toString();
        final errorMsg = errorRaw.toLowerCase();
        if (errorRaw.contains('حظر') || errorMsg.contains('banned') || errorMsg.contains('blocked') || errorMsg.contains('suspend') || errorMsg.contains('suspended')) {
          isBan = true;
        }
      }
      if (isBan) {
        await _handleBannedState();
        throw UserBannedException();
      } else {
        final errorRaw = (data is Map ? (data['error'] ?? data['message'] ?? '') : '').toString();
        throw Exception(errorRaw.isNotEmpty ? errorRaw : 'Access forbidden');
      }
    }

    if (data is Map) {
      final user = data['user'] as Map<String, dynamic>?;
      if (user != null) {
        final isBanned = user['is_banned'];
        if (isBanned == 1 || isBanned == true || isBanned.toString() == '1' || isBanned.toString().toLowerCase() == 'true') {
          await _handleBannedState();
          throw UserBannedException();
        }
      }
    }

    final errorRaw = (data is Map ? (data['error'] ?? data['message'] ?? '') : '').toString();
    final errorMsg = errorRaw.toLowerCase();
    
    if (errorRaw.contains('حظر') || errorMsg.contains('banned') || errorMsg.contains('blocked') || errorMsg.contains('suspend') || errorMsg.contains('suspended')) {
      await _handleBannedState();
      throw UserBannedException();
    }

    final fullErrText = (data is Map ? ('${data['error'] ?? ''} ${data['message'] ?? ''}') : '').toLowerCase();
    if (fullErrText.contains('mismatch') || fullErrText.contains('linked to another device') || fullErrText.contains('disconnect the old device') || fullErrText.contains('another device')) {
      await clearSession();
      DerasyApp.navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false, arguments: 'device_mismatch');
      throw DeviceMismatchException(
        (data is Map && data['message'] != null && data['message'].toString().isNotEmpty)
            ? data['message'].toString()
            : 'This account is already linked to another device. Please disconnect the old device first.'
      );
    }
    
    if (response.statusCode >= 400) {
      final formattedMsg = extractErrorMessage(data is Map ? Map<String, dynamic>.from(data) : {}, 'API Error (${response.statusCode})');
      debugPrint('❌ API ERROR [${response.statusCode}] $path: $formattedMsg');
      if (response.statusCode >= 500) {
        throw ServerException(formattedMsg, response.statusCode);
      }
      throw Exception(formattedMsg);
    }
    return data;
  }

  Future<Map<String, dynamic>> login(String host, String email, String password) async {
      await _checkDeviceSafety();
      final uri = _buildUri(host, '/api/auth/login');
      
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      String model = 'unknown';
      String os = Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iOS' : 'unknown');
      String osVersion = 'unknown';
      String manufacturer = 'unknown';

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        model = androidInfo.model;
        osVersion = androidInfo.version.release;
        manufacturer = androidInfo.manufacturer;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        model = iosInfo.utsname.machine;
        osVersion = iosInfo.systemVersion;
        manufacturer = 'Apple';
      }

      final body = {
        'email': email,
        'password': password,
        'device_id': deviceId,
        'hwid': deviceId,
        'device_model': model,
        'device_os': os,
        'device_os_version': osVersion,
        'device_manufacturer': manufacturer,
        'device_assigned_at': DateTime.now().toIso8601String(),
        'last_device_change_at': DateTime.now().toIso8601String(),
      };

      debugPrint('-----------------------------------------');
      debugPrint('🚀 LOGIN API CALL (MOBILE): $uri');
      debugPrint('📦 BODY: ${json.encode(body)}');
      
      var response = await http.post(
        uri,
        headers: {
          'Host': host,
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'site_link': kSiteUrl,
          'site-link': kSiteUrl,
          'X-Site-Link': kSiteUrl,
        },
        body: json.encode(body),
      );

      var finalHost = host;
      if (response.statusCode == 301 || response.statusCode == 302 || response.statusCode == 307 || response.statusCode == 308) {
        try {
          String? redirectUrlStr = response.headers['location'];
          if (redirectUrlStr == null) {
            try {
              final redirectData = json.decode(response.body);
              redirectUrlStr = redirectData['redirect'] ?? redirectData['url'];
            } catch (_) {}
          }
          if (redirectUrlStr != null) {
            final redirectUri = Uri.parse(redirectUrlStr);
            debugPrint('🔄 FOLLOW REDIRECT IN LOGIN TO: $redirectUri');
            finalHost = redirectUri.host;
            response = await http.post(
              redirectUri,
              headers: {
                'Host': redirectUri.host,
                'Accept': 'application/json',
                'Content-Type': 'application/json',
          'site_link': kSiteUrl,
          'site-link': kSiteUrl,
          'X-Site-Link': kSiteUrl,
              },
              body: json.encode(body),
            );
          }
        } catch (e) {
          debugPrint('Failed to follow redirect in login(): $e');
        }
      }

      debugPrint('-----------------------------------------');
      debugPrint('🚀 LOGIN API CALL: $uri');
      debugPrint('📥 STATUS: ${response.statusCode}');
      debugPrint('📦 RESPONSE: ${response.body}');
      debugPrint('-----------------------------------------');

      if (response.statusCode == 403) {
        await _handleBannedState();
        throw UserBannedException();
      }

      final Map<String, dynamic> data = Map<String, dynamic>.from(json.decode(response.body));
      data['redirectedHost'] = finalHost;
      
      final errorRaw = (data['error'] ?? data['message'] ?? '').toString();
      final errorMsg = errorRaw.toLowerCase();
      if (errorRaw.contains('حظر') || errorMsg.contains('banned') || errorMsg.contains('blocked') || errorMsg.contains('suspend') || errorMsg.contains('suspended')) {
        await _handleBannedState();
        throw UserBannedException();
      }

      final fullErrText = ('${data['error'] ?? ''} ${data['message'] ?? ''}').toLowerCase();
      if (fullErrText.contains('mismatch') || fullErrText.contains('linked to another device') || fullErrText.contains('disconnect the old device') || fullErrText.contains('another device')) {
        throw DeviceMismatchException(
          (data['message'] != null && data['message'].toString().isNotEmpty)
              ? data['message'].toString()
              : 'This account is already linked to another device. Please disconnect the old device first.'
        );
      }

      final user = data['user'] as Map<String, dynamic>?;
      if (user != null) {
        final isBanned = user['is_banned'];
        if (isBanned == 1 || isBanned == true || isBanned.toString() == '1' || isBanned.toString().toLowerCase() == 'true') {
          await _handleBannedState();
          throw UserBannedException();
        }
      }

      if (response.statusCode >= 500) throw ServerException(data['message'] ?? 'Login server error', response.statusCode);
      if (response.statusCode != 200) {
        throw Exception(data['error'] ?? 'Login failed');
      }
      return data;
  }

  Future<Map<String, dynamic>> loginWithGoogle({
    required String host,
    required String email,
    required String name,
    required String googleId,
  }) async {
    await _checkDeviceSafety();
    final uri = _buildUri(host, '/api/auth/google');

    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String model = 'unknown';
    String os = Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iOS' : 'unknown');
    String osVersion = 'unknown';
    String manufacturer = 'unknown';

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      model = androidInfo.model;
      osVersion = androidInfo.version.release;
      manufacturer = androidInfo.manufacturer;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      model = iosInfo.utsname.machine;
      osVersion = iosInfo.systemVersion;
      manufacturer = 'Apple';
    }

    final body = {
      'email': email,
      'name': name,
      'googleId': googleId,
      'device_id': deviceId,
      'hwid': deviceId,
      'device_model': model,
      'device_os': os,
      'device_os_version': osVersion,
      'device_manufacturer': manufacturer,
      'device_assigned_at': DateTime.now().toIso8601String(),
      'last_device_change_at': DateTime.now().toIso8601String(),
    };

    debugPrint('-----------------------------------------');
    debugPrint('🚀 GOOGLE LOGIN API CALL: $uri');
    debugPrint('📦 BODY: ${json.encode(body)}');

    var response = await http.post(
      uri,
      headers: {
        'Host': host,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
          'site_link': kSiteUrl,
          'site-link': kSiteUrl,
          'X-Site-Link': kSiteUrl,
      },
      body: json.encode(body),
    );

    var finalHost = host;
    if (response.statusCode == 301 || response.statusCode == 302 || response.statusCode == 307 || response.statusCode == 308) {
      try {
        String? redirectUrlStr = response.headers['location'];
        if (redirectUrlStr == null) {
          try {
            final redirectData = json.decode(response.body);
            redirectUrlStr = redirectData['redirect'] ?? redirectData['url'];
          } catch (_) {}
        }
        if (redirectUrlStr != null) {
          final redirectUri = Uri.parse(redirectUrlStr);
          debugPrint('🔄 FOLLOW REDIRECT IN GOOGLE LOGIN TO: $redirectUri');
          finalHost = redirectUri.host;
          response = await http.post(
            redirectUri,
            headers: {
              'Host': redirectUri.host,
              'Accept': 'application/json',
              'Content-Type': 'application/json',
          'site_link': kSiteUrl,
          'site-link': kSiteUrl,
          'X-Site-Link': kSiteUrl,
            },
            body: json.encode(body),
          );
        }
      } catch (e) {
        debugPrint('Failed to follow redirect in loginWithGoogle(): $e');
      }
    }

    debugPrint('📥 STATUS: ${response.statusCode}');
    debugPrint('📦 RESPONSE: ${response.body}');
    debugPrint('-----------------------------------------');

    if (response.statusCode == 403) {
      await _handleBannedState();
      throw UserBannedException();
    }

    final Map<String, dynamic> data = Map<String, dynamic>.from(json.decode(response.body));
    data['redirectedHost'] = finalHost;
    
    final errorRaw = (data['error'] ?? data['message'] ?? '').toString();
    final errorMsg = errorRaw.toLowerCase();
    if (errorRaw.contains('حظر') || errorMsg.contains('banned') || errorMsg.contains('blocked') || errorMsg.contains('suspend') || errorMsg.contains('suspended')) {
      await _handleBannedState();
      throw UserBannedException();
    }

    final fullErrText = ('${data['error'] ?? ''} ${data['message'] ?? ''}').toLowerCase();
    if (fullErrText.contains('mismatch') || fullErrText.contains('linked to another device') || fullErrText.contains('disconnect the old device') || fullErrText.contains('another device')) {
      throw DeviceMismatchException(
        (data['message'] != null && data['message'].toString().isNotEmpty)
            ? data['message'].toString()
            : 'This account is already linked to another device. Please disconnect the old device first.'
      );
    }

    final user = data['user'] as Map<String, dynamic>?;
    if (user != null) {
      final isBanned = user['is_banned'];
      if (isBanned == 1 || isBanned == true || isBanned.toString() == '1' || isBanned.toString().toLowerCase() == 'true') {
        await _handleBannedState();
        throw UserBannedException();
      }
    }

    if (response.statusCode >= 500) throw ServerException(data['message'] ?? 'Google login server error', response.statusCode);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(data['error'] ?? data['message'] ?? 'Google login failed');
    }
    return data;
  }

  Future<Map<String, dynamic>> register({
    required String host,
    required String name,
    required String email,
    required String password,
    required String phone,
    required String birthDate,
  }) async {
    await _checkDeviceSafety();
    final uri = _buildUri(host, '/api/auth/register');

    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String model = 'unknown';
    String os = Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iOS' : 'unknown');
    String osVersion = 'unknown';
    String manufacturer = 'unknown';

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      model = androidInfo.model;
      osVersion = androidInfo.version.release;
      manufacturer = androidInfo.manufacturer;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      model = iosInfo.utsname.machine;
      osVersion = iosInfo.systemVersion;
      manufacturer = 'Apple';
    }

    final body = {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': password,
      'phone': phone,
      'birthDate': birthDate,
      'birth_date': birthDate,
      'date_of_birth': birthDate,
      'device_id': deviceId,
      'hwid': deviceId,
      'device_model': model,
      'device_os': os,
      'device_os_version': osVersion,
      'device_manufacturer': manufacturer,
      'device_assigned_at': DateTime.now().toIso8601String(),
      'last_device_change_at': DateTime.now().toIso8601String(),
    };

    debugPrint('-----------------------------------------');
    debugPrint('🚀 REGISTER API CALL: $uri');
    debugPrint('📦 BODY: ${json.encode(body)}');

    var response = await http.post(
      uri,
      headers: {
        'Host': host,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
          'site_link': kSiteUrl,
          'site-link': kSiteUrl,
          'X-Site-Link': kSiteUrl,
      },
      body: json.encode(body),
    );

    var finalHost = host;
    if (response.statusCode == 301 || response.statusCode == 302 || response.statusCode == 307 || response.statusCode == 308) {
      try {
        String? redirectUrlStr = response.headers['location'];
        if (redirectUrlStr == null) {
          try {
            final redirectData = json.decode(response.body);
            redirectUrlStr = redirectData['redirect'] ?? redirectData['url'];
          } catch (_) {}
        }
        if (redirectUrlStr != null) {
          final redirectUri = Uri.parse(redirectUrlStr);
          debugPrint('🔄 FOLLOW REDIRECT IN REGISTER TO: $redirectUri');
          finalHost = redirectUri.host;
          response = await http.post(
            redirectUri,
            headers: {
              'Host': host,
              'Accept': 'application/json',
              'Content-Type': 'application/json',
          'site_link': kSiteUrl,
          'site-link': kSiteUrl,
          'X-Site-Link': kSiteUrl,
            },
            body: json.encode(body),
          );
        }
      } catch (e) {
        debugPrint('Failed to follow redirect in register(): $e');
      }
    }

    debugPrint('📥 STATUS: ${response.statusCode}');
    debugPrint('📦 RESPONSE: ${response.body}');
    debugPrint('-----------------------------------------');

    if (response.statusCode == 403) {
      await _handleBannedState();
      throw UserBannedException();
    }

    final Map<String, dynamic> data = parseJsonResponse(response);
    data['redirectedHost'] = finalHost;
    
    final errorRaw = (data['error'] ?? data['message'] ?? '').toString();
    final errorMsg = errorRaw.toLowerCase();
    if (errorRaw.contains('حظر') || errorMsg.contains('banned') || errorMsg.contains('blocked') || errorMsg.contains('suspend') || errorMsg.contains('suspended')) {
      await _handleBannedState();
      throw UserBannedException();
    }

    final fullErrText = ('${data['error'] ?? ''} ${data['message'] ?? ''}').toLowerCase();
    if (fullErrText.contains('mismatch') || fullErrText.contains('linked to another device') || fullErrText.contains('disconnect the old device') || fullErrText.contains('another device')) {
      throw DeviceMismatchException(
        (data['message'] != null && data['message'].toString().isNotEmpty)
            ? data['message'].toString()
            : 'This account is already linked to another device. Please disconnect the old device first.'
      );
    }

    final user = data['user'] as Map<String, dynamic>?;
    if (user != null) {
      final isBanned = user['is_banned'];
      if (isBanned == 1 || isBanned == true || isBanned.toString() == '1' || isBanned.toString().toLowerCase() == 'true') {
        await _handleBannedState();
        throw UserBannedException();
      }
    }

    if (response.statusCode >= 500) throw ServerException(extractErrorMessage(data, 'خطأ في سيرفر التسجيل (${response.statusCode})'), response.statusCode);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(extractErrorMessage(data, 'فشل إنشاء الحساب'));
    }
    return data;
    return data;
  }

  Future<Map<String, dynamic>> sendOtp(String host, String email) async {
    await _checkDeviceSafety();
    final uri = _buildUri(host, '/api/auth/otp/send');
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String model = 'unknown';
    String os = Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iOS' : 'unknown');
    String osVersion = 'unknown';
    String manufacturer = 'unknown';
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      model = androidInfo.model;
      osVersion = androidInfo.version.release;
      manufacturer = androidInfo.manufacturer;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      model = iosInfo.utsname.machine;
      osVersion = iosInfo.systemVersion;
      manufacturer = 'Apple';
    }

    final body = {
      'email': email,
      'device_id': deviceId,
      'hwid': deviceId,
      'device_model': model,
      'device_os': os,
      'device_os_version': osVersion,
      'device_manufacturer': manufacturer,
      'device_assigned_at': DateTime.now().toIso8601String(),
      'last_device_change_at': DateTime.now().toIso8601String(),
    };
    debugPrint('🚀 SEND OTP API CALL: $uri');
    var response = await http.post(
      uri,
      headers: {
        'Host': host,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
          'site_link': kSiteUrl,
          'site-link': kSiteUrl,
          'X-Site-Link': kSiteUrl,
      },
      body: json.encode(body),
    );
    
    if (response.statusCode == 301 || response.statusCode == 302 || response.statusCode == 307 || response.statusCode == 308) {
      try {
        String? redirectUrlStr = response.headers['location'];
        if (redirectUrlStr != null) {
          final redirectUri = Uri.parse(redirectUrlStr);
          debugPrint('🔄 FOLLOW REDIRECT IN SEND OTP TO: $redirectUri');
          response = await http.post(
            redirectUri,
            headers: {
              'Host': host,
              'Accept': 'application/json',
              'Content-Type': 'application/json',
          'site_link': kSiteUrl,
          'site-link': kSiteUrl,
          'X-Site-Link': kSiteUrl,
            },
            body: json.encode(body),
          );
        }
      } catch (e) {
        debugPrint('Failed to follow redirect in sendOtp: $e');
      }
    }

    debugPrint('📥 OTP SEND STATUS: ${response.statusCode}');
    if (response.statusCode == 403) {
      throw UserBannedException();
    }
    final Map<String, dynamic> data = parseJsonResponse(response);
    if (response.statusCode >= 500) throw ServerException(extractErrorMessage(data, 'خطأ في سيرفر إرسال كود التحقق (${response.statusCode})'), response.statusCode);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(extractErrorMessage(data, 'فشل إرسال كود التحقق'));
    }
    return data;
  }

  Future<Map<String, dynamic>> verifyOtpAndRegister({
    required String host,
    required String name,
    required String email,
    required String password,
    required String phone,
    required String otp,
    required String birthDate,
  }) async {
    await _checkDeviceSafety();
    final uri = _buildUri(host, '/api/auth/otp/verify');
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String model = 'unknown';
    String os = Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iOS' : 'unknown');
    String osVersion = 'unknown';
    String manufacturer = 'unknown';
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      model = androidInfo.model;
      osVersion = androidInfo.version.release;
      manufacturer = androidInfo.manufacturer;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      model = iosInfo.utsname.machine;
      osVersion = iosInfo.systemVersion;
      manufacturer = 'Apple';
    }
    final body = {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': password,
      'phone': phone,
      'otp': otp,
      'birthDate': birthDate,
      'birth_date': birthDate,
      'date_of_birth': birthDate,
      'device_id': deviceId,
      'hwid': deviceId,
      'device_model': model,
      'device_os': os,
      'device_os_version': osVersion,
      'device_manufacturer': manufacturer,
      'device_assigned_at': DateTime.now().toIso8601String(),
      'last_device_change_at': DateTime.now().toIso8601String(),
    };
    debugPrint('🚀 VERIFY OTP API CALL: $uri');
    var response = await http.post(
      uri,
      headers: {
        'Host': host,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
          'site_link': kSiteUrl,
          'site-link': kSiteUrl,
          'X-Site-Link': kSiteUrl,
      },
      body: json.encode(body),
    );
    var finalHost = host;
    if (response.statusCode == 301 || response.statusCode == 302 || response.statusCode == 307 || response.statusCode == 308) {
      try {
        String? redirectUrlStr = response.headers['location'];
        if (redirectUrlStr == null) {
          try {
            final redirectData = json.decode(response.body);
            redirectUrlStr = redirectData['redirect'] ?? redirectData['url'];
          } catch (_) {}
        }
        if (redirectUrlStr != null) {
          final redirectUri = Uri.parse(redirectUrlStr);
          finalHost = redirectUri.host;
          response = await http.post(
            redirectUri,
            headers: {
              'Host': host,
              'Accept': 'application/json',
              'Content-Type': 'application/json',
          'site_link': kSiteUrl,
          'site-link': kSiteUrl,
          'X-Site-Link': kSiteUrl,
            },
            body: json.encode(body),
          );
        }
      } catch (e) {
        debugPrint('Failed to follow redirect in verifyOtpAndRegister(): $e');
      }
    }
    debugPrint('📥 OTP VERIFY STATUS: ${response.statusCode}');
    if (response.statusCode == 403) {
      throw UserBannedException();
    }
    final Map<String, dynamic> data = parseJsonResponse(response);
    data['redirectedHost'] = finalHost;
    final user = data['user'] as Map<String, dynamic>?;
    if (user != null) {
      final isBanned = user['is_banned'];
      if (isBanned == 1 || isBanned == true || isBanned.toString() == '1' || isBanned.toString().toLowerCase() == 'true') {
        throw UserBannedException();
      }
    }
    if (response.statusCode >= 500) throw ServerException(extractErrorMessage(data, 'خطأ في سيرفر التحقق (${response.statusCode})'), response.statusCode);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(extractErrorMessage(data, 'فشل التحقق وإنشاء الحساب'));
    }
    return data;
    return data;
  }

  Future<Map<String, dynamic>> getPlayback(String code) async {
    return await request('GET', '/courses/playback/$code');
  }

  // REVISED FLOW: /api/courses/[id]/learn
  Future<Map<String, dynamic>> getCourseLearn(int id) async {
    return await request('GET', '/courses/$id/learn');
  }

  Future<Map<String, dynamic>> getDashboard() async {
    final futures = [
      request('GET', '/dashboard/stats'),
      request('GET', '/dashboard/courses').catchError((_) => {'courses': []}),
      request('GET', '/courses').catchError((_) => {'courses': [], 'categories': []}),
    ];

    final results = await Future.wait(futures);
    
    final statsRes = Map<String, dynamic>.from(results[0]);
    final coursesRes = results[1] as Map<String, dynamic>;
    final allRes = results[2] as Map<String, dynamic>;

    statsRes['courses'] = coursesRes['courses'] ?? [];
    statsRes['all_courses'] = allRes['courses'] ?? [];
    statsRes['categories'] = allRes['categories'] ?? [];
    
    return statsRes;
  }

  Future<Map<String, dynamic>> getAllCourses() async {
    return await request('GET', '/courses');
  }

  Future<Map<String, dynamic>> getCourse(int id) async {
    return await request('GET', '/courses/$id');
  }

  Future<void> markProgress(int courseId, int materialId) async {
    await request('POST', '/courses/$courseId/progress', body: {
      'materialId': materialId,
    });
  }

  Future<Map<String, dynamic>> toggleFavorite(int courseId) async {
    return await request('POST', '/courses/favorite', body: {'courseId': courseId});
  }

  Future<Map<String, dynamic>> getFavorites() async {
    return await request('GET', '/courses/favorite');
  }

  Future<Map<String, dynamic>> getSiteSettings() async {
    return await request('GET', '/site-settings');
  }

  Future<Map<String, dynamic>> getPublicSiteSettings(String host) async {
    await _checkDeviceSafety();
    final uri = Uri.https(host, '/api/site-settings');
    debugPrint('⚙️ [PUBLIC SITE SETTINGS REQ] GET $uri');
    final response = await http.get(uri, headers: {
      'Accept': 'application/json',
      'site_link': kSiteUrl,
      'site-link': kSiteUrl,
      'X-Site-Link': kSiteUrl,
    }).timeout(const Duration(seconds: 15));
    debugPrint('⚙️ [PUBLIC SITE SETTINGS RES] Status: ${response.statusCode}');
    debugPrint('⚙️ [PUBLIC SITE SETTINGS RES BODY]: ${response.body}');
    if (response.statusCode == 200) {
      return parseJsonResponse(response);
    }
    throw Exception('Failed to load site settings: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> getMobileSettings(String host) async {
    await _checkDeviceSafety();
    final uri = Uri.https(host, '/api/mobile/settings');
    debugPrint('📱 [MOBILE SETTINGS REQ] GET $uri');
    final response = await http.get(uri, headers: {
      'Accept': 'application/json',
      'site_link': kSiteUrl,
      'site-link': kSiteUrl,
      'X-Site-Link': kSiteUrl,
    }).timeout(const Duration(seconds: 15));
    debugPrint('📱 [MOBILE SETTINGS RES] Status: ${response.statusCode}');
    debugPrint('📱 [MOBILE SETTINGS RES BODY]: ${response.body}');
    if (response.statusCode == 200) {
      return parseJsonResponse(response);
    }
    throw Exception('Failed to load mobile settings: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> redeemCoupon(String code, {int? courseId}) async {
    final workspace = activeWorkspace;
    final String host = workspace?.host ?? kSiteHost;
    
    final Map<String, dynamic> body = {
      'code': code,
      'site_link': host,
      'site_url': 'https://$host',
      'subdomain': workspace?.tenant ?? '',
    };
    
    if (courseId != null) {
      body['courseId'] = courseId.toString();
      body['course_id'] = courseId.toString();
    }

    return await request('POST', '/coupons/redeem', body: body);
  }

  Future<Map<String, dynamic>> redeemVoucher(String code) async {
    return await request('POST', '/vouchers/redeem', body: {'code': code});
  }

  Future<Map<String, dynamic>> checkoutWallet(int courseId) async {
    return await request('POST', '/checkout/wallet', body: {'courseId': courseId});
  }

  // REVISED FLOW: /api/courses/unenroll
  Future<Map<String, dynamic>> unenroll(int courseId) async {
    return await request('POST', '/courses/unenroll', body: {'courseId': courseId});
  }

  Future<Map<String, dynamic>> getWalletTransactions() async {
    return await request('GET', '/wallet/status');
  }

  Future<Map<String, dynamic>> getWalletBalance() async {
    return await request('GET', '/wallet/status');
  }

  // REVISED FLOW: /api/categories
  Future<Map<String, dynamic>> getCategories() async {
    return await request('GET', '/categories');
  }

  // REVISED FLOW: /api/quizzes/[id]/submit
  Future<Map<String, dynamic>> getQuiz(int quizId) async {
    return await request('GET', '/quizzes/$quizId');
  }

  Future<Map<String, dynamic>> submitQuiz(int quizId, dynamic answers) async {
    return await request('POST', '/quizzes/$quizId/submit', body: {'answers': answers});
  }

  // REVISED FLOW: /api/assignments/[id]
  Future<Map<String, dynamic>> getAssignment(int assignmentId) async {
    return await request('GET', '/assignments/$assignmentId');
  }

  // REVISED FLOW: /api/assignments/[id]/submit
  Future<Map<String, dynamic>> submitAssignment(int assignmentId, Map<String, dynamic> submissionData) async {
    return await request('POST', '/assignments/$assignmentId/submit', body: submissionData);
  }

  // REVISED FLOW: /api/assignments/[id]/submit with Multipart File Upload
  Future<Map<String, dynamic>> submitAssignmentMultipart(
    int assignmentId,
    String textAnswer,
    String? filePath,
  ) async {
    await _checkDeviceSafety();
    final workspace = activeWorkspace;
    if (workspace == null) throw Exception('No active workspace');

    final uri = Uri.https(workspace.host, '/api/assignments/$assignmentId/submit');
    
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer ${workspace.token}';
    request.headers['Accept'] = 'application/json';

    request.fields['text_answer'] = textAnswer;

    if (filePath != null && filePath.isNotEmpty) {
      final file = File(filePath);
      if (await file.exists()) {
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          file.path,
        ));
      }
    }

    debugPrint('>>> MULTIPART POST $uri');
    final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint('<<< Status: ${response.statusCode}');
    debugPrint('<<< Response: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to submit assignment: ${response.body}');
    }
  }

  // REVISED FLOW: /api/courses/[id]/reviews
  Future<Map<String, dynamic>> getReviews(int courseId) async {
    return await request('GET', '/courses/$courseId/reviews');
  }

  Future<Map<String, dynamic>> submitReview(int courseId, int rating, String comment) async {
    return await request('POST', '/courses/$courseId/reviews', body: {
      'rating': rating,
      'comment': comment,
    });
  }

  // REVISED FLOW: /api/imagekit/auth
  Future<Map<String, dynamic>> getImageKitAuth() async {
    return await request('GET', '/imagekit/auth');
  }

  // REVISED FLOW: /api/auth/me
  Future<Map<String, dynamic>> getMe() async {
    return await request('GET', '/auth/me');
  }

  Future<Map<String, dynamic>> updateProfile({String? name, String? phone, String? avatarUrl}) async {
    final body = <String, dynamic>{};
    if (name != null && name.isNotEmpty) {
      body['name'] = name;
      body['full_name'] = name;
    }
    if (phone != null && phone.isNotEmpty) {
      body['phone'] = phone;
      body['phone_number'] = phone;
      body['mobile'] = phone;
    }
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      body['avatar_url'] = avatarUrl;
      body['avatar'] = avatarUrl;
      body['image'] = avatarUrl;
      body['profile_photo'] = avatarUrl;
    }
    debugPrint('🚀 UPDATE PROFILE CALL: /api/auth/profile');
    debugPrint('📦 BODY: ${json.encode(body)}');
    return await request('POST', '/auth/profile', body: body);
  }

  // REVISED FLOW: /api/auth/batches
  Future<Map<String, dynamic>> getGroups() async {
    return await request('GET', '/auth/batches');
  }

  Future<Map<String, dynamic>> joinGroup(int groupId) async {
    return await request('POST', '/auth/batches', body: {'groupId': groupId});
  }

  // REVISED FLOW: /api/schedule
  Future<Map<String, dynamic>> getSchedule() async {
    return await request('GET', '/schedule');
  }

  Future<void> setConnectData({
    List<int>? enrolledCourses,
    String? bio,
    String? coverUrl,
    Workspace? workspace,
  }) async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String model = 'unknown';
    String os = Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iOS' : 'unknown');
    String osVersion = 'unknown';
    String manufacturer = 'unknown';

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      model = androidInfo.model;
      osVersion = androidInfo.version.release;
      manufacturer = androidInfo.manufacturer;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      model = iosInfo.utsname.machine;
      osVersion = iosInfo.systemVersion;
      manufacturer = 'Apple';
    }

    final body = {
      'hwid': deviceId,
      'device_model': model,
      'device_os': os,
      'device_os_version': osVersion,
      'device_manufacturer': manufacturer,
      'device_assigned_at': DateTime.now().toIso8601String(),
      'last_device_change_at': DateTime.now().toIso8601String(),
      'enrolled_courses': enrolledCourses ?? [],
      'bio': bio ?? '',
      'cover_url': coverUrl ?? '',
    };

    debugPrint('-----------------------------------------');
    debugPrint('📱 SYNC DEVICE DATA (MOBILE API): /auth/mobile/set-connect-data');
    debugPrint('📦 PAYLOAD: ${json.encode(body)}');
    debugPrint('-----------------------------------------');

    await request('POST', '/auth/mobile/set-connect-data', body: body, overrideWorkspace: workspace);
  }

  // SECURITY: /api/mobile/security-alerts
  Future<void> reportSecurityAlert(String incidentType, {String description = ''}) async {
    try {
      await request('POST', '/mobile/security-alerts', body: {
        'incident_type': incidentType,
        'description': description,
      });
      debugPrint('🔒 Security alert reported: $incidentType');
    } catch (e) {
      debugPrint('⚠️ Failed to report security alert: $e');
    }
  }
}
