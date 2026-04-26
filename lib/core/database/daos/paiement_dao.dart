import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../schemas/paiement_schema.dart';
import '../schemas/paiement_detail_schema.dart';
import 'base_dao.dart';

class PaiementDao extends BaseDao {
  PaiementDao(Database db) : super(db);

  Future<List<Map<String, dynamic>>> getPaymentDetails(
    int eleveId, {
    int? anneeId,
  }) async {
    String queryStr =
        '''
      SELECT pd.*, c.nom as classe_nom, a.libelle as annee_nom, u.nom_complet as agent_nom, u.pseudo as agent_pseudo
      FROM ${PaiementDetailSchema.tableName} pd
      LEFT JOIN classe c ON pd.classe_id = c.id
      LEFT JOIN annee_scolaire a ON pd.annee_scolaire_id = a.id
      LEFT JOIN user u ON pd.created_by_id = u.id
      WHERE pd.eleve_id = ?
    ''';
    List<dynamic> args = [eleveId];

    if (anneeId != null) {
      queryStr += ' AND pd.annee_scolaire_id = ?';
      args.add(anneeId);
    }

    queryStr += ' ORDER BY pd.date_paiement DESC';

    return await db.rawQuery(queryStr, args);
  }

  Future<List<Map<String, dynamic>>> getPaymentsByStudent(int eleveId) async {
    return await db.rawQuery(
      '''
      SELECT p.*, c.nom as classe_nom, a.libelle as annee_nom
      FROM ${PaiementSchema.tableName} p
      JOIN classe c ON p.classe_id = c.id
      JOIN annee_scolaire a ON p.annee_scolaire_id = a.id
      WHERE p.eleve_id = ?
      ORDER BY a.date_debut DESC
    ''',
      [eleveId],
    );
  }

