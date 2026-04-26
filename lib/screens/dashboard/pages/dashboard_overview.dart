import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/dashboard/stats_card.dart';
import '../../../widgets/dashboard/recent_reports.dart';
import '../../../core/database/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../providers/academic_year_provider.dart';
import '../../../services/pdf/dashboard_pdf_service.dart';
import '../../../widgets/student/add_student_modal.dart';
import './payment/new_payment_page.dart';
import './settings_page.dart';

class DashboardOverview extends StatefulWidget {
  final Function(int)? onNavigate;
  const DashboardOverview({super.key, this.onNavigate});

  @override
  State<DashboardOverview> createState() => _DashboardOverviewState();
}

class _DashboardOverviewState extends State<DashboardOverview> {
  bool _isLoading = true;
  int? _lastLoadedAnneeId;
  Map<String, dynamic>? _stats;
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'GNF',
    decimalDigits: 0,
  );

  String _formatAbbreviatedAmount(double value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} Md GNF';
    } else if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} M GNF';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} k GNF';
    }
    return '${value.toStringAsFixed(0)} GNF';
  }

  @override
  void initState() {
    super.initState();
    // Data will be loaded in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Use Provider.of instead of context.watch inside lifecycle methods
    final provider = Provider.of<AcademicYearProvider>(context);
    final anneeId = provider.selectedAnneeId;

    if (anneeId != null && anneeId != _lastLoadedAnneeId) {
      _lastLoadedAnneeId = anneeId;
      // Use microtask to avoid calling setState during build/dependency change if needed,
      // though _loadDashboardData is async and starts with setState which is generally safe here.
      _loadDashboardData(anneeId);
    }
  }

  Future<void> _loadDashboardData(int anneeId) async {
    setState(() => _isLoading = true);
    try {
      final db = DatabaseHelper.instance;
      final stats = await db.getDashboardStats(anneeId);
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading dashboard stats: $e');
      setState(() => _isLoading = false);
    }
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return 2;
    if (width < 1200) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final financial = _stats?['financial'] ?? {};
    final recoveryRate = (financial['recoveryRate'] as num?)?.toDouble() ?? 0.0;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Head Section
            _buildHeader(theme, isDark),

            const SizedBox(height: 32),

            // Statistics Cards
            _buildStatsGrid(
              context,
              financial,
              recoveryRate,
              _stats?['academic'] ?? {},
            ),

            const SizedBox(height: 40),

            // Action Shortcuts Title
            Text(
              'Raccourcis d\'Actions',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            // Quick Actions Scrollable
            _buildQuickActions(isDark),

            const SizedBox(height: 48),

            // Bottom Content: Attendance & Reports
            Wrap(
              spacing: 32,
              runSpacing: 32,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                SizedBox(width: 800, child: _buildGraphsGrid(theme, isDark)),
                SizedBox(
                  width: 400,
                  height: 800,
                  child: RecentReports(
                    recentPayments: List<Map<String, dynamic>>.from(
                      _stats?['recentPayments'] ?? [],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tableau de Bord Global',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                  fontSize: 28,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'Aperçu en temps réel des statistiques de l\'établissement',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Row(
          children: [
            _buildHeaderButton(
              Icons.download_rounded,
              'Exporter',
              isDark,
              onTap: () async {
                if (_stats != null) {
                  await DashboardPdfService.generateDashboardReport(_stats!);
                }
              },
            ),
            const SizedBox(width: 12),
            _buildHeaderButton(
              Icons.refresh_rounded,
              'Actualiser',
              isDark,
              isPrimary: true,
              onTap: () {
                if (_lastLoadedAnneeId != null) {
                  _loadDashboardData(_lastLoadedAnneeId!);
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderButton(
    IconData icon,
    String label,
    bool isDark, {
    bool isPrimary = false,
    VoidCallback? onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap ?? () {},
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary
            ? AppTheme.primaryColor
            : (isDark ? Colors.grey[800] : Colors.white),
        foregroundColor: isPrimary
            ? Colors.white
            : (isDark ? Colors.white : AppTheme.textPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isPrimary
              ? BorderSide.none
              : BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
        ),
        elevation: isPrimary ? 4 : 0,
      ),
    );
  }

  Widget _buildStatsGrid(
    BuildContext context,
    Map financial,
    double recoveryRate,
    Map academic,
  ) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getCrossAxisCount(context),
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        mainAxisExtent: 190,
      ),
      children: [
        StatsCard(
          title: 'Effectif Total',
          value: '${_stats?['students'] ?? 0}',
          subtitle: 'Élèves inscrits',
          icon: Icons.people_alt_rounded,
          iconColor: Colors.white,
          iconBackgroundColor: AppTheme.primaryColor,
        ),
        StatsCard(
          title: 'Dépenses',
          value: _formatAbbreviatedAmount(
            (financial['expenses'] ?? 0).toDouble(),
          ),
          tooltipMessage: _currencyFormat.format(financial['expenses'] ?? 0),
          subtitle: 'Salaires & Charges',
          icon: Icons.outbox_rounded,
          iconColor: Colors.white,
          iconBackgroundColor: Colors.redAccent,
        ),
        StatsCard(
          title: 'Recouvrement',
          value: '${recoveryRate.toStringAsFixed(1)}%',
          subtitle: 'Taux de paiement',
          icon: Icons.pie_chart_rounded,
          iconColor: Colors.white,
          iconBackgroundColor: Colors.green,
          showProgress: true,
          progressValue: recoveryRate / 100,
        ),
        StatsCard(
          title: 'Budget Net',
          value: _formatAbbreviatedAmount(
            (financial['netRevenue'] ?? financial['collected'] ?? 0).toDouble(),
          ),
          tooltipMessage: _currencyFormat.format(
            financial['netRevenue'] ?? financial['collected'] ?? 0,
          ),
          subtitle: 'Trésorerie Actuelle',
          icon: Icons.account_balance_rounded,
          iconColor: Colors.white,
          iconBackgroundColor: Colors.teal,
        ),
        StatsCard(
          title: 'Collecte Mensuelle',
          value: _formatAbbreviatedAmount(
            financial['thisMonth']?.toDouble() ?? 0.0,
          ),
          tooltipMessage: _currencyFormat.format(financial['thisMonth'] ?? 0),
          subtitle:
              '${(financial['growth'] ?? 0) >= 0 ? '+' : ''}${financial['growth']?.toStringAsFixed(1)}% vs mois dernier',
          icon: Icons.payments_rounded,
          iconColor: Colors.white,
          iconBackgroundColor: Colors.indigo,
          subtitleColor: (financial['growth'] ?? 0) >= 0
              ? Colors.green
              : Colors.red,
        ),
        StatsCard(
          title: 'Personnel',
          value: '${_stats?['teachers'] ?? 0}',
          subtitle: 'Enseignants & Staff',
          icon: Icons.school_rounded,
          iconColor: Colors.white,
          iconBackgroundColor: Colors.orange,
        ),
        StatsCard(
          title: 'Taux de Réussite',
          value:
              '${(academic['successRate'] as num?)?.toStringAsFixed(1) ?? '0.0'}%',
          subtitle: 'Global (Matières)',
          icon: Icons.auto_graph_rounded,
          iconColor: Colors.white,
          iconBackgroundColor: Colors.cyan,
          showProgress: true,
          progressValue:
              ((academic['successRate'] as num?)?.toDouble() ?? 0.0) / 100,
        ),
        StatsCard(
          title: 'Moyenne Générale',
          value:
              '${(academic['average'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
          subtitle: 'Moyenne de l\'école',
          icon: Icons.analytics_rounded,
          iconColor: Colors.white,
          iconBackgroundColor: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildActionItem(
            Icons.person_add_rounded,
            'Nouvel Élève',
            Colors.blue,
            isDark,
            onTap: () {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AddStudentModal(
                  onSuccess: () {
                    if (_lastLoadedAnneeId != null) {
                      _loadDashboardData(_lastLoadedAnneeId!);
                    }
                  },
                  onClose: () => Navigator.pop(context),
                ),
              );
            },
          ),
          _buildActionItem(
            Icons.add_card_rounded,
            'Nouveau Paiement',
            Colors.green,
            isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NewPaymentPage()),
              );
            },
          ),
          _buildActionItem(
            Icons.class_rounded,
            'Gérer Classes',
            Colors.purple,
            isDark,
            targetIndex: 2,
          ),
          _buildActionItem(
            Icons.assessment_rounded,
            'Rapports',
            Colors.orange,
            isDark,
            targetIndex: 9,
          ),
          _buildActionItem(
            Icons.event_note_rounded,
            'Emploi du Temps',
            Colors.teal,
            isDark,
            targetIndex: 6,
          ),
          _buildActionItem(
            Icons.settings_rounded,
            'Paramètres',
            Colors.grey,
            isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SettingsPage(onRetour: () => Navigator.pop(context)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(
    IconData icon,
    String label,
    Color color,
    bool isDark, {
    int? targetIndex,
    VoidCallback? onTap,
  }) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      child: Material(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap:
              onTap ??
              () {
                if (targetIndex != null && widget.onNavigate != null) {
                  widget.onNavigate!(targetIndex);
                }
              },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade100,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGraphsGrid(ThemeData theme, bool isDark) {
    return Column(
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 24,
          children: [
            SizedBox(
              width: 380,
              child: _buildPieChartCard(
                'Répartition par Sexe',
                _stats?['genderStats'] ?? [],
                isGender: true,
              ),
            ),
            SizedBox(
              width: 380,
              child: _buildPieChartCard(
                'Répartition par Cycle',
                _stats?['cycleStats'] ?? [],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildPaymentComparisonCard(_stats?['financial'] ?? {}),
        const SizedBox(height: 24),
        _buildBarChartCard('Élèves par Classe', _stats?['classStats'] ?? []),
        const SizedBox(height: 24),
        _buildPaymentTrendCard(
          'Tendance des Paiements',
          _stats?['paymentMonthlyStats'] ?? [],
        ),
        const SizedBox(height: 24),
        _buildRevenueVsExpenseCard(
          'Revenus vs Dépenses',
          _stats?['paymentMonthlyStats'] ?? [],
          _stats?['expenseMonthlyStats'] ?? [],
        ),
      ],
    );
  }

  Widget _buildPieChartCard(String title, List data, {bool isGender = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Color> colors = [
      AppTheme.primaryColor,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.teal,
    ];

    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
        ),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: data.isEmpty
                ? const Center(child: Text('Pas de données'))
                : PieChart(
                    PieChartData(
                      sections: data.asMap().entries.map((e) {
                        final val = (e.value['count'] as num).toDouble();
                        return PieChartSectionData(
                          value: val,
                          title: '$val',
                          color: colors[e.key % colors.length],
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: data.asMap().entries.map((e) {
              final label = isGender
                  ? (e.value['sexe'] == 'M' ? 'Garçons' : 'Filles')
                  : e.value['cycle'] ?? 'N/A';
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    color: colors[e.key % colors.length],
                  ),
                  const SizedBox(width: 4),
                  Text(label, style: const TextStyle(fontSize: 11)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChartCard(String title, List data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
        ),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          Expanded(
            child: data.isEmpty
                ? const Center(child: Text('Pas de données'))
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: data.isEmpty
                          ? 10
                          : (data
                                    .map((e) => (e['count'] as num).toDouble())
                                    .reduce((a, b) => a > b ? a : b) *
                                1.2),
                      barGroups: data.asMap().entries.map((e) {
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: (e.value['count'] as num).toDouble(),
                              color: AppTheme.primaryColor,
                              width: 20,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              int idx = value.toInt();
                              if (idx >= 0 && idx < data.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    data[idx]['nom'],
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTrendCard(String title, List data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Reverse data for chronological display
    final chronData = data.reversed.toList();

    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
        ),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          Expanded(
            child: chronData.isEmpty
                ? const Center(child: Text('Pas de données de paiement'))
                : LineChart(
                    LineChartData(
                      gridData: const FlGridData(
                        show: true,
                        drawVerticalLine: false,
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              int idx = value.toInt();
                              if (idx >= 0 && idx < chronData.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    chronData[idx]['month'],
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
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                _formatAbbreviatedAmount(value),
                                style: const TextStyle(fontSize: 8),
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
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: chronData.asMap().entries.map((e) {
                            return FlSpot(
                              e.key.toDouble(),
                              (e.value['total'] as num).toDouble(),
                            );
                          }).toList(),
                          isCurved: true,
                          color: AppTheme.primaryColor,
                          barWidth: 4,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueVsExpenseCard(
    String title,
    List revenueData,
    List expenseData,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Process data to align months
    final Map<String, double> revenueMap = {
      for (var item in revenueData)
        item['month']: (item['total'] as num).toDouble(),
    };
    final Map<String, double> expenseMap = {
      for (var item in expenseData)
        item['month']: (item['total'] as num).toDouble(),
    };

    final Set<String> allMonths = {...revenueMap.keys, ...expenseMap.keys};
    final List<String> sortedMonths = allMonths.toList()..sort();
    final List<String> displayMonths = sortedMonths.length > 6
        ? sortedMonths.sublist(sortedMonths.length - 6)
        : sortedMonths;

    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Row(
                children: [
                  _buildLegendItem('Revenus', Colors.green),
                  const SizedBox(width: 16),
                  _buildLegendItem('Dépenses', Colors.red),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: displayMonths.isEmpty
                ? const Center(child: Text('Pas de données comparatives'))
                : BarChart(
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
                                  text: _currencyFormat.format(rod.toY),
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
                            reservedSize: 45,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                _formatAbbreviatedAmount(value),
                                style: const TextStyle(fontSize: 9),
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
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(
                        show: true,
                        drawVerticalLine: false,
                      ),
                      barGroups: displayMonths.asMap().entries.map((e) {
                        final month = e.value;
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: revenueMap[month] ?? 0.0,
                              color: Colors.green,
                              width: 12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            BarChartRodData(
                              toY: expenseMap[month] ?? 0.0,
                              color: Colors.red,
                              width: 12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
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

  Widget _buildPaymentComparisonCard(Map<String, dynamic> financial) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final collected = (financial['collected'] as num?)?.toDouble() ?? 0.0;
    final remaining = (financial['remaining'] as num?)?.toDouble() ?? 0.0;
    final total = collected + remaining;

    final List<Map<String, dynamic>> data = [
      {'label': 'Payé', 'value': collected, 'color': Colors.green},
      {'label': 'Impayé', 'value': remaining, 'color': Colors.red},
    ];

    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Situation Financière (Payé vs Impayé)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: total == 0
                ? const Center(child: Text('Pas de données financières'))
                : PieChart(
                    PieChartData(
                      sections: data.map((e) {
                        return PieChartSectionData(
                          value: e['value'],
                          title:
                              '${((e['value'] / total) * 100).toStringAsFixed(1)}%',
                          color: e['color'],
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 50,
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: data.map((e) {
              final formatter = NumberFormat.currency(
                locale: 'fr_FR',
                symbol: 'GNF',
                decimalDigits: 0,
              );
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 12, height: 12, color: e['color']),
                  const SizedBox(width: 8),
                  Text(
                    '${e['label']}: ${formatter.format(e['value'])}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
