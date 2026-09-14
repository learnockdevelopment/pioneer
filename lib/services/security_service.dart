import 'dart:io';
import 'package:no_screenshot/no_screenshot.dart';
import 'package:safe_device/safe_device.dart';

class SecurityService {
  static final _noScreenshot = NoScreenshot.instance;
  static const bool bypassSecurityChecks = true;

  static Future<void> setupSecurity() async {
    if (!bypassSecurityChecks) {
      await _noScreenshot.screenshotOff(); 
    }
  }

  static bool? _isCachedSafe;

  static Future<bool> isDeviceSafe() async {
    if (bypassSecurityChecks) return true;
    if (_isCachedSafe != null) return _isCachedSafe!;
 
    // Block macOS (MacBooks)
    if (Platform.isMacOS) {
      _isCachedSafe = false;
      return false;
    }

    try {
      bool isReal = await SafeDevice.isRealDevice;
      bool isJailBroken = await SafeDevice.isJailBroken;
      bool isDeveloperOptionsEnabled = await SafeDevice.isDevelopmentModeEnable;

      if (!isReal) {
        _isCachedSafe = false;
        return false;
      }
      if (isJailBroken) {
        _isCachedSafe = false;
        return false;
      }
      if (isDeveloperOptionsEnabled && Platform.isAndroid) {
        _isCachedSafe = false;
        return false;
      }
      _isCachedSafe = true;
      return true;
    } catch (e) {
      _isCachedSafe = false;
      return false;
    }
  }
  static void exitApp() {
    exit(0);
  }
}
