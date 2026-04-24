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

  Future<int> checkConflicts(
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
      SELECT COUNT(*) as count FROM ${EmploiDuTempsSchema.tableName}
      WHERE jour_semaine = ? AND annee_scolaire_id = ?
      AND (
        (heure_debut < ? AND heure_fin > ?) OR
        (heure_debut < ? AND heure_fin > ?) OR
        (heure_debut >= ? AND heure_fin <= ?)
      )
    ''';
    List<dynamic> args = [jour, anneeId, fin, debut, fin, debut, debut, fin];

    if (enseignantId != null && classeId != null) {
      queryStr += ' AND (enseignant_id = ? OR classe_id = ?)';
      args.addAll([enseignantId, classeId]);
    } else if (enseignantId != null) {
      queryStr += ' AND enseignant_id = ?';
      args.add(enseignantId);
    } else if (classeId != null) {
      queryStr += ' AND classe_id = ?';
      args.add(classeId);
    }

    if (excludeId != null) {
      queryStr += ' AND id != ?';
      args.add(excludeId);
    }

    final executor = txn ?? db;
    final result = await executor.rawQuery(queryStr, args);
    return Sqflite.firstIntValue(result) ?? 0;
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
}
