import 'dart:convert';
import 'package:crypto/crypto.dart';

class SecurityUtils {
  /// Hashes a password using SHA-256
  static String hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verifies a password against a hash
  static bool verifyPassword(String password, String hash) {
    return hashPassword(password) == hash;
  }
}
