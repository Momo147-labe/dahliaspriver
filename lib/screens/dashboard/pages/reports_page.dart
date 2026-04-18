import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../core/database/database_helper.dart';
import '../../../widgets/reports/bulletin_preview.dart';
import '../../../widgets/reports/bulletin_pdf_helper.dart';
import '../../../core/utils/mention_helper.dart';
import '../../../models/ecole.dart';
import '../../grades/result_sheet_selection_modal.dart';
import '../../../theme/app_theme.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  int _selectedTrimestre = 0;
  Map<String, dynamic>? _selectedClasse;
  Map<String, dynamic>? _selectedStudent;
  Ecole? _ecole;
  double _zoomLevel = 0.85;
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _leftPanelScrollController = ScrollController();
  final ScrollController _rightPanelScrollController = ScrollController();

  final List<String> _trimestres = [
    '1er Trimestre',
    '2ème Trimestre',
    '3ème Trimestre',
    'Bilan Annuel',
  ];
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _grades = [];
  Map<String, dynamic> _bulletinStats = {};
  Map<int, bool> _studentCompletionStatus = {};
  List<Map<String, dynamic>> _allSequences = [];
  Map<int, List<Map<String, dynamic>>> _trimesterMap = {};
  List<int> _plannedTrimesters = [];
  List<Map<String, dynamic>> _mentions = [];

  bool _isAnnualMode = false;

  String? _anneeLibelle;
  bool get _isAnnualSelected => _selectedTrimestre == _trimestres.length - 1;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _showClassSearch() async {
    final Map<String, dynamic>? selected =
        await showSearch<Map<String, dynamic>>(
          context: context,
          delegate: ClasseSearchDelegate(_classes),
        );

    if (selected != null && mounted) {
      setState(() {
        _selectedClasse = selected;
        _searchQuery = '';
        _searchController.clear();
      });
      _loadStudentsForClass(selected['id']);
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    // Load school info
    _ecole = await _dbHelper.getEcole();

    // Load active academic year
    final anneeId = await _dbHelper.ensureActiveAnneeCached();
    if (anneeId != null) {
      final db = await _dbHelper.database;
      final anneeRes = await db.query(
        'annee_scolaire',
        where: 'id = ?',
        whereArgs: [anneeId],
      );
      if (anneeRes.isNotEmpty) {
        _anneeLibelle = anneeRes.first['libelle'] as String;
      }

      // Load all sequences for mapping
      final sequences = await _dbHelper.getSequencesPlanification(anneeId);
      _allSequences = List<Map<String, dynamic>>.from(sequences);

      // Group by trimester
      _trimesterMap.clear();
      for (var s in _allSequences) {
        int tri = s['trimestre'] as int;
        _trimesterMap.putIfAbsent(tri, () => []).add(s);
      }
    }

    final classesList = await _dbHelper.getClassesForReports();

    // Load dynamic periods for active year
    if (anneeId != null) {
      final trimesters = await _dbHelper.getTrimesters(anneeId);
      if (mounted) {
        setState(() {
          _classes = List<Map<String, dynamic>>.from(classesList);
          if (_classes.isNotEmpty) {
            _selectedClasse = _classes[0];
            _loadStudentsForClass(_classes[0]['id']);
          }

          if (trimesters.isNotEmpty) {
            _plannedTrimesters = trimesters;
            _trimestres.clear();
            for (int tri in trimesters) {
              if (tri == 1)
                _trimestres.add('1er Trimestre');
              else if (tri == 2)
                _trimestres.add('2ème Trimestre');
              else
                _trimestres.add('$trième Trimestre');
            }
            _trimestres.add('Bilan Annuel');
          } else {
            // Re-fallback
            _plannedTrimesters = [1, 2, 3];
            _trimestres.clear();
            _trimestres.addAll([
              '1er Trimestre',
              '2ème Trimestre',
              '3ème Trimestre',
              'Bilan Annuel',
            ]);
          }

          if (_classes.isEmpty) {
            _isLoading = false;
          }
        });
      }
    }
  }

  Future<void> _loadStudentsForClass(int classId) async {
    setState(() => _isLoading = true);

    // Load students
    final students = await _dbHelper.getStudentsByClasse(classId);

    // Load completion status for current term
    final anneeId = await _dbHelper.ensureActiveAnneeCached();
    if (anneeId != null) {
      final statusList = await _dbHelper.getStudentsCompletionStatus(
        classId,
        _isAnnualMode ? 0 : _selectedTrimestre + 1,
        anneeId,
      );

      _studentCompletionStatus = {
        for (var item in statusList)
          (item['eleve_id'] as int):
              (item['total_subjects'] as int) > 0 &&
              (item['subjects_with_notes'] as int) >=
                  (item['total_subjects'] as int),
      };
    }

    if (mounted) {
      setState(() {
        _students = List<Map<String, dynamic>>.from(students);
        if (_students.isNotEmpty) {
          _selectedStudent = _students[0];
          _loadBulletinData();
        } else {
          _selectedStudent = null;
          _isLoading = false;
        }
      });
    }
  }

  Future<void> _loadBulletinData() async {
    if (_selectedStudent == null) return;

    setState(() => _isLoading = true);

    int tri = _selectedTrimestre + 1;
    final anneeId = await _dbHelper.ensureActiveAnneeCached();
    if (anneeId == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Determine the list of periods to display
    final isAnnual = _isAnnualSelected;

    // Load mentions if a cycle is defined
    if (_selectedClasse?['cycle_id'] != null) {
      _mentions = await _dbHelper.getMentionsByCycle(
        _selectedClasse!['cycle_id'],
      );
    } else {
      _mentions = [];
    }

    try {
      if (isAnnual) {
        final stats = await _dbHelper.getAnnualStats(
          _selectedStudent!['id'],
          _selectedClasse!['id'],
          anneeId,
        );
        final notes = await _dbHelper.getAnnualGradesForStudent(
          _selectedStudent!['id'],
          anneeId,
          classId: _selectedClasse!['id'],
        );

        if (mounted) {
          setState(() {
            _isAnnualMode = true;
            _bulletinStats = stats;
            _grades = notes;
            _isLoading = false;
          });
        }
        return;
      }

      // Normal load (Trimestre or Sequence)
      final stats = await _dbHelper.getBulletinStats(
        _selectedStudent!['id'],
        _selectedClasse!['id'],
        tri,
        anneeId,
      );

      final notes = await _dbHelper.getStudentNotesForBulletin(
        _selectedStudent!['id'],
        tri,
        anneeId,
      );

      // All periodic reports (non-annual) are handled as trimesters
      final currentTriSeqs = _trimesterMap[tri] ?? [];
      final processedGrades = _groupGradesBySubject(notes, currentTriSeqs);

      if (mounted) {
        setState(() {
          _isAnnualMode = false;
          _bulletinStats = stats;
          _grades = processedGrades;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur de chargement : $e')));
      }
    }
  }

  void _showResultSheetModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ResultSheetSelectionModal(dbHelper: _dbHelper),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _leftPanelScrollController.dispose();
    _rightPanelScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Use AppTheme constants instead of local hardcoded colors
    final primaryColor = AppTheme.primaryColor;
    final textPrimary = isDark
        ? AppTheme.textDarkPrimary
        : AppTheme.textPrimary;
    final textSecondary = isDark
        ? AppTheme.textDarkSecondary
        : AppTheme.textSecondary;
    final borderMain = isDark ? AppTheme.borderDark : AppTheme.borderLight;
    final surfaceMain = isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight;
    final backgroundMain = isDark
        ? AppTheme.backgroundDark
        : AppTheme.backgroundLight;
    final surfaceSecondary = isDark
        ? AppTheme.cardDark.withOpacity(0.5)
        : AppTheme.cardLight;

    return Container(
      color: backgroundMain,
      child: Column(
        children: [
          // Fixed Header Section
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTitleSection(
                  isDark,
                  primaryColor,
                  textPrimary,
                  textSecondary,
                  borderMain,
                  surfaceMain,
                ),
                const SizedBox(height: 12),

                // Academic Term Tabs
                _buildTrimestreTabs(
                  isDark,
                  primaryColor,
                  textPrimary,
                  textSecondary,
                  borderMain,
                ),
              ],
            ),
          ),

          // Scrollable Main Content
          Expanded(
            child: _isLoading && _classes.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Panel: Classes & Students
                        SizedBox(
                          width: 320,
                          child: _buildLeftPanel(
                            isDark,
                            primaryColor,
                            textPrimary,
                            textSecondary,
                            borderMain,
                            surfaceMain,
                            surfaceSecondary,
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Right Panel: Preview
                        Expanded(
                          child: _selectedStudent == null
                              ? Center(
                                  child: Text(
                                    'Aucun élève sélectionné',
                                    style: TextStyle(color: textSecondary),
                                  ),
                                )
                              : _buildRightPanel(
                                  isDark,
                                  primaryColor,
                                  textPrimary,
                                  textSecondary,
                                  borderMain,
                                  surfaceMain,
                                  surfaceSecondary,
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

  Widget _buildTitleSection(
    bool isDark,
    Color primaryColor,
    Color textPrimary,
    Color textSecondary,
    Color borderMain,
    Color surfaceMain,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Si l'écran est large, utiliser Row, sinon Column
        if (constraints.maxWidth > 800) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.analytics_rounded,
                            color: primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [
                                  primaryColor,
                                  primaryColor.withOpacity(0.8),
                                ],
                              ).createShader(bounds),
                              child: const Text(
                                'Gestion des Rapports',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: _showClassSearch,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: surfaceMain,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: borderMain),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.search_rounded,
                                      size: 16,
                                      color: primaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _selectedClasse?['nom'] ??
                                          'Sélectionner une classe',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _selectedClasse == null
                                            ? textSecondary
                                            : textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 18,
                                      color: textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: _showResultSheetModal,
                    icon: const Icon(Icons.analytics_outlined, size: 18),
                    label: const Text('Rapport de Classe'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? surfaceMain : Colors.white,
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _exportBatchPdf,
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('Générer Bulletins (PDF)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: textPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gestion des Bulletins Scolaires',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sélectionnez une classe et un élève pour prévisualiser ou imprimer les rapports.',
                style: TextStyle(fontSize: 14, color: textSecondary),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: _showResultSheetModal,
                    icon: const Icon(Icons.analytics_outlined, size: 18),
                    label: const Text('Rapport de Classe'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? surfaceMain : Colors.white,
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _exportBatchPdf,
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('Générer Bulletins (PDF)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: textPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildTrimestreTabs(
    bool isDark,
    Color primaryColor,
    Color textPrimary,
    Color textSecondary,
    Color borderMain,
  ) {
    // Determine the list of periods to display
    final labels = _trimestres;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderMain)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: labels.asMap().entries.map((entry) {
            final index = entry.key;
            final isSelected = _selectedTrimestre == index;
            final isAnnual = index == labels.length - 1;

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedTrimestre = index;
                  _isAnnualMode = isAnnual;
                });
                if (_selectedClasse != null) {
                  _loadStudentsForClass(_selectedClasse!['id']);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? primaryColor : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? (isDark ? Colors.white : textPrimary)
                        : textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLeftPanel(
    bool isDark,
    Color primaryColor,
    Color textPrimary,
    Color textSecondary,
    Color borderMain,
    Color surfaceMain,
    Color surfaceSecondary,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Class Selection List
        // Searchable Class Picker in Header instead of horizontal list
        const SizedBox.shrink(),
        const SizedBox(height: 16),
        // Student List with Search
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: surfaceMain,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderMain),
            ),
            child: Column(
              children: [
                // Header + Search
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Élèves',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? Colors.white : textPrimary,
                            ),
                          ),
                          Text(
                            '${_students.length} au total',
                            style: TextStyle(
                              fontSize: 11,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Rechercher un élève...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          isDense: true,
                          contentPadding: const EdgeInsets.all(10),
                          fillColor: surfaceSecondary,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _students.length,
                    itemBuilder: (context, index) {
                      final student = _students[index];
                      final fullName = '${student['nom']} ${student['prenom']}'
                          .toLowerCase();
                      if (_searchQuery.isNotEmpty &&
                          !fullName.contains(_searchQuery.toLowerCase())) {
                        return const SizedBox.shrink();
                      }

                      final isSelected =
                          _selectedStudent?['id'] == student['id'];
                      final initiales =
                          (student['nom'] as String).substring(0, 1) +
                          (student['prenom'] as String).substring(0, 1);
                      return InkWell(
                        onTap: () {
                          setState(() => _selectedStudent = student);
                          _loadBulletinData();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryColor.withOpacity(0.05)
                                : Colors.transparent,
                            border: Border(
                              left: BorderSide(
                                color: isSelected
                                    ? primaryColor
                                    : Colors.transparent,
                                width: 4,
                              ),
                              bottom: BorderSide(color: borderMain),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isSelected
                                    ? primaryColor.withOpacity(0.2)
                                    : surfaceSecondary,
                                child: Text(
                                  initiales.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? primaryColor
                                        : textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${student['nom']} ${student['prenom']}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: isDark
                                            ? Colors.white
                                            : textPrimary,
                                      ),
                                    ),
                                    Text(
                                      student['matricule'] ?? '',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_studentCompletionStatus[student['id']] ??
                                  false)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Prêt',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Incomplet',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getDynamicColumns() {
    final isAnnual = _isAnnualSelected;
    if (isAnnual) {
      return _plannedTrimesters
          .map((t) => {'key': t, 'label': 'Trim. $t'})
          .toList();
    } else {
      final sequences = _trimesterMap[_selectedTrimestre + 1] ?? [];
      return sequences
          .map(
            (s) => {
              'key': s['numero_sequence'],
              'label': s['nom']?.toString() ?? 'S${s['numero_sequence']}',
            },
          )
          .toList();
    }
  }

  String _getNoteKey() {
    return _isAnnualSelected ? 'notes_par_trimestre' : 'notes_par_sequence';
  }

  Widget _buildPreviewContent() {
    if (_selectedStudent == null) {
      return const Center(child: Text('Sélectionnez un élève'));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderMain = isDark ? Colors.white10 : Colors.black.withOpacity(0.05);
    final isAnnual = _isAnnualSelected;
    final columns = _getDynamicColumns();
    final noteKey = _getNoteKey();

    return Column(
      children: [
        // ToolBar (Zoom & Export)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderMain),
          ),
          child: Row(
            children: [
              Text(
                'Bulletin Preview',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.zoom_out, size: 20),
                onPressed: () => setState(
                  () => _zoomLevel = (_zoomLevel - 0.1).clamp(0.5, 2.0),
                ),
              ),
              Text(
                '${(_zoomLevel * 100).toInt()}%',
                style: const TextStyle(fontSize: 12),
              ),
              IconButton(
                icon: const Icon(Icons.zoom_in, size: 20),
                onPressed: () => setState(
                  () => _zoomLevel = (_zoomLevel + 0.1).clamp(0.5, 2.0),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _exportIndividualPdf,
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: const Text('PDF'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Document Area
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.backgroundDark.withOpacity(0.3)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderMain),
            ),
            child: Center(
              child: SingleChildScrollView(
                controller: _rightPanelScrollController,
                child: BulletinPreview(
                  zoomLevel: _zoomLevel,
                  trimestre: isAnnual
                      ? "BILAN ANNUEL"
                      : _trimestres[_selectedTrimestre].toUpperCase(),
                  annee: _anneeLibelle ?? 'N/A',
                  ecole: _ecole,
                  isAnnual: isAnnual,
                  columns: columns,
                  noteKey: noteKey,
                  studentInfo: {
                    ...Map<String, dynamic>.from(_selectedStudent ?? {}),
                    'classe_nom': _selectedClasse?['nom'] ?? '',
                  },
                  grades: _grades,
                  summary: {
                    'moyenne':
                        ((_bulletinStats['average'] as num?)?.toDouble())
                            ?.toStringAsFixed(2) ??
                        '0.00',
                    'rang':
                        '${_bulletinStats['rank'] ?? 0} / ${_bulletinStats['totalStudents'] ?? 0}',
                    'moyenneGenerale':
                        ((_bulletinStats['classAverage'] as num?)?.toDouble())
                            ?.toStringAsFixed(2) ??
                        '0.00',
                    'moyennePassage': _bulletinStats['moyenne_passage'],
                    'note_max': _bulletinStats['note_max'] ?? 20.0,
                    'observations': _getFinalObservation(
                      (_bulletinStats['average'] as num?)?.toDouble() ?? 0.0,
                    ),
                  },
                  mentions: _mentions,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanel(
    bool isDark,
    Color primaryColor,
    Color textPrimary,
    Color textSecondary,
    Color borderMain,
    Color surfaceMain,
    Color surfaceSecondary,
  ) {
    return _buildPreviewContent();
  }

  Future<void> _exportIndividualPdf() async {
    if (_selectedStudent == null ||
        _selectedClasse == null ||
        _anneeLibelle == null ||
        _isLoading) {
      return;
    }

    try {
      final columns = _getDynamicColumns();
      final noteKey = _getNoteKey();

      final pdf = _isAnnualSelected
          ? await BulletinPdfHelper.generateSingleAnnualBulletin(
              student: {
                ..._selectedStudent!,
                'classe_nom': _selectedClasse!['nom'],
              },
              grades: _grades,
              stats: _bulletinStats,
              ecole: _ecole,
              annee: _anneeLibelle!,
              columns: columns,
              noteKey: noteKey,
            )
          : await BulletinPdfHelper.generateSingleBulletin(
              student: {
                ..._selectedStudent!,
                'classe_nom': _selectedClasse!['nom'],
              },
              grades: _grades,
              stats: _bulletinStats,
              ecole: _ecole,
              trimestre: _trimestres[_selectedTrimestre],
              annee: _anneeLibelle!,
              columns: columns,
              noteKey: noteKey,
            );

      final fileName =
          'Bulletin_${_isAnnualSelected ? "Annuel" : _trimestres[_selectedTrimestre].replaceAll(' ', '_')}_${_selectedStudent!['nom']}_${_selectedStudent!['prenom']}.pdf';

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: fileName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la génération du PDF: $e')),
        );
      }
    }
  }

  Future<void> _exportBatchPdf() async {
    if (_selectedClasse == null || _anneeLibelle == null || _isLoading) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Génération des bulletins en cours...")),
    );

    setState(() => _isLoading = true);

    try {
      final isAnnual = _isAnnualSelected;
      final anneeId = await _dbHelper.ensureActiveAnneeCached();
      if (anneeId == null) throw Exception("Année scolaire non définie");

      List<Map<String, dynamic>> studentsData = [];
      final students = await _dbHelper.getStudentsByClasse(
        _selectedClasse!['id'],
      );

      for (var student in students) {
        if (isAnnual) {
          final grades = await _dbHelper.getAnnualGradesForStudent(
            student['id'],
            anneeId,
            classId: _selectedClasse!['id'],
          );
          final stats = await _dbHelper.getAnnualStats(
            student['id'],
            _selectedClasse!['id'],
            anneeId,
          );
          studentsData.add({
            'student': {...student, 'classe_nom': _selectedClasse!['nom']},
            'grades': grades,
            'stats': stats,
          });
        } else {
          final notes = await _dbHelper.getStudentNotesForBulletin(
            student['id'],
            _selectedTrimestre + 1,
            anneeId,
          );

          final stats = await _dbHelper.getBulletinStats(
            student['id'],
            _selectedClasse!['id'],
            _selectedTrimestre + 1,
            anneeId,
          );

          final currentTriSeqs = _trimesterMap[_selectedTrimestre + 1] ?? [];
          studentsData.add({
            'student': {...student, 'classe_nom': _selectedClasse!['nom']},
            'grades': _groupGradesBySubject(notes, currentTriSeqs),
            'stats': stats,
          });
        }
      }

      final columns = _getDynamicColumns();
      final noteKey = _getNoteKey();

      final pdf = isAnnual
          ? await BulletinPdfHelper.generateBatchAnnualBulletins(
              studentsData: studentsData,
              ecole: _ecole,
              annee: _anneeLibelle!,
              columns: columns,
              noteKey: noteKey,
              mentions: _mentions,
            )
          : await BulletinPdfHelper.generateBatchBulletins(
              studentsData: studentsData,
              ecole: _ecole,
              trimestre: _trimestres[_selectedTrimestre],
              annee: _anneeLibelle!,
              columns: columns,
              noteKey: noteKey,
              mentions: _mentions,
            );

      final fileName =
          'Bulletins_${_selectedClasse!['nom']}_${isAnnual ? "Annuel" : _trimestres[_selectedTrimestre].replaceAll(' ', '_')}.pdf';

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: fileName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la génération des bulletins: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getObservation(double note) {
    if (_mentions.isNotEmpty) {
      final m = MentionHelper.getMentionForGrade(note, _mentions);
      if (m != null) return m['appreciation'] ?? m['label'] ?? '';
    }
    if (note >= 16) return 'Très Bien';
    if (note >= 14) return 'Bien';
    if (note >= 12) return 'Assez Bien';
    if (note >= 10) return 'Passable';
    return 'Insuffisant';
  }

  String _getFinalObservation(double average) {
    if (_mentions.isNotEmpty) {
      final m = MentionHelper.getMentionForGrade(average, _mentions);
      if (m != null) return m['appreciation'] ?? m['label'] ?? '';
    }
    if (average >= 16) return 'Excellent travail, félicitations !';
    if (average >= 14) return 'Très bon travail, continuez ainsi.';
    if (average >= 12) return 'Bon travail, peut encore mieux faire.';
    if (average >= 10) return 'Résultats passables, redoublez d\'effort.';
    return 'Résultats insuffisants, doit travailler davantage.';
  }

  List<Map<String, dynamic>> _groupGradesBySubject(
    List<Map<String, dynamic>> rawNotes,
    List<Map<String, dynamic>> sequencesPlan,
  ) {
    Map<String, Map<String, dynamic>> grouped = {};
    for (var n in rawNotes) {
      String mId = n['matiere_id']?.toString() ?? n['matiere_nom'];
      if (!grouped.containsKey(mId)) {
        grouped[mId] = {
          'matiere': n['matiere_nom'],
          'coeff': (n['coefficient'] as num?)?.toDouble() ?? 1.0,
          'notes': <int, double?>{},
        };
      }

      double val = (n['note'] as num?)?.toDouble() ?? 0.0;
      int seqNum = n['sequence'] ?? 1;
      (grouped[mId]!['notes'] as Map<int, double?>)[seqNum] = val;
    }

    return grouped.values.map((g) {
      final notesMap = g['notes'] as Map<int, double?>;

      double sum = 0;
      double totalWeight = 0;

      for (var sPlan in sequencesPlan) {
        int sNum = sPlan['numero_sequence'] as int;
        double weight = (sPlan['poids'] as num?)?.toDouble() ?? 1.0;
        double? val = notesMap[sNum];

        if (val != null) {
          sum += val * weight;
          totalWeight += weight;
        }
      }

      double avg = totalWeight > 0 ? sum / totalWeight : 0.0;

      return {
        'matiere': g['matiere'],
        'coeff': g['coeff'],
        'notes_par_sequence': notesMap,
        'note': avg,
        'total': avg * ((g['coeff'] as num?)?.toDouble() ?? 1.0),
        'obs': _getObservation(avg),
      };
    }).toList();
  }
}

class ClasseSearchDelegate extends SearchDelegate<Map<String, dynamic>> {
  final List<Map<String, dynamic>> classes;

  ClasseSearchDelegate(this.classes);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null as dynamic);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = classes
        .where(
          (c) =>
              (c['nom'] as String).toLowerCase().contains(query.toLowerCase()),
        )
        .toList();

    return _buildList(results);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final results = classes
        .where(
          (c) =>
              (c['nom'] as String).toLowerCase().contains(query.toLowerCase()),
        )
        .toList();

    return _buildList(results);
  }

  Widget _buildList(List<Map<String, dynamic>> results) {
    if (results.isEmpty) {
      return const Center(child: Text('Aucune classe trouvée'));
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final classe = results[index];
        return ListTile(
          title: Text(classe['nom'] ?? ''),
          onTap: () {
            close(context, classe);
          },
        );
      },
    );
  }
}
