# AL Masa

A Flutter application designed for secure educational material distribution with built-in DRM protection.

## Security Features
- **Anti-Screenshot & Screen Recording**: Implemented using `flutter_windowmanager` (Android) and `screen_protector` (iOS).
- **Environment Detection**: Blocks execution on Emulators, Rooted/Jailbroken devices, and devices with Developer Options enabled.
- **Direct Database Connectivity**: Connects to the central Hub database to authenticate and fetch material metadata.
- **Generic Material Support**: Built-in support for Videos (via Chewie) and PDFs.

## How to build with Maximum Protection (Anti-Reverse Engineering)
To prevent reverse engineering, you MUST build the application with obfuscation enabled. Use the following commands:

### Android
```bash
flutter build apk --obfuscate --split-debug-info=/<your_path>/debug_info
```

### iOS
```bash
flutter build ios --obfuscate --split-debug-info=/<your_path>/debug_info
```

## Configuration
The database connection settings are located in `lib/constants/db_config.dart`.

## Dependencies
- `mysql1`: For direct DB connection.
- `safe_device`: For security environment checks.
- `flutter_windowmanager`: For Android screen capture prevention.
- `screen_protector`: For cross-platform protection.
- `google_fonts`: For premium aesthetics.
- `chewie`: For advanced video playback control.
