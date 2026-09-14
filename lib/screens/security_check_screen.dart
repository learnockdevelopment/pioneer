import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/security_service.dart';
import '../providers/language_provider.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';

class SecurityCheckScreen extends StatefulWidget {
  const SecurityCheckScreen({super.key});

  @override
  State<SecurityCheckScreen> createState() => _SecurityCheckScreenState();
}

class _SecurityCheckScreenState extends State<SecurityCheckScreen> {
  String _statusKey = "verifying_system";
  bool _isChecking = true;
  String? _errorKey;

  @override
  void initState() {
    super.initState();
    _performChecks();
  }

  Future<void> _performChecks() async {
    await Future.delayed(const Duration(seconds: 2)); // Artificial delay for UX
    
    bool isSafe = await SecurityService.isDeviceSafe();
    
    if (!mounted) return;

    if (isSafe) {
      setState(() {
        _statusKey = "system_safe";
        _isChecking = false;
      });
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } else {
      setState(() {
        _errorKey = "security_failure_msg";
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF020617), Color(0xFF0F172A)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 100, color: Theme.of(context).primaryColor),
            const SizedBox(height: 48),
            if (_isChecking) ...[
              CircularProgressIndicator(color: Theme.of(context).primaryColor, strokeWidth: 3),
              const SizedBox(height: 24),
              Text(
                lang.translate(_statusKey), 
                style: GoogleFonts.cairo(
                  fontSize: 18, 
                  color: Colors.white70,
                  fontWeight: FontWeight.w600
                )
              ),
            ] else if (_errorKey != null) ...[
              const Icon(Icons.error_outline_rounded, size: 64, color: Color(0xFFF43F5E)),
              const SizedBox(height: 12),
              Text(
                lang.translate("security_block"),
                style: GoogleFonts.cairo(
                  color: const Color(0xFFF43F5E),
                  fontSize: 22,
                  fontWeight: FontWeight.bold
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  lang.translate(_errorKey!),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    color: Colors.white, 
                    fontSize: 16,
                    fontWeight: FontWeight.w500
                  ),
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () => SecurityService.exitApp(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF43F5E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(lang.translate("close_app"), style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
