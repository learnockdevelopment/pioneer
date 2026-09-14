import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elmasa/providers/workspace_provider.dart';
import 'package:elmasa/providers/language_provider.dart';
import 'package:elmasa/providers/theme_provider.dart';
import 'package:elmasa/widgets/premium_loader.dart';
import 'package:elmasa/screens/simple_scanner_screen.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class CourseDetailScreen extends StatefulWidget {
  final int courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  Map<String, dynamic>? _courseData;
  bool _isLoading = true;
  bool _isSubscribing = false;
  String? _activeFilter; // null = ALL
  final TextEditingController _couponController = TextEditingController();
  bool _isWhiteboardActive = false;
  int? _whiteboardId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _fetch({bool force = false}) async {
    if (_courseData == null || !force) {
      setState(() => _isLoading = true);
    }
    try {
      final wp = Provider.of<WorkspaceProvider>(context, listen: false);
      _courseData = await wp.getCourse(widget.courseId);
      
      // Check if whiteboard is active for this course
      if (!wp.isGuest) {
        try {
          final res = await wp.request('GET', '/courses/${widget.courseId}/whiteboard');
          if (res != null && res['whiteboard_id'] != null) {
            _whiteboardId = res['whiteboard_id'];
            _isWhiteboardActive = true;
          }
        } catch (_) {
          _isWhiteboardActive = false;
        }
      }
    } catch (e) {
      final wp = Provider.of<WorkspaceProvider>(context, listen: false);
      if (!wp.isGuest && (e.toString().contains('Session expired') || e.toString().contains('unauthorized'))) {
        if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (route) => false);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── SUBSCRIBE: Wallet checkout ────────────────────────────────────────────
  Future<void> _handleWalletCheckout() async {
    if (!_checkLogin(context)) return;
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final sm = ScaffoldMessenger.of(context);
    if (_isSubscribing) return;
    setState(() => _isSubscribing = true);
    try {
      final res = await wp.checkoutWallet(widget.courseId);
      sm.showSnackBar(SnackBar(content: Text(res['message'] ?? 'Enrolled successfully!'), backgroundColor: Colors.green));
      await wp.eagerLoad();
      if (mounted) await _fetch(); // Reload course to reflect enrollment
    } catch (e) {
      final errorStr = e.toString();
      final isInsufficientBalance = errorStr.toLowerCase().contains('balance') || 
                                    errorStr.toLowerCase().contains('insufficient') ||
                                    errorStr.contains('رصيد') ||
                                    errorStr.contains('كاف');
      if (isInsufficientBalance) {
        if (mounted) {
          final showCharge = wp.activeWorkspace?.enablePurchasing ?? true;
          final errorMsg = errorStr.replaceAll('Exception: ', '');
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                lang.currentLocale.languageCode == 'ar' ? 'تنبيه' : 'Alert',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              content: Text(
                errorMsg,
                style: const TextStyle(height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    lang.currentLocale.languageCode == 'ar' ? 'إغلاق' : 'Close',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                if (showCharge)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                        context,
                        '/wallet',
                        arguments: {'prompt': 'insuff_balance'},
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      lang.currentLocale.languageCode == 'ar' ? 'شحن المحفظة' : 'Charge Wallet',
                    ),
                  ),
              ],
            ),
          );
        }
        return;
      }
      final msg = errorStr.contains('already subscribed') || errorStr.contains('مشترك')
          ? 'You are already enrolled!'
          : errorStr;
      sm.showSnackBar(SnackBar(content: Text(msg), backgroundColor: errorStr.contains('already') ? Colors.orange : Colors.red));
      if (errorStr.contains('already subscribed') || errorStr.contains('مشترك')) {
        await wp.eagerLoad();
        if (mounted) await _fetch();
      }
    } finally {
      if (mounted) setState(() => _isSubscribing = false);
    }
  }

  // ─── SHOW FULLSCREEN IMAGE MODAL ──────────────────────────────────────────
  void _showImageModal(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 5.0,
                  child: Hero(
                    tag: imageUrl,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── SUBSCRIBE: Coupon code ─────────────────────────────────────────────────
  void _showCouponSheet(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final primaryColor = Theme.of(context).primaryColor;
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(sheetCtx).viewInsets.bottom + 40),
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lang.translate('redeem_coupon') ?? 'Activate Coupon',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 8),
            Text(lang.translate('coupon_hint') ?? 'Enter your coupon code',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'XXXX-XXXX-XXXX',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                prefixIcon: Icon(Icons.qr_code_rounded, color: primaryColor),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (controller.text.isEmpty) return;
                  final nav = Navigator.of(sheetCtx);
                  final sm = ScaffoldMessenger.of(context);
                  nav.pop();
                  setState(() => _isSubscribing = true);
                    try {
                      final res = await wp.redeemCoupon(controller.text, courseId: widget.courseId);
                    sm.showSnackBar(SnackBar(content: Text(res['message'] ?? 'Success!'), backgroundColor: Colors.green));
                    await wp.eagerLoad();
                    if (mounted) await _fetch();
                  } catch (e) {
                    sm.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                  } finally {
                    if (mounted) setState(() => _isSubscribing = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(lang.translate('confirm') ?? 'Confirm',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(lang.translate('or') ?? 'OR', style: TextStyle(color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: Icon(Icons.qr_code_scanner_rounded, color: primaryColor),
                label: Text(lang.translate('scan_new_code') ?? 'Scan QR Code', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 16)),
                onPressed: () async {
                  final code = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(builder: (_) => SimpleScannerScreen(title: lang.translate('scan_new_code') ?? 'Scan Code')),
                  );
                  if (code != null && code.isNotEmpty) {
                    controller.text = code;
                    // Auto-submit if scanned
                    final nav = Navigator.of(sheetCtx);
                    final sm = ScaffoldMessenger.of(context);
                    nav.pop();
                    setState(() => _isSubscribing = true);
                    try {
                      final res = await wp.redeemCoupon(code, courseId: widget.courseId);
                      sm.showSnackBar(SnackBar(content: Text(res['message'] ?? 'Success!'), backgroundColor: Colors.green));
                      await wp.eagerLoad();
                      if (mounted) await _fetch();
                    } catch (e) {
                      sm.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                    } finally {
                      if (mounted) setState(() => _isSubscribing = false);
                    }
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  side: BorderSide(color: primaryColor.withOpacity(0.5), width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: primaryColor.withOpacity(0.05),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── MATERIAL ROW ──────────────────────────────────────────────────────────
  Widget _buildMaterialItem(
    Map<String, dynamic> material,
    int index,
    List allMaterials,
    bool isEnrolled,
    LanguageProvider lang,
    Color primaryColor,
    Color onSurface,
  ) {
    final type = material['type']?.toString().toLowerCase() ?? 'lesson';
    final isCompleted = material['isCompleted'] ?? false;

    // ACCESS: free OR enrolled
    final isFree = material['is_free'] == 1 || material['is_free'] == true || material['is_free'] == '1';
    final hasAccess = isEnrolled || isFree;

    final isVideo = type == 'video' || type == 'mp4';

    if (type == 'section') {
      return Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.class_rounded, color: primaryColor, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                material['title'] ?? (lang.currentLocale.languageCode == 'ar' ? 'قسم' : 'Section'),
                style: TextStyle(
                  color: onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final String? currentSection = material['section_name']?.toString();
    String? previousSection;
    if (index > 0) {
      previousSection = allMaterials[index - 1]['section_name']?.toString();
    }
    
    final bool isNewSection = currentSection != null && currentSection.trim().isNotEmpty && currentSection != previousSection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isNewSection)
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.class_rounded, color: primaryColor, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    currentSection,
                    style: TextStyle(
                      color: onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        InkWell(
          onTap: () {
            if (!_checkLogin(context)) return;
            if (hasAccess) {
              final nextMaterial = (index + 1 < allMaterials.length) ? allMaterials[index + 1] : null;
              Navigator.pushNamed(context, '/material', arguments: {
                'material': material,
                'courseId': widget.courseId,
                'forceLandscape': isVideo,
                'nextMaterial': nextMaterial,
              });
            } else {
              _showEnrollPrompt(context);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // THUMBNAIL / ICON
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 64,
                      decoration: BoxDecoration(
                        color: hasAccess ? onSurface.withOpacity(0.05) : onSurface.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: material['thumbnail_url'] != null
                            ? Image.network(
                                material['thumbnail_url'],
                                width: 100, height: 64, fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => _typeIcon(type, hasAccess, primaryColor),
                              )
                            : _typeIcon(type, hasAccess, primaryColor),
                      ),
                    ),
                    if (isVideo && hasAccess)
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle, border: Border.all(color: Colors.white30, width: 1)),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                      ),
                    if (!hasAccess)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                        child: Icon(Icons.lock_rounded, color: primaryColor, size: 16),
                      ),
                    if (isCompleted && hasAccess)
                      Positioned(
                        bottom: 4, right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                          child: const Icon(Icons.check, color: Colors.white, size: 10),
                        ),
                      ),
                    // Video duration overlay chip (bottom-left, YouTube style)
                    if (isVideo) Builder(builder: (_) {
                      final rawDuration = material['duration'] ?? material['video_duration'] ?? material['duration_seconds'];
                      if (rawDuration == null) return const SizedBox.shrink();
                      final secs = int.tryParse(rawDuration.toString()) ?? 0;
                      if (secs <= 0) return const SizedBox.shrink();
                      final h = secs ~/ 3600;
                      final m = (secs % 3600) ~/ 60;
                      final s = secs % 60;
                      final label = h > 0
                          ? '${h}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
                          : '${m}:${s.toString().padLeft(2, '0')}';
                      return Positioned(
                        bottom: 5, left: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        material['order_index'] != null ? "${material['order_index']}. ${material['title'] ?? ''}" : "${index + 1}. ${material['title'] ?? ''}",
                        style: TextStyle(
                          color: hasAccess
                              ? (isCompleted ? onSurface.withOpacity(0.5) : onSurface)
                              : onSurface.withOpacity(0.3),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (isFree && !isEnrolled) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                              child: const Text("FREE", style: TextStyle(color: Colors.green, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Icon(
                            isVideo ? Icons.play_circle_outline_rounded : (type == 'quiz' ? Icons.quiz_outlined : Icons.description_outlined),
                            color: onSurface.withOpacity(0.3), size: 11,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            type.toUpperCase(),
                            style: TextStyle(color: onSurface.withOpacity(0.35), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                          // Duration badge for video materials
                          if (isVideo) ...[
                            const SizedBox(width: 8),
                            Builder(builder: (_) {
                              // Try multiple fields the API may send
                              final rawDuration = material['duration'] ?? material['video_duration'] ?? material['duration_seconds'];
                              if (rawDuration == null) return const SizedBox.shrink();
                              final secs = int.tryParse(rawDuration.toString()) ?? 0;
                              if (secs <= 0) return const SizedBox.shrink();
                              final mins = secs ~/ 60;
                              final sec = secs % 60;
                              final label = mins > 0
                                  ? '${mins}m${sec > 0 ? ' ${sec}s' : ''}'
                                  : '${sec}s';
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.timer_outlined, size: 8, color: primaryColor),
                                    const SizedBox(width: 3),
                                    Text(
                                      label,
                                      style: TextStyle(color: primaryColor, fontSize: 8, fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (!hasAccess)
                  Icon(Icons.lock_outline_rounded, color: onSurface.withOpacity(0.15), size: 18),
              ],
            ),
          ),
        ),
        Divider(color: onSurface.withOpacity(0.08), height: 1),
      ],
    );
  }

  Widget _typeIcon(String type, bool hasAccess, Color primary) {
    final isVideo = type == 'video' || type == 'mp4';
    final isQuiz = type == 'quiz' || type == 'exam';
    return Center(
      child: Icon(
        isVideo ? Icons.play_circle_outline_rounded : (isQuiz ? Icons.quiz_outlined : Icons.description_outlined),
        color: hasAccess ? primary.withOpacity(0.4) : primary.withOpacity(0.15),
        size: 28,
      ),
    );
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final dynamic courseObj = _courseData?['data']?['course'] ?? _courseData?['course'];
    final Map<String, dynamic>? course = courseObj is Map<String, dynamic> ? courseObj : null;

    final lang = Provider.of<LanguageProvider>(context);
    final wp = Provider.of<WorkspaceProvider>(context);
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    // ── THEME-AWARE COLOR TOKENS ──────────────────────────────────────────────
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardBg = Theme.of(context).cardColor;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF64748B);
    final textMuted = isDark ? Colors.white.withOpacity(0.35) : Colors.black.withOpacity(0.4);
    final overlayLight = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04);
    final overlayMid = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);
    final divider = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);
    // ─────────────────────────────────────────────────────────────────────────

    final rawMaterials = (course?['materials'] as List?) ?? [];
    final materials = rawMaterials.where((m) {
      if (m is Map) {
        if (m.containsKey('is_active') && m['is_active'] != null) {
          final a = m['is_active'];
          if (a == 0 || a == false || a == '0') return false;
        }
        if (m.containsKey('status') && m['status'] != null) {
          final s = m['status'].toString().toLowerCase();
          if (s == '0' || s == 'inactive' || s == 'draft' || s == 'false') return false;
        }
      }
      return true;
    }).toList();

    final bool hasVideos = materials.any((m) {
      final type = (m['type'] ?? '').toString().toLowerCase();
      return type == 'video' || type == 'mp4';
    });

    final bool hasFiles = materials.any((m) {
      final type = (m['type'] ?? '').toString().toLowerCase();
      return type == 'file' || type == 'pdf' || type == 'doc' || type == 'docx' || type == 'pdf_file' || type == 'document';
    });

    final bool hasQuizzes = materials.any((m) {
      final type = (m['type'] ?? '').toString().toLowerCase();
      return type == 'quiz';
    });

    final bool hasAssignments = materials.any((m) {
      final type = (m['type'] ?? '').toString().toLowerCase();
      return type == 'assignment' || type == 'homework';
    });

    final filteredMaterials = materials.where((m) {
      if (_activeFilter == null) return true;
      final type = (m['type'] ?? '').toString().toLowerCase();
      final isVideo = type == 'video' || type == 'mp4';
      final isFile = type == 'file' || type == 'pdf' || type == 'doc' || type == 'docx' || type == 'pdf_file' || type == 'document';
      final isQuiz = type == 'quiz';
      final isAssignment = type == 'assignment' || type == 'homework';
      switch (_activeFilter) {
        case 'video': return isVideo;
        case 'file':  return isFile;
        case 'quiz':  return isQuiz;
        case 'assignment': return isAssignment;
        default: return true;
      }
    }).toList();

    // ENROLLMENT / ACCESS
    final dynamic enrolledRaw = course?['isEnrolled'] ?? course?['is_enrolled'] ?? course?['is_accessible'];
    final bool isEnrolled = enrolledRaw == true || enrolledRaw == 1 || enrolledRaw == '1' || enrolledRaw == 'true';

    // CATEGORY
    String catStr = (course?['category_path'] ?? course?['category_depth'] ?? "").toString();
    if (catStr.isEmpty && course != null) {
      for (var c in [course['category_name'], course['category'], course['subject'], course['cat_name']]) {
        if (c == null) continue;
        if (c is Map) {
          final n = (c['name'] ?? c['title'] ?? "").toString().trim();
          if (n.isNotEmpty) { catStr = n; break; }
        } else {
          final s = c.toString().trim();
          if (s.isNotEmpty && int.tryParse(s) == null) { catStr = s; break; }
        }
      }
    }

    final isFavorited = wp.localFavoriteIds.contains(widget.courseId);

    if (_isLoading) return Scaffold(backgroundColor: scaffoldBg, body: const Center(child: PremiumLoader()));
    if (course == null) return Scaffold(backgroundColor: scaffoldBg, body: Center(child: Text(lang.translate('failure'), style: TextStyle(color: textSecondary))));

    // CONTINUE BUTTON LOGIC
    final lastAccessed = wp.lastAccessedMaterials[widget.courseId];
    final freeMaterials = materials.where((m) => m['is_free'] == 1 || m['is_free'] == true).toList();
    final accessibleMaterials = isEnrolled ? materials : freeMaterials;
    final Map<String, dynamic> targetMaterial = lastAccessed ??
        (accessibleMaterials.isNotEmpty ? accessibleMaterials[0] : (materials.isNotEmpty ? materials[0] : {}));
    final int targetIndex = materials.indexWhere((m) => (m['id']) == (targetMaterial['id']));
    final nextMat = (targetIndex != -1 && targetIndex + 1 < materials.length) ? materials[targetIndex + 1] : null;

    // COUNT
    final int freeMaterialsCount = materials.where((m) => m['is_free'] == 1 || m['is_free'] == true).length;

    return Scaffold(
      backgroundColor: scaffoldBg,
      // ── SUBSCRIBE BOTTOM BAR (only when not enrolled) ──
      bottomNavigationBar: !isEnrolled
          ? _buildSubscribeBar(course, lang, primaryColor, context)
          : null,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => _fetch(force: true),
            color: primaryColor,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // HERO IMAGE
                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: GestureDetector(
                          onTap: () {
                            final imgUrl = course['image_url'] ?? course['thumbnail_url'];
                            if (imgUrl != null && imgUrl.isNotEmpty) {
                              _showImageModal(context, imgUrl);
                            }
                          },
                          child: Hero(
                            tag: course['image_url'] ?? course['thumbnail_url'] ?? 'course_cover_${widget.courseId}',
                            child: Image.network(
                              course['image_url'] ?? course['thumbnail_url'] ?? 'https://images.unsplash.com/photo-1546410531-bb4caa6b424d?w=800&q=80',
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(color: Colors.white.withOpacity(0.05)),
                            ),
                          ),
                        ),
                      ),
                      // Gradient overlay for text readability
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter, end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                            ),
                          ),
                        ),
                      ),
                      if (!isEnrolled && course['demo_video_url'] != null && course['demo_video_url'].toString().trim().isNotEmpty)
                        Positioned.fill(
                          child: Center(
                            child: InkWell(
                              onTap: () {
                                Navigator.pushNamed(context, '/material', arguments: {
                                  'material': {
                                    'id': -999,
                                    'title': lang.translate('course_preview') ?? 'Course Preview',
                                    'type': 'video',
                                    'is_free': true,
                                    'content_url': course['demo_video_url'],
                                    'video_url': course['demo_video_url'],
                                  },
                                  'courseId': widget.courseId,
                                  'forceLandscape': true,
                                });
                              },
                              borderRadius: BorderRadius.circular(100),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.9),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.5),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    )
                                  ],
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                        ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const SizedBox(),
                              Container(
                                decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle, border: Border.all(color: Colors.white12)),
                                child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
  
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 10),
  
                      // ENROLLMENT STATUS BADGE
                      if (isEnrolled)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.verified_rounded, color: Colors.green, size: 12),
                            const SizedBox(width: 6),
                            Text(lang.translate('joined') ?? 'ENROLLED', style: const TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                          ]),
                        ),
  
                      // CATEGORY BADGE + PRICE
                      Row(children: [
                        if (catStr.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: primaryColor.withOpacity(0.2))),
                            child: Text(catStr.toUpperCase(), style: TextStyle(color: primaryColor, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (!isEnrolled && (wp.activeWorkspace?.enablePurchasing ?? true)) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.amber.withOpacity(0.25))),
                            child: Text('${course['price'] ?? '0'} ${lang.translate('currency_le') ?? 'LE'}', style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 10),
  
                      // TITLE
                      Text(course['title'] ?? '', style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.3, height: 1.2)),
                      const SizedBox(height: 12),
  
                      // STATS ROW — real data
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(color: overlayLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: overlayMid)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStat(Icons.play_lesson_rounded, '${materials.length}', lang.translate('materials') ?? 'Lessons', primaryColor, textPrimary),
                            Container(width: 1, height: 16, color: overlayMid),
                            _buildStat(Icons.people_rounded,
                              (() { final m = course['members_count'] ?? course['students_count'] ?? course['members'] ?? 0; return m.toString(); })(),
                              lang.translate('members') ?? 'Students', primaryColor, textPrimary),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
  
                      // INLINE APPLY COUPON SECTION
                      if (!isEnrolled && !wp.isGuest) ...[
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: primaryColor.withOpacity(0.12),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.translate('apply_coupon') ?? 'Have a coupon?',
                                style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: -0.2),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 48,
                                      child: TextField(
                                        controller: _couponController,
                                        style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                        decoration: InputDecoration(
                                          hintText: lang.translate('coupon_hint') ?? 'Enter coupon code',
                                          hintStyle: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w500),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          filled: true,
                                          fillColor: isDark ? Colors.black26 : Colors.white60,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide(color: primaryColor.withOpacity(0.15), width: 1),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide(color: primaryColor.withOpacity(0.08), width: 1),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide(color: primaryColor, width: 1.5),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    height: 48,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        padding: const EdgeInsets.symmetric(horizontal: 24),
                                      ),
                                      onPressed: () async {
                                        if (_couponController.text.isEmpty) return;
                                        final code = _couponController.text.trim();
                                        final sm = ScaffoldMessenger.of(context);
                                        setState(() => _isSubscribing = true);
                                        try {
                                          final res = await wp.redeemCoupon(code, courseId: widget.courseId);
                                          sm.showSnackBar(SnackBar(content: Text(res['message'] ?? 'Success!'), backgroundColor: Colors.green));
                                          await wp.eagerLoad();
                                          if (mounted) await _fetch();
                                        } catch (e) {
                                          sm.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                                        } finally {
                                          if (mounted) setState(() => _isSubscribing = false);
                                        }
                                      },
                                      child: Text(
                                        lang.translate('apply') ?? 'Apply',
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
  
                      // CONTINUE / START BUTTON
                      if (isEnrolled) ...[
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.12), blurRadius: 20, spreadRadius: -5)],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              if (!_checkLogin(context)) return;
                              if (!isEnrolled && freeMaterialsCount == 0 && course['demo_video_url'] != null && course['demo_video_url'].toString().trim().isNotEmpty) {
                                Navigator.pushNamed(context, '/material', arguments: {
                                  'material': {
                                    'id': -999,
                                    'title': lang.translate('course_preview') ?? 'Course Preview',
                                    'type': 'video',
                                    'is_free': true,
                                    'content_url': course['demo_video_url'],
                                    'video_url': course['demo_video_url'],
                                  },
                                  'courseId': widget.courseId,
                                  'forceLandscape': true,
                                });
                                return;
                              }
                              final type = targetMaterial['type']?.toString().toLowerCase() ?? 'lesson';
                              Navigator.pushNamed(context, '/material', arguments: {
                                'material': targetMaterial,
                                'courseId': widget.courseId,
                                'forceLandscape': type == 'video' || type == 'mp4',
                                'nextMaterial': nextMat,
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                              foregroundColor: isDark ? Colors.black : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(lastAccessed == null ? Icons.bolt_rounded : Icons.play_circle_filled_rounded, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isEnrolled
                                            ? (lastAccessed == null ? lang.translate('open_course')?.toUpperCase() ?? "START LEARNING" : "RESUME CURRICULUM")
                                            : "START FREE PREVIEW",
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 1.5),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        (!isEnrolled && freeMaterialsCount == 0)
                                            ? (lang.translate('course_preview') ?? 'Course Preview')
                                            : (targetMaterial['title'] ?? 'First lesson'), 
                                        maxLines: 1, 
                                        overflow: TextOverflow.ellipsis, 
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (isEnrolled && _isWhiteboardActive) ...[
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.12), blurRadius: 20, spreadRadius: -5)],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/whiteboard', arguments: widget.courseId);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B5CF6),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.border_color_rounded, size: 22),
                                  const SizedBox(width: 10),
                                  Text(
                                    lang.translate('whiteboard') ?? (lang.currentLocale.languageCode == 'ar' ? 'السبورة التفاعلية' : 'Interactive Whiteboard'),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],

                    // PROGRESS (enrolled only)
                    if (isEnrolled) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(lang.translate('progress')?.toUpperCase() ?? "COURSE PROGRESS", style: TextStyle(color: textMuted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                              Text("${wp.lastAccessedMaterials[widget.courseId] != null ? '40' : '0'}%", style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.w900)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 5,
                            decoration: BoxDecoration(color: onSurface.withOpacity(0.1), borderRadius: BorderRadius.circular(3)),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: wp.lastAccessedMaterials[widget.courseId] != null ? 0.4 : 0.02,
                              child: Container(decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(3))),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // DESCRIPTION — only shown when no learning_outcomes (avoid duplication)
                    if ((course['description'] ?? '').toString().trim().isNotEmpty &&
                        (course['learning_outcomes'] ?? '').toString().trim().isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: overlayLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: overlayMid),
                        ),
                        child: Text(_stripHtml(course['description'] ?? ''),
                          style: TextStyle(color: textSecondary, fontSize: 14, height: 1.7, fontWeight: FontWeight.w400),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // WHAT YOU'LL LEARN (learning_outcomes)
                    if ((course['learning_outcomes'] ?? '').toString().trim().isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: primaryColor.withOpacity(0.15)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.lightbulb_outline_rounded, color: primaryColor, size: 16),
                              const SizedBox(width: 8),
                              Text(lang.translate('what_youll_learn') ?? "WHAT YOU'LL LEARN", style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                            ]),
                            const SizedBox(height: 12),
                            Text(_stripHtml(course['learning_outcomes'] ?? ''),
                              style: TextStyle(color: textSecondary, fontSize: 13, height: 1.6),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],


                    // INSTRUCTOR CARD
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: overlayLight, borderRadius: BorderRadius.circular(14), border: Border.all(color: overlayMid)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: primaryColor.withOpacity(0.15),
                          backgroundImage: course['instructor_avatar'] != null ? NetworkImage(course['instructor_avatar'].toString()) : null,
                          child: course['instructor_avatar'] == null ? Icon(Icons.person_rounded, color: primaryColor, size: 22) : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(course['instructor_name'] ?? course['teacher_name'] ?? 'Academy Expert', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                            if (course['instructor_bio'] != null && course['instructor_bio'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(_stripHtml(course['instructor_bio'].toString()), style: TextStyle(color: textMuted, fontSize: 11, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                              )
                            else
                              Text(lang.translate('instructor') ?? 'Instructor', style: TextStyle(color: textMuted, fontSize: 11)),
                          ],
                        )),
                        Icon(Icons.verified_rounded, color: primaryColor.withOpacity(0.6), size: 16),
                      ]),
                    ),
                    const SizedBox(height: 28),

                    // FAVORITES TOGGLE — optimistic UI
                    InkWell(
                      onTap: () async {
                        if (!_checkLogin(context)) return;
                        final newFav = !isFavorited;
                        
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Row(children: [
                            Icon(newFav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 10),
                            Text(newFav ? (lang.translate('added_to_favorites') ?? 'Added to favorites') : (lang.translate('removed_from_favorites') ?? 'Removed from favorites')),
                          ]),
                          backgroundColor: newFav ? Colors.green.shade700 : Colors.grey.shade700,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        ));

                        try {
                          await wp.toggleFavoriteOptimistic(widget.courseId);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(e.toString().replaceAll('Exception: ', '')),
                              backgroundColor: Colors.red.shade700,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                            ));
                          }
                          debugPrint('Fav Toggle Error: $e');
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: _buildQuickAction(
                          isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          isFavorited ? (lang.translate('remove_favorites') ?? 'REMOVE FROM FAVORITES').toUpperCase() : (lang.translate('save_favorites') ?? 'SAVE IN FAVORITES').toUpperCase(),
                          isFavorited ? primaryColor : onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // CURRICULUM HEADER
                    Text(lang.translate('curriculum')?.toUpperCase() ?? "ACADEMY CURRICULUM", style: TextStyle(color: textPrimary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    const SizedBox(height: 16),

                    // FILTER PILLS — use fixed type-key + display label pairs
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: overlayLight, borderRadius: BorderRadius.circular(16), border: Border.all(color: overlayMid)),
                        child: Row(
                          children: [
                            _buildFilterItem(null, lang.translate('all')?.toUpperCase() ?? 'ALL', primaryColor, onSurface, isDark),
                            if (hasVideos) ...[
                              const SizedBox(width: 4),
                              _buildFilterItem('video', lang.translate('videos')?.toUpperCase() ?? 'VIDEOS', primaryColor, onSurface, isDark),
                            ],
                            if (hasFiles) ...[
                              const SizedBox(width: 4),
                              _buildFilterItem('file', lang.translate('files')?.toUpperCase() ?? 'FILES', primaryColor, onSurface, isDark),
                            ],
                            if (hasQuizzes) ...[
                              const SizedBox(width: 4),
                              _buildFilterItem('quiz', lang.translate('quizzes')?.toUpperCase() ?? 'QUIZZES', primaryColor, onSurface, isDark),
                            ],
                            if (hasAssignments) ...[
                              const SizedBox(width: 4),
                              _buildFilterItem('assignment', lang.translate('assignments')?.toUpperCase() ?? 'ASSIGNMENTS', primaryColor, onSurface, isDark),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ]),
                ),
              ),

              // MATERIALS LIST
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildMaterialItem(
                      filteredMaterials[index], index, filteredMaterials, isEnrolled, lang, primaryColor, onSurface,
                    ),
                    childCount: filteredMaterials.length,
                  ),
                ),
              ),

              // ENROLLED: UNENROLL BUTTON
              if (isEnrolled)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 40, 24, 100),
                    child: InkWell(
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                            title: Text(lang.translate('unenroll') ?? "UNENROLL FROM COURSE", style: TextStyle(color: onSurface, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                            content: Text(lang.translate('unenroll_hint') ?? "Your learning progress will be saved, but you will lose instant access until you re-subscribe.", style: TextStyle(color: textSecondary, fontSize: 12, height: 1.5)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(lang.translate('cancel')?.toUpperCase() ?? "CANCEL", style: TextStyle(color: onSurface.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.w900))),
                              TextButton(onPressed: () => Navigator.pop(c, true), child: Text(lang.translate('unenroll')?.toUpperCase() ?? "UNENROLL", style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w900))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          try {
                            await wp.unenroll(widget.courseId);
                            await wp.eagerLoad();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.translate('unenrolled_success') ?? "Unenrolled successfully"), backgroundColor: Colors.orange));
                              Navigator.pushReplacementNamed(context, '/dashboard');
                            }
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                          }
                        }
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.redAccent.withOpacity(0.1))),
                        child: Row(
                          children: [
                            const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                            const SizedBox(width: 16),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(lang.translate('stop_learning')?.toUpperCase() ?? 'STOP LEARNING', style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w900)),
                              Text(lang.translate('unenroll_from_course') ?? 'Unenroll from this course', style: TextStyle(color: Colors.redAccent.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w600)),
                            ]),
                            const Spacer(),
                            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.redAccent, size: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                const SliverToBoxAdapter(child: SizedBox(height: 180)),
            ],
          ),
          ),
          // SUBSCRIBE LOADING OVERLAY
          if (_isSubscribing)
            Container(
              color: Colors.black54,
              child: const Center(child: PremiumLoader(size: 80)),
            ),
        ],
      ),
    );
  }

  // ─── SUBSCRIBE BOTTOM BAR ─────────────────────────────────────────────────
  Widget _buildSubscribeBar(Map<String, dynamic> course, LanguageProvider lang, Color primaryColor, BuildContext context) {
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final bool enablePurchasing = wp.activeWorkspace?.enablePurchasing ?? true;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final bottomBarColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);
    final textMutedColor = isDark ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.45);
    final chipBgColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);
    final chipIconColor = isDark ? Colors.white54 : Colors.black54;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: bottomBarColor,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
        boxShadow: [
          BoxShadow(
            color: isDark ? primaryColor.withOpacity(0.15) : Colors.black.withOpacity(0.05),
            blurRadius: 40,
            offset: const Offset(0, -10),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (wp.isGuest) ...[
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (route) => false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.login_rounded, size: 20),
                    const SizedBox(width: 10),
                    Text(lang.translate('login') ?? 'Login to Subscribe',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
          ] else ...[
            if (wp.activeWorkspace?.enablePurchasing ?? true) ...[
              // PRICE ROW
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((lang.translate('course_price') ?? 'COURSE PRICE').toUpperCase(),
                        style: TextStyle(color: textMutedColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    Text(
                      (double.tryParse(course['price']?.toString() ?? '0') ?? 0.0) == 0.0
                          ? (lang.translate('free') ?? (lang.currentLocale.languageCode == 'ar' ? 'مجاني' : 'Free'))
                          : "${course['price'] ?? '0.00'} ${lang.translate('currency_le') ?? 'LE'}",
                      style: TextStyle(color: primaryColor, fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                  ]),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: chipBgColor, borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      Icon(Icons.lock_clock_rounded, color: chipIconColor, size: 14),
                      const SizedBox(width: 6),
                      Text((lang.translate('subscribe_to_unlock') ?? 'Subscribe to unlock').toUpperCase(),
                          style: TextStyle(color: textMutedColor, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            // PURCHASE/ENROLL BUTTON
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _handleWalletCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(enablePurchasing ? Icons.wallet_rounded : Icons.check_circle_outline_rounded, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      enablePurchasing
                          ? (lang.translate('redeem_wallet') ?? 'Subscribe using Wallet')
                          : (lang.translate('subscribe_now') ?? 'Enroll Now'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── MODERN COUPON BOTTOM SHEET ───────────────────────────────────────────
  void _showModernCouponSheet(BuildContext context, LanguageProvider lang, Color primaryColor, WorkspaceProvider wp) {
    final sheetController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 40),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: primaryColor.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.confirmation_num_rounded, color: primaryColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.translate('apply_coupon') ?? 'Apply Coupon',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        lang.translate('coupon_hint') ?? 'Enter your coupon code to enroll',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: sheetController,
              autofocus: true,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
              decoration: InputDecoration(
                hintText: 'XXXX-XXXX-XXXX',
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
                filled: true,
                fillColor: primaryColor.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                prefixIcon: Icon(Icons.vpn_key_rounded, color: primaryColor.withOpacity(0.5)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  if (sheetController.text.isEmpty) return;
                  final code = sheetController.text.trim();
                  final nav = Navigator.of(ctx);
                  final sm = ScaffoldMessenger.of(context);
                  nav.pop();
                  setState(() => _isSubscribing = true);
                  try {
                    final res = await wp.redeemCoupon(code, courseId: widget.courseId);
                    sm.showSnackBar(SnackBar(content: Text(res['message'] ?? 'Success!'), backgroundColor: Colors.green));
                    await wp.eagerLoad();
                    if (mounted) await _fetch();
                  } catch (e) {
                    sm.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                  } finally {
                    if (mounted) setState(() => _isSubscribing = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  (lang.translate('apply') ?? 'APPLY COUPON').toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildFilterItem(String? key, String label, Color primaryColor, Color onSurface, bool isDark) {
    final isSelected = _activeFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected ? [BoxShadow(color: primaryColor.withOpacity(0.2), blurRadius: 8)] : [],
        ),
        child: Text(
          label, textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : onSurface.withOpacity(0.4),
            fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildMetaTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white10)),
      child: Text(text, style: const TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, [Color? iconColor]) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Icon(icon, color: iconColor ?? onSurface, size: 20),
        const SizedBox(width: 14),
        Text(label, style: TextStyle(color: onSurface.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildStat(IconData icon, String value, String label, Color accent, Color textPrimary) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: accent, size: 14),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w900)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: textPrimary.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // Strip HTML tags and decode common entities for clean plain text
  String _stripHtml(String html) {
    if (html.isEmpty) return '';
    String result = html
        .replaceAll(RegExp(r'<br\s*/?>|</p>|</div>|</li>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return result;
  }

  bool _checkLogin(BuildContext context) {
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    if (wp.isGuest) {
      _showLoginRequiredDialog(context);
      return false;
    }
    return true;
  }

  void _showEnrollPrompt(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final primary = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRTL = lang.currentLocale.languageCode == 'ar';
    showDialog(
      context: context,
      builder: (c) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF1E293B) : Colors.white).withOpacity(0.95),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 40)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.school_rounded, color: primary, size: 36),
                ),
                const SizedBox(height: 24),
                Text(
                  isRTL ? 'يجب التسجيل أولاً' : 'Enrollment Required',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 18, fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isRTL
                      ? 'يرجى التسجيل في هذا الكورس أولاً للوصول إلى المحتوى.'
                      : 'Please enroll in this course first to access this content.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.55),
                    height: 1.5, fontWeight: FontWeight.w600, fontSize: 13,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: Text(
                          lang.translate('cancel') ?? (isRTL ? 'إلغاء' : 'CANCEL'),
                          style: TextStyle(
                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.3),
                            fontWeight: FontWeight.w900, fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(c);
                          // Scroll to the subscribe bar (bottom) — just trigger checkout
                          _handleWalletCheckout();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          lang.translate('enroll') ?? (isRTL ? 'سجّل الآن' : 'ENROLL'),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLoginRequiredDialog(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final primary = Theme.of(context).primaryColor;
    showDialog(
      context: context,
      builder: (c) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.9),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.lock_outline_rounded, color: primary, size: 32),
                ),
                const SizedBox(height: 24),
                Text(
                  (lang.translate('login_required') ?? 'Login Required').toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
                const SizedBox(height: 12),
                Text(
                  lang.translate('login_to_view_content') ?? 'Please login to view this content.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), height: 1.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: Text(
                          lang.translate('cancel') ?? 'CANCEL',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3), fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(c);
                          Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (route) => false);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          lang.translate('login') ?? 'LOGIN',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

