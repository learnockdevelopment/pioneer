import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class ErrorScreen extends StatelessWidget {
  final String title;
  final String message;
  final String? code;
  final VoidCallback onRetry;

  const ErrorScreen({
    super.key,
    this.title = 'حدث خطأ غير متوقع',
    this.message = 'نواجه بعض الصعوبات التقنية حالياً. فريقنا يعمل على إصلاح الأمر.',
    this.code = '500',
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Stack(
        children: [
          // Background Blooms
          Positioned(
            top: -100,
            right: -100,
            child: _buildBloom(Theme.of(context).primaryColor.withOpacity(0.2), 400),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: _buildBloom(const Color(0xFFF43F5E).withOpacity(0.1), 350),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Error Illustration
                  TweenAnimationBuilder<double>(
                    duration: const Duration(seconds: 1),
                    tween: Tween(begin: 0, end: 1),
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.scale(
                        scale: 0.8 + (0.2 * value),
                        child: child,
                      ),
                    ),
                    child: Container(
                      height: 280,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).primaryColor.withOpacity(0.2),
                            blurRadius: 40,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Image.asset(
                          'assets/error_illustration.png', // We'll need to make sure this path exists or use a dynamic one
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 48),

                  // Error Code Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF43F5E).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF43F5E).withOpacity(0.2)),
                    ),
                    child: Text(
                      'ERROR CODE: $code',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFF43F5E),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  Text(
                    message,
                    style: GoogleFonts.cairo(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 56),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onRetry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.refresh_rounded),
                          const SizedBox(width: 12),
                          Text(
                            'المحاولة مرة أخرى',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  TextButton(
                    onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
                    child: Text(
                      'العودة للرئيسية',
                      style: GoogleFonts.cairo(
                        color: Colors.white.withOpacity(0.3),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
