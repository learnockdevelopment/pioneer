import 'dart:io';

void main() {
  final baseDir = Directory('c:\\Users\\dell\\apps\\apps\\Learnock-DRM-');

  // 1. Rename all package imports in lib/ and test/
  print('Renaming package imports...');
  final libDir = Directory('${baseDir.path}/lib');
  if (libDir.existsSync()) {
    libDir.listSync(recursive: true).forEach((entity) {
      if (entity is File && entity.path.endsWith('.dart')) {
        var content = entity.readAsStringSync();
        if (content.contains('package:learnock_drm/')) {
          content = content.replaceAll('package:learnock_drm/', 'package:elmasa/');
          entity.writeAsStringSync(content);
          print('Updated imports in: ${entity.path}');
        }
      }
    });
  }

  final testDir = Directory('${baseDir.path}/test');
  if (testDir.existsSync()) {
    testDir.listSync(recursive: true).forEach((entity) {
      if (entity is File && entity.path.endsWith('.dart')) {
        var content = entity.readAsStringSync();
        if (content.contains('package:learnock_drm/')) {
          content = content.replaceAll('package:learnock_drm/', 'package:elmasa/');
          entity.writeAsStringSync(content);
          print('Updated imports in: ${entity.path}');
        }
      }
    });
  }

  // 2. Android Configs
  print('Updating Android...');
  final appGradle = File('${baseDir.path}/android/app/build.gradle');
  if (appGradle.existsSync()) {
    var content = appGradle.readAsStringSync();
    content = content.replaceAll('namespace = "com.omran_college.app"', 'namespace = "com.elprof.app"');
    content = content.replaceAll('applicationId = "com.omran_college.app"', 'applicationId = "com.elprof.app"');
    appGradle.writeAsStringSync(content);
  }

  final rootGradle = File('${baseDir.path}/android/build.gradle');
  if (rootGradle.existsSync()) {
    var content = rootGradle.readAsStringSync();
    content = content.replaceAll('namespace = "com.learnock.\${project.name.replace(\'-\', \'_\')}"', 'namespace = "com.elprof.\${project.name.replace(\'-\', \'_\')}"');
    rootGradle.writeAsStringSync(content);
  }

  final manifest = File('${baseDir.path}/android/app/src/main/AndroidManifest.xml');
  if (manifest.existsSync()) {
    var content = manifest.readAsStringSync();
    content = content.replaceAll('android:label="Learnock Drm"', 'android:label="AL Masa"');
    manifest.writeAsStringSync(content);
  }

  // Move MainActivity.kt
  final oldKotlinDir = Directory('${baseDir.path}/android/app/src/main/kotlin/com/learnock/learnock_drm');
  final newKotlinDir = Directory('${baseDir.path}/android/app/src/main/kotlin/com/elmasa/app');
  newKotlinDir.createSync(recursive: true);
  
  final newActivity = File('${newKotlinDir.path}/MainActivity.kt');
  newActivity.writeAsStringSync('package com.elprof.app
\n\nimport io.flutter.embedding.android.FlutterActivity\n\nclass MainActivity: FlutterActivity()\n');

  final oldActivity = File('${oldKotlinDir.path}/MainActivity.kt');
  if (oldActivity.existsSync()) {
    oldActivity.deleteSync();
    print('Deleted old MainActivity.kt');
  }

  // 3. iOS Configs
  print('Updating iOS...');
  final infoPlist = File('${baseDir.path}/ios/Runner/Info.plist');
  if (infoPlist.existsSync()) {
    var content = infoPlist.readAsStringSync();
    content = content.replaceAll('<string>Learnock Drm</string>', '<string>AL Masa</string>');
    infoPlist.writeAsStringSync(content);
  }

  final pbxprojIos = File('${baseDir.path}/ios/Runner.xcodeproj/project.pbxproj');
  if (pbxprojIos.existsSync()) {
    var content = pbxprojIos.readAsStringSync();
    content = content.replaceAll('PRODUCT_BUNDLE_IDENTIFIER = com.learnock.learnockDrm;', 'PRODUCT_BUNDLE_IDENTIFIER = com.elprof.app
;');
    content = content.replaceAll('INFOPLIST_KEY_CFBundleDisplayName = "Learnock DRM";', 'INFOPLIST_KEY_CFBundleDisplayName = "AL Masa";');
    pbxprojIos.writeAsStringSync(content);
  }

  // 4. macOS Configs
  print('Updating macOS...');
  final appInfo = File('${baseDir.path}/macos/Runner/Configs/AppInfo.xcconfig');
  if (appInfo.existsSync()) {
    var content = appInfo.readAsStringSync();
    content = content.replaceAll('PRODUCT_NAME = learnock_drm', 'PRODUCT_NAME = elmasa');
    content = content.replaceAll('PRODUCT_BUNDLE_IDENTIFIER = com.learnock.learnockDrm', 'PRODUCT_BUNDLE_IDENTIFIER = com.elprof.app
');
    content = content.replaceAll('PRODUCT_COPYRIGHT = Copyright © 2026 com.learnock. All rights reserved.', 'PRODUCT_COPYRIGHT = Copyright © 2026 com.elprof. All rights reserved.');
    appInfo.writeAsStringSync(content);
  }

  final pbxprojMacos = File('${baseDir.path}/macos/Runner.xcodeproj/project.pbxproj');
  if (pbxprojMacos.existsSync()) {
    var content = pbxprojMacos.readAsStringSync();
    content = content.replaceAll('PRODUCT_BUNDLE_IDENTIFIER = com.learnock.learnockDrm.RunnerTests;', 'PRODUCT_BUNDLE_IDENTIFIER = com.elprof.app
.RunnerTests;');
    content = content.replaceAll('learnock_drm.app', 'elmasa.app');
    content = content.replaceAll('learnock_drm', 'elmasa');
    pbxprojMacos.writeAsStringSync(content);
  }

  // 5. Windows Configs
  print('Updating Windows...');
  final cmakeWindows = File('${baseDir.path}/windows/CMakeLists.txt');
  if (cmakeWindows.existsSync()) {
    var content = cmakeWindows.readAsStringSync();
    content = content.replaceAll('project(learnock_drm LANGUAGES CXX)', 'project(elmasa LANGUAGES CXX)');
    content = content.replaceAll('set(BINARY_NAME "learnock_drm")', 'set(BINARY_NAME "elmasa")');
    cmakeWindows.writeAsStringSync(content);
  }

  final mainCpp = File('${baseDir.path}/windows/runner/main.cpp');
  if (mainCpp.existsSync()) {
    var content = mainCpp.readAsStringSync();
    content = content.replaceAll('L"learnock_drm"', 'L"AL Masa"');
    mainCpp.writeAsStringSync(content);
  }

  final runnerRc = File('${baseDir.path}/windows/runner/Runner.rc');
  if (runnerRc.existsSync()) {
    var content = runnerRc.readAsStringSync();
    content = content.replaceAll('"CompanyName", "com.learnock"', '"CompanyName", "com.elprof"');
    content = content.replaceAll('"FileDescription", "learnock_drm"', '"FileDescription", "elmasa"');
    content = content.replaceAll('"InternalName", "learnock_drm"', '"InternalName", "elmasa"');
    content = content.replaceAll('"LegalCopyright", "Copyright (C) 2026 com.learnock. All rights reserved."', '"LegalCopyright", "Copyright (C) 2026 com.elprof. All rights reserved."');
    content = content.replaceAll('"OriginalFilename", "learnock_drm.exe"', '"OriginalFilename", "elmasa.exe"');
    content = content.replaceAll('"ProductName", "learnock_drm"', '"ProductName", "elmasa"');
    runnerRc.writeAsStringSync(content);
  }

  // 6. Linux Configs
  print('Updating Linux...');
  final cmakeLinux = File('${baseDir.path}/linux/CMakeLists.txt');
  if (cmakeLinux.existsSync()) {
    var content = cmakeLinux.readAsStringSync();
    content = content.replaceAll('set(BINARY_NAME "learnock_drm")', 'set(BINARY_NAME "elmasa")');
    content = content.replaceAll('set(APPLICATION_ID "com.omran_college.app\\n")', 'set(APPLICATION_ID "com.elprof.app
\\n")');
    content = content.replaceAll('set(APPLICATION_ID "com.omran_college.app")', 'set(APPLICATION_ID "com.elprof.app")');
    cmakeLinux.writeAsStringSync(content);
  }

  final myAppCc = File('${baseDir.path}/linux/my_application.cc');
  if (myAppCc.existsSync()) {
    var content = myAppCc.readAsStringSync();
    content = content.replaceAll('"learnock_drm"', '"AL Masa"');
    myAppCc.writeAsStringSync(content);
  }

  // 7. Translations & specific strings
  print('Updating translations and encryption keys...');
  final enJson = File('${baseDir.path}/assets/lang/en.json');
  if (enJson.existsSync()) {
    var content = enJson.readAsStringSync();
    content = content.replaceAll('Learnock Student', 'elmasa Student');
    content = content.replaceAll('Welcome to Learnock', 'Welcome to AL Masa');
    content = content.replaceAll('© 2026 Learnock LMS', '© 2026 elmasa LMS');
    content = content.replaceAll('LEARNOCK DRM ENGINE v4.0', 'elmasa DRM ENGINE v4.0');
    content = content.replaceAll('academy.Learnock.app', 'academy.elmasa.app');
    enJson.writeAsStringSync(content);
  }

  final arJson = File('${baseDir.path}/assets/lang/ar.json');
  if (arJson.existsSync()) {
    var content = arJson.readAsStringSync();
    content = content.replaceAll('طالب Learnock', 'طالب الماسة');
    content = content.replaceAll('مرحباً بك في Learnock', 'مرحباً بك في أكاديمية الماسة');
    content = content.replaceAll('© 2026 Learnock LMS', '© 2026 elmasa LMS');
    content = content.replaceAll('محرك حماية LEARNOCK v4.0', 'محرك حماية elmasa v4.0');
    content = content.replaceAll('academy.Learnock.app', 'academy.elmasa.app');
    arJson.writeAsStringSync(content);
  }

  final encryptService = File('${baseDir.path}/lib/services/encryption_service.dart');
  if (encryptService.existsSync()) {
    var content = encryptService.readAsStringSync();
    content = content.replaceAll('lEaRnOcKdRmSeCuReKeY2026_03_29_32', 'elmasaApPsEcUrEkEy2026_03_29_32');
    encryptService.writeAsStringSync(content);
  }

  final onboardScreen = File('${baseDir.path}/lib/screens/onboarding_screen.dart');
  if (onboardScreen.existsSync()) {
    var content = onboardScreen.readAsStringSync();
    content = content.replaceAll('academy.Learnock.app', 'academy.elmasa.app');
    onboardScreen.writeAsStringSync(content);
  }

  final matViewer = File('${baseDir.path}/lib/screens/material_viewer_screen.dart');
  if (matViewer.existsSync()) {
    var content = matViewer.readAsStringSync();
    content = content.replaceAll('https://learnock.com/', 'https://elmasa.com/');
    content = content.replaceAll('https://learnock.com', 'https://elmasa.com');
    matViewer.writeAsStringSync(content);
  }

  final homeScreen = File('${baseDir.path}/lib/screens/home_screen.dart');
  if (homeScreen.existsSync()) {
    var content = homeScreen.readAsStringSync();
    content = content.replaceAll('"LEARNOCK"', '"elmasa"');
    content = content.replaceAll('"مدعوم بنظام ليرنوك الذكي™"', '"مدعوم بنظام الماسة الذكي™"');
    homeScreen.writeAsStringSync(content);
  }

  // 8. Fix Logo Tinting
  print('Fixing logo tint/color issues...');
  final premiumLoader = File('${baseDir.path}/lib/widgets/premium_loader.dart');
  if (premiumLoader.existsSync()) {
    var content = premiumLoader.readAsStringSync();
    content = content.replaceAll(
      "Image.asset('assets/logo.png', color: primary, fit: BoxFit.contain, errorBuilder: (c,e,s) => Icon(Icons.school_rounded, color: primary, size: widget.size * 0.26))",
      "Image.asset('assets/logo.png', fit: BoxFit.contain, errorBuilder: (c,e,s) => Icon(Icons.school_rounded, color: primary, size: widget.size * 0.26))"
    );
    premiumLoader.writeAsStringSync(content);
  }

  final splashScreen = File('${baseDir.path}/lib/screens/splash_screen.dart');
  if (splashScreen.existsSync()) {
    var content = splashScreen.readAsStringSync();
    content = content.replaceAll(
      "child: Image.asset('assets/logo.png', width: 80, height: 80, color: Colors.white),",
      "child: Image.asset('assets/logo.png', width: 80, height: 80),"
    );
    splashScreen.writeAsStringSync(content);
  }

  final onboardingScreen = File('${baseDir.path}/lib/screens/onboarding_screen.dart');
  if (onboardingScreen.existsSync()) {
    var content = onboardingScreen.readAsStringSync();
    content = content.replaceAll(
      "child: Image.asset('assets/logo.png', height: 64, color: onSurface),",
      "child: Image.asset('assets/logo.png', height: 64),"
    );
    onboardingScreen.writeAsStringSync(content);
  }

  print('Successfully renamed project and fixed logo color issues!');
}
