import 'package:sqflite/sqflite.dart';
import 'base_dao.dart';
import '../schemas/paiement_schema.dart';
import '../schemas/paiement_detail_schema.dart';
import '../schemas/enseignant_schema.dart';
import 'package:intl/intl.dart';

class DashboardDao extends BaseDao {
  DashboardDao(Database db) : super(db);

  Future<Map<String, dynamic>> getDashboardData(int anneeId) async {
    // 1. Student Count
    final studentResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM eleve WHERE annee_scolaire_id = ?',
      [anneeId],
    );

    // 2. Class Count
    final classeResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM classe',
    );

    // 3. Teacher Count (Global)
    final teacherResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${EnseignantSchema.tableName}',
    );

    // 4. Financial Status
    final expectedResult = await db.rawQuery(
      '''
      SELECT SUM(fs.montant_total) as total
      FROM eleve e
      JOIN frais_scolarite fs ON e.classe_id = fs.classe_id AND e.annee_scolaire_id = fs.annee_scolaire_id
      WHERE e.annee_scolaire_id = ?
    ''',
      [anneeId],
    );

    final collectedResult = await db.rawQuery(
      '''
      SELECT SUM(montant_paye) as total
      FROM ${PaiementSchema.tableName}
      WHERE annee_scolaire_id = ?
    ''',
      [anneeId],
    );

    double expected =
        (expectedResult.first['total'] as num?)?.toDouble() ?? 0.0;
    double collected =
        (collectedResult.first['total'] as num?)?.toDouble() ?? 0.0;
    double remaining = expected - collected;
    double recoveryRate = expected > 0 ? (collected / expected) * 100 : 0.0;

    final financial = {
      'expected': expected,
      'collected': collected,
      'remaining': remaining,
      'recoveryRate': recoveryRate,
    };

    // 5. Recent Payments
    final recentPayments = await db.rawQuery(
      '''
      SELECT pd.*, e.nom, e.prenom, c.nom as classe_nom
      FROM ${PaiementDetailSchema.tableName} pd
      JOIN eleve e ON pd.eleve_id = e.id
      JOIN classe c ON e.classe_id = c.id
      WHERE pd.annee_scolaire_id = ?
      ORDER BY pd.date_paiement DESC
      LIMIT 5
    ''',
      [anneeId],
    );

    // 6. Level Stats
    final levelStats = await db.rawQuery(
      '''
      SELECT n.nom, COUNT(e.id) as count 
      FROM eleve e 
      JOIN classe c ON e.classe_id = c.id 
      JOIN niveaux n ON c.niveau_id = n.id
      WHERE e.annee_scolaire_id = ? 
      GROUP BY n.nom
      ''',
      [anneeId],
    );

    // 7. Gender Stats
    final genderStats = await db.rawQuery(
      'SELECT sexe, COUNT(*) as count FROM eleve WHERE annee_scolaire_id = ? GROUP BY sexe',
      [anneeId],
    );

    // 8. Cycle Stats
    final cycleStats = await db.rawQuery(
      '''
      SELECT cy.nom as cycle, COUNT(e.id) as count 
      FROM eleve e 
      JOIN classe c ON e.classe_id = c.id 
      JOIN cycles_scolaires cy ON c.cycle_id = cy.id
      WHERE e.annee_scolaire_id = ? 
      GROUP BY cy.nom
      ''',
      [anneeId],
    );

    // 9. Class Stats
    final classStats = await db.rawQuery(
      '''
      SELECT c.nom, COUNT(e.id) as count 
      FROM eleve e 
      JOIN classe c ON e.classe_id = c.id 
      WHERE e.annee_scolaire_id = ? 
      GROUP BY c.nom
      ORDER BY count DESC
      LIMIT 10
      ''',
      [anneeId],
    );

    // 10. Payment Monthly Stats (6 last months)
    final paymentMonthlyStats = await db.rawQuery(
      '''
      SELECT SUBSTR(pd.date_paiement, 1, 7) as month, SUM(pd.montant) as total 
      FROM ${PaiementDetailSchema.tableName} pd
      WHERE pd.annee_scolaire_id = ?
      GROUP BY month
      ORDER BY month DESC
      LIMIT 6
    ''',
      [anneeId],
    );

    // 11. Academic Stats — cycle-aware moyenne_passage
    final academicStatsResult = await db.rawQuery(
      '''
      SELECT 
        AVG(student_avg) as average,
        COUNT(*) as total,
        SUM(CASE WHEN student_avg >= moyenne_passage THEN 1 ELSE 0 END) as passed
      FROM (
        SELECT
          sub.eleve_id,
          SUM(sub.subj_avg * sub.coef) / NULLIF(SUM(sub.coef), 0) as student_avg,
          MAX(sub.moyenne_passage) as moyenne_passage
        FROM (
          SELECT n.eleve_id, n.matiere_id,
                 AVG(n.note) as subj_avg,
                 COALESCE(cm.coefficient, 1) as coef,
                 COALESCE(cy.moyenne_passage, 10.0) as moyenne_passage
          FROM notes n
          JOIN eleve e ON n.eleve_id = e.id
          JOIN classe c ON e.classe_id = c.id
          LEFT JOIN cycles_scolaires cy ON c.cycle_id = cy.id
          LEFT JOIN classe_matiere cm ON cm.matiere_id = n.matiere_id
            AND cm.classe_id = e.classe_id
          WHERE n.annee_scolaire_id = ?
          GROUP BY n.eleve_id, n.matiere_id, cm.coefficient, cy.moyenne_passage
        ) as sub
        GROUP BY sub.eleve_id
      ) as sub_student
    ''',
      [anneeId],
    );

    final academicData = academicStatsResult.first;
    final acadTotal = academicData['total'] as int? ?? 0;
    final acadPassed = academicData['passed'] as int? ?? 0;

    // 12. Gender-based success rates — cycle-aware moyenne_passage
    Future<Map<String, dynamic>> computeGenderStats(String sexe) async {
      final result = await db.rawQuery(
        '''
        SELECT COUNT(*) as total,
               SUM(CASE WHEN student_avg >= moyenne_passage THEN 1 ELSE 0 END) as passed
        FROM (
          SELECT sub.eleve_id,
                 SUM(sub.note_avg * sub.coef) / NULLIF(SUM(sub.coef), 0) as student_avg,
                 MAX(sub.moyenne_passage) as moyenne_passage
          FROM (
            SELECT n.eleve_id,
                   n.matiere_id,
                   AVG(n.note) as note_avg,
                   COALESCE(cm.coefficient, 1) as coef,
                   COALESCE(cy.moyenne_passage, 10.0) as moyenne_passage
            FROM notes n
            JOIN eleve e ON n.eleve_id = e.id
            JOIN classe c ON e.classe_id = c.id
            LEFT JOIN cycles_scolaires cy ON c.cycle_id = cy.id
            LEFT JOIN classe_matiere cm
              ON cm.matiere_id = n.matiere_id
              AND cm.classe_id = e.classe_id
            WHERE n.annee_scolaire_id = ? AND e.sexe = ?
            GROUP BY n.eleve_id, n.matiere_id, cm.coefficient, cy.moyenne_passage
          ) as sub
          GROUP BY sub.eleve_id
        ) as per_student
        ''',
        [anneeId, sexe],
      );
      final row = result.first;
      final total = (row['total'] as num?)?.toInt() ?? 0;
      final passed = (row['passed'] as num?)?.toInt() ?? 0;
      return {
        'total': total,
        'passed': passed,
        'rate': total > 0 ? (passed / total) * 100 : 0.0,
      };
    }

    final maleData = await computeGenderStats('M');
    final femaleData = await computeGenderStats('F');

    final maleTotal = maleData['total'] as int;
    final malePassed = maleData['passed'] as int;
    final maleSuccessRate = maleData['rate'] as double;
    final femaleTotal = femaleData['total'] as int;
    final femalePassed = femaleData['passed'] as int;
    final femaleSuccessRate = femaleData['rate'] as double;

    final academic = {
      'average': (academicData['average'] as num?)?.toDouble() ?? 0.0,
      'successRate': acadTotal > 0 ? (acadPassed / acadTotal) * 100 : 0.0,
      'totalStudents': acadTotal,
      'maleSuccessRate': maleSuccessRate,
      'femaleSuccessRate': femaleSuccessRate,
      'maleTotal': maleTotal,
      'malePassed': malePassed,
      'femaleTotal': femaleTotal,
      'femalePassed': femalePassed,
    };

    final now = DateTime.now();
    final currentMonthStr = DateFormat('yyyy-MM').format(now);
    final previousMonthStr = DateFormat(
      'yyyy-MM',
    ).format(DateTime(now.year, now.month - 1));

    double thisMonth = 0.0;
    double prevMonth = 0.0;

    for (var row in paymentMonthlyStats) {
      if (row['month'] == currentMonthStr) {
        thisMonth = (row['total'] as num?)?.toDouble() ?? 0.0;
      } else if (row['month'] == previousMonthStr) {
        prevMonth = (row['total'] as num?)?.toDouble() ?? 0.0;
      }
    }

    double growth = 0.0;
    if (prevMonth > 0) {
      growth = ((thisMonth - prevMonth) / prevMonth) * 100;
    } else if (thisMonth > 0) {
      growth = 100.0;
    }

    financial['thisMonth'] = thisMonth;
    financial['growth'] = growth;

    return {
      'students': studentResult.first['count'] as int? ?? 0,
      'classes': classeResult.first['count'] as int? ?? 0,
      'teachers': teacherResult.first['count'] as int? ?? 0,
      'financial': financial,
      'academic': academic,
      'recentPayments': recentPayments,
      'levelStats': levelStats,
      'genderStats': genderStats,
      'cycleStats': cycleStats,
      'classStats': classStats,
      'paymentMonthlyStats': paymentMonthlyStats,
    };
  }
}
