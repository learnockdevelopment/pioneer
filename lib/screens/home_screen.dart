import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../services/api_service.dart';
import 'material_viewer_screen.dart';
import 'package:provider/provider.dart';
import 'package:elmasa/providers/language_provider.dart';
import 'package:elmasa/providers/workspace_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _searchMaterial() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final material = await _apiService.getPlayback(code);
      if (!mounted) return;

      if (material != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MaterialViewerScreen(
              material: material,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("عذراً، الرمز الذي أدخلته غير صحيح", textAlign: TextAlign.right),
            backgroundColor: const Color(0xFFF43F5E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("عذراً، حدث خطأ في الاتصال بالخدمة", textAlign: TextAlign.right),
          backgroundColor: const Color(0xFFF43F5E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final wp = Provider.of<WorkspaceProvider>(context);
    final isAr = lang.currentLocale.languageCode == 'ar';
    final siteName = wp.appName;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF020617), // Deepest Slate
        body: Stack(
          children: [
            // Enhanced Background Design with Animated Gradients
            _buildAnimatedBackground(),
            
            // Subtle Blur Overlay
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(color: Colors.black.withOpacity(0.2)),
              ),
            ),
            
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 60),
                      // Header Section
                      Center(
                        child: Hero(
                          tag: 'app_logo',
                          child: Container(
                            width: 158,
                            height: 158,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).primaryColor.withOpacity(0.15),
                                  blurRadius: 50,
                                  spreadRadius: 5,
                                )
                              ]
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/logo.png',
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        "دخول آمن",
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.5),
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        siteName,
                        style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 60),
                      
                      // Arabic Search Section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Text(
                              "أدخل رمز الوصول الخاص بك",
                              style: GoogleFonts.cairo(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                )
                              ]
                            ),
                            child: TextField(
                              controller: _codeController,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.robotoMono(
                                color: Colors.white, 
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3,
                              ),
                              decoration: InputDecoration(
                                hintText: "••••••••",
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.1)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 26),
                              ),
                              onSubmitted: (_) => _searchMaterial(),
                            ),
                          ),
                          const SizedBox(height: 28),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _searchMaterial,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 26),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              minimumSize: const Size(double.infinity, 0),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "تفعيل المحتوى",
                                        style: GoogleFonts.cairo(
                                          fontWeight: FontWeight.bold, 
                                          fontSize: 18, 
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      const Icon(Icons.flash_on_rounded, size: 22),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),
                      
                      // Footer
                      Text(
                        siteName.isNotEmpty ? "مدعوم بنظام $siteName الذكي™" : "منصة تعليمية ذكية",
                        style: GoogleFonts.cairo(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Stack(
          children: [
            // Fixed base gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF020617), Color(0xFF0F172A)],
                ),
              ),
            ),
            // Floating Bloom 1
            Positioned(
              top: -100 + (50 * _animController.value),
              right: -100 + (30 * (1 - _animController.value)),
              child: _buildBloom(Theme.of(context).primaryColor.withOpacity(0.3), 400),
            ),
            // Floating Bloom 2
            Positioned(
              bottom: -50 + (40 * (1 - _animController.value)),
              left: -50 + (60 * _animController.value),
              child: _buildBloom(const Color(0xFFF43F5E).withOpacity(0.2), 350),
            ),
            // Floating Bloom 3 (Center)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.4,
              left: MediaQuery.of(context).size.width * 0.1,
              child: _buildBloom(const Color(0xFF8B5CF6).withOpacity(0.1), 300),
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
}
