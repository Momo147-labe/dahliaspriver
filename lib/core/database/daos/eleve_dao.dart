import 'package:sqflite/sqflite.dart';
import '../schemas/eleve_schema.dart';
import 'base_dao.dart';

class EleveDao extends BaseDao {
  EleveDao(Database db) : super(db);

  Future<List<Map<String, dynamic>>> getElevesByClasse(int classeId) async {
    return await db.rawQuery(
      '''
      SELECT e.*, c.nom as classe_nom 
      FROM ${EleveSchema.tableName} e
      LEFT JOIN classe c ON e.classe_id = c.id
      WHERE e.classe_id = ?
    ''',
      [classeId],
    );
  }

  Future<List<Map<String, dynamic>>> getElevesByAnnee(int anneeId) async {
    return await db.query(
      EleveSchema.tableName,
      where: 'annee_scolaire_id = ?',
      whereArgs: [anneeId],
      orderBy: 'nom, prenom',
    );
  }

  Future<List<Map<String, dynamic>>> getElevesPaginated({
    required int anneeId,
    required int limit,
    required int offset,
    String? search,
    String? selectedClass,
    String? selectedStatus,
    String? selectedGender,
  }) async {
    List<String> whereClauses = ['e.annee_scolaire_id = ?'];
    List<dynamic> whereArgs = [anneeId];

    if (search != null && search.isNotEmpty) {
      whereClauses.add(
        '(e.nom LIKE ? OR e.prenom LIKE ? OR e.matricule LIKE ?)',
      );
      whereArgs.addAll(['%$search%', '%$search%', '%$search%']);
    }

    if (selectedClass != null && selectedClass != 'Toutes les classes') {
      whereClauses.add('c.nom = ?');
      whereArgs.add(selectedClass);
    }

    if (selectedStatus != null && selectedStatus != 'Tous les statuts') {
      whereClauses.add('e.statut = ?');
      whereArgs.add(selectedStatus.toLowerCase());
    }

    if (selectedGender != null && selectedGender != 'Tous les sexes') {
      whereClauses.add('e.sexe = ?');
      whereArgs.add(selectedGender == 'Masculin' ? 'M' : 'F');
    }

    final String whereString = whereClauses.join(' AND ');

    return await db.rawQuery(
      '''
      SELECT e.*, c.nom as classe_nom 
      FROM ${EleveSchema.tableName} e
      LEFT JOIN classe c ON e.classe_id = c.id
      WHERE $whereString
      ORDER BY e.nom ASC, e.prenom ASC
      LIMIT ? OFFSET ?
    ''',
      [...whereArgs, limit, offset],
    );
  }

