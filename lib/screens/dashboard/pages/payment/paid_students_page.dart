import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:printing/printing.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../theme/app_theme.dart';
import '../../../../services/pdf/payment_control_pdf_service.dart';

class PaidStudentsPage extends StatefulWidget {
  const PaidStudentsPage({super.key});

  @override
  State<PaidStudentsPage> createState() => _PaidStudentsPageState();
}

class _PaidStudentsPageState extends State<PaidStudentsPage> {
  final dbHelper = DatabaseHelper.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _studentsData = [];
  List<Map<String, dynamic>> _filteredData = [];
  String _activeAnneeLabel = "";
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _cycles = [];
  String _selectedCycle = "Tous";
  int? _selectedClasseId;
  String _searchQuery = "";
  int _currentPage = 1;
  static const int _pageSize = 50;

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
        // Only keep students who have paid everything
        final paidData = data.where((s) {
          final double? rest = s['montant_restant'] != null
              ? (s['montant_restant'] as num).toDouble()
              : null;
          final total = (s['montant_total'] as num?)?.toDouble() ?? 0.0;
          final paid = (s['total_paye'] as num?)?.toDouble() ?? 0.0;

          if (rest != null) {
            return rest <= 0 && total > 0;
          }
          return total > 0 && paid >= total;
        }).toList();

        final activeAnnee = await dbHelper.getActiveAnnee();
        final classes = await dbHelper.getAllClasses();
        final cycles = await dbHelper.getCycles();
        setState(() {
          _studentsData = paidData;
          _classes = classes;
          _cycles = cycles;
          _activeAnneeLabel = activeAnnee?['libelle'] ?? "N/A";
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading paid students data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredData = _studentsData.where((student) {
        final fullName = "${student['prenom']} ${student['nom']}".toLowerCase();
        final matricule = (student['matricule'] ?? "").toLowerCase();
        final matchesSearch =
            fullName.contains(_searchQuery.toLowerCase()) ||
            matricule.contains(_searchQuery.toLowerCase());

        final matchesCycle =
            _selectedCycle == "Tous" || student['cycle_nom'] == _selectedCycle;

        final matchesClasse =
            _selectedClasseId == null ||
            student['classe_id'] == _selectedClasseId;

        return matchesSearch && matchesCycle && matchesClasse;
      }).toList();
      _currentPage = 1;
    });
  }

  Future<void> _exportPdf() async {
    if (_filteredData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune donnée à exporter.')),
      );
      return;
    }
    try {
      final doc = await PaymentControlPdfService().generate(
        _filteredData,
        _activeAnneeLabel,
        isPaidOnly: true,
      );
      await Printing.layoutPdf(
        onLayout: (format) async => doc.save(),
        name: 'Liste_Eleves_Soldes.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur PDF: $e'),
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
                    "Élèves Soldés",
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
                  'Liste des élèves ayant entièrement réglé les frais pour $_activeAnneeLabel',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          _buildActionButton(
            Symbols.picture_as_pdf,
            "Exporter la liste",
            isDark,
            theme,
            isPrimary: true,
            onTap: _exportPdf,
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
    VoidCallback? onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
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
      ),
    );
  }

  Widget _buildFilters(bool isDark, ThemeData theme) {
    return Row(
      children: [
        _buildCycleFilter(isDark),
        const SizedBox(width: 12),
        _buildClasseFilter(isDark),
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
              hintText: "Rechercher...",
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

  Widget _buildCycleFilter(bool isDark) {
    return PopupMenuButton<String>(
      onSelected: (val) {
        setState(() {
          _selectedCycle = val;
          _selectedClasseId = null;
          _applyFilters();
        });
      },
      itemBuilder: (context) {
        return [
          const PopupMenuItem(value: "Tous", child: Text("Tous les cycles")),
          ..._cycles.map(
            (c) => PopupMenuItem(value: c['nom'], child: Text(c['nom'])),
          ),
        ];
      },
      child: _buildFilterChip(_selectedCycle, Symbols.school, isDark),
    );
  }

  Widget _buildClasseFilter(bool isDark) {
    String label = "Toutes les classes";
    if (_selectedClasseId != null) {
      final c = _classes.firstWhere(
        (e) => e['id'] == _selectedClasseId,
        orElse: () => {},
      );
      if (c.isNotEmpty) label = c['nom'];
    }
    final filteredClasses = _classes.where((c) {
      if (_selectedCycle == "Tous") return true;
      return c['cycle_nom'] == _selectedCycle;
    }).toList();

    return PopupMenuButton<int?>(
      onSelected: (val) {
        setState(() {
          _selectedClasseId = val;
          _applyFilters();
        });
      },
      itemBuilder: (context) {
        return [
          const PopupMenuItem(value: null, child: Text("Toutes les classes")),
          ...filteredClasses.map(
            (c) => PopupMenuItem(value: c['id'], child: Text(c['nom'])),
          ),
        ];
      },
      child: _buildFilterChip(label, Symbols.meeting_room, isDark),
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
        mainAxisSize: MainAxisSize.min,
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

  Widget _buildDataTable(bool isDark, ThemeData theme) {
    if (_filteredData.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(64),
          child: Column(
            children: [
              Icon(
                Symbols.verified_user,
                size: 64,
                color: AppTheme.primaryColor.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                "Aucun élève n'a encore tout payé.",
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize < _filteredData.length)
        ? startIndex + _pageSize
        : _filteredData.length;
    final pagedData = _filteredData.sublist(startIndex, endIndex);
    final totalPages = (_filteredData.length / _pageSize).ceil();

    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
          ),
          child: DataTable(
            horizontalMargin: 24,
            columnSpacing: 24,
            headingRowHeight: 60,
            dataRowMaxHeight: 70,
            columns: const [
              DataColumn(label: Text("ÉLÈVE")),
              DataColumn(label: Text("CLASSE")),
              DataColumn(label: Text("TOTAL PAYÉ")),
              DataColumn(label: Text("STATUT")),
            ],
            rows: pagedData.map((student) {
              final paid = (student['total_paye'] as num?)?.toDouble() ?? 0.0;
              return DataRow(
                cells: [
                  DataCell(_buildStudentLabel(student, isDark)),
                  DataCell(Text(student['classe_nom'] ?? "")),
                  DataCell(
                    Text(
                      "${paid.toInt()} GNF",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ),
                  DataCell(_buildStatusBadge("Soldé")),
                ],
              );
            }).toList(),
          ),
        ),
        if (totalPages > 1) _buildPagination(totalPages),
      ],
    );
  }

  Widget _buildStudentLabel(Map<String, dynamic> student, bool isDark) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
          child: Text(
            student['nom'][0],
            style: const TextStyle(
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
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              student['matricule'] ?? "",
              style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        "SOLDE RÉGLÉ",
        style: TextStyle(
          color: AppTheme.successColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPagination(int totalPages) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _currentPage > 1
                ? () => setState(() => _currentPage--)
                : null,
            icon: const Icon(Symbols.chevron_left),
          ),
          Text(
            "Page $_currentPage sur $totalPages",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          IconButton(
            onPressed: _currentPage < totalPages
                ? () => setState(() => _currentPage++)
                : null,
            icon: const Icon(Symbols.chevron_right),
          ),
        ],
      ),
    );
  }
}
