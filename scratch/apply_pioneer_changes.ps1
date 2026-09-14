$baseDir = "f:\learnock\pioneer"
Write-Host "Updating Pioneer Academy configurations in $baseDir..."

# 1. Update pubspec.yaml
$pubspecPath = "$baseDir\pubspec.yaml"
if (Test-Path $pubspecPath) {
    $content = Get-Content -Raw -Encoding UTF8 $pubspecPath
    $content = [regex]::Replace($content, '(?m)^name:\s+\w+', 'name: pioneer')
    $content = [regex]::Replace($content, '(?m)^description:\s+".*"', 'description: "Pioneer Academy Learning Platform"')
    $content = [regex]::Replace($content, '(?m)^version:\s+.*', 'version: 1.0.0+1')
    [IO.File]::WriteAllText($pubspecPath, $content, [Text.Encoding]::UTF8)
    Write-Host "Updated pubspec.yaml"
}

# 2. Update imports in lib/ and test/
$dartFiles = Get-ChildItem -Path "$baseDir\lib", "$baseDir\test" -Filter "*.dart" -Recurse -ErrorAction SilentlyContinue
foreach ($file in $dartFiles) {
    $content = [IO.File]::ReadAllText($file.FullName, [Text.Encoding]::UTF8)
    $modified = $false
    if ($content.Contains("package:elmasa/")) {
        $content = $content.Replace("package:elmasa/", "package:pioneer/")
        $modified = $true
    }
    if ($content.Contains("package:learnock_drm/")) {
        $content = $content.Replace("package:learnock_drm/", "package:pioneer/")
        $modified = $true
    }
    if ($modified) {
        [IO.File]::WriteAllText($file.FullName, $content, [Text.Encoding]::UTF8)
        Write-Host "Updated package imports in $($file.FullName)"
    }
}

# 3. Android build.gradle & Manifest
$appGradlePath = "$baseDir\android\app\build.gradle"
if (Test-Path $appGradlePath) {
    $content = [IO.File]::ReadAllText($appGradlePath, [Text.Encoding]::UTF8)
    $content = [regex]::Replace($content, 'namespace\s*=\s*"[^"]+"', 'namespace = "com.pioneer.app"')
    $content = [regex]::Replace($content, 'applicationId\s+("[^"]+"|\S+)', 'applicationId "com.pioneer.app"')
    $content = [regex]::Replace($content, 'versionCode\s*=\s*\d+', 'versionCode = 1')
    $content = [regex]::Replace($content, 'versionName\s*=\s*"[^"]+"', 'versionName = "1.0.0"')
    $content = $content.Replace('flutterVersionCode = "92"', 'flutterVersionCode = "1"')
    $content = $content.Replace('flutterVersionName = "92"', 'flutterVersionName = "1.0.0"')
    [IO.File]::WriteAllText($appGradlePath, $content, [Text.Encoding]::UTF8)
    Write-Host "Updated android/app/build.gradle"
}

$rootGradlePath = "$baseDir\android\build.gradle"
if (Test-Path $rootGradlePath) {
    $content = [IO.File]::ReadAllText($rootGradlePath, [Text.Encoding]::UTF8)
    $content = $content.Replace('namespace = "com.elprof.${project.name.replace(''-'', ''_'')}"', 'namespace = "com.pioneer.${project.name.replace(''-'', ''_'')}"')
    $content = $content.Replace('namespace = "com.learnock.${project.name.replace(''-'', ''_'')}"', 'namespace = "com.pioneer.${project.name.replace(''-'', ''_'')}"')
    [IO.File]::WriteAllText($rootGradlePath, $content, [Text.Encoding]::UTF8)
    Write-Host "Updated android/build.gradle"
}

$manifestPath = "$baseDir\android\app\src\main\AndroidManifest.xml"
if (Test-Path $manifestPath) {
    $content = [IO.File]::ReadAllText($manifestPath, [Text.Encoding]::UTF8)
    $content = [regex]::Replace($content, 'android:label="[^"]+"', 'android:label="Pioneer Academy"')
    [IO.File]::WriteAllText($manifestPath, $content, [Text.Encoding]::UTF8)
    Write-Host "Updated AndroidManifest.xml"
}

