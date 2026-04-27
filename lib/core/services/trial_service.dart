import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrialService {
  static const String _trialKey = 'trial_start_date';
  static const String _lastRunKey = 'trial_last_run';
  static const int trialDurationDays = 7;

  /// Vérifie si l'utilisateur est en période d'essai valide
  static Future<Map<String, dynamic>> checkTrialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final String? startDateStr = prefs.getString(_trialKey);
    final String? lastRunStr = prefs.getString(_lastRunKey);

    if (startDateStr == null) {
      return {
        'isTrial': false,
        'expired': false,
        'message': 'Aucun essai en cours',
      };
    }

    final startDate = DateTime.parse(startDateStr);
    final lastRunDate = lastRunStr != null
        ? DateTime.parse(lastRunStr)
        : startDate;
    final now = DateTime.now();

    // 1. Vérification de la triche (Horloge reculée)
    if (now.isBefore(lastRunDate)) {
      return {
        'isTrial': true,
        'expired': true,
        'message': 'Action suspecte détectée sur l\'horloge système.',
      };
    }

    // 2. Vérification de l'expiration
    final difference = now.difference(startDate).inDays;
    if (difference >= trialDurationDays) {
      return {
        'isTrial': true,
        'expired': true,
        'message':
            'Votre période d\'essai de $trialDurationDays jours est terminée.',
      };
    }

    // 3. Mise à jour de la dernière date de lancement
    await prefs.setString(_lastRunKey, now.toIso8601String());

    final remaining = startDate
        .add(const Duration(days: trialDurationDays))
        .difference(now);

    return {
      'isTrial': true,
      'expired': false,
      'remainingDays': remaining.inDays,
      'remainingDuration': remaining,
      'message': 'Il vous reste ${_formatDuration(remaining)} d\'essai.',
    };
  }

  /// Vérifie si l'essai est actif (commencé et non expiré)
  static Future<bool> isTrialActive() async {
    final status = await checkTrialStatus();
    return (status['isTrial'] as bool) && !(status['expired'] as bool);
  }

  /// Retourne la durée restante sous forme lisible
  static String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}j ${duration.inHours.remainder(24)}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    }
  }

  /// Retourne directement la durée restante
  static Future<Duration?> getRemainingTime() async {
    final prefs = await SharedPreferences.getInstance();
    final String? startDateStr = prefs.getString(_trialKey);
    if (startDateStr == null) return null;

    final startDate = DateTime.parse(startDateStr);
    final now = DateTime.now();
    final expiryDate = startDate.add(const Duration(days: trialDurationDays));

    if (now.isAfter(expiryDate)) return Duration.zero;
    return expiryDate.difference(now);
  }

  /// Active la période d'essai de 7 jours
  static Future<bool> activateTrial() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_trialKey)) return false; // Déjà activé une fois

    final now = DateTime.now();
    await prefs.setString(_trialKey, now.toIso8601String());
    await prefs.setString(_lastRunKey, now.toIso8601String());

    // Pour plus de sécurité sur Desktop, on crée aussi un fichier caché
    await _createHiddenCheckpoint(now);

    return true;
  }

  /// Crée un fichier de vérification caché pour éviter le contournement par SharedPreferences
  static Future<void> _createHiddenCheckpoint(DateTime startDate) async {
    try {
      final directory = await getApplicationSupportDirectory();
      final deviceId = await _getDeviceId();
      final path = '${directory.path}/.sys_data_cache.db';
      final file = File(path);

      final data = {
        'd': startDate.toIso8601String(),
        'id': deviceId,
        'h': _generateHash(startDate.toIso8601String(), deviceId),
      };

      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      // Erreur silencieuse
    }
  }

  static String _generateHash(String date, String deviceId) {
    final key = utf8.encode('dahliaspriver_salt_2024_$deviceId');
    final bytes = utf8.encode(date);
    final hmac = Hmac(sha256, key);
    return hmac.convert(bytes).toString();
  }

  static Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isLinux) {
      final linuxInfo = await deviceInfo.linuxInfo;
      return linuxInfo.machineId ?? 'linux_id';
    } else if (Platform.isWindows) {
      final windowsInfo = await deviceInfo.windowsInfo;
      return windowsInfo.deviceId;
    }
    return 'generic_id';
  }

  /// Réinitialise complètement les données d'essai (appelé après activation licence réelle)
  static Future<void> resetTrial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_trialKey);
    await prefs.remove(_lastRunKey);

    try {
      final directory = await getApplicationSupportDirectory();
      final path = '${directory.path}/.sys_data_cache.db';
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignorer
    }
  }
}
