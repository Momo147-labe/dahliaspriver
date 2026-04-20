import 'package:sqflite/sqflite.dart';
import '../schemas/classe_schema.dart';
import 'base_dao.dart';

class ClasseDao extends BaseDao {
  ClasseDao(Database db) : super(db);

  Future<List<Map<String, dynamic>>> getClassesByAnnee([int? anneeId]) async {
    // Classes sont maintenant globales, on ignore anneeId pour la liste
    return await db.query(ClasseSchema.tableName, orderBy: 'nom ASC');
  }

  Future<List<Map<String, dynamic>>> getClassesByNiveau(int niveauId) async {
    return await db.query(
      ClasseSchema.tableName,
      where: 'niveau_id = ?',
      whereArgs: [niveauId],
      orderBy: 'nom ASC',
    );
  }

  Future<Map<String, dynamic>?> getClasseById(int id) async {
    final result = await db.query(
      ClasseSchema.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<Map<String, dynamic>?> getClasseWithCycle(int classId) async {
    final results = await db.rawQuery(
      '''
      SELECT c.*, cy.nom as cycle_nom, cy.note_min, cy.note_max, cy.moyenne_passage, cy.id as cycle_id
      FROM ${ClasseSchema.tableName} c
      LEFT JOIN cycles_scolaires cy ON c.cycle_id = cy.id
      WHERE c.id = ?
    ''',
      [classId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> insertClasse(Map<String, dynamic> classe) async {
    return await db.insert(ClasseSchema.tableName, classe);
  }

  Future<int> updateClasse(int id, Map<String, dynamic> classe) async {
    classe['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      ClasseSchema.tableName,
      classe,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteClasse(int id) async {
    return await db.delete(
      ClasseSchema.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getClassesForReports() async {
    return await db.rawQuery('''
      SELECT c.*, 
             (SELECT COUNT(*) FROM eleve WHERE classe_id = c.id) as student_count
      FROM ${ClasseSchema.tableName} c
      ORDER BY c.nom
    ''');
  }

  Future<List<Map<String, dynamic>>> getSubjectsByClass(
    int classeId, [
    int? anneeId,
  ]) async {
    return await db.rawQuery(
      '''
      SELECT m.*, cm.coefficient
      FROM matiere m
      JOIN classe_matiere cm ON m.id = cm.matiere_id
      WHERE cm.classe_id = ?
      ORDER BY m.nom ASC
    ''',
      [classeId],
    );
  }

  Future<void> saveClassSubjects(
    int classeId,
    int? anneeId,
    List<Map<String, dynamic>> subjectsData,
  ) async {
    await db.transaction((txn) async {
      // Remove existing (globally)
      await txn.delete(
        'classe_matiere',
        where: 'classe_id = ?',
        whereArgs: [classeId],
      );

      // Insert new
      for (var data in subjectsData) {
        await txn.insert('classe_matiere', {
          'classe_id': classeId,
          'matiere_id': data['id'],
          'coefficient': data['coefficient'] ?? 1.0,
        });
      }
    });
  }

  Future<int> getClasseCount([int? anneeId]) async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${ClasseSchema.tableName}',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Map<String, dynamic>> getClassAnalytics(
    int currentYearId,
    int? previousYearId,
  ) async {
    // Current year class data
    final currentClasses = await db.rawQuery(
      '''
      SELECT 
        COUNT(DISTINCT c.id) as total_classes,
        AVG(student_counts.count) as avg_class_size,
        MAX(student_counts.count) as max_class_size,
        MIN(student_counts.count) as min_class_size
      FROM ${ClasseSchema.tableName} c
      LEFT JOIN (
        SELECT classe_id, COUNT(*) as count
        FROM eleve
        WHERE annee_scolaire_id = ?
        GROUP BY classe_id
      ) student_counts ON c.id = student_counts.classe_id
    ''',
      [currentYearId],
    );

    // Previous year class data
    Map<String, dynamic>? previousClasses;
    if (previousYearId != null) {
      final prevResult = await db.rawQuery(
        '''
        SELECT 
          COUNT(DISTINCT c.id) as total_classes,
          AVG(student_counts.count) as avg_class_size
        FROM ${ClasseSchema.tableName} c
        LEFT JOIN (
          SELECT classe_id, COUNT(*) as count
          FROM eleve
          WHERE annee_scolaire_id = ?
          GROUP BY classe_id
        ) student_counts ON c.id = student_counts.classe_id
      ''',
        [previousYearId],
      );
      previousClasses = prevResult.first;
    }

    // Distribution by cycle (current year)
    final cycleDistribution = await db.rawQuery(
      '''
      SELECT 
        cy.nom as cycle,
        COUNT(DISTINCT c.id) as class_count,
        COUNT(e.id) as student_count
      FROM ${ClasseSchema.tableName} c
      JOIN cycles_scolaires cy ON c.cycle_id = cy.id
      LEFT JOIN eleve e ON c.id = e.classe_id AND e.annee_scolaire_id = ?
      GROUP BY cy.nom
    ''',
      [currentYearId],
    );

    // Distribution by level (current year)
    final levelDistribution = await db.rawQuery(
      '''
      SELECT 
        n.nom as niveau,
        COUNT(DISTINCT c.id) as class_count,
        COUNT(e.id) as student_count
      FROM ${ClasseSchema.tableName} c
      JOIN niveaux n ON c.niveau_id = n.id
      LEFT JOIN eleve e ON c.id = e.classe_id AND e.annee_scolaire_id = ?
      GROUP BY n.nom
      ORDER BY n.ordre
    ''',
      [currentYearId],
    );

    return {
      'current': currentClasses.first,
      'previous': previousClasses,
      'cycleDistribution': cycleDistribution,
      'levelDistribution': levelDistribution,
    };
  }

  Future<bool> isSubjectInClass(
    int classeId,
    int matiereId, [
    int? anneeId,
  ]) async {
    final result = await db.query(
      'classe_matiere',
      where: 'classe_id = ? AND matiere_id = ?',
      whereArgs: [classeId, matiereId],
    );
    return result.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getClassesWithStats(int anneeId) async {
    return await db.rawQuery(
      '''
      SELECT 
        c.*, 
        cy.nom as cycle_nom,
        nv.nom as niveau_nom,
        e.nom as prof_principal_nom,
        e.prenom as prof_principal_prenom,
        (SELECT COUNT(*) FROM eleve WHERE classe_id = c.id AND annee_scolaire_id = ?) as eleve_count
      FROM ${ClasseSchema.tableName} c
      LEFT JOIN cycles_scolaires cy ON c.cycle_id = cy.id
      LEFT JOIN niveaux nv ON c.niveau_id = nv.id
      LEFT JOIN enseignant e ON c.prof_principal_id = e.id
      ORDER BY c.nom ASC
    ''',
      [anneeId],
    );
  }
}
