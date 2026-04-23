import 'package:sqflite/sqflite.dart';
import 'base_dao.dart';

class ResultDao extends BaseDao {
  ResultDao(Database db) : super(db);

  Future<double> calculerMoyenneGenerale(int eleveId, int anneeId) async {
    final result = await db.rawQuery(
      '''
      SELECT SUM(note * coef) / SUM(coef) as moyenne
      FROM (
        SELECT n.note, COALESCE(cm.coefficient, 1) as coef
        FROM notes n
        JOIN eleve e ON n.eleve_id = e.id
        LEFT JOIN classe_matiere cm ON cm.matiere_id = n.matiere_id AND cm.classe_id = e.classe_id
        WHERE n.eleve_id = ? AND n.annee_scolaire_id = ?
      )
    ''',
      [eleveId, anneeId],
    );

    return (result.first['moyenne'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<String, dynamic>> getBulletinStats(
    int studentId,
    int classId,
    int trimestre,
    int anneeId,
  ) async {
    // 1. Get average and cycle info for the specific student
    final studentDataResult = await db.rawQuery(
      '''
      SELECT 
        SUM(note * COALESCE(cm.coefficient, 1)) / SUM(COALESCE(cm.coefficient, 1)) as average,
        cy.moyenne_passage,
        cy.note_min,
        cy.note_max
      FROM notes n
      JOIN matiere m ON n.matiere_id = m.id
      JOIN eleve e ON n.eleve_id = e.id
      JOIN classe c ON e.classe_id = c.id
      LEFT JOIN cycles_scolaires cy ON c.cycle_id = cy.id
      LEFT JOIN classe_matiere cm ON cm.matiere_id = m.id 
           AND cm.classe_id = e.classe_id
      WHERE n.eleve_id = ? AND n.trimestre = ? AND n.annee_scolaire_id = ?
      GROUP BY cy.moyenne_passage, cy.note_min, cy.note_max
    ''',
      [studentId, trimestre, anneeId],
    );

    final studentData = studentDataResult.isNotEmpty
        ? studentDataResult.first
        : {};
    double studentAvg = (studentData['average'] as num?)?.toDouble() ?? 0.0;
    double passMark =
        (studentData['moyenne_passage'] as num?)?.toDouble() ?? 10.0;
    double noteMin = (studentData['note_min'] as num?)?.toDouble() ?? 0.0;
    double noteMax = (studentData['note_max'] as num?)?.toDouble() ?? 20.0;

    // 2. Get averages for all students in the class to calculate rank and class average
    final allAvgsResult = await db.rawQuery(
      '''
      SELECT ep.eleve_id as id, SUM(n.note * COALESCE(cm.coefficient, 1)) / SUM(COALESCE(cm.coefficient, 1)) as average
      FROM eleve_parcours ep
      JOIN notes n ON n.eleve_id = ep.eleve_id AND n.annee_scolaire_id = ep.annee_scolaire_id
      JOIN matiere m ON n.matiere_id = m.id
      LEFT JOIN classe_matiere cm ON cm.matiere_id = m.id 
           AND cm.classe_id = ep.classe_id
      WHERE ep.classe_id = ? AND n.trimestre = ? AND ep.annee_scolaire_id = ?
      GROUP BY ep.eleve_id
      ORDER BY average DESC
    ''',
      [classId, trimestre, anneeId],
    );

    int rank = 0;
    double totalClassAvg = 0;
    for (int i = 0; i < allAvgsResult.length; i++) {
      totalClassAvg += (allAvgsResult[i]['average'] as num?)?.toDouble() ?? 0.0;
      if (allAvgsResult[i]['id'] == studentId) {
        rank = i + 1;
      }
    }

    double classAvg = allAvgsResult.isNotEmpty
        ? totalClassAvg / allAvgsResult.length
        : 0.0;

    // 4. Get student total points
    final studentSumResult = await db.rawQuery(
      '''
      SELECT SUM(n.note * COALESCE(cm.coefficient, 1)) as total_points
      FROM notes n
      JOIN eleve_parcours ep ON n.eleve_id = ep.eleve_id AND ep.annee_scolaire_id = n.annee_scolaire_id
      JOIN matiere m ON n.matiere_id = m.id
      LEFT JOIN classe_matiere cm ON cm.matiere_id = m.id 
           AND cm.classe_id = ep.classe_id
      WHERE n.eleve_id = ? AND n.trimestre = ? AND n.annee_scolaire_id = ?
    ''',
      [studentId, trimestre, anneeId],
    );
    double totalPoints =
        (studentSumResult.first['total_points'] as num?)?.toDouble() ?? 0.0;

    return {
      'average': studentAvg,
      'rank': rank,
      'classAverage': classAvg,
      'totalStudents': allAvgsResult.length,
      'moyenne_passage': passMark,
      'note_min': noteMin,
      'note_max': noteMax,
      'totalPoints': totalPoints,
    };
  }

  Future<List<Map<String, dynamic>>> getAnnualGradesForStudent(
    int studentId,
    int anneeId, {
    int? classId,
  }) async {
    // Fetch classId if not provided (needed for rank)
    int? effectiveClassId = classId;
    if (effectiveClassId == null) {
      final studentInfo = await db.query(
        'eleve_parcours',
        columns: ['classe_id'],
        where: 'eleve_id = ? AND annee_scolaire_id = ?',
        whereArgs: [studentId, anneeId],
      );
      if (studentInfo.isNotEmpty) {
        effectiveClassId = studentInfo.first['classe_id'] as int;
      }
    }

    // 1. Get all grades for the year
    final allGrades = await db.rawQuery(
      '''
      SELECT n.note, n.trimestre, 
             m.id as matiere_id, m.nom as matiere_nom, 
             COALESCE(cm.coefficient, 1) as coefficient
      FROM notes n
      JOIN matiere m ON n.matiere_id = m.id
      JOIN eleve_parcours ep ON n.eleve_id = ep.eleve_id AND ep.annee_scolaire_id = n.annee_scolaire_id
      LEFT JOIN classe_matiere cm ON cm.matiere_id = m.id 
           AND cm.classe_id = ep.classe_id
      WHERE n.eleve_id = ? AND n.annee_scolaire_id = ?
      ORDER BY m.nom
    ''',
      [studentId, anneeId],
    );

    // 2. Pivot and calculate averages per subject
    Map<int, Map<String, dynamic>> subjectStats = {};

    for (var row in allGrades) {
      int matId = row['matiere_id'] as int;
      String matNom = row['matiere_nom'] as String;
      double coeff = (row['coefficient'] as num).toDouble();
      double note = (row['note'] as num).toDouble();
      int tri = row['trimestre'] as int;

      if (!subjectStats.containsKey(matId)) {
        subjectStats[matId] = {
          'matiere_id': matId,
          'matiere_nom': matNom,
          'coefficient': coeff,
          'notes': <int, double?>{},
        };
      }
      (subjectStats[matId]!['notes'] as Map<int, double?>)[tri] = note;
    }

    // 3. Calculate annual averages and subject ranks
    List<Map<String, dynamic>> results = [];
    for (var stat in subjectStats.values) {
      final notesMap = stat['notes'] as Map<int, double?>;

      int count = 0;
      double sum = 0;
      notesMap.forEach((triId, val) {
        if (val != null) {
          sum += val;
          count++;
        }
      });

      double moyAnnuelle = count > 0 ? sum / count : 0.0;

      int rank = 0;
      if (effectiveClassId != null) {
        rank = await _getAnnualSubjectRank(
          stat['matiere_id'],
          moyAnnuelle,
          effectiveClassId,
          anneeId,
        );
      }

      results.add({
        'matiere_id': stat['matiere_id'],
        'matiere': stat['matiere_nom'],
        'coefficient': stat['coefficient'],
        'coeff': stat['coefficient'],
        'notes_par_trimestre': notesMap,
        'moy_annuelle': moyAnnuelle,
        'note': moyAnnuelle,
        'total': moyAnnuelle * (stat['coefficient'] ?? 1.0),
        'rang': rank,
        'appreciation': appreciationAutomatique(moyAnnuelle),
      });
    }

    return results;
  }

  Future<int> _getAnnualSubjectRank(
    int matiereId,
    double targetAvg,
    int classeId,
    int anneeId,
  ) async {
    // Get annual averages for this subject for all students in the class
    final allGrades = await db.rawQuery(
      '''
      SELECT n.eleve_id, n.note, n.trimestre
      FROM notes n
      JOIN eleve_parcours ep ON n.eleve_id = ep.eleve_id AND ep.annee_scolaire_id = n.annee_scolaire_id
      WHERE n.matiere_id = ? 
        AND n.annee_scolaire_id = ?
        AND ep.classe_id = ?
    ''',
      [matiereId, anneeId, classeId],
    );

    // Pivot in memory to get annual avg per student
    Map<int, List<double>> studentGrades = {};
    for (var row in allGrades) {
      int sId = row['eleve_id'] as int;
      double note = (row['note'] as num).toDouble();
      if (!studentGrades.containsKey(sId)) {
        studentGrades[sId] = [];
      }
      studentGrades[sId]!.add(note);
    }

    List<double> annualAvgs = [];
    for (var grades in studentGrades.values) {
      if (grades.isNotEmpty) {
        double avg = grades.reduce((a, b) => a + b) / grades.length;
        annualAvgs.add(avg);
      }
    }

    annualAvgs.sort((a, b) => b.compareTo(a)); // Descending
    int rank = annualAvgs.indexOf(targetAvg) + 1;
    return rank > 0 ? rank : annualAvgs.length + 1; // Fallback
  }

  Future<Map<String, dynamic>> getAnnualStats(
    int studentId,
    int classId,
    int anneeId,
    Future<List<Map<String, dynamic>>> Function(int) getStudentsByClasse,
  ) async {
    final grades = await getAnnualGradesForStudent(studentId, anneeId);

    double totalPoints = 0;
    double totalCoeff = 0;

    for (var g in grades) {
      double moy = (g['moy_annuelle'] as num?)?.toDouble() ?? 0.0;
      double coeff = (g['coefficient'] as num?)?.toDouble() ?? 1.0;
      totalPoints += moy * coeff;
      totalCoeff += coeff;
    }

    double annualAvg = totalCoeff > 0 ? totalPoints / totalCoeff : 0.0;

    // Calculate Rank
    final allStudents = await getStudentsByClasse(classId);
    List<double> allAverages = [];

    for (var s in allStudents) {
      final sGrades = await getAnnualGradesForStudent(s['id'] as int, anneeId);
      double sTotalPoints = 0;
      double sTotalCoeff = 0;
      for (var g in sGrades) {
        double sMoy = (g['moy_annuelle'] as num?)?.toDouble() ?? 0.0;
        double sCoeff = (g['coefficient'] as num?)?.toDouble() ?? 1.0;
        sTotalPoints += sMoy * sCoeff;
        sTotalCoeff += sCoeff;
      }
      allAverages.add(sTotalCoeff > 0 ? sTotalPoints / sTotalCoeff : 0.0);
    }

    allAverages.sort((a, b) => b.compareTo(a)); // Descending
    int rank = allAverages.indexOf(annualAvg) + 1;

    double classTotalAvg = allAverages.isNotEmpty
        ? allAverages.reduce((a, b) => a + b) / allAverages.length
        : 0.0;

    final cycleResult = await db.rawQuery(
      'SELECT cy.moyenne_passage, cy.note_min, cy.note_max FROM classe c JOIN cycles_scolaires cy ON c.cycle_id = cy.id WHERE c.id = ?',
      [classId],
    );
    final cycleData = cycleResult.isNotEmpty ? cycleResult.first : {};
    double passMark =
        (cycleData['moyenne_passage'] as num?)?.toDouble() ?? 10.0;
    double noteMin = (cycleData['note_min'] as num?)?.toDouble() ?? 0.0;
    double noteMax = (cycleData['note_max'] as num?)?.toDouble() ?? 20.0;

    return {
      'average': annualAvg,
      'rank': rank,
      'classAverage': classTotalAvg,
      'totalStudents': allStudents.length,
      'moyenne_passage': passMark,
      'note_min': noteMin,
      'note_max': noteMax,
      'totalPoints': totalPoints,
      'totalCoeff': totalCoeff,
    };
  }

  Future<List<Map<String, dynamic>>> getGradesByClassSubject(
    int classId,
    int subjectId,
    int trimestre,
    int sequence,
    int anneeId,
  ) async {
    return await db.rawQuery(
      '''
      SELECT e.id as eleve_id, e.nom, e.prenom, e.matricule, e.photo, n.note, n.id as note_id,
             COALESCE(cm.coefficient, 1) as coefficient
      FROM eleve e
      LEFT JOIN notes n ON n.eleve_id = e.id 
          AND n.matiere_id = ? 
          AND n.trimestre = ? 
          AND n.sequence = ?
          AND n.annee_scolaire_id = ?
      LEFT JOIN classe_matiere cm ON cm.matiere_id = ? 
          AND cm.classe_id = e.classe_id
      WHERE e.classe_id = ?
      ORDER BY e.nom ASC, e.prenom ASC
    ''',
      [subjectId, trimestre, sequence, anneeId, subjectId, classId],
    );
  }

  Future<void> saveGrade(Map<String, dynamic> noteData) async {
    final existing = await db.query(
      'notes',
      where:
          'eleve_id = ? AND matiere_id = ? AND trimestre = ? AND sequence = ? AND annee_scolaire_id = ?',
      whereArgs: [
        noteData['eleve_id'],
        noteData['matiere_id'],
        noteData['trimestre'],
        noteData['sequence'],
        noteData['annee_scolaire_id'],
      ],
    );

    if (existing.isNotEmpty) {
      await db.update(
        'notes',
        noteData,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert('notes', noteData);
    }
  }

  Future<Map<String, dynamic>> getGradesStats(
    int classId,
    int subjectId,
    int trimestre,
    int sequence,
    int anneeId, {
    double passingGrade = 10.0,
  }) async {
    final result = await db.rawQuery(
      '''
      SELECT 
        AVG(note) as average,
        MAX(note) as maxNote,
        MIN(note) as minNote,
        COUNT(id) as total,
        SUM(CASE WHEN note >= ? THEN 1 ELSE 0 END) as passed
      FROM notes
      WHERE matiere_id = ? AND trimestre = ? AND sequence = ? AND annee_scolaire_id = ?
      AND eleve_id IN (SELECT id FROM eleve WHERE classe_id = ?)
    ''',
      [passingGrade, subjectId, trimestre, sequence, anneeId, classId],
    );

    if (result.isEmpty || result.first['total'] == 0) {
      return {
        'average': 0.0,
        'maxNote': 0.0,
        'minNote': 0.0,
        'successRate': 0.0,
        'total': 0,
      };
    }

    final data = result.first;
    final total = data['total'] as int;
    final passed = data['passed'] as int;

    return {
      'average': (data['average'] as num?)?.toDouble() ?? 0.0,
      'maxNote': (data['maxNote'] as num?)?.toDouble() ?? 0.0,
      'minNote': (data['minNote'] as num?)?.toDouble() ?? 0.0,
      'successRate': total > 0 ? (passed / total) * 100 : 0.0,
      'total': total,
    };
  }

  Future<Map<String, dynamic>> getAcademicAnalytics(
    int currentYearId,
    int? previousYearId,
  ) async {
    // Current year academic performance
    final currentAcademic = await db.rawQuery(
      '''
      SELECT 
        AVG(n.note) as average_grade,
        COUNT(DISTINCT n.eleve_id) as students_graded,
        COUNT(n.id) as total_grades
      FROM notes n
      JOIN eleve_parcours ep ON n.eleve_id = ep.eleve_id
      WHERE ep.annee_scolaire_id = ?
    ''',
      [currentYearId],
    );

    // Performance by trimester (current year)
    final trimesterPerformance = await db.rawQuery(
      '''
      SELECT 
        n.trimestre,
        AVG(n.note) as average,
        COUNT(DISTINCT n.eleve_id) as students
      FROM notes n
      JOIN eleve_parcours ep ON n.eleve_id = ep.eleve_id
      WHERE ep.annee_scolaire_id = ?
      GROUP BY n.trimestre
      ORDER BY n.trimestre
    ''',
      [currentYearId],
    );

    // Performance by class (current year)
    final classPerformance = await db.rawQuery(
      '''
      SELECT 
        c.nom as class_name,
        cy.nom as cycle,
        AVG(n.note) as average,
        COUNT(DISTINCT n.eleve_id) as students
      FROM notes n
      JOIN eleve_parcours ep ON n.eleve_id = ep.eleve_id
      JOIN classe c ON ep.classe_id = c.id
      JOIN cycles_scolaires cy ON c.cycle_id = cy.id
      WHERE ep.annee_scolaire_id = ?
      GROUP BY c.id
      ORDER BY cy.nom, c.nom
    ''',
      [currentYearId],
    );

    return {
      'current': currentAcademic.first,
      'trimesterPerformance': trimesterPerformance,
      'classPerformance': classPerformance,
    };
  }

  Future<void> calculerRangsClasse(int classeId, int anneeId) async {
    // Note: Rankin logic often involves multiple queries or complex window functions
    // For now, mirroring what might be in DatabaseHelper or providing a placeholder
    // if the logic was previously inlined.
  }

  Future<void> passerEleves(
    List<int> ids,
    int nouvelleClasseId,
    int nouvelleAnneeId,
  ) async {
    final batch = db.batch();
    for (var id in ids) {
      batch.insert('eleve_parcours', {
        'eleve_id': id,
        'classe_id': nouvelleClasseId,
        'annee_scolaire_id': nouvelleAnneeId,
        'date_inscription': DateTime.now().toIso8601String(),
      });
      batch.update(
        'eleve',
        {'classe_id': nouvelleClasseId},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  String appreciationAutomatique(double moyenne) {
    if (moyenne >= 18) return 'Excellent';
    if (moyenne >= 16) return 'Très Bien';
    if (moyenne >= 14) return 'Bien';
    if (moyenne >= 12) return 'Assez Bien';
    if (moyenne >= 10) return 'Passable';
    return 'Médiocre';
  }

  Future<String> getAppreciation(double moyenne) async {
    final result = await db.query(
      'mention_config',
      where: 'min_note <= ? AND max_note >= ?',
      whereArgs: [moyenne, moyenne],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first['mention'] as String;
    }
    return appreciationAutomatique(moyenne);
  }
}
