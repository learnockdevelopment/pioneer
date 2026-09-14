import 'package:flutter/material.dart';
import 'package:elmasa/services/security_service.dart';
import 'package:provider/provider.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'package:elmasa/providers/workspace_provider.dart';
import 'package:elmasa/providers/language_provider.dart';
import 'package:elmasa/screens/splash_screen.dart';
import 'package:elmasa/screens/onboarding_screen.dart';
import 'package:elmasa/screens/dashboard_screen.dart';
import 'package:elmasa/screens/material_viewer_screen.dart';
import 'package:elmasa/screens/course_detail_screen.dart';
import 'package:elmasa/screens/profile_screen.dart';
import 'package:elmasa/screens/faqs_screen.dart';
import 'package:elmasa/screens/courses_screen.dart';
import 'package:elmasa/screens/highlights_screen.dart';
import 'package:elmasa/screens/favorites_screen.dart';
import 'package:elmasa/screens/transactions_screen.dart';
import 'package:elmasa/screens/wallet_screen.dart';
import 'package:elmasa/screens/register_screen.dart';
import 'package:elmasa/screens/profile_setup_screen.dart';
import 'package:elmasa/providers/theme_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:elmasa/screens/banned_screen.dart';
import 'package:elmasa/screens/whiteboard_screen.dart';
import 'package:elmasa/widgets/watermark_overlay.dart';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:elmasa/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  if (!kDebugMode && !SecurityService.bypassSecurityChecks && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android)) {
    try {
      await NoScreenshot.instance.screenshotOff();
    } catch (e) {
      debugPrint('Security Error: $e');
    }
  }

  final themeProvider = ThemeProvider();
  await themeProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WorkspaceProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => themeProvider),
      ],
      child: const DerasyApp(),
    ),
  );
}

// ─── GLOBAL SCREENSHOT DETECTION WRAPPER ──────────────────────────────────────
// Wraps the entire app — any screenshot or recording detected anywhere
// is automatically reported via the security API.
class _DrmSecurityObserver extends StatefulWidget {
  final Widget child;
  const _DrmSecurityObserver({required this.child});
  @override
  State<_DrmSecurityObserver> createState() => _DrmSecurityObserverState();
}

class _DrmSecurityObserverState extends State<_DrmSecurityObserver> {
  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android) {
      NoScreenshot.instance.onScreenshotDetected = (_) => _report('screenshot_taken');
      NoScreenshot.instance.onScreenRecordingStarted = (_) => _report('screen_recording_started');
      NoScreenshot.instance.onScreenRecordingStopped = (_) => _report('screen_recording_stopped');
      NoScreenshot.instance.startCallbacks();
    }
  }

  void _report(String incidentType) {
    try {
      final wp = Provider.of<WorkspaceProvider>(context, listen: false);
      if (wp.activeWorkspace == null) return; // not logged in yet
      wp.reportSecurityAlert(incidentType, description: 'Global app capture attempt');
      debugPrint('🔒 [GLOBAL] Security event: $incidentType');
    } catch (e) {
      debugPrint('⚠️ Could not report security event: $e');
    }
  }

  @override
  void dispose() {
    if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android) {
      NoScreenshot.instance.removeAllCallbacks();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class DerasyApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  const DerasyApp({super.key}); 

  @override
  Widget build(BuildContext context) {
    return Consumer3<LanguageProvider, ThemeProvider, WorkspaceProvider>(
      builder: (context, lang, theme, wp, child) {
        final lightThemeData = theme.lightThemeData.copyWith(
          textTheme: GoogleFonts.rubikTextTheme(theme.lightThemeData.textTheme),
        );
        final darkThemeData = theme.darkThemeData.copyWith(
          textTheme: GoogleFonts.rubikTextTheme(theme.darkThemeData.textTheme),
        );
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: wp.appName,
          debugShowCheckedModeBanner: false,
          locale: lang.currentLocale,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('ar'),
          ],
          theme: lightThemeData,
          darkTheme: darkThemeData,
          themeMode: theme.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          initialRoute: '/',
          builder: (context, child) => Stack(
            children: [
              _DrmSecurityObserver(child: child ?? const SizedBox()),
              const WatermarkOverlay(isContentOnly: false),
            ],
          ),
          routes: {
            '/': (context) => const SplashScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
            '/register': (context) => const RegisterScreen(),
            '/profile-setup': (context) => const ProfileSetupScreen(),
            '/dashboard': (context) => const DashboardScreen(),
            '/profile': (context) => const ProfileScreen(),
            '/faqs': (context) => const FaqsScreen(),
            '/all-courses': (context) => const CoursesScreen(),
            '/favorites': (context) => const FavoritesScreen(),
            '/transactions': (context) => const TransactionsScreen(),
            '/highlights': (context) => const HighlightsScreen(),
            '/wallet': (context) => const WalletScreen(),
            '/banned': (context) => const BannedScreen(),
            '/whiteboard': (context) => const WhiteboardScreen(),
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/course') { 
              final id = settings.arguments as int;
              return MaterialPageRoute(builder: (context) => CourseDetailScreen(courseId: id));
            }
            if (settings.name == '/material') {
              final args = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(builder: (context) => MaterialViewerScreen(
                material: args['material'],
                courseId: args['courseId'],
                forceLandscape: args['forceLandscape'] ?? false,
                nextMaterial: args['nextMaterial'],
              ));
            }
            return null;
          },
        );
      },
    );
  }
}

