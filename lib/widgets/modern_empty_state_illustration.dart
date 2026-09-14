import 'package:flutter/material.dart';

class ModernEmptyStateIllustration extends StatelessWidget {
  final double size;
  final Color primaryColor;

  const ModernEmptyStateIllustration({
    super.key,
    this.size = 140,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Soft Glow Ring
          Container(
            width: size * 0.95,
            height: size * 0.95,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  primaryColor.withOpacity(0.25),
                  primaryColor.withOpacity(0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          
          // Middle Glass Layer
          Container(
            width: size * 0.72,
            height: size * 0.72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor.withOpacity(0.12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ],
            ),
          ),

          // Inner Core Gradient Badge
          Container(
            width: size * 0.52,
            height: size * 0.52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor.withOpacity(0.9),
                  primaryColor,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 34,
              color: Colors.white,
            ),
          ),

          // Top Floating Little Sparkle Badge 1
          Positioned(
            top: size * 0.12,
            right: size * 0.14,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.15),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
              ),
              child: const Icon(
                Icons.star_rounded,
                size: 14,
                color: Colors.amberAccent,
              ),
            ),
          ),

          // Bottom Floating Little Badge 2
          Positioned(
            bottom: size * 0.14,
            left: size * 0.12,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(0.3),
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
              ),
              child: const Icon(
                Icons.auto_awesome_mosaic_rounded,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
