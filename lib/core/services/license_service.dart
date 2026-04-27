import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:postgres/postgres.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class LicenseService {
  static final LicenseService _instance = LicenseService._internal();
  factory LicenseService() => _instance;
  LicenseService._internal();

  static const String _licenseTokenKey = 'signed_license_token';
  static const String _secretKey = 'dahliaspriver_security_salt_2024';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    wOptions: WindowsOptions(),
    lOptions: LinuxOptions(),
  );

  Connection? _connection;

  Future<Connection> _getConnection() async {
    if (_connection != null && _connection!.isOpen) {
      return _connection!;
    }

    // On supporte NEAN_URL (typo dans .env utilisateur) ou NEON_URL
    final String? url = dotenv.env['NEAN_URL'] ?? dotenv.env['NEON_URL'];

    if (url == null) {
      throw Exception("URL de connexion Neon non trouvée dans le fichier .env");
    }

    try {
      final uri = Uri.parse(url);
      final userInfo = uri.userInfo.split(':');
      final username = userInfo.isNotEmpty ? userInfo[0] : null;
      final password = userInfo.length > 1 ? userInfo[1] : null;

      _connection = await Connection.open(
        Endpoint(
          host: uri.host,
          port: uri.port != 0 ? uri.port : 5432,
          database: uri.path.substring(1), // remove initial /
          username: username,
          password: password,
        ),
        settings: const ConnectionSettings(sslMode: SslMode.require),
      );
      return _connection!;
    } catch (e) {
      debugPrint("Erreur connexion Neon: $e");
      rethrow;
    }
  }

  /// Récupère l'identifiant unique de la machine
  Future<String> getDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        return linuxInfo.machineId ?? "unknown_linux";
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        return windowsInfo.deviceId;
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        return macInfo.systemGUID ?? "unknown_mac";
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      }
    } catch (e) {
      debugPrint("Erreur récupération Device ID: $e");
    }
    return "unknown_device";
  }

  /// Génère un HMAC pour signer les données
  String _generateHMAC(String data) {
    final key = utf8.encode(_secretKey);
    final bytes = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    return hmac.convert(bytes).toString();
  }

  /// Sauvegarde la licence localement avec signature
  Future<void> _saveLocalLicense(String key, String deviceId) async {
    final data = {
      'key': key,
      'deviceId': deviceId,
      'timestamp': DateTime.now().toIso8601String(),
    };
    final jsonStr = jsonEncode(data);
    final signature = _generateHMAC(jsonStr);

    final payload = jsonEncode({'data': data, 'sig': signature});
    await _storage.write(key: _licenseTokenKey, value: payload);
  }

  /// Vérifie la licence localement (Hors-ligne)
  Future<bool> checkLicenseLocally() async {
    try {
      final payloadStr = await _storage.read(key: _licenseTokenKey);
      if (payloadStr == null) return false;

      final payload = jsonDecode(payloadStr);
      final data = payload['data'];
      final String signature = payload['sig'];

      // 1. Vérifier la signature
      final expectedSig = _generateHMAC(jsonEncode(data));
      if (signature != expectedSig) {
        debugPrint("ALERTE: Signature de licence invalide !");
        return false;
      }

      // 2. Vérifier le device ID
      final currentDeviceId = await getDeviceId();
      if (data['deviceId'] != currentDeviceId) {
        debugPrint("ALERTE: Licence transférée sur un autre appareil !");
        return false;
      }

      return true;
    } catch (e) {
      debugPrint("Erreur checkLicenseLocally: $e");
      return false;
    }
  }

  /// Synchronise le statut avec Neon si internet est disponible
  Future<void> syncLicenseWithServer() async {
    try {
      final payloadStr = await _storage.read(key: _licenseTokenKey);
      if (payloadStr == null) return;

      final payload = jsonDecode(payloadStr);
      final String licenseKey = payload['data']['key'];

      final conn = await _getConnection();
      final result = await conn.execute(
        Sql.named('SELECT active FROM licence WHERE key = @key'),
        parameters: {'key': licenseKey},
      );

      if (result.isNotEmpty) {
        final bool isActive = result.first[0] as bool;
        if (!isActive) {
          debugPrint("Licence révoquée par le serveur. Nettoyage local.");
          await _storage.delete(key: _licenseTokenKey);
        } else {
          debugPrint("Licence confirmée par le serveur.");
        }
      }
    } catch (e) {
      // Échec silencieux si pas d'internet
      debugPrint("Vérification online ignorée (Hors-ligne)");
    }
  }

  /// Vérifie et active la licence
  Future<Map<String, dynamic>> verifyAndActivateLicense({
    required String licenseKey,
    required Map<String, dynamic> schoolData,
  }) async {
    try {
      await setupDatabase();
      final conn = await _getConnection();
      final deviceId = await getDeviceId();

      // 1. Vérifier si la licence existe
      final result = await conn.execute(
        Sql.named('SELECT * FROM licence WHERE key = @key'),
        parameters: {'key': licenseKey},
      );

      if (result.isEmpty) {
        return {'success': false, 'message': "Clé de licence inexistante."};
      }

      final row = result.first.toColumnMap();
      final bool isActiveOnline = row['active'] == true;
      final String? dbDeviceId = row['device_id'];

      // 2. Si déjà active, vérifier le device_id
      if (isActiveOnline) {
        if (dbDeviceId == deviceId) {
          await _saveLocalLicense(licenseKey, deviceId);
          return {
            'success': true,
            'message': "Licence valide (Même appareil).",
            'id_ecole': row['id_ecole'],
          };
        } else {
          return {
            'success': false,
            'message': "Cette licence est déjà utilisée sur un autre appareil.",
          };
        }
      }

      // 3. Activation initiale
      final schoolResult = await conn.execute(
        Sql.named(
          'INSERT INTO ecole (nom, adresse, telephone, email, ville) '
          'VALUES (@nom, @adresse, @telephone, @email, @ville) '
          'RETURNING id',
        ),
        parameters: {
          'nom': schoolData['nom'] ?? 'Inconnu',
          'adresse': schoolData['adresse'] ?? '',
          'telephone': schoolData['telephone'] ?? '',
          'email': schoolData['email'] ?? '',
          'ville': schoolData['ville'] ?? '',
        },
      );

      final int schoolId = schoolResult.first[0] as int;

      await conn.execute(
        Sql.named(
          'UPDATE licence SET '
          'active = true, '
          'id_ecole = @schoolId, '
          'device_id = @deviceId, '
          'activated_at = @now '
          'WHERE key = @key',
        ),
        parameters: {
          'schoolId': schoolId,
          'deviceId': deviceId,
          'now': DateTime.now().toUtc(),
          'key': licenseKey,
        },
      );

      // Sauvegarde sécurisée locale
      await _saveLocalLicense(licenseKey, deviceId);

      return {
        'success': true,
        'message': "Licence activée avec succès !",
        'id_ecole': schoolId,
      };
    } on SocketException {
      return {
        'success': false,
        'message':
            "Pas de connexion internet. L'activation nécessite d'être en ligne.",
      };
    } catch (e) {
      debugPrint("Erreur activation: $e");
      String userMessage = "Une erreur est survenue lors de l'activation.";

      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('connection refused') ||
          errorStr.contains('timeout')) {
        userMessage = "Serveur de licence injoignable. Réessayez plus tard.";
      } else if (errorStr.contains('password authentication failed')) {
        userMessage = "Problème d'authentification avec le serveur distant.";
      } else if (errorStr.contains('relation') &&
          errorStr.contains('does not exist')) {
        userMessage = "Erreur de structure de base de données distante.";
      }

      return {'success': false, 'message': userMessage};
    }
  }

  /// Pour l'administration (Création des tables si besoin)
  Future<void> setupDatabase() async {
    final conn = await _getConnection();
    try {
      await conn.execute('''
        CREATE TABLE IF NOT EXISTS ecole (
          id SERIAL PRIMARY KEY,
          nom TEXT NOT NULL,
          adresse TEXT,
          telephone TEXT,
          email TEXT,
          ville TEXT,
          pays TEXT DEFAULT 'Guinée',
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
      ''');

      await conn.execute('''
        CREATE TABLE IF NOT EXISTS licence (
          id SERIAL PRIMARY KEY,
          key TEXT UNIQUE NOT NULL,
          id_ecole INTEGER REFERENCES ecole(id),
          active BOOLEAN DEFAULT FALSE,
          device_id TEXT,
          activated_at TIMESTAMP,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
      ''');
      debugPrint("Tables Neon configurées avec succès.");
    } catch (e) {
      debugPrint("Erreur setup Neon: $e");
    }
  }

  Future<void> close() async {
    await _connection?.close();
  }
}
