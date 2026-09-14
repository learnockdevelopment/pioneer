$baseDir = "c:\Users\dell\apps\apps\Learnock-DRM-"

# 1. Update all .dart files to replace package name imports
Write-Host "Updating .dart files..."
Get-ChildItem -Path "$baseDir\lib", "$baseDir\test" -Filter "*.dart" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
    $content = [System.IO.File]::ReadAllText($_.FullName)
    if ($content.Contains("package:learnock_drm/")) {
        $content = $content.Replace("package:learnock_drm/", "package:elmasa/")
        [System.IO.File]::WriteAllText($_.FullName, $content)
        Write-Host "Updated imports in: $($_.Name)"
    }
}

# 2. Update Android configuration files
Write-Host "Updating Android configurations..."
$appGradle = "$baseDir\android\app\build.gradle"
if (Test-Path $appGradle) {
    $content = [System.IO.File]::ReadAllText($appGradle)
    $content = $content.Replace('namespace = "com.omran_college.app"', 'namespace = "com.elprof.app"')
    $content = $content.Replace('applicationId = "com.omran_college.app"', 'applicationId = "com.elprof.app"')
    [System.IO.File]::WriteAllText($appGradle, $content)
}

$rootGradle = "$baseDir\android\build.gradle"
if (Test-Path $rootGradle) {
    $content = [System.IO.File]::ReadAllText($rootGradle)
    $content = $content.Replace('namespace = "com.learnock.${project.name.replace(''-'', ''_'')}"', 'namespace = "com.elprof.${project.name.replace(''-'', ''_'')}"')
    [System.IO.File]::WriteAllText($rootGradle, $content)
}

$manifest = "$baseDir\android\app\src\main\AndroidManifest.xml"
if (Test-Path $manifest) {
    $content = [System.IO.File]::ReadAllText($manifest)
    $content = $content.Replace('android:label="AL Masa"', 'android:label="AL Masa"')
    [System.IO.File]::WriteAllText($manifest, $content)
}

# Move MainActivity.kt and create package folder
$oldKotlinDir = "$baseDir\android\app\src\main\kotlin\com\learnock\learnock_drm"
$newKotlinDir = "$baseDir\android\app\src\main\kotlin\com\elmasa\app"

if (!(Test-Path $newKotlinDir)) {
    New-Item -ItemType Directory -Force -Path $newKotlinDir
}

$newActivityPath = "$newKotlinDir\MainActivity.kt"
$activityContent = "package com.elprof.app
`n`nimport io.flutter.embedding.android.FlutterActivity`n`nclass MainActivity: FlutterActivity()`n"
[System.IO.File]::WriteAllText($newActivityPath, $activityContent)

$oldActivityPath = "$oldKotlinDir\MainActivity.kt"
if (Test-Path $oldActivityPath) {
    Remove-Item -Path $oldActivityPath -Force
    Write-Host "Removed old MainActivity.kt"
}

# 3. Update iOS configuration files
Write-Host "Updating iOS configurations..."
$infoPlist = "$baseDir\ios\Runner\Info.plist"
if (Test-Path $infoPlist) {
    $content = [System.IO.File]::ReadAllText($infoPlist)
    $content = $content.Replace("<string>AL Masa</string>", "<string>AL Masa</string>")
    $content = $content.Replace("<string>AL Masa</string>", "<string>AL Masa</string>")
    [System.IO.File]::WriteAllText($infoPlist, $content)
}

$pbxprojIos = "$baseDir\ios\Runner.xcodeproj\project.pbxproj"
if (Test-Path $pbxprojIos) {
    $content = [System.IO.File]::ReadAllText($pbxprojIos)
    $content = $content.Replace("PRODUCT_BUNDLE_IDENTIFIER = com.learnock.learnockDrm;", "PRODUCT_BUNDLE_IDENTIFIER = com.elprof.app
;")
    $content = $content.Replace("INFOPLIST_KEY_CFBundleDisplayName = `"AL Masa`";", "INFOPLIST_KEY_CFBundleDisplayName = `"AL Masa`";")
    [System.IO.File]::WriteAllText($pbxprojIos, $content)
}

