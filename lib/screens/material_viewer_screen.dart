import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:elmasa/services/security_service.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'package:google_fonts/google_fonts.dart' as modern_fonts;
import 'package:elmasa/providers/workspace_provider.dart';
import 'package:elmasa/providers/language_provider.dart';
import 'package:elmasa/providers/theme_provider.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:elmasa/screens/simple_scanner_screen.dart';
import 'package:elmasa/widgets/premium_loader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:elmasa/config/app_config.dart';
import 'package:elmasa/widgets/watermark_overlay.dart';

void _showImageModal(BuildContext context, String imageUrl) {
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => GestureDetector(
      onTap: () => Navigator.pop(ctx),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 5.0,
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (c, child, progress) => progress == null
                      ? child
                      : const Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2)),
                  errorBuilder: (c, e, s) => const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(ctx).padding.top + 12,
              right: 16,
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


class MaterialViewerScreen extends StatefulWidget {
  final Map<String, dynamic> material;
  final int? courseId;
  final bool forceLandscape;
  final Map<String, dynamic>? nextMaterial;
  const MaterialViewerScreen({super.key, required this.material, this.courseId, this.forceLandscape = false, this.nextMaterial});

  @override
  State<MaterialViewerScreen> createState() => _MaterialViewerScreenState();
}

class _MaterialViewerScreenState extends State<MaterialViewerScreen> {
  bool _isLoading = true;
  String? _localPdfPath;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLandscapeMode = false;
  bool _showNextHint = false;
  int _remainingSeconds = 0;
  Timer? _hideHintTimer; // 5-second auto-hide timer for next video card
  String? _errorMessage;
  bool _notEnrolled = false;
  bool _isSubscribing = false;
  Map<String, dynamic>? _courseData;
  
  // QUIZ STATE
  final Map<int, int?> _quizAnswers = {};
  bool _isQuizSubmitted = false;
  bool _isSubmittingQuiz = false;
  dynamic _quizResult;

  // ASSIGNMENT STATE
  bool _isSubmittingAssignment = false;
  final TextEditingController _assignmentTextController = TextEditingController();
  final TextEditingController _assignmentFileController = TextEditingController();
  dynamic _assignmentResult;
  bool _isAssignmentSubmitted = false;
  String? _pickedAssignmentFilePath;
  String? _pickedAssignmentFileName;

