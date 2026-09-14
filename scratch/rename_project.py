import os
import re

base_dir = r"c:\Users\dell\apps\apps\Learnock-DRM-"

# 1. Update all .dart files to replace package name imports
def update_dart_imports():
    print("Updating .dart files...")
    count = 0
    for root, dirs, files in os.walk(os.path.join(base_dir, "lib")):
        for file in files:
            if file.endswith(".dart"):
                path = os.path.join(root, file)
                with open(path, "r", encoding="utf-8") as f:
                    content = f.read()
                if "package:learnock_drm/" in content:
                    content = content.replace("package:learnock_drm/", "package:elmasa/")
                    with open(path, "w", encoding="utf-8") as f:
                        f.write(content)
                    count += 1
                    
    # Also update tests if they exist
    for root, dirs, files in os.walk(os.path.join(base_dir, "test")):
        for file in files:
            if file.endswith(".dart"):
                path = os.path.join(root, file)
                with open(path, "r", encoding="utf-8") as f:
                    content = f.read()
                if "package:learnock_drm/" in content:
                    content = content.replace("package:learnock_drm/", "package:elmasa/")
                    with open(path, "w", encoding="utf-8") as f:
                        f.write(content)
                    count += 1
    print(f"Updated package imports in {count} Dart files.")

