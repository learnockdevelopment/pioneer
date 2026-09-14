import 'package:flutter/material.dart';
import 'package:elmasa/providers/workspace_provider.dart';
import 'package:elmasa/providers/language_provider.dart';
import 'package:provider/provider.dart' show Provider;

class PremiumLoader extends StatefulWidget {
  final Color? color;
  final bool useAppLogoOnly;
  final double size;
  const PremiumLoader({super.key, this.color, this.useAppLogoOnly = false, this.size = 150});

  @override
  State<PremiumLoader> createState() => _PremiumLoaderState();
}

class _PremiumLoaderState extends State<PremiumLoader> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.color ?? Theme.of(context).primaryColor;
    final wp = Provider.of<WorkspaceProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final activeWorkspace = wp.activeWorkspace;
    final logoUrl = activeWorkspace?.logoUrl ?? wp.publicLogoUrl;
    
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1.1).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
                child: Container(
                  width: widget.size, height: widget.size,
                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: primary.withOpacity(0.12), blurRadius: widget.size * 0.4, spreadRadius: widget.size * 0.06)]),
                ),
              ),
              
              SizedBox(
                width: widget.size * 0.66, height: widget.size * 0.66,
                child: CircularProgressIndicator(strokeWidth: widget.size * 0.02, valueColor: AlwaysStoppedAnimation<Color>(primary), backgroundColor: primary.withOpacity(0.05)),
              ),

              Container(
                width: widget.size * 0.46, height: widget.size * 0.46,
                child: (logoUrl != null && logoUrl.isNotEmpty) 
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(40),
                        child: Image.network(
                          logoUrl, 
                          fit: BoxFit.cover,
                          loadingBuilder: (c,w,p) => (p == null) ? w : Icon(Icons.school_rounded, color: primary, size: widget.size * 0.26),
                          errorBuilder: (c,e,s) => Icon(Icons.school_rounded, color: primary, size: widget.size * 0.26),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(40),
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (c,e,s) => Icon(Icons.school_rounded, color: primary, size: widget.size * 0.26),
                        ),
                      ),
              ),
            ],
          ),
          if (widget.size > 50) ...[
            const SizedBox(height: 16),
            Text(
              (wp.appName.isNotEmpty ? wp.appName : lang.translate("initializing_security")),
              style: TextStyle(color: primary.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
          ],
        ],
      ),
    );
  }
}
