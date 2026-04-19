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
      LEFT JOIN ${NotesSchema.tableName} n ON n.eleve_id = e.id 
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
      LEFT JOIN ${NotesSchema.tableName} n ON n.eleve_id = e.id 
          AND n.matiere_id = ? 
          AND n.trimestre = ? 
          AND n.annee_scolaire_id = ?
      LEFT JOIN classe_matiere cm ON cm.matiere_id = ? 
          AND cm.classe_id = e.classe_id
      WHERE e.classe_id = ?
      ORDER BY e.nom ASC, e.prenom ASC, n.sequence ASC
    ''',
      [subjectId, trimestre, anneeId, subjectId, classId],
    );
  }

  Future<void> saveGrade(Map<String, dynamic> noteData) async {
    // 1. Validation : Vérifier si un enseignant est affecté
    final eleveResult = await db.query(
      'eleve',
      columns: ['classe_id'],
      where: 'id = ?',
      whereArgs: [noteData['eleve_id']],
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
        AND eleve_id IN (SELECT id FROM eleve WHERE classe_id = ?)
        GROUP BY eleve_id
      ) as student_averages
    ''',
      [passingGrade, subjectId, trimestre, anneeId, classId],
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
      SELECT n.note, cm.coefficient 
      FROM ${NotesSchema.tableName} n
      JOIN eleve e ON n.eleve_id = e.id
      JOIN classe_matiere cm ON cm.matiere_id = n.matiere_id 
        AND cm.classe_id = e.classe_id 
      WHERE n.eleve_id = ? AND n.annee_scolaire_id = ?
    ''',
      [eleveId, anneeId],
    );

    double sommeNotes = 0.0;
    double sommeCoeff = 0.0;

    for (var row in result) {
      double note = (row['note'] as num?)?.toDouble() ?? 0.0;
      double coeff = (row['coefficient'] as num?)?.toDouble() ?? 1.0;
      sommeNotes += note * coeff;
      sommeCoeff += coeff;
    }

    return sommeCoeff == 0 ? 0.0 : (sommeNotes / sommeCoeff);
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
      JOIN eleve e ON n.eleve_id = e.id
      LEFT JOIN classe_matiere cm ON cm.matiere_id = m.id 
           AND cm.classe_id = e.classe_id
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
    // 1. Get average for the specific student
    final studentAvgResult = await db.rawQuery(
      '''
      SELECT 
        SUM(n.note * COALESCE(cm.coefficient, 1)) / SUM(COALESCE(cm.coefficient, 1)) as average,
        cy.moyenne_passage,
        cy.note_min,
        cy.note_max
      FROM ${NotesSchema.tableName} n
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

    final studentData = studentAvgResult.isNotEmpty
        ? studentAvgResult.first
        : {};
    double studentAvg = (studentData['average'] as num?)?.toDouble() ?? 0.0;
    double passMark =
        (studentData['moyenne_passage'] as num?)?.toDouble() ?? 10.0;
    double noteMin = (studentData['note_min'] as num?)?.toDouble() ?? 0.0;
    double noteMax = (studentData['note_max'] as num?)?.toDouble() ?? 20.0;

    // 2. Get averages for all students in the class to calculate rank and class average
    final allAvgsResult = await db.rawQuery(
      '''
      SELECT e.id, SUM(note * COALESCE(cm.coefficient, 1)) / SUM(COALESCE(cm.coefficient, 1)) as average
      FROM eleve e
      JOIN ${NotesSchema.tableName} n ON n.eleve_id = e.id
      JOIN matiere m ON n.matiere_id = m.id
      LEFT JOIN classe_matiere cm ON cm.matiere_id = m.id 
           AND cm.classe_id = e.classe_id
      WHERE e.classe_id = ? AND n.trimestre = ? AND n.annee_scolaire_id = ?
      GROUP BY e.id
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

    // 3. Get student total points
    final studentSumResult = await db.rawQuery(
      '''
      SELECT SUM(note * COALESCE(cm.coefficient, 1)) as total_points
      FROM ${NotesSchema.tableName} n
      JOIN matiere m ON n.matiere_id = m.id
      JOIN eleve e ON n.eleve_id = e.id
      LEFT JOIN classe_matiere cm ON cm.matiere_id = m.id 
           AND cm.classe_id = e.classe_id
      WHERE n.eleve_id = ? AND n.trimestre = ? AND n.annee_scolaire_id = ?
    ''',
      [studentId, trimestre, anneeId],
    );

    return {
      'average': studentAvg,
      'totalPoints': studentSumResult.first['total_points'] ?? 0.0,
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
    // 1. Get all grades for the year
    final allGrades = await db.rawQuery(
      '''
      SELECT n.note, n.trimestre, 
             m.id as matiere_id, m.nom as matiere_nom, 
             COALESCE(cm.coefficient, 1) as coefficient
      FROM ${NotesSchema.tableName} n
      JOIN matiere m ON n.matiere_id = m.id
      JOIN eleve e ON n.eleve_id = e.id
      LEFT JOIN classe_matiere cm ON cm.matiere_id = m.id 
           AND cm.classe_id = e.classe_id
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
          't1': null,
          't2': null,
          't3': null,
        };
      }
      if (tri == 1) subjectStats[matId]!['t1'] = note;
      if (tri == 2) subjectStats[matId]!['t2'] = note;
      if (tri == 3) subjectStats[matId]!['t3'] = note;
    }

    List<Map<String, dynamic>> results = [];
    for (var stat in subjectStats.values) {
      double? t1 = stat['t1'];
      double? t2 = stat['t2'];
      double? t3 = stat['t3'];

      int count = 0;
      double sum = 0;
      if (t1 != null) {
        sum += t1;
        count++;
      }
      if (t2 != null) {
        sum += t2;
        count++;
      }
      if (t3 != null) {
        sum += t3;
        count++;
      }

      double moyAnnuelle = count > 0 ? sum / count : 0.0;

      // Calculate rank in class for this subject (annual)
      int rang = 1;
      if (classId != null) {
        rang = await getAnnualSubjectRank(
          stat['matiere_id'],
          moyAnnuelle,
          classId,
          anneeId,
        );
      }

      results.add({
        'matiere_id': stat['matiere_id'],
        'matiere': stat['matiere_nom'],
        'matiere_nom': stat['matiere_nom'],
        'coefficient': stat['coefficient'],
        'coeff': stat['coefficient'],
        'moy_t1': t1,
        'moy_t2': t2,
        'moy_t3': t3,
        'notes_par_trimestre': {1: t1, 2: t2, 3: t3},
        'moy_annuelle': moyAnnuelle,
        'note': moyAnnuelle,
        'total': moyAnnuelle * (stat['coefficient'] ?? 1.0),
        'rang': rang,
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
      SELECT n.eleve_id, n.note, n.trimestre
      FROM ${NotesSchema.tableName} n
      JOIN eleve e ON n.eleve_id = e.id
      WHERE n.matiere_id = ? 
        AND n.annee_scolaire_id = ?
        AND e.classe_id = ?
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

    // Class Annual Average
    double classTotalAvg = allAverages.isNotEmpty
        ? allAverages.reduce((a, b) => a + b) / allAverages.length
        : 0.0;

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
    final eleves = await db.query(
      'eleve',
      where: 'classe_id = ?',
      whereArgs: [classeId],
    );

    List<Map<String, dynamic>> resultats = [];

    for (var eleve in eleves) {
      double moyenne = await calculerMoyenneGenerale(
        eleve['id'] as int,
        anneeId,
      );
      resultats.add({'eleve_id': eleve['id'], 'moyenne': moyenne});
    }

    resultats.sort(
      (a, b) => (b['moyenne'] as double).compareTo(a['moyenne'] as double),
    );

    for (int i = 0; i < resultats.length; i++) {
      await db.insert('averages', {
        'eleve_id': resultats[i]['eleve_id'],
        'annee_scolaire_id': anneeId,
        'moyenne': resultats[i]['moyenne'],
        'rang': i + 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
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
    return await db.rawQuery('''
      SELECT n.*, e.nom as eleve_nom, e.prenom as eleve_prenom, m.nom as matiere_nom
      FROM ${NotesSchema.tableName} n
      JOIN eleve e ON n.eleve_id = e.id
      JOIN matiere m ON n.matiere_id = m.id
      WHERE n.annee_scolaire_id = ?
      ORDER BY n.id DESC
      LIMIT ?
    ''');
  }

  Future<List<Map<String, dynamic>>> getStudentResults(int id) async {
    return await db.rawQuery(
      '''
      SELECT n.*, m.nom as matiere_nom, a.libelle as annee_nom,
             ens.nom as enseignant_nom, ens.prenom as enseignant_prenom
      FROM ${NotesSchema.tableName} n
      JOIN matiere m ON n.matiere_id = m.id
      JOIN annee_scolaire a ON n.annee_scolaire_id = a.id
      LEFT JOIN attribution_enseignant ae ON ae.classe_id = (SELECT classe_id FROM eleve WHERE id = n.eleve_id) 
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
      JOIN eleve e ON n.eleve_id = e.id
      WHERE e.annee_scolaire_id = ?
    ''',
      [currentYearId],
    );

    // Previous year academic performance
    Map<String, dynamic>? previousAcademic;
    if (previousYearId != null) {
      final prevResult = await db.rawQuery(
        '''
        SELECT 
          AVG(n.note) as average_grade,
          COUNT(DISTINCT n.eleve_id) as students_graded,
          COUNT(n.id) as total_grades
        FROM ${NotesSchema.tableName} n
        JOIN eleve e ON n.eleve_id = e.id
        WHERE e.annee_scolaire_id = ?
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
      JOIN eleve e ON n.eleve_id = e.id
      WHERE e.annee_scolaire_id = ?
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
      JOIN eleve e ON n.eleve_id = e.id
      JOIN classe c ON e.classe_id = c.id
      JOIN cycles_scolaires cy ON c.cycle_id = cy.id
      WHERE e.annee_scolaire_id = ?
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
      JOIN eleve e ON n.eleve_id = e.id
      JOIN classe c ON e.classe_id = c.id
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
      JOIN classe_matiere cm ON e.classe_id = cm.classe_id
      JOIN matiere m ON cm.matiere_id = m.id
      LEFT JOIN notes n ON e.id = n.eleve_id 
                        AND n.matiere_id = cm.matiere_id 
                        AND n.annee_scolaire_id = ?
      WHERE e.classe_id = ?
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
    return await db.rawQuery(
      '''
      SELECT e.id as eleve_id,
             (SELECT COUNT(*) FROM classe_matiere cm 
              WHERE cm.classe_id = e.classe_id) as total_subjects,
             (SELECT COUNT(DISTINCT n.matiere_id) FROM notes n 
              WHERE n.eleve_id = e.id 
              AND n.trimestre = ? 
              AND n.annee_scolaire_id = ?) as subjects_with_notes
      FROM eleve e
      WHERE e.classe_id = ?
    ''',
      [trimestre, anneeId, classId],
    );
  }
}
