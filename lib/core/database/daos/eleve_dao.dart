import 'package:sqflite/sqflite.dart';
import '../schemas/eleve_schema.dart';
import 'base_dao.dart';

class EleveDao extends BaseDao {
  EleveDao(Database db) : super(db);

  Future<List<Map<String, dynamic>>> getElevesByClasse(
    int classeId,
    int anneeId,
  ) async {
    return await db.rawQuery(
      '''
      SELECT e.*, c.nom as classe_nom 
      FROM ${EleveSchema.tableName} e
      JOIN eleve_parcours p ON e.id = p.eleve_id AND p.annee_scolaire_id = ?
      LEFT JOIN classe c ON p.classe_id = c.id
      WHERE p.classe_id = ?
    ''',
      [anneeId, classeId],
    );
  }

  Future<List<Map<String, dynamic>>> getElevesByAnnee(int anneeId) async {
    return await db.rawQuery(
      '''
      SELECT e.*, p.classe_id, p.annee_scolaire_id
      FROM ${EleveSchema.tableName} e
      JOIN eleve_parcours p ON e.id = p.eleve_id
      WHERE p.annee_scolaire_id = ?
      ORDER BY e.nom, e.prenom
    ''',
      [anneeId],
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
    List<String> whereClauses = ['p.annee_scolaire_id = ?'];
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
      SELECT e.*, 
             c.nom as classe_nom, 
             p.moyenne, p.decision, p.confirmation_statut, p.type_inscription,
             p.classe_id as current_classe_id
      FROM ${EleveSchema.tableName} e
      JOIN eleve_parcours p ON e.id = p.eleve_id AND p.annee_scolaire_id = ?
      LEFT JOIN classe c ON p.classe_id = c.id
      WHERE $whereString
      ORDER BY e.nom ASC, e.prenom ASC
      LIMIT ? OFFSET ?
    ''',
      [anneeId, ...whereArgs, limit, offset],
    );
  }

  Future<int> getElevesFilteredCount({
    required int anneeId,
    String? search,
    String? selectedClass,
    String? selectedStatus,
    String? selectedGender,
  }) async {
    List<String> whereClauses = ['p.annee_scolaire_id = ?'];
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
      JOIN eleve_parcours p ON e.id = p.eleve_id
      LEFT JOIN classe c ON p.classe_id = c.id
      WHERE $whereString
    ''', whereArgs);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Map<String, dynamic>>> searchEleves(
    String query,
    int anneeId,
  ) async {
    return await db.rawQuery(
      '''
      SELECT e.*, c.nom as classe_nom,
             p.moyenne, p.decision, p.confirmation_statut, p.type_inscription
      FROM ${EleveSchema.tableName} e
      LEFT JOIN eleve_parcours p ON e.id = p.eleve_id AND p.annee_scolaire_id = ?
      LEFT JOIN classe c ON p.classe_id = c.id
      WHERE (e.nom LIKE ? OR e.prenom LIKE ? OR e.matricule LIKE ?)
      AND p.annee_scolaire_id IS NOT NULL
      LIMIT 20
    ''',
      [anneeId, '%$query%', '%$query%', '%$query%'],
    );
  }

  Future<List<Map<String, dynamic>>> getInitialSearchData(int anneeId) async {
    return await db.rawQuery(
      '''
      SELECT e.*, c.nom as classe_nom,
             p.moyenne, p.decision, p.confirmation_statut, p.type_inscription 
      FROM ${EleveSchema.tableName} e
      LEFT JOIN eleve_parcours p ON e.id = p.eleve_id AND p.annee_scolaire_id = ?
      LEFT JOIN classe c ON p.classe_id = c.id
      WHERE p.annee_scolaire_id IS NOT NULL
      LIMIT 20
    ''',
      [anneeId],
    );
  }

  Future<Map<String, dynamic>?> getEleveById(int id) async {
    final result = await db.rawQuery(
      '''
      SELECT e.*, c.nom as classe_nom, a.libelle as annee_nom
      FROM ${EleveSchema.tableName} e
      LEFT JOIN eleve_parcours p ON e.id = p.eleve_id AND e.annee_scolaire_id = p.annee_scolaire_id
      LEFT JOIN classe c ON p.classe_id = c.id
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
      SELECT p.*, c.nom as classe_nom, a.libelle as annee_nom,
             cy.note_max, cy.moyenne_passage
      FROM eleve_parcours p
      JOIN classe c ON p.classe_id = c.id
      JOIN annee_scolaire a ON p.annee_scolaire_id = a.id
      LEFT JOIN cycles_scolaires cy ON c.cycle_id = cy.id
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
      'SELECT COUNT(*) as count FROM eleve_parcours WHERE annee_scolaire_id = ?',
      [anneeId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Promeut une liste d'élèves vers une classe supérieure pour une nouvelle année.
  Future<void> executeBulkPromotion({
    required List<int> eleveIds,
    required int oldClasseId,
    required int oldAnneeId,
    required int newClasseId,
    required int newAnneeId,
    required String decision, // 'Admis' ou 'Redoublant'
    String confirmationStatut = 'En attente',
  }) async {
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();

      for (int eleveId in eleveIds) {
        // 1. Archiver la performance (moyenne et rang) pour l'année qui se termine
        // On récupère la moyenne calculée
        final averageResult = await txn.query(
          'averages',
          where: 'eleve_id = ? AND annee_scolaire_id = ?',
          whereArgs: [eleveId, oldAnneeId],
        );

        double? moyenne;
        int? rang;

        if (averageResult.isNotEmpty) {
          moyenne = (averageResult.first['moyenne'] as num?)?.toDouble();
          rang = averageResult.first['rang'] as int?;
        }

        // On met à jour ou crée le record pour l'année qui se termine avec moyenne, rang et décision
        final existingOld = await txn.query(
          'eleve_parcours',
          where: 'eleve_id = ? AND annee_scolaire_id = ?',
          whereArgs: [eleveId, oldAnneeId],
        );

        if (existingOld.isNotEmpty) {
          await txn.update(
            'eleve_parcours',
            {
              'decision': decision,
              'moyenne': moyenne,
              'rang': rang,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [existingOld.first['id']],
          );
        } else {
          await txn.insert('eleve_parcours', {
            'eleve_id': eleveId,
            'classe_id': oldClasseId,
            'annee_scolaire_id': oldAnneeId,
            'decision': decision,
            'moyenne': moyenne,
            'rang': rang,
            'updated_at': now,
            'created_at': now,
          });
        }

        // 2. Créer l'entrée pour la nouvelle année si elle n'existe pas déjà
        final existingNew = await txn.query(
          'eleve_parcours',
          where: 'eleve_id = ? AND annee_scolaire_id = ?',
          whereArgs: [eleveId, newAnneeId],
        );

        if (existingNew.isEmpty) {
          await txn.insert('eleve_parcours', {
            'eleve_id': eleveId,
            'classe_id': newClasseId,
            'annee_scolaire_id': newAnneeId,
            'confirmation_statut': confirmationStatut,
            'type_inscription': decision == 'Admis'
                ? 'Promotion'
                : 'Redoublement',
            'moyenne': null,
            'rang': null,
            'created_at': now,
            'updated_at': now,
          });
        }

        // 3. Supprimer d'éventuelles moyennes résiduelles pour la nouvelle année
        await txn.delete(
          'averages',
          where: 'eleve_id = ? AND annee_scolaire_id = ?',
          whereArgs: [eleveId, newAnneeId],
        );

        // 4. Mettre à jour le statut global de l'élève (optionnel, mais ne plus toucher à classe_id)
        await txn.update(
          EleveSchema.tableName,
          {'statut': 'reinscrit', 'updated_at': now},
          where: 'id = ?',
          whereArgs: [eleveId],
        );
      }
    });
  }

  // Analytics
  Future<Map<String, dynamic>> getStudentAnalytics(
    int currentYearId, {
    int? previousYearId,
  }) async {
    const statsQuery = '''
      SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN e.sexe = 'M' THEN 1 ELSE 0 END) as males,
        SUM(CASE WHEN e.sexe = 'F' THEN 1 ELSE 0 END) as females,
        SUM(CASE WHEN LOWER(p.type_inscription) IN ('promotion', 'reinscrit', 'réinscrit') THEN 1 ELSE 0 END) as returning_students,
        SUM(CASE WHEN LOWER(p.type_inscription) = 'redoublement' THEN 1 ELSE 0 END) as repeaters,
        SUM(CASE WHEN p.type_inscription IS NULL OR LOWER(p.type_inscription) IN ('inscrit', 'nouveau', 'en attente') THEN 1 ELSE 0 END) as new_students,
        AVG(CASE 
          WHEN e.date_naissance IS NOT NULL AND e.date_naissance != '' 
          THEN (strftime('%Y', 'now') - strftime('%Y', e.date_naissance)) 
          ELSE NULL 
        END) as average_age
      FROM eleve e
      JOIN eleve_parcours p ON e.id = p.eleve_id
      WHERE p.annee_scolaire_id = ?
    ''';

    final currentStats = await db.rawQuery(statsQuery, [currentYearId]);

    Map<String, dynamic>? previousStats;
    if (previousYearId != null) {
      final prevResult = await db.rawQuery(statsQuery, [previousYearId]);
      if (prevResult.isNotEmpty) {
        previousStats = prevResult.first;
      }
    }

    final cycleDistribution = await db.rawQuery(
      '''
      SELECT cy.nom as cycle, COUNT(e.id) as count
      FROM eleve e
      JOIN eleve_parcours p ON e.id = p.eleve_id
      JOIN classe c ON p.classe_id = c.id
      JOIN cycles_scolaires cy ON c.cycle_id = cy.id
      WHERE p.annee_scolaire_id = ?
      GROUP BY cy.nom
    ''',
      [currentYearId],
    );

    final classDistribution = await db.rawQuery(
      '''
      SELECT c.nom as classe, COUNT(e.id) as count
      FROM eleve e
      JOIN eleve_parcours p ON e.id = p.eleve_id
      JOIN classe c ON p.classe_id = c.id
      WHERE p.annee_scolaire_id = ?
      GROUP BY c.nom
    ''',
      [currentYearId],
    );

    return {
      'current': currentStats.first,
      'previous': previousStats,
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
        c.id as classe_id, c.nom as classe_nom,
        cy.nom as cycle_nom,
        fs.inscription, fs.reinscription, fs.tranche1, fs.tranche2, fs.tranche3, fs.montant_total,
        COALESCE(p_main.montant_paye, 0) as total_paye
      FROM ${EleveSchema.tableName} e
      JOIN eleve_parcours p ON e.id = p.eleve_id
      JOIN classe c ON p.classe_id = c.id
      JOIN cycles_scolaires cy ON c.cycle_id = cy.id
      LEFT JOIN frais_scolarite fs ON p.classe_id = fs.classe_id AND p.annee_scolaire_id = fs.annee_scolaire_id
      LEFT JOIN paiement p_main ON p_main.eleve_id = e.id AND p_main.annee_scolaire_id = p.annee_scolaire_id
      WHERE p.annee_scolaire_id = ?
      ORDER BY c.nom ASC, e.nom ASC
    ''',
      [anneeId],
    );
  }

