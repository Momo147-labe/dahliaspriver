import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/database/database_helper.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/academic_year_provider.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  bool _isLoading = true;
  Map<String, dynamic> _studentData = {};
  Map<String, dynamic> _financialData = {};
  Map<String, dynamic> _academicData = {};
  Map<String, dynamic> _classData = {};
  Map<String, dynamic> _teacherData = {};
  int? _currentYearId;
  int? _previousYearId;
  int? _lastAnneeId;

  // Additional Analytics Data
  List<Map<String, dynamic>> _ageDistribution = [];
  List<Map<String, dynamic>> _geographicDistribution = [];
  List<Map<String, dynamic>> _genderStatsByCycle = [];
  List<Map<String, dynamic>> _subjectPerformance = [];
  List<Map<String, dynamic>> _teacherPerformanceStats = [];
  List<Map<String, dynamic>> _monthlyCollectionCurve = [];
  List<Map<String, dynamic>> _monthlyExpenseCurve = [];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final academicProvider = Provider.of<AcademicYearProvider>(context);
    final anneeId = academicProvider.selectedAnneeId;

    if (anneeId != null && anneeId != _lastAnneeId) {
      _lastAnneeId = anneeId;
      Future.microtask(() => _loadAnalytics());
    }
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final db = DatabaseHelper.instance;

      // Get year comparison
      final years = await db.getYearComparison();
      _currentYearId = years['currentYearId'];
      _previousYearId = years['previousYearId'];

      if (_currentYearId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Load all analytics
      final studentData = await db.getStudentAnalytics(
        _currentYearId!,
        _previousYearId,
      );
      final financialData = await db.getFinancialAnalytics(
        _currentYearId!,
        _previousYearId,
      );
      final academicData = await db.getAcademicAnalytics(
        _currentYearId!,
        _previousYearId,
      );
      final classData = await db.getClassAnalytics(
        _currentYearId!,
        _previousYearId,
      );
      final teacherData = await db.getTeacherAnalytics(
        _currentYearId!,
        _previousYearId,
      );

      // New detailed analytics
      final ageDistribution = await db.getAgeDistribution(_currentYearId!);
      final geographicDistribution = await db.getGeographicDistribution(
        _currentYearId!,
      );
      final genderStatsByCycle = await db.getGenderStatsByCycle(
        _currentYearId!,
      );
      final subjectPerformance = await db.getSubjectPerformanceStats(
        _currentYearId!,
      );
      final teacherPerformanceStats = await db.getTeacherPerformanceStats(
        _currentYearId!,
      );
      final monthlyCollectionCurve = await db.getMonthlyCollectionCurve(
        _currentYearId!,
      );
      final monthlyExpenseCurve = await db.getMonthlyExpenseCurve(
        _currentYearId!,
      );

      if (mounted) {
        setState(() {
          _studentData = studentData;
          _financialData = financialData;
          _academicData = academicData;
          _classData = classData;
          _teacherData = teacherData;

          _ageDistribution = ageDistribution;
          _geographicDistribution = geographicDistribution;
          _genderStatsByCycle = genderStatsByCycle;
          _subjectPerformance = subjectPerformance;
          _teacherPerformanceStats = teacherPerformanceStats;
          _monthlyCollectionCurve = monthlyCollectionCurve;
          _monthlyExpenseCurve = monthlyExpenseCurve;

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentYearId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Symbols.analytics, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Aucune année scolaire active',
              style: theme.textTheme.titleLarge?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDark),
          const SizedBox(height: 32),
          _buildExecutiveSummary(isDark),
          const SizedBox(height: 32),
          _buildStudentSection(isDark),
          const SizedBox(height: 24),
          _buildFinancialSection(isDark),
          const SizedBox(height: 24),
          _buildAcademicSection(isDark),
          const SizedBox(height: 24),
          _buildClassSection(isDark),
          const SizedBox(height: 24),
          _buildTeacherSection(isDark),
          const SizedBox(height: 32),
          Text(
            'Analyses Avancées',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildRevenueVsExpenseChart(isDark),
          const SizedBox(height: 24),
          _buildRevenueCurve(isDark),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildAgePyramid(isDark)),
              const SizedBox(width: 24),
              Expanded(child: _buildGenderRatioByCycle(isDark)),
            ],
          ),
          const SizedBox(height: 24),
          _buildTopFlopSubjects(isDark),
          const SizedBox(height: 24),
          _buildGeographicDistribution(isDark),
          const SizedBox(height: 24),
          _buildTeacherPerformance(isDark),
          const SizedBox(height: 64),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, Colors.purple],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Symbols.analytics, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Analyse Comparative',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              Text(
                _previousYearId != null
                    ? 'Année actuelle vs Année précédente'
                    : 'Année actuelle (pas de données précédentes)',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _loadAnalytics,
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualiser',
        ),
      ],
    );
  }

  Widget _buildExecutiveSummary(bool isDark) {
    final currentStudents = _studentData['current']?['total'] ?? 0;
    final previousStudents = _studentData['previous']?['total'];
    final currentRevenue = _financialData['current']?['total_collected'] ?? 0.0;
    final previousRevenue = _financialData['previous']?['total_collected'];
    final currentExpenses = _financialData['current']?['expenses'] ?? 0.0;
    final previousExpenses = _financialData['previous']?['expenses'];
    final currentNetRevenue =
        _financialData['current']?['netRevenue'] ?? currentRevenue;
    final previousNetRevenue = _financialData['previous'] != null
        ? (_financialData['previous']['total_collected'] ?? 0.0) -
              (_financialData['previous']['expenses'] ?? 0.0)
        : null;

    final currentAvgGrade = _academicData['current']?['average_grade'] ?? 0.0;
    final currentSuccessRate = _academicData['current']?['success_rate'] ?? 0.0;
    final previousSuccessRate = _academicData['previous']?['success_rate'];
    final currentClasses = _classData['current']?['total'] ?? 0;
    final previousClasses = _classData['previous']?['total'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vue d\'ensemble',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.2,
          children: [
            _buildSummaryCard(
              'Effectif Total',
              currentStudents.toString(),
              previousStudents,
              Symbols.group,
              Colors.blue,
              isDark,
            ),
            _buildSummaryCard(
              'Classes',
              currentClasses.toString(),
              previousClasses,
              Symbols.meeting_room,
              Colors.brown,
              isDark,
            ),
            _buildSummaryCard(
              'Revenus Collectés',
              '${(currentRevenue as num).toStringAsFixed(0)} FG',
              previousRevenue,
              Symbols.payments,
              Colors.green,
              isDark,
              isFinancial: true,
            ),
            _buildSummaryCard(
              'Dépenses Total',
              '${(currentExpenses as num).toStringAsFixed(0)} FG',
              previousExpenses,
              Symbols.outbox,
              Colors.redAccent,
              isDark,
              isFinancial: true,
            ),
            _buildSummaryCard(
              'Résultat Net',
              '${(currentNetRevenue as num).toStringAsFixed(0)} FG',
              previousNetRevenue,
              Symbols.account_balance,
              Colors.teal,
              isDark,
              isFinancial: true,
            ),
            _buildSummaryCard(
              'Moyenne Générale',
              (currentAvgGrade as num).toStringAsFixed(2),
              _academicData['previous']?['average_grade'],
              Symbols.school,
              Colors.purple,
              isDark,
              isGrade: true,
            ),
            _buildSummaryCard(
              'Taux de Réussite',
              '${(currentSuccessRate as num).toStringAsFixed(1)}%',
              previousSuccessRate,
              Symbols.auto_graph,
              Colors.cyan,
              isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    dynamic previousValue,
    IconData icon,
    Color color,
    bool isDark, {
    bool isFinancial = false,
    bool isGrade = false,
  }) {
    double? percentChange;
    if (previousValue != null && previousValue != 0) {
      final current = isFinancial || isGrade
          ? double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0
          : double.tryParse(value) ?? 0;
      final previous = (previousValue as num).toDouble();
      percentChange = ((current - previous) / previous) * 100;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              if (percentChange != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: percentChange >= 0
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        percentChange >= 0
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 12,
                        color: percentChange >= 0 ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${percentChange.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: percentChange >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentSection(bool isDark) {
    final current = _studentData['current'] ?? {};
    final previous = _studentData['previous'];
    final cycleDistribution =
        (_studentData['cycleDistribution'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    return _buildSection(
      title: 'Effectifs Scolaires',
      icon: Symbols.group,
      color: Colors.blue,
      isDark: isDark,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Élèves',
                  (current['total'] ?? 0).toString(),
                  previous?['total'],
                  isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Garçons',
                  (current['males'] ?? 0).toString(),
                  previous?['males'],
                  isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Filles',
                  (current['females'] ?? 0).toString(),
                  previous?['females'],
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Nouveaux',
                  (current['new_students'] ?? 0).toString(),
                  null,
                  isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Réinscrits',
                  (current['returning_students'] ?? 0).toString(),
                  null,
                  isDark,
                ),
              ),
            ],
          ),
          if (cycleDistribution.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildDistributionTable(
              'Répartition par Cycle',
              cycleDistribution,
              'cycle',
              'count',
              isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinancialSection(bool isDark) {
    final current = _financialData['current'] ?? {};
    final previous = _financialData['previous'];
    final paymentMethods =
        (_financialData['paymentMethods'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    final collected = (current['total_collected'] ?? 0.0) as num;
    final expected = (current['total_expected'] ?? 0.0) as num;
    final collectionRate = expected > 0 ? (collected / expected) * 100 : 0.0;

    return _buildSection(
      title: 'Finances',
      icon: Symbols.payments,
      color: Colors.green,
      isDark: isDark,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Montant Collecté',
                  '${collected.toStringAsFixed(0)} FG',
                  previous?['total_collected'],
                  isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Taux de Recouvrement',
                  '${collectionRate.toStringAsFixed(1)}%',
                  null,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Élèves Payants',
                  (current['students_paid'] ?? 0).toString(),
                  previous?['students_paid'],
                  isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Nombre de Paiements',
                  (current['payment_count'] ?? 0).toString(),
                  previous?['payment_count'],
                  isDark,
                ),
              ),
            ],
          ),
          if (paymentMethods.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildDistributionTable(
              'Modes de Paiement',
              paymentMethods,
              'mode_paiement',
              'count',
              isDark,
              extraColumn: 'total',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAcademicSection(bool isDark) {
    final current = _academicData['current'] ?? {};
    final previous = _academicData['previous'];
    final trimesterPerf =
        (_academicData['trimesterPerformance'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final classPerf =
        (_academicData['classPerformance'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    return _buildSection(
      title: 'Performance Académique',
      icon: Symbols.school,
      color: Colors.purple,
      isDark: isDark,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Moyenne Générale',
                  ((current['average_grade'] ?? 0.0) as num).toStringAsFixed(2),
                  previous?['average_grade'],
                  isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Élèves Notés',
                  (current['students_graded'] ?? 0).toString(),
                  previous?['students_graded'],
                  isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Total Notes',
                  (current['total_grades'] ?? 0).toString(),
                  previous?['total_grades'],
                  isDark,
                ),
              ),
            ],
          ),
          if (trimesterPerf.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildDistributionTable(
              'Performance par Trimestre',
              trimesterPerf,
              'trimestre',
              'average',
              isDark,
              isAverage: true,
            ),
          ],
          if (classPerf.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildClassPerformanceTable(classPerf, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildClassSection(bool isDark) {
    final current = _classData['current'] ?? {};
    final previous = _classData['previous'];
    final cycleDistribution =
        (_classData['cycleDistribution'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    return _buildSection(
      title: 'Classes',
      icon: Symbols.door_front,
      color: Colors.orange,
      isDark: isDark,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Classes',
                  (current['total_classes'] ?? 0).toString(),
                  previous?['total_classes'],
                  isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Taille Moyenne',
                  ((current['avg_class_size'] ?? 0.0) as num).toStringAsFixed(
                    1,
                  ),
                  previous?['avg_class_size'],
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Classe la Plus Grande',
                  (current['max_class_size'] ?? 0).toString(),
                  null,
                  isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Classe la Plus Petite',
                  (current['min_class_size'] ?? 0).toString(),
                  null,
                  isDark,
                ),
              ),
            ],
          ),
          if (cycleDistribution.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildCycleDistributionTable(cycleDistribution, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildTeacherSection(bool isDark) {
    final totalTeachers = _teacherData['totalTeachers'] ?? 0;
    final current = _teacherData['current'] ?? {};
    final previous = _teacherData['previous'];
    final specialities =
        (_teacherData['specialityDistribution'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    return _buildSection(
      title: 'Enseignants',
      icon: Symbols.person,
      color: Colors.teal,
      isDark: isDark,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Enseignants',
                  totalTeachers.toString(),
                  null,
                  isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Ratio Élèves/Prof',
                  '${((current['studentTeacherRatio'] ?? 0.0) as num).toStringAsFixed(1)}:1',
                  previous?['studentTeacherRatio'],
                  isDark,
                ),
              ),
            ],
          ),
          if (specialities.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildDistributionTable(
              'Spécialités',
              specialities,
              'specialite',
              'count',
              isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    dynamic previousValue,
    bool isDark,
  ) {
    double? percentChange;
    if (previousValue != null && previousValue != 0) {
      final current =
          double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      final previous = (previousValue as num).toDouble();
      percentChange = ((current - previous) / previous) * 100;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              if (percentChange != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: percentChange >= 0
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        percentChange >= 0
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 10,
                        color: percentChange >= 0 ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${percentChange.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: percentChange >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionTable(
    String title,
    List<Map<String, dynamic>> data,
    String labelKey,
    String valueKey,
    bool isDark, {
    String? extraColumn,
    bool isAverage = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Table(
          border: TableBorder.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF374151)
                    : const Color(0xFFF3F4F6),
              ),
              children: [
                _buildTableCell(labelKey.toUpperCase(), isDark, isHeader: true),
                _buildTableCell(valueKey.toUpperCase(), isDark, isHeader: true),
                if (extraColumn != null)
                  _buildTableCell(
                    extraColumn.toUpperCase(),
                    isDark,
                    isHeader: true,
                  ),
              ],
            ),
            ...data.map((row) {
              final value = row[valueKey];
              final displayValue = isAverage
                  ? (value as num).toStringAsFixed(2)
                  : value.toString();

              return TableRow(
                children: [
                  _buildTableCell(row[labelKey]?.toString() ?? '', isDark),
                  _buildTableCell(displayValue, isDark),
                  if (extraColumn != null)
                    _buildTableCell(
                      '${(row[extraColumn] as num).toStringAsFixed(0)} FG',
                      isDark,
                    ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildClassPerformanceTable(
    List<Map<String, dynamic>> data,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Performance par Classe',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Table(
          border: TableBorder.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF374151)
                    : const Color(0xFFF3F4F6),
              ),
              children: [
                _buildTableCell('CLASSE', isDark, isHeader: true),
                _buildTableCell('CYCLE', isDark, isHeader: true),
                _buildTableCell('MOYENNE', isDark, isHeader: true),
                _buildTableCell('ÉLÈVES', isDark, isHeader: true),
              ],
            ),
            ...data.map((row) {
              return TableRow(
                children: [
                  _buildTableCell(row['class_name']?.toString() ?? '', isDark),
                  _buildTableCell(row['cycle']?.toString() ?? '', isDark),
                  _buildTableCell(
                    ((row['average'] ?? 0.0) as num).toStringAsFixed(2),
                    isDark,
                  ),
                  _buildTableCell(row['students']?.toString() ?? '0', isDark),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildCycleDistributionTable(
    List<Map<String, dynamic>> data,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Répartition par Cycle',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Table(
          border: TableBorder.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF374151)
                    : const Color(0xFFF3F4F6),
              ),
              children: [
                _buildTableCell('CYCLE', isDark, isHeader: true),
                _buildTableCell('CLASSES', isDark, isHeader: true),
                _buildTableCell('ÉLÈVES', isDark, isHeader: true),
              ],
            ),
            ...data.map((row) {
              return TableRow(
                children: [
                  _buildTableCell(row['cycle']?.toString() ?? '', isDark),
                  _buildTableCell(
                    row['class_count']?.toString() ?? '0',
                    isDark,
                  ),
                  _buildTableCell(
                    row['student_count']?.toString() ?? '0',
                    isDark,
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildTableCell(String text, bool isDark, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isHeader ? 11 : 13,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: isDark
              ? (isHeader ? Colors.white70 : Colors.white)
              : (isHeader ? AppTheme.textSecondary : AppTheme.textPrimary),
        ),
      ),
    );
  }

  Widget _buildRevenueCurve(bool isDark) {
    if (_monthlyCollectionCurve.isEmpty) return const SizedBox.shrink();

    final months = [
      'Jan',
      'Fév',
      'Mar',
      'Avr',
      'Mai',
      'Juin',
      'Juil',
      'Août',
      'Sep',
      'Oct',
      'Nov',
      'Déc',
    ];

    return _buildSection(
      title: 'Courbe de Trésorerie Mensuelle',
      icon: Symbols.show_chart,
      color: Colors.green,
      isDark: isDark,
      child: SizedBox(
        height: 300,
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    int index = value.toInt() - 1;
                    if (index >= 0 && index < months.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          months[index],
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: _monthlyCollectionCurve.map((e) {
                  return FlSpot(
                    double.parse(e['month'].toString()),
                    ((e['total'] ?? 0.0) as num).toDouble(),
                  );
                }).toList(),
                isCurved: true,
                color: Colors.green,
                barWidth: 4,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.green.withOpacity(0.1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgePyramid(bool isDark) {
    if (_ageDistribution.isEmpty) return const SizedBox.shrink();

    return _buildSection(
      title: 'Pyramide des Âges',
      icon: Symbols.leaderboard,
      color: Colors.blue,
      isDark: isDark,
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < _ageDistribution.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _ageDistribution[index]['bracket'],
                              style: const TextStyle(fontSize: 9),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(_ageDistribution.length, (index) {
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: ((_ageDistribution[index]['count'] ?? 0) as num)
                            .toDouble(),
                        color: Colors.blue,
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderRatioByCycle(bool isDark) {
    if (_genderStatsByCycle.isEmpty) return const SizedBox.shrink();

    return _buildSection(
      title: 'Genre par Cycle',
      icon: Symbols.group,
      color: Colors.purple,
      isDark: isDark,
      child: Column(
        children: _genderStatsByCycle.map((e) {
          final maleCount = (e['male_count'] ?? 0) as int;
          final femaleCount = (e['female_count'] ?? 0) as int;
          final total = maleCount + femaleCount;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e['nom'] ?? 'Cycle Inconnu',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: Row(
                      children: [
                        if (total > 0)
                          Expanded(
                            flex: maleCount,
                            child: Container(color: Colors.blue),
                          ),
                        if (total > 0)
                          Expanded(
                            flex: femaleCount,
                            child: Container(color: Colors.pink),
                          ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('H: $maleCount', style: const TextStyle(fontSize: 9)),
                    Text(
                      'F: $femaleCount',
                      style: const TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopFlopSubjects(bool isDark) {
    if (_subjectPerformance.isEmpty) return const SizedBox.shrink();

    return _buildSection(
      title: 'Top/Flop Matières',
      icon: Symbols.subject,
      color: Colors.orange,
      isDark: isDark,
      child: Column(
        children: _subjectPerformance.map((e) {
          final avg = ((e['avg_grade'] ?? 0.0) as num).toDouble();
          final color = avg >= 10 ? Colors.green : Colors.red;

          return ListTile(
            dense: true,
            title: Text(e['nom'] ?? '', style: const TextStyle(fontSize: 12)),
            trailing: Text(
              avg.toStringAsFixed(2),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            subtitle: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: avg / 20.0,
                color: color.withOpacity(0.7),
                backgroundColor: color.withOpacity(0.05),
                minHeight: 4,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGeographicDistribution(bool isDark) {
    if (_geographicDistribution.isEmpty) return const SizedBox.shrink();

    return _buildSection(
      title: 'Origine Géographique',
      icon: Symbols.map,
      color: Colors.teal,
      isDark: isDark,
      child: Column(
        children: _geographicDistribution.map((e) {
          return ListTile(
            dense: true,
            title: Text(
              e['lieu_naissance'] ?? 'Non spécifié',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                e['count'].toString(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTeacherPerformance(bool isDark) {
    if (_teacherPerformanceStats.isEmpty) return const SizedBox.shrink();

    return _buildSection(
      title: 'Performance Moyenne Enseignants',
      icon: Symbols.person_pin,
      color: Colors.indigo,
      isDark: isDark,
      child: Column(
        children: _teacherPerformanceStats.map((e) {
          final avg = ((e['avg_grade'] ?? 0.0) as num).toDouble();
          return ListTile(
            dense: true,
            title: Text(
              e['nom_complet'] ?? '',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Text(
              avg.toStringAsFixed(2),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRevenueVsExpenseChart(bool isDark) {
    if (_monthlyCollectionCurve.isEmpty && _monthlyExpenseCurve.isEmpty) {
      return const SizedBox.shrink();
    }

    final currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'GNF',
      decimalDigits: 0,
    );

    // Filter to last 6 months for readability
    final Map<String, double> revenueMap = {
      for (var item in _monthlyCollectionCurve)
        item['month'] as String: (item['total'] as num).toDouble(),
    };
    final Map<String, double> expenseMap = {
      for (var item in _monthlyExpenseCurve)
        item['month'] as String: (item['total'] as num).toDouble(),
    };

    final allMonths = {...revenueMap.keys, ...expenseMap.keys}.toList()..sort();
    final displayMonths = allMonths.length > 6
        ? allMonths.sublist(allMonths.length - 6)
        : allMonths;

    return _buildSection(
      title: 'Comparatif Revenus vs Dépenses',
      icon: Symbols.query_stats,
      color: Colors.blue,
      isDark: isDark,
      child: Container(
        height: 350,
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildLegendItem('Revenus', Colors.green),
                const SizedBox(width: 16),
                _buildLegendItem('Dépenses', Colors.red),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY:
                      1.2 *
                      ([...revenueMap.values, ...expenseMap.values].isEmpty
                          ? 1000
                          : [
                              ...revenueMap.values,
                              ...expenseMap.values,
                            ].reduce((a, b) => a > b ? a : b)),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        String month = displayMonths[group.x.toInt()];
                        String type = rodIndex == 0 ? 'Revenu' : 'Dépense';
                        return BarTooltipItem(
                          '$month : $type\n',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          children: [
                            TextSpan(
                              text: currencyFormat.format(rod.toY),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          int idx = value.toInt();
                          if (idx >= 0 && idx < displayMonths.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                displayMonths[idx].split('-').last,
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const Text('');
                          return Text(
                            NumberFormat.compact(locale: 'fr_FR').format(value),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: null,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: displayMonths.asMap().entries.map((e) {
                    final month = e.value;
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: revenueMap[month] ?? 0.0,
                          color: Colors.green,
                          width: 14,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                        BarChartRodData(
                          toY: expenseMap[month] ?? 0.0,
                          color: Colors.red,
                          width: 14,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
