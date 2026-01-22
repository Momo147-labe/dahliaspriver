import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../core/database/database_helper.dart';
import '../../../widgets/reports/bulletin_preview.dart';
import '../../../widgets/reports/bulletin_pdf_helper.dart';
import '../../../models/ecole.dart';
import '../../grades/result_sheet_selection_modal.dart';

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
    final students = await _dbHelper.getStudentsByClasse(classId);
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

      if (mounted) {
        setState(() {
          _grades = List<Map<String, dynamic>>.from(notes);
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Couleurs du design HTML
    const primaryColor = Color(0xFF13DAEC);
    const backgroundLight = Color(0xFFF6F8F8);
    const backgroundDark = Color(0xFF102022);
    const surfaceDark = Color(0xFF1A2B2D);
    const borderLight = Color(0xFFDBE5E6);
    const borderDark = Color(0xFF2A3A3C);
    const textPrimary = Color(0xFF111718);
    const textSecondary = Color(0xFF618689);
    const textSecondaryDark = Color(0xFFA1B6B8);
    const surfaceSecondary = Color(0xFFF0F4F4);
    const surfaceSecondaryDark = Color(0xFF243537);

    return Container(
      color: isDark ? backgroundDark : backgroundLight,
      child: Column(
        children: [
          // Fixed Header Section
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTitleSection(
                  isDark,
                  primaryColor,
                  textPrimary,
                  textSecondary,
                  textSecondaryDark,
                  borderLight,
                  borderDark,
                  surfaceDark,
                ),
                const SizedBox(height: 24),

                // Academic Term Tabs
                _buildTrimestreTabs(
                  isDark,
                  primaryColor,
                  textPrimary,
                  textSecondary,
                  textSecondaryDark,
                  borderLight,
                  borderDark,
                ),
              ],
            ),
          ),

          // Scrollable Main Content
          Expanded(
            child: _isLoading && _classes.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Panel: Classes & Students
                        Flexible(
                          flex: 4,
                          child: _buildLeftPanel(
                            isDark,
                            primaryColor,
                            textPrimary,
                            textSecondary,
                            textSecondaryDark,
                            borderLight,
                            borderDark,
                            surfaceDark,
                            surfaceSecondary,
                            surfaceSecondaryDark,
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Right Panel: Preview
                        Flexible(
                          flex: 8,
                          child: _selectedStudent == null
                              ? Center(child: Text('Aucun élève sélectionné'))
                              : _buildRightPanel(
                                  isDark,
                                  primaryColor,
                                  textPrimary,
                                  textSecondary,
                                  borderLight,
                                  borderDark,
                                  surfaceDark,
                                  surfaceSecondary,
                                  surfaceSecondaryDark,
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
    Color textSecondaryDark,
    Color borderLight,
    Color borderDark,
    Color surfaceDark,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Si l'écran est large, utiliser Row, sinon Column
        if (constraints.maxWidth > 800) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
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
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            Text(
                              'Générez et visualisez les bulletins scolaires',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? textSecondaryDark
                                    : textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                flex: 1,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? surfaceDark : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              isDark ? 0.3 : 0.05,
                            ),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(
                          color: isDark ? borderDark : borderLight,
                          width: 1,
                        ),
                      ),
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Exportation CSV en cours...'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.file_download, size: 18),
                        label: const Text('Exporter CSV'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: isDark ? Colors.white : textPrimary,
                          side: BorderSide.none,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _showResultSheetModal,
                      icon: const Icon(Icons.analytics_outlined, size: 18),
                      label: const Text('Rapport de Classe'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: primaryColor,
                        side: BorderSide(color: primaryColor),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
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
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ],
                ),
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
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? textSecondaryDark : textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.file_download, size: 18),
                    label: const Text('Exporter CSV'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isDark ? surfaceDark : Colors.white,
                      foregroundColor: isDark ? Colors.white : textPrimary,
                      side: BorderSide(
                        color: isDark ? borderDark : borderLight,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _exportBatchPdf,
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('Générer Tous (PDF)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: textPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
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
    Color textSecondaryDark,
    Color borderLight,
    Color borderDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: isDark ? borderDark : borderLight),
        ),
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
                  _loadBulletinData();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isSelected ? primaryColor : Colors.transparent,
                        width: 3,
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
                            : (isDark ? textSecondaryDark : textSecondary),
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
    Color textSecondaryDark,
    Color borderLight,
    Color borderDark,
    Color surfaceDark,
    Color surfaceSecondary,
    Color surfaceSecondaryDark,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Class Selection Grid
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? borderDark : borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.groups, color: primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Classes Disponibles',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? Colors.white : textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: _classes.length,
                  itemBuilder: (context, index) {
                    final classe = _classes[index];
                    final isSelected = _selectedClasse?['id'] == classe['id'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () {
                          setState(() => _selectedClasse = classe);
                          _loadStudentsForClass(classe['id']);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryColor.withOpacity(0.08)
                                : (isDark
                                      ? surfaceSecondaryDark
                                      : surfaceSecondary),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? primaryColor
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? primaryColor
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.class_outlined,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                            ? Colors.white70
                                            : textSecondary),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      classe['nom'] as String,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: isSelected
                                            ? primaryColor
                                            : (isDark
                                                  ? Colors.white
                                                  : textPrimary),
                                      ),
                                    ),
                                    Text(
                                      '${classe['student_count'] ?? 0} Élèves',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? textSecondaryDark
                                            : textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: primaryColor,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Student List
        SizedBox(
          height: 500, // Hauteur fixe pour éviter le problème avec Expanded
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? borderDark : borderLight),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? borderDark : borderLight,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Liste des Élèves (${_selectedClasse?['nom'] ?? ""})',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isDark ? Colors.white : textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'COMPLET',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.green.shade700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _students.length,
                    itemBuilder: (context, index) {
                      final student = _students[index];
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
                          padding: const EdgeInsets.all(16),
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
                              bottom: BorderSide(
                                color: isDark ? borderDark : borderLight,
                                width: index < _students.length - 1 ? 1 : 0,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? primaryColor.withOpacity(0.2)
                                          : (isDark
                                                ? surfaceSecondaryDark
                                                : surfaceSecondary),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        initiales.toUpperCase(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? primaryColor
                                              : (isDark
                                                    ? Colors.white70
                                                    : textPrimary),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${student['nom']} ${student['prenom']}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: isDark
                                              ? Colors.white
                                              : textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Matricule: ${student['matricule']}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? textSecondaryDark
                                              : textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Icon(
                                isSelected
                                    ? Icons.visibility
                                    : Icons.description,
                                color: isSelected
                                    ? primaryColor
                                    : (isDark
                                          ? textSecondaryDark
                                          : textSecondary),
                                size: 20,
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
    Color borderLight,
    Color borderDark,
    Color surfaceDark,
    Color surfaceSecondary,
    Color surfaceSecondaryDark,
  ) {
    bool isAnnual = _selectedTrimestre == 3;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Preview ToolBar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? borderDark : borderLight),
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
                      color: isDark ? surfaceSecondaryDark : surfaceSecondary,
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
                    color: isDark ? Colors.white70 : textPrimary,
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, size: 20),
                    onPressed: _exportIndividualPdf,
                    color: isDark ? Colors.white70 : textPrimary,
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
        SizedBox(
          height: 900,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0C1A1C) : const Color(0xFFE2E8E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: SingleChildScrollView(
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
                  grades: isAnnual
                      ? _grades // Already in correct format for annual
                      : _grades.map((n) {
                          final double note =
                              (n['note'] as num?)?.toDouble() ?? 0.0;
                          final double coeff =
                              (n['coefficient'] as num?)?.toDouble() ?? 1.0;
                          return {
                            'matiere': n['matiere_nom'],
                            'coeff': coeff,
                            'note': note,
                            'total': note * coeff,
                            'obs': _getObservation(note),
                          };
                        }).toList(),
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
              grades: _grades
                  .map(
                    (n) => {
                      'matiere_nom': n['matiere_nom'],
                      // Note mapping is different for BulletinPdfHelper._buildGradesTable
                      // It expects 'note' and 'coefficient'
                      'note': n['note'],
                      'coefficient': n['coefficient'],
                    },
                  )
                  .toList(),
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
            'grades': notes
                .map(
                  (n) => {
                    'matiere_nom': n['matiere_nom'],
                    'note': n['note'],
                    'coefficient': n['coefficient'],
                  },
                )
                .toList(),
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
}
