import 'package:sqflite/sqflite.dart';
import '../schemas/emploi_du_temps_schema.dart';
import 'base_dao.dart';

class TimetableDao extends BaseDao {
  TimetableDao(Database db) : super(db);

  Future<List<Map<String, dynamic>>> getTimetableByClass(
    int classId,
    int anneeId,
  ) async {
    return await db.rawQuery(
      '''
      SELECT edt.*, m.nom as matiere_nom, e.nom as enseignant_nom, e.prenom as enseignant_prenom
      FROM ${EmploiDuTempsSchema.tableName} edt
      JOIN matiere m ON edt.matiere_id = m.id
      LEFT JOIN enseignant e ON edt.enseignant_id = e.id
      WHERE edt.classe_id = ? AND edt.annee_scolaire_id = ?
      ORDER BY edt.jour_semaine, edt.heure_debut
    ''',
      [classId, anneeId],
    );
  }

  Future<Map<String, dynamic>?> checkConflicts(
    int jour,
    String debut,
    String fin, {
    int? enseignantId,
    int? classeId,
    int? excludeId,
    int? anneeId,
    Transaction? txn,
  }) async {
    String queryStr =
        '''
      SELECT edt.*, m.nom as matiere_nom, e.nom as enseignant_nom, e.prenom as enseignant_prenom, c.nom as classe_nom
      FROM ${EmploiDuTempsSchema.tableName} edt
      JOIN matiere m ON edt.matiere_id = m.id
      JOIN classe c ON edt.classe_id = c.id
      LEFT JOIN enseignant e ON edt.enseignant_id = e.id
      WHERE edt.jour_semaine = ? AND edt.annee_scolaire_id = ?
      AND (
        (edt.heure_debut < ? AND edt.heure_fin > ?) OR
        (edt.heure_debut < ? AND edt.heure_fin > ?) OR
        (edt.heure_debut >= ? AND edt.heure_fin <= ?)
      )
    ''';
    List<dynamic> args = [jour, anneeId, fin, debut, fin, debut, debut, fin];

    if (enseignantId != null && classeId != null) {
      queryStr += ' AND (edt.enseignant_id = ? OR edt.classe_id = ?)';
      args.addAll([enseignantId, classeId]);
    } else if (enseignantId != null) {
      queryStr += ' AND edt.enseignant_id = ?';
      args.add(enseignantId);
    } else if (classeId != null) {
      queryStr += ' AND edt.classe_id = ?';
      args.add(classeId);
    }

    if (excludeId != null) {
      queryStr += ' AND edt.id != ?';
      args.add(excludeId);
    }

    queryStr += ' LIMIT 1';

    final executor = txn ?? db;
    final result = await executor.rawQuery(queryStr, args);
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> bulkSaveTimetableEntries(
    List<Map<String, dynamic>> entries,
  ) async {
    await db.transaction((txn) async {
      for (var entry in entries) {
        // En mode bulk save, si c'est une mise à jour ou un ajout on peut insérer
        // (La logique de conflit est déjà validée côté DAO si on veut, ou on peut lancer une exception ici)
        // Mais AddScheduleModal utilise checkConflicts pour l'UI, alors on l'insère / met à jour ici.
        if (entry['id'] != null) {
          entry['updated_at'] = DateTime.now().toIso8601String();
          await txn.update(
            EmploiDuTempsSchema.tableName,
            entry,
            where: 'id = ?',
            whereArgs: [entry['id']],
          );
        } else {
          await txn.insert(EmploiDuTempsSchema.tableName, entry);
        }
      }
    });
  }

  Future<int> insertTimetableEntry(Map<String, dynamic> entry) async {
    return await db.insert(EmploiDuTempsSchema.tableName, entry);
  }

  Future<int> updateTimetableEntry(int id, Map<String, dynamic> entry) async {
    entry['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      EmploiDuTempsSchema.tableName,
      entry,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTimetableEntry(int id) async {
    return await db.delete(
      EmploiDuTempsSchema.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTimetableByClass(int classId, int anneeId) async {
    return await db.delete(
      EmploiDuTempsSchema.tableName,
      where: 'classe_id = ? AND annee_scolaire_id = ?',
      whereArgs: [classId, anneeId],
    );
  }

  Future<double> getTeacherWeeklyHours(int teacherId, int anneeId) async {
    final result = await db.rawQuery(
      '''
      SELECT heure_debut, heure_fin 
      FROM ${EmploiDuTempsSchema.tableName}
      WHERE enseignant_id = ? AND annee_scolaire_id = ?
    ''',
      [teacherId, anneeId],
    );

    double totalHours = 0.0;
    for (var row in result) {
      final debut = row['heure_debut'] as String;
      final fin = row['heure_fin'] as String;

      final startParts = debut.split(':');
      final endParts = fin.split(':');

      if (startParts.length == 2 && endParts.length == 2) {
        final start = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
        final end = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
        totalHours += (end - start) / 60.0;
      }
    }
    return totalHours;
  }
}
