import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../core/database/database_helper.dart';
import '../../../widgets/reports/bulletin_preview.dart';
import '../../../widgets/reports/bulletin_pdf_helper.dart';
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

  String? _anneeLibelle;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
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
    }

    final classes = await _dbHelper.getClassesForReports();
    if (mounted) {
      setState(() {
        _classes = List<Map<String, dynamic>>.from(classes);
        if (_classes.isNotEmpty) {
          _selectedClasse = _classes[0];
          _loadStudentsForClass(_classes[0]['id']);
        } else {
          _isLoading = false;
        }
      });
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
        _selectedTrimestre + 1,
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

    // For now we use trimestre + 1 (0 to 3 index mapping to 1 to 4)
    // Trimestre 4 could be annual
    int tri = _selectedTrimestre + 1;

    // We need an active school year ID.
    final anneeId = await _dbHelper.ensureActiveAnneeCached();
    if (anneeId == null) {
      setState(() => _isLoading = false);
      return;
    }

    if (_selectedTrimestre == 3) {
      // Annual Report
      final grades = await _dbHelper.getAnnualGradesForStudent(
        _selectedStudent!['id'],
        anneeId,
        classId: _selectedClasse!['id'],
      );
      final stats = await _dbHelper.getAnnualStats(
        _selectedStudent!['id'],
        _selectedClasse!['id'],
        anneeId,
      );

      if (mounted) {
        setState(() {
          _grades = grades;
          _bulletinStats = stats;
          _isLoading = false;
        });
      }
    } else {
      // Trimester Report
      final notes = await _dbHelper.getStudentNotesForBulletin(
        _selectedStudent!['id'],
        tri,
        anneeId,
      );

      final stats = await _dbHelper.getBulletinStats(
        _selectedStudent!['id'],
        _selectedClasse!['id'],
        tri,
        anneeId,
      );

      final formattedGrades = _groupGradesBySubject(notes);

      if (mounted) {
        setState(() {
          _grades = formattedGrades;
          _bulletinStats = stats;
          _isLoading = false;
        });
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
                            Text(
                              'Générez et visualisez les bulletins scolaires',
                              style: TextStyle(
                                fontSize: 13,
                                color: textSecondary,
                                fontWeight: FontWeight.w500,
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
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderMain)),
      ),
      child: IntrinsicWidth(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _trimestres.asMap().entries.map((entry) {
            final index = entry.key;
            final isSelected = _selectedTrimestre == index;
            return Flexible(
              child: InkWell(
                onTap: () {
                  setState(() => _selectedTrimestre = index);
                  if (_selectedClasse != null) {
                    _loadStudentsForClass(_selectedClasse!['id']);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isSelected ? primaryColor : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.015,
                        color: isSelected
                            ? (isDark ? Colors.white : textPrimary)
                            : textSecondary,
                      ),
                    ),
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
        Container(
          height: 140,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surfaceMain,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderMain),
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _classes.length,
            itemBuilder: (context, index) {
              final classe = _classes[index];
              final isSelected = _selectedClasse?['id'] == classe['id'];
              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedClasse = classe;
                      _searchQuery = '';
                      _searchController.clear();
                    });
                    _loadStudentsForClass(classe['id']);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primaryColor.withOpacity(0.08)
                          : surfaceSecondary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? primaryColor : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.class_outlined,
                          color: isSelected ? primaryColor : textSecondary,
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          classe['nom'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isSelected ? primaryColor : textPrimary,
                          ),
                        ),
                        Text(
                          '${classe['student_count'] ?? 0} Élèves',
                          style: TextStyle(fontSize: 10, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
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

  Widget _buildRightPanel(
    bool isDark,
    Color primaryColor,
    Color textPrimary,
    Color textSecondary,
    Color borderMain,
    Color surfaceMain,
    Color surfaceSecondary,
  ) {
    bool isAnnual = _selectedTrimestre == 3;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Preview ToolBar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceMain,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderMain),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Aperçu du Bulletin',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : textPrimary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceSecondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.zoom_out, size: 18),
                          onPressed: () {
                            if (_zoomLevel > 0.5) {
                              setState(() => _zoomLevel -= 0.05);
                            }
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${(_zoomLevel * 100).toInt()}%',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.zoom_in, size: 18),
                          onPressed: () {
                            if (_zoomLevel < 1.5) {
                              setState(() => _zoomLevel += 0.05);
                            }
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.print, size: 20),
                    onPressed: _exportIndividualPdf,
                    color: isDark ? AppTheme.textDarkSecondary : textPrimary,
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, size: 20),
                    onPressed: _exportIndividualPdf,
                    color: isDark ? AppTheme.textDarkSecondary : textPrimary,
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () {},
                    color: Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // The Actual Bulletin Document
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.backgroundDark.withOpacity(0.5)
                  : AppTheme.backgroundLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderMain),
            ),
            child: Center(
              child: SingleChildScrollView(
                controller: _rightPanelScrollController,
                child: BulletinPreview(
                  zoomLevel: _zoomLevel,
                  trimestre: _trimestres[_selectedTrimestre].toUpperCase(),
                  annee: _anneeLibelle ?? 'N/A',
                  ecole: _ecole,
                  isAnnual: isAnnual,
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
                    'observations': _getFinalObservation(
                      (_bulletinStats['average'] as num?)?.toDouble() ?? 0.0,
                    ),
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _exportIndividualPdf() async {
    if (_selectedStudent == null ||
        _selectedClasse == null ||
        _anneeLibelle == null ||
        _isLoading) {
      return;
    }

    try {
      final isAnnual = _selectedTrimestre == 3;
      final pdf = isAnnual
          ? await BulletinPdfHelper.generateSingleAnnualBulletin(
              student: {
                ..._selectedStudent!,
                'classe_nom': _selectedClasse!['nom'],
              },
              grades: _grades,
              stats: _bulletinStats,
              ecole: _ecole,
              annee: _anneeLibelle!,
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
            );

      final fileName =
          'Bulletin_${isAnnual ? "Annuel" : "T${_selectedTrimestre + 1}"}_${_selectedStudent!['nom']}_${_selectedStudent!['prenom']}.pdf';

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
      final isAnnual = _selectedTrimestre == 3;
      final anneeId = await _dbHelper.ensureActiveAnneeCached();
      if (anneeId == null) throw Exception("Année scolaire non définie");

      List<Map<String, dynamic>> allData = [];
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
          allData.add({
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

          allData.add({
            'student': {...student, 'classe_nom': _selectedClasse!['nom']},
            'grades': _groupGradesBySubject(notes),
            'stats': stats,
          });
        }
      }

      final pdf = isAnnual
          ? await BulletinPdfHelper.generateBatchAnnualBulletins(
              studentsData: allData,
              ecole: _ecole,
              annee: _anneeLibelle!,
            )
          : await BulletinPdfHelper.generateBatchBulletins(
              studentsData: allData,
              ecole: _ecole,
              trimestre: _trimestres[_selectedTrimestre],
              annee: _anneeLibelle!,
            );

      final fileName =
          'Bulletins_${_selectedClasse!['nom']}_${isAnnual ? "Annuel" : "T${_selectedTrimestre + 1}"}.pdf';

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
    if (note >= 16) return 'Très Bien';
    if (note >= 14) return 'Bien';
    if (note >= 12) return 'Assez Bien';
    if (note >= 10) return 'Passable';
    return 'Insuffisant';
  }

  String _getFinalObservation(double average) {
    if (average >= 16) return 'Excellent travail, félicitations !';
    if (average >= 14) return 'Très bon travail, continuez ainsi.';
    if (average >= 12) return 'Bon travail, peut encore mieux faire.';
    if (average >= 10) return 'Résultats passables, redoublez d\'effort.';
    return 'Résultats insuffisants, doit travailler davantage.';
  }

  List<Map<String, dynamic>> _groupGradesBySubject(
    List<Map<String, dynamic>> rawNotes,
  ) {
    Map<String, Map<String, dynamic>> grouped = {};
    for (var n in rawNotes) {
      String mId = n['matiere_id']?.toString() ?? n['matiere_nom'];
      if (!grouped.containsKey(mId)) {
        grouped[mId] = {
          'matiere': n['matiere_nom'],
          'coeff': (n['coefficient'] as num?)?.toDouble() ?? 1.0,
          'control': null,
          'comp': null,
        };
      }

      double val = (n['note'] as num?)?.toDouble() ?? 0.0;
      int seq = n['sequence'] ?? 1;

      if (seq % 3 == 0) {
        grouped[mId]!['comp'] = val;
      } else {
        if (grouped[mId]!['control'] == null) {
          grouped[mId]!['control'] = val;
        } else {
          grouped[mId]!['control'] = (grouped[mId]!['control'] + val) / 2;
        }
      }
    }

    return grouped.values.map((g) {
      double? ctrl = g['control'] as double?;
      double? comp = g['comp'] as double?;
      double? avg;
      if (ctrl != null && comp != null) {
        avg = (ctrl + comp) / 2;
      } else {
        avg = ctrl ?? comp;
      }
      return {
        'matiere': g['matiere'],
        'coeff': g['coeff'],
        'note_ctrl': ctrl,
        'note_comp': comp,
        'note': avg,
        'total': (avg ?? 0) * (g['coeff'] as double),
        'obs': _getObservation(avg ?? 0.0),
      };
    }).toList();
  }
}
