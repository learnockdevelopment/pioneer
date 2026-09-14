import 'package:flutter/material.dart';
import 'package:elmasa/models/workspace.dart';
import 'package:elmasa/providers/theme_provider.dart';
import 'package:elmasa/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'dart:convert';

class WorkspaceProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _cachedDashboard;
  Map<String, dynamic>? _cachedFavorites;
  Map<String, dynamic>? _cachedWallet;
  Map<String, dynamic>? _cachedME;
  Map<String, dynamic>? _cachedWalletTransactions;
  Map<String, dynamic>? _cachedGroups;
  bool _isInitialized = false;
  bool _isEagerLoaded = false;
  final Map<int, Map<String, dynamic>> _lastAccessedMaterials = {};
  final Set<int> _localFavoriteIds = {}; // TRUTH FOR OPTIMISTIC FAVS (Shared across screens)


  bool get isInitialized => _isInitialized;
  bool get isEagerLoaded => _isEagerLoaded;
  Map<String, dynamic>? get cachedDashboard => _cachedDashboard;
  Map<String, dynamic>? get cachedFavorites => _cachedFavorites;
  Map<String, dynamic>? get cachedWallet => _cachedWallet;
  Map<String, dynamic>? get cachedME => _cachedME;
  Map<String, dynamic>? get cachedWalletTransactions => _cachedWalletTransactions;
  Map<String, dynamic>? get cachedGroups => _cachedGroups;
  Map<int, Map<String, dynamic>> get lastAccessedMaterials => _lastAccessedMaterials;
  Set<int> get localFavoriteIds => _localFavoriteIds;
  String? _lastErrorMessage;
  String? get lastErrorMessage => _lastErrorMessage;

  // ── GUEST MODE ──────────────────────────────────────────────────────────────
  bool _guestMode = false;
  bool get isGuest => _guestMode && activeWorkspace == null;

  bool _requireLogin = false;
  bool get requireLogin => _requireLogin;

  String? publicSiteName;
  String? publicLogoUrl;
  String? publicCurrency;
  List<dynamic>? publicCourses;
  List<dynamic>? publicCategories;
  List<dynamic>? publicFaqs;

  bool enableRegistration = true;
  bool enableSocialLogin = true;

  bool _watermarkEnabled = false;
  String _watermarkFields = "id,name,phone";
  String _watermarkScope = "all_site";
  int _watermarkIntervalSeconds = 15;

  bool get watermarkEnabled => _watermarkEnabled;
  String get watermarkFields => _watermarkFields;
  String get watermarkScope => _watermarkScope;
  int get watermarkIntervalSeconds => _watermarkIntervalSeconds;

  // ── MOBILE SETTINGS ────────────────────────────────────────────────────────
  String? mobileLatestVersion;
  String? mobileMinSupportedVersion;
  bool mobileForceUpdate = false;
  String? mobileAndroidUrl;
  String? mobileIosUrl;
  bool mobileMaintenanceMode = false;
  String? mobileMaintenanceMessage;
  String? mobileReleaseNotes;


  void setRequireLogin(bool value) {
    _requireLogin = value;
    notifyListeners();
  }

  void enterGuestMode() {
    _guestMode = true;
    _requireLogin = false;
    notifyListeners();
  }

  void exitGuestMode() {
    _guestMode = false;
    notifyListeners();
  }

  void clearError() {
    _lastErrorMessage = null;
    notifyListeners();
  }


  Workspace? get activeWorkspace => _apiService.activeWorkspace;
  List<Workspace> get workspaces => _apiService.workspaces;
  String get deviceId => _apiService.deviceId;

  String get appName {
    if (activeWorkspace != null && activeWorkspace!.name.trim().isNotEmpty) {
      return activeWorkspace!.name.trim();
    }
    if (publicSiteName != null && publicSiteName!.trim().isNotEmpty) {
      return publicSiteName!.trim();
    }
    return '';
  }

  Future<Map<String, dynamic>> getPublicSiteSettings(String host) async {
    final res = await _apiService.getPublicSiteSettings(host);
    try {
      final settings = (res['settings'] is Map ? Map<String, dynamic>.from(res['settings']) : null) ?? 
                       (res['data'] is Map ? Map<String, dynamic>.from(res['data']) : null) ?? 
                       Map<String, dynamic>.from(res);
      
      final siteNameRaw = settings['site_name']?.toString() ?? res['site_name']?.toString() ?? '';
      publicSiteName = (siteNameRaw.trim().toLowerCase() == 'www') ? '' : siteNameRaw.trim();
      publicLogoUrl = settings['logo_url']?.toString() ?? res['logo_url']?.toString();
      final cur = settings['currency']?.toString() ?? settings['currency_symbol']?.toString() ?? settings['currency_code']?.toString() ?? res['currency']?.toString();
      if (cur != null && cur.isNotEmpty) publicCurrency = cur;

      final enableReg = settings['enable_registration'] ?? res['enable_registration'];
      debugPrint('ℹ️ enable_registration raw value: $enableReg (type: ${enableReg.runtimeType})');
      if (enableReg != null) enableRegistration = enableReg == true || enableReg == 1 || enableReg == '1' || enableReg == 'true';
      debugPrint('ℹ️ enableRegistration parsed value: $enableRegistration');
      
      final enableSocial = settings['enable_social_login'] ?? res['enable_social_login'];
      debugPrint('ℹ️ enable_social_login raw value: $enableSocial (type: ${enableSocial.runtimeType})');
      if (enableSocial != null) enableSocialLogin = enableSocial == true || enableSocial == 1 || enableSocial == '1' || enableSocial == 'true';
      debugPrint('ℹ️ enableSocialLogin parsed value: $enableSocialLogin');
      
      final enabledVal = settings['watermark_enabled'] ?? res['watermark_enabled'];
      _watermarkEnabled = enabledVal == 1 || enabledVal == true || enabledVal.toString() == '1' || enabledVal.toString().toLowerCase() == 'true';
      _watermarkFields = settings['watermark_fields']?.toString() ?? res['watermark_fields']?.toString() ?? "id,name,phone";
      _watermarkScope = settings['watermark_scope']?.toString() ?? res['watermark_scope']?.toString() ?? "all_site";
      _watermarkIntervalSeconds = int.tryParse(settings['watermark_interval_seconds']?.toString() ?? res['watermark_interval_seconds']?.toString() ?? '') ?? 15;
      if (_watermarkIntervalSeconds < 3) {
        _watermarkIntervalSeconds = 3;
      }
      
      try {
        final coursesRes = await _apiService.request('GET', '/courses');
        publicCourses = coursesRes['courses'] as List?;
        publicCategories = coursesRes['categories'] as List?;
      } catch (e) {
        debugPrint('Error fetching public courses: $e');
        publicCourses = res['courses'] as List?;
        publicCategories = res['categories'] as List?;
      }
      
      if (res['faqs'] is List) {
        publicFaqs = res['faqs'] as List?;
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error parsing public settings in provider: $e');
    }
    return res;
  }

  Future<Map<String, dynamic>> getMobileSettings(String host) async {
    final res = await _apiService.getMobileSettings(host);
    try {
      final data = (res['data'] is Map ? Map<String, dynamic>.from(res['data']) : null) ?? 
                   (res['raw'] is Map ? Map<String, dynamic>.from(res['raw']) : null) ?? 
                   Map<String, dynamic>.from(res);
                   
      mobileLatestVersion = data['latestVersion']?.toString() ?? data['mobile_app_version']?.toString();
      mobileMinSupportedVersion = data['minSupportedVersion']?.toString() ?? data['mobile_min_version']?.toString();
      
      final forceUp = data['forceUpdate'] ?? data['mobile_force_update'];
      mobileForceUpdate = forceUp == true || forceUp == 1 || forceUp.toString() == '1' || forceUp.toString().toLowerCase() == 'true';
      
      mobileAndroidUrl = data['androidUrl']?.toString() ?? data['mobile_android_url']?.toString();
      mobileIosUrl = data['iosUrl']?.toString() ?? data['mobile_ios_url']?.toString();
      
      final maint = data['maintenanceMode'] ?? data['mobile_maintenance_mode'];
      mobileMaintenanceMode = maint == true || maint == 1 || maint.toString() == '1' || maint.toString().toLowerCase() == 'true';
      
      mobileMaintenanceMessage = data['maintenanceMessage']?.toString() ?? data['mobile_maintenance_msg']?.toString();
      mobileReleaseNotes = data['releaseNotes']?.toString() ?? data['mobile_release_notes']?.toString();
      
      if (data['appName'] != null) {
        publicSiteName = data['appName'].toString();
      } else if (data['mobile_app_name'] != null) {
        publicSiteName = data['mobile_app_name'].toString();
      }
      
      if (data['appIcon'] != null) {
        publicLogoUrl = data['appIcon'].toString();
      } else if (data['mobile_app_icon'] != null) {
        publicLogoUrl = data['mobile_app_icon'].toString();
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error parsing mobile settings in provider: $e');
    }
    return res;
  }

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Workspace? overrideWorkspace,
  }) async {
    return _apiService.request(method, path, body: body, overrideWorkspace: overrideWorkspace);
  }

  Future<void> init() async {
    await _apiService.init();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> eagerLoad([BuildContext? context]) async {
    if (activeWorkspace == null) return;
    
    _isEagerLoaded = false;
    final futures = [
      enrichWorkspace(activeWorkspace!.id, context),
      getDashboard(),
      getFavorites(),
      getWalletBalance(),
      getMe(),
      getGroups(),
    ];

    try {
      final results = await Future.wait(futures);
      _cachedDashboard = results[1] as Map<String, dynamic>;
      _cachedFavorites = results[2] as Map<String, dynamic>;
      _cachedWallet = results[3] as Map<String, dynamic>;
      _cachedME = results[4] as Map<String, dynamic>;
      _cachedGroups = results[5] as Map<String, dynamic>;
      
      // SYNC FAVORITES SET
      final List favs = (_cachedFavorites?['favorites'] as List?) ?? [];
      _localFavoriteIds.clear();
      _localFavoriteIds.addAll(favs.map((f) => int.tryParse(f['id']?.toString() ?? '0') ?? 0).where((id) => id != 0));

      _isEagerLoaded = true;
      debugPrint('🚀 EAGER LOAD COMPLETE: All data cached. Favs: ${_localFavoriteIds.length}');
      notifyListeners();

      // SYNC CONNECT DATA TO BACKEND
      await syncConnectData();
    } catch (e) {
      debugPrint('❌ Eager Load Error: $e');
      if (e is UserBannedException) {
        rethrow;
      }
      final isMismatch = e is DeviceMismatchException || e.toString().toLowerCase().contains('mismatch device id');
      
      if (isMismatch) {
        _lastErrorMessage = 'device_mismatch';
        await logout(); // This clears the session and notifies
        if (context != null && context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false, arguments: 'device_mismatch');
        }
      }
      
      if (e.toString().contains('Session expired')) {
        await logout();
        if (context != null && context.mounted) {
           Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      }
    }
    notifyListeners();
  }

  Future<void> enrichWorkspace(String id, [BuildContext? context]) async {
    try {
      final response = await _apiService.getSiteSettings();
      final workspacesList = List<Workspace>.from(_apiService.workspaces);
      final index = workspacesList.indexWhere((w) => w.id == id);
      
      if (index != -1) {
        final w = workspacesList[index];
        final tenant = response['tenant'] as Map<String, dynamic>?;
        final settings = response['settings'] as Map<String, dynamic>?;
        final courses = response['courses'] as List?;
        
        final apiName = settings?['site_name']?.toString() ?? '';
        final finalName = (apiName.trim().isEmpty || apiName.trim().toLowerCase() == 'www') ? w.name : apiName.trim();
        
        // Also keep publicCurrency in sync when enriching workspace
        final curRaw = settings?['currency']?.toString() ?? settings?['currency_symbol']?.toString() ?? settings?['currency_code']?.toString();
        if (curRaw != null && curRaw.isNotEmpty) publicCurrency = curRaw;

        if (settings != null) {
          final enabledVal = settings['watermark_enabled'];
          _watermarkEnabled = enabledVal == 1 || enabledVal == true || enabledVal.toString() == '1' || enabledVal.toString().toLowerCase() == 'true';
          _watermarkFields = settings['watermark_fields']?.toString() ?? "id,name,phone";
          _watermarkScope = settings['watermark_scope']?.toString() ?? "all_site";
          _watermarkIntervalSeconds = int.tryParse(settings['watermark_interval_seconds']?.toString() ?? '') ?? 15;
          if (_watermarkIntervalSeconds < 3) {
            _watermarkIntervalSeconds = 3;
          }
        }

        final updated = w.copyWith(
          name: finalName,
          teacherName: tenant?['teacher_name'] ?? w.teacherName,
          theme: tenant?['theme'] ?? settings?['theme'] ?? w.theme,
          heroTitle: settings?['hero_title'],
          heroSubtitle: settings?['hero_subtitle'],
          aboutTeacher: settings?['about_teacher'],
          whatsappNumber: settings?['whatsapp_number'],
          logoUrl: settings?['logo_url'],
          themeColor: ApiService.extractAdminColor(response) ?? settings?['theme_color'] ?? w.themeColor,
          faqsJson: json.encode(settings?['faqs'] ?? []),
          featuresJson: json.encode(settings?['features'] ?? []),
          latestCoursesJson: json.encode(courses ?? []),
          enablePurchasing: (settings?['enable_purchasing'] == 1 || settings?['enable_purchasing'] == true),
        );
        
        await _apiService.addWorkspace(updated);
        
        // AUTO-SYNC THEME IF CONTEXT PROVIDED
        if (context != null) {
          try {
            final tp = Provider.of<ThemeProvider>(context, listen: false);
            final sColor = updated.themeColor;
            debugPrint('🔥🔥 Academy Branding Sync: Color detected -> $sColor');
            tp.setTenant(updated.theme, themeColor: sColor);
          } catch (e) {
            debugPrint('⚠️ Theme Sync Error: $e');
          }
        }
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Branding Enrich Error: $e');
      if (e is DeviceMismatchException) {
        rethrow;
      }
      if (e.toString().contains('Session expired')) {
        notifyListeners();
        if (context != null && context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } else if (e.toString().contains('Tenant not registered')) {
        debugPrint('⚠️ CRITICAL: Tenant revoked or not found. Purging workspace ID: $id');
        await removeWorkspace(id);
        
        // If we have a context, force a reset to the root to show onboarding/selection
        if (context != null && context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      }
    }
  }

  Future<void> addWorkspaceWithToken(String host, String token, String email, String name) async {
    final tenantName = host.split('.').first;
    final workspace = Workspace(
      id: '$tenantName-$email',
      tenant: tenantName,
      host: host,
      name: tenantName.toUpperCase(),
      studentName: name,
      email: email,
      token: token,
      deviceId: deviceId,
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _apiService.addWorkspace(workspace);
    try {
      await _apiService.setConnectData(workspace: workspace);
    } catch (e) {
      debugPrint('Set Connect Data Error (Token Login): $e');
    }
    await enrichWorkspace(workspace.id);
    notifyListeners();
  }

  Future<void> addWorkspaceManual(String host, String email, String password) async {
    final loginData = await _apiService.login(host, email, password);
    final token = loginData['token'];
    final Map<String, dynamic>? user = loginData['user'] is Map ? Map<String, dynamic>.from(loginData['user']) : null;
    final actualHost = loginData['redirectedHost'] ?? host;
    final tenantName = actualHost.split('.').first;

    final workspace = Workspace(
      id: '$tenantName-$email',
      tenant: tenantName,
      host: actualHost,
      name: tenantName.toUpperCase(),
      studentName: user?['name'] ?? '',
      email: email,
      token: token,
      deviceId: deviceId,
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _apiService.addWorkspace(workspace);
    try {
      await _apiService.setConnectData(workspace: workspace);
    } catch (e) {
      debugPrint('Set Connect Data Error (Manual Login): $e');
    }
    await enrichWorkspace(workspace.id);
    notifyListeners();
  }

  Future<void> addWorkspaceWithGoogle({
    required String host,
    required String email,
    required String name,
    required String googleId,
    String? photoUrl,
  }) async {
    final loginData = await _apiService.loginWithGoogle(
      host: host,
      email: email,
      name: name,
      googleId: googleId,
    );
    final token = loginData['token'];
    final Map<String, dynamic>? user = loginData['user'] is Map ? Map<String, dynamic>.from(loginData['user']) : null;
    final actualHost = loginData['redirectedHost'] ?? host;
    final tenantName = actualHost.split('.').first;
    final userEmail = user?['email'] ?? email;

    final workspace = Workspace(
      id: '$tenantName-$userEmail',
      tenant: tenantName,
      host: actualHost,
      name: tenantName.toUpperCase(),
      studentName: user?['name'] ?? name,
      email: userEmail,
      studentPhotoUrl: photoUrl,
      token: token,
      deviceId: deviceId,
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _apiService.addWorkspace(workspace);
    try {
      await _apiService.setConnectData(workspace: workspace);
    } catch (e) {
      debugPrint('Set Connect Data Error (Google Login): $e');
    }
    await enrichWorkspace(workspace.id);
    notifyListeners();
  }

  Future<void> addWorkspaceRegister({
    required String host,
    required String name,
    required String email,
    required String password,
    required String phone,
    required String birthDate,
  }) async {
    final registerData = await _apiService.register(
      host: host,
      name: name,
      email: email,
      password: password,
      phone: phone,
      birthDate: birthDate,
    );
    final token = registerData['token'];
    final user = registerData['user'];
    final actualHost = registerData['redirectedHost'] ?? host;
    final tenantName = actualHost.split('.').first;
    final userEmail = user['email'] ?? email;

    final workspace = Workspace(
      id: '$tenantName-$userEmail',
      tenant: tenantName,
      host: actualHost,
      name: tenantName.toUpperCase(),
      studentName: user['name'] ?? name,
      email: userEmail,
      token: token,
      deviceId: deviceId,
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _apiService.addWorkspace(workspace);
    
    // Defer non-critical API calls to the background to speed up UI transition
    Future.microtask(() async {
      try {
        await _apiService.setConnectData(workspace: workspace);
      } catch (e) {
        debugPrint('Set Connect Data Error (Register): $e');
      }
      await enrichWorkspace(workspace.id);
      notifyListeners();
    });
  }

  Future<void> sendOtp(String host, String email) async {
    await _apiService.sendOtp(host, email);
  }

  Future<void> verifyOtpAndRegister({
    required String host,
    required String name,
    required String email,
    required String password,
    required String phone,
    required String otp,
    required String birthDate,
  }) async {
    final registerData = await _apiService.verifyOtpAndRegister(
      host: host,
      name: name,
      email: email,
      password: password,
      phone: phone,
      otp: otp,
      birthDate: birthDate,
    );
    final token = registerData['token'];
    final user = registerData['user'] ?? {};
    final actualHost = registerData['redirectedHost'] ?? host;
    final tenantName = actualHost.split('.').first;
    final userEmail = user['email'] ?? email;

    final workspace = Workspace(
      id: '$tenantName-$userEmail',
      tenant: tenantName,
      host: actualHost,
      name: tenantName.toUpperCase(),
      studentName: user['name'] ?? name,
      email: userEmail,
      token: token,
      deviceId: deviceId,
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _apiService.addWorkspace(workspace);
    
    // Defer non-critical API calls to the background to speed up UI transition
    Future.microtask(() async {
      try {
        await _apiService.setConnectData(workspace: workspace);
      } catch (e) {
        debugPrint('Set Connect Data Error (OTP Register): $e');
      }
      await enrichWorkspace(workspace.id);
      notifyListeners();
    });
  }

  Future<void> switchWorkspace(String id, [BuildContext? context]) async {
    final workspace = workspaces.firstWhere((w) => w.id == id);
    
    // IMMEDIATE THEME SYNC IF CONTEXT PROVIDED
    if (context != null) {
      try {
        final tp = Provider.of<ThemeProvider>(context, listen: false);
        tp.setTenant(workspace.theme, themeColor: workspace.themeColor);
      } catch (_) {}
    }
    
    await _apiService.switchWorkspace(id);
    await eagerLoad(context);
    notifyListeners();
  }

  Future<void> logout() async {
    await _apiService.clearSession();
    invalidateCache();
    notifyListeners();
  }

  Future<void> removeWorkspace(String id) async {
    await _apiService.removeWorkspace(id);
    invalidateCache();
    notifyListeners();
  }

  void invalidateCache() {
    _cachedDashboard = null;
    _cachedFavorites = null;
    _cachedWallet = null;
    _cachedME = null;
    _cachedWalletTransactions = null;
    _cachedGroups = null;
    _isEagerLoaded = false;
    debugPrint('🧹 Cache invalidated');
  }

  Future<Map<String, dynamic>> getDashboard() async {
    if (_cachedDashboard != null) return _cachedDashboard!;
    final res = await _apiService.getDashboard();
    _cachedDashboard = res;
    return res;
  }
  
  Future<Map<String, dynamic>> getCourse(int id) => _apiService.getCourse(id);
  Future<Map<String, dynamic>> getCourseLearn(int id) => _apiService.getCourseLearn(id);
  Future<Map<String, dynamic>> getPlayback(String code) => _apiService.getPlayback(code);
  
  Future<void> markProgress(int courseId, Map<String, dynamic> material) async {
    final materialId = int.tryParse(material['id']?.toString() ?? '0') ?? 0;
    if (materialId != 0) await _apiService.markProgress(courseId, materialId);
    _lastAccessedMaterials[courseId] = material;
    notifyListeners();
  }
  
  Future<Map<String, dynamic>> toggleFavorite(int courseId) => _apiService.toggleFavorite(courseId);

  Future<void> toggleFavoriteOptimistic(int courseId) async {
    final bool wasFav = _localFavoriteIds.contains(courseId);
    
    // 1. UPDATE LOCALLY FIRST (notify all screens)
    if (wasFav) {
      _localFavoriteIds.remove(courseId);
    } else {
      _localFavoriteIds.add(courseId);
    }
    notifyListeners();

    // 2. BACKEND SYNC
    try {
      await _apiService.toggleFavorite(courseId);
      // Optional: re-fetch favorites list in background to keep full movie objects fresh
      getFavorites().then((res) {
        _cachedFavorites = res;
        final List favs = (res['favorites'] as List?) ?? [];
        _localFavoriteIds.clear();
        _localFavoriteIds.addAll(favs.map((f) => int.tryParse(f['id']?.toString() ?? '0') ?? 0).where((id) => id != 0));
        notifyListeners();
      });
    } catch (e) {
      // REVERT ON ERROR
      if (wasFav) {
        _localFavoriteIds.add(courseId);
      } else {
        _localFavoriteIds.remove(courseId);
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getFavorites() async {
    if (_cachedFavorites != null) return _cachedFavorites!;
    final res = await _apiService.getFavorites();
    _cachedFavorites = res;
    return res;
  }

  Future<Map<String, dynamic>> redeemCoupon(String code, {int? courseId}) async {
    final res = await _apiService.redeemCoupon(code, courseId: courseId);
    invalidateCache();
    () async {
      try {
        await eagerLoad();
      } catch (e) {
        debugPrint('Background eagerLoad error: $e');
      }
    }();
    return res;
  }
  
  Future<Map<String, dynamic>> redeemVoucher(String code) async {
    final res = await _apiService.redeemVoucher(code);
    invalidateCache();
    () async {
      try {
        await eagerLoad();
      } catch (e) {
        debugPrint('Background eagerLoad error: $e');
      }
    }();
    return res;
  }
  
  Future<Map<String, dynamic>> checkoutWallet(int courseId) async {
    final res = await _apiService.checkoutWallet(courseId);
    invalidateCache();
    () async {
      try {
        await eagerLoad();
      } catch (e) {
        debugPrint('Background eagerLoad error: $e');
      }
    }();
    return res;
  }
  
  Future<Map<String, dynamic>> unenroll(int courseId) async {
    final res = await _apiService.unenroll(courseId);
    invalidateCache();
    () async {
      try {
        await eagerLoad();
      } catch (e) {
        debugPrint('Background eagerLoad error: $e');
      }
    }();
    return res;
  }
  
  Future<Map<String, dynamic>> getWalletTransactions() async {
    if (_cachedWalletTransactions != null) return _cachedWalletTransactions!;
    final res = await _apiService.getWalletTransactions();
    _cachedWalletTransactions = res;
    return res;
  }
  
  Future<Map<String, dynamic>> getWalletBalance() async {
    if (_cachedWallet != null) return _cachedWallet!;
    final res = await _apiService.getWalletBalance();
    _cachedWallet = res;
    return res;
  }
  
  Future<Map<String, dynamic>> getCourses({int? categoryId}) async {
     final path = categoryId != null ? '/courses?categoryId=$categoryId' : '/courses';
     final res = await _apiService.request('GET', path);
     return Map<String, dynamic>.from(res);
  }

  Future<Map<String, dynamic>> getCategories() => _apiService.getCategories();
  
  Future<Map<String, dynamic>> getMe({bool force = false}) async {
    if (!force && _cachedME != null) return _cachedME!;
    final res = await _apiService.getMe();
    _cachedME = res;
    notifyListeners();
    return res;
  }
  
  Future<Map<String, dynamic>> getGroups({bool force = false}) async {
    if (!force && _cachedGroups != null) return _cachedGroups!;
    final res = await _apiService.getGroups();
    _cachedGroups = res;
    notifyListeners();
    return res;
  }
  
  Future<Map<String, dynamic>> joinGroup(int groupId) async {
    final res = await _apiService.joinGroup(groupId);
    invalidateCache();
    await eagerLoad();
    return res;
  }
  
  Future<Map<String, dynamic>> getQuiz(int quizId) => _apiService.getQuiz(quizId);
  Future<Map<String, dynamic>> submitQuiz(int quizId, dynamic results) => _apiService.submitQuiz(quizId, results);
  Future<Map<String, dynamic>> getAssignment(int assignmentId) => _apiService.getAssignment(assignmentId);
  Future<Map<String, dynamic>> submitAssignment(int assignmentId, Map<String, dynamic> submissionData) => _apiService.submitAssignment(assignmentId, submissionData);
  Future<Map<String, dynamic>> submitAssignmentMultipart(int assignmentId, String textAnswer, String? filePath) => _apiService.submitAssignmentMultipart(assignmentId, textAnswer, filePath);
  Future<Map<String, dynamic>> getReviews(int courseId) => _apiService.getReviews(courseId);
  Future<Map<String, dynamic>> submitReview(int courseId, int rating, String comment) => _apiService.submitReview(courseId, rating, comment);
  Future<Map<String, dynamic>> updateProfile({String? name, String? phone, String? avatarUrl}) async {
    final data = await _apiService.updateProfile(name: name, phone: phone, avatarUrl: avatarUrl);
    _cachedME = null;
    await getMe();
    notifyListeners();
    return data;
  }

  Future<Map<String, dynamic>> getImageKitAuth() => _apiService.getImageKitAuth();
  Future<Map<String, dynamic>> getSchedule() => _apiService.getSchedule();

  Future<void> syncConnectData() async {
    if (activeWorkspace == null) return;

    try {
      final List coursesList = (_cachedDashboard?['courses'] as List?) ?? [];
      final List<int> courseIds = coursesList
          .map((c) => int.tryParse(c['id']?.toString() ?? '0') ?? 0)
          .where((id) => id != 0)
          .toList();

      final user = _cachedME?['user'] as Map<String, dynamic>?;

      await _apiService.setConnectData(
        enrolledCourses: courseIds,
        bio: user?['bio'],
        coverUrl: user?['cover_url'],
        workspace: activeWorkspace,
      );
      debugPrint('✅ Connect data synchronized');
    } catch (e) {
      debugPrint('⚠️ Connect Data Sync Error: $e');
      if (e is DeviceMismatchException || e.toString().toLowerCase().contains('mismatch device id')) {
        rethrow; // Pass up to eagerLoad to handle logout
      }
    }
  }

  Future<void> launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      bool launched = false;
      try {
        launched = await launcher.launchUrl(uri, mode: launcher.LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('Failed to launch with externalApplication: $e');
      }
      if (!launched) {
        await launcher.launchUrl(uri, mode: launcher.LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  Future<void> reloadWalletData() async {
    _cachedWallet = null;
    _cachedDashboard = null;
    final balFuture = _apiService.getWalletBalance();
    final dashFuture = _apiService.getDashboard();
    final results = await Future.wait([dashFuture, balFuture]);
    _cachedWallet = results[1];
    _cachedDashboard = results[0];
    notifyListeners();
  }

  Future<void> reportSecurityAlert(String incidentType, {String description = ''}) =>
      _apiService.reportSecurityAlert(incidentType, description: description);
}