# Move MainActivity.kt
$pioneerKotlinDir = "$baseDir\android\app\src\main\kotlin\com\pioneer\app"
if (-not (Test-Path $pioneerKotlinDir)) {
    New-Item -ItemType Directory -Path $pioneerKotlinDir -Force | Out-Null
}
$mainActivityContent = @"
package com.pioneer.app

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity()
"@
[IO.File]::WriteAllText("$pioneerKotlinDir\MainActivity.kt", $mainActivityContent, [Text.Encoding]::UTF8)
Write-Host "Created $pioneerKotlinDir\MainActivity.kt"

# 4. iOS Info.plist & pbxproj
$infoPlistPath = "$baseDir\ios\Runner\Info.plist"
if (Test-Path $infoPlistPath) {
    $content = [IO.File]::ReadAllText($infoPlistPath, [Text.Encoding]::UTF8)
    $content = [regex]::Replace($content, '(?s)<key>CFBundleDisplayName<\/key>\s*<string>[^<]*<\/string>', "<key>CFBundleDisplayName</key>`n`t<string>Pioneer Academy</string>")
    $content = [regex]::Replace($content, '(?s)<key>CFBundleName<\/key>\s*<string>[^<]*<\/string>', "<key>CFBundleName</key>`n`t<string>Pioneer Academy</string>")
    [IO.File]::WriteAllText($infoPlistPath, $content, [Text.Encoding]::UTF8)
    Write-Host "Updated ios/Runner/Info.plist"
}

$pbxprojIosPath = "$baseDir\ios\Runner.xcodeproj\project.pbxproj"
if (Test-Path $pbxprojIosPath) {
    $content = [IO.File]::ReadAllText($pbxprojIosPath, [Text.Encoding]::UTF8)
    $content = [regex]::Replace($content, 'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*com\.[a-zA-Z0-9_\.]*;', 'PRODUCT_BUNDLE_IDENTIFIER = com.pioneer.app;')
    $content = [regex]::Replace($content, 'INFOPLIST_KEY_CFBundleDisplayName\s*=\s*"[^"]*";', 'INFOPLIST_KEY_CFBundleDisplayName = "Pioneer Academy";')
    [IO.File]::WriteAllText($pbxprojIosPath, $content, [Text.Encoding]::UTF8)
    Write-Host "Updated ios/Runner.xcodeproj/project.pbxproj"
}

# 5. macOS AppInfo.xcconfig & pbxproj
$appInfoPath = "$baseDir\macos\Runner\Configs\AppInfo.xcconfig"
if (Test-Path $appInfoPath) {
    $content = [IO.File]::ReadAllText($appInfoPath, [Text.Encoding]::UTF8)
    $content = [regex]::Replace($content, 'PRODUCT_NAME\s*=\s*\w+', 'PRODUCT_NAME = pioneer_academy')
    $content = [regex]::Replace($content, 'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*com\.[a-zA-Z0-9_\.]+', 'PRODUCT_BUNDLE_IDENTIFIER = com.pioneer.app')
    $content = [regex]::Replace($content, 'PRODUCT_COPYRIGHT\s*=\s*Copyright © 2026 [^\.]*\. All rights reserved\.', 'PRODUCT_COPYRIGHT = Copyright © 2026 com.pioneer. All rights reserved.')
    [IO.File]::WriteAllText($appInfoPath, $content, [Text.Encoding]::UTF8)
    Write-Host "Updated macos/Runner/Configs/AppInfo.xcconfig"
}

$pbxprojMacosPath = "$baseDir\macos\Runner.xcodeproj\project.pbxproj"
if (Test-Path $pbxprojMacosPath) {
    $content = [IO.File]::ReadAllText($pbxprojMacosPath, [Text.Encoding]::UTF8)
    $content = [regex]::Replace($content, 'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*com\.[a-zA-Z0-9_\.]*\.RunnerTests;', 'PRODUCT_BUNDLE_IDENTIFIER = com.pioneer.app.RunnerTests;')
    $content = [regex]::Replace($content, 'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*com\.[a-zA-Z0-9_\.]*;', 'PRODUCT_BUNDLE_IDENTIFIER = com.pioneer.app;')
    [IO.File]::WriteAllText($pbxprojMacosPath, $content, [Text.Encoding]::UTF8)
    Write-Host "Updated macos/Runner.xcodeproj/project.pbxproj"
}