# 4. Update macOS configuration files
Write-Host "Updating macOS configurations..."
$appInfo = "$baseDir\macos\Runner\Configs\AppInfo.xcconfig"
if (Test-Path $appInfo) {
    $content = [System.IO.File]::ReadAllText($appInfo)
    $content = $content.Replace("PRODUCT_NAME = learnock_drm", "PRODUCT_NAME = elmasa")
    $content = $content.Replace("PRODUCT_BUNDLE_IDENTIFIER = com.learnock.learnockDrm", "PRODUCT_BUNDLE_IDENTIFIER = com.elprof.app")
    $content = $content.Replace("PRODUCT_COPYRIGHT = Copyright © 2026 com.learnock. All rights reserved.", "PRODUCT_COPYRIGHT = Copyright © 2026 com.elprof. All rights reserved.")
    [System.IO.File]::WriteAllText($appInfo, $content)
}

$pbxprojMacos = "$baseDir\macos\Runner.xcodeproj\project.pbxproj"
if (Test-Path $pbxprojMacos) {
    $content = [System.IO.File]::ReadAllText($pbxprojMacos)
    $content = $content.Replace("PRODUCT_BUNDLE_IDENTIFIER = com.learnock.learnockDrm.RunnerTests;", "PRODUCT_BUNDLE_IDENTIFIER = com.elprof.app
.RunnerTests;")
    $content = $content.Replace("learnock_drm.app", "elmasa.app")
    $content = $content.Replace("learnock_drm", "elmasa")
    [System.IO.File]::WriteAllText($pbxprojMacos, $content)
}

# 5. Update Windows configuration files
Write-Host "Updating Windows configurations..."
$cmakeWindows = "$baseDir\windows\CMakeLists.txt"
if (Test-Path $cmakeWindows) {
    $content = [System.IO.File]::ReadAllText($cmakeWindows)
    $content = $content.Replace("project(learnock_drm LANGUAGES CXX)", "project(elmasa LANGUAGES CXX)")
    $content = $content.Replace("set(BINARY_NAME `"learnock_drm`")", "set(BINARY_NAME `"elmasa`")")
    [System.IO.File]::WriteAllText($cmakeWindows, $content)
}

$mainCpp = "$baseDir\windows\runner\main.cpp"
if (Test-Path $mainCpp) {
    $content = [System.IO.File]::ReadAllText($mainCpp)
    $content = $content.Replace('L"learnock_drm"', 'L"AL Masa"')
    [System.IO.File]::WriteAllText($mainCpp, $content)
}

$runnerRc = "$baseDir\windows\runner\Runner.rc"
if (Test-Path $runnerRc) {
    $content = [System.IO.File]::ReadAllText($runnerRc)
    $content = $content.Replace('`"CompanyName`", `"com.learnock`"', '`"CompanyName`", `"com.elprof`"')
    $content = $content.Replace('`"FileDescription`", `"learnock_drm`"', '`"FileDescription`", `"elmasa`"')
    $content = $content.Replace('`"InternalName`", `"learnock_drm`"', '`"InternalName`", `"elmasa`"')
    $content = $content.Replace('`"LegalCopyright`", `"Copyright (C) 2026 com.learnock. All rights reserved.`"', '`"LegalCopyright`", `"Copyright (C) 2026 com.elprof. All rights reserved.`"')
    $content = $content.Replace('`"OriginalFilename`", `"learnock_drm.exe`"', '`"OriginalFilename`", `"elmasa.exe`"')
    $content = $content.Replace('`"ProductName`", `"learnock_drm`"', '`"ProductName`", `"elmasa`"')
    [System.IO.File]::WriteAllText($runnerRc, $content)
}

# 6. Update Linux configuration files
Write-Host "Updating Linux configurations..."
$cmakeLinux = "$baseDir\linux\CMakeLists.txt"
if (Test-Path $cmakeLinux) {
    $content = [System.IO.File]::ReadAllText($cmakeLinux)
    $content = $content.Replace('set(BINARY_NAME "learnock_drm")', 'set(BINARY_NAME "elmasa")')
    $content = $content.Replace('set(APPLICATION_ID "com.omran_college.app`n")', 'set(APPLICATION_ID "com.elprof.app
`n")')
    $content = $content.Replace('set(APPLICATION_ID "com.omran_college.app")', 'set(APPLICATION_ID "com.elprof.app")')
    [System.IO.File]::WriteAllText($cmakeLinux, $content)
}

$myAppCc = "$baseDir\linux\my_application.cc"
if (Test-Path $myAppCc) {
    $content = [System.IO.File]::ReadAllText($myAppCc)
    $content = $content.Replace('"learnock_drm"', '"AL Masa"')
    [System.IO.File]::WriteAllText($myAppCc, $content)
}

# 7. Update language files and specific Dart source string matches
Write-Host "Updating language files and Dart strings..."
$langFiles = @("en.json", "ar.json")
foreach ($lang in $langFiles) {
    $langPath = "$baseDir\assets\lang\$lang"
    if (Test-Path $langPath) {
        $content = [System.IO.File]::ReadAllText($langPath)
        $content = $content.Replace("Learnock Student", "elmasa Student")
        $content = $content.Replace("طالب Learnock", "طالب الماسة")
        $content = $content.Replace("Welcome to Learnock", "Welcome to AL Masa")
        $content = $content.Replace("مرحباً بك في Learnock", "مرحباً بك في أكاديمية الماسة")
        $content = $content.Replace("© 2026 Learnock LMS", "© 2026 elmasa LMS")
        $content = $content.Replace("AL Masa ENGINE v4.0", "elmasa DRM ENGINE v4.0")
        $content = $content.Replace("محرك حماية LEARNOCK v4.0", "محرك حماية elmasa v4.0")
        $content = $content.Replace("academy.Learnock.app", "academy.elmasa.app")
        [System.IO.File]::WriteAllText($langPath, $content)
    }
}

$encryptService = "$baseDir\lib\services\encryption_service.dart"
if (Test-Path $encryptService) {
    $content = [System.IO.File]::ReadAllText($encryptService)
    $content = $content.Replace("lEaRnOcKdRmSeCuReKeY2026_03_29_32", "elmasaApPsEcUrEkEy2026_03_29_32")
    [System.IO.File]::WriteAllText($encryptService, $content)
}

$onboardScreen = "$baseDir\lib\screens\onboarding_screen.dart"
if (Test-Path $onboardScreen) {
    $content = [System.IO.File]::ReadAllText($onboardScreen)
    $content = $content.Replace("academy.Learnock.app", "academy.elmasa.app")
    [System.IO.File]::WriteAllText($onboardScreen, $content)
}

$matViewer = "$baseDir\lib\screens\material_viewer_screen.dart"
if (Test-Path $matViewer) {
    $content = [System.IO.File]::ReadAllText($matViewer)
    $content = $content.Replace("https://learnock.com/", "https://elmasa.com/")
    $content = $content.Replace("https://learnock.com", "https://elmasa.com")
    [System.IO.File]::WriteAllText($matViewer, $content)
}

$homeScreen = "$baseDir\lib\screens\home_screen.dart"
if (Test-Path $homeScreen) {
    $content = [System.IO.File]::ReadAllText($homeScreen)
    $content = $content.Replace('"LEARNOCK"', '"elmasa"')
    [System.IO.File]::WriteAllText($homeScreen, $content)
}

Write-Host "Project renaming completed successfully!"
