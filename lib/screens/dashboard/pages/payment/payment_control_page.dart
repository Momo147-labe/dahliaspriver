import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../theme/app_theme.dart';

class PaymentControlPage extends StatefulWidget {
  const PaymentControlPage({super.key});

  @override
  State<PaymentControlPage> createState() => _PaymentControlPageState();
}

class _PaymentControlPageState extends State<PaymentControlPage> {
  final dbHelper = DatabaseHelper.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _studentsData = [];
  List<Map<String, dynamic>> _filteredData = [];
  String _searchQuery = "";

  // Stats
  int _enRegle = 0;
  int _enRetard = 0;
  double _tauxRecouvrement = 0.0;
  String _activeAnneeLabel = "";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final anneeId = await dbHelper.ensureActiveAnneeCached();
      if (anneeId != null) {
        final data = await dbHelper.getStudentPaymentControlData(anneeId);
        final activeAnnee = await dbHelper.getActiveAnnee();
        setState(() {
          _studentsData = data;
          _activeAnneeLabel = activeAnnee?['libelle'] ?? "N/A";
          _applyFilters();
          _calculateStats();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading payment control data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _calculateStats() {
    int upToDate = 0;
    int late = 0;
    double totalExpected = 0;
    double totalCollected = 0;

    for (var student in _studentsData) {
      final double totalPaid =
          (student['total_paye'] as num?)?.toDouble() ?? 0.0;
      final double totalDue =
          (student['montant_total'] as num?)?.toDouble() ?? 0.0;

      totalExpected += totalDue;
      totalCollected += totalPaid;

      if (totalPaid >= totalDue) {
        upToDate++;
      } else {
        late++;
      }
    }

    setState(() {
      _enRegle = upToDate;
      _enRetard = late;
      _tauxRecouvrement = totalExpected > 0
          ? (totalCollected / totalExpected) * 100
          : 0.0;
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredData = _studentsData.where((student) {
        final fullName = "${student['prenom']} ${student['nom']}".toLowerCase();
        final matricule = (student['matricule'] ?? "").toLowerCase();
        return fullName.contains(_searchQuery.toLowerCase()) ||
            matricule.contains(_searchQuery.toLowerCase());
      }).toList();
    });
  }

  String _getStatus(Map<String, dynamic> student, String type) {
    final double totalPaid = (student['total_paye'] as num?)?.toDouble() ?? 0.0;
    final double inscription =
        (student['inscription'] as num?)?.toDouble() ?? 0.0;
    final double reinscription =
        (student['reinscription'] as num?)?.toDouble() ?? 0.0;
    final double t1 = (student['tranche1'] as num?)?.toDouble() ?? 0.0;
    final double t2 = (student['tranche2'] as num?)?.toDouble() ?? 0.0;
    final double t3 = (student['tranche3'] as num?)?.toDouble() ?? 0.0;

    final bool isReinscrit = student['eleve_statut'] == 'reinscrit';
    final double firstFee = isReinscrit ? reinscription : inscription;

    double sum1 = firstFee;
    double sum2 = sum1 + t1;
    double sum3 = sum2 + t2;
    double sum4 = sum3 + t3;

    switch (type) {
      case 'Inscription':
        if (totalPaid >= sum1) return "Payé";
        if (totalPaid > 0) return "Partiel";
        return "Impayé";
      case 'Tranche 1':
        if (totalPaid >= sum2) return "Payé";
        if (totalPaid > sum1) return "Partiel";
        return "Impayé";
      case 'Tranche 2':
        if (totalPaid >= sum3) return "Payé";
        if (totalPaid > sum2) return "Partiel";
        return "Impayé";
      case 'Tranche 3':
        if (totalPaid >= sum4) return "Payé";
        if (totalPaid > sum3) return "Partiel";
        return "Impayé";
      default:
        return "Inconnu";
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "Payé":
        return AppTheme.successColor;
      case "Partiel":
        return AppTheme.warningColor;
      case "Impayé":
        return AppTheme.errorColor;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.backgroundDark
          : AppTheme.backgroundLight,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(isDark, theme),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        _buildFilters(isDark, theme),
                        const SizedBox(height: 32),
                        _buildStatsGrid(isDark, theme),
                        const SizedBox(height: 32),
                        _buildDataTable(isDark, theme),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader(bool isDark, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Symbols.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Contrôle des Frais",
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Text(
                  'Suivi des paiements et recouvrement par classe',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildActionButton(
                Symbols.download,
                "Exporter les impayés",
                isDark,
                theme,
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                Symbols.add,
                "Nouvel Encaissement",
                isDark,
                theme,
                isPrimary: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    bool isDark,
    ThemeData theme, {
    bool isPrimary = false,
  }) {
    return ElevatedButton.icon(
      onPressed: () {},
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

  Widget _buildFilters(bool isDark, ThemeData theme) {
    return Row(
      children: [
        _buildFilterChip(_activeAnneeLabel, Symbols.calendar_today, isDark),
        const SizedBox(width: 12),
        _buildFilterChip("Primaire", Symbols.school, isDark),
        const SizedBox(width: 12),
        _buildFilterChip("Toutes les classes", Symbols.meeting_room, isDark),
        const SizedBox(width: 24),
        Expanded(
          child: TextField(
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
                _applyFilters();
              });
            },
            decoration: InputDecoration(
              hintText: "Rechercher un élève...",
              prefixIcon: const Icon(Symbols.search, size: 20),
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(width: 4),
          const Icon(Symbols.expand_more, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(bool isDark, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            "En règle",
            _enRegle.toString(),
            "+5%",
            Symbols.verified,
            AppTheme.successColor,
            isDark,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildStatCard(
            "En retard",
            _enRetard.toString(),
            "-2%",
            Symbols.warning,
            AppTheme.errorColor,
            isDark,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildStatCard(
            "Taux de recouvrement",
            "${_tauxRecouvrement.toStringAsFixed(1)}%",
            "+12%",
            Symbols.pie_chart,
            AppTheme.primaryColor,
            isDark,
            isHighlight: true,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String trend,
    IconData icon,
    Color color,
    bool isDark, {
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isHighlight
              ? color.withOpacity(0.5)
              : (isDark ? Colors.white10 : Colors.grey.shade200),
          width: isHighlight ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.grey : AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: color, size: 24),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                trend,
                style: TextStyle(
                  color: trend.startsWith('+')
                      ? AppTheme.successColor
                      : AppTheme.errorColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: title == "En règle"
                  ? (_enRegle / (_enRegle + _enRetard + 0.1))
                  : (title == "En retard"
                        ? (_enRetard / (_enRegle + _enRetard + 0.1))
                        : (_tauxRecouvrement / 100)),
              backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
              color: color,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(bool isDark, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Liste des Élèves",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Symbols.filter_list, color: Colors.grey),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Symbols.more_vert, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 48,
              ),
              child: DataTable(
                horizontalMargin: 24,
                columnSpacing: 40,
                dataRowMaxHeight: 70,
                dataRowMinHeight: 60,
                headingRowHeight: 60,
                headingRowColor: WidgetStateProperty.all(
                  isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
                ),
                columns: const [
                  DataColumn(
                    label: Text(
                      "ÉLÈVE",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "CLASSE",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "INSCRIPTION",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "TRANCHE 1",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "TRANCHE 2",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "TRANCHE 3",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "ACTIONS",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
                rows: _filteredData.map((student) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppTheme.primaryColor
                                  .withOpacity(0.1),
                              child: Text(
                                student['nom'][0],
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${student['prenom']} ${student['nom']}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  student['matricule'] ?? "",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Text(
                          student['classe_nom'] ?? "",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      DataCell(
                        _buildStatusBadge(_getStatus(student, 'Inscription')),
                      ),
                      DataCell(
                        _buildStatusBadge(_getStatus(student, 'Tranche 1')),
                      ),
                      DataCell(
                        _buildStatusBadge(_getStatus(student, 'Tranche 2')),
                      ),
                      DataCell(
                        _buildStatusBadge(_getStatus(student, 'Tranche 3')),
                      ),
                      DataCell(
                        _getStatus(student, 'Tranche 3') == "Payé"
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  "À jour",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor
                                      .withOpacity(0.1),
                                  foregroundColor: AppTheme.primaryColor,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 0,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  minimumSize: const Size(0, 32),
                                ),
                                child: const Text(
                                  "Relancer",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
