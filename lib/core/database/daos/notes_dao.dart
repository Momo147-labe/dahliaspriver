import 'package:sqflite/sqflite.dart';
import '../schemas/notes_schema.dart';
import 'base_dao.dart';

class NotesDao extends BaseDao {
  NotesDao(Database db) : super(db);

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
      LEFT JOIN ${NotesSchema.tableName} n ON n.eleve_id = e.id 
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

  Future<List<Map<String, dynamic>>> getTrimesterGradesByClassSubject(
    int classId,
    int subjectId,
    int trimestre,
    int anneeId,
  ) async {
    return await db.rawQuery(
      '''
      SELECT e.id as eleve_id, e.nom, e.prenom, e.matricule, e.photo, 
             n.note, n.id as note_id, n.sequence,
             COALESCE(cm.coefficient, 1) as coefficient
      FROM eleve e
      JOIN eleve_parcours ep ON e.id = ep.eleve_id AND ep.annee_scolaire_id = ?
      LEFT JOIN ${NotesSchema.tableName} n ON n.eleve_id = e.id 
          AND n.matiere_id = ? 
          AND n.trimestre = ? 
          AND n.annee_scolaire_id = ?
      LEFT JOIN classe_matiere cm ON cm.matiere_id = ? 
          AND cm.classe_id = ep.classe_id
      WHERE ep.classe_id = ?
      ORDER BY e.nom ASC, e.prenom ASC, n.sequence ASC
    ''',
      [anneeId, subjectId, trimestre, anneeId, subjectId, classId],
    );
  }

  Future<void> saveGrade(Map<String, dynamic> noteData) async {
    // 1. Validation : Vérifier si un enseignant est affecté
    final eleveResult = await db.rawQuery(
      'SELECT classe_id FROM eleve_parcours WHERE eleve_id = ? AND annee_scolaire_id = ?',
      [noteData['eleve_id'], noteData['annee_scolaire_id']],
    );

    if (eleveResult.isEmpty) {
      throw Exception("Élève non trouvé");
    }

    final int classeId = eleveResult.first['classe_id'] as int;

    // Vérifier l'attribution (globale — sans filtre sur annee_scolaire_id)
    final attribution = await db.query(
      'attribution_enseignant',
      where: 'classe_id = ? AND matiere_id = ?',
      whereArgs: [classeId, noteData['matiere_id']],
    );

    if (attribution.isEmpty) {
      throw Exception(
        "Impossible d'enregistrer la note : aucun enseignant n'est affecté à cette matière pour cette classe.",
      );
    }

    // 2. Enregistrement
    final existing = await db.query(
      NotesSchema.tableName,
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
        NotesSchema.tableName,
        noteData,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert(NotesSchema.tableName, noteData);
    }

    // Trigger rank calculation for the class
    await calculerRangsClasse(classeId, noteData['annee_scolaire_id'] as int);
  }

  Future<void> deleteGrade({
    required int eleveId,
    required int matiereId,
    required int trimestre,
    required int sequence,
    required int anneeId,
  }) async {
    // 1. Get student class for rank recalculation
    final eleveResult = await db.rawQuery(
      'SELECT classe_id FROM eleve_parcours WHERE eleve_id = ? AND annee_scolaire_id = ?',
      [eleveId, anneeId],
    );

    if (eleveResult.isEmpty) return;
    final int classeId = eleveResult.first['classe_id'] as int;

    // 2. Delete the record
    await db.delete(
      NotesSchema.tableName,
      where:
          'eleve_id = ? AND matiere_id = ? AND trimestre = ? AND sequence = ? AND annee_scolaire_id = ?',
      whereArgs: [eleveId, matiereId, trimestre, sequence, anneeId],
    );

    // 3. Recalculate ranks (crucial as removing a grade affects averages)
    await calculerRangsClasse(classeId, anneeId);
  }

