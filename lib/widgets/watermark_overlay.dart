import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elmasa/providers/workspace_provider.dart';

class WatermarkOverlay extends StatefulWidget {
  final bool isContentOnly;
  const WatermarkOverlay({super.key, this.isContentOnly = false});

  @override
  State<WatermarkOverlay> createState() => _WatermarkOverlayState();
}

class _WatermarkOverlayState extends State<WatermarkOverlay> {
  Timer? _timer;
  double _topPercent = 0.3;
  double _leftPercent = 0.3;
  final Random _random = Random();
  int _currentIntervalSeconds = 15;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    _currentIntervalSeconds = max(3, wp.watermarkIntervalSeconds);
    _timer = Timer.periodic(Duration(seconds: _currentIntervalSeconds), (timer) {
      if (!mounted) return;
      setState(() {
        // Random position between 10% and 75%
        _topPercent = (_random.nextInt(65) + 10) / 100.0;
        _leftPercent = (_random.nextInt(65) + 10) / 100.0;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wp = Provider.of<WorkspaceProvider>(context);
    final interval = max(3, wp.watermarkIntervalSeconds);
    if (interval != _currentIntervalSeconds) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _buildWatermarkText(Map<String, dynamic> user, String fieldsString) {
    final fields = fieldsString.split(RegExp(r'[\s,;]+')).map((f) => f.trim().toLowerCase()).toList();
    final parts = <String>[];

    final userId = user['id']?.toString() ?? '';
    final name = user['name']?.toString() ?? '';
    final email = user['email']?.toString() ?? '';
    final phone = user['phone']?.toString() ?? '';

    if (fields.contains('id') && userId.isNotEmpty) {
      parts.add('ID: $userId');
    }
    if (fields.contains('name') && name.isNotEmpty) {
      parts.add(name);
    }
    if (fields.contains('email') && email.isNotEmpty) {
      parts.add(email);
    }
    if (fields.contains('phone') && phone.isNotEmpty) {
      parts.add(phone);
    }

    if (parts.isEmpty) {
      if (name.isNotEmpty) {
        return userId.isNotEmpty ? '$name ($userId)' : name;
      }
      return userId.isNotEmpty ? 'ID: $userId' : 'Protected Connection';
    }

    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final wp = Provider.of<WorkspaceProvider>(context);
    if (wp.activeWorkspace == null || !wp.watermarkEnabled) {
      return const SizedBox.shrink();
    }

    // Check scope
    if (widget.isContentOnly) {
      // Shown over video player: always show if watermark is enabled
    } else {
      // Global app overlay: show only if scope is 'all_site'
      if (wp.watermarkScope != 'all_site') {
        return const SizedBox.shrink();
      }
    }

    final Map<String, dynamic> user = (wp.cachedME?['user'] is Map)
        ? Map<String, dynamic>.from(wp.cachedME!['user'])
        : {};

    if (user.isEmpty) {
      return const SizedBox.shrink();
    }

    final String text = _buildWatermarkText(user, wp.watermarkFields);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Aesthetics matching spec
    final pillBg = isDark
        ? const Color(0xFF0F172A).withOpacity(0.75) // rgba(15, 23, 42, 0.75)
        : Colors.white.withOpacity(0.85);          // rgba(255, 255, 255, 0.85)

    final textColor = isDark ? Colors.white70 : Colors.black87;

    return IgnorePointer(
      ignoring: true,
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 1000),
            alignment: Alignment(_leftPercent * 2 - 1, _topPercent * 2 - 1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 30,
                      spreadRadius: 0,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _PulseDot(),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        text,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          decoration: TextDecoration.none,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.redAccent.withOpacity(0.2 + (_pulseController.value * 0.8)),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(_pulseController.value),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}
