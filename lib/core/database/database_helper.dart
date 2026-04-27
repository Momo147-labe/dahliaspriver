import 'dart:async';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../models/ecole.dart';
import '../../models/matiere.dart';
import 'database_path.dart';
import 'daos/annee_scolaire_dao.dart';
import 'daos/classe_dao.dart';
import 'daos/config_dao.dart';
import 'daos/dashboard_dao.dart';
import 'daos/ecole_dao.dart';
import 'daos/eleve_dao.dart';
import 'daos/enseignant_dao.dart';
import 'daos/fees_dao.dart';
import 'daos/matiere_dao.dart';
import 'daos/notes_dao.dart';
import 'daos/paiement_dao.dart';
import 'daos/timetable_dao.dart';
import 'daos/user_dao.dart';
import 'daos/common_dao.dart';
import 'daos/result_dao.dart';
import 'daos/reports_dao.dart';
import 'schema/database_schema.dart';
import 'migrations/database_migrations.dart';
import 'daos/promotion_log_dao.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal();

  static Database? _db;
  static Completer<Database>? _dbCompleter;
  static int? activeAnneeId;

  // DAOs Getters
  AnneeScolaireDao get anneeScolaireDao => AnneeScolaireDao(_db!);
  ClasseDao get classeDao => ClasseDao(_db!);
  ConfigDao get configDao => ConfigDao(_db!);
  DashboardDao get dashboardDao => DashboardDao(_db!);
  EcoleDao get ecoleDao => EcoleDao(_db!);
  EleveDao get eleveDao => EleveDao(_db!);
  EnseignantDao get enseignantDao => EnseignantDao(_db!);
  FeesDao get feesDao => FeesDao(_db!);
  MatiereDao get matiereDao => MatiereDao(_db!);
  NotesDao get notesDao => NotesDao(_db!);
  PaiementDao get paiementDao => PaiementDao(_db!);
  TimetableDao get timetableDao => TimetableDao(_db!);
  UserDao get userDao => UserDao(_db!);
  CommonDao get commonDao => CommonDao(_db!);
  ResultDao get resultDao => ResultDao(_db!);
  ReportsDao get reportsDao => ReportsDao(_db!);
  PromotionLogDao get promotionLogDao => PromotionLogDao(_db!);

  // ==============================================================================
  // PROXY METHODS TO DAOs (for UI compatibility)
  // ==============================================================================

  // PaiementDao Proxies
  Future<Map<String, dynamic>> getFinancialSummary(int anneeId) =>
      paiementDao.getFinancialSummary(anneeId);
  Future<List<Map<String, dynamic>>> getRecoveryByClass(int anneeId) =>
      paiementDao.getRecoveryByClass(anneeId);
  Future<List<Map<String, dynamic>>> getPaymentMethodsBreakdown(int anneeId) =>
      paiementDao.getPaymentMethodsBreakdown(anneeId);
  Future<int> countPayments(
    int anneeId, {
    String? searchQuery,
    String? modeFilter,
  }) => paiementDao.countPayments(
    anneeId,
    searchQuery: searchQuery,
    modeFilter: modeFilter,
  );
  Future<List<Map<String, dynamic>>> getRecentTransactions(
    int anneeId, {
    int? limit,
    int? offset,
    String? searchQuery,
    String? modeFilter,
  }) => paiementDao.getRecentTransactions(
    anneeId,
    limit: limit ?? 10,
    offset: offset ?? 0,
    searchQuery: searchQuery,
    modeFilter: modeFilter,
  );

  // NotesDao Proxies
  Future<List<Map<String, dynamic>>> getTrimesterGradesByClassSubject(
    int classId,
    int subjectId,
    int trimestre,
    int anneeId,
  ) => notesDao.getTrimesterGradesByClassSubject(
    classId,
    subjectId,
    trimestre,
    anneeId,
  );
  Future<Map<String, dynamic>> getTrimesterGradesStats(
    int classId,
    int subjectId,
    int trimestre,
    int anneeId, {
    double passingGrade = 10.0,
  }) => notesDao.getTrimesterGradesStats(
    classId,
    subjectId,
    trimestre,
    anneeId,
    passingGrade: passingGrade,
  );
  Future<List<Map<String, dynamic>>> getStudentsCompletionStatus(
    int classId,
    int trimestre,
    int anneeId,
  ) => notesDao.getStudentsCompletionStatus(classId, trimestre, anneeId);
  Future<List<Map<String, dynamic>>> getClassGradesData(
    int anneeId,
    int classId,
  ) => notesDao.getClassGradesData(anneeId, classId);
  Future<List<Map<String, dynamic>>> getGradesOverview(int anneeId) =>
      notesDao.getGradesOverview(anneeId);

  // ConfigDao Proxies
  Future<bool> hasGradesForSequence(int anneeId, int trimestre, int sequence) =>
      configDao.hasGradesForSequence(anneeId, trimestre, sequence);
  Future<Map<String, dynamic>?> getDocumentTemplate(int anneeId, String type) =>
      configDao.getDocumentTemplate(anneeId, type);
  Future<int> saveDocumentTemplate(Map<String, dynamic> template) =>
      configDao.saveDocumentTemplate(template);

  Future<Database> get database async {
    if (_db != null) return _db!;

    if (_dbCompleter != null) {
      return _dbCompleter!.future;
    }

    _dbCompleter = Completer<Database>();
    try {
      _db = await _initDatabase();

      // Schema creation and upgrades are handled in _onCreate and _onUpgrade

      _dbCompleter!.complete(_db!);
      return _db!;
    } catch (e) {
      _dbCompleter!.completeError(e);
      _dbCompleter = null; // Allow retry on failure
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    final path = await getDatabasePath();
    return await openDatabase(
      path,
      version: 68,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await DatabaseSchema.create(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await DatabaseMigrations.upgrade(db, oldVersion, newVersion);
  }

  // -------------------------
  // CRUD générique
  // -------------------------
  // -------------------------
  // CRUD générique
  // -------------------------
  Future<int> insert(String table, Map<String, dynamic> values) =>
      commonDao.insert(table, values);

  Future<int> update(
    String table,
    Map<String, dynamic> values,
    String where,
    List<dynamic> whereArgs,
  ) => commonDao.update(table, values, where, whereArgs);

  Future<int> delete(String table, String where, List<dynamic> whereArgs) =>
      commonDao.delete(table, where, whereArgs);

  Future<List<Map<String, dynamic>>> queryAll(String table) =>
      commonDao.queryAll(table);

  Future<Map<String, dynamic>?> queryById(String table, int id) =>
      commonDao.queryById(table, id);

  // -------------------------
  // Méthodes Configuration École
  // -------------------------
  Future<int> saveConfigurationEcole(Map<String, dynamic> config) =>
      configDao.saveConfigurationAnnee(config);

  Future<int> updateConfigurationEcole(int id, Map<String, dynamic> config) =>
      configDao.updateConfigurationAnnee(id, config);

  Future<Map<String, dynamic>?> getConfigurationEcole(int anneeScolaireId) =>
      configDao.getConfigurationAnnee(anneeScolaireId);

  Future<int> saveConfigurationEvaluation(Map<String, dynamic> config) =>
      configDao.saveConfigurationAnnee(config);

  Future<int> updateConfigurationEvaluation(
    int id,
    Map<String, dynamic> config,
  ) => configDao.updateConfigurationAnnee(id, config);

  Future<Map<String, dynamic>?> getConfigurationEvaluation(
    int anneeScolaireId,
  ) => configDao.getConfigurationAnnee(anneeScolaireId);

  Future<int> saveCycleScolaire(Map<String, dynamic> cycle) =>
      configDao.saveCycle(cycle);

  Future<List<Map<String, dynamic>>> getCyclesScolaires() =>
      configDao.getCyclesScolaires();

  Future<Map<String, dynamic>?> getCycleById(int id) =>
      configDao.getCycleById(id);

  Future<int> updateCycleScolaire(int id, Map<String, dynamic> cycle) =>
      configDao.updateCycle(id, cycle);

  Future<int> deleteCycleScolaire(int id) => configDao.deleteCycle(id);

  // -------------------------
  // Niveaux configuration
  // -------------------------
  Future<List<Map<String, dynamic>>> getNiveauxByCycle(int cycleId) =>
      configDao.getNiveauxByCycle(cycleId);

  Future<int> saveNiveau(Map<String, dynamic> niveau) =>
      configDao.saveNiveau(niveau);

  Future<int> deleteNiveau(int id) => configDao.deleteNiveau(id);

  Future<Map<String, dynamic>?> getClasseWithCycle(int classId) =>
      classeDao.getClasseWithCycle(classId);

  // -------------------------
  // Mentions configuration
  // -------------------------
  Future<List<Map<String, dynamic>>> getMentionsByCycle(int? cycleId) =>
      configDao.getMentionsByCycle(cycleId);

  Future<void> saveMention(Map<String, dynamic> mention) =>
      configDao.saveMention(mention);

  Future<void> deleteMention(int id) => configDao.deleteMention(id);

  // -------------------------
  // Evaluation Planification
  // -------------------------
  Future<List<Map<String, dynamic>>> getSequencesPlanification(int anneeId) =>
      configDao.getSequencesPlanification(anneeId);

  Future<void> saveSequencesPlanification(
    List<Map<String, dynamic>> sequences,
  ) => configDao.saveSequencesPlanification(sequences);

  // -------------------------
  // Moyennes, rangs et passage
  // -------------------------
  Future<double> calculerMoyenneGenerale(int eleveId, int anneeId) =>
      resultDao.calculerMoyenneGenerale(eleveId, anneeId);

  Future<int> deleteTimetableByClass(int classId, int anneeId) =>
      timetableDao.deleteTimetableByClass(classId, anneeId);
  Future<double> getTeacherWeeklyHours(int teacherId, int anneeId) =>
      timetableDao.getTeacherWeeklyHours(teacherId, anneeId);

  Future<void> calculerRangsClasse(int classeId, int anneeId) =>
      resultDao.calculerRangsClasse(classeId, anneeId);

  Future<void> passerEleves(
    List<int> ids,
    int nouvelleClasseId,
    int nouvelleAnneeId,
  ) => resultDao.passerEleves(ids, nouvelleClasseId, nouvelleAnneeId);

  String appreciationAutomatique(double moyenne) =>
      resultDao.appreciationAutomatique(moyenne);

  Future<String> getAppreciation(double moyenne) =>
      resultDao.getAppreciation(moyenne);

  Future<int?> ensureActiveAnneeCached({bool forceRefresh = false}) async {
    if (activeAnneeId != null && !forceRefresh) return activeAnneeId;
    final annee = await getActiveAnnee();
    activeAnneeId = annee?['id'];
    return activeAnneeId;
  }

  Future<void> setActiveAnnee(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'annee_scolaire',
        {'statut': 'Inactive'},
        where: 'statut = ?',
        whereArgs: ['Active'],
      );
      await txn.update(
        'annee_scolaire',
        {'statut': 'Active'},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    await ensureActiveAnneeCached(forceRefresh: true);
  }

  Future<Map<String, dynamic>?> getActiveAnnee() =>
      anneeScolaireDao.getActiveAnnee();

  // -------------------------
  // Méthodes Écoles
  // -------------------------
  Future<List<Map<String, dynamic>>> getEcoles() => ecoleDao.getEcoles();

  Future<int> countEcoles() => ecoleDao.countEcoles();

  Future<bool> hasEcoles() => ecoleDao.hasEcoles();

  Future<Ecole?> getEcole() async {
    final map = await ecoleDao.getSchoolProfile();
    return map != null ? Ecole.fromMap(map) : null;
  }

  Future<int> upsertEcole(Ecole ecole) => ecoleDao.upsertEcole(ecole);

  // -------------------------
  // Méthodes Matières
  // -------------------------
  Future<List<Matiere>> getMatieresByAnnee(int anneeId) =>
      matiereDao.getMatieresByAnnee(anneeId);

  Future<int> saveMatiere(Matiere matiere) =>
      matiereDao.saveSubject(matiere.toMap());

  Future<void> updateMatiere(Matiere matiere) =>
      matiereDao.updateSubject(matiere.id!, matiere.toMap());

  Future<void> deleteMatiere(int id) => matiereDao.deleteSubject(id);

  Future<List<Map<String, dynamic>>> getMatieresStats() =>
      matiereDao.getMatieresStats();

  // -------------------------
  // Méthodes Enseignants
  // -------------------------
  Future<List<Map<String, dynamic>>> getEnseignants() =>
      enseignantDao.getEnseignants();

  Future<Map<String, dynamic>> getEnseignantsStats() =>
      enseignantDao.getEnseignantsStats();

  Future<int> deleteEnseignant(int id) => enseignantDao.deleteEnseignant(id);

  // -------------------------
  // Méthodes Emploi du Temps
  // -------------------------
  Future<List<Map<String, dynamic>>> getEmploiDuTempsByClasse(
    int classeId,
    int anneeScolaireId,
  ) => timetableDao.getTimetableByClass(classeId, anneeScolaireId);

  Future<Map<String, dynamic>?> checkConflicts(
    int jour,
    String debut,
    String fin, {
    int? enseignantId,
    int? classeId,
    int? excludeId,
    int? anneeId,
  }) => timetableDao.checkConflicts(
    jour,
    debut,
    fin,
    enseignantId: enseignantId,
    classeId: classeId,
    excludeId: excludeId,
    anneeId: anneeId,
  );

  // -------------------------
  // Méthodes Bulletins / Rapports
  // -------------------------

  Future<Map<String, dynamic>?> getActiveAnneeScolaire() =>
      anneeScolaireDao.getActiveAnnee();

  Future<List<Map<String, dynamic>>> getClassesForReports(int anneeId) =>
      reportsDao.getClassesForReports(anneeId);

  Future<List<Map<String, dynamic>>> getStudentsByClasse(
    int classeId,
    int anneeId,
  ) => reportsDao.getStudentsByClasse(classeId, anneeId);

  Future<List<Map<String, dynamic>>> getStudentNotesForBulletin(
    int studentId,
    int trimestre,
    int anneeId,
  ) => reportsDao.getStudentNotesForBulletin(studentId, trimestre, anneeId);

  Future<Map<String, dynamic>> getBulletinStats(
    int studentId,
    int classId,
    int trimestre,
    int anneeId,
  ) => resultDao.getBulletinStats(studentId, classId, trimestre, anneeId);

  // --- ANNUAL REPORT METHODS ---

  Future<List<Map<String, dynamic>>> getAnnualGradesForStudent(
    int studentId,
    int anneeId, {
    int? classId,
  }) =>
      resultDao.getAnnualGradesForStudent(studentId, anneeId, classId: classId);

  Future<Map<String, dynamic>> getAnnualStats(
    int studentId,
    int classId,
    int anneeId,
    Future<List<Map<String, dynamic>>> Function(int) getStudentsByClasse,
  ) => resultDao.getAnnualStats(
    studentId,
    classId,
    anneeId,
    getStudentsByClasse,
  );

  // --- GRADES MANAGEMENT ---

  Future<List<Map<String, dynamic>>> getAllSubjects() =>
      matiereDao.getAllSubjects();

  Future<List<Map<String, dynamic>>> getGradesByClassSubject(
    int classId,
    int subjectId,
    int trimestre,
    int sequence,
    int anneeId,
  ) => notesDao.getGradesByClassSubject(
    classId,
    subjectId,
    trimestre,
    sequence,
    anneeId,
  );

  Future<void> saveGrade(Map<String, dynamic> noteData) =>
      notesDao.saveGrade(noteData);

  Future<void> deleteGrade({
    required int eleveId,
    required int matiereId,
    required int trimestre,
    required int sequence,
    required int anneeId,
  }) => notesDao.deleteGrade(
    eleveId: eleveId,
    matiereId: matiereId,
    trimestre: trimestre,
    sequence: sequence,
    anneeId: anneeId,
  );

  Future<Map<String, dynamic>> getGradesStats(
    int classId,
    int subjectId,
    int trimestre,
    int sequence,
    int anneeId, {
    double passingGrade = 10.0,
  }) => notesDao.getGradesStats(
    classId,
    subjectId,
    trimestre,
    sequence,
    anneeId,
    passingGrade: passingGrade,
  );

  // --- PAYMENTS MANAGEMENT ---

  Future<Map<String, dynamic>?> getFraisByClasse(int classId, int anneeId) =>
      feesDao.getFraisByClasse(classId, anneeId);

  Future<List<Map<String, dynamic>>> getPaiementsByEleve(
    int eleveId,
    int anneeId,
  ) => feesDao.getPaiementsByEleve(eleveId, anneeId);

  Future<void> addPaiement(Map<String, dynamic> data) =>
      feesDao.addPaiement(data);

  Future<List<Map<String, dynamic>>> searchEleves(
    String query,
    int anneeId,
  ) async {
    return await eleveDao.searchEleves(query, anneeId);
  }

  Future<List<Map<String, dynamic>>> getClassesByAnnee(int anneeId) =>
      classeDao.getClassesByAnnee(anneeId);

  Future<List<Map<String, dynamic>>> getElevesByClasse(
    int classeId,
    int anneeId,
  ) async {
    return await eleveDao.getElevesByClasse(classeId, anneeId);
  }

  // ===================================================================
  // ANALYTICS METHODS - Year-over-Year Comparison
  // ===================================================================

  /// Get current and previous academic year IDs for comparison
  Future<Map<String, int?>> getYearComparison() =>
      anneeScolaireDao.getYearComparison();

  /// Get student enrollment analytics comparing two years
  Future<Map<String, dynamic>> getStudentAnalytics(
    int currentYearId,
    int? previousYearId,
  ) => eleveDao.getStudentAnalytics(
    currentYearId,
    previousYearId: previousYearId,
  );

  /// Get financial analytics comparing two years
  Future<Map<String, dynamic>> getFinancialAnalytics(
    int currentYearId,
    int? previousYearId,
  ) => paiementDao.getFinancialAnalytics(
    currentYearId,
    previousYearId: previousYearId,
  );

  /// Get academic performance analytics comparing two years
  Future<Map<String, dynamic>> getAcademicAnalytics(
    int currentYearId,
    int? previousYearId,
  ) => resultDao.getAcademicAnalytics(currentYearId, previousYearId);

  /// Get class distribution analytics comparing two years
  Future<Map<String, dynamic>> getClassAnalytics(
    int currentYearId,
    int? previousYearId,
  ) => classeDao.getClassAnalytics(currentYearId, previousYearId);

  /// Get teacher analytics comparing two years
  Future<Map<String, dynamic>> getTeacherAnalytics(
    int currentYearId,
    int? previousYearId,
  ) => enseignantDao.getTeacherAnalytics(
    currentYearId,
    previousYearId: previousYearId,
  );

  Future<Map<String, double>> getStudentFinancialStatus(
    int eleveId,
    int anneeId,
  ) => feesDao.getStudentFinancialStatus(eleveId, anneeId);

  Future<List<Map<String, dynamic>>> getPaymentHistory(
    int eleveId,
    int anneeId,
  ) => feesDao.getPaiementsByEleve(eleveId, anneeId);

  Future<Map<String, dynamic>> getDashboardStats(int anneeId) =>
      dashboardDao.getDashboardData(anneeId);

  Future<List<Map<String, dynamic>>> getAllClasses() =>
      classeDao.getClassesByAnnee();

  Future<List<Map<String, dynamic>>> getCycles() =>
      configDao.getCyclesScolaires();

  Future<List<Map<String, dynamic>>> getStudentPaymentControlData(
    int anneeId,
  ) => eleveDao.getStudentPaymentControlData(anneeId);

  Future<List<Map<String, dynamic>>> getOverdueStudents(int anneeId) =>
      paiementDao.getOverdueStudents(anneeId);

  Future<List<Map<String, dynamic>>> getAgeDistribution(int anneeId) =>
      eleveDao.getAgeDistribution(anneeId);
  Future<List<Map<String, dynamic>>> getGeographicDistribution(int anneeId) =>
      eleveDao.getGeographicDistribution(anneeId);
  Future<List<Map<String, dynamic>>> getGenderStatsByCycle(int anneeId) =>
      eleveDao.getGenderStatsByCycle(anneeId);

  Future<List<Map<String, dynamic>>> getSubjectPerformanceStats(int anneeId) =>
      resultDao.getSubjectPerformanceStats(anneeId);
  Future<List<Map<String, dynamic>>> getTeacherPerformanceStats(int anneeId) =>
      resultDao.getTeacherPerformanceStats(anneeId);

  Future<List<Map<String, dynamic>>> getMonthlyCollectionCurve(int anneeId) =>
      feesDao.getMonthlyCollectionCurve(anneeId);
  Future<List<Map<String, dynamic>>> getMonthlyExpenseCurve(int anneeId) =>
      paiementDao.getMonthlyExpenseCurve(anneeId);

  Future<List<Map<String, dynamic>>> getAttributionsByClass(int classeId) =>
      enseignantDao.getAttributionsByClass(classeId);

  Future<void> saveAllAttributions(int classeId, Map<int, int?> assignments) =>
      enseignantDao.saveAllAttributions(classeId, assignments);

  Future<void> saveAttribution(Map<String, dynamic> attribution) =>
      enseignantDao.saveAttribution(attribution);

  Future<Map<String, dynamic>?> getAssignedTeacher(
    int classeId,
    int matiereId,
  ) => enseignantDao.getAssignedTeacher(classeId, matiereId);

  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) => commonDao.rawQuery(sql, arguments);

  Future<List<Map<String, dynamic>>> getSubjectsByClass(int classeId) =>
      matiereDao.getSubjectsByClass(classeId);

  Future<void> saveClassSubjects(
    int classeId,
    List<Map<String, dynamic>> subjectsData,
  ) => classeDao.saveClassSubjects(classeId, subjectsData);

  Future<bool> isSubjectInClass(int classeId, int matiereId) =>
      matiereDao.isSubjectInClass(classeId, matiereId);

  // --- STUDENT DETAILS & HISTORY ---

  Future<Map<String, dynamic>?> getStudentById(int id) =>
      eleveDao.getEleveById(id);

  Future<List<Map<String, dynamic>>> getStudentParcours(int id) =>
      eleveDao.getEleveParcours(id);

  Future<List<Map<String, dynamic>>> getStudentPayments(int id) =>
      paiementDao.getPaymentsByStudent(id);

  Future<List<Map<String, dynamic>>> getStudentPaymentDetails(
    int id, {
    int? anneeId,
  }) => paiementDao.getPaymentDetails(id, anneeId: anneeId);

  Future<List<Map<String, dynamic>>> getStudentResults(int id) =>
      notesDao.getStudentResults(id);

  // --- FRAIS SCOLAIRES MANAGEMENT ---

  Future<void> createFraisForMultipleClasses(
    List<int> classeIds,
    int anneeScolaireId,
    Map<String, dynamic> fraisData,
  ) => feesDao.createFraisForMultipleClasses(
    classeIds,
    anneeScolaireId,
    fraisData,
  );

  /// Obtenir toutes les classes avec leurs frais pour une année scolaire
  Future<List<Map<String, dynamic>>> getClassesWithFrais(int anneeScolaireId) =>
      feesDao.getClassesWithFrais(anneeScolaireId);

  Future<List<Map<String, dynamic>>> getClassesWithSameFees(
    int anneeScolaireId,
    Map<String, dynamic> fraisReference,
  ) => feesDao.getClassesWithSameFees(anneeScolaireId, fraisReference);

  Future<void> duplicateFraisToClasses(
    int sourceClasseId,
    List<int> targetClasseIds,
    int anneeScolaireId,
  ) => feesDao.duplicateFraisToClasses(
    sourceClasseId,
    targetClasseIds,
    anneeScolaireId,
  );

  Future<Map<String, dynamic>> getFraisStatistics(int anneeScolaireId) =>
      feesDao.getFraisStatistics(anneeScolaireId);

  Future<List<Map<String, dynamic>>> getClassesByTeacher(int enseignantId) =>
      enseignantDao.getClassesByTeacher(enseignantId);

  // Paiements Enseignants
  Future<List<Map<String, dynamic>>> getPaiementsEnseignant(
    int? enseignantId,
    int anneeId,
  ) => enseignantDao.getPaiementsEnseignant(enseignantId, anneeId);

  Future<int> addPaiementEnseignant(Map<String, dynamic> paiement) =>
      enseignantDao.addPaiementEnseignant(paiement);

  Future<int> deletePaiementEnseignant(int id) =>
      enseignantDao.deletePaiementEnseignant(id);

  Future<void> deleteFraisForClasses(
    List<int> classeIds,
    int anneeScolaireId,
  ) => feesDao.deleteFraisForClasses(classeIds, anneeScolaireId);

  Future<int> updateEleveParcoursStatut(
    int eleveId,
    int anneeId,
    String statut,
  ) => eleveDao.updateEleveParcoursStatut(eleveId, anneeId, statut);

  // ==============================================================================
  // GESTION DES UTILISATEURS
  // ==============================================================================

  Future<Map<String, dynamic>?> getUser(int id) => userDao.getUser(id);

  // ==============================================================================
  // PROMOTION LOGGING
  // ==============================================================================

  Future<bool> hasPromotionBeenLogged(int fromAnneeId, int fromClasseId) =>
      promotionLogDao.hasPromotionBeenLogged(fromAnneeId, fromClasseId);

  Future<int> logPromotion({
    required int fromAnneeId,
    required int fromClasseId,
    required int toAnneeId,
    required int toClasseId,
    String? status,
  }) => promotionLogDao.logPromotion(
    fromAnneeId: fromAnneeId,
    fromClasseId: fromClasseId,
    toAnneeId: toAnneeId,
    toClasseId: toClasseId,
    status: status,
  );

  Future<List<Map<String, dynamic>>> getUsers() => userDao.getUsers();

  Future<int> addUser(Map<String, dynamic> user) => userDao.addUser(user);

  Future<int> updateUser(Map<String, dynamic> user) => userDao.updateUser(user);

  Future<Map<String, dynamic>> getEcoleInfo() async {
    final ecole = await ecoleDao.getSchoolProfile();
    return ecole ??
        {
          'nom': 'Guiner Schools',
          'adresse': 'Conakry, Guinée',
          'telephone': '+224 600 00 00 00',
          'email': 'contact@guinerschools.com',
          'logo': null,
        };
  }

  Future<int> changePassword(int id, String newPassword) =>
      userDao.changePassword(id, newPassword);

  Future<int> deleteUser(int id) => userDao.deleteUser(id);

  // ==============================================================================
  // GESTION DES SEQUENCES ET TRIMESTRES (DYNAMIC)
  // ==============================================================================

  /// Get configured sequences for a specific academic year
  Future<List<Map<String, dynamic>>> getSequences(int anneeId) =>
      configDao.getSequences(anneeId);

  /// Get configured sequences for a specific trimester and academic year
  Future<List<Map<String, dynamic>>> getSequencesForTrimester(
    int anneeId,
    int trimester,
  ) => configDao.getSequencesForTrimester(anneeId, trimester);

  /// Get configured trimesters for a specific academic year

  Future<List<int>> getTrimesters(int anneeId) =>
      configDao.getTrimesters(anneeId);
}