  Future<List<Map<String, dynamic>>> getGenderStats(int anneeId) async {
    return await db.rawQuery(
      '''
      SELECT e.sexe, COUNT(*) as count 
      FROM ${EleveSchema.tableName} e 
      JOIN eleve_parcours p ON e.id = p.eleve_id
      WHERE p.annee_scolaire_id = ? 
      GROUP BY e.sexe
      ''',
      [anneeId],
    );
  }

  Future<List<Map<String, dynamic>>> getCycleStats(int anneeId) async {
    return await db.rawQuery(
      '''
      SELECT cy.nom as cycle, COUNT(e.id) as count 
      FROM ${EleveSchema.tableName} e 
      JOIN eleve_parcours p ON e.id = p.eleve_id
      JOIN classe c ON p.classe_id = c.id 
      JOIN cycles_scolaires cy ON c.cycle_id = cy.id
      WHERE p.annee_scolaire_id = ? 
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
      JOIN eleve_parcours p ON e.id = p.eleve_id
      JOIN classe c ON p.classe_id = c.id 
      WHERE p.annee_scolaire_id = ? 
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
      bool isFinal = classe?['is_final_class'] == 1;

      // Note: next_class_id has been removed.
      // Manual promotion via executeBulkPromotion is now the preferred way.
      if (moyenne >= defaultPassingGrade && !isFinal) {
        // We can't automatically promote without next_class_id defined per class
        // keeping logic for repeaters/graduates for now
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

  Future<int> updateEleveParcoursStatut(
    int eleveId,
    int anneeId,
    String statut,
  ) async {
    return await db.update(
      'eleve_parcours',
      {
        'confirmation_statut': statut,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'eleve_id = ? AND annee_scolaire_id = ?',
      whereArgs: [eleveId, anneeId],
    );
  }

  Future<void> transfererEleve({
    required int eleveId,
    required int newClasseId,
    required int anneeId,
  }) async {
    await db.transaction((txn) async {
      // 1. Mettre à jour la table principale eleve
      await txn.update(
        EleveSchema.tableName,
        {
          'classe_id': newClasseId,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [eleveId],
      );

      // 2. Mettre à jour la table eleve_parcours pour l'année scolaire en cours
      await txn.update(
        'eleve_parcours',
        {
          'classe_id': newClasseId,
          'moyenne': null, // Réinitialiser pour forcer le recalcul
          'rang': null,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'eleve_id = ? AND annee_scolaire_id = ?',
        whereArgs: [eleveId, anneeId],
      );

      // 3. Mettre à jour les paiements pour l'année scolaire en cours
      await txn.update(
        'paiement',
        {'classe_id': newClasseId},
        where: 'eleve_id = ? AND annee_scolaire_id = ?',
        whereArgs: [eleveId, anneeId],
      );

      await txn.update(
        'paiement_detail',
        {'classe_id': newClasseId},
        where: 'eleve_id = ? AND annee_scolaire_id = ?',
        whereArgs: [eleveId, anneeId],
      );

      // 4. Supprimer les moyennes précalculées dans la table averages
      await txn.delete(
        'averages',
        where: 'eleve_id = ? AND annee_scolaire_id = ?',
        whereArgs: [eleveId, anneeId],
      );
    });
  }

  Future<List<Map<String, dynamic>>> getAgeDistribution(int anneeId) async {
    return await db.rawQuery(
      '''
      SELECT 
        CASE 
          WHEN age < 6 THEN '0-5'
          WHEN age BETWEEN 6 AND 10 THEN '6-10'
          WHEN age BETWEEN 11 AND 14 THEN '11-14'
          WHEN age BETWEEN 15 AND 18 THEN '15-18'
          ELSE '19+'
        END as bracket,
        COUNT(*) as count
      FROM (
        SELECT (strftime('%Y', 'now') - strftime('%Y', e.date_naissance)) as age
        FROM eleve e
        JOIN eleve_parcours p ON e.id = p.eleve_id
        WHERE p.annee_scolaire_id = ? AND e.date_naissance IS NOT NULL AND e.date_naissance != ''
      )
      GROUP BY bracket
      ORDER BY bracket
      ''',
      [anneeId],
    );
  }

  Future<List<Map<String, dynamic>>> getGeographicDistribution(
    int anneeId,
  ) async {
    return await db.rawQuery(
      '''
      SELECT e.lieu_naissance, COUNT(*) as count
      FROM eleve e
      JOIN eleve_parcours p ON e.id = p.eleve_id
      WHERE p.annee_scolaire_id = ? AND e.lieu_naissance IS NOT NULL AND e.lieu_naissance != ''
      GROUP BY e.lieu_naissance
      ORDER BY count DESC
      ''',
      [anneeId],
    );
  }

  Future<List<Map<String, dynamic>>> getGenderStatsByCycle(int anneeId) async {
    return await db.rawQuery(
      '''
      SELECT cy.nom, 
             SUM(CASE WHEN e.sexe = 'M' THEN 1 ELSE 0 END) as male_count,
             SUM(CASE WHEN e.sexe = 'F' THEN 1 ELSE 0 END) as female_count
      FROM eleve e
      JOIN eleve_parcours p ON e.id = p.eleve_id
      JOIN classe c ON p.classe_id = c.id
      JOIN cycles_scolaires cy ON c.cycle_id = cy.id
      WHERE p.annee_scolaire_id = ?
      GROUP BY cy.nom
      ''',
      [anneeId],
    );
  }
}
