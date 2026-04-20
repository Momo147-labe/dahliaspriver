import 'package:sqflite/sqflite.dart';
import '../schemas/frais_scolarite_schema.dart';
import 'base_dao.dart';

class FeesDao extends BaseDao {
  FeesDao(Database db) : super(db);

  Future<Map<String, dynamic>?> getFraisByClasse(
    int classId,
    int anneeId,
  ) async {
    final result = await db.query(
      FraisScolariteSchema.tableName,
      where: 'classe_id = ? AND annee_scolaire_id = ?',
      whereArgs: [classId, anneeId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> createFraisForMultipleClasses(
    List<int> classeIds,
    int anneeScolaireId,
    Map<String, dynamic> fraisData,
  ) async {
    await db.transaction((txn) async {
      for (int classeId in classeIds) {
        final fraisMap = {
          'classe_id': classeId,
          'annee_scolaire_id': anneeScolaireId,
          ...fraisData,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        final existing = await txn.query(
          FraisScolariteSchema.tableName,
          where: 'classe_id = ? AND annee_scolaire_id = ?',
          whereArgs: [classeId, anneeScolaireId],
        );

        if (existing.isNotEmpty) {
          await txn.update(
            FraisScolariteSchema.tableName,
            fraisMap,
            where: 'id = ?',
            whereArgs: [existing.first['id']],
          );
        } else {
          await txn.insert(FraisScolariteSchema.tableName, fraisMap);
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> getClassesWithSameFees(
    int anneeScolaireId,
    Map<String, dynamic> fraisReference,
  ) async {
    return await db.rawQuery(
      '''
      SELECT c.*, fs.*
      FROM classe c
      JOIN ${FraisScolariteSchema.tableName} fs ON c.id = fs.classe_id
      WHERE fs.annee_scolaire_id = ? 
        AND fs.inscription = ? 
        AND fs.reinscription = ?
        AND fs.tranche1 = ?
        AND fs.tranche2 = ?
        AND fs.tranche3 = ?
      ORDER BY c.nom ASC
    ''',
      [
        anneeScolaireId,
        fraisReference['inscription'] ?? 0.0,
        fraisReference['reinscription'] ?? 0.0,
        fraisReference['tranche1'] ?? 0.0,
        fraisReference['tranche2'] ?? 0.0,
        fraisReference['tranche3'] ?? 0.0,
      ],
    );
  }

  Future<void> duplicateFraisToClasses(
    int sourceClasseId,
    List<int> targetClasseIds,
    int anneeScolaireId,
  ) async {
    final sourceFrais = await getFraisByClasse(sourceClasseId, anneeScolaireId);
    if (sourceFrais == null) {
      throw Exception('Aucun frais trouvé pour la classe source');
    }

    final data = Map<String, dynamic>.from(sourceFrais);
    data.remove('id');
    data.remove('classe_id');
    data.remove('annee_scolaire_id');
    data.remove('created_at');
    data.remove('updated_at');

    await createFraisForMultipleClasses(targetClasseIds, anneeScolaireId, data);
  }

  Future<Map<String, dynamic>> getFraisStatistics(int anneeScolaireId) async {
    final stats = await db.rawQuery(
      '''
      SELECT 
        COUNT(DISTINCT fs.classe_id) as classes_with_fees,
        COUNT(DISTINCT c.id) as total_classes,
        AVG(fs.montant_total) as average_fees,
        MIN(fs.montant_total) as min_fees,
        MAX(fs.montant_total) as max_fees,
        SUM(fs.montant_total * (
          SELECT COUNT(*) FROM eleve 
          WHERE classe_id = fs.classe_id AND annee_scolaire_id = ?
        )) as total_expected_revenue
      FROM classe c
      LEFT JOIN ${FraisScolariteSchema.tableName} fs ON c.id = fs.classe_id AND fs.annee_scolaire_id = ?
    ''',
      [anneeScolaireId, anneeScolaireId],
    );
    return stats.first;
  }

  Future<void> deleteFraisForClasses(List<int> classeIds, int anneeId) async {
    await db.transaction((txn) async {
      for (int id in classeIds) {
        await txn.delete(
          FraisScolariteSchema.tableName,
          where: 'classe_id = ? AND annee_scolaire_id = ?',
          whereArgs: [id, anneeId],
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getClassesWithFrais(
    int anneeScolaireId,
  ) async {
    return await db.rawQuery(
      '''
      SELECT c.*, fs.id as frais_id, fs.inscription, fs.reinscription, 
             fs.tranche1, fs.date_limite_t1, fs.tranche2, fs.date_limite_t2,
             fs.tranche3, fs.date_limite_t3, fs.montant_total,
             (SELECT COUNT(*) FROM eleve WHERE classe_id = c.id AND annee_scolaire_id = ?) as nb_eleves
      FROM classe c
      LEFT JOIN ${FraisScolariteSchema.tableName} fs ON c.id = fs.classe_id AND fs.annee_scolaire_id = ?
      ORDER BY c.nom ASC
    ''',
      [anneeScolaireId, anneeScolaireId],
    );
  }

  Future<int> importFeesFromYear({
    required int sourceYearId,
    required int targetYearId,
    double adjustmentPercentage = 0.0,
    double adjustmentFlat = 0.0,
  }) async {
    final sourceFees = await db.query(
      FraisScolariteSchema.tableName,
      where: 'annee_scolaire_id = ?',
      whereArgs: [sourceYearId],
    );

    int count = 0;
    await db.transaction((txn) async {
      for (var f in sourceFees) {
        // Vérifier si des frais existent déjà pour cette classe dans l'année cible
        final existing = await txn.query(
          FraisScolariteSchema.tableName,
          where: 'classe_id = ? AND annee_scolaire_id = ?',
          whereArgs: [f['classe_id'], targetYearId],
        );

        if (existing.isEmpty) {
          final data = Map<String, dynamic>.from(f);
          data.remove('id');
          data['annee_scolaire_id'] = targetYearId;

          // Appliquer les ajustements aux champs monétaires
          final fieldsToAdjust = [
            'inscription',
            'reinscription',
            'tranche1',
            'tranche2',
            'tranche3',
          ];
          double total = 0.0;

          for (var field in fieldsToAdjust) {
            double val = (data[field] as num?)?.toDouble() ?? 0.0;
            if (val > 0) {
              // Appliquer le pourcentage et ajouter le montant fixe proportionnel
              // (ou juste sur le total, mais ici on le fait par champ si > 0)
              val = val * (1 + (adjustmentPercentage / 100));

              // On ajoute le montant fixe à la tranche 1 par défaut si c'est un ajustement global
              if (field == 'tranche1') {
                val += adjustmentFlat;
              }

              data[field] = val;
            }
            total += val;
          }
          data['montant_total'] = total;
          data['created_at'] = DateTime.now().toIso8601String();
          data['updated_at'] = DateTime.now().toIso8601String();

          await txn.insert(FraisScolariteSchema.tableName, data);
          count++;
        }
      }
    });
    return count;
  }
}
