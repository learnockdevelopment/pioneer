import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:elmasa/providers/language_provider.dart';
import 'package:elmasa/providers/workspace_provider.dart';
import 'dart:ui';

class UpdateScreen extends StatelessWidget {
  final String? releaseNotes;
  final String? androidUrl;
  final String? iosUrl;

  const UpdateScreen({
    super.key,
    this.releaseNotes,
    this.androidUrl,
    this.iosUrl,
  });

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final isRTL = lang.currentLocale.languageCode == 'ar';
    final wp = Provider.of<WorkspaceProvider>(context);
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFF060913),
      body: Stack(
        children: [
          // Background Gradient Blobs
          Positioned(
            top: -100,
            right: -100,
            child: _buildGlowSphere(primaryColor.withOpacity(0.18), 350),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: _buildGlowSphere(const Color(0xFF6366F1).withOpacity(0.12), 300),
          ),
          Positioned(
            top: 250,
            left: -100,
            child: _buildGlowSphere(const Color(0xFFEC4899).withOpacity(0.06), 250),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: Column(
                  children: [
                    const SizedBox(height: 30),
                    
                    // Floating Glowing Icon
                    Center(
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [primaryColor.withOpacity(0.15), const Color(0xFF6366F1).withOpacity(0.05)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.2),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.system_update_rounded,
                            size: 64,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Version Title Header
                    Text(
                      isRTL ? 'تحديث جديد متوفر' : 'New Update Available',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    Text(
                      isRTL
                          ? 'لضمان أفضل أداء وحماية لحسابك، يرجى تثبيت التحديث الجديد.'
                          : 'Please update your application to ensure maximum security and efficiency.',
                      style: GoogleFonts.cairo(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Version Badge compare chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, color: primaryColor, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            wp.mobileLatestVersion != null 
                                ? '${isRTL ? 'إصدار' : 'Version'} ${wp.mobileLatestVersion}'
                                : (isRTL ? 'أحدث إصدار' : 'Latest Version'),
                            style: GoogleFonts.outfit(
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Glassmorphic release notes box
                    if (releaseNotes != null && releaseNotes!.trim().isNotEmpty) ...[
                      Align(
                        alignment: isRTL ? Alignment.centerRight : Alignment.centerLeft,
                        child: Text(
                          isRTL ? 'أبرز التغييرات والميزات:' : 'Release Highlights:',
                          style: GoogleFonts.cairo(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.06),
                              ),
                            ),
                            child: Text(
                              releaseNotes!,
                              style: GoogleFonts.cairo(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 13,
                                height: 1.7,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 48),

                    // Action buttons
                    if (androidUrl != null && androidUrl!.trim().isNotEmpty && androidUrl != 'null') ...[
                      _buildUpdateAction(
                        label: isRTL ? 'تحديث عبر Google Play' : 'Update on Google Play',
                        icon: Icons.android_rounded,
                        onTap: () => wp.launchUrl(androidUrl!),
                        primaryColor: primaryColor,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (iosUrl != null && iosUrl!.trim().isNotEmpty && iosUrl != 'null') ...[
                      _buildUpdateAction(
                        label: isRTL ? 'تحديث عبر App Store' : 'Update on App Store',
                        icon: Icons.apple_rounded,
                        onTap: () => wp.launchUrl(iosUrl!),
                        primaryColor: primaryColor,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowSphere(Color color, double size) {
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

  Widget _buildUpdateAction({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color primaryColor,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [primaryColor, const Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 20),
        label: Text(
          label,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
    );
  }
}