# 2. Update Android configuration files
def update_android_configs():
    print("Updating Android configurations...")
    # build.gradle (app level)
    app_gradle = os.path.join(base_dir, "android", "app", "build.gradle")
    if os.path.exists(app_gradle):
        with open(app_gradle, "r", encoding="utf-8") as f:
            content = f.read()
        content = content.replace('namespace = "com.omran_college.app"', 'namespace = "com.elprof.app"')
        content = content.replace('applicationId = "com.omran_college.app"', 'applicationId = "com.elprof.app"')
        with open(app_gradle, "w", encoding="utf-8") as f:
            f.write(content)

    # build.gradle (root level)
    root_gradle = os.path.join(base_dir, "android", "build.gradle")
    if os.path.exists(root_gradle):
        with open(root_gradle, "r", encoding="utf-8") as f:
            content = f.read()
        content = content.replace('namespace = "com.learnock.${project.name.replace(\'-\', \'_\')}"', 'namespace = "com.elprof.${project.name.replace(\'-\', \'_\')}"')
        with open(root_gradle, "w", encoding="utf-8") as f:
            f.write(content)

    # AndroidManifest.xml
    manifest_path = os.path.join(base_dir, "android", "app", "src", "main", "AndroidManifest.xml")
    if os.path.exists(manifest_path):
        with open(manifest_path, "r", encoding="utf-8") as f:
            content = f.read()
        content = content.replace('android:label="AL Masa"', 'android:label="AL Masa"')
        with open(manifest_path, "w", encoding="utf-8") as f:
            f.write(content)

    # Create new MainActivity directory and file
    old_kotlin_dir = os.path.join(base_dir, "android", "app", "src", "main", "kotlin", "com", "learnock", "learnock_drm")
    new_kotlin_dir = os.path.join(base_dir, "android", "app", "src", "main", "kotlin", "com", "elmasa", "app")
    
    os.makedirs(new_kotlin_dir, exist_ok=True)
    new_activity_path = os.path.join(new_kotlin_dir, "MainActivity.kt")
    
    with open(new_activity_path, "w", encoding="utf-8") as f:
        f.write("package com.elprof.app
\n\nimport io.flutter.embedding.android.FlutterActivity\n\nclass MainActivity: FlutterActivity()\n")
    
    # Remove old MainActivity.kt if it exists
    old_activity_path = os.path.join(old_kotlin_dir, "MainActivity.kt")
    if os.path.exists(old_activity_path):
        os.remove(old_activity_path)
        print("Removed old MainActivity.kt")

# 3. Update iOS configuration files
def update_ios_configs():
    print("Updating iOS configurations...")
    # Info.plist
    info_plist = os.path.join(base_dir, "ios", "Runner", "Info.plist")
    if os.path.exists(info_plist):
        with open(info_plist, "r", encoding="utf-8") as f:
            content = f.read()
        content = content.replace("<string>AL Masa</string>", "<string>AL Masa</string>")
        with open(info_plist, "w", encoding="utf-8") as f:
            f.write(content)

    # project.pbxproj
    pbxproj = os.path.join(base_dir, "ios", "Runner.xcodeproj", "project.pbxproj")
    if os.path.exists(pbxproj):
        with open(pbxproj, "r", encoding="utf-8") as f:
            content = f.read()
        content = content.replace("PRODUCT_BUNDLE_IDENTIFIER = com.learnock.learnockDrm;", "PRODUCT_BUNDLE_IDENTIFIER = com.elprof.app
;")
        content = content.replace("INFOPLIST_KEY_CFBundleDisplayName = \"AL Masa\";", "INFOPLIST_KEY_CFBundleDisplayName = \"AL Masa\";")
        with open(pbxproj, "w", encoding="utf-8") as f:
            f.write(content)

# 4. Update macOS configuration files
def update_macos_configs():
    print("Updating macOS configurations...")
    # AppInfo.xcconfig
    app_info = os.path.join(base_dir, "macos", "Runner", "Configs", "AppInfo.xcconfig")
    if os.path.exists(app_info):
        with open(app_info, "r", encoding="utf-8") as f:
            content = f.read()
        content = content.replace("PRODUCT_NAME = learnock_drm", "PRODUCT_NAME = elmasa")
        content = content.replace("PRODUCT_BUNDLE_IDENTIFIER = com.learnock.learnockDrm", "PRODUCT_BUNDLE_IDENTIFIER = com.elprof.app")
        content = content.replace("PRODUCT_COPYRIGHT = Copyright © 2026 com.learnock. All rights reserved.", "PRODUCT_COPYRIGHT = Copyright © 2026 com.elprof. All rights reserved.")
        with open(app_info, "w", encoding="utf-8") as f:
            f.write(content)

    # project.pbxproj
    pbxproj = os.path.join(base_dir, "macos", "Runner.xcodeproj", "project.pbxproj")
    if os.path.exists(pbxproj):
        with open(pbxproj, "r", encoding="utf-8") as f:
            content = f.read()
        content = content.replace("PRODUCT_BUNDLE_IDENTIFIER = com.learnock.learnockDrm.RunnerTests;", "PRODUCT_BUNDLE_IDENTIFIER = com.elprof.app
.RunnerTests;")
        content = content.replace("learnock_drm.app", "elmasa.app")
        content = content.replace("learnock_drm", "elmasa")
        with open(pbxproj, "w", encoding="utf-8") as f:
            f.write(content)

# 5. Update Windows configuration files
def update_windows_configs():
    print("Updating Windows configurations...")
    # CMakeLists.txt
    cmake = os.path.join(base_dir, "windows", "CMakeLists.txt")
    if os.path.exists(cmake):
        with open(cmake, "r", encoding="utf-8") as f:
            content = f.read()
        content = content.replace("project(learnock_drm LANGUAGES CXX)", "project(elmasa LANGUAGES CXX)")
        content = content.replace('set(BINARY_NAME "learnock_drm")', 'set(BINARY_NAME "elmasa")')
        with open(cmake, "w", encoding="utf-8") as f:
            f.write(content)

    # main.cpp
    main_cpp = os.path.join(base_dir, "windows", "runner", "main.cpp")
    if os.path.exists(main_cpp):
        with open(main_cpp, "r", encoding="utf-8") as f:
            content = f.read()
        content = content.replace('L"learnock_drm"', 'L"AL Masa"')
        with open(main_cpp, "w", encoding="utf-8") as f:
            f.write(content)

    # Runner.rc
    runner_rc = os.path.join(base_dir, "windows", "runner", "Runner.rc")
    if os.path.exists(runner_rc):
        with open(runner_rc, "r", encoding="utf-8") as f:
            content = f.read()
        content = content.replace('"CompanyName", "com.learnock"', '"CompanyName", "com.elprof"')
        content = content.replace('"FileDescription", "learnock_drm"', '"FileDescription", "elmasa"')
        content = content.replace('"InternalName", "learnock_drm"', '"InternalName", "elmasa"')
        content = content.replace('"LegalCopyright", "Copyright (C) 2026 com.learnock. All rights reserved."', '"LegalCopyright", "Copyright (C) 2026 com.elprof. All rights reserved."')
        content = content.replace('"OriginalFilename", "learnock_drm.exe"', '"OriginalFilename", "elmasa.exe"')
        content = content.replace('"ProductName", "learnock_drm"', '"ProductName", "elmasa"')
        with open(runner_rc, "w", encoding="utf-8") as f:
            f.write(content)

# 6. Update Linux configuration files
def update_linux_configs():
    print("Updating Linux configurations...")
    # CMakeLists.txt
    cmake = os.path.join(base_dir, "linux", "CMakeLists.txt")
    if os.path.exists(cmake):
        with open(cmake, "r", encoding="utf-8") as f:
            content = f.read()
        content = content.replace('set(BINARY_NAME "learnock_drm")', 'set(BINARY_NAME "elmasa")')
        content = content.replace('set(APPLICATION_ID "com.omran_college.app\n")', 'set(APPLICATION_ID "com.elprof.app
\n")')
        content = content.replace('set(APPLICATION_ID "com.omran_college.app")', 'set(APPLICATION_ID "com.elprof.app")')
        with open(cmake, "w", encoding="utf-8") as f:
            f.write(content)

    # my_application.cc
    app_cc = os.path.join(base_dir, "linux", "my_application.cc")
    if os.path.exists(app_cc):
        with open(app_cc, "r", encoding="utf-8") as f:
            content = f.read()
        content = content.replace('"learnock_drm"', '"AL Masa"')
        with open(app_cc, "w", encoding="utf-8") as f:
            f.write(content)

# 7. Update language files and specific Dart source string matches
def update_translation_and_strings():
    print("Updating language files and Dart strings...")
    # Translation files
    for lang in ["en.json", "ar.json"]:
        path = os.path.join(base_dir, "assets", "lang", lang)
        if os.path.exists(path):
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
            content = content.replace("Learnock Student", "elmasa Student")
            content = content.replace("طالب Learnock", "طالب الماسة")
            content = content.replace("Welcome to Learnock", "Welcome to AL Masa")
            content = content.replace("مرحباً بك في Learnock", "مرحباً بك في أكاديمية الماسة")
            content = content.replace("© 2026 Learnock LMS", "© 2026 elmasa LMS")
            content = content.replace("AL Masa ENGINE v4.0", "elmasa DRM ENGINE v4.0")
            content = content.replace("محرك حماية LEARNOCK v4.0", "محرك حماية elmasa v4.0")
            content = content.replace("academy.Learnock.app", "academy.elmasa.app")
            with open(path, "w", encoding="utf-8") as f:
                f.write(content)

    # encryption_service.key
    encrypt_service = os.path.join(base_dir, "lib", "services", "encryption_service.dart")
    if os.path.exists(encrypt_service):
        with open(encrypt_service, "r", encoding="utf-8") as f:
            content = f.read()
        content = content.replace('lEaRnOcKdRmSeCuReKeY2026_03_29_32', 'elmasaApPsEcUrEkEy2026_03_29_32')
        with open(encrypt_service, "w", encoding="utf-8") as f:
            f.write(content)

    # onboarding_screen.dart (hint)
    onboard_screen = os.path.join(base_dir, "lib", "screens", "onboarding_screen.dart")
    if os.path.exists(onboard_screen):
        with open(onboard_screen, "r", encoding="utf-8") as f:
            content = f.read()
        content = content.replace("academy.Learnock.app", "academy.elmasa.app")
        with open(onboard_screen, "w", encoding="utf-8") as f:
            f.write(content)

    # material_viewer_screen.dart (Referer & Origin)
    mat_viewer = os.path.join(base_dir, "lib", "screens", "material_viewer_screen.dart")
    if os.path.exists(mat_viewer):
        with open(mat_viewer, "r", encoding="utf-8") as f:
            content = f.read()
        content = content.replace("https://learnock.com/", "https://elmasa.com/")
        content = content.replace("https://learnock.com", "https://elmasa.com")
        with open(mat_viewer, "w", encoding="utf-8") as f:
            f.write(content)

    # home_screen.dart ("LEARNOCK")
    home_screen = os.path.join(base_dir, "lib", "screens", "home_screen.dart")
    if os.path.exists(home_screen):
        with open(home_screen, "r", encoding="utf-8") as f:
            content = f.read()
        content = content.replace('"LEARNOCK"', '"elmasa"')
        with open(home_screen, "w", encoding="utf-8") as f:
            f.write(content)

if __name__ == "__main__":
    update_dart_imports()
    update_android_configs()
    update_ios_configs()
    update_macos_configs()
    update_windows_configs()
    update_linux_configs()
    update_translation_and_strings()
    print("Project renaming completed successfully!")
