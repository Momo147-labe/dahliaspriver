import 'package:sqflite/sqflite.dart';
import '../schemas/configuration_annee_schema.dart';
import '../schemas/cycles_scolaires_schema.dart';
import '../schemas/niveaux_schema.dart';
import '../schemas/matiere_schema.dart';
import 'base_dao.dart';

class ConfigDao extends BaseDao {
  ConfigDao(Database db) : super(db);

  // Configuration Annee
  Future<Map<String, dynamic>?> getConfigurationAnnee(
    int anneeScolaireId,
  ) async {
    final result = await db.query(
      ConfigurationAnneeSchema.tableName,
      where: 'annee_scolaire_id = ?',
      whereArgs: [anneeScolaireId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> saveConfigurationAnnee(Map<String, dynamic> config) async {
    return await db.insert(
      ConfigurationAnneeSchema.tableName,
      config,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateConfigurationAnnee(
    int id,
    Map<String, dynamic> config,
  ) async {
    config['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      ConfigurationAnneeSchema.tableName,
      config,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Cycles Scolaires
  Future<List<Map<String, dynamic>>> getCyclesScolaires() async {
    return await db.query(
      CyclesScolairesSchema.tableName,
      where: 'actif = 1',
      orderBy: 'ordre',
    );
  }

  Future<Map<String, dynamic>?> getCycleById(int id) async {
    final result = await db.query(
      CyclesScolairesSchema.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> saveCycle(Map<String, dynamic> cycle) async {
    return await db.insert(CyclesScolairesSchema.tableName, cycle);
  }

  Future<int> updateCycle(int id, Map<String, dynamic> cycle) async {
    final data = Map<String, dynamic>.from(cycle);
    data.remove('id'); // ID cannot be updated
    data['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      CyclesScolairesSchema.tableName,
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCycle(int id) async {
    return await db.update(
      CyclesScolairesSchema.tableName,
      {'actif': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Niveaux
  Future<List<Map<String, dynamic>>> getNiveauxByCycle(int cycleId) async {
    return await db.query(
      NiveauxSchema.tableName,
      where: 'cycle_id = ? AND actif = 1',
      whereArgs: [cycleId],
      orderBy: 'ordre',
    );
  }

  Future<int> saveNiveau(Map<String, dynamic> niveau) async {
    if (niveau['id'] != null) {
      int id = niveau['id'];
      Map<String, dynamic> data = Map.from(niveau);
      data.remove('id');
      data['updated_at'] = DateTime.now().toIso8601String();
      return await db.update(
        NiveauxSchema.tableName,
        data,
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      return await db.insert(NiveauxSchema.tableName, niveau);
    }
  }

  Future<Map<String, dynamic>?> getClasseWithCycle(int classId) async {
    final results = await db.rawQuery(
      '''
      SELECT c.*, cy.nom as cycle_nom, cy.note_min, cy.note_max, cy.moyenne_passage, cy.id as cycle_id
      FROM classe c
      LEFT JOIN cycles_scolaires cy ON c.cycle_id = cy.id
      WHERE c.id = ?
    ''',
      [classId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> deleteNiveau(int id) async {
    return await db.update(
      NiveauxSchema.tableName,
      {'actif': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Mentions
  Future<void> saveMention(Map<String, dynamic> mention) async {
    await db.insert(
      'mention_config',
      mention,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteMention(int id) async {
    await db.delete('mention_config', where: 'id = ?', whereArgs: [id]);
  }

  // Evaluation Config
  Future<List<Map<String, dynamic>>> getSequences(int anneeId) async {
    // Priority: Query sequence_planification
    final sequences = await db.query(
      'sequence_planification',
      where: 'annee_scolaire_id = ?',
      whereArgs: [anneeId],
      orderBy: 'trimestre ASC, numero_sequence ASC',
    );

    if (sequences.isNotEmpty) return sequences;

    // Default fallback if no planning exists yet
    return List.generate(6, (index) {
      final t = (index ~/ 2) + 1;
      final s = (index % 2) + 1;
      return {
        'id': index + 1,
        'nom': 'Séquence $s',
        'trimestre': t,
        'numero_sequence': s,
      };
    });
  }

  Future<List<int>> getTrimesters(int anneeId) async {
    final result = await db.rawQuery(
      'SELECT DISTINCT trimestre FROM sequence_planification WHERE annee_scolaire_id = ? ORDER BY trimestre ASC',
      [anneeId],
    );

    if (result.isNotEmpty) {
      return result.map((row) => row['trimestre'] as int).toList();
    }

    // Default fallback
    return [1, 2, 3];
  }

  Future<List<Map<String, dynamic>>> getMentionsByCycle(int? cycleId) async {
    return await db.query(
      'mention_config',
      where: cycleId == null ? 'cycle_id IS NULL' : 'cycle_id = ?',
      whereArgs: cycleId == null ? [] : [cycleId],
      orderBy: 'note_min DESC',
    );
  }

  // Sequence Planification
  Future<List<Map<String, dynamic>>> getSequencesPlanification(
    int anneeId,
  ) async {
    return await db.query(
      'sequence_planification',
      where: 'annee_scolaire_id = ?',
      whereArgs: [anneeId],
      orderBy: 'numero_sequence ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getNiveaux() async {
    return await db.query(NiveauxSchema.tableName, where: 'actif = 1');
  }

  // Default Subjects by Cycle
  Future<List<Map<String, dynamic>>> getDefaultSubjectsByCycle(
    int cycleId,
  ) async {
    return await db.query(
      'cycle_matiere_default',
      where: 'cycle_id = ?',
      whereArgs: [cycleId],
    );
  }

  Future<void> autoAssignDefaultSubjectsToClass(
    int classeId,
    int cycleId,
  ) async {
    final defaults = await getDefaultSubjectsByCycle(cycleId);
    if (defaults.isEmpty) return;

    await db.transaction((txn) async {
      for (var def in defaults) {
        final matiereNom = def['matiere_nom'] as String;
        final coefficient = def['coefficient'] as double? ?? 1.0;

        // 1. S'assurer que la matière existe globalement
        final matieres = await txn.query(
          MatiereSchema.tableName,
          where: 'nom = ?',
          whereArgs: [matiereNom],
        );

        int matiereId;
        if (matieres.isEmpty) {
          matiereId = await txn.insert(MatiereSchema.tableName, {
            'nom': matiereNom,
          });
        } else {
          matiereId = matieres.first['id'] as int;
        }

        // 2. Lier à la classe
        await txn.insert('classe_matiere', {
          'classe_id': classeId,
          'matiere_id': matiereId,
          'coefficient': coefficient,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<void> initializeTeachingStructure({
    required bool prescolaire,
    required bool primaire,
    required bool college,
    required bool lycee,
  }) async {
    await db.transaction((txn) async {
      final List<Map<String, dynamic>> cyclesToInsert = [];
      final List<Map<String, dynamic>> niveauxToInsert = [];
      final Set<String> matieresToInsert = {};

      if (prescolaire) {
        cyclesToInsert.add({
          'id': 1,
          'nom': 'Préscolaire',
          'ordre': 1,
          'note_min': 0.0,
          'note_max': 0.0,
          'moyenne_passage': 0.0,
        });
        niveauxToInsert.addAll([
          {
            'nom': 'Petite section',
            'cycle_id': 1,
            'ordre': 1,
            'moyenne_passage': 0.0,
          },
          {
            'nom': 'Moyenne section',
            'cycle_id': 1,
            'ordre': 2,
            'moyenne_passage': 0.0,
          },
          {
            'nom': 'Grande section',
            'cycle_id': 1,
            'ordre': 3,
            'moyenne_passage': 0.0,
          },
        ]);
        // Pas de matières spécifiques pour le préscolaire mentionnées.
      }
      if (primaire) {
        cyclesToInsert.add({
          'id': 2,
          'nom': 'Primaire',
          'ordre': 2,
          'note_min': 0.0,
          'note_max': 10.0,
          'moyenne_passage': 5.0,
        });
        niveauxToInsert.addAll([
          {
            'nom': '1ère année',
            'cycle_id': 2,
            'ordre': 1,
            'moyenne_passage': 5.0,
          },
          {
            'nom': '2ème année',
            'cycle_id': 2,
            'ordre': 2,
            'moyenne_passage': 5.0,
          },
          {
            'nom': '3ème année',
            'cycle_id': 2,
            'ordre': 3,
            'moyenne_passage': 5.0,
          },
          {
            'nom': '4ème année',
            'cycle_id': 2,
            'ordre': 4,
            'moyenne_passage': 5.0,
          },
          {
            'nom': '5ème année',
            'cycle_id': 2,
            'ordre': 5,
            'moyenne_passage': 5.0,
          },
          {
            'nom': '6ème année',
            'cycle_id': 2,
            'ordre': 6,
            'moyenne_passage': 5.0,
          },
        ]);
        matieresToInsert.addAll([
          "Français",
          "Calculs",
          "Sciences d'observation",
          "Histoire-Géographie",
          "ECM",
          "Dessin / Arts plastiques",
          "Éducation physique et sportive (EPS)",
        ]);
      }
      if (college) {
        cyclesToInsert.add({
          'id': 3,
          'nom': 'Collège',
          'ordre': 3,
          'note_min': 0.0,
          'note_max': 20.0,
          'moyenne_passage': 10.0,
        });
        niveauxToInsert.addAll([
          {
            'nom': '7ème année',
            'cycle_id': 3,
            'ordre': 1,
            'moyenne_passage': 10.0,
          },
          {
            'nom': '8ème année',
            'cycle_id': 3,
            'ordre': 2,
            'moyenne_passage': 10.0,
          },
          {
            'nom': '9ème année',
            'cycle_id': 3,
            'ordre': 3,
            'moyenne_passage': 10.0,
          },
          {
            'nom': '10ème année',
            'cycle_id': 3,
            'ordre': 4,
            'moyenne_passage': 10.0,
          },
        ]);
        matieresToInsert.addAll([
          "Français",
          "Mathématiques",
          "Anglais",
          "Physique",
          "Chimie",
          "Biologie",
          "Géologie",
          "Histoire",
          "Géographie",
          "ECM",
          "Informatique",
          "EPS",
        ]);
      }
      if (lycee) {
        cyclesToInsert.add({
          'id': 4,
          'nom': 'Lycée',
          'ordre': 4,
          'note_min': 0.0,
          'note_max': 20.0,
          'moyenne_passage': 10.0,
        });
        niveauxToInsert.addAll([
          {
            'nom': '11ème année',
            'cycle_id': 4,
            'ordre': 1,
            'moyenne_passage': 10.0,
          },
          {
            'nom': '12ème année',
            'cycle_id': 4,
            'ordre': 2,
            'moyenne_passage': 10.0,
          },
          {
            'nom': 'Terminale',
            'cycle_id': 4,
            'ordre': 3,
            'moyenne_passage': 10.0,
          },
        ]);
        matieresToInsert.addAll([
          "Français",
          "Philosophie",
          "Anglais",
          "Mathématiques",
          "Physique",
          "Chimie",
          "Biologie",
          "Géologie",
          "Histoire",
          "Géographie",
          "EPS",
          "Économie",
        ]);
      }

      // Insert cycles safely
      for (var cycle in cyclesToInsert) {
        await txn.insert(
          CyclesScolairesSchema.tableName,
          cycle,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // Insert niveaux safely
      final List<Map<String, dynamic>> insertedNiveaux = [];
      for (var niveau in niveauxToInsert) {
        final existing = await txn.query(
          NiveauxSchema.tableName,
          where: 'nom = ? AND cycle_id = ?',
          whereArgs: [niveau['nom'], niveau['cycle_id']],
        );

        int insertedId;
        if (existing.isNotEmpty) {
          insertedId = existing.first['id'] as int;
          await txn.update(
            NiveauxSchema.tableName,
            niveau,
            where: 'id = ?',
            whereArgs: [insertedId],
          );
        } else {
          insertedId = await txn.insert(NiveauxSchema.tableName, niveau);
        }

        insertedNiveaux.add({'id': insertedId, 'nom': niveau['nom']});
      }

      // Insert matieres safely (avoid duplicates globally)
      for (var matiereNom in matieresToInsert) {
        final existing = await txn.query(
          MatiereSchema.tableName,
          where: 'nom = ?',
          whereArgs: [matiereNom],
        );
        if (existing.isEmpty) {
          await txn.insert(MatiereSchema.tableName, {'nom': matiereNom});
        }
      }

      // Progression Links mapping
      final Map<String, String> progressionLinks = {
        'Petite section': 'Moyenne section',
        'Moyenne section': 'Grande section',
        'Grande section': '1ère année',
        '1ère année': '2ème année',
        '2ème année': '3ème année',
        '3ème année': '4ème année',
        '4ème année': '5ème année',
        '5ème année': '6ème année',
        '6ème année': '7ème année',
        '7ème année': '8ème année',
        '8ème année': '9ème année',
        '9ème année': '10ème année',
        '10ème année': '11ème année',
        '11ème année': '12ème année',
        '12ème année': 'Terminale',
      };

      for (var niveau in insertedNiveaux) {
        final nom = niveau['nom'] as String;
        final nextNom = progressionLinks[nom];

        if (nextNom != null) {
          final nextNiveauIndex = insertedNiveaux.indexWhere(
            (n) => n['nom'] == nextNom,
          );
          if (nextNiveauIndex != -1) {
            final nextNiveauId = insertedNiveaux[nextNiveauIndex]['id'];
            await txn.update(
              NiveauxSchema.tableName,
              {'next_niveau_id': nextNiveauId},
              where: 'id = ?',
              whereArgs: [niveau['id']],
            );
          }
        } else {
          await txn.update(
            NiveauxSchema.tableName,
            {'next_niveau_id': null},
            where: 'id = ?',
            whereArgs: [niveau['id']],
          );
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> getSequencesForTrimester(
    int anneeId,
    int trimester,
  ) async {
    try {
      return await db.query(
        'sequence_planification',
        where: 'annee_scolaire_id = ? AND trimestre = ?',
        whereArgs: [anneeId, trimester],
        orderBy: 'numero_sequence ASC',
      );
    } catch (e) {
      return [];
    }
  }

  Future<void> saveSequencesPlanification(
    List<Map<String, dynamic>> sequences,
  ) async {
    final batch = db.batch();
    for (var seq in sequences) {
      if (seq['id'] != null) {
        batch.update(
          'sequence_planification',
          seq,
          where: 'id = ?',
          whereArgs: [seq['id']],
        );
      } else {
        batch.insert('sequence_planification', seq);
      }
    }
    await batch.commit(noResult: true);
  }

  // Document Templates
  Future<Map<String, dynamic>?> getDocumentTemplate(
    int anneeScolaireId,
    String type,
  ) async {
    final result = await db.query(
      'document_templates',
      where: 'annee_scolaire_id = ? AND type = ?',
      whereArgs: [anneeScolaireId, type],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> saveDocumentTemplate(Map<String, dynamic> template) async {
    final existing = await getDocumentTemplate(
      template['annee_scolaire_id'],
      template['type'],
    );
    if (existing != null) {
      template['updated_at'] = DateTime.now().toIso8601String();
      return await db.update(
        'document_templates',
        template,
        where: 'id = ?',
        whereArgs: [existing['id']],
      );
    } else {
      return await db.insert('document_templates', template);
    }
  }

  Future<bool> hasGradesForSequence(
    int anneeId,
    int trimestre,
    int sequence,
  ) async {
    final result = await db.query(
      'notes',
      where: 'annee_scolaire_id = ? AND trimestre = ? AND sequence = ?',
      whereArgs: [anneeId, trimestre, sequence],
      limit: 1,
    );
    return result.isNotEmpty;
  }
}
