import 'package:sqflite/sqflite.dart';
import '../schemas/enseignant_schema.dart';
import 'base_dao.dart';

class EnseignantDao extends BaseDao {
  EnseignantDao(Database db) : super(db);

  Future<List<Map<String, dynamic>>> getEnseignants() async {
    return await db.query(
      EnseignantSchema.tableName,
      orderBy: 'nom ASC, prenom ASC',
    );
  }

  Future<Map<String, dynamic>?> getEnseignantById(int id) async {
    final result = await db.query(
      EnseignantSchema.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> insertEnseignant(Map<String, dynamic> enseignant) async {
    return await db.insert(EnseignantSchema.tableName, enseignant);
  }

  Future<int> updateEnseignant(int id, Map<String, dynamic> enseignant) async {
    enseignant['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      EnseignantSchema.tableName,
      enseignant,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getClassesByTeacher(
    int enseignantId,
    int anneeId,
  ) async {
    return await db.rawQuery(
      '''
      SELECT DISTINCT c.nom, cy.nom as cycle, n.nom as niveau
      FROM classe c
      JOIN cycles_scolaires cy ON c.cycle_id = cy.id
      JOIN niveaux n ON c.niveau_id = n.id
      JOIN attribution_enseignant ae ON c.id = ae.classe_id
      WHERE ae.enseignant_id = ? AND ae.annee_scolaire_id = ?
      ORDER BY c.nom ASC
    ''',
      [enseignantId, anneeId],
    );
  }

  Future<Map<String, dynamic>?> getAssignedTeacher(
    int classeId,
    int matiereId,
    int anneeId,
  ) async {
    final results = await db.rawQuery(
      '''
      SELECT e.*
      FROM attribution_enseignant ae
      JOIN ${EnseignantSchema.tableName} e ON ae.enseignant_id = e.id
      WHERE ae.classe_id = ? AND ae.matiere_id = ? AND ae.annee_scolaire_id = ?
    ''',
      [classeId, matiereId, anneeId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>> getEnseignantsStats() async {
    final result = await db.rawQuery('''
      SELECT 
        (SELECT COUNT(*) FROM ${EnseignantSchema.tableName}) as total_enseignants,
        (SELECT COUNT(DISTINCT specialite) FROM ${EnseignantSchema.tableName} WHERE specialite IS NOT NULL AND specialite != '') as total_specialites,
        (SELECT COUNT(*) FROM emploi_du_temps) as assignments_count
    ''');
    return result.first;
  }

  Future<void> saveAllAttributions(
    int classeId,
    int? anneeId,
    Map<int, int?> assignments,
  ) async {
    await db.transaction((txn) async {
      for (var entry in assignments.entries) {
        if (entry.value != null) {
          await txn.insert('attribution_enseignant', {
            'classe_id': classeId,
            'matiere_id': entry.key,
            'enseignant_id': entry.value,
            'annee_scolaire_id': anneeId,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  Future<void> saveAttribution(Map<String, dynamic> attribution) async {
    await db.insert(
      'attribution_enseignant',
      attribution,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAttributionsByClass(
    int classeId, [
    int? anneeId,
  ]) async {
    final String whereClause = anneeId != null
        ? 'WHERE ae.classe_id = ? AND ae.annee_scolaire_id = ?'
        : 'WHERE ae.classe_id = ?';
    final List<dynamic> whereArgs = anneeId != null
        ? [classeId, anneeId]
        : [classeId];

    return await db.rawQuery('''
      SELECT ae.*, e.nom, e.prenom, m.nom as matiere_nom
      FROM attribution_enseignant ae
      JOIN ${EnseignantSchema.tableName} e ON ae.enseignant_id = e.id
      JOIN matiere m ON ae.matiere_id = m.id
      $whereClause
    ''', whereArgs);
  }

  Future<Map<String, dynamic>> getTeacherAnalytics(
    int currentYearId, {
    int? previousYearId,
  }) async {
    final teachers = await getEnseignants();
    final totalTeachers = teachers.length;

    // Get student count for current year
    final currentStudentCountResult = await db.rawQuery(
      'SELECT COUNT(*) as total FROM eleve WHERE annee_scolaire_id = ?',
      [currentYearId],
    );
    final currentStudents =
        Sqflite.firstIntValue(currentStudentCountResult) ?? 0;

    // Get student count for previous year
    int previousStudents = 0;
    if (previousYearId != null) {
      final prevResult = await db.rawQuery(
        'SELECT COUNT(*) as total FROM eleve WHERE annee_scolaire_id = ?',
        [previousYearId],
      );
      previousStudents = Sqflite.firstIntValue(prevResult) ?? 0;
    }

    // Speciality distribution
    final specialityDistribution = await db.rawQuery('''
      SELECT specialite, COUNT(*) as count
      FROM ${EnseignantSchema.tableName}
      WHERE specialite IS NOT NULL AND specialite != ''
      GROUP BY specialite
      ORDER BY count DESC
    ''');

    return {
      'totalTeachers': totalTeachers,
      'current': {
        'studentTeacherRatio': totalTeachers > 0
            ? currentStudents / totalTeachers
            : 0.0,
        'students': currentStudents,
      },
      'previous': previousYearId != null
          ? {
              'studentTeacherRatio': totalTeachers > 0
                  ? previousStudents / totalTeachers
                  : 0.0,
              'students': previousStudents,
            }
          : null,
      'specialityDistribution': specialityDistribution,
    };
  }
}
