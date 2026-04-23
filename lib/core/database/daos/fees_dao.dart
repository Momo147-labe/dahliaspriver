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

  Future<List<Map<String, dynamic>>> getPaiementsByEleve(
    int eleveId,
    int anneeId,
  ) async {
    return await db.query(
      'paiement_detail',
      where: 'eleve_id = ? AND annee_scolaire_id = ?',
      whereArgs: [eleveId, anneeId],
      orderBy: 'date_paiement DESC',
    );
  }

  Future<void> addPaiement(Map<String, dynamic> data) async {
    await db.transaction((txn) async {
      // 1. Insert into paiement_detail
      int? classeId = data['classe_id'];
      int? fraisId = data['frais_id'];

      if (classeId == null || fraisId == null) {
        final eleve = await txn.query(
          'eleve',
          columns: ['classe_id'],
          where: 'id = ?',
          whereArgs: [data['eleve_id']],
        );
        if (eleve.isNotEmpty) {
          classeId = eleve.first['classe_id'] as int;
          data['classe_id'] = classeId;

          final fees = await txn.query(
            FraisScolariteSchema.tableName,
            columns: ['id'],
            where: 'classe_id = ? AND annee_scolaire_id = ?',
            whereArgs: [classeId, data['annee_scolaire_id']],
          );
          if (fees.isNotEmpty) {
            fraisId = fees.first['id'] as int?;
            data['frais_id'] = fraisId;
          }
        }
      }

      await txn.insert('paiement_detail', data);

      // 2. Update or insert into aggregate 'paiement' table
      final existing = await txn.query(
        'paiement',
        where: 'eleve_id = ? AND annee_scolaire_id = ?',
        whereArgs: [data['eleve_id'], data['annee_scolaire_id']],
      );

      if (existing.isNotEmpty) {
        final double currentPaid =
            (existing.first['montant_paye'] as num?)?.toDouble() ?? 0.0;
        final double total =
            (existing.first['montant_total'] as num?)?.toDouble() ?? 0.0;
        final double newPaid =
            currentPaid + (data['montant'] as num).toDouble();
        final double newRemaining = total - newPaid;

        await txn.update(
          'paiement',
          {
            'montant_paye': newPaid,
            'montant_restant': newRemaining,
            'mode_paiement': data['mode_paiement'],
            'reference_paiement': data['observation'],
            'date_paiement': data['date_paiement'],
            'type_paiement': data['type_frais'],
            'statut': newRemaining <= 0 ? 'Réglé' : 'Partiel',
            'classe_id': classeId,
            'frais_id': fraisId,
          },
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      } else {
        // Initial payment record creation
        double totalFees = 0.0;
        if (classeId != null) {
          final fees = await txn.query(
            FraisScolariteSchema.tableName,
            columns: ['montant_total'],
            where: 'classe_id = ? AND annee_scolaire_id = ?',
            whereArgs: [classeId, data['annee_scolaire_id']],
          );
          if (fees.isNotEmpty) {
            totalFees =
                (fees.first['montant_total'] as num?)?.toDouble() ?? 0.0;
          }
        }

        final double montantPaye = (data['montant'] as num).toDouble();
        final double remaining = totalFees - montantPaye;

        await txn.insert('paiement', {
          'eleve_id': data['eleve_id'],
          'classe_id': classeId,
          'frais_id': fraisId,
          'annee_scolaire_id': data['annee_scolaire_id'],
          'montant_total': totalFees,
          'montant_paye': montantPaye,
          'montant_restant': remaining,
          'mode_paiement': data['mode_paiement'],
          'reference_paiement': data['observation'],
          'date_paiement': data['date_paiement'],
          'type_paiement': data['type_frais'],
          'statut': remaining <= 0 ? 'Réglé' : 'Partiel',
        });
      }
    });
  }

  Future<Map<String, dynamic>> getFinancialAnalytics(
    int currentYearId,
    int? previousYearId,
  ) async {
    final currentFinances = await db.rawQuery(
      '''
      SELECT 
        COUNT(DISTINCT pd.eleve_id) as students_paid,
        SUM(pd.montant) as total_collected,
        COUNT(pd.id) as payment_count
      FROM paiement_detail pd
      JOIN eleve_parcours ep ON pd.eleve_id = ep.eleve_id
      WHERE ep.annee_scolaire_id = ?
    ''',
      [currentYearId],
    );

    final currentExpected = await db.rawQuery(
      '''
      SELECT 
        SUM(
          (fs.inscription + fs.reinscription + fs.tranche1 + fs.tranche2 + fs.tranche3) * 
          (SELECT COUNT(*) FROM eleve_parcours WHERE classe_id = fs.classe_id AND annee_scolaire_id = ?)
        ) as total_expected
      FROM ${FraisScolariteSchema.tableName} fs
      WHERE fs.annee_scolaire_id = ?
    ''',
      [currentYearId, currentYearId],
    );

    final paymentMethods = await db.rawQuery(
      '''
      SELECT pd.mode_paiement, COUNT(*) as count, SUM(pd.montant) as total
      FROM paiement_detail pd
      JOIN eleve_parcours ep ON pd.eleve_id = ep.eleve_id
      WHERE ep.annee_scolaire_id = ?
      GROUP BY pd.mode_paiement
    ''',
      [currentYearId],
    );

    return {
      'current': {
        ...currentFinances.first,
        'total_expected': currentExpected.first['total_expected'],
      },
      'paymentMethods': paymentMethods,
    };
  }

  Future<Map<String, double>> getStudentFinancialStatus(
    int eleveId,
    int anneeId,
  ) async {
    final result = await db.rawQuery(
      '''
      SELECT 
        COALESCE(p.montant_total, fs.montant_total, 0) as total_expected,
        COALESCE(p.montant_paye, 0) as total_paid
      FROM eleve e
      JOIN eleve_parcours ep ON e.id = ep.eleve_id AND ep.annee_scolaire_id = ?
      JOIN classe c ON ep.classe_id = c.id
      LEFT JOIN paiement p ON e.id = p.eleve_id AND p.annee_scolaire_id = ?
      LEFT JOIN frais_scolarite fs ON ep.classe_id = fs.classe_id AND ep.annee_scolaire_id = fs.annee_scolaire_id
      WHERE e.id = ?
    ''',
      [anneeId, anneeId, eleveId],
    );

    if (result.isEmpty) {
      return {'totalExpected': 0.0, 'totalPaid': 0.0, 'balance': 0.0};
    }

    final double expected =
        (result.first['total_expected'] as num?)?.toDouble() ?? 0.0;
    final double paid = (result.first['total_paid'] as num?)?.toDouble() ?? 0.0;

    return {
      'totalExpected': expected,
      'totalPaid': paid,
      'balance': expected - paid,
    };
  }

  Future<List<Map<String, dynamic>>> getOverdueStudents(int anneeId) async {
    return await db.rawQuery(
      '''
      SELECT 
        e.id, e.nom, e.prenom, e.matricule,
        c.nom as classe_nom,
        p.montant_restant, p.statut,
        fs.date_limite_t1, fs.date_limite_t2, fs.date_limite_t3
      FROM eleve e
      JOIN eleve_parcours ep ON e.id = ep.eleve_id AND ep.annee_scolaire_id = ?
      JOIN classe c ON ep.classe_id = c.id
      JOIN paiement p ON e.id = p.eleve_id AND p.annee_scolaire_id = ?
      JOIN frais_scolarite fs ON ep.classe_id = fs.classe_id AND ep.annee_scolaire_id = fs.annee_scolaire_id
      WHERE p.montant_restant > 0 
      AND (
        (fs.date_limite_t1 < date('now') AND p.montant_paye < fs.tranche1) OR
        (fs.date_limite_t2 < date('now') AND p.montant_paye < (fs.tranche1 + fs.tranche2)) OR
        (fs.date_limite_t3 < date('now') AND p.montant_paye < fs.montant_total)
      )
    ''',
      [anneeId, anneeId],
    );
  }
}