  Future<int> getElevesFilteredCount({
    required int anneeId,
    String? search,
    String? selectedClass,
    String? selectedStatus,
    String? selectedGender,
  }) async {
    List<String> whereClauses = ['e.annee_scolaire_id = ?'];
    List<dynamic> whereArgs = [anneeId];

    if (search != null && search.isNotEmpty) {
      whereClauses.add(
        '(e.nom LIKE ? OR e.prenom LIKE ? OR e.matricule LIKE ?)',
      );
      whereArgs.addAll(['%$search%', '%$search%', '%$search%']);
    }

    if (selectedClass != null && selectedClass != 'Toutes les classes') {
      whereClauses.add('c.nom = ?');
      whereArgs.add(selectedClass);
    }

    if (selectedStatus != null && selectedStatus != 'Tous les statuts') {
      whereClauses.add('e.statut = ?');
      whereArgs.add(selectedStatus.toLowerCase());
    }

    if (selectedGender != null && selectedGender != 'Tous les sexes') {
      whereClauses.add('e.sexe = ?');
      whereArgs.add(selectedGender == 'Masculin' ? 'M' : 'F');
    }

    final String whereString = whereClauses.join(' AND ');

    final result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM ${EleveSchema.tableName} e
      LEFT JOIN classe c ON e.classe_id = c.id
      WHERE $whereString
    ''', whereArgs);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Map<String, dynamic>>> searchEleves(String query) async {
    return await db.rawQuery(
      '''
      SELECT e.*, c.nom as classe_nom 
      FROM ${EleveSchema.tableName} e
      LEFT JOIN classe c ON e.classe_id = c.id
      WHERE e.nom LIKE ? OR e.prenom LIKE ? OR e.matricule LIKE ?
      LIMIT 20
    ''',
      ['%$query%', '%$query%', '%$query%'],
    );
  }

  Future<List<Map<String, dynamic>>> getInitialSearchData() async {
    return await db.rawQuery('''
      SELECT e.*, c.nom as classe_nom 
      FROM ${EleveSchema.tableName} e
      LEFT JOIN classe c ON e.classe_id = c.id
      LIMIT 20
    ''');
  }

  Future<Map<String, dynamic>?> getEleveById(int id) async {
    final result = await db.rawQuery(
      '''
      SELECT e.*, c.nom as classe_nom, a.libelle as annee_nom
      FROM ${EleveSchema.tableName} e
      LEFT JOIN classe c ON e.classe_id = c.id
      LEFT JOIN annee_scolaire a ON e.annee_scolaire_id = a.id
      WHERE e.id = ?
    ''',
      [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getEleveParcours(int id) async {
    return await db.rawQuery(
      '''
      SELECT p.*, c.nom as classe_nom, a.libelle as annee_nom
      FROM eleve_parcours p
      JOIN classe c ON p.classe_id = c.id
      JOIN annee_scolaire a ON p.annee_scolaire_id = a.id
      WHERE p.eleve_id = ?
      ORDER BY a.date_debut DESC
    ''',
      [id],
    );
  }

  Future<int> insertEleve(Map<String, dynamic> eleve) async {
    return await db.insert(EleveSchema.tableName, eleve);
  }

  Future<int> updateEleve(int id, Map<String, dynamic> eleve) async {
    eleve['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      EleveSchema.tableName,
      eleve,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteEleve(int id) async {
    return await db.delete(
      EleveSchema.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getEleveCount(int anneeId) async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${EleveSchema.tableName} WHERE annee_scolaire_id = ?',
      [anneeId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Analytics
  Future<Map<String, dynamic>> getStudentAnalytics(
    int currentYearId, {
    int? previousYearId,
  }) async {
    final currentStats = await db.rawQuery(
      '''
      SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN sexe = 'M' THEN 1 ELSE 0 END) as males,
        SUM(CASE WHEN sexe = 'F' THEN 1 ELSE 0 END) as females,
        SUM(CASE WHEN statut = 'inscrit' THEN 1 ELSE 0 END) as new_students,
        SUM(CASE WHEN statut = 'reinscrit' THEN 1 ELSE 0 END) as returning_students,
        AVG(CASE 
          WHEN date_naissance IS NOT NULL AND date_naissance != '' 
          THEN (strftime('%Y', 'now') - strftime('%Y', date_naissance)) 
          ELSE NULL 
        END) as average_age
      FROM ${EleveSchema.tableName}
      WHERE annee_scolaire_id = ?
    ''',
      [currentYearId],
    );

    final cycleDistribution = await db.rawQuery(
      '''
      SELECT cy.nom as cycle, COUNT(e.id) as count
      FROM ${EleveSchema.tableName} e
      JOIN classe c ON e.classe_id = c.id
      JOIN cycles_scolaires cy ON c.cycle_id = cy.id
      WHERE e.annee_scolaire_id = ?
      GROUP BY cy.nom
    ''',
      [currentYearId],
    );

    final classDistribution = await db.rawQuery(
      '''
      SELECT c.nom as classe, COUNT(e.id) as count
      FROM ${EleveSchema.tableName} e
      JOIN classe c ON e.classe_id = c.id
      WHERE e.annee_scolaire_id = ?
      GROUP BY c.nom
    ''',
      [currentYearId],
    );

    return {
      'stats': currentStats.first,
      'cycleDistribution': cycleDistribution,
      'classDistribution': classDistribution,
    };
  }

  Future<List<Map<String, dynamic>>> getStudentPaymentControlData(
    int anneeId,
  ) async {
    return await db.rawQuery(
      '''
      SELECT 
        e.id, e.nom, e.prenom, e.matricule, e.statut as eleve_statut, e.photo,
        c.nom as classe_nom,
        fs.inscription, fs.reinscription, fs.tranche1, fs.tranche2, fs.tranche3, fs.montant_total,
        COALESCE(p.montant_paye, 0) as total_paye
      FROM ${EleveSchema.tableName} e
      JOIN classe c ON e.classe_id = c.id
      LEFT JOIN frais_scolarite fs ON e.classe_id = fs.classe_id AND e.annee_scolaire_id = fs.annee_scolaire_id
      LEFT JOIN paiement p ON p.eleve_id = e.id AND p.annee_scolaire_id = e.annee_scolaire_id
      WHERE e.annee_scolaire_id = ?
      ORDER BY c.nom ASC, e.nom ASC
    ''',
      [anneeId],
    );
  }

  Future<List<Map<String, dynamic>>> getGenderStats(int anneeId) async {
    return await db.rawQuery(
      'SELECT sexe, COUNT(*) as count FROM ${EleveSchema.tableName} WHERE annee_scolaire_id = ? GROUP BY sexe',
      [anneeId],
    );
  }

  Future<List<Map<String, dynamic>>> getCycleStats(int anneeId) async {
    return await db.rawQuery(
      '''
      SELECT cy.nom as cycle, COUNT(e.id) as count 
      FROM ${EleveSchema.tableName} e 
      JOIN classe c ON e.classe_id = c.id 
      JOIN cycles_scolaires cy ON c.cycle_id = cy.id
      WHERE e.annee_scolaire_id = ? 
      GROUP BY cy.nom
      ''',
      [anneeId],
    );
  }

  Future<List<Map<String, dynamic>>> getClassStats(int anneeId) async {
    return await db.rawQuery(
      '''
      SELECT c.nom, COUNT(e.id) as count 
      FROM ${EleveSchema.tableName} e 
      JOIN classe c ON e.classe_id = c.id 
      WHERE e.annee_scolaire_id = ? 
      GROUP BY c.nom
      ORDER BY count DESC
      LIMIT 10
      ''',
      [anneeId],
    );
  }

  Future<void> promoteStudents(
    int anneeId,
    int nouvelleAnneeId,
    Future<double> Function(int, int) calculateMoyenne,
    Future<Map<String, dynamic>?> Function(int) getClasse,
    double defaultPassingGrade,
  ) async {
    final eleves = await getElevesByAnnee(anneeId);

    for (var eleve in eleves) {
      double moyenne = await calculateMoyenne(eleve['id'] as int, anneeId);
      final classe = await getClasse(eleve['classe_id'] as int);
      int? nextClassId = classe?['next_class_id'] as int?;
      bool isFinal = classe?['is_final_class'] == 1;

      if (moyenne >= defaultPassingGrade && !isFinal && nextClassId != null) {
        await db.update(
          EleveSchema.tableName,
          {'classe_id': nextClassId, 'annee_scolaire_id': nouvelleAnneeId},
          where: 'id = ?',
          whereArgs: [eleve['id']],
        );
      } else if (isFinal) {
        await db.update(
          EleveSchema.tableName,
          {'statut': 'sorti'},
          where: 'id = ?',
          whereArgs: [eleve['id']],
        );
      } else {
        await db.update(
          EleveSchema.tableName,
          {
            'classe_id': eleve['classe_id'],
            'annee_scolaire_id': nouvelleAnneeId,
          },
          where: 'id = ?',
          whereArgs: [eleve['id']],
        );
      }
    }
  }

  Future<int> updateEleveStatut(int id, String statut) async {
    return await db.update(
      EleveSchema.tableName,
      {'statut': statut, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
