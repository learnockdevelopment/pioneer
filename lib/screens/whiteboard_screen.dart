import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:elmasa/providers/workspace_provider.dart';
import 'package:elmasa/providers/language_provider.dart';
import 'package:elmasa/widgets/premium_loader.dart';

class WhiteboardScreen extends StatefulWidget {
  final int? courseId;
  const WhiteboardScreen({super.key, this.courseId});

  @override
  State<WhiteboardScreen> createState() => _WhiteboardScreenState();
}

class _WhiteboardScreenState extends State<WhiteboardScreen> {
  int? _selectedCourseId;
  bool _isLoading = false;
  Map<String, dynamic>? _sessionData;
  List<dynamic> _pages = [];
  int _currentPageIndex = 0;
  String _userAccessType = 'view'; // full, draw, view
  bool _canDraw = false;
  bool _canPresent = false;
  int? _whiteboardId;

  // Drawing state
  List<_DrawingStroke> _strokes = [];
  List<Offset> _currentPoints = [];
  Color _selectedColor = const Color(0xFF4F46E5);
  double _selectedWidth = 4.0;
  
  // Real-time connection
  http.Client? _sseClient;
  bool _isConnectingSSE = false;

  final List<Color> _palette = [
    const Color(0xFF4F46E5), // Indigo
    const Color(0xFFEF4444), // Red
    const Color(0xFF10B981), // Emerald
    const Color(0xFFF59E0B), // Amber
    const Color(0xFF06B6D4), // Cyan
    const Color(0xFFEC4899), // Pink
    const Color(0xFF000000), // Black
    const Color(0xFFFFFFFF), // White
  ];

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _selectedCourseId = widget.courseId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      if (_selectedCourseId == null) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is int) {
          _selectedCourseId = args;
        } else if (args is Map && args.containsKey('courseId')) {
          _selectedCourseId = args['courseId'] as int?;
        }
      }
      
      if (_selectedCourseId != null) {
        _loadWhiteboard();
      } else {
        _autoSelectCourse();
      }
    }
  }

  @override
  void dispose() {
    _disconnectSSE();
    super.dispose();
  }

  void _disconnectSSE() {
    _sseClient?.close();
    _sseClient = null;
    _isConnectingSSE = false;
  }

  Future<void> _autoSelectCourse() async {
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final List courses = (wp.cachedDashboard?['courses'] ?? wp.cachedDashboard?['data']?['courses'] ?? []) as List;
    if (courses.isNotEmpty) {
      final firstCourseId = int.tryParse(courses.first['id']?.toString() ?? '');
      if (firstCourseId != null) {
        setState(() {
          _selectedCourseId = firstCourseId;
        });
        _loadWhiteboard();
      }
    }
  }

  Future<void> _loadWhiteboard() async {
    if (_selectedCourseId == null) return;
    setState(() {
      _isLoading = true;
      _strokes = [];
    });

    _disconnectSSE();

    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    try {
      final res = await wp.request('GET', '/courses/$_selectedCourseId/whiteboard');
      if (res != null) {
        setState(() {
          _sessionData = res;
          _whiteboardId = res['whiteboard_id'];
          _userAccessType = res['user_access_type']?.toString() ?? 'view';
          _canDraw = res['can_draw'] == true || _userAccessType == 'full' || _userAccessType == 'draw';
          _canPresent = res['can_present'] == true || _userAccessType == 'full';
          _pages = res['pages'] is List ? List.from(res['pages']) : [];
          _currentPageIndex = int.tryParse(res['current_page_index']?.toString() ?? '0') ?? 0;
          
          if (_pages.isNotEmpty && _currentPageIndex < _pages.length) {
            _parseCanvasData(_pages[_currentPageIndex]['canvas_data']);
          }
        });

        if (_whiteboardId != null) {
          _connectSSE();
        }
      }
    } catch (e) {
      debugPrint('Error loading whiteboard: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _parseCanvasData(String? canvasDataStr) {
    if (canvasDataStr == null || canvasDataStr.isEmpty) return;
    try {
      final data = json.decode(canvasDataStr);
      final List objects = data['objects'] is List ? data['objects'] : [];
      List<_DrawingStroke> loadedStrokes = [];
      
      for (final obj in objects) {
        if (obj['type'] == 'path' && obj['path'] is List) {
          final List pathData = obj['path'];
          final color = _parseColor(obj['stroke']);
          final strokeWidth = double.tryParse(obj['strokeWidth']?.toString() ?? '3') ?? 3.0;
          
          List<Offset> points = [];
          for (final step in pathData) {
            if (step is List && step.length >= 3) {
              final x = double.tryParse(step[1]?.toString() ?? '0') ?? 0.0;
              final y = double.tryParse(step[2]?.toString() ?? '0') ?? 0.0;
              points.add(Offset(x, y));
            }
          }
          if (points.isNotEmpty) {
            loadedStrokes.add(_DrawingStroke(points: points, color: color, width: strokeWidth));
          }
        }
      }

      setState(() {
        _strokes = loadedStrokes;
      });
    } catch (e) {
      debugPrint('Failed to parse canvas data: $e');
    }
  }

  Color _parseColor(dynamic strokeVal) {
    if (strokeVal == null) return Colors.black;
    final str = strokeVal.toString().replaceAll('#', '');
    if (str.length == 6) {
      return Color(int.parse('FF$str', radix: 16));
    } else if (str.length == 8) {
      return Color(int.parse(str, radix: 16));
    }
    return Colors.black;
  }

  String _toHexColor(Color color) {
    return '#${color.value.toRadixString(16).substring(2).padLeft(6, '0')}';
  }

  Future<void> _connectSSE() async {
    if (_whiteboardId == null || _selectedCourseId == null || _isConnectingSSE) return;
    _isConnectingSSE = true;

    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final workspace = wp.activeWorkspace;
    if (workspace == null) return;

    final host = workspace.host;
    final token = workspace.token;

    _sseClient = http.Client();
    final url = Uri.parse('https://$host/api/courses/$_selectedCourseId/whiteboard/stream?whiteboard_id=$_whiteboardId');
    final request = http.Request('GET', url);
    request.headers.addAll({
      'Accept': 'text/event-stream',
      'Authorization': 'Bearer $token',
      'Cache-Control': 'no-cache',
    });

    try {
      final response = await _sseClient!.send(request);
      if (response.statusCode == 200) {
        response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
              if (line.startsWith('data:')) {
                final dataStr = line.substring(5).trim();
                _handleIncomingSSEEvent(dataStr);
              }
            }, onError: (e) {
              debugPrint('SSE Error: $e');
              _reconnectSSELater();
            }, onDone: () {
              debugPrint('SSE Closed');
              _reconnectSSELater();
            });
      }
    } catch (e) {
      debugPrint('SSE Connection Exception: $e');
      _reconnectSSELater();
    }
  }

  void _reconnectSSELater() {
    _isConnectingSSE = false;
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _whiteboardId != null) {
        _connectSSE();
      }
    });
  }

  void _handleIncomingSSEEvent(String jsonStr) {
    try {
      final data = json.decode(jsonStr);
      final action = data['action']?.toString();
      final pageId = data['page_id'];

      if (action == 'DRAW_OBJECT' && data['payload'] != null) {
        final payload = data['payload'];
        if (payload['type'] == 'path' && payload['path'] is List) {
          final List pathData = payload['path'];
          final color = _parseColor(payload['stroke']);
          final width = double.tryParse(payload['strokeWidth']?.toString() ?? '3') ?? 3.0;

          List<Offset> points = [];
          for (final step in pathData) {
            if (step is List && step.length >= 3) {
              final x = double.tryParse(step[1]?.toString() ?? '0') ?? 0.0;
              final y = double.tryParse(step[2]?.toString() ?? '0') ?? 0.0;
              points.add(Offset(x, y));
            }
          }

          if (points.isNotEmpty) {
            setState(() {
              _strokes.add(_DrawingStroke(points: points, color: color, width: width));
            });
          }
        }
      } else if (action == 'CLEAR_CANVAS') {
        setState(() {
          _strokes = [];
        });
      } else if (action == 'PAGE_CHANGED') {
        _loadWhiteboard();
      }
    } catch (e) {
      debugPrint('Error parsing incoming event: $e');
    }
  }

  Future<void> _syncStroke(_DrawingStroke stroke) async {
    if (_selectedCourseId == null || _whiteboardId == null) return;
    
    // Format coordinates list into path actions [["M", x, y], ["L", x, y]...]
    List<List<dynamic>> pathSteps = [];
    for (int i = 0; i < stroke.points.length; i++) {
      final pt = stroke.points[i];
      pathSteps.add([
        i == 0 ? 'M' : 'L',
        pt.dx,
        pt.dy
      ]);
    }

    final payload = {
      'type': 'path',
      'stroke': _toHexColor(stroke.color),
      'strokeWidth': stroke.width,
      'path': pathSteps,
    };

    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final pageId = _pages.isNotEmpty && _currentPageIndex < _pages.length ? _pages[_currentPageIndex]['id'] : null;

    try {
      await wp.request('POST', '/courses/$_selectedCourseId/whiteboard/sync', body: {
        'whiteboard_id': _whiteboardId,
        'page_id': pageId,
        'action': 'DRAW_OBJECT',
        'payload': payload,
      });
    } catch (e) {
      debugPrint('Sync stroke error: $e');
    }
  }

  Future<void> _clearCanvas() async {
    if (!_canPresent) return;
    setState(() {
      _strokes = [];
    });

    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final pageId = _pages.isNotEmpty && _currentPageIndex < _pages.length ? _pages[_currentPageIndex]['id'] : null;

    try {
      await wp.request('POST', '/courses/$_selectedCourseId/whiteboard/sync', body: {
        'whiteboard_id': _whiteboardId,
        'page_id': pageId,
        'action': 'CLEAR_CANVAS',
      });
    } catch (e) {
      debugPrint('Clear canvas error: $e');
    }
  }

  Future<void> _saveSnapshot() async {
    if (_selectedCourseId == null) return;
    
    // Create base64 snapshot image
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 800, 600));
    
    // Background
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(const Rect.fromLTWH(0, 0, 800, 600), bgPaint);

    // Draw all strokes
    for (final stroke in _strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      if (stroke.points.isNotEmpty) {
        path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(800, 600);
    final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (pngBytes == null) return;
    
    final base64String = 'data:image/png;base64,${base64Encode(pngBytes.buffer.asUint8List())}';
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 12), Text('Saving snapshot...')])),
    );

    try {
      final res = await wp.request('POST', '/courses/$_selectedCourseId/whiteboard/snapshot', body: {
        'snapshotDataUrl': base64String,
        'snapshotName': 'Snapshot Page ${_currentPageIndex + 1}',
      });

      if (mounted && res != null && res['success'] == true) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode == 'ar' ? 'تم حفظ اللوحة بنجاح!' : 'Whiteboard snapshot saved successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wp = Provider.of<WorkspaceProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final isRTL = lang.currentLocale.languageCode == 'ar';
    final List courses = (wp.cachedDashboard?['courses'] ?? wp.cachedDashboard?['data']?['courses'] ?? []) as List;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(isRTL ? Icons.arrow_back_ios_new_rounded : Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lang.translate('whiteboard') ?? (isRTL ? 'السبورة التفاعلية' : 'Interactive Whiteboard'),
          style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (_sessionData != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _canDraw ? const Color(0xFF10B981).withOpacity(0.2) : Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _canDraw ? const Color(0xFF10B981) : Colors.amber, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    _canDraw 
                        ? (isRTL ? 'متاح للرسم' : 'Can Draw') 
                        : (isRTL ? 'عرض فقط' : 'View Only'),
                    style: TextStyle(color: _canDraw ? const Color(0xFF10B981) : Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Course selector & Options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedCourseId,
                        dropdownColor: const Color(0xFF0F172A),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
                        hint: Text(isRTL ? 'اختر الكورس' : 'Select Course', style: const TextStyle(color: Colors.white54)),
                        items: courses.map<DropdownMenuItem<int>>((c) {
                          return DropdownMenuItem<int>(
                            value: int.tryParse(c['id']?.toString() ?? ''),
                            child: Text(
                              c['title']?.toString() ?? '',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          );
                        }).toList(),
                        onChanged: (id) {
                          if (id != null) {
                            setState(() {
                              _selectedCourseId = id;
                            });
                            _loadWhiteboard();
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_sessionData != null) ...[
                  IconButton(
                    onPressed: _loadWhiteboard,
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                    tooltip: isRTL ? 'إعادة تحميل' : 'Reload',
                  ),
                  if (_canPresent)
                    IconButton(
                      onPressed: _saveSnapshot,
                      icon: const Icon(Icons.camera_alt_rounded, color: Colors.white70),
                      tooltip: isRTL ? 'حفظ لقطة' : 'Save Snapshot',
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Main Canvas Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  color: Colors.white,
                  child: _isLoading
                      ? Center(child: PremiumLoader(color: primaryColor))
                      : _sessionData == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.border_color_rounded, size: 64, color: Colors.black26),
                                  const SizedBox(height: 16),
                                  Text(
                                    isRTL ? 'الرجاء اختيار كورس للبدء' : 'Please select a course to start',
                                    style: GoogleFonts.cairo(color: Colors.black54, fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            )
                          : Stack(
                              children: [
                                // Grid background
                                if (_sessionData?['grid_type'] == 'grid')
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _GridPainter(),
                                    ),
                                  ),
                                
                                // Drawing gesture / custom paint
                                Positioned.fill(
                                  child: GestureDetector(
                                    onPanStart: _canDraw ? (details) {
                                      final localPos = details.localPosition;
                                      setState(() {
                                        _currentPoints = [localPos];
                                      });
                                    } : null,
                                    onPanUpdate: _canDraw ? (details) {
                                      final localPos = details.localPosition;
                                      setState(() {
                                        _currentPoints.add(localPos);
                                      });
                                    } : null,
                                    onPanEnd: _canDraw ? (details) {
                                      if (_currentPoints.isNotEmpty) {
                                        final newStroke = _DrawingStroke(
                                          points: List.from(_currentPoints),
                                          color: _selectedColor,
                                          width: _selectedWidth,
                                        );
                                        setState(() {
                                          _strokes.add(newStroke);
                                          _currentPoints = [];
                                        });
                                        _syncStroke(newStroke);
                                      }
                                    } : null,
                                    child: CustomPaint(
                                      painter: _CanvasPainter(
                                        strokes: _strokes,
                                        activePoints: _currentPoints,
                                        activeColor: _selectedColor,
                                        activeWidth: _selectedWidth,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                ),
              ),
            ),
          ),

          // Tools Overlay / Bar
          if (_sessionData != null && _canDraw)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Color Palette & Clear Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: _palette.map((color) {
                          final isSelected = _selectedColor == color;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedColor = color),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  width: 2.5,
                                ),
                                boxShadow: isSelected
                                    ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10)]
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (_canPresent)
                        IconButton(
                          onPressed: _clearCanvas,
                          icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444)),
                          tooltip: isRTL ? 'مسح اللوحة' : 'Clear Canvas',
                        ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 16),
                  
                  // Width slider
                  Row(
                    children: [
                      const Icon(Icons.gesture_rounded, color: Colors.white54, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: primaryColor,
                            inactiveTrackColor: Colors.white10,
                            thumbColor: Colors.white,
                            overlayColor: primaryColor.withOpacity(0.2),
                          ),
                          child: Slider(
                            value: _selectedWidth,
                            min: 1.0,
                            max: 15.0,
                            onChanged: (val) => setState(() => _selectedWidth = val),
                          ),
                        ),
                      ),
                      Text(
                        '${_selectedWidth.toInt()}px',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DrawingStroke {
  final List<Offset> points;
  final Color color;
  final double width;
  _DrawingStroke({required this.points, required this.color, required this.width});
}

class _CanvasPainter extends CustomPainter {
  final List<_DrawingStroke> strokes;
  final List<Offset> activePoints;
  final Color activeColor;
  final double activeWidth;

  _CanvasPainter({
    required this.strokes,
    required this.activePoints,
    required this.activeColor,
    required this.activeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw past strokes
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      if (stroke.points.isNotEmpty) {
        path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }

    // Draw active stroke
    if (activePoints.isNotEmpty) {
      final paint = Paint()
        ..color = activeColor
        ..strokeWidth = activeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(activePoints.first.dx, activePoints.first.dy);
      for (int i = 1; i < activePoints.length; i++) {
        path.lineTo(activePoints[i].dx, activePoints[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.12)
      ..strokeWidth = 1.0;

    const double step = 20.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
