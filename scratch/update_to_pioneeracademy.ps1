$baseDir = "f:\learnock\pioneer"
Write-Host "Changing package name to com.pioneeracademy.app..."

# 1. Android build.gradle
$appGradlePath = "$baseDir\android\app\build.gradle"
if (Test-Path $appGradlePath) {
    $content = [IO.File]::ReadAllText($appGradlePath, [Text.Encoding]::UTF8)
    $content = $content.Replace('namespace = "com.pioneer.app"', 'namespace = "com.pioneeracademy.app"')
    $content = $content.Replace('applicationId "com.pioneer.app"', 'applicationId "com.pioneeracademy.app"')
    [IO.File]::WriteAllText($appGradlePath, $content, [Text.Encoding]::UTF8)
    Write-Host "Updated android/app/build.gradle"
}

$rootGradlePath = "$baseDir\android\build.gradle"
if (Test-Path $rootGradlePath) {
    $content = [IO.File]::ReadAllText($rootGradlePath, [Text.Encoding]::UTF8)
    $content = $content.Replace('namespace = "com.pioneer.${project.name.replace(''-'', ''_'')}"', 'namespace = "com.pioneeracademy.${project.name.replace(''-'', ''_'')}"')
    [IO.File]::WriteAllText($rootGradlePath, $content, [Text.Encoding]::UTF8)
    Write-Host "Updated android/build.gradle"
}

# 2. Kotlin MainActivity
$pioneerAcademyKotlinDir = "$baseDir\android\app\src\main\kotlin\com\pioneeracademy\app"
if (-not (Test-Path $pioneerAcademyKotlinDir)) {
    New-Item -ItemType Directory -Path $pioneerAcademyKotlinDir -Force | Out-Null
}
$mainActivityContent = @"
package com.pioneeracademy.app

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity()
"@
[IO.File]::WriteAllText("$pioneerAcademyKotlinDir\MainActivity.kt", $mainActivityContent, [Text.Encoding]::UTF8)
Write-Host "Created $pioneerAcademyKotlinDir\MainActivity.kt"

# Clear old pioneer kotlin MainActivity if exists
$oldKotlinMainActivity = "$baseDir\android\app\src\main\kotlin\com\pioneer\app\MainActivity.kt"
if (Test-Path $oldKotlinMainActivity) {
    [IO.File]::WriteAllText($oldKotlinMainActivity, "// Obsolete - moved to com.pioneeracademy.app.MainActivity`n", [Text.Encoding]::UTF8)
}

# 3. iOS project.pbxproj
$pbxprojIosPath = "$baseDir\ios\Runner.xcodeproj\project.pbxproj"
if (Test-Path $pbxprojIosPath) {
    $content = [IO.File]::ReadAllText($pbxprojIosPath, [Text.Encoding]::UTF8)
    $content = $content.Replace('PRODUCT_BUNDLE_IDENTIFIER = com.pioneer.app;', 'PRODUCT_BUNDLE_IDENTIFIER = com.pioneeracademy.app;')
    [IO.File]::WriteAllText($pbxprojIosPath, $content, [Text.Encoding]::UTF8)
    Write-Host "Updated ios/Runner.xcodeproj/project.pbxproj"
}

# 4. macOS AppInfo.xcconfig & pbxproj
$appInfoPath = "$baseDir\macos\Runner\Configs\AppInfo.xcconfig"
if (Test-Path $appInfoPath) {
    $content = [IO.File]::ReadAllText($appInfoPath, [Text.Encoding]::UTF8)
    $content = $content.Replace('PRODUCT_BUNDLE_IDENTIFIER = com.pioneer.app', 'PRODUCT_BUNDLE_IDENTIFIER = com.pioneeracademy.app')
    [IO.File]::WriteAllText($appInfoPath, $content, [Text.Encoding]::UTF8)
    Write-Host "Updated macos/Runner/Configs/AppInfo.xcconfig"
}

$pbxprojMacosPath = "$baseDir\macos\Runner.xcodeproj\project.pbxproj"
if (Test-Path $pbxprojMacosPath) {
    $content = [IO.File]::ReadAllText($pbxprojMacosPath, [Text.Encoding]::UTF8)
    $content = $content.Replace('PRODUCT_BUNDLE_IDENTIFIER = com.pioneer.app.RunnerTests;', 'PRODUCT_BUNDLE_IDENTIFIER = com.pioneeracademy.app.RunnerTests;')
    $content = $content.Replace('PRODUCT_BUNDLE_IDENTIFIER = com.pioneer.app;', 'PRODUCT_BUNDLE_IDENTIFIER = com.pioneeracademy.app;')
    [IO.File]::WriteAllText($pbxprojMacosPath, $content, [Text.Encoding]::UTF8)
    Write-Host "Updated macos/Runner.xcodeproj/project.pbxproj"
}

# 5. Linux CMakeLists.txt
$cmakeLinuxPath = "$baseDir\linux\CMakeLists.txt"
if (Test-Path $cmakeLinuxPath) {
    $content = [IO.File]::ReadAllText($cmakeLinuxPath, [Text.Encoding]::UTF8)
    $content = $content.Replace('set(APPLICATION_ID "com.pioneer.app")', 'set(APPLICATION_ID "com.pioneeracademy.app")')
    [IO.File]::WriteAllText($cmakeLinuxPath, $content, [Text.Encoding]::UTF8)
    Write-Host "Updated linux/CMakeLists.txt"
}

# 6. Firebase Options & Google Services
$firebaseOptionsPath = "$baseDir\lib\firebase_options.dart"
if (Test-Path $firebaseOptionsPath) {
    $content = [IO.File]::ReadAllText($firebaseOptionsPath, [Text.Encoding]::UTF8)
    $content = $content.Replace("iosBundleId: 'com.pioneer.app'", "iosBundleId: 'com.pioneeracademy.app'")
    [IO.File]::WriteAllText($firebaseOptionsPath, $content, [Text.Encoding]::UTF8)
    Write-Host "Updated lib/firebase_options.dart"
}

$googleServicesPath = "$baseDir\android\app\google-services.json"
if (Test-Path $googleServicesPath) {
    $content = [IO.File]::ReadAllText($googleServicesPath, [Text.Encoding]::UTF8)
    $content = $content.Replace('"com.pioneer.app"', '"com.pioneeracademy.app"')
    [IO.File]::WriteAllText($googleServicesPath, $content, [Text.Encoding]::UTF8)
    Write-Host "Updated android/app/google-services.json"
}

Write-Host "Package name changed to com.pioneeracademy.app successfully!"
