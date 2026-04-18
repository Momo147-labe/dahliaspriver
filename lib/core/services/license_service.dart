import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:postgres/postgres.dart';
import 'package:device_info_plus/device_info_plus.dart';

class LicenseService {
  static final LicenseService _instance = LicenseService._internal();
  factory LicenseService() => _instance;
  LicenseService._internal();

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

  /// Vérifie et active la licence
  Future<Map<String, dynamic>> verifyAndActivateLicense({
    required String licenseKey,
    required Map<String, dynamic> schoolData,
  }) async {
    await setupDatabase(); // S'assure que les tables existent
    final conn = await _getConnection();
    final deviceId = await getDeviceId();

    try {
      // 1. Vérifier si la licence existe
      final result = await conn.execute(
        Sql.named('SELECT * FROM licence WHERE key = @key'),
        parameters: {'key': licenseKey},
      );

      if (result.isEmpty) {
        return {'success': false, 'message': "Clé de licence inexistante."};
      }

      final row = result.first.toColumnMap();
      final bool isActive = row['active'] == true;
      final String? dbDeviceId = row['device_id'];

      // 2. Si déjà active, vérifier le device_id
      if (isActive) {
        if (dbDeviceId == deviceId) {
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

      // 3. Si non active, procéder à l'activation
      // a. Créer l'école
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

      // b. Mettre à jour la licence
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

      return {
        'success': true,
        'message': "Licence activée avec succès !",
        'id_ecole': schoolId,
      };
    } catch (e) {
      debugPrint("Erreur lors de la vérification de licence: $e");
      return {'success': false, 'message': "Erreur technique: $e"};
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