  Future<void> addPaiement(Map<String, dynamic> data) async {
    await db.transaction((txn) async {
      // 1. Insert into paiement_detail
      if (!data.containsKey('classe_id') || !data.containsKey('frais_id')) {
        final eleveParcours = await txn.query(
          'eleve_parcours',
          columns: ['classe_id'],
          where: 'eleve_id = ? AND annee_scolaire_id = ?',
          whereArgs: [data['eleve_id'], data['annee_scolaire_id']],
        );
        if (eleveParcours.isNotEmpty) {
          final int classeId = eleveParcours.first['classe_id'] as int;
          data['classe_id'] = classeId;

          final fees = await txn.query(
            'frais_scolarite',
            columns: ['id'],
            where: 'classe_id = ? AND annee_scolaire_id = ?',
            whereArgs: [classeId, data['annee_scolaire_id']],
          );
          if (fees.isNotEmpty) {
            data['frais_id'] = fees.first['id'];
          }
        }
      }

      if (!data.containsKey('numero_recu')) {
        data['numero_recu'] = await generateNextReceiptNumber(
          txn,
          data['annee_scolaire_id'],
        );
      }

      await txn.insert(PaiementDetailSchema.tableName, data);

      // 2. Update or insert into aggregate 'paiement' table
      final existing = await txn.query(
        PaiementSchema.tableName,
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
          PaiementSchema.tableName,
          {
            'montant_paye': newPaid,
            'montant_restant': newRemaining,
            'mode_paiement': data['mode_paiement'],
            'reference_paiement': data['observation'],
            'date_paiement': data['date_paiement'],
            'type_paiement': data['type_frais'],
            'statut': newRemaining <= 0 ? 'Réglé' : 'Partiel',
            'classe_id': data['classe_id'],
            'frais_id': data['frais_id'],
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );

        // Confirmation automatique du statut de l'élève dans son parcours
        await txn.update(
          'eleve_parcours',
          {'confirmation_statut': 'Confirmé'},
          where:
              'eleve_id = ? AND annee_scolaire_id = ? AND confirmation_statut = ?',
          whereArgs: [
            data['eleve_id'],
            data['annee_scolaire_id'],
            'En attente',
          ],
        );
      } else {
        final eleveParcours = await txn.query(
          'eleve_parcours',
          columns: ['classe_id'],
          where: 'eleve_id = ? AND annee_scolaire_id = ?',
          whereArgs: [data['eleve_id'], data['annee_scolaire_id']],
        );
        int? classeId = eleveParcours.isNotEmpty
            ? eleveParcours.first['classe_id'] as int?
            : null;

        double totalFees = 0.0;
        if (classeId != null) {
          final fees = await txn.query(
            'frais_scolarite',
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
        await txn.insert(PaiementSchema.tableName, {
          'eleve_id': data['eleve_id'],
          'classe_id': data['classe_id'],
          'frais_id': data['frais_id'],
          'annee_scolaire_id': data['annee_scolaire_id'],
          'montant_total': totalFees,
          'montant_paye': montantPaye,
          'montant_restant': totalFees - montantPaye,
          'mode_paiement': data['mode_paiement'],
          'reference_paiement': data['observation'],
          'date_paiement': data['date_paiement'],
          'type_paiement': data['type_frais'],
          'statut': (totalFees - montantPaye) <= 0 ? 'Réglé' : 'Partiel',
        });
      }
    });
  }

  Future<Map<String, dynamic>> getFinancialSummary(int anneeId) async {
    // Total expected: Sum of class fees for all enrolled students
    final expectedResult = await db.rawQuery(
      '''
      SELECT SUM(fs.montant_total) as total
      FROM eleve_parcours ep
      JOIN frais_scolarite fs ON ep.classe_id = fs.classe_id AND ep.annee_scolaire_id = fs.annee_scolaire_id
      WHERE ep.annee_scolaire_id = ?
    ''',
      [anneeId],
    );

    // Total collected
    final collectedResult = await db.rawQuery(
      '''
      SELECT SUM(montant_paye) as total
      FROM ${PaiementSchema.tableName}
      WHERE annee_scolaire_id = ?
    ''',
      [anneeId],
    );

    // Growth comparison (this month vs last month)
    final now = DateTime.now();
    final firstDayThisMonth = DateTime(
      now.year,
      now.month,
      1,
    ).toIso8601String();
    final firstDayLastMonth = DateTime(
      now.year,
      now.month - 1,
      1,
    ).toIso8601String();

    final thisMonthResult = await db.rawQuery(
      '''
      SELECT SUM(montant) as total
      FROM ${PaiementDetailSchema.tableName}
      WHERE annee_scolaire_id = ? AND date_paiement >= ?
    ''',
      [anneeId, firstDayThisMonth],
    );

    final lastMonthResult = await db.rawQuery(
      '''
      SELECT SUM(montant) as total
      FROM ${PaiementDetailSchema.tableName}
      WHERE annee_scolaire_id = ? AND date_paiement >= ? AND date_paiement < ?
    ''',
      [anneeId, firstDayLastMonth, firstDayThisMonth],
    );

    double expected =
        (expectedResult.first['total'] as num?)?.toDouble() ?? 0.0;
    double collected =
        (collectedResult.first['total'] as num?)?.toDouble() ?? 0.0;
    double remaining = expected - collected;
    double recoveryRate = expected > 0 ? (collected / expected) * 100 : 0.0;

    double thisMonth =
        (thisMonthResult.first['total'] as num?)?.toDouble() ?? 0.0;
    double lastMonth =
        (lastMonthResult.first['total'] as num?)?.toDouble() ?? 0.0;
    double growth = lastMonth > 0
        ? ((thisMonth - lastMonth) / lastMonth) * 100
        : 0.0;

    // Total Teacher Salaries (Expenses)
    final salaryResult = await db.rawQuery(
      'SELECT SUM(montant) as total FROM paiement_enseignant WHERE annee_scolaire_id = ?',
      [anneeId],
    );
    double totalSalaries =
        (salaryResult.first['total'] as num?)?.toDouble() ?? 0.0;

    return {
      'expected': expected,
      'collected': collected,
      'remaining': remaining,
      'recoveryRate': recoveryRate,
      'thisMonth': thisMonth,
      'growth': growth,
      'expenses': totalSalaries,
      'netRevenue': collected - totalSalaries,
    };
  }

  Future<List<Map<String, dynamic>>> getRecoveryByClass(int anneeId) async {
    return await db.rawQuery(
      '''
      SELECT c.nom, SUM(p.montant_paye) as paid, SUM(p.montant_total) as expected
      FROM classe c
      JOIN eleve_parcours ep ON ep.classe_id = c.id
      LEFT JOIN ${PaiementSchema.tableName} p ON p.eleve_id = ep.eleve_id AND p.annee_scolaire_id = ?
      WHERE ep.annee_scolaire_id = ?
      GROUP BY c.id
      ORDER BY c.nom ASC
    ''',
      [anneeId, anneeId],
    );
  }

  Future<List<Map<String, dynamic>>> getPaymentMethodsBreakdown(
    int anneeId,
  ) async {
    return await db.rawQuery(
      '''
      SELECT COALESCE(mode_paiement, 'Inconnu') as mode, SUM(montant) as total, COUNT(*) as count
      FROM ${PaiementDetailSchema.tableName}
      WHERE annee_scolaire_id = ?
      GROUP BY mode_paiement
    ''',
      [anneeId],
    );
  }

  Future<List<Map<String, dynamic>>> getRecentTransactions(
    int anneeId, {
    int limit = 10,
    int offset = 0,
    String? searchQuery,
    String? modeFilter,
  }) async {
    String queryStr =
        '''
      SELECT pd.*, e.nom as eleve_nom, e.prenom as eleve_prenom, e.id as eleve_id, e.photo as eleve_photo, 
             c.nom as classe_nom, u.nom_complet as agent_nom, u.pseudo as agent_pseudo
      FROM ${PaiementDetailSchema.tableName} pd
      JOIN eleve e ON pd.eleve_id = e.id
      JOIN eleve_parcours ep ON ep.eleve_id = e.id AND ep.annee_scolaire_id = pd.annee_scolaire_id
      JOIN classe c ON ep.classe_id = c.id
      LEFT JOIN user u ON pd.created_by_id = u.id
      WHERE pd.annee_scolaire_id = ?
    ''';
    List<dynamic> args = [anneeId];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      queryStr += ' AND (e.nom LIKE ? OR e.prenom LIKE ?)';
      args.addAll(['%$searchQuery%', '%$searchQuery%']);
    }

    if (modeFilter != null && modeFilter != 'Tous') {
      queryStr += ' AND pd.mode_paiement = ?';
      args.add(modeFilter);
    }

    queryStr += ' ORDER BY pd.date_paiement DESC LIMIT ? OFFSET ?';
    args.addAll([limit, offset]);

    return await db.rawQuery(queryStr, args);
  }

  Future<int> countPayments(
    int anneeId, {
    String? searchQuery,
    String? modeFilter,
  }) async {
    String queryStr =
        '''
      SELECT COUNT(*) as count 
      FROM ${PaiementDetailSchema.tableName} pd
      JOIN eleve e ON pd.eleve_id = e.id
      JOIN eleve_parcours ep ON ep.eleve_id = e.id AND ep.annee_scolaire_id = pd.annee_scolaire_id
      JOIN classe c ON ep.classe_id = c.id
      WHERE pd.annee_scolaire_id = ?
    ''';
    List<dynamic> args = [anneeId];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      queryStr += ' AND (e.nom LIKE ? OR e.prenom LIKE ?)';
      args.addAll(['%$searchQuery%', '%$searchQuery%']);
    }

    if (modeFilter != null && modeFilter != 'Tous') {
      queryStr += ' AND pd.mode_paiement = ?';
      args.add(modeFilter);
    }

    final result = await db.rawQuery(queryStr, args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getPaymentMonthlyStats(int anneeId) async {
    return await db.rawQuery(
      '''
      SELECT SUBSTR(date_paiement, 1, 7) as month, SUM(montant) as total 
      FROM ${PaiementDetailSchema.tableName}
      WHERE annee_scolaire_id = ?
      GROUP BY month
      ORDER BY month DESC
      LIMIT 6
    ''',
      [anneeId],
    );
  }

  Future<bool> isBlocked(int eleveId, int anneeId) async {
    final result = await db.query(
      PaiementSchema.tableName,
      where: 'eleve_id = ? AND annee_scolaire_id = ?',
      whereArgs: [eleveId, anneeId],
    );

    if (result.isEmpty) return false;
    double reste = (result.first['montant_restant'] as num?)?.toDouble() ?? 0;
    return reste > 0;
  }

  Future<Map<String, double>> getStudentFinancialStatus(
    int eleveId,
    int anneeId,
  ) async {
    // 1. Get total paid by student for the year
    final paidResult = await db.rawQuery(
      '''
      SELECT SUM(montant) as total_paid
      FROM paiement_detail
      WHERE eleve_id = ? AND annee_scolaire_id = ?
    ''',
      [eleveId, anneeId],
    );

    final totalPaid =
        (paidResult.first['total_paid'] as num?)?.toDouble() ?? 0.0;

    // 2. Get student's class ID and status from their parcours for the given year
    final parcoursResult = await db.query(
      'eleve_parcours',
      columns: ['classe_id'],
      where: 'eleve_id = ? AND annee_scolaire_id = ?',
      whereArgs: [eleveId, anneeId],
      limit: 1,
    );

    if (parcoursResult.isEmpty) {
      return {'totalPaid': totalPaid, 'totalExpected': 0.0, 'balance': 0.0};
    }

    final studentResult = await db.query(
      'eleve',
      columns: ['statut'],
      where: 'id = ?',
      whereArgs: [eleveId],
      limit: 1,
    );

    final classeId = parcoursResult.first['classe_id'] as int;
    final statut = studentResult.isNotEmpty
        ? studentResult.first['statut'] as String?
        : null;

    // 3. Get total expected fees for the class from frais_scolarite
    final feesResult = await db.query(
      'frais_scolarite',
      where: 'classe_id = ? AND annee_scolaire_id = ?',
      whereArgs: [classeId, anneeId],
      limit: 1,
    );

    double totalExpected = 0.0;
    if (feesResult.isNotEmpty) {
      final f = feesResult.first;
      // Depending on student status (inscrit vs reinscrit)
      double enrollmentFee = (statut == 'inscrit')
          ? (f['inscription'] as num?)?.toDouble() ?? 0.0
          : (f['reinscription'] as num?)?.toDouble() ?? 0.0;

      totalExpected =
          enrollmentFee +
          ((f['tranche1'] as num?)?.toDouble() ?? 0.0) +
          ((f['tranche2'] as num?)?.toDouble() ?? 0.0) +
          ((f['tranche3'] as num?)?.toDouble() ?? 0.0);
    }

    return {
      'totalPaid': totalPaid,
      'totalExpected': totalExpected,
      'balance': totalExpected - totalPaid,
    };
  }

  Future<List<Map<String, dynamic>>> getStudentPaymentControlData(
    int anneeId,
  ) async {
    return await db.rawQuery(
      '''
      SELECT 
        e.id, e.nom, e.prenom, e.matricule, e.statut as eleve_statut, e.photo,
        ep.classe_id, c.nom as classe_nom,
        cy.nom as cycle_nom,
        fs.inscription, fs.reinscription, fs.tranche1, fs.tranche2, fs.tranche3, fs.montant_total,
        COALESCE(p.montant_paye, 0) as total_paye,
        p.montant_restant
      FROM eleve e
      JOIN eleve_parcours ep ON e.id = ep.eleve_id
      JOIN classe c ON ep.classe_id = c.id
      JOIN cycles_scolaires cy ON c.cycle_id = cy.id
      LEFT JOIN frais_scolarite fs ON ep.classe_id = fs.classe_id AND ep.annee_scolaire_id = fs.annee_scolaire_id
      LEFT JOIN ${PaiementSchema.tableName} p ON p.eleve_id = e.id AND p.annee_scolaire_id = ep.annee_scolaire_id
      WHERE ep.annee_scolaire_id = ?
      ORDER BY cy.nom ASC, c.nom ASC, e.nom ASC
    ''',
      [anneeId],
    );
  }

  Future<List<Map<String, dynamic>>> getOverdueStudents(int anneeId) async {
    final now = DateTime.now();
    final DateFormat formatter = DateFormat('dd/MM/yyyy');

    // 1. Get all students with their class and fee info
    final data = await db.rawQuery(
      '''
      SELECT 
        e.id, e.nom, e.prenom, e.matricule, e.photo,
        c.nom as classe_nom,
        fs.date_limite_t1, fs.tranche1,
        fs.date_limite_t2, fs.tranche2,
        fs.date_limite_t3, fs.tranche3,
        COALESCE(p.montant_paye, 0) as total_paye,
        COALESCE(fs.inscription, 0) as inscription,
        COALESCE(fs.reinscription, 0) as reinscription,
        e.statut as eleve_statut
      FROM eleve e
      JOIN eleve_parcours ep ON e.id = ep.eleve_id
      JOIN classe c ON ep.classe_id = c.id
      JOIN frais_scolarite fs ON ep.classe_id = fs.classe_id AND ep.annee_scolaire_id = fs.annee_scolaire_id
      LEFT JOIN ${PaiementSchema.tableName} p ON p.eleve_id = e.id AND p.annee_scolaire_id = ep.annee_scolaire_id
      WHERE ep.annee_scolaire_id = ?
    ''',
      [anneeId],
    );

    List<Map<String, dynamic>> overdue = [];

    for (var row in data) {
      double totalPaye = (row['total_paye'] as num).toDouble();
      double initialFee = (row['eleve_statut'] == 'inscrit'
          ? (row['inscription'] as num).toDouble()
          : (row['reinscription'] as num).toDouble());

      double remainingAfterInitial = totalPaye - initialFee;

      // Check Tranche 1
      if (row['date_limite_t1'] != null && (row['tranche1'] as num) > 0) {
        try {
          DateTime deadline = formatter.parse(row['date_limite_t1'] as String);
          if (now.isAfter(deadline)) {
            double tranche1 = (row['tranche1'] as num).toDouble();
            if (remainingAfterInitial < tranche1) {
              overdue.add({
                ...row,
                'overdue_tranche': 'Tranche 1',
                'amount_due':
                    tranche1 -
                    (remainingAfterInitial > 0 ? remainingAfterInitial : 0),
                'deadline': row['date_limite_t1'],
              });
              continue;
            }
            remainingAfterInitial -= tranche1;
          } else {
            remainingAfterInitial -= (row['tranche1'] as num).toDouble();
          }
        } catch (e) {}
      }

      // Check Tranche 2
      if (row['date_limite_t2'] != null && (row['tranche2'] as num) > 0) {
        try {
          DateTime deadline = formatter.parse(row['date_limite_t2'] as String);
          if (now.isAfter(deadline)) {
            double tranche2 = (row['tranche2'] as num).toDouble();
            if (remainingAfterInitial < tranche2) {
              overdue.add({
                ...row,
                'overdue_tranche': 'Tranche 2',
                'amount_due':
                    tranche2 -
                    (remainingAfterInitial > 0 ? remainingAfterInitial : 0),
                'deadline': row['date_limite_t2'],
              });
              continue;
            }
            remainingAfterInitial -= tranche2;
          } else {
            remainingAfterInitial -= (row['tranche2'] as num).toDouble();
          }
        } catch (e) {}
      }

      // Check Tranche 3
      if (row['date_limite_t3'] != null && (row['tranche3'] as num) > 0) {
        try {
          DateTime deadline = formatter.parse(row['date_limite_t3'] as String);
          if (now.isAfter(deadline)) {
            double tranche3 = (row['tranche3'] as num).toDouble();
            if (remainingAfterInitial < tranche3) {
              overdue.add({
                ...row,
                'overdue_tranche': 'Tranche 3',
                'amount_due':
                    tranche3 -
                    (remainingAfterInitial > 0 ? remainingAfterInitial : 0),
                'deadline': row['date_limite_t3'],
              });
            }
          }
        } catch (e) {}
      }
    }

    return overdue;
  }

  Future<Map<String, dynamic>> getFinancialAnalytics(
    int currentYearId, {
    int? previousYearId,
  }) async {
    // Current year financial data
    final currentFinances = await db.rawQuery(
      '''
      SELECT 
        COUNT(DISTINCT pd.eleve_id) as students_paid,
        SUM(pd.montant) as total_collected,
        (SELECT SUM(montant) FROM paiement_enseignant WHERE annee_scolaire_id = ?) as expenses,
        COUNT(pd.id) as payment_count
      FROM ${PaiementDetailSchema.tableName} pd
      JOIN eleve_parcours ep ON pd.eleve_id = ep.eleve_id AND pd.annee_scolaire_id = ep.annee_scolaire_id
      WHERE ep.annee_scolaire_id = ?
    ''',
      [currentYearId, currentYearId],
    );

    // Get total expected fees for current year
    final currentExpected = await db.rawQuery(
      '''
      SELECT 
        SUM(
          (fs.inscription + fs.reinscription + fs.tranche1 + fs.tranche2 + fs.tranche3) * 
          (SELECT COUNT(*) FROM eleve_parcours WHERE classe_id = fs.classe_id AND annee_scolaire_id = ?)
        ) as total_expected
      FROM frais_scolarite fs
      JOIN classe c ON fs.classe_id = c.id
      WHERE fs.annee_scolaire_id = ?
    ''',
      [currentYearId, currentYearId],
    );

    Map<String, dynamic>? previousFinances;
    if (previousYearId != null) {
      final prevResult = await db.rawQuery(
        '''
        SELECT 
          COUNT(DISTINCT pd.eleve_id) as students_paid,
          SUM(pd.montant) as total_collected,
          (SELECT SUM(montant) FROM paiement_enseignant WHERE annee_scolaire_id = ?) as expenses,
          COUNT(pd.id) as payment_count
        FROM ${PaiementDetailSchema.tableName} pd
        JOIN eleve_parcours ep ON pd.eleve_id = ep.eleve_id AND pd.annee_scolaire_id = ep.annee_scolaire_id
        WHERE ep.annee_scolaire_id = ?
      ''',
        [previousYearId, previousYearId],
      );
      previousFinances = prevResult.isNotEmpty ? prevResult.first : null;
    }

    // Payment methods distribution
    final paymentMethods = await db.rawQuery(
      '''
      SELECT pd.mode_paiement, COUNT(*) as count, SUM(pd.montant) as total
      FROM ${PaiementDetailSchema.tableName} pd
      JOIN eleve_parcours ep ON pd.eleve_id = ep.eleve_id AND pd.annee_scolaire_id = ep.annee_scolaire_id
      WHERE ep.annee_scolaire_id = ?
      GROUP BY pd.mode_paiement
    ''',
      [currentYearId],
    );

    // Teacher salaries as expenses
    final salaryResult = await db.rawQuery(
      'SELECT SUM(montant) as total FROM paiement_enseignant WHERE annee_scolaire_id = ?',
      [currentYearId],
    );
    final totalSalaries =
        (salaryResult.first['total'] as num?)?.toDouble() ?? 0.0;

    return {
      'current': {
        ...currentFinances.first,
        'expected': currentExpected.first['total_expected'] ?? 0,
        'expenses': totalSalaries,
        'netRevenue':
            ((currentFinances.first['total_collected'] as num?)?.toDouble() ??
                0.0) -
            totalSalaries,
      },
      'previous': previousFinances,
      'paymentMethods': paymentMethods,
    };
  }

  Future<String> generateNextReceiptNumber(
    DatabaseExecutor db,
    int anneeId,
  ) async {
    final yearResult = await db.query(
      'annee_scolaire',
      columns: ['libelle'],
      where: 'id = ?',
      whereArgs: [anneeId],
    );

    String yearPrefix = '';
    if (yearResult.isNotEmpty) {
      final libelle = yearResult.first['libelle'] as String;
      // Get the last two digits of the year (e.g., 2023-2024 -> 24)
      final years = libelle.split('-');
      if (years.isNotEmpty) {
        final lastYear = years.last.trim();
        if (lastYear.length >= 2) {
          yearPrefix = lastYear.substring(lastYear.length - 2);
        }
      }
    }

    if (yearPrefix.isEmpty) {
      yearPrefix = DateTime.now().year.toString().substring(2);
    }

    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${PaiementDetailSchema.tableName} WHERE annee_scolaire_id = ?',
      [anneeId],
    );

    int count = Sqflite.firstIntValue(countResult) ?? 0;
    String sequence = (count + 1).toString().padLeft(4, '0');

    return 'REC-$yearPrefix-$sequence';
  }

  Future<List<Map<String, dynamic>>> getMonthlyExpenseCurve(int anneeId) async {
    return await db.rawQuery(
      '''
      SELECT SUBSTR(date_paiement, 1, 7) as month, SUM(montant) as total 
      FROM paiement_enseignant
      WHERE annee_scolaire_id = ?
      GROUP BY month
      ORDER BY month ASC
    ''',
      [anneeId],
    );
  }
}
