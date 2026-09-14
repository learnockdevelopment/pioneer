import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class EncryptionService {
  // Use a secure 32-character key for AES-256
  // In a production app, this should be stored securely (e.g., flutter_secure_storage)
  static final _key = Key.fromUtf8('elmasaApPsEcUrEkEy2026_03_29_32'); 
  static final _iv = IV.fromLength(16);
  static final _encrypter = Encrypter(AES(_key));

  /// Decrypts a string (e.g., encoded material URL or title)
  static String? decrypt(String? encryptedText) {
    if (encryptedText == null || encryptedText.isEmpty) return null;
    try {
      return _encrypter.decrypt64(encryptedText, iv: _iv);
    } catch (e) {
      // If decryption fails, it might mean the data is not encrypted or wrong key
      debugPrint('Decryption Error: $e');
      return encryptedText; // Fallback to original text if error
    }
  }

  /// Encrypts a string (for testing/storing purposes)
  static String? encrypt(String? plainText) {
    if (plainText == null || plainText.isEmpty) return null;
    return _encrypter.encrypt(plainText, iv: _iv).base64;
  }
}