# 6. Windows
$cmakeWinPath = "$baseDir\windows\CMakeLists.txt"
if (Test-Path $cmakeWinPath) {
    $content = [IO.File]::ReadAllText($cmakeWinPath, [Text.Encoding]::UTF8)
    $content = [regex]::Replace($content, 'project\(\w+\s+LANGUAGES CXX\)', 'project(pioneer_academy LANGUAGES CXX)')
    $content = [regex]::Replace($content, 'set\(BINARY_NAME\s+"[^"]+"\s*\)', 'set(BINARY_NAME "pioneer_academy")')
    [IO.File]::WriteAllText($cmakeWinPath, $content, [Text.Encoding]::UTF8)
    Write-Host "Updated windows/CMakeLists.txt"
}

$mainCppPath = "$baseDir\windows\runner\main.cpp"
if (Test-Path $mainCppPath) {
    $content = [IO.File]::ReadAllText($mainCppPath, [Text.Encoding]::UTF8)
    $content = [regex]::Replace($content, 'window\.Create\(L"[^"]*"', 'window.Create(L"Pioneer Academy"')
    [IO.File]::WriteAllText($mainCppPath, $content, [Text.Encoding]::UTF8)
    Write-Host "Updated windows/runner/main.cpp"
}

$runnerRcPath = "$baseDir\windows\runner\Runner.rc"
if (Test-Path $runnerRcPath) {
    $content = [IO.File]::ReadAllText($runnerRcPath, [Text.Encoding]::UTF8)
    $content = [regex]::Replace($content, '"CompanyName",\s*"[^"]*"', '"CompanyName", "com.pioneer"')
    $content = [regex]::Replace($content, '"FileDescription",\s*"[^"]*"', '"FileDescription", "pioneer_academy"')
    $content = [regex]::Replace($content, '"InternalName",\s*"[^"]*"', '"InternalName", "pioneer_academy"')
    $content = [regex]::Replace($content, '"LegalCopyright",\s*"Copyright \(C\) 2026 [^"]*"', '"LegalCopyright", "Copyright (C) 2026 com.pioneer. All rights reserved."')
    $content = [regex]::Replace($content, '"OriginalFilename",\s*"[^"]*"', '"OriginalFilename", "pioneer_academy.exe"')
    $content = [regex]::Replace($content, '"ProductName",\s*"[^"]*"', '"ProductName", "Pioneer Academy"')
    [IO.File]::WriteAllText($runnerRcPath, $content, [Text.Encoding]::UTF8)
    Write-Host "Updated windows/runner/Runner.rc"
}

# 7. Linux
$cmakeLinuxPath = "$baseDir\linux\CMakeLists.txt"
if (Test-Path $cmakeLinuxPath) {
    $content = [IO.File]::ReadAllText($cmakeLinuxPath, [Text.Encoding]::UTF8)
    $content = [regex]::Replace($content, 'set\(BINARY_NAME\s+"[^"]+"\s*\)', 'set(BINARY_NAME "pioneer_academy")')
    $content = [regex]::Replace($content, 'set\(APPLICATION_ID\s+"[^"]+"\s*\)', 'set(APPLICATION_ID "com.pioneer.app")')
    [IO.File]::WriteAllText($cmakeLinuxPath, $content, [Text.Encoding]::UTF8)
    Write-Host "Updated linux/CMakeLists.txt"
}

$myAppCcPath = "$baseDir\linux\my_application.cc"
if (Test-Path $myAppCcPath) {
    $content = [IO.File]::ReadAllText($myAppCcPath, [Text.Encoding]::UTF8)
    $content = [regex]::Replace($content, 'gtk_header_bar_set_title\(header_bar,\s*"[^"]*"\);', 'gtk_header_bar_set_title(header_bar, "Pioneer Academy");')
    $content = [regex]::Replace($content, 'gtk_window_set_title\(window,\s*"[^"]*"\);', 'gtk_window_set_title(window, "Pioneer Academy");')
    [IO.File]::WriteAllText($myAppCcPath, $content, [Text.Encoding]::UTF8)
    Write-Host "Updated linux/my_application.cc"
}