  Future<void> deleteAllGradesForSubjectSequence({
    required int classeId,
    required int matiereId,
    required int trimestre,
    required int sequence,
    required int anneeId,
  }) async {
    await db.delete(
      NotesSchema.tableName,
      where:
          'matiere_id = ? AND trimestre = ? AND sequence = ? AND annee_scolaire_id = ? AND eleve_id IN (SELECT eleve_id FROM eleve_parcours WHERE classe_id = ? AND annee_scolaire_id = ?)',
      whereArgs: [
        matiereId,
        trimestre,
        sequence,
        anneeId,
        classeId,
        anneeId,
      ],
    );
    await calculerRangsClasse(classeId, anneeId);
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
      FROM ${NotesSchema.tableName}
      WHERE matiere_id = ? AND trimestre = ? AND sequence = ? AND annee_scolaire_id = ?
      AND eleve_id IN (SELECT eleve_id FROM eleve_parcours WHERE classe_id = ? AND annee_scolaire_id = ?)
    ''',
      [passingGrade, subjectId, trimestre, sequence, anneeId, classId, anneeId],
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

  Future<Map<String, dynamic>> getTrimesterGradesStats(
    int classId,
    int subjectId,
    int trimestre,
    int anneeId, {
    double passingGrade = 10.0,
  }) async {
    final result = await db.rawQuery(
      '''
      SELECT 
        AVG(student_avg) as average,
        MAX(student_avg) as maxNote,
        MIN(student_avg) as minNote,
        COUNT(*) as total,
        SUM(CASE WHEN student_avg >= ? THEN 1 ELSE 0 END) as passed
      FROM (
        SELECT eleve_id, AVG(note) as student_avg
        FROM ${NotesSchema.tableName}
        WHERE matiere_id = ? AND trimestre = ? AND annee_scolaire_id = ?
        AND eleve_id IN (SELECT eleve_id FROM eleve_parcours WHERE classe_id = ? AND annee_scolaire_id = ?)
        GROUP BY eleve_id
      ) as student_averages
    ''',
      [passingGrade, subjectId, trimestre, anneeId, classId, anneeId],
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

  Future<double> calculerMoyenneGenerale(int eleveId, int anneeId) async {
    final result = await db.rawQuery(
      '''
      WITH SubjectTrimesterAvgs AS (
          SELECT 
              n.matiere_id,
              n.trimestre,
              AVG(n.note) as moy_subj_tri,
              MAX(COALESCE(cm.coefficient, 1)) as coef
          FROM ${NotesSchema.tableName} n
          JOIN eleve_parcours ep ON n.eleve_id = ep.eleve_id AND ep.annee_scolaire_id = n.annee_scolaire_id
          LEFT JOIN classe_matiere cm ON cm.matiere_id = n.matiere_id AND cm.classe_id = ep.classe_id
          WHERE n.eleve_id = ? AND n.annee_scolaire_id = ?
          GROUP BY n.matiere_id, n.trimestre
      ),
      SubjectAnnualAvgs AS (
        SELECT 
          matiere_id,
          AVG(moy_subj_tri) as moy_matiere_annuelle,
          coef
        FROM SubjectTrimesterAvgs
        GROUP BY matiere_id
      )
      SELECT SUM(moy_matiere_annuelle * coef) / SUM(coef) as moyenne
      FROM SubjectAnnualAvgs
    ''',
      [eleveId, anneeId],
    );

    return (result.first['moyenne'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Map<String, dynamic>>> getStudentNotesForBulletin(
    int studentId,
    int trimestre,
    int anneeId,
  ) async {
    return await db.rawQuery(
      '''
      SELECT n.*, m.nom as matiere_nom, COALESCE(cm.coefficient, 1) as coefficient
      FROM ${NotesSchema.tableName} n
      JOIN matiere m ON n.matiere_id = m.id
      JOIN eleve_parcours ep ON n.eleve_id = ep.eleve_id AND ep.annee_scolaire_id = n.annee_scolaire_id
      LEFT JOIN classe_matiere cm ON cm.matiere_id = m.id 
           AND cm.classe_id = ep.classe_id
      WHERE n.eleve_id = ? AND n.trimestre = ? AND n.annee_scolaire_id = ?
    ''',
      [studentId, trimestre, anneeId],
    );
  }

  Future<Map<String, dynamic>> getBulletinStats(
    int studentId,
    int classId,
    int trimestre,
    int anneeId,
  ) async {
    // 1. Get cycle info
    final cycleResult = await db.rawQuery(
      'SELECT cy.moyenne_passage, cy.note_min, cy.note_max FROM classe c JOIN cycles_scolaires cy ON c.cycle_id = cy.id WHERE c.id = ?',
      [classId],
    );
    final cycleData = cycleResult.isNotEmpty ? cycleResult.first : {};
    double passMark =
        (cycleData['moyenne_passage'] as num?)?.toDouble() ?? 10.0;
    double noteMin = (cycleData['note_min'] as num?)?.toDouble() ?? 0.0;
    double noteMax = (cycleData['note_max'] as num?)?.toDouble() ?? 20.0;

    // 2. Calculate student average and total points via CTE (Hierarchical Level 1 & 2)
    final studentAvgResult = await db.rawQuery(
      '''
      WITH SubjectAvgs AS (
        SELECT 
          n.matiere_id,
          AVG(n.note) as moy_matiere,
          MAX(COALESCE(cm.coefficient, 1)) as coeff
        FROM ${NotesSchema.tableName} n
        LEFT JOIN classe_matiere cm ON cm.matiere_id = n.matiere_id AND cm.classe_id = ?
        WHERE n.eleve_id = ? AND n.trimestre = ? AND n.annee_scolaire_id = ?
        GROUP BY n.matiere_id
      )
      SELECT 
        SUM(moy_matiere * coeff) / SUM(coeff) as average,
        SUM(moy_matiere * coeff) as total_points
      FROM SubjectAvgs
      ''',
      [classId, studentId, trimestre, anneeId],
    );

    double studentAvg =
        (studentAvgResult.first['average'] as num?)?.toDouble() ?? 0.0;
    double totalPoints =
        (studentAvgResult.first['total_points'] as num?)?.toDouble() ?? 0.0;

    // 3. Get averages for all students in the class
    final allAvgsResult = await db.rawQuery(
      '''
      WITH SubjectAvgs AS (
        SELECT 
          n.eleve_id,
          n.matiere_id,
          AVG(n.note) as moy_matiere,
          MAX(COALESCE(cm.coefficient, 1)) as coeff
        FROM ${NotesSchema.tableName} n
        JOIN eleve_parcours ep ON n.eleve_id = ep.eleve_id AND ep.annee_scolaire_id = n.annee_scolaire_id
        LEFT JOIN classe_matiere cm ON cm.matiere_id = n.matiere_id AND cm.classe_id = ep.classe_id
        WHERE ep.classe_id = ? AND n.trimestre = ? AND n.annee_scolaire_id = ?
        GROUP BY n.eleve_id, n.matiere_id
      )
      SELECT eleve_id, SUM(moy_matiere * coeff) / SUM(coeff) as student_average
      FROM SubjectAvgs
      GROUP BY eleve_id
      ORDER BY student_average DESC
      ''',
      [classId, trimestre, anneeId],
    );

    int rank = 0;
    double totalClassAvg = 0;
    for (int i = 0; i < allAvgsResult.length; i++) {
      totalClassAvg +=
          (allAvgsResult[i]['student_average'] as num?)?.toDouble() ?? 0.0;
      if (allAvgsResult[i]['eleve_id'] == studentId) {
        rank = i + 1;
      }
    }

    double classAvg = allAvgsResult.isNotEmpty
        ? totalClassAvg / allAvgsResult.length
        : 0.0;

    return {
      'average': studentAvg,
      'totalPoints': totalPoints,
      'rank': rank,
      'totalStudents': allAvgsResult.length,
      'classAverage': classAvg,
      'moyenne_passage': passMark,
      'note_min': noteMin,
      'note_max': noteMax,
    };
  }

  Future<List<Map<String, dynamic>>> getAnnualGradesForStudent(
    int studentId,
    int anneeId, {
    int? classId,
  }) async {
    // 1. Get trimester averages for the year (to populate the pivot columns)
    final allGrades = await db.rawQuery(
      '''
      SELECT 
          n.matiere_id,
          n.trimestre,
          AVG(n.note) as average
      FROM ${NotesSchema.tableName} n
      WHERE n.eleve_id = ? AND n.annee_scolaire_id = ?
      GROUP BY n.matiere_id, n.trimestre
      ''',
      [studentId, anneeId],
    );

    // ... (CTE SubjectStatsResult remains same) ...

    // 2. Get annual averages and ranks (Hierarchical)
    final subjectStatsResult = await db.rawQuery(
      '''
      WITH SubjectTrimesterAvgs AS (
          SELECT 
              n.eleve_id,
              n.matiere_id,
              n.trimestre,
              AVG(n.note) as moy_trimestre
          FROM ${NotesSchema.tableName} n
          JOIN eleve_parcours ep ON n.eleve_id = ep.eleve_id AND ep.annee_scolaire_id = n.annee_scolaire_id
          WHERE ep.classe_id = ? AND n.annee_scolaire_id = ?
          GROUP BY n.eleve_id, n.matiere_id, n.trimestre
      ),
      SubjectAnnualAvgs AS (
          SELECT 
              eleve_id,
              matiere_id,
              AVG(moy_trimestre) as moy_annuelle
          FROM SubjectTrimesterAvgs
          GROUP BY eleve_id, matiere_id
      ),
      SubjectRanks AS (
          SELECT 
              eleve_id,
              matiere_id,
              moy_annuelle,
              RANK() OVER (PARTITION BY matiere_id ORDER BY moy_annuelle DESC) as rang
          FROM SubjectAnnualAvgs
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
        classId ??
            0, // Fallback if classId is null, though it shouldn't be for ranks
        anneeId,
        classId ?? 0,
        classId ?? 0,
        studentId,
      ],
    );

