import 'package:sqflite/sqflite.dart';
import '../schemas/configuration_annee_schema.dart';
import '../schemas/cycles_scolaires_schema.dart';
import '../schemas/niveaux_schema.dart';
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
    cycle['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      CyclesScolairesSchema.tableName,
      cycle,
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
    if (cycleId == null) {
      return await db.query('mention_config', where: 'cycle_id IS NULL');
    }
    return await db.query(
      'mention_config',
      where: 'cycle_id = ?',
      whereArgs: [cycleId],
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
