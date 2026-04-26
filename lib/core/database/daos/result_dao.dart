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
        JOIN eleve_parcours ep ON n.eleve_id = ep.eleve_id AND ep.annee_scolaire_id = n.annee_scolaire_id
        LEFT JOIN classe_matiere cm ON cm.matiere_id = n.matiere_id AND cm.classe_id = ep.classe_id
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
      JOIN eleve_parcours ep ON n.eleve_id = ep.eleve_id AND n.annee_scolaire_id = ep.annee_scolaire_id
      JOIN classe c ON ep.classe_id = c.id
      LEFT JOIN cycles_scolaires cy ON c.cycle_id = cy.id
      LEFT JOIN classe_matiere cm ON cm.matiere_id = m.id 
           AND cm.classe_id = ep.classe_id
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

    // 1. Get all grades for the student for the pivot
    final studentGrades = await db.rawQuery(
      '''
      SELECT n.note, n.trimestre, m.id as matiere_id
      FROM notes n
      JOIN matiere m ON n.matiere_id = m.id
      WHERE n.eleve_id = ? AND n.annee_scolaire_id = ?
    ''',
      [studentId, anneeId],
    );

    // 2. Get annual averages and ranks for all subjects using a single window function query
    final subjectStatsResult = await db.rawQuery(
      '''
      WITH SubjectAverages AS (
          SELECT 
              n.eleve_id,
              n.matiere_id,
              AVG(n.note) as moy_annuelle
          FROM notes n
          JOIN eleve_parcours ep ON n.eleve_id = ep.eleve_id AND ep.annee_scolaire_id = n.annee_scolaire_id
          WHERE ep.classe_id = ? AND n.annee_scolaire_id = ?
          GROUP BY n.eleve_id, n.matiere_id
      ),
      SubjectRanks AS (
          SELECT 
              eleve_id,
              matiere_id,
              moy_annuelle,
              RANK() OVER (PARTITION BY matiere_id ORDER BY moy_annuelle DESC) as rang
          FROM SubjectAverages
      )
      SELECT 
          sr.*,
          m.nom as matiere_nom,
          COALESCE(cm.coefficient, 1) as coefficient,
          cy.note_max
      FROM SubjectRanks sr
      JOIN matiere m ON sr.matiere_id = m.id
      JOIN classe c ON c.id = ?
      JOIN cycles_scolaires cy ON c.cycle_id = cy.id
      LEFT JOIN classe_matiere cm ON cm.matiere_id = sr.matiere_id AND cm.classe_id = ?
      WHERE sr.eleve_id = ?
      ORDER BY m.nom
      ''',
      [
        effectiveClassId,
        anneeId,
        effectiveClassId,
        effectiveClassId,
        studentId,
      ],
    );

    // 3. Prepare notes map for each subject
    Map<int, Map<int, double?>> notesPerSubject = {};
    for (var row in studentGrades) {
      int matId = row['matiere_id'] as int;
      int tri = row['trimestre'] as int;
      double note = (row['note'] as num).toDouble();

      notesPerSubject.putIfAbsent(matId, () => <int, double?>{})[tri] = note;
    }

    // 4. Build final results
    return subjectStatsResult.map((row) {
      int matId = row['matiere_id'] as int;
      double moyAnnuelle = (row['moy_annuelle'] as num).toDouble();
      double coeff = (row['coefficient'] as num).toDouble();
      double noteMax = (row['note_max'] as num?)?.toDouble() ?? 20.0;

      return {
        'matiere_id': matId,
        'matiere': row['matiere_nom'],
        'coefficient': coeff,
        'coeff': coeff,
        'notes_par_trimestre': notesPerSubject[matId] ?? {},
        'moy_annuelle': moyAnnuelle,
        'note': moyAnnuelle,
        'note_max': noteMax,
        'total': moyAnnuelle * coeff,
        'rang': row['rang'],
        'appreciation': appreciationAutomatique(moyAnnuelle, noteMax: noteMax),
      };
    }).toList();
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

    // Calculate Rank via SQL to avoid N+1 queries
    final classAvgsResult = await db.rawQuery(
      '''
      SELECT 
        eleve_id,
        SUM(moy_annuelle * coef) / SUM(coef) as annual_average
      FROM (
        SELECT 
          n.eleve_id,
          n.matiere_id,
          AVG(n.note) as moy_annuelle,
          MAX(COALESCE(cm.coefficient, 1)) as coef
        FROM notes n
        JOIN eleve_parcours ep ON ep.eleve_id = n.eleve_id AND ep.annee_scolaire_id = n.annee_scolaire_id
        LEFT JOIN classe_matiere cm ON cm.matiere_id = n.matiere_id AND cm.classe_id = ep.classe_id
        WHERE ep.classe_id = ? AND n.annee_scolaire_id = ?
        GROUP BY n.eleve_id, n.matiere_id
      ) subquery
      GROUP BY eleve_id
      ORDER BY annual_average DESC
      ''',
      [classId, anneeId],
    );

    int rank = 0;
    double classTotalAvg = 0;
    int index = 1;
    for (var row in classAvgsResult) {
      double avg = (row['annual_average'] as num?)?.toDouble() ?? 0.0;
      classTotalAvg += avg;
      if (row['eleve_id'] == studentId) rank = index;
      index++;
    }

    if (classAvgsResult.isNotEmpty) {
      classTotalAvg = classTotalAvg / classAvgsResult.length;
    }

    final allStudents = await getStudentsByClasse(
      classId,
    ); // We still need the count if the query doesn't yield all students

    if (rank == 0 && allStudents.any((s) => s['id'] == studentId)) {
      rank = classAvgsResult.length + 1;
    }

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
      JOIN eleve_parcours ep ON e.id = ep.eleve_id AND ep.annee_scolaire_id = ?
      LEFT JOIN notes n ON n.eleve_id = e.id 
          AND n.matiere_id = ? 
          AND n.trimestre = ? 
          AND n.sequence = ?
          AND n.annee_scolaire_id = ?
      LEFT JOIN classe_matiere cm ON cm.matiere_id = ? 
          AND cm.classe_id = ep.classe_id
      WHERE ep.classe_id = ?
      ORDER BY e.nom ASC, e.prenom ASC
    ''',
      [anneeId, subjectId, trimestre, sequence, anneeId, subjectId, classId],
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
        AVG(n.note) as average,
        MAX(n.note) as maxNote,
        MIN(n.note) as minNote,
        COUNT(n.id) as total,
        SUM(CASE WHEN n.note >= ? THEN 1 ELSE 0 END) as passed
      FROM notes n
      JOIN eleve_parcours ep ON n.eleve_id = ep.eleve_id AND ep.annee_scolaire_id = n.annee_scolaire_id
      WHERE n.matiere_id = ? AND n.trimestre = ? AND n.sequence = ? AND n.annee_scolaire_id = ?
      AND ep.classe_id = ?
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
    const academicQuery = '''
      SELECT 
        AVG(n.note) as average_grade,
        COUNT(DISTINCT n.eleve_id) as students_graded,
        COUNT(n.id) as total_grades,
        (CAST(SUM(CASE WHEN n.note >= 10.0 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(n.id)) * 100.0 as success_rate
      FROM notes n
      WHERE n.annee_scolaire_id = ?
    ''';

    final currentAcademic = await db.rawQuery(academicQuery, [currentYearId]);

    Map<String, dynamic>? previousAcademic;
    if (previousYearId != null) {
      final prevResult = await db.rawQuery(academicQuery, [previousYearId]);
      if (prevResult.isNotEmpty) {
        previousAcademic = prevResult.first;
      }
    }

    // Performance by trimester (current year)
    final trimesterPerformance = await db.rawQuery(
      '''
      SELECT 
        n.trimestre,
        AVG(n.note) as average,
        COUNT(DISTINCT n.eleve_id) as students
      FROM notes n
      WHERE n.annee_scolaire_id = ?
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
      JOIN eleve_parcours ep ON n.eleve_id = ep.eleve_id AND ep.annee_scolaire_id = n.annee_scolaire_id
      JOIN classe c ON ep.classe_id = c.id
      JOIN cycles_scolaires cy ON c.cycle_id = cy.id
      WHERE n.annee_scolaire_id = ?
      GROUP BY c.id
      ORDER BY cy.nom, c.nom
    ''',
      [currentYearId],
    );

    return {
      'current': currentAcademic.first,
      'previous': previousAcademic,
      'trimesterPerformance': trimesterPerformance,
      'classPerformance': classPerformance,
    };
  }

  Future<void> calculerRangsClasse(int classeId, int anneeId) async {
    final classAvgsResult = await db.rawQuery(
      '''
      SELECT 
        eleve_id,
        SUM(moy_annuelle * coef) / SUM(coef) as annual_average
      FROM (
        SELECT 
          n.eleve_id,
          n.matiere_id,
          AVG(n.note) as moy_annuelle,
          MAX(COALESCE(cm.coefficient, 1)) as coef
        FROM notes n
        JOIN eleve_parcours ep ON ep.eleve_id = n.eleve_id AND ep.annee_scolaire_id = n.annee_scolaire_id
        LEFT JOIN classe_matiere cm ON cm.matiere_id = n.matiere_id AND cm.classe_id = ep.classe_id
        WHERE ep.classe_id = ? AND n.annee_scolaire_id = ?
        GROUP BY n.eleve_id, n.matiere_id
      ) subquery
      GROUP BY eleve_id
      ORDER BY annual_average DESC
      ''',
      [classeId, anneeId],
    );

    final batch = db.batch();
    for (int i = 0; i < classAvgsResult.length; i++) {
      batch.update(
        'eleve_parcours',
        {
          'rang': i + 1,
          'moyenne': classAvgsResult[i]['annual_average'],
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'eleve_id = ? AND annee_scolaire_id = ?',
        whereArgs: [classAvgsResult[i]['eleve_id'], anneeId],
      );
    }
    await batch.commit(noResult: true);
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
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  String appreciationAutomatique(double moyenne, {double noteMax = 20.0}) {
    double ratio = noteMax > 0 ? moyenne / noteMax : 0;
    if (ratio >= 0.9) return 'Excellent';
    if (ratio >= 0.8) return 'Très Bien';
    if (ratio >= 0.7) return 'Bien';
    if (ratio >= 0.6) return 'Assez Bien';
    if (ratio >= 0.5) return 'Passable';
    return 'Médiocre';
  }

  Future<String> getAppreciation(double moyenne, {int? cycleId}) async {
    final whereClause = cycleId != null
        ? 'note_min <= ? AND note_max >= ? AND cycle_id = ?'
        : 'note_min <= ? AND note_max >= ?';
    final whereArgs = cycleId != null
        ? [moyenne, moyenne, cycleId]
        : [moyenne, moyenne];

    final result = await db.query(
      'mention_config',
      where: whereClause,
      whereArgs: whereArgs,
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first['label'] as String;
    }
    return appreciationAutomatique(moyenne);
  }

  Future<List<Map<String, dynamic>>> getSubjectPerformanceStats(
    int anneeId,
  ) async {
    return await db.rawQuery(
      '''
      SELECT 
        m.nom as matiere_nom, 
        AVG(n.note) as avg_note,
        (CAST(SUM(CASE WHEN n.note >= 10.0 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(n.id)) * 100.0 as taux_reussite,
        COUNT(n.id) as nombre_evaluations
      FROM notes n
      JOIN matiere m ON n.matiere_id = m.id
      WHERE n.annee_scolaire_id = ?
      GROUP BY m.id
      ORDER BY avg_note DESC
      ''',
      [anneeId],
    );
  }

  Future<List<Map<String, dynamic>>> getTeacherPerformanceStats(
    int anneeId,
  ) async {
    return await db.rawQuery(
      '''
      SELECT 
        ens.nom || ' ' || ens.prenom as enseignant_nom, 
        m.nom as matiere_nom,
        AVG(n.note) as avg_note,
        (CAST(SUM(CASE WHEN n.note >= 10.0 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(n.id)) * 100.0 as taux_reussite
      FROM notes n
      JOIN eleve_parcours ep ON n.eleve_id = ep.eleve_id AND n.annee_scolaire_id = ep.annee_scolaire_id
      JOIN attribution_enseignant ae ON n.matiere_id = ae.matiere_id AND ep.classe_id = ae.classe_id
      JOIN enseignant ens ON ae.enseignant_id = ens.id
      JOIN matiere m ON n.matiere_id = m.id
      WHERE n.annee_scolaire_id = ?
      GROUP BY ens.id, m.id
      ORDER BY avg_note DESC
      ''',
      [anneeId],
    );
  }
}