# 8. Web
$webIndexPath = "$baseDir\web\index.html"
if (Test-Path $webIndexPath) {
    $content = [IO.File]::ReadAllText($webIndexPath, [Text.Encoding]::UTF8)
    $content = [regex]::Replace($content, '<title>[^<]*<\/title>', '<title>Pioneer Academy</title>')
    $content = [regex]::Replace($content, '<meta name="apple-mobile-web-app-title"\s+content="[^"]*">', '<meta name="apple-mobile-web-app-title" content="Pioneer Academy">')
    [IO.File]::WriteAllText($webIndexPath, $content, [Text.Encoding]::UTF8)
    Write-Host "Updated web/index.html"
}

$webManifestPath = "$baseDir\web\manifest.json"
if (Test-Path $webManifestPath) {
    $content = [IO.File]::ReadAllText($webManifestPath, [Text.Encoding]::UTF8)
    $content = [regex]::Replace($content, '"name":\s*"[^"]*"', '"name": "Pioneer Academy"')
    $content = [regex]::Replace($content, '"short_name":\s*"[^"]*"', '"short_name": "Pioneer Academy"')
    [IO.File]::WriteAllText($webManifestPath, $content, [Text.Encoding]::UTF8)
    Write-Host "Updated web/manifest.json"
}

# 9. Firebase Options
$firebaseOptionsPath = "$baseDir\lib\firebase_options.dart"
if (Test-Path $firebaseOptionsPath) {
    $content = [IO.File]::ReadAllText($firebaseOptionsPath, [Text.Encoding]::UTF8)
    $content = $content.Replace("iosBundleId: 'com.elprof.app'", "iosBundleId: 'com.pioneer.app'")
    [IO.File]::WriteAllText($firebaseOptionsPath, $content, [Text.Encoding]::UTF8)
    Write-Host "Updated lib/firebase_options.dart"
}

# 10. Copy Launcher Icons
Write-Host "Applying new logo to Launcher Icons..."
# Android mipmaps
$androidSrcDir = "$baseDir\assets\AppIcons (1)\android"
$androidResDir = "$baseDir\android\app\src\main\res"

if (Test-Path $androidSrcDir) {
    $mipmaps = @("mipmap-hdpi", "mipmap-mdpi", "mipmap-xhdpi", "mipmap-xxhdpi", "mipmap-xxxhdpi")
    foreach ($mm in $mipmaps) {
        $srcFile = "$androidSrcDir\$mm\ic_launcher.png"
        $destDir = "$androidResDir\$mm"
        if (Test-Path $srcFile) {
            if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
            Copy-Item -Path $srcFile -Destination "$destDir\ic_launcher.png" -Force
            Copy-Item -Path $srcFile -Destination "$destDir\launcher_icon.png" -Force
            Write-Host "Copied $mm launcher icon"
        }
    }
    # Adaptive foreground
    $adaptiveSrc = "$androidSrcDir\adaptive-foreground.png"
    if (Test-Path $adaptiveSrc) {
        Copy-Item -Path $adaptiveSrc -Destination "$androidResDir\drawable\ic_launcher_foreground.png" -Force
        Copy-Item -Path $adaptiveSrc -Destination "$androidResDir\drawable-v21\ic_launcher_foreground.png" -Force
        Copy-Item -Path $adaptiveSrc -Destination "$androidResDir\drawable-xxhdpi\ic_launcher_foreground.png" -Force
        Write-Host "Copied adaptive foreground icon"
    }
}

# iOS AppIcon
$iosSrcDir = "$baseDir\assets\AppIcons (1)\Assets.xcassets\AppIcon.appiconset\_"
$iosDestDir = "$baseDir\ios\Runner\Assets.xcassets\AppIcon.appiconset"
if (Test-Path $iosSrcDir) {
    Get-ChildItem -Path $iosSrcDir -Filter "*.png" | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination "$iosDestDir\$($_.Name)" -Force
    }
    $iosJsonSrc = "$baseDir\assets\AppIcons (1)\Assets.xcassets\AppIcon.appiconset\Contents.json"
    if (Test-Path $iosJsonSrc) {
        $jsonContent = [IO.File]::ReadAllText($iosJsonSrc, [Text.Encoding]::UTF8)
        $jsonContent = $jsonContent.Replace("Assets.xcassets/AppIcon.appiconset/", "")
        [IO.File]::WriteAllText("$iosDestDir\Contents.json", $jsonContent, [Text.Encoding]::UTF8)
    }
    Write-Host "Copied iOS AppIcons"
}

Write-Host "All Pioneer Academy updates applied successfully!"
