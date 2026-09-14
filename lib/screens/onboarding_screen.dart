import 'dart:convert';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:provider/provider.dart';
import 'package:elmasa/providers/workspace_provider.dart';
import 'package:elmasa/providers/language_provider.dart';
import 'package:elmasa/providers/theme_provider.dart';
import 'package:elmasa/widgets/premium_loader.dart';
import 'package:elmasa/widgets/official_google_logo.dart';
import 'package:elmasa/config/app_config.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/workspace.dart';
import '../services/api_service.dart';
import '../services/security_service.dart';
import 'error_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isManual = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final wp = Provider.of<WorkspaceProvider>(context, listen: false);
      final args = ModalRoute.of(context)?.settings.arguments;
      
      debugPrint('🔍 Onboarding init: args=$args, wp.lastErrorMessage=${wp.lastErrorMessage}');
      
      if (args == 'device_mismatch' || wp.lastErrorMessage == 'device_mismatch') {
        debugPrint('🎯 TRIGGERING MISMATCH PROMPT');
        wp.clearError();
        
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => _buildErrorPrompt(
              context,
              title: 'تنبيه الأمان',
              message: 'تم تسجيل الخروج لأن هذا الحساب مفعل على جهاز آخر حالياً. يرجى استخدام جهازك الأساسي.',
              icon: Icons.phonelink_lock_rounded,
              isExitButton: true,
            ),
          );
        });
      }
    });
  }
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  bool _isRegisterMode = false;
  bool _isPasswordObscure = true;

  void _registerManual() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    if (_nameController.text.isEmpty ||
        _userController.text.isEmpty ||
        _passController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _birthDateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.translate('fill_fields') ?? 'Please fill all fields')));
      return;
    }

    setState(() => _isLoading = true);
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);

    try {
      await wp.addWorkspaceRegister(
        host: kSiteHost,
        name: _nameController.text.trim(),
        email: _userController.text.trim(),
        password: _passController.text.trim(),
        phone: _phoneController.text.trim(),
        birthDate: _birthDateController.text.trim(),
      );
      debugPrint('✅ MANUAL REGISTER SUCCESS');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.translate('registration_success') ?? 'Registration successful!')),
        );
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (e) {
      debugPrint('❌ MANUAL REGISTER FAILED: $e');
      if (mounted) {
        if (e is UserBannedException) {
          Navigator.pushNamedAndRemoveUntil(context, '/banned', (route) => false);
          return;
        }
        final errorStr = e.toString().toLowerCase();
        final isRTL = lang.currentLocale.languageCode == 'ar';
        if (e is DeviceMismatchException || errorStr.contains('mismatch') || errorStr.contains('linked to another device') || errorStr.contains('disconnect the old device')) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => _buildErrorPrompt(
              context,
              title: isRTL ? 'تنبيه الأمان' : 'Security Alert',
              message: isRTL 
                  ? 'هذا الحساب مرتبط بجهاز آخر بالفعل. يرجى إلغاء ربط الجهاز القديم أولاً.'
                  : 'This account is already linked to another device. Please disconnect the old device first.',
              icon: Icons.phonelink_lock_rounded,
              isExitButton: true,
            ),
          );
        } else if (e is ServerException) {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => ErrorScreen(
            code: e.statusCode.toString(),
            message: e.message,
            onRetry: () {
              Navigator.pop(context);
              _registerManual();
            },
          )));
        } else {
          showDialog(
            context: context,
            builder: (context) => _buildErrorPrompt(
              context,
              title: lang.translate('register_failed') ?? 'Registration Failed',
              message: e.toString().replaceAll('Exception: ', ''),
              icon: Icons.error_outline_rounded,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2005),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _birthDateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Widget _buildDatePickerField({
    required TextEditingController controller, 
    required String label, 
    required IconData icon, 
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final fieldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFF);
    final fieldBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final fieldText = isDark ? Colors.white : const Color(0xFF1E293B);
    final hintColor = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
    final iconColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label, 
          style: GoogleFonts.cairo(
            color: labelColor,
            fontWeight: FontWeight.w800, 
            fontSize: 12, 
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 5),
        GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: fieldBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: fieldBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 16),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    controller.text.isEmpty ? 'YYYY-MM-DD' : controller.text,
                    style: TextStyle(
                      color: controller.text.isEmpty ? hintColor : fieldText,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool _isScanning = true;
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? _qrController;

  @override
  void reassemble() {
    super.reassemble();
    try {
      if (Platform.isAndroid) {
        _qrController?.pauseCamera();
      }
      _qrController?.resumeCamera();
    } catch (e) {
      debugPrint('📸 Camera reassemble exception caught: $e');
    }
  }

  @override
  void dispose() {
    try {
      _qrController?.dispose();
    } catch (e) {
      debugPrint('📸 Camera dispose exception caught: $e');
    }
    _nameController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _hostController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    _qrController = controller;
    controller.scannedDataStream.listen((scanData) {
      if (scanData.code != null) {
        _onCodeScanned(scanData.code!);
      }
    });
  }

  void _onCodeScanned(String code) async {
    if (!_isScanning) return;
    setState(() => _isScanning = false);

    try {
      final data = json.decode(code);
      final wp = Provider.of<WorkspaceProvider>(context, listen: false);

      if (data['version'] == '1.2' && data['token'] != null) {
        setState(() => _isLoading = true);
        await wp.addWorkspaceWithToken(
          data['host'] ?? (data['tenant'] != null ? "${data['tenant']}.derasy.com" : ""),
          data['token'],
          data['email'] ?? "",
          data['name'] ?? "Student",
        );
        if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
        return;
      }

      if (data['version'] == '1.0' || data['tenant'] != null || data['host'] != null) {
        _hostController.text = data['host'] ?? (data['tenant'] != null ? "${data['tenant']}.derasy.com" : "");
        _userController.text = data['email'] ?? "";
        if (data['password'] != null) {
          _passController.text = data['password'];
          _loginManual();
        } else {
          setState(() => _isManual = true);
        }
        return;
      }
      throw 'Invalid QR Format';
    } catch (e) {
      debugPrint('❌ QR LOGIN FAILED: $e');
      if (mounted) {
        setState(() => _isScanning = true);
        setState(() => _isLoading = false);
        if (e is UserBannedException) {
          Navigator.pushNamedAndRemoveUntil(context, '/banned', (route) => false);
          return;
        }
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        final errorStr = e.toString().toLowerCase();
        
        final isRTL = lang.currentLocale.languageCode == 'ar';
        if (e is DeviceMismatchException || errorStr.contains('mismatch') || errorStr.contains('linked to another device') || errorStr.contains('disconnect the old device')) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => _buildErrorPrompt(
              context,
              title: isRTL ? 'تنبيه الأمان' : 'Security Alert',
              message: isRTL 
                  ? 'هذا الحساب مرتبط بجهاز آخر بالفعل. يرجى إلغاء ربط الجهاز القديم أولاً.'
                  : 'This account is already linked to another device. Please disconnect the old device first.',
              icon: Icons.phonelink_lock_rounded,
              isExitButton: true,
            ),
          );
        } else if (errorStr.contains('unauthorized') || errorStr.contains('invalid') || errorStr.contains('غير صحيحة') || errorStr.contains('credential')) {
          showDialog(
            context: context,
            builder: (context) => _buildErrorPrompt(
              context,
              title: lang.translate('login_failed') ?? 'Login Failed',
              message: lang.currentLocale.languageCode == 'ar'
                  ? 'بيانات تسجيل الدخول في رمز QR غير صحيحة أو منتهية الصلاحية.'
                  : 'The login credentials in the QR code are invalid or expired.',
              icon: Icons.qr_code_scanner_rounded,
              accentColor: const Color(0xFFF59E0B),
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (context) => _buildErrorPrompt(
              context,
              title: lang.translate('login_failed') ?? 'Login Failed',
              message: e.toString().replaceAll('Exception: ', ''),
              icon: Icons.error_outline_rounded,
            ),
          );
        }
      }
    }
  }

  void _browseAsGuest() {
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    wp.enterGuestMode();
    Navigator.of(context).pushReplacementNamed('/dashboard');
  }

  void _loginManual() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    _hostController.text = kSiteHost;
    if (_userController.text.isEmpty || _passController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.translate('fill_fields'))));
      setState(() => _isManual = true);
      return;
    }

    setState(() => _isLoading = true);
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    
    try {
       await wp.addWorkspaceManual(
        _hostController.text.trim(),
        _userController.text.trim(),
        _passController.text.trim(),
      );
      debugPrint('✅ MANUAL LOGIN SUCCESS');
      if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      debugPrint('❌ MANUAL LOGIN FAILED: $e');
      if (mounted) {
        if (e is UserBannedException) {
          Navigator.pushNamedAndRemoveUntil(context, '/banned', (route) => false);
          return;
        }
        final errorStr = e.toString().toLowerCase();
        final isRTL = lang.currentLocale.languageCode == 'ar';
        if (e is DeviceMismatchException || errorStr.contains('mismatch') || errorStr.contains('linked to another device') || errorStr.contains('disconnect the old device')) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => _buildErrorPrompt(
              context,
              title: isRTL ? 'تنبيه الأمان' : 'Security Alert',
              message: isRTL 
                  ? 'هذا الحساب مرتبط بجهاز آخر بالفعل. يرجى إلغاء ربط الجهاز القديم أولاً.'
                  : 'This account is already linked to another device. Please disconnect the old device first.',
              icon: Icons.phonelink_lock_rounded,
              isExitButton: true,
            ),
          );
        } else if (errorStr.contains('unauthorized') || errorStr.contains('invalid') || errorStr.contains('غير صحيحة') || errorStr.contains('credential')) {
          showDialog(
            context: context,
            builder: (context) => _buildErrorPrompt(
              context,
              title: lang.translate('login_failed') ?? 'Login Failed',
              message: lang.currentLocale.languageCode == 'ar'
                  ? 'البريد الإلكتروني أو كلمة المرور غير صحيحة. يرجى التحقق من بياناتك والمحاولة مرة أخرى.'
                  : 'Invalid email or password. Please verify your credentials and try again.',
              icon: Icons.lock_person_rounded,
              accentColor: const Color(0xFFF59E0B),
            ),
          );
        } else if (e is ServerException) {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => ErrorScreen(
            code: e.statusCode.toString(),
            message: e.message,
            onRetry: () {
              Navigator.pop(context);
              _loginManual();
            },
          )));
        } else {
          showDialog(
            context: context,
            builder: (context) => _buildErrorPrompt(
              context,
              title: lang.translate('login_failed') ?? 'Login Failed',
              message: e.toString().replaceAll('Exception: ', ''),
              icon: Icons.error_outline_rounded,
            ),
          );
          setState(() => _isScanning = true);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Singleton GoogleSignIn instance with correct Web Client ID from google-services.json
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '49233807571-43jpuohpjf5gn66lqrdurfglu3b5c9jj.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );
  static final GoogleSignIn _googleSignInFallback = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  bool _isGoogleSigningIn = false; // Extra guard against concurrent calls

  void _loginWithGoogle() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    if (_isLoading || _isGoogleSigningIn) return; // Hard guard
    _isGoogleSigningIn = true;
    setState(() => _isLoading = true);
    try {
      try {
        await _googleSignIn.signOut();
        await _googleSignInFallback.signOut();
      } catch (_) {}
      
      GoogleSignInAccount? account;
      try {
        account = await _googleSignIn.signIn();
      } catch (signInError) {
        debugPrint('⚠️ Main GoogleSignIn failed: $signInError. Attempting fallback...');
        account = await _googleSignInFallback.signIn();
      }

      if (account == null) {
        // User cancelled
        setState(() => _isLoading = false);
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) throw Exception('Could not obtain Google ID token');

      // Use Firebase Auth to validate the credential properly
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      // Now hand the credentials to the workspace backend as documented
      final wp = Provider.of<WorkspaceProvider>(context, listen: false);
      await wp.addWorkspaceWithGoogle(
        host: kSiteHost,
        email: account.email,
        name: account.displayName ?? 'Google Student',
        googleId: account.id,
        photoUrl: account.photoUrl,
      );
      debugPrint('✅ GOOGLE LOGIN SUCCESS');
      if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      debugPrint('❌ GOOGLE LOGIN FAILED: $e');
      if (mounted) {
        if (e is UserBannedException) {
          Navigator.pushNamedAndRemoveUntil(context, '/banned', (route) => false);
          return;
        }
        final errorStr = e.toString().toLowerCase();
        final isRTL = lang.currentLocale.languageCode == 'ar';
        if (e is DeviceMismatchException || errorStr.contains('mismatch') || errorStr.contains('linked to another device') || errorStr.contains('disconnect the old device')) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => _buildErrorPrompt(
              context,
              title: isRTL ? 'تنبيه الأمان' : 'Security Alert',
              message: isRTL 
                  ? 'هذا الحساب مرتبط بجهاز آخر بالفعل. يرجى إلغاء ربط الجهاز القديم أولاً.'
                  : 'This account is already linked to another device. Please disconnect the old device first.',
              icon: Icons.phonelink_lock_rounded,
              isExitButton: true,
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (context) => _buildErrorPrompt(
              context,
              title: lang.translate('login_failed') ?? 'Login Failed',
              message: e.toString().replaceAll('Exception: ', ''),
              icon: Icons.g_mobiledata_rounded,
              accentColor: const Color(0xFFEA4335),
            ),
          );
        }
      }
    } finally {
      _isGoogleSigningIn = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wp = Provider.of<WorkspaceProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final isRTL = lang.currentLocale.languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final tabBgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Background blobs
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(isDark ? 0.12 : 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(isDark ? 0.08 : 0.05),
              ),
            ),
          ),
          
          // Main content
          Positioned.fill(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        wp.enterGuestMode();
                        Navigator.pushReplacementNamed(context, '/dashboard');
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Hero(
                          tag: 'app-logo',
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              color: Colors.transparent,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: (wp.publicLogoUrl != null && wp.publicLogoUrl!.isNotEmpty)
                                  ? Image.network(
                                      wp.publicLogoUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => Image.asset('assets/logo.png', fit: BoxFit.cover),
                                    )
                                  : Image.asset('assets/logo.png', fit: BoxFit.cover),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      wp.appName.isNotEmpty 
                          ? "${lang.translate('welcome_to')} ${wp.appName}" 
                          : lang.translate('welcome_to_Learnock'),
                      style: GoogleFonts.cairo(
                        color: titleColor,
                        fontSize: 20, 
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lang.translate('start_journey'),
                      style: GoogleFonts.cairo(
                        color: subtitleColor,
                        fontSize: 11, 
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    // Form card
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: cardBorderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: tabBgColor,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Expanded(child: _buildTabButton(1, lang.translate('manual_entry'))),
                                Expanded(child: _buildTabButton(0, lang.translate('scan_qr'))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _isManual ? _buildManualForm(lang) : (_isLoading ? _buildLoading() : _buildQRSection(lang)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (!wp.requireLogin) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: subtitleColor.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: subtitleColor.withOpacity(0.1)),
                        ),
                        child: InkWell(
                          onTap: _browseAsGuest,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.travel_explore_rounded, size: 20, color: subtitleColor.withOpacity(0.8)),
                                const SizedBox(width: 10),
                                Text(
                                  wp.isGuest 
                                    ? (lang.translate('continue_browsing') ?? 'Continue browsing') 
                                    : (lang.translate('browse_without_login') ?? 'Browse without login'),
                                  style: GoogleFonts.cairo(
                                    color: subtitleColor.withOpacity(0.9),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(isRTL ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded, size: 16, color: subtitleColor.withOpacity(0.5)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      lang.translate('copyright'),
                      style: GoogleFonts.cairo(
                        color: subtitleColor.withOpacity(0.5),
                        fontSize: 10, 
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      key: ValueKey('loading'),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: PremiumLoader(),
      ),
    );
  }

  Widget _buildQRSection(LanguageProvider lang) {
    return Column(
      key: const ValueKey('qr'),
      children: [
        Container(
          height: 260,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: QRView(
            key: _qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: Theme.of(context).primaryColor,
              borderRadius: 12,
              borderLength: 30,
              borderWidth: 6,
              cutOutSize: 190,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          lang.translate('scan_qr').toUpperCase(),
          style: GoogleFonts.cairo(
            color: Theme.of(context).primaryColor, 
            fontWeight: FontWeight.w900, 
            fontSize: 12, 
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildManualForm(LanguageProvider lang) {
    final wp = Provider.of<WorkspaceProvider>(context);
    final isRTL = lang.currentLocale.languageCode == 'ar';
    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Column(
        key: const ValueKey('manual'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            controller: _userController, 
            label: lang.translate('email') ?? (isRTL ? 'البريد الإلكتروني' : 'Email Address'), 
            icon: Icons.alternate_email_rounded,
            hint: 'user@email.com',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _passController, 
            label: lang.translate('password') ?? (isRTL ? 'كلمة المرور' : 'Password'), 
            icon: Icons.lock_outline_rounded, 
            isObscure: _isPasswordObscure,
            hint: '••••••••',
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordObscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                size: 18,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordObscure = !_isPasswordObscure;
                });
              },
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withOpacity(0.85),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ]
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _loginManual,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isLoading 
                    ? const SpinKitThreeBounce(color: Colors.white, size: 18) 
                    : Text(
                        (lang.translate('login') ?? (isRTL ? 'تسجيل الدخول' : 'LOGIN')).toUpperCase(), 
                        style: GoogleFonts.cairo(
                          fontSize: 13, 
                          fontWeight: FontWeight.w900, 
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ),
          if (wp.enableRegistration) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/register');
                },
                child: Text(
                  lang.translate('dont_have_account') ?? (isRTL ? 'ليس لديك حساب؟ سجل الآن' : "Don't have an account? Register Now"),
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ),
          ],
          if (wp.enableSocialLogin) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12), thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    lang.translate('or') ?? (isRTL ? 'أو' : 'OR'),
                    style: GoogleFonts.cairo(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12), thickness: 1)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E293B)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black.withOpacity(0.3)
                        : const Color(0xFF64748B).withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _isLoading ? null : _loginWithGoogle,
                  splashColor: const Color(0xFF4285F4).withOpacity(0.1),
                  highlightColor: const Color(0xFF4285F4).withOpacity(0.05),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isGoogleSigningIn)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4285F4)),
                            ),
                          )
                        else ...[
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const OfficialGoogleLogo(size: 20),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            lang.translate('continue_with_google') ?? (isRTL ? 'المتابعة بحساب جوجل' : 'Continue with Google'),
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ], 
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final bool isActive = (index == 1) == _isManual;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? const Color(0xFF334155) : Colors.white;
    final activeTextColor = Theme.of(context).primaryColor;
    final inactiveTextColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    return GestureDetector(
      onTap: () => setState(() {
        _isManual = index == 1;
        if (!_isManual) _isScanning = true;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ] : null,
        ),
        child: Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            color: isActive ? activeTextColor : inactiveTextColor,
            fontSize: 11, 
            fontWeight: FontWeight.w900, 
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller, 
    required String label, 
    required IconData icon, 
    String? hint, 
    bool isObscure = false,
    Widget? suffixIcon,
  }) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final isRTL = lang.currentLocale.languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final fieldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFF);
    final fieldBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final fieldText = isDark ? Colors.white : const Color(0xFF1E293B);
    final hintColor = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
    final iconColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label, 
          style: GoogleFonts.cairo(
            color: labelColor,
            fontWeight: FontWeight.w800, 
            fontSize: 12, 
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: fieldBorder),
          ),
          child: TextField(
            controller: controller,
            obscureText: isObscure,
            textAlign: isRTL ? TextAlign.right : TextAlign.left,
            textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
            style: TextStyle(color: fieldText, fontWeight: FontWeight.bold, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: hintColor),
              prefixIcon: Icon(icon, color: iconColor, size: 16),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAcademySelectionCard(BuildContext context, Workspace w, WorkspaceProvider wp, Color primary, Color onSurface) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle),
          child: (w.logoUrl != null && w.logoUrl!.isNotEmpty) 
            ? ClipRRect(
                borderRadius: BorderRadius.circular(24), 
                child: Image.network(w.logoUrl!, fit: BoxFit.cover, errorBuilder: (c,e,s) => Icon(Icons.school_rounded, color: primary)),
              )
            : Icon(Icons.school_rounded, color: primary),
        ),
        title: Text(
          w.name.toUpperCase(), 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
        ),
        subtitle: Text(
          w.studentName, 
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    title: Text(
                      lang.translate('remove_academy') ?? 'Remove Academy', 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                    content: Text(
                      lang.translate('remove_academy_confirm') ?? 'Are you sure you want to remove this academy from your device?', 
                      style: TextStyle(color: Colors.white.withOpacity(0.6)),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(lang.translate('cancel') ?? 'CANCEL', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('REMOVE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await wp.removeWorkspace(w.id);
                }
              },
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white.withOpacity(0.2)),
          ],
        ),
        onTap: () async {
          setState(() => _isLoading = true);
          try {
            await wp.switchWorkspace(w.id, context);
            if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
          } catch (e) {
            if (mounted) {
              setState(() => _isLoading = false);
              if (e is UserBannedException) {
                Navigator.pushNamedAndRemoveUntil(context, '/banned', (route) => false);
                return;
              }
              final errStr = e.toString().toLowerCase();
              final isRTL = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode == 'ar';
              if (e is DeviceMismatchException || errStr.contains('mismatch') || errStr.contains('linked to another device') || errStr.contains('disconnect the old device')) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => _buildErrorPrompt(
                    context,
                    title: isRTL ? 'تنبيه الأمان' : 'Security Alert',
                    message: isRTL 
                        ? 'هذا الحساب مرتبط بجهاز آخر بالفعل. يرجى إلغاء ربط الجهاز القديم أولاً.'
                        : 'This account is already linked to another device. Please disconnect the old device first.',
                    icon: Icons.phonelink_lock_rounded,
                    isExitButton: true,
                  ),
                );
              }
            }
          }
        },
      ),
    );
  }

  Widget _buildErrorPrompt(BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
    Color accentColor = const Color(0xFFF43F5E),
    String? buttonText,
    bool isExitButton = false,
  }) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.9),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(color: Colors.black54, blurRadius: 40, spreadRadius: 10)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: GoogleFonts.cairo(
                  color: Colors.white60,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (isExitButton) {
                      SecurityService.exitApp();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    buttonText ?? (isExitButton
                        ? (lang.currentLocale.languageCode == 'ar' ? 'إغلاق التطبيق' : 'Exit App')
                        : (lang.translate('confirm') ?? 'فهمت')),
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
