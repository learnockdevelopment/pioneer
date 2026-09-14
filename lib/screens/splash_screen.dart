import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:elmasa/providers/workspace_provider.dart';
import 'package:elmasa/providers/language_provider.dart';
import 'package:elmasa/widgets/premium_loader.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'package:elmasa/services/security_service.dart';
import 'package:elmasa/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart' as package_info_plus;
import 'package:google_fonts/google_fonts.dart';
import 'package:elmasa/screens/error_screen.dart';
import 'package:elmasa/screens/maintenance_screen.dart';
import 'package:elmasa/screens/update_screen.dart';

import '../providers/theme_provider.dart';
import '../services/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _securityFailure = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _controller.forward();
    _init();
  }
  Future<void> _init() async {
    // Load language first (default to ar)
    await Provider.of<LanguageProvider>(context, listen: false)
        .loadLanguage(const Locale('ar'));

    // ACTIVATE ANTI-CAPTURE PROTOCOL
    if (!kDebugMode && !SecurityService.bypassSecurityChecks && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android)) {
      try {
        await NoScreenshot.instance.screenshotOff();
      } catch (e) {
        debugPrint('Security Warning: $e');
      }
    }

    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    
    // Check Mobile App Settings first for force update and maintenance status
    try {
      final mobileSettings = await wp.getMobileSettings(kSiteHost);
      
      // 1. Check Maintenance Mode
      if (wp.mobileMaintenanceMode) {
        if (mounted) {
          final isRTL = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode == 'ar';
          final mTitle = isRTL ? 'وضع الصيانة' : 'Maintenance Mode';
          final mMessage = wp.mobileMaintenanceMessage ?? 
              (isRTL 
                ? 'التطبيق حالياً في وضع الصيانة. يرجى المحاولة لاحقاً.' 
                : 'The application is currently undergoing maintenance. Please try again later.');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => MaintenanceScreen(
                title: mTitle,
                message: mMessage,
                onRefresh: () => Navigator.of(context).pushReplacementNamed('/'),
              ),
            ),
          );
        }
        return;
      }
      
      // 2. Check Force Update
      if (wp.mobileLatestVersion != null || wp.mobileMinSupportedVersion != null) {
        final package_info = await package_info_plus.PackageInfo.fromPlatform();
        final currentVersion = package_info.version;
        
        bool isVersionGreater(String siteV, String appV) {
          final siteParts = siteV.split('.').map((e) => int.tryParse(e) ?? 0).toList();
          final appParts = appV.split('.').map((e) => int.tryParse(e) ?? 0).toList();
          final maxLen = siteParts.length > appParts.length ? siteParts.length : appParts.length;
          for (int i = 0; i < maxLen; i++) {
            final siteVal = i < siteParts.length ? siteParts[i] : 0;
            final appVal = i < appParts.length ? appParts[i] : 0;
            if (siteVal > appVal) return true;
            if (siteVal < appVal) return false;
          }
          return false;
        }

        bool isUpdateNeeded = false;
        if (wp.mobileMinSupportedVersion != null && isVersionGreater(wp.mobileMinSupportedVersion!, currentVersion)) {
          isUpdateNeeded = true;
        }
        if (wp.mobileLatestVersion != null && isVersionGreater(wp.mobileLatestVersion!, currentVersion)) {
          isUpdateNeeded = true;
        }
        
        if (isUpdateNeeded) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => UpdateScreen(
                  releaseNotes: wp.mobileReleaseNotes,
                  androidUrl: wp.mobileAndroidUrl,
                  iosUrl: wp.mobileIosUrl,
                ),
              ),
            );
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Error handling Mobile Settings API on launch: $e');
    }

    // Run workspace init first
    await wp.init();

    // Enforce security check
    final isSafe = await SecurityService.isDeviceSafe();
    if (!isSafe) {
      if (mounted) {
        setState(() {
          _securityFailure = true;
        });
      }
      return;
    }

    if (wp.activeWorkspace != null) {
      try {
        final w = wp.activeWorkspace!;
        if (mounted) {
          Provider.of<ThemeProvider>(context, listen: false).setTenant(w.theme, themeColor: w.themeColor);
        }
        await wp.eagerLoad(context);
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/dashboard');
        }
      } catch (e) {
        debugPrint('Splash eagerLoad error: $e');
        if (e is UserBannedException) {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/banned');
          }
          return;
        }
        // Fallback for other errors (e.g. offline) to let them view cached dashboard
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/dashboard');
        }
      }
      // Fetch in background for other settings
      wp.getPublicSiteSettings(kSiteHost).catchError((_) => <String, dynamic>{});
      return;
    }

    await Future.delayed(const Duration(milliseconds: 500));

    bool reqLogin = false;
    try {
      final settingsRes = await wp.getPublicSiteSettings(kSiteHost);
      final settings = (settingsRes['settings'] is Map ? Map<String, dynamic>.from(settingsRes['settings']) : null) ?? 
                       (settingsRes['data'] is Map ? Map<String, dynamic>.from(settingsRes['data']) : null) ?? 
                       Map<String, dynamic>.from(settingsRes);
      
      final rl = settings['require_login'] ?? settingsRes['require_login'];
      debugPrint('ℹ️ require_login raw value: $rl (type: ${rl.runtimeType})');
      reqLogin = rl == true || rl == 1 || rl.toString() == '1' || rl.toString().toLowerCase() == 'true';
      debugPrint('ℹ️ reqLogin parsed value: $reqLogin');
      if (wp.publicSiteName == null) {
        wp.publicSiteName = settings['site_name']?.toString() ?? settingsRes['site_name']?.toString();
      }
      if (wp.publicLogoUrl == null) {
        wp.publicLogoUrl = settings['logo_url']?.toString() ?? settingsRes['logo_url']?.toString();
      }
      final pubColor = ApiService.extractAdminColor(settingsRes);
      if (pubColor != null && mounted) {
         Provider.of<ThemeProvider>(context, listen: false).setTenant('default', themeColor: pubColor);
      }
    } catch (e) {
      debugPrint('Failed to get public site settings: $e');
    }
    wp.setRequireLogin(reqLogin);

    if (mounted) {
      if (reqLogin) {
        Navigator.of(context).pushReplacementNamed(
          '/onboarding', 
          arguments: wp.lastErrorMessage
        );
      } else {
        wp.enterGuestMode();
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_securityFailure) return _buildSecurityLockUI();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: PremiumLoader(color: Theme.of(context).primaryColor, useAppLogoOnly: true),
      ),
    );
  }

  Widget _buildSecurityLockUI() {
    final wp = Provider.of<WorkspaceProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // DEEP DARK SLATE
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 144,
              height: 144,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.12), 
                shape: BoxShape.circle,
                border: Border.all(color: Colors.redAccent.withOpacity(0.2), width: 2),
                boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.1), blurRadius: 40, spreadRadius: 10)],
              ),
              child: ClipOval(
                child: wp.publicLogoUrl != null 
                  ? Image.network(
                      wp.publicLogoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Image.asset('assets/logo.png', fit: BoxFit.cover),
                    )
                  : Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.cover,
                    ),
              ),
            ),
            const SizedBox(height: 40),
            
            Text(
              lang.translate('security_block'),
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              lang.translate('drm_protection'),
              style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white10)),
              child: Column(
                children: [
                  Text(
                    lang.translate('security_failure_msg'),
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.6, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 20),
                  Text(
                    lang.translate('disable_dev_options'),
                    style: TextStyle(color: Colors.redAccent.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w900),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 60),
            Text(
               lang.translate('drm_engine'),
               style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }
}
