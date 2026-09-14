import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:elmasa/providers/workspace_provider.dart';
import 'package:elmasa/providers/language_provider.dart';
import 'package:elmasa/config/app_config.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:elmasa/services/api_service.dart';
import 'error_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  bool _otpSent = false;
  bool _isPasswordObscure = true;
  bool _isConfirmPasswordObscure = true;

  final List<Map<String, String>> _countries = const [
    {'name': 'Egypt', 'code': '+20', 'flag': '🇪🇬', 'nameAr': 'مصر'},
    {'name': 'Saudi Arabia', 'code': '+966', 'flag': '🇸🇦', 'nameAr': 'السعودية'},
    {'name': 'United Arab Emirates', 'code': '+971', 'flag': '🇦🇪', 'nameAr': 'الإمارات'},
    {'name': 'Kuwait', 'code': '+965', 'flag': '🇰🇼', 'nameAr': 'الكويت'},
    {'name': 'Oman', 'code': '+968', 'flag': '🇴🇲', 'nameAr': 'عمان'},
    {'name': 'Qatar', 'code': '+974', 'flag': '🇶🇦', 'nameAr': 'قطر'},
    {'name': 'Bahrain', 'code': '+973', 'flag': '🇧🇭', 'nameAr': 'البحرين'},
    {'name': 'Jordan', 'code': '+962', 'flag': '🇯🇴', 'nameAr': 'الأردن'},
    {'name': 'Iraq', 'code': '+964', 'flag': '🇮🇶', 'nameAr': 'العراق'},
  ];
  Map<String, String>? _selectedCountry;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _selectedCountry = _countries[0]; // Egypt as default
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _userController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Widget _buildAnimatedBackground(Color primaryColor, bool isDark) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Stack(
          children: [
            // Fixed base gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark 
                      ? [const Color(0xFF0F172A), const Color(0xFF020617)]
                      : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
                ),
              ),
            ),
            // Floating Bloom 1
            Positioned(
              top: -100 + (50 * _animController.value),
              right: -100 + (30 * (1 - _animController.value)),
              child: _buildBloom(primaryColor.withOpacity(isDark ? 0.2 : 0.12), 400),
            ),
            // Floating Bloom 2
            Positioned(
              bottom: -50 + (40 * (1 - _animController.value)),
              left: -50 + (60 * _animController.value),
              child: _buildBloom(const Color(0xFFF43F5E).withOpacity(isDark ? 0.15 : 0.08), 350),
            ),
            // Floating Bloom 3 (Center)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.4,
              left: MediaQuery.of(context).size.width * 0.1,
              child: _buildBloom(const Color(0xFF8B5CF6).withOpacity(isDark ? 0.08 : 0.05), 300),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBloom(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
        ),
      ),
    );
  }

  void _showCountrySelector() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final isRTL = lang.currentLocale.languageCode == 'ar';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
             padding: const EdgeInsets.symmetric(vertical: 20),
             decoration: BoxDecoration(
               color: Theme.of(context).cardColor,
               borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
               border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
             ),
             child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                 Container(
                   width: 40,
                   height: 4,
                   margin: const EdgeInsets.only(bottom: 16),
                   decoration: BoxDecoration(
                     color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                     borderRadius: BorderRadius.circular(2),
                   ),
                 ),
                 Text(
                   isRTL ? 'اختر رمز الدولة' : 'Select Country Code',
                   style: TextStyle(
                     color: Theme.of(context).colorScheme.onSurface,
                     fontSize: 16,
                     fontWeight: FontWeight.bold,
                   ),
                 ),
                 const SizedBox(height: 16),
                 Flexible(
                   child: ListView.builder(
                     shrinkWrap: true,
                     itemCount: _countries.length,
                     itemBuilder: (context, index) {
                       final c = _countries[index];
                       final name = isRTL ? c['nameAr']! : c['name']!;
                       return ListTile(
                         leading: Text(c['flag']!, style: const TextStyle(fontSize: 24)),
                         title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                         trailing: Directionality(
                           textDirection: TextDirection.ltr,
                           child: Text(c['code']!, style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w900)),
                         ),
                         onTap: () {
                           setState(() {
                             _selectedCountry = c;
                           });
                           Navigator.pop(context);
                         },
                       );
                     },
                   ),
                 ),
               ],
             ),
          ),
        );
      },
    );
  }

  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Theme.of(context).cardColor,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
            dialogBackgroundColor: Theme.of(context).scaffoldBackgroundColor,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthDateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  void _sendVerificationCode() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final isRTL = lang.currentLocale.languageCode == 'ar';

    if (_nameController.text.trim().isEmpty ||
        _userController.text.trim().isEmpty ||
        _passController.text.trim().isEmpty ||
        _confirmPassController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _birthDateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(lang.translate('fill_fields') ?? (isRTL ? 'يرجى ملء جميع الحقول' : 'Please fill all fields')),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    if (_passController.text != _confirmPassController.text) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isRTL ? 'كلمتا المرور غير متطابقتين' : 'Passwords do not match'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    setState(() => _isLoading = true);
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);

    try {
      await wp.sendOtp(kSiteHost, _userController.text.trim());
      setState(() {
        _otpSent = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(lang.translate('otp_sent_success') ?? (isRTL ? 'تم إرسال كود التحقق بنجاح.' : 'Verification code has been sent successfully.')),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      debugPrint('❌ SEND OTP FAILED: $e. Attempting direct registration fallback...');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('404') || errStr.contains('405') || errStr.contains('not found') || errStr.contains('unsupported') || errStr.contains('format') || errStr.contains('server')) {
        await _registerDirectly();
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => _buildErrorPrompt(
              context,
              title: lang.translate('register_failed') ?? (isRTL ? 'فشل التسجيل' : 'Registration Failed'),
              message: e.toString().replaceAll('Exception: ', '').replaceAll('ServerException: ', ''),
              icon: Icons.error_outline_rounded,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerDirectly() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final isRTL = lang.currentLocale.languageCode == 'ar';
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);

    String cleanPhone = _phoneController.text.trim();
    if (cleanPhone.startsWith('0')) {
      cleanPhone = cleanPhone.substring(1);
    }
    final fullPhone = '${_selectedCountry?['code'] ?? ""}$cleanPhone';

    try {
      await wp.addWorkspaceRegister(
        host: kSiteHost,
        name: _nameController.text.trim(),
        email: _userController.text.trim(),
        password: _passController.text.trim(),
        phone: fullPhone,
        birthDate: _birthDateController.text.trim(),
      );
      debugPrint('✅ DIRECT REGISTER SUCCESS');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.translate('registration_success') ?? (isRTL ? 'تم التسجيل بنجاح!' : 'Registration successful!')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacementNamed(context, '/profile-setup', arguments: fullPhone);
      }
    } catch (e) {
      debugPrint('❌ DIRECT REGISTER FAILED: $e');
      if (mounted) {
        final errStr = e.toString().toLowerCase();
        if (e is DeviceMismatchException || errStr.contains('mismatch') || errStr.contains('linked to another device') || errStr.contains('disconnect the old device')) {
          showDialog(
            context: context,
            builder: (context) => _buildErrorPrompt(
              context,
              title: isRTL ? 'تنبيه الأمان' : 'Security Alert',
              message: isRTL 
                  ? 'هذا الحساب مرتبط بجهاز آخر بالفعل. يرجى إلغاء ربط الجهاز القديم أولاً.'
                  : 'This account is already linked to another device. Please disconnect the old device first.',
              icon: Icons.phonelink_lock_rounded,
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (context) => _buildErrorPrompt(
              context,
              title: lang.translate('register_failed') ?? (isRTL ? 'فشل التسجيل' : 'Registration Failed'),
              message: e.toString().replaceAll('Exception: ', '').replaceAll('ServerException: ', ''),
              icon: Icons.error_outline_rounded,
            ),
          );
        }
      }
    }
  }

  void _verifyCodeAndRegister() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final isRTL = lang.currentLocale.languageCode == 'ar';

    if (_otpController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(lang.translate('fill_fields') ?? (isRTL ? 'يرجى إدخال كود التحقق' : 'Please enter verification code')),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    setState(() => _isLoading = true);
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);

    String cleanPhone = _phoneController.text.trim();
    if (cleanPhone.startsWith('0')) {
      cleanPhone = cleanPhone.substring(1);
    }
    final fullPhone = '${_selectedCountry?['code'] ?? ""}$cleanPhone';

    try {
      await wp.verifyOtpAndRegister(
        host: kSiteHost,
        name: _nameController.text.trim(),
        email: _userController.text.trim(),
        password: _passController.text.trim(),
        phone: fullPhone,
        otp: _otpController.text.trim(),
        birthDate: _birthDateController.text.trim(),
      );
      debugPrint('✅ OTP REGISTER SUCCESS');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.translate('registration_success') ?? (isRTL ? 'تم التسجيل بنجاح!' : 'Registration successful!')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacementNamed(context, '/profile-setup', arguments: fullPhone);
      }
    } catch (e) {
      debugPrint('❌ OTP REGISTER FAILED: $e');
      if (mounted) {
        final errStr = e.toString().toLowerCase();
        if (e is DeviceMismatchException || errStr.contains('mismatch') || errStr.contains('linked to another device') || errStr.contains('disconnect the old device')) {
          showDialog(
            context: context,
            builder: (context) => _buildErrorPrompt(
              context,
              title: isRTL ? 'تنبيه الأمان' : 'Security Alert',
              message: isRTL 
                  ? 'هذا الحساب مرتبط بجهاز آخر بالفعل. يرجى إلغاء ربط الجهاز القديم أولاً.'
                  : 'This account is already linked to another device. Please disconnect the old device first.',
              icon: Icons.phonelink_lock_rounded,
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (context) => _buildErrorPrompt(
              context,
              title: lang.translate('register_failed') ?? (isRTL ? 'فشل التحقق' : 'Verification Failed'),
              message: e.toString().replaceAll('Exception: ', '').replaceAll('ServerException: ', ''),
              icon: Icons.error_outline_rounded,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool isObscure = false,
    bool isRTL = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
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
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: fieldBorder),
          ),
          child: TextField(
            controller: controller,
            obscureText: isObscure,
            keyboardType: keyboardType,
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

  Widget _buildPhoneField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isRTL,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final fieldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFF);
    final fieldBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final fieldText = isDark ? Colors.white : const Color(0xFF1E293B);
    final hintColor = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);

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
        const SizedBox(height: 6),
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: fieldBorder),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: _showCountrySelector,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_selectedCountry?['flag'] ?? '🇪🇬', style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 4),
                      Text(
                        _selectedCountry?['code'] ?? '+20',
                        style: TextStyle(
                          color: fieldText,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, color: isDark ? Colors.white38 : Colors.black38),
                    ],
                  ),
                ),
              ),
              Container( 
                width: 1,
                height: 24,
                color: isDark ? Colors.white10 : Colors.black12,
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: fieldText, fontWeight: FontWeight.bold, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(color: hintColor),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
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
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: fieldBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: fieldBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 16),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    controller.text.isEmpty ? hint : controller.text,
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



  Widget _buildErrorPrompt(BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
    Color accentColor = const Color(0xFFF43F5E),
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
            boxShadow: const [
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
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(lang.translate('confirm') ?? 'فهمت', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Enhanced Background Design with Animated Gradients
          _buildAnimatedBackground(primaryColor, isDark),
          
          // Subtle Blur Overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(color: Colors.transparent),
            ),
          ),

          Positioned.fill(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // App Logo inside premium container
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      lang.translate('register') ?? (isRTL ? 'إنشاء حساب جديد' : 'Register Account'),
                      style: GoogleFonts.cairo(
                        color: titleColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isRTL ? 'انضم إلينا اليوم وابدأ رحلتك التعليمية' : 'Join us today and start your learning journey',
                      style: GoogleFonts.cairo(
                        color: subtitleColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // Modern Form Container
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: cardBorderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Directionality(
                        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!_otpSent) ...[
                              _buildTextField(
                                controller: _nameController,
                                label: lang.translate('full_name') ?? (isRTL ? 'الاسم كامل' : 'Full Name'),
                                icon: Icons.person_outline_rounded,
                                hint: isRTL ? 'محمد أحمد' : 'John Doe',
                                isRTL: isRTL,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _userController,
                                label: lang.translate('email') ?? (isRTL ? 'البريد الإلكتروني' : 'Email Address'),
                                icon: Icons.alternate_email_rounded,
                                hint: 'user@email.com',
                                keyboardType: TextInputType.emailAddress,
                                isRTL: isRTL,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _passController,
                                label: lang.translate('password') ?? (isRTL ? 'كلمة المرور' : 'Password'),
                                icon: Icons.lock_outline_rounded,
                                hint: '••••••••',
                                isObscure: _isPasswordObscure,
                                isRTL: isRTL,
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
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _confirmPassController,
                                label: isRTL ? 'تأكيد كلمة المرور' : 'Confirm Password',
                                icon: Icons.lock_outline_rounded,
                                hint: '••••••••',
                                isObscure: _isConfirmPasswordObscure,
                                isRTL: isRTL,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isConfirmPasswordObscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isConfirmPasswordObscure = !_isConfirmPasswordObscure;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildDateField(
                                controller: _birthDateController,
                                label: isRTL ? 'تاريخ الميلاد' : 'Birthdate',
                                icon: Icons.calendar_today_rounded,
                                hint: isRTL ? 'اختر تاريخ الميلاد' : 'Choose birthdate',
                                onTap: () => _selectBirthDate(context),
                              ),
                              const SizedBox(height: 16),
                              _buildPhoneField(
                                controller: _phoneController,
                                label: lang.translate('phone_number') ?? (isRTL ? 'رقم الهاتف' : 'Phone Number'),
                                hint: '1012345678',
                                isRTL: isRTL,
                              ),
                            ] else ...[
                              // Enhanced OTP Verification UI
                              Center(
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.mark_email_read_rounded, size: 36, color: primaryColor),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      lang.translate('otp_sent_success') ?? (isRTL ? 'تم إرسال كود التحقق بنجاح' : 'Verification code sent'),
                                      style: GoogleFonts.cairo(
                                        color: titleColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: subtitleColor.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: subtitleColor.withOpacity(0.1)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.email_outlined, size: 16, color: subtitleColor),
                                          const SizedBox(width: 8),
                                          Text(
                                            _userController.text,
                                            style: GoogleFonts.cairo(
                                              color: primaryColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),
                              _buildTextField(
                                controller: _otpController,
                                label: lang.translate('enter_otp') ?? (isRTL ? 'أدخل كود التحقق' : 'Enter Verification Code'),
                                icon: Icons.vpn_key_rounded,
                                hint: '123456',
                                keyboardType: TextInputType.number,
                                isRTL: isRTL,
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: TextButton.icon(
                                  onPressed: _isLoading ? null : () => setState(() => _otpSent = false),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    backgroundColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: Icon(Icons.edit_rounded, size: 16, color: subtitleColor),
                                  label: Text(
                                    lang.translate('change_email') ?? (isRTL ? 'تعديل البريد الإلكتروني' : 'Change Email'),
                                    style: GoogleFonts.cairo(
                                      color: subtitleColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 28),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  gradient: LinearGradient(
                                    colors: [
                                      primaryColor,
                                      primaryColor.withOpacity(0.85),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.25),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    )
                                  ]
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading 
                                      ? null 
                                      : (_otpSent ? _verifyCodeAndRegister : _sendVerificationCode),
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
                                          (_otpSent 
                                              ? (lang.translate('verify_and_register') ?? (isRTL ? 'التحقق وإنشاء الحساب' : 'VERIFY & REGISTER'))
                                              : (lang.translate('send_verification_code') ?? (isRTL ? 'إرسال كود التحقق' : 'SEND CODE'))).toUpperCase(),
                                          style: GoogleFonts.cairo(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Navigation to Login screen
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        lang.translate('already_have_account') ?? (isRTL ? 'لديك حساب بالفعل؟ تسجيل الدخول' : 'Already have an account? Login'),
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