  @override
  void initState() {
    super.initState();
    if (!kDebugMode && !SecurityService.bypassSecurityChecks) {
      NoScreenshot.instance.screenshotOff();
    }

    // Hook screenshot & recording detection → report to security API
    NoScreenshot.instance.onScreenshotDetected = (_) => _reportSecurityEvent('screenshot_taken');
    NoScreenshot.instance.onScreenRecordingStarted = (_) => _reportSecurityEvent('screen_recording_started');
    NoScreenshot.instance.onScreenRecordingStopped = (_) => _reportSecurityEvent('screen_recording_stopped');
    if (!kDebugMode && !SecurityService.bypassSecurityChecks) {
      NoScreenshot.instance.startCallbacks();
    }
    
    _isLandscapeMode = widget.forceLandscape;
    if (_isLandscapeMode) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  void _reportSecurityEvent(String incidentType) {
    try {
      final wp = Provider.of<WorkspaceProvider>(context, listen: false);
      wp.reportSecurityAlert(incidentType, description: 'Detected on material: ${widget.material['title'] ?? ''}');
      debugPrint('🔒 Security event: $incidentType');
    } catch (e) {
      debugPrint('⚠️ Could not report security event: $e');
    }
  }

  void _videoListener() {
    if (_videoPlayerController == null) return;
    final value = _videoPlayerController!.value;
    if (!value.isInitialized) return;

    final duration = value.duration;
    final position = value.position;

    // AUTO-PLAY NEXT ON COMPLETION
    if (position >= duration && duration > Duration.zero && widget.nextMaterial != null) {
      _videoPlayerController!.removeListener(_videoListener);
      _playNext();
      return;
    }

    final remaining = duration - position;

    if (widget.nextMaterial != null && remaining.inSeconds <= 60 && remaining.inSeconds > 0) {
      if (!_showNextHint) {
        setState(() => _showNextHint = true);
        // Start 5-second auto-hide timer when hint first appears
        _hideHintTimer?.cancel();
        _hideHintTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() => _showNextHint = false);
        });
      }
      if (_remainingSeconds != remaining.inSeconds) {
        setState(() => _remainingSeconds = remaining.inSeconds);
      }
    } else if (_showNextHint) {
      setState(() => _showNextHint = false);
      _hideHintTimer?.cancel();
    }
  }

  Future<void> _fetch() async {
    try {
      final wp = Provider.of<WorkspaceProvider>(context, listen: false);
      Map<String, dynamic> material = widget.material;
      final type = material['type']?.toString().toLowerCase();

      final isFree = material['is_free'] == 1 || material['is_free'] == true || material['is_free'] == '1';
      if (widget.courseId != null && !isFree) {
         try {
           final cRes = await wp.getCourse(widget.courseId!);
           if (mounted) {
             setState(() {
               _courseData = cRes;
             });
           }
           final dynamic courseObj = cRes['data']?['course'] ?? cRes['course'];
           if (courseObj is Map<String, dynamic>) {
              final dynamic enrolledRaw = courseObj['isEnrolled'] ?? courseObj['is_enrolled'] ?? courseObj['is_accessible'];
              final bool isEnrolled = enrolledRaw == true || enrolledRaw == 1 || enrolledRaw == '1' || enrolledRaw == 'true';
              if (!isEnrolled) {
                 throw Exception('Not enrolled');
              }
           }
         } catch (e) {
           if (e.toString().contains('Not enrolled') || e.toString().contains('Not Enrolled') || e.toString().contains('403')) {
              rethrow;
           }
           debugPrint('Error getting course status: $e');
         }
      }

      // COMPREHENSIVE URL EXTRACTION — use content_url directly from course API
      String directUrl = material['content_url']?.toString() ?? 
                         material['link_url']?.toString() ?? 
                         material['file_path']?.toString() ?? 
                         material['url']?.toString() ?? 
                         material['video_url']?.toString() ?? 
                         material['stream_url']?.toString() ?? '';

      // BUNNY FALLBACK
      if (directUrl.isEmpty && (material['bunny_video_id'] != null || material['bunny_id'] != null)) {
         final vid = material['bunny_video_id'] ?? material['bunny_id'];
         directUrl = "https://iframe.mediadelivery.net/hls/$vid/playlist.m3u8";
         debugPrint('🎬 Bunny Fallback URL: $directUrl');
      }

      // NOTE: /learn endpoint returns an HTML page (Next.js app), not JSON.
      // We intentionally skip it and rely on content_url from the course/materials API.
      if (directUrl.isEmpty) {
        debugPrint('⚠️ No content URL found for material: ${material['title']}');
      }


      // Detect image type by extension in URL regardless of declared type
      final isImageUrl = directUrl.isNotEmpty &&
          RegExp(r'\.(jpg|jpeg|png|gif|webp|svg|bmp)(\?.*)?$', caseSensitive: false).hasMatch(directUrl);

      // Treat as image if: type == 'image', OR type is unset and URL is an image,
      // OR type is pdf/document but the actual URL resolves to an image (mismatch case)
      final bool treatAsImage = type == 'image' ||
          ((type == null || type.isEmpty) && isImageUrl) ||
          ((type == 'pdf' || type == 'document' || type == 'pdf_file') && isImageUrl);

      if (treatAsImage) {
         debugPrint('🖼️ Image material (resolved): $directUrl');
         if (mounted) setState(() => _isLoading = false);
      } else if (type == 'pdf' || type == 'document' || type == 'pdf_file') {
         if (directUrl.isNotEmpty && !directUrl.contains('<iframe')) {
           await _downloadPdf(directUrl);
         }
         // Empty URL → fall through to loading=false → shows _buildDefaultLessonNotice (No Content)
         if (mounted) setState(() => _isLoading = false);
      } else if (type == 'quiz') {
         debugPrint('📝 Quiz Material Data: $material');
         // Quizzes: Always fetch quiz details to get current previousAttempt
         try {
           final rawId = material['quiz_id'] ?? material['id'] ?? '0';
           final mid = (int.tryParse(rawId.toString()) ?? 0).abs();
           
           if (mid != 0) {
             debugPrint('🔍 Fetching Quiz ID: $mid');
             final res = await wp.getQuiz(mid);
             if (mounted && res['success'] == true) {
               setState(() {
                 widget.material['quiz_data'] = res;
                 final List qList = res['questions'] ?? res['data']?['questions'] ?? [];
                 if (qList.isNotEmpty) {
                   widget.material['questions'] = qList;
                 }
               });
             }
           }
         } catch (e) {
           if (e.toString().contains('Not enrolled') || e.toString().contains('Not Enrolled') || e.toString().contains('403')) {
              rethrow;
           }
           debugPrint('! Quiz fetch failed: $e');
         }
         if (mounted) setState(() => _isLoading = false);
      } else if (type == 'assignment' || type == 'homework') {
         debugPrint('📝 Assignment Material Data: $material');
         // Try to fetch assignment details if missing
         final assignmentData = widget.material['assignment_data'];
         if (assignmentData == null) {
            try {
              final rawId = material['assignment_id'] ?? material['id'] ?? '0';
              final mid = (int.tryParse(rawId.toString()) ?? 0).abs();
              
              if (mid != 0) {
                debugPrint('🔍 Fetching Assignment ID: $mid');
                final res = await wp.getAssignment(mid);
                // Backend returns: { success: true, assignment: { ... }, previousSubmission: { ... } }
                if (mounted && res['success'] == true) {
                  setState(() {
                    widget.material['assignment_data'] = res;
                  });
                }
              }
            } catch (e) {
              if (e.toString().contains('Not enrolled') || e.toString().contains('Not Enrolled') || e.toString().contains('403')) {
                 rethrow;
              }
              debugPrint('! Assignment fetch failed: $e');
            }
         }
         if (mounted) setState(() => _isLoading = false);
      } else if (type == 'video' || type == 'mp4' || type == 'stream') {
         debugPrint('🚀 Initializing Video: $directUrl');
         if (directUrl.isNotEmpty) {
           await _initVideo(directUrl, wp.activeWorkspace?.host);
         } else {
           if (mounted) setState(() => _isLoading = false);
         }
      } else if (directUrl.isNotEmpty) {
         // Any URL that we don't recognize — try as video
         debugPrint('🚀 Unknown type, trying as video: $directUrl');
         await _initVideo(directUrl, wp.activeWorkspace?.host);
      } else {
         debugPrint('📄 Skipping media init for text/html lesson.');
         if (mounted) setState(() => _isLoading = false);
      }

      // MARK PROGRESS (non-blocking — don't let it fail the whole fetch)
      try {
        final courseIdVal = widget.courseId ?? int.tryParse(material['course_id']?.toString() ?? '0') ?? 0;
        if (courseIdVal != 0) await wp.markProgress(courseIdVal, material);
      } catch (e) {
        debugPrint('Progress mark failed (non-fatal): $e');
      }

    } catch (e) {
      debugPrint('Content Load Error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (e.toString().contains('Not enrolled') || e.toString().contains('Not Enrolled') || e.toString().contains('403')) {
            _notEnrolled = true;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading content: $e")));
          }
        });
      }
    }
  }

  Future<void> _handleBuyWallet() async {
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final isRTL = lang.currentLocale.languageCode == 'ar';
    if (wp.isGuest) {
      Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (r) => false);
      return;
    }
    if (widget.courseId == null) return;
    if (_isSubscribing) return;
    setState(() => _isSubscribing = true);
    try {
      final res = await wp.checkoutWallet(widget.courseId!);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? (isRTL ? 'تم الاشتراك بنجاح!' : 'Enrolled successfully!')),
        backgroundColor: Colors.green,
      ));
      await wp.eagerLoad();
      setState(() {
        _notEnrolled = false;
        _isLoading = true;
      });
      await _fetch();
    } catch (e) {
      final errorStr = e.toString();
      final isInsufficientBalance = errorStr.toLowerCase().contains('balance') || 
                                    errorStr.toLowerCase().contains('insufficient') ||
                                    errorStr.contains('رصيد') ||
                                    errorStr.contains('كاف');
      if (isInsufficientBalance) {
        if (mounted) {
          Navigator.pushNamed(
            context,
            '/wallet',
            arguments: {'prompt': 'insuff_balance'},
          );
        }
        return;
      }
      final msg = errorStr.contains('already subscribed') || errorStr.contains('مشترك')
          ? (isRTL ? 'أنت مشترك بالفعل!' : 'You are already enrolled!')
          : errorStr;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: errorStr.contains('already') ? Colors.orange : Colors.red,
      ));
      if (errorStr.contains('already subscribed') || errorStr.contains('مشترك')) {
        await wp.eagerLoad();
        setState(() {
          _notEnrolled = false;
          _isLoading = true;
        });
        await _fetch();
      }
    } finally {
      if (mounted) setState(() => _isSubscribing = false);
    }
  }

  void _showCouponSheet(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final primaryColor = Theme.of(context).primaryColor;
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isRTL = lang.currentLocale.languageCode == 'ar';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(sheetCtx).viewInsets.bottom + 40),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: primaryColor.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.translate('redeem_coupon') ?? (isRTL ? 'تفعيل كود الاشتراك' : 'Activate Coupon'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: onSurface)
            ),
            const SizedBox(height: 8),
            Text(
              lang.translate('coupon_hint') ?? (isRTL ? 'أدخل كود الكوبون الخاص بك أدناه' : 'Enter your coupon code below'),
              style: TextStyle(color: onSurface.withOpacity(0.5), fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(color: onSurface),
              decoration: InputDecoration(
                hintText: 'XXXX-XXXX-XXXX',
                hintStyle: TextStyle(color: onSurface.withOpacity(0.3)),
                filled: true,
                fillColor: onSurface.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (controller.text.isEmpty) return;
                  final nav = Navigator.of(sheetCtx);
                  nav.pop();
                  setState(() => _isSubscribing = true);
                  try {
                    final res = await wp.redeemCoupon(controller.text, courseId: widget.courseId);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(res['message'] ?? (isRTL ? 'نجح الاشتراك!' : 'Success!')),
                      backgroundColor: Colors.green,
                    ));
                    await wp.eagerLoad();
                    setState(() {
                      _notEnrolled = false;
                      _isLoading = true;
                    });
                    await _fetch();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: Colors.red,
                    ));
                  } finally {
                    if (mounted) setState(() => _isSubscribing = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  (lang.translate('apply') ?? (isRTL ? 'تطبيق الكود' : 'Apply')).toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNotEnrolledView(LanguageProvider lang, Color primaryColor, Color onSurface) {
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final showPurchasing = wp.activeWorkspace?.enablePurchasing ?? true;
    final isRTL = lang.currentLocale.languageCode == 'ar';

    final dynamic courseObj = _courseData?['data']?['course'] ?? _courseData?['course'];
    final Map<String, dynamic>? course = courseObj is Map<String, dynamic> ? courseObj : null;
    final String price = course != null ? (course['price'] ?? '0.00').toString() : '0.00';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          // Locked Icon with elegant layout
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: Colors.redAccent,
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          // Error/Not enrolled Title
          Text(
            isRTL ? 'محتوى مغلق' : 'Content Locked',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          // Description
          Text(
            isRTL
                ? 'أنت غير مشترك في هذا الكورس. يرجى الاشتراك لتتمكن من الوصول للمحتوى.'
                : 'You are not enrolled in this course. Please enroll to access this content.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: onSurface.withOpacity(0.6),
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),

          // Price box (if enable_purchasing is true)
          if (showPurchasing) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryColor.withOpacity(0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isRTL ? 'سعر الكورس:' : 'Course Price:',
                    style: TextStyle(
                      color: onSurface.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$price ${isRTL ? 'جنيه' : 'LE'}',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Buy button (if enable_purchasing is true)
          if (showPurchasing) ...[
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _handleBuyWallet,
                icon: const Icon(Icons.wallet_rounded, size: 20),
                label: Text(
                  isRTL ? 'شراء الكورس باستخدام المحفظة' : 'Buy Course using Wallet',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Enroll with Coupon button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _showCouponSheet(context),
              icon: Icon(Icons.confirmation_num_rounded, color: primaryColor, size: 18),
              label: Text(
                isRTL ? 'تفعيل كود الاشتراك' : 'Enroll with Coupon Code',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: onSurface,
                side: BorderSide(color: onSurface.withOpacity(0.15)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _downloadPdf(String url) async {
    int retryCount = 0;
    while (retryCount < 3) {
      try {
        final client = http.Client();
        final response = await client.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          final dir = await getApplicationDocumentsDirectory();
          _localPdfPath = '${dir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.pdf';
          final file = File(_localPdfPath!);
          await file.writeAsBytes(response.bodyBytes);
          if (mounted) setState(() {});
          client.close();
          break;
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      } catch (e) {
        retryCount++;
        debugPrint('PDF Download Retry $retryCount: $e');
        if (retryCount >= 3) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("PDF Download Failed: Connection issue. Check your internet.")));
        }
        await Future.delayed(Duration(seconds: retryCount));
      }
    }
  }

  Future<void> _initVideo(String url, String? host) async {
    if (url.isEmpty) {
      debugPrint('⚠️ Empty video URL — cannot play');
      if (mounted) setState(() {
        _isLoading = false;
        _errorMessage = 'Video URL is missing or invalid. Please contact support.';
      });
      return;
    }

    // Capture theme colors synchronously BEFORE any async work
    final primaryColor = Theme.of(context).primaryColor;

    String streamUrl = url;
    if (url.contains('<iframe')) {
      streamUrl = RegExp(r'src="([^"]+)"').firstMatch(url)?.group(1) ?? url;
    }

    // AUTO-CONVERT GOOGLE DRIVE PREVIEW LINKS TO DIRECT STREAM LINKS
    if (streamUrl.contains('drive.google.com')) {
      String? driveId;
      if (streamUrl.contains('/file/d/')) {
        final parts = streamUrl.split('/file/d/');
        if (parts.length > 1) {
          driveId = parts[1].split('/')[0].split('?')[0];
        }
      } else if (streamUrl.contains('id=')) {
        try {
          final uri = Uri.parse(streamUrl);
          driveId = uri.queryParameters['id'];
        } catch (_) {}
      }
      
      if (driveId != null && driveId.isNotEmpty) {
        streamUrl = 'https://docs.google.com/uc?export=download&id=$driveId';
        debugPrint('✅ Transformed Google Drive URL to direct stream: $streamUrl');

        // Dynamically resolve virus warning bypass for large files
        try {
          final response = await http.get(Uri.parse(streamUrl)).timeout(const Duration(seconds: 7));
          if (response.statusCode == 200 && response.body.contains('confirm=')) {
            final match = RegExp(r'confirm=([^&"]+)').firstMatch(response.body);
            if (match != null) {
              final confirmToken = match.group(1);
              streamUrl = 'https://docs.google.com/uc?export=download&confirm=$confirmToken&id=$driveId';
              debugPrint('✅ Resolved Google Drive warning bypass confirm token: $confirmToken');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Google Drive warning bypass check failed: $e');
        }
      }
    }

    // ALWAYS convert host to video.mediadelivery.net for raw video playback
    if (streamUrl.contains('iframe.mediadelivery.net') || streamUrl.contains('player.mediadelivery.net')) {
      streamUrl = streamUrl
          .replaceAll('iframe.mediadelivery.net', 'video.mediadelivery.net')
          .replaceAll('player.mediadelivery.net', 'video.mediadelivery.net');
    }

    // AUTO-CONVERT BUNNY PLAYER URLS TO HLS STREAMS
    if (streamUrl.contains('video.mediadelivery.net') && !streamUrl.contains('.m3u8')) {
      try {
        final uri = Uri.parse(streamUrl);
        final segments = uri.pathSegments;
        if (segments.length >= 2) {
          final videoId = segments.last;
          final libraryId = segments.length >= 3 ? segments[segments.length - 2] : null;
          
          String newPath;
          if (libraryId != null && libraryId != 'embed' && libraryId != 'play') {
            newPath = "/play/$libraryId/$videoId/playlist.m3u8";
          } else {
            newPath = "/hls/$videoId/playlist.m3u8";
          }
          
          final newUri = uri.replace(path: newPath);
          streamUrl = newUri.toString();
          debugPrint('✅ Transformed Bunny Player URL to HLS: $streamUrl');
        }
      } catch (e) {
        debugPrint('⚠️ Bunny URL Transformation Error: $e');
      }
    }

    final Map<String, String> httpHeaders = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    };
    if (streamUrl.contains('mediadelivery.net') || streamUrl.contains('bunny')) {
      httpHeaders['Referer'] = host != null ? 'https://$host/' : '$kSiteUrl/';
      httpHeaders['Origin'] = host != null ? 'https://$host' : kSiteUrl;
    }

    debugPrint('🎬 Initializing Source: $streamUrl');

    // Dispose any previous controller cleanly
    final oldChewie = _chewieController;
    final oldVideo = _videoPlayerController;
    
    _videoPlayerController = null;
    _chewieController = null;
    
    oldVideo?.removeListener(_videoListener);
    
    Future.microtask(() {
      oldChewie?.dispose();
      oldVideo?.dispose();
    });

    try {
      VideoFormat? format;
      final lowercaseUrl = streamUrl.toLowerCase();
      if (lowercaseUrl.contains('.m3u8') || lowercaseUrl.contains('m3u8')) {
        format = VideoFormat.hls;
      } else if (lowercaseUrl.contains('.mpd') || lowercaseUrl.contains('mpd')) {
        format = VideoFormat.dash;
      } else if (lowercaseUrl.contains('.ism') || lowercaseUrl.contains('ism')) {
        format = VideoFormat.ss;
      }

      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(streamUrl),
        formatHint: format,
        httpHeaders: httpHeaders,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );
    } catch (e) {
      debugPrint('❌ Video Controller creation failed: $e');
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // ✅ INITIALIZE FIRST — then create ChewieController
    try {
      await _videoPlayerController!.initialize();
      debugPrint('''
================ VIDEO DEBUG ================
initialized: ${_videoPlayerController!.value.isInitialized}
hasError: ${_videoPlayerController!.value.hasError}
errorDescription: ${_videoPlayerController!.value.errorDescription}
duration: ${_videoPlayerController!.value.duration}
size: ${_videoPlayerController!.value.size}
aspectRatio: ${_videoPlayerController!.value.aspectRatio}
position: ${_videoPlayerController!.value.position}
isPlaying: ${_videoPlayerController!.value.isPlaying}
==============================================
''');
    } catch (e) {
      debugPrint('❌ Video Initialize Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video playback error: $e'), backgroundColor: Colors.red),
        );
        final wp = Provider.of<WorkspaceProvider>(context, listen: false);
        wp.getMe(force: true).catchError((_) => <String, dynamic>{});
      }
      return;
    }

    if (!mounted) return;

    _videoPlayerController!.addListener(_videoListener);

    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController!,
      autoPlay: true,
      looping: false,
      showControls: true,
      allowFullScreen: true,
      allowPlaybackSpeedChanging: true,
      playbackSpeeds: [0.5, 1.0, 1.5, 2.0],
      aspectRatio: _videoPlayerController!.value.aspectRatio > 0
          ? _videoPlayerController!.value.aspectRatio
          : 16 / 9,
      autoInitialize: false, // Already initialized above
      allowedScreenSleep: false,
      isLive: false,
      errorBuilder: (context, errorMessage) {
        final wp = Provider.of<WorkspaceProvider>(context, listen: false);
        wp.getMe(force: true).catchError((_) => <String, dynamic>{});
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 42),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Playback Error: $errorMessage',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => setState(() { _isLoading = true; _initVideo(url, host); }),
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('RETRY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        );
      },
      cupertinoProgressColors: ChewieProgressColors(
        playedColor: primaryColor, bufferedColor: Colors.white24, handleColor: primaryColor),
      materialProgressColors: ChewieProgressColors(
        playedColor: primaryColor, bufferedColor: Colors.white24, handleColor: primaryColor),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      _videoPlayerController!.play();
    }
  }

  Future<void> _submitQuiz() async {
    final material = widget.material;
    final quizId = (int.tryParse(material['id']?.toString() ?? '0') ?? 0).abs();
    if (quizId == 0) return;

    setState(() => _isSubmittingQuiz = true);
    try {
      final wp = Provider.of<WorkspaceProvider>(context, listen: false);
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      final results = _quizAnswers.map((k, v) => MapEntry(k.toString(), v));
      debugPrint('📝 >>> SUBMITTING QUIZ: id=$quizId answers=$results');
      final res = await wp.submitQuiz(quizId, results);
      debugPrint('📝 <<< QUIZ RESPONSE: $res');
      if (mounted) {
        setState(() {
          _quizResult = res;
          _isQuizSubmitted = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(lang.translate('quiz_submitted_msg')),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("${lang.translate('operation_failure')}: $e"),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      }
    } finally {
      if (mounted) setState(() => _isSubmittingQuiz = false);
    }
  }

  void _playNext() {
    if (widget.nextMaterial == null) return;
    
    // Nullify controllers immediately so build() doesn't reuse them
    final oldChewie = _chewieController;
    final oldVideo = _videoPlayerController;
    
    _chewieController = null;
    _videoPlayerController = null;
    
    oldVideo?.removeListener(_videoListener);
    
    // Dispose asynchronously to let the widget tree rebuild first
    Future.microtask(() {
      oldChewie?.dispose();
      oldVideo?.dispose();
    });
    
    if (mounted) setState(() {});
    
    // FETCH THE UPDATED LIST TO FIND THE NEW "NEXT"
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final courseId = widget.courseId ?? int.tryParse(widget.material['course_id']?.toString() ?? '0') ?? 0;
    
    // RECURSIVE BINGE LEARNING TRANSITION
    Navigator.pushReplacementNamed(context, '/material', arguments: {
      'material': widget.nextMaterial, 
      'courseId': courseId,
      'forceLandscape': widget.nextMaterial!['type']?.toString().toLowerCase() == 'video' || widget.nextMaterial!['type']?.toString().toLowerCase() == 'mp4',
      'nextMaterial': null // The Dashboard or CourseDetail will figure out the next in real logic, but for simple transition we can pass it via previous state if available
    });
  }

  @override
  void dispose() {
    _hideHintTimer?.cancel();
    _videoPlayerController?.removeListener(_videoListener);
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _assignmentTextController.dispose();
    _assignmentFileController.dispose();
    NoScreenshot.instance.removeAllCallbacks();
    
    if (_isLandscapeMode) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final material = widget.material;
    final type = material['type']?.toString().toLowerCase();
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    
    final isRTL = lang.currentLocale.languageCode == 'ar';

    final Map<String, dynamic> materialData = widget.material;
    final contentUrl = materialData['content_url']?.toString() ?? materialData['link_url']?.toString() ?? materialData['file_path']?.toString() ?? materialData['url']?.toString() ?? '';
    
    final isImageUrl = contentUrl.isNotEmpty &&
        RegExp(r'\.(jpg|jpeg|png|gif|webp|svg|bmp)(\?.*)?$', caseSensitive: false).hasMatch(contentUrl);
    // isImage is true when type is 'image', type is unset+url is image,
    // OR type is pdf/document but the actual URL is an image (mismatch — open as image)
    final isImage = type == 'image' ||
        ((type == null || type.isEmpty) && isImageUrl) ||
        ((type == 'pdf' || type == 'document' || type == 'pdf_file') && isImageUrl);
    final isVideo = (type == 'video' || type == 'mp4' || type == 'stream') || _chewieController != null || _errorMessage != null;
    // PDF fullscreen only applies when it's actually a PDF (not an image-url mismatch)
    final isPdfContent = (type == 'pdf' || type == 'document' || type == 'pdf_file') && !isImageUrl;
    final isFullscreen = !_notEnrolled && (_isLandscapeMode && isVideo || isPdfContent);

    return Scaffold(
      backgroundColor: isFullscreen ? Colors.black : Theme.of(context).scaffoldBackgroundColor,
      appBar: isFullscreen ? null : AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        leading: IconButton(icon: Icon(isRTL ? Icons.arrow_back_ios_new_rounded : Icons.arrow_back_ios_rounded, color: onSurface, size: 18), onPressed: () => Navigator.pop(context)),
        title: Text(material['title'] ?? lang.translate('course_contents'), style: TextStyle(color: onSurface, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Center(
                    child: _isLoading 
                      ? const PremiumLoader()
                      : _notEnrolled
                        ? _buildNotEnrolledView(lang, primaryColor, onSurface)
                        : isVideo
                          ? AspectRatio(
                              aspectRatio: _videoPlayerController?.value.aspectRatio ?? 16 / 9,
                              child: Container(
                                margin: _isLandscapeMode ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                                decoration: BoxDecoration(
                                  color: Colors.black, 
                                  borderRadius: _isLandscapeMode ? null : BorderRadius.circular(28),
                                  boxShadow: _isLandscapeMode ? [] : [
                                    BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: 40, spreadRadius: -10, offset: const Offset(0, 20)),
                                    const BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 5)),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: _errorMessage != null
                                          ? Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                                                  const SizedBox(height: 16),
                                                  Text(_errorMessage!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                                ],
                                              ),
                                            )
                                          : (_chewieController != null) 
                                              ? Chewie(controller: _chewieController!) 
                                              : const PremiumLoader(),
                                    ),
                                    const WatermarkOverlay(isContentOnly: true),
                                    
                                    // NEXT VIDEO OVERLAY (BINGE MODE)
                                    if (_showNextHint && widget.nextMaterial != null)
                                      Positioned(
                                        top: _isLandscapeMode ? 32 : null,
                                        bottom: _isLandscapeMode ? null : 40, 
                                        right: isRTL ? null : 24,
                                        left: isRTL ? 24 : null,
                                        child: TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0, end: 1.0),
                                          duration: const Duration(milliseconds: 600),
                                          builder: (context, opacity, child) => Opacity(
                                            opacity: opacity,
                                            child: Transform.translate(offset: Offset(0, (1 - opacity) * 10), child: child),
                                          ),
                                          child: GestureDetector(
                                            onTap: _playNext,
                                            child: Container(
                                              width: 280,
                                              padding: const EdgeInsets.all(14),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.9),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(color: Colors.white24, width: 2),
                                                boxShadow: [
                                                  BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 30, spreadRadius: -5),
                                                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20),
                                                ],
                                              ),
                                              child: Row(
                                                children: [
                                                  Stack(
                                                    alignment: Alignment.center,
                                                    children: [
                                                      ClipRRect(
                                                        borderRadius: BorderRadius.circular(12),
                                                        child: Image.network(
                                                          widget.nextMaterial!['thumbnail_url'] ?? 'https://images.unsplash.com/photo-1546410531-bb4caa6b424d?w=200&q=80',
                                                          width: 72, height: 40, fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                      Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14)),
                                                    ],
                                                  ),
                                                  const SizedBox(width: 14),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text("NEXT LESSON IN ${_remainingSeconds}S", style: const TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                                                        const SizedBox(height: 4),
                                                        Text(widget.nextMaterial!['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                    if (_isLandscapeMode)
                                      Positioned(
                                        top: 20, 
                                        left: isRTL ? null : 20,
                                        right: isRTL ? 20 : null,
                                        child: Container(
                                          decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                                          child: IconButton(
                                            onPressed: () => Navigator.pop(context),
                                            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
                                          ),
                                        ),
                                      ),
                                    // PREMIUM OVERLAY LABEL (TOP LEFT)
                                    if (!_isLandscapeMode)
                                      Positioned(
                                        top: 16, left: 16,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.security_rounded, color: Colors.white, size: 10),
                                              const SizedBox(width: 6),
                                              Text('SECURE STREAM', style: modern_fonts.GoogleFonts.outfit(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            )
                         : (type == 'pdf' || type == 'document' || type == 'pdf_file')
                            ? Stack(
                                children: [
                                  if (_localPdfPath != null)
                                     Container(color: Colors.white, child: PDFView(filePath: _localPdfPath!, autoSpacing: true, enableSwipe: true, pageSnap: true, swipeHorizontal: true, nightMode: false))
                                  else
                                     _buildPdfDownloadNotice(contentUrl, lang, primaryColor),
                                  
                                  // FLOATING CLOSE BUTTON FOR PDF
                                  Positioned(
                                      top: 20, 
                                      right: isRTL ? null : 20,
                                      left: isRTL ? 20 : null,
                                      child: Container(
                                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                        child: IconButton(
                                          onPressed: () => Navigator.pop(context),
                                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                                        ),
                                      ),
                                  ),
                                ],
                              )
                            : type == 'quiz'
                              ? _buildQuizView(material, lang, primaryColor)
                              : (type == 'assignment' || type == 'homework')
                                ? _buildAssignmentView(material, lang, primaryColor)
                                : _buildDefaultLessonNotice(material, lang),
                  ),
                ),
                
                // LESSON DETAILS DRAWER
                if (!_isLoading && !isFullscreen && !_notEnrolled)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32)), border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 2))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(lang.translate('now_active').toUpperCase(), style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5))),
                            const Spacer(),
                            Icon(Icons.shield_rounded, color: primaryColor.withOpacity(0.5), size: 16),
                            const SizedBox(width: 4),
                            Text('DRM PROTECTED', style: TextStyle(color: primaryColor.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(material['title'] ?? '', style: TextStyle(color: onSurface, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                      ],
                    ),
                  ),
              ],
            ),
            if (_isSubscribing)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: const Center(
                    child: PremiumLoader(size: 80),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfDownloadNotice(String url, LanguageProvider lang, Color primary) {
     return Column(
       mainAxisAlignment: MainAxisAlignment.center,
       children: [
         const PremiumLoader(),
         const SizedBox(height: 24),
         Text(lang.translate('loading_curriculum') ?? 'INITIALIZING CURRICULUM...', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
       ],
     );
  }

  Widget _buildNoContentView(LanguageProvider lang, Color onSurface, bool isRTL) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: onSurface.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.file_present_rounded, size: 56, color: onSurface.withOpacity(0.2)),
        ),
        const SizedBox(height: 20),
        Text(
          isRTL ? 'لا يوجد محتوى' : 'No Content Available',
          style: TextStyle(color: onSurface, fontSize: 18, fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          isRTL ? 'هذا الدرس لا يحتوي على ملف بعد.' : 'This lesson has no file attached yet.',
          style: TextStyle(color: onSurface.withOpacity(0.45), fontSize: 13, fontWeight: FontWeight.w500, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDefaultLessonNotice(Map<String, dynamic> material, LanguageProvider lang) {
     return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Theme.of(context).dividerColor, shape: BoxShape.circle), child: Icon(Icons.article_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3), size: 56)),
          const SizedBox(height: 24),
          Text(material['title'] ?? '', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w900)),
        ],
     );
  }

  Widget _buildQuizView(Map<String, dynamic> material, LanguageProvider lang, Color primary) {
    final List questions = material['questions'] ?? [];
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final answeredCount = _quizAnswers.values.where((v) => v != null).length;

    final quizData = material['quiz_data'] ?? {};
    final quizObj = quizData['quiz'] ?? {};
    final timeLimit = quizObj['time_limit'] ?? material['time_limit'] ?? 0;
    final prevAttempt = quizData['previousAttempt'];
    final hasPrevAttempt = prevAttempt != null;

    // ── EMPTY STATE ──
    if (questions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.quiz_rounded, size: 56, color: primary.withOpacity(0.4)),
            ),
            const SizedBox(height: 20),
            Text(
              lang.translate('no_quiz_data'),
              style: GoogleFonts.cairo(color: onSurface.withOpacity(0.5), fontSize: 15, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // ── RESULT SCREEN ──
    if (_isQuizSubmitted || hasPrevAttempt) {
      final resData = _quizResult?['data'] ?? _quizResult ?? prevAttempt;
      final scoreRaw = resData?['score'] ?? resData?['percentage'] ?? '0';
      final scoreDouble = double.tryParse(scoreRaw.toString()) ?? 0.0;
      final total = resData?['totalCount'] ?? resData?['total'] ?? questions.length;
      final correct = resData?['correct'] ?? resData?['correct_count'] ?? '-';
      final passed = scoreDouble >= 50;
      final scoreColor = passed
          ? const Color(0xFF22C55E)
          : const Color(0xFFF43F5E);

      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              passed
                  ? const Color(0xFF22C55E).withOpacity(isDark ? 0.15 : 0.07)
                  : const Color(0xFFF43F5E).withOpacity(isDark ? 0.15 : 0.07),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
          child: Column(
            children: [
              // Score ring
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      value: scoreDouble / 100,
                      strokeWidth: 10,
                      backgroundColor: scoreColor.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${scoreDouble.toStringAsFixed(0)}%',
                        style: GoogleFonts.outfit(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: scoreColor,
                          height: 1,
                        ),
                      ),
                      Text(
                        lang.translate('your_score'),
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Pass/Fail badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: scoreColor.withOpacity(0.3), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(passed ? Icons.emoji_events_rounded : Icons.refresh_rounded, color: scoreColor, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      passed ? lang.translate('quiz_passed') : lang.translate('quiz_failed'),
                      style: GoogleFonts.cairo(color: scoreColor, fontSize: 14, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Quiz title
              Text(
                lang.translate('quiz_completed'),
                style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w900, color: onSurface),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                material['title'] ?? '',
                style: GoogleFonts.cairo(fontSize: 14, color: onSurface.withOpacity(0.5)),
                textAlign: TextAlign.center,
              ),
              if (timeLimit > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${lang.translate('available_tries') ?? "Available tries"}: $timeLimit',
                    style: GoogleFonts.cairo(fontSize: 12, color: primary, fontWeight: FontWeight.w900),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // Stats row
              Row(
                children: [
                  _buildResultStat(
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF22C55E),
                    label: lang.translate('correct_answers'),
                    value: correct.toString(),
                    onSurface: onSurface,
                  ),
                  const SizedBox(width: 12),
                  _buildResultStat(
                    icon: Icons.quiz_rounded,
                    color: primary,
                    label: lang.translate('question'),
                    value: total.toString(),
                    onSurface: onSurface,
                  ),
                  const SizedBox(width: 12),
                  _buildResultStat(
                    icon: Icons.percent_rounded,
                    color: scoreColor,
                    label: lang.translate('your_score'),
                    value: '${scoreDouble.toStringAsFixed(1)}%',
                    onSurface: onSurface,
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // Back button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                  label: Text(lang.translate('back_to_course'), style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                ),
              ),

            ],
          ),
        ),
      );
    }

    // ── QUIZ QUESTION VIEW ──
    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primary, primary.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: primary.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.quiz_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                material['title'] ?? lang.translate('quiz_title'),
                                style: GoogleFonts.cairo(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                lang.translate('quiz_subtitle'),
                                style: GoogleFonts.cairo(color: Colors.white70, fontSize: 11),
                              ),
                              if (timeLimit > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '${lang.translate('available_tries') ?? "Available tries allowed"}: $timeLimit',
                                    style: GoogleFonts.cairo(color: Colors.white.withOpacity(0.85), fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            '${questions.length} ${lang.translate('question')}',
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: answeredCount / questions.length,
                        backgroundColor: Colors.white.withOpacity(0.25),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${lang.translate('answered').replaceFirst('{}', answeredCount.toString()).replaceFirst('{}', questions.length.toString())}',
                      style: GoogleFonts.cairo(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),

            // Questions list
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final q = questions[i];
                    final qId = int.tryParse(q['id']?.toString() ?? '0') ?? 0;
                    final List options = q['options'] ?? [];
                    final isAnswered = _quizAnswers[qId] != null;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isAnswered
                              ? primary.withOpacity(0.3)
                              : onSurface.withOpacity(0.06),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isAnswered
                                ? primary.withOpacity(0.08)
                                : Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Question header
                          Container(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                            decoration: BoxDecoration(
                              color: isAnswered
                                  ? primary.withOpacity(0.06)
                                  : onSurface.withOpacity(0.03),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isAnswered ? primary : onSurface.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${i + 1}',
                                      style: GoogleFonts.outfit(
                                        color: isAnswered ? Colors.white : onSurface.withOpacity(0.5),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${lang.translate('question')} ${i + 1}',
                                  style: GoogleFonts.cairo(
                                    color: isAnswered ? primary : onSurface.withOpacity(0.4),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const Spacer(),
                                if (isAnswered)
                                  Icon(Icons.check_circle_rounded, color: primary, size: 16),
                              ],
                            ),
                          ),

                          // Question text
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            child: HtmlWidget(
                              q['question_text'] ?? q['text'] ?? q['question'] ?? '',
                              textStyle: GoogleFonts.cairo(
                                color: onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                              onTapImage: (src) => _showImageModal(context, src.toString()),
                            ),
                          ),

                          // Question Image (API-driven) - Small Preview Box
                          if (q['image_url'] != null && q['image_url'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: GestureDetector(
                                  onTap: () => _showImageModal(context, q['image_url'].toString()),
                                  child: Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: onSurface.withOpacity(0.12), width: 1.5),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: Image.network(
                                            q['image_url'].toString(),
                                            fit: BoxFit.cover,
                                            loadingBuilder: (c, child, progress) => progress == null
                                                ? child
                                                : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                            errorBuilder: (c, e, s) => const Icon(Icons.broken_image_rounded, color: Colors.grey),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 4,
                                          right: 4,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // Options
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Column(
                              children: List.generate(options.length, (oi) {
                                final opt = options[oi];
                                final optId = int.tryParse(opt['id']?.toString() ?? oi.toString()) ?? oi;
                                final isSelected = _quizAnswers[qId] == optId;
                                final letter = String.fromCharCode(65 + oi); // A, B, C, D...

                                return GestureDetector(
                                  onTap: () => setState(() => _quizAnswers[qId] = optId),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? primary.withOpacity(isDark ? 0.2 : 0.08)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? primary : onSurface.withOpacity(0.1),
                                        width: isSelected ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Letter badge
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: isSelected ? primary : onSurface.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Center(
                                            child: Text(
                                              letter,
                                              style: GoogleFonts.outfit(
                                                color: isSelected ? Colors.white : onSurface.withOpacity(0.5),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: HtmlWidget(
                                            opt['option_text'] ?? opt['text'] ?? opt['option'] ?? '',
                                            textStyle: GoogleFonts.cairo(
                                              color: isSelected ? onSurface : onSurface.withOpacity(0.75),
                                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                            onTapImage: (src) => _showImageModal(context, src.toString()),
                                          ),
                                        ),
                                        if (isSelected)
                                          Icon(Icons.check_circle_rounded, color: primary, size: 18),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: questions.length,
                ),
              ),
            ),
          ],
        ),

        // ── STICKY BOTTOM SUBMIT BAR ──
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$answeredCount / ${questions.length}',
                        style: GoogleFonts.outfit(color: primary, fontSize: 13, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        lang.translate('answered').split(' ').first,
                        style: GoogleFonts.cairo(color: onSurface.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (answeredCount == 0 || _isSubmittingQuiz) ? null : _submitQuiz,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: onSurface.withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: answeredCount > 0 ? 4 : 0,
                    ),
                    child: _isSubmittingQuiz
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text(
                            lang.translate('submit_quiz').toUpperCase(),
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultStat({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required Color onSurface,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.12 : 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.outfit(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.cairo(color: onSurface.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 2),
          ],
        ),
      ),
    );
  }

  // ─── ASSIGNMENT SUBMISSION & VIEWS ─────────────────────────────────────────
  Future<void> _submitAssignment() async {
    final material = widget.material;
    final assignmentId = (int.tryParse(material['id']?.toString() ?? '0') ?? 0).abs();
    if (assignmentId == 0) return;

    final lang = Provider.of<LanguageProvider>(context, listen: false);
    if (_assignmentTextController.text.trim().isEmpty && 
        _assignmentFileController.text.trim().isEmpty &&
        (_pickedAssignmentFilePath == null || _pickedAssignmentFilePath!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(lang.translate('write_text_or_file') ?? "Please provide a text answer or file attachment URL"),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() => _isSubmittingAssignment = true);
    try {
      final wp = Provider.of<WorkspaceProvider>(context, listen: false);
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      
      dynamic res;
      if (_pickedAssignmentFilePath != null && _pickedAssignmentFilePath!.isNotEmpty) {
        debugPrint('📝 >>> SUBMITTING MULTIPART ASSIGNMENT: id=$assignmentId path=$_pickedAssignmentFilePath');
        res = await wp.submitAssignmentMultipart(
          assignmentId,
          _assignmentTextController.text.trim(),
          _pickedAssignmentFilePath,
        );
      } else {
        final body = {
          'text_answer': _assignmentTextController.text.trim(),
          'file_url': _assignmentFileController.text.trim(),
        };
        debugPrint('📝 >>> SUBMITTING ASSIGNMENT: id=$assignmentId body=$body');
        res = await wp.submitAssignment(assignmentId, body);
      }
      
      debugPrint('📝 <<< ASSIGNMENT RESPONSE: $res');
      
      if (mounted) {
        setState(() {
          _assignmentResult = res;
          _isAssignmentSubmitted = true;
          // Enrich original material to show updated submission status
          if (widget.material['assignment_data'] != null) {
            widget.material['assignment_data']['previousSubmission'] = {
              'text_answer': _assignmentTextController.text.trim(),
              'file_url': _pickedAssignmentFileName ?? _assignmentFileController.text.trim(),
              'status': 'submitted',
              'submitted_at': DateTime.now().toIso8601String(),
            };
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(lang.translate('operation_success') ?? 'Assignment submitted successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("${lang.translate('operation_failure')}: $e"),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } finally {
      if (mounted) setState(() => _isSubmittingAssignment = false);
    }
  }

  Widget _buildAssignmentView(Map<String, dynamic> material, LanguageProvider lang, Color primary) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final assignData = material['assignment_data'] ?? {};
    final assignment = assignData['assignment'] ?? {};
    final prevSub = assignData['previousSubmission'];

    final String title = assignment['title'] ?? material['title'] ?? 'Assignment';
    final String description = assignment['description'] ?? material['description'] ?? 'No instructions provided.';
    final int maxPoints = assignment['max_points'] ?? 100;
    final String dueDate = assignment['due_date'] ?? 'No due date';

    final hasPrevSubmission = prevSub != null || _isAssignmentSubmitted;
    final submissionStatus = (prevSub?['status'] ?? 'submitted').toString().toLowerCase();
    
    // Status color
    Color statusColor = Colors.orange;
    if (submissionStatus == 'graded' || submissionStatus == 'completed') {
      statusColor = Colors.green;
    } else if (submissionStatus == 'failed' || submissionStatus == 'rejected') {
      statusColor = Colors.red;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary, primary.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: primary.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.assignment_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.cairo(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${lang.translate('max_points') ?? 'Max Points'}: $maxPoints',
                            style: GoogleFonts.cairo(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 24, thickness: 1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${lang.translate('due_date') ?? 'Due Date'}:',
                      style: GoogleFonts.cairo(color: Colors.white70, fontSize: 11),
                    ),
                    Text(
                      dueDate.length > 10 ? dueDate.substring(0, 10) : dueDate,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Instructions Label
          Text(
            lang.translate('assignment_instructions') ?? 'INSTRUCTIONS',
            style: GoogleFonts.cairo(color: onSurface.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
          ),
          const SizedBox(height: 10),

          // Description Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: onSurface.withOpacity(0.06), width: 1.5),
            ),
            child: HtmlWidget(
              description,
              textStyle: GoogleFonts.cairo(
                color: onSurface,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Submission Status (if exists)
          if (hasPrevSubmission) ...[
            Text(
              lang.translate('submission_status') ?? 'SUBMISSION STATUS',
              style: GoogleFonts.cairo(color: onSurface.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withOpacity(0.2), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: statusColor, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        (lang.translate('status') ?? 'Status').toUpperCase(),
                        style: GoogleFonts.cairo(color: onSurface.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          submissionStatus.toUpperCase(),
                          style: GoogleFonts.outfit(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  if (prevSub?['file_url'] != null && prevSub['file_url'].toString().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      lang.translate('submitted_file') ?? 'Submitted File',
                      style: GoogleFonts.cairo(color: onSurface.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () {
                        final url = prevSub['file_url'].toString();
                        if (url.isNotEmpty) {
                          final provider = Provider.of<WorkspaceProvider>(context, listen: false);
                          provider.launchUrl(url);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: onSurface.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: onSurface.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.insert_drive_file_rounded, color: primary, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                prevSub['file_url'].toString().split('/').last,
                                style: GoogleFonts.outfit(color: primary, fontSize: 12, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (prevSub?['text_answer'] != null && prevSub['text_answer'].toString().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      lang.translate('submitted_answer') ?? 'Your Answer',
                      style: GoogleFonts.cairo(color: onSurface.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      prevSub['text_answer'].toString(),
                      style: GoogleFonts.cairo(color: onSurface, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Submission Form (if not graded AND has not submitted before - only one answer)
          if (submissionStatus != 'graded' && !hasPrevSubmission) ...[
            Text(
              lang.translate('new_submission') ?? 'SUBMIT ASSIGNMENT',
              style: GoogleFonts.cairo(color: onSurface.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: onSurface.withOpacity(0.06), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.translate('text_answer') ?? 'Write your answer:',
                    style: GoogleFonts.cairo(color: onSurface, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _assignmentTextController,
                    maxLines: 5,
                    style: TextStyle(color: onSurface),
                    decoration: InputDecoration(
                      hintText: lang.translate('type_here') ?? 'Type your answer here...',
                      hintStyle: TextStyle(color: onSurface.withOpacity(0.3)),
                      filled: true,
                      fillColor: onSurface.withOpacity(0.03),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: onSurface.withOpacity(0.1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: primary, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    lang.translate('upload_file') ?? 'Upload Document:',
                    style: GoogleFonts.cairo(color: onSurface, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  
                  // Premium Device File Picker UI
                  if (_pickedAssignmentFilePath != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.withOpacity(0.3), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.insert_drive_file_rounded, color: Colors.green, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _pickedAssignmentFileName ?? "Selected File",
                                  style: GoogleFonts.outfit(color: onSurface, fontWeight: FontWeight.bold, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Ready to upload",
                                  style: GoogleFonts.outfit(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                            onPressed: () => setState(() {
                              _pickedAssignmentFilePath = null;
                              _pickedAssignmentFileName = null;
                            }),
                          ),
                        ],
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () async {
                        try {
                          FilePickerResult? result = await FilePicker.platform.pickFiles(
                            type: FileType.any,
                          );
                          if (result != null && result.files.single.path != null) {
                            setState(() {
                              _pickedAssignmentFilePath = result.files.single.path;
                              _pickedAssignmentFileName = result.files.single.name;
                            });
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text("Error picking file: $e"),
                            backgroundColor: Colors.red,
                          ));
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: primary.withOpacity(0.25), width: 1.5, style: BorderStyle.solid),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.cloud_upload_rounded, color: primary, size: 36),
                            const SizedBox(height: 12),
                            Text(
                              lang.translate('select_file') ?? "Select file from device",
                              style: GoogleFonts.cairo(color: onSurface, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lang.translate('select_file_hint') ?? "PDF, ZIP, DOC, Images allowed",
                              style: GoogleFonts.cairo(color: onSurface.withOpacity(0.4), fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmittingAssignment ? null : _submitAssignment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isSubmittingAssignment
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Text(
                              (lang.translate('submit_assignment') ?? 'Submit Assignment').toUpperCase(),
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