    List<Map<String, dynamic>> results = [];
    for (var row in subjectStatsResult) {
      int matId = row['matiere_id'] as int;
      double moyAnnuelle = (row['moy_annuelle'] as num).toDouble();
      double coeff = (row['coefficient'] as num).toDouble();

      // Pivot notes_par_trimestre from the allGrades fetched earlier
      Map<int, double?> notesTri = {};
      for (var g in allGrades) {
        if (g['matiere_id'] == matId) {
          notesTri[g['trimestre'] as int] = (g['average'] as num).toDouble();
        }
      }

      results.add({
        'matiere_id': matId,
        'matiere': row['matiere_nom'],
        'matiere_nom': row['matiere_nom'],
        'coefficient': coeff,
        'coeff': coeff,
        'notes_par_trimestre': notesTri,
        'moy_annuelle': moyAnnuelle,
        'note': moyAnnuelle,
        'total': moyAnnuelle * coeff,
        'rang': row['rang'],
        'appreciation': _getObservation(moyAnnuelle),
      });
    }

    return results;
  }

  String _getObservation(double note) {
    if (note >= 16) return 'Très Bien';
    if (note >= 14) return 'Bien';
    if (note >= 12) return 'Assez Bien';
    if (note >= 10) return 'Passable';
    return 'Insuffisant';
  }

  Future<int> getAnnualSubjectRank(
    int matiereId,
    double targetAvg,
    int classeId,
    int anneeId,
  ) async {
    // Get annual averages for this subject for all students in the class
    final allGrades = await db.rawQuery(
      '''
      SELECT 
        n.eleve_id, 
        AVG(n.note) as moy_tri
      FROM ${NotesSchema.tableName} n
      JOIN eleve_parcours ep ON n.eleve_id = ep.eleve_id AND ep.annee_scolaire_id = n.annee_scolaire_id
      WHERE n.matiere_id = ? 
        AND n.annee_scolaire_id = ?
        AND ep.classe_id = ?
      GROUP BY n.eleve_id, n.trimestre
    ''',
      [matiereId, anneeId, classeId],
    );

    // Pivot in memory to get annual avg per student
    Map<int, List<double>> studentGrades = {};
    for (var row in allGrades) {
      int sId = row['eleve_id'] as int;
      double note = (row['moy_tri'] as num).toDouble();
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

    // Get pass mark for class cycle
    final cycleResult = await db.rawQuery(
      'SELECT cy.moyenne_passage FROM classe c JOIN cycles_scolaires cy ON c.cycle_id = cy.id WHERE c.id = ?',
      [classId],
    );
    double passMark =
        (cycleResult.isNotEmpty
            ? (cycleResult.first['moyenne_passage'] as num?)?.toDouble()
            : null) ??
        10.0;

    double annualAvg = totalCoeff > 0 ? totalPoints / totalCoeff : 0.0;

    // Calculate Rank via SQL (Hierarchical)
    final classAvgsResult = await db.rawQuery(
      '''
      WITH SubjectTrimesterAvgs AS (
        SELECT 
          n.eleve_id,
          n.matiere_id,
          n.trimestre,
          AVG(n.note) as moy_subj_tri,
          MAX(COALESCE(cm.coefficient, 1)) as coef
        FROM ${NotesSchema.tableName} n
        JOIN eleve_parcours ep ON ep.eleve_id = n.eleve_id AND ep.annee_scolaire_id = n.annee_scolaire_id
        LEFT JOIN classe_matiere cm ON cm.matiere_id = n.matiere_id AND cm.classe_id = ep.classe_id
        WHERE ep.classe_id = ? AND n.annee_scolaire_id = ?
        GROUP BY n.eleve_id, n.matiere_id, n.trimestre
      ),
      SubjectAnnualAvgs AS (
        SELECT 
          eleve_id,
          matiere_id,
          AVG(moy_subj_tri) as moy_subj_annual,
          coef
        FROM SubjectTrimesterAvgs
        GROUP BY eleve_id, matiere_id
      )
      SELECT 
        eleve_id,
        SUM(moy_subj_annual * coef) / SUM(coef) as annual_average
      FROM SubjectAnnualAvgs
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
    ); // Needed for totalStudents count

    if (rank == 0 && allStudents.any((s) => s['id'] == studentId)) {
      rank = classAvgsResult.length + 1;
    }

    return {
      'average': annualAvg,
      'rank': rank,
      'classAverage': classTotalAvg,
      'totalStudents': allStudents.length,
      'moyenne_passage': passMark,
      'totalPoints': totalPoints,
      'totalCoeff': totalCoeff,
    };
  }

  Future<void> calculerRangsClasse(int classeId, int anneeId) async {
    // 1. Get class cycle info
    final classInfo = await db.rawQuery(
      '''
      SELECT c.*, cy.id as cycle_id
      FROM classe c
      LEFT JOIN cycles_scolaires cy ON c.cycle_id = cy.id
      WHERE c.id = ?
    ''',
      [classeId],
    );

    int? cycleId;
    if (classInfo.isNotEmpty) {
      cycleId = classInfo.first['cycle_id'] as int?;
    }

    // 2. Get mentions for this cycle (or global if cycle null)
    final mentions = await db.query(
      'mention_config',
      where: cycleId == null ? 'cycle_id IS NULL' : 'cycle_id = ?',
      whereArgs: cycleId == null ? [] : [cycleId],
      orderBy: 'note_min DESC',
    );

    // 3. Get students in class averages in bulk (Hierarchical)
    final classAvgsResult = await db.rawQuery(
      '''
      WITH SubjectTrimesterAvgs AS (
          SELECT 
              n.eleve_id,
              n.matiere_id,
              n.trimestre,
              AVG(n.note) as moy_subj_tri,
              MAX(COALESCE(cm.coefficient, 1)) as coef
          FROM ${NotesSchema.tableName} n
          JOIN eleve_parcours ep ON n.eleve_id = ep.eleve_id AND ep.annee_scolaire_id = n.annee_scolaire_id
          LEFT JOIN classe_matiere cm ON cm.matiere_id = n.matiere_id AND cm.classe_id = ep.classe_id
          WHERE ep.classe_id = ? AND n.annee_scolaire_id = ?
          GROUP BY n.eleve_id, n.matiere_id, n.trimestre
      ),
      SubjectAnnualAvgs AS (
        SELECT 
          eleve_id,
          matiere_id,
          AVG(moy_subj_tri) as moy_subj_annual,
          coef
        FROM SubjectTrimesterAvgs
        GROUP BY eleve_id, matiere_id
      )
      SELECT 
        eleve_id,
        SUM(moy_subj_annual * coef) / SUM(coef) as moyenne
      FROM SubjectAnnualAvgs
      GROUP BY eleve_id
      ''',
      [classeId, anneeId],
    );

    Map<int, double> moyennesMap = {};
    for (var row in classAvgsResult) {
      moyennesMap[row['eleve_id'] as int] =
          (row['moyenne'] as num?)?.toDouble() ?? 0.0;
    }

    // 3b. Also get students matching the specific class and year (to include students without notes)
    final eleves = await db.query(
      'eleve_parcours',
      where: 'classe_id = ? AND annee_scolaire_id = ?',
      whereArgs: [classeId, anneeId],
    );

    List<Map<String, dynamic>> resultats = [];

    for (var eleve in eleves) {
      int eleveId = eleve['eleve_id'] as int;
      double moyenne = moyennesMap[eleveId] ?? 0.0;

      // Find mention
      String? mentionLabel;
      for (var m in mentions) {
        final double min = (m['note_min'] as num?)?.toDouble() ?? 0.0;
        final double max = (m['note_max'] as num?)?.toDouble() ?? 20.0;
        if (moyenne >= min && moyenne <= max) {
          mentionLabel = m['label'] as String?;
          break;
        }
      }

      resultats.add({
        'eleve_id': eleveId,
        'moyenne': moyenne,
        'mention': mentionLabel,
      });
    }

    // 4. Sort and save using a batch
    resultats.sort(
      (a, b) => (b['moyenne'] as double).compareTo(a['moyenne'] as double),
    );

    final batch = db.batch();
    for (int i = 0; i < resultats.length; i++) {
      batch.insert('averages', {
        'eleve_id': resultats[i]['eleve_id'],
        'annee_scolaire_id': anneeId,
        'moyenne': resultats[i]['moyenne'],
        'rang': i + 1,
        'mention': resultats[i]['mention'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getTopGradesBySubject(int anneeId) async {
    return await db.rawQuery(
      '''
      SELECT m.nom as subject, AVG(n.note) as average
      FROM ${NotesSchema.tableName} n
      JOIN matiere m ON n.matiere_id = m.id
      WHERE n.annee_scolaire_id = ?
      GROUP BY m.id
      ORDER BY average DESC
      LIMIT 5
    ''',
      [anneeId],
    );
  }

  Future<List<Map<String, dynamic>>> getRecentNotes(
    int anneeId, {
    int limit = 5,
  }) async {
    return await db.rawQuery(
      '''
      SELECT n.*, e.nom as eleve_nom, e.prenom as eleve_prenom, m.nom as matiere_nom
      FROM ${NotesSchema.tableName} n
      JOIN eleve e ON n.eleve_id = e.id
      JOIN matiere m ON n.matiere_id = m.id
      WHERE n.annee_scolaire_id = ?
      ORDER BY n.id DESC
      LIMIT ?
    ''',
      [anneeId, limit],
    );
  }

  Future<List<Map<String, dynamic>>> getStudentResults(int id) async {
    return await db.rawQuery(
      '''
      SELECT n.*, m.nom as matiere_nom, a.libelle as annee_nom,
             ens.nom as enseignant_nom, ens.prenom as enseignant_prenom,
             COALESCE(cm.coefficient, 1) as coefficient
      FROM ${NotesSchema.tableName} n
      JOIN matiere m ON n.matiere_id = m.id
      JOIN annee_scolaire a ON n.annee_scolaire_id = a.id
      JOIN eleve_parcours ep ON n.eleve_id = ep.eleve_id AND n.annee_scolaire_id = ep.annee_scolaire_id
      LEFT JOIN classe_matiere cm ON cm.matiere_id = n.matiere_id AND cm.classe_id = ep.classe_id
      LEFT JOIN attribution_enseignant ae ON ae.classe_id = ep.classe_id 
           AND ae.matiere_id = n.matiere_id
      LEFT JOIN enseignant ens ON ae.enseignant_id = ens.id
      WHERE n.eleve_id = ?
      ORDER BY a.date_debut DESC, n.trimestre ASC, n.sequence ASC
    ''',
      [id],
    );
  }

  String appreciationAutomatique(double moyenne) {
    if (moyenne >= 16) return "Excellent";
    if (moyenne >= 14) return "Très bien";
    if (moyenne >= 12) return "Bien";
    if (moyenne >= 10) return "Assez bien";
    if (moyenne >= 8) return "Passable";
    return "Insuffisant";
  }

  Future<String> getAppreciation(
    double moyenne, {
    int? cycleId,
    required Future<List<Map<String, dynamic>>> Function(int?) getMentions,
  }) async {
    final mentions = await getMentions(cycleId);
    if (mentions.isEmpty && cycleId != null) {
      final globalMentions = await getMentions(null);
      if (globalMentions.isNotEmpty) {
        for (var m in globalMentions) {
          if (moyenne >= (m['note_min'] as num).toDouble() &&
              moyenne <= (m['note_max'] as num).toDouble()) {
            return m['label'];
          }
        }
      }
    } else {
      for (var m in mentions) {
        if (moyenne >= (m['note_min'] as num).toDouble() &&
            moyenne <= (m['note_max'] as num).toDouble()) {
          return m['label'];
        }
      }
    }
    return appreciationAutomatique(moyenne);
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
      FROM ${NotesSchema.tableName} n
      JOIN eleve_parcours ep ON n.eleve_id = ep.eleve_id AND ep.annee_scolaire_id = n.annee_scolaire_id
      WHERE ep.annee_scolaire_id = ?
    ''',
      [currentYearId],
    );

    // Previous year academic performance
    Map<String, dynamic>? previousAcademic;
    if (previousYearId != null) {
      final prevResult = await db.rawQuery(
        '''
        SELECT 
          AVG(n.note) as average_grade
        FROM ${NotesSchema.tableName} n
        WHERE n.annee_scolaire_id = ?
      ''',
        [previousYearId],
      );
      previousAcademic = prevResult.first;
    }

    // Performance by trimester (current year)
    final trimesterPerformance = await db.rawQuery(
      '''
      SELECT 
        n.trimestre,
        AVG(n.note) as average,
        COUNT(DISTINCT n.eleve_id) as students
      FROM ${NotesSchema.tableName} n
      JOIN eleve_parcours ep ON n.eleve_id = ep.eleve_id AND ep.annee_scolaire_id = n.annee_scolaire_id
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
      FROM ${NotesSchema.tableName} n
      JOIN eleve_parcours ep ON n.eleve_id = ep.eleve_id AND ep.annee_scolaire_id = n.annee_scolaire_id
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
      'previous': previousAcademic,
      'trimesterPerformance': trimesterPerformance,
      'classPerformance': classPerformance,
    };
  }

  Future<List<Map<String, dynamic>>> getGradesOverview(int anneeId) async {
    return await db.rawQuery(
      '''
      SELECT 
        m.id as matiere_id,
        m.nom as matiere_nom, 
        c.id as classe_id,
        c.nom as classe_nom, 
        n.trimestre,
        n.sequence,
        COALESCE(cm.coefficient, 1) as coefficient,
        COUNT(n.id) as count, 
        AVG(n.note) as average
      FROM notes n
      JOIN matiere m ON n.matiere_id = m.id
      JOIN eleve_parcours ep ON n.eleve_id = ep.eleve_id AND ep.annee_scolaire_id = n.annee_scolaire_id
      JOIN classe c ON ep.classe_id = c.id
      LEFT JOIN classe_matiere cm ON cm.matiere_id = m.id AND cm.classe_id = c.id
      WHERE n.annee_scolaire_id = ?
      GROUP BY m.id, c.id, n.trimestre, n.sequence, cm.coefficient
      ORDER BY n.trimestre DESC, n.sequence DESC, c.nom, m.nom
    ''',
      [anneeId],
    );
  }

  Future<List<Map<String, dynamic>>> getClassGradesData(
    int anneeId,
    int classeId,
  ) async {
    return await db.rawQuery(
      '''
      SELECT 
        e.id as eleve_id,
        e.nom as eleve_nom,
        e.prenom as eleve_prenom,
        e.photo as eleve_photo,
        e.matricule as matricule,
        COALESCE(e.date_naissance, '') as date_naissance,
        COALESCE(e.lieu_naissance, '') as lieu_naissance,
        e.sexe as sexe,
        cm.matiere_id,
        m.nom as matiere_nom,
        COALESCE(cm.coefficient, 1) as coefficient,
        n.trimestre,
        n.sequence,
        n.note
      FROM eleve e
      JOIN eleve_parcours ep ON e.id = ep.eleve_id AND ep.annee_scolaire_id = ?
      JOIN classe_matiere cm ON ep.classe_id = cm.classe_id
      JOIN matiere m ON cm.matiere_id = m.id
      LEFT JOIN notes n ON e.id = n.eleve_id 
                        AND n.matiere_id = cm.matiere_id 
                        AND n.annee_scolaire_id = ep.annee_scolaire_id
      WHERE ep.classe_id = ?
      ORDER BY e.nom, e.prenom, m.nom, n.trimestre, n.sequence
    ''',
      [anneeId, classeId],
    );
  }

  Future<List<Map<String, dynamic>>> getStudentsCompletionStatus(
    int classId,
    int trimestre,
    int anneeId,
  ) async {
    // If trimestre is 0, we are in Annual Mode (all trimestres cumulative)
    final trimestersFilter = trimestre == 0 ? '' : 'AND trimestre = $trimestre';
    final nTrimestersFilter = trimestre == 0
        ? ''
        : 'AND n.trimestre = $trimestre';

    return await db.rawQuery(
      '''
      SELECT e.id as eleve_id,
             -- Total expected notes = (Number of subjects) * (Number of planned sequences)
             ((SELECT COUNT(*) FROM classe_matiere cm WHERE cm.classe_id = ep.classe_id) *
              (SELECT COUNT(*) FROM sequence_planification WHERE annee_scolaire_id = ? $trimestersFilter)) as total_subjects,
             
             -- Actual notes recorded for the student (in the specified period)
             (SELECT COUNT(*) FROM notes n 
              WHERE n.eleve_id = e.id 
              AND n.annee_scolaire_id = ?
              $nTrimestersFilter) as subjects_with_notes
      FROM eleve e
      JOIN eleve_parcours ep ON e.id = ep.eleve_id AND ep.annee_scolaire_id = ?
      WHERE ep.classe_id = ?
    ''',
      [anneeId, anneeId, anneeId, classId],
    );
  }
}
