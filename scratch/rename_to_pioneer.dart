import 'dart:io';

void main() {
  final baseDir = Directory.current;
  print('Running renaming script in ${baseDir.path}...');

  // 1. Update pubspec.yaml
  final pubspecFile = File('${baseDir.path}/pubspec.yaml');
  if (pubspecFile.existsSync()) {
    var content = pubspecFile.readAsStringSync();
    content = content.replaceFirst(RegExp(r'name:\s+\w+'), 'name: pioneer');
    content = content.replaceFirst(RegExp(r'description:\s+".*"'), 'description: "Pioneer Academy Learning Platform"');
    content = content.replaceFirst(RegExp(r'version:\s+.*'), 'version: 1.0.0+1');
    pubspecFile.writeAsStringSync(content);
    print('Updated pubspec.yaml');
  }

  // 2. Rename all package imports in lib/ and test/
  print('Renaming package imports...');
  void replaceImportsInDir(Directory dir) {
    if (!dir.existsSync()) return;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        var content = entity.readAsStringSync();
        bool changed = false;
        if (content.contains('package:elmasa/')) {
          content = content.replaceAll('package:elmasa/', 'package:pioneer/');
          changed = true;
        }
        if (content.contains('package:learnock_drm/')) {
          content = content.replaceAll('package:learnock_drm/', 'package:pioneer/');
          changed = true;
        }
        if (changed) {
          entity.writeAsStringSync(content);
          print('Updated imports in: ${entity.path}');
        }
      }
    }
  }

  replaceImportsInDir(Directory('${baseDir.path}/lib'));
  replaceImportsInDir(Directory('${baseDir.path}/test'));

  // 3. Android Configs
  print('Updating Android...');
  final appGradle = File('${baseDir.path}/android/app/build.gradle');
  if (appGradle.existsSync()) {
    var content = appGradle.readAsStringSync();
    content = content.replaceAll(RegExp(r'namespace\s*=\s*"[^"]+"'), 'namespace = "com.pioneeracademy.app"');
    content = content.replaceAll(RegExp(r'applicationId\s+("[^"]+"|\S+)'), 'applicationId "com.pioneeracademy.app"');
    content = content.replaceAll(RegExp(r'versionCode\s*=\s*\d+'), 'versionCode = 1');
    content = content.replaceAll(RegExp(r'versionName\s*=\s*"[^"]+"'), 'versionName = "1.0.0"');
    content = content.replaceAll('flutterVersionCode = "92"', 'flutterVersionCode = "1"');
    content = content.replaceAll('flutterVersionName = "92"', 'flutterVersionName = "1.0.0"');
    appGradle.writeAsStringSync(content);
    print('Updated android/app/build.gradle');
  }

  final rootGradle = File('${baseDir.path}/android/build.gradle');
  if (rootGradle.existsSync()) {
    var content = rootGradle.readAsStringSync();
    content = content.replaceAll('namespace = "com.elprof.\${project.name.replace(\'-\', \'_\')}"', 'namespace = "com.pioneer.\${project.name.replace(\'-\', \'_\')}"');
    content = content.replaceAll('namespace = "com.learnock.\${project.name.replace(\'-\', \'_\')}"', 'namespace = "com.pioneer.\${project.name.replace(\'-\', \'_\')}"');
    rootGradle.writeAsStringSync(content);
    print('Updated android/build.gradle');
  }

  final manifest = File('${baseDir.path}/android/app/src/main/AndroidManifest.xml');
  if (manifest.existsSync()) {
    var content = manifest.readAsStringSync();
    content = content.replaceAll(RegExp(r'android:label="[^"]+"'), 'android:label="Pioneer Academy"');
    manifest.writeAsStringSync(content);
    print('Updated AndroidManifest.xml');
  }

  // Move MainActivity.kt to com/pioneer/app/MainActivity.kt
  final kotlinBase = Directory('${baseDir.path}/android/app/src/main/kotlin');
  final targetKotlinDir = Directory('${kotlinBase.path}/com/pioneer/app');
  targetKotlinDir.createSync(recursive: true);
  final newActivity = File('${targetKotlinDir.path}/MainActivity.kt');
  newActivity.writeAsStringSync('package com.pioneeracademy.app\n\nimport io.flutter.embedding.android.FlutterActivity\n\nclass MainActivity: FlutterActivity()\n');
  print('Wrote new MainActivity.kt in ${targetKotlinDir.path}');

  // Remove old kotlin package folders if different
  if (kotlinBase.existsSync()) {
    for (final entity in Directory('${kotlinBase.path}/com').listSync()) {
      if (entity is Directory && !entity.path.endsWith('pioneer')) {
        try {
          entity.deleteSync(recursive: true);
          print('Cleaned up old kotlin directory: ${entity.path}');
        } catch (e) {
          print('Error cleaning up ${entity.path}: $e');
        }
      }
    }
  }

  // 4. iOS Configs
  print('Updating iOS...');
  final infoPlist = File('${baseDir.path}/ios/Runner/Info.plist');
  if (infoPlist.existsSync()) {
    var content = infoPlist.readAsStringSync();
    content = content.replaceAll(RegExp(r'<key>CFBundleDisplayName<\/key>\s*<string>[^<]*<\/string>'), '<key>CFBundleDisplayName</key>\n\t<string>Pioneer Academy</string>');
    content = content.replaceAll(RegExp(r'<key>CFBundleName<\/key>\s*<string>[^<]*<\/string>'), '<key>CFBundleName</key>\n\t<string>Pioneer Academy</string>');
    infoPlist.writeAsStringSync(content);
    print('Updated ios/Runner/Info.plist');
  }

  final pbxprojIos = File('${baseDir.path}/ios/Runner.xcodeproj/project.pbxproj');
  if (pbxprojIos.existsSync()) {
    var content = pbxprojIos.readAsStringSync();
    content = content.replaceAll(RegExp(r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*com\.[a-zA-Z0-9_\.]*;'), 'PRODUCT_BUNDLE_IDENTIFIER = com.pioneeracademy.app;');
    content = content.replaceAll(RegExp(r'INFOPLIST_KEY_CFBundleDisplayName\s*=\s*"[^"]*";'), 'INFOPLIST_KEY_CFBundleDisplayName = "Pioneer Academy";');
    pbxprojIos.writeAsStringSync(content);
    print('Updated ios/Runner.xcodeproj/project.pbxproj');
  }

  // 5. macOS Configs
  print('Updating macOS...');
  final appInfo = File('${baseDir.path}/macos/Runner/Configs/AppInfo.xcconfig');
  if (appInfo.existsSync()) {
    var content = appInfo.readAsStringSync();
    content = content.replaceAll(RegExp(r'PRODUCT_NAME\s*=\s*\w+'), 'PRODUCT_NAME = pioneer_academy');
    content = content.replaceAll(RegExp(r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*com\.[a-zA-Z0-9_\.]+'), 'PRODUCT_BUNDLE_IDENTIFIER = com.pioneeracademy.app');
    content = content.replaceAll(RegExp(r'PRODUCT_COPYRIGHT\s*=\s*Copyright © 2026 [^\.]*\. All rights reserved\.'), 'PRODUCT_COPYRIGHT = Copyright © 2026 com.pioneer. All rights reserved.');
    appInfo.writeAsStringSync(content);
    print('Updated macos/Runner/Configs/AppInfo.xcconfig');
  }

  final pbxprojMacos = File('${baseDir.path}/macos/Runner.xcodeproj/project.pbxproj');
  if (pbxprojMacos.existsSync()) {
    var content = pbxprojMacos.readAsStringSync();
    content = content.replaceAll(RegExp(r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*com\.[a-zA-Z0-9_\.]*\.RunnerTests;'), 'PRODUCT_BUNDLE_IDENTIFIER = com.pioneeracademy.app.RunnerTests;');
    content = content.replaceAll(RegExp(r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*com\.[a-zA-Z0-9_\.]*;'), 'PRODUCT_BUNDLE_IDENTIFIER = com.pioneeracademy.app;');
    pbxprojMacos.writeAsStringSync(content);
    print('Updated macos/Runner.xcodeproj/project.pbxproj');
  }

  // 6. Windows Configs
  print('Updating Windows...');
  final cmakeWindows = File('${baseDir.path}/windows/CMakeLists.txt');
  if (cmakeWindows.existsSync()) {
    var content = cmakeWindows.readAsStringSync();
    content = content.replaceAll(RegExp(r'project\(\w+\s+LANGUAGES CXX\)'), 'project(pioneer_academy LANGUAGES CXX)');
    content = content.replaceAll(RegExp(r'set\(BINARY_NAME\s+"[^"]+"\s*\)'), 'set(BINARY_NAME "pioneer_academy")');
    cmakeWindows.writeAsStringSync(content);
    print('Updated windows/CMakeLists.txt');
  }

  final mainCpp = File('${baseDir.path}/windows/runner/main.cpp');
  if (mainCpp.existsSync()) {
    var content = mainCpp.readAsStringSync();
    content = content.replaceAll(RegExp(r'window\.Create\(L"[^"]*"'), 'window.Create(L"Pioneer Academy"');
    mainCpp.writeAsStringSync(content);
    print('Updated windows/runner/main.cpp');
  }

  final runnerRc = File('${baseDir.path}/windows/runner/Runner.rc');
  if (runnerRc.existsSync()) {
    var content = runnerRc.readAsStringSync();
    content = content.replaceAll(RegExp(r'"CompanyName",\s*"[^"]*"'), '"CompanyName", "com.pioneer"');
    content = content.replaceAll(RegExp(r'"FileDescription",\s*"[^"]*"'), '"FileDescription", "pioneer_academy"');
    content = content.replaceAll(RegExp(r'"InternalName",\s*"[^"]*"'), '"InternalName", "pioneer_academy"');
    content = content.replaceAll(RegExp(r'"LegalCopyright",\s*"Copyright \(C\) 2026 [^"]*"'), '"LegalCopyright", "Copyright (C) 2026 com.pioneer. All rights reserved."');
    content = content.replaceAll(RegExp(r'"OriginalFilename",\s*"[^"]*"'), '"OriginalFilename", "pioneer_academy.exe"');
    content = content.replaceAll(RegExp(r'"ProductName",\s*"[^"]*"'), '"ProductName", "Pioneer Academy"');
    runnerRc.writeAsStringSync(content);
    print('Updated windows/runner/Runner.rc');
  }

  // 7. Linux Configs
  print('Updating Linux...');
  final cmakeLinux = File('${baseDir.path}/linux/CMakeLists.txt');
  if (cmakeLinux.existsSync()) {
    var content = cmakeLinux.readAsStringSync();
    content = content.replaceAll(RegExp(r'set\(BINARY_NAME\s+"[^"]+"\s*\)'), 'set(BINARY_NAME "pioneer_academy")');
    content = content.replaceAll(RegExp(r'set\(APPLICATION_ID\s+"[^"]+"\s*\)'), 'set(APPLICATION_ID "com.pioneeracademy.app")');
    cmakeLinux.writeAsStringSync(content);
    print('Updated linux/CMakeLists.txt');
  }

  final myAppCc = File('${baseDir.path}/linux/my_application.cc');
  if (myAppCc.existsSync()) {
    var content = myAppCc.readAsStringSync();
    content = content.replaceAll(RegExp(r'gtk_header_bar_set_title\(header_bar,\s*"[^"]*"\);'), 'gtk_header_bar_set_title(header_bar, "Pioneer Academy");');
    content = content.replaceAll(RegExp(r'gtk_window_set_title\(window,\s*"[^"]*"\);'), 'gtk_window_set_title(window, "Pioneer Academy");');
    myAppCc.writeAsStringSync(content);
    print('Updated linux/my_application.cc');
  }

  // 8. Web Configs
  print('Updating Web...');
  final webIndex = File('${baseDir.path}/web/index.html');
  if (webIndex.existsSync()) {
    var content = webIndex.readAsStringSync();
    content = content.replaceAll(RegExp(r'<title>[^<]*<\/title>'), '<title>Pioneer Academy</title>');
    content = content.replaceAll(RegExp(r'<meta name="apple-mobile-web-app-title"\s+content="[^"]*">'), '<meta name="apple-mobile-web-app-title" content="Pioneer Academy">');
    webIndex.writeAsStringSync(content);
    print('Updated web/index.html');
  }

  final webManifest = File('${baseDir.path}/web/manifest.json');
  if (webManifest.existsSync()) {
    var content = webManifest.readAsStringSync();
    content = content.replaceAll(RegExp(r'"name":\s*"[^"]*"'), '"name": "Pioneer Academy"');
    content = content.replaceAll(RegExp(r'"short_name":\s*"[^"]*"'), '"short_name": "Pioneer Academy"');
    webManifest.writeAsStringSync(content);
    print('Updated web/manifest.json');
  }

  // 9. Update flutter_launcher_icons.yaml
  final launcherConfig = File('${baseDir.path}/flutter_launcher_icons.yaml');
  if (launcherConfig.existsSync()) {
    launcherConfig.writeAsStringSync('''flutter_launcher_icons:
  image_path: "assets/logo.png"

  android: "launcher_icon"
  min_sdk_android: 21 
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/maskable-icon.png"

  ios: true
  remove_alpha_ios: true

  web:
    generate: true
    image_path: "assets/logo.png"
    background_color: "#0175C2"
    theme_color: "#0175C2"

  windows:
    generate: true
    image_path: "assets/logo.png"
    icon_size: 48

  macos:
    generate: true
    image_path: "assets/logo.png"
''');
    print('Updated flutter_launcher_icons.yaml');
  }

  print('All project renaming and configuration steps completed!');
}
