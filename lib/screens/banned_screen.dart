import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:elmasa/providers/workspace_provider.dart';
import 'package:elmasa/providers/language_provider.dart';
import 'package:elmasa/services/security_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

class BannedScreen extends StatelessWidget {
  const BannedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final lang = Provider.of<LanguageProvider>(context);
    final isRTL = lang.currentLocale.languageCode == 'ar';

    final whatsappNumber = wp.activeWorkspace?.whatsappNumber ?? '';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // Deep dark slate
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.1),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.gavel_rounded,
                  color: Colors.redAccent,
                  size: 64,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                isRTL ? 'تم إيقاف حسابك' : 'Account Suspended',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    Text(
                      isRTL
                          ? 'تم إيقاف حسابك من قبل إدارة الأكاديمية لمخالفة شروط الاستخدام. يجب إلغاء ربط هذا الجهاز أولاً لتتمكن من المتابعة. يرجى التواصل مع الدعم الفني.'
                          : 'Your account has been suspended by the academy administrator for violating the terms of use. You must unlink this device first to proceed. Please contact support.',
                      style: GoogleFonts.cairo(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await wp.logout();
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (route) => false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isRTL ? 'تسجيل الدخول بحساب آخر' : 'Login with other account',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              )],
          ),
        ),
      ),
    );
  }
}
