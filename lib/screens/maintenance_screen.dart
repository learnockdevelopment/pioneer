import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:elmasa/providers/language_provider.dart';
import 'package:elmasa/providers/workspace_provider.dart';

class MaintenanceScreen extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRefresh;

  const MaintenanceScreen({
    super.key,
    required this.title,
    required this.message,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final isRTL = lang.currentLocale.languageCode == 'ar';
    final wp = Provider.of<WorkspaceProvider>(context);
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Stack(
        children: [
          // Background blooms
          Positioned(
            top: -150,
            right: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [primaryColor.withOpacity(0.15), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.amber.withOpacity(0.08), Colors.transparent],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  
                  // Pulse icon container
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amber.withOpacity(0.2), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.05),
                          blurRadius: 40,
                          spreadRadius: 10,
                        )
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.engineering_rounded,
                        size: 56,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Title
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Message in glass container
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Text(
                      message,
                      style: GoogleFonts.cairo(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.7,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const Spacer(),

                  // Refresh/Retry action
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [primaryColor, primaryColor.withOpacity(0.8)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                        label: Text(
                          isRTL ? 'تحديث الحالة' : 'Check Status',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Contact support option if available
                  TextButton.icon(
                    onPressed: () {
                      final phone = wp.cachedDashboard?['site_whatsapp']?.toString() ?? '';
                      if (phone.isNotEmpty) {
                        wp.launchUrl('https://wa.me/${phone.replaceAll('+', '')}');
                      }
                    },
                    icon: const Icon(Icons.support_agent_rounded, color: Colors.white38),
                    label: Text(
                      isRTL ? 'اتصل بالدعم الفني' : 'Contact Support',
                      style: GoogleFonts.cairo(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.bold),
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
}
