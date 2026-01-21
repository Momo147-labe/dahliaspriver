import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../theme/app_theme.dart';
import '../../grades/grade_sheet_page.dart';
import '../../grades/grade_sheet_selection_modal.dart';
import '../../grades/result_sheet_selection_modal.dart';
import 'package:provider/provider.dart';
import '../../../providers/academic_year_provider.dart';

class GradesPage extends StatefulWidget {
  const GradesPage({super.key});

  @override
  State<GradesPage> createState() => _GradesPageState();
}

class _GradesPageState extends State<GradesPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  bool _isSaisieMode = false;
  bool _isLoading = true;
  int? _lastLoadedAnneeId;

  // Overview Data
  List<Map<String, dynamic>> _overviewGrades = [];

  // Entry Form Data
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _studentGrades = [];
  List<Map<String, dynamic>> _filteredGrades = [];
  Map<String, dynamic>? _selectedClass;
  Map<String, dynamic>? _selectedSubject;
  int _selectedTrimestre = 1;
  int _selectedSequence = 1;

  Map<String, dynamic>? _assignedTeacher;

  Map<String, dynamic> _stats = {
    'average': 0.0,
    'maxNote': 0.0,
    'minNote': 0.0,
    'successRate': 0.0,
    'total': 0,
    'ranges': {'0-5': 0, '5-10': 0, '10-15': 0, '15-20': 0},
  };
  final Map<int, TextEditingController> _controllers = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Data will be loaded in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final anneeId = context.watch<AcademicYearProvider>().selectedAnneeId;
    if (anneeId != null && anneeId != _lastLoadedAnneeId) {
      _lastLoadedAnneeId = anneeId;
      if (_isSaisieMode) {
        _loadSaisieData(anneeId);
      } else {
        _loadOverview(anneeId);
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOverview(int anneeId) async {
    try {
      final overview = await _dbHelper.getGradesOverview(anneeId);

      setState(() {
        _overviewGrades = overview;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erreur chargement aperçu: $e');
    }
  }

  Future<void> _loadSaisieData(int anneeId) async {
    setState(() => _isLoading = true);
    try {
      final db = await _dbHelper.database;
      final classes = await db.query('classe', orderBy: 'nom ASC');
      setState(() {
        _classes = classes;
        if (_classes.isNotEmpty && _selectedClass == null) {
          _selectedClass = _classes[0];
        }
      });

      await _loadSubjectsForSelectedClass(anneeId);

      if (_classes.isEmpty) {
        setState(() => _isLoading = false);
        _showError('Veuillez d\'abord ajouter des classes.');
        return;
      }

      await _loadGrades(anneeId);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erreur initialisation saisie: $e');
    }
  }

  Future<void> _loadSubjectsForSelectedClass(int anneeId) async {
    if (_selectedClass == null) return;
    try {
      final subjects = await _dbHelper.getSubjectsByClass(
        _selectedClass!['id'],
        anneeId,
      );
      setState(() {
        _subjects = subjects;
        if (_subjects.isNotEmpty) {
          // Keep current if still available, otherwise first
          if (_selectedSubject == null ||
              !_subjects.any((s) => s['id'] == _selectedSubject!['id'])) {
            _selectedSubject = _subjects[0];
          }
        } else {
          _selectedSubject = null;
        }
      });
    } catch (e) {
      debugPrint('Error loading subjects for class: $e');
    }
  }

  Future<void> _loadGrades(int anneeId) async {
    if (_selectedClass == null || _selectedSubject == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final grades = await _dbHelper.getGradesByClassSubject(
        _selectedClass!['id'],
        _selectedSubject!['id'],
        _selectedTrimestre,
        _selectedSequence,
        anneeId,
      );

      final stats = await _dbHelper.getGradesStats(
        _selectedClass!['id'],
        _selectedSubject!['id'],
        _selectedTrimestre,
        _selectedSequence,
        anneeId,
      );

      final teacher = await _dbHelper.getAssignedTeacher(
        _selectedClass!['id'],
        _selectedSubject!['id'],
        anneeId,
      );

      final Map<String, dynamic> finalStats = Map<String, dynamic>.from(stats);
      int r1 = 0, r2 = 0, r3 = 0, r4 = 0;
      for (var g in grades) {
        final note = (g['note'] as num?)?.toDouble() ?? -1.0;
        if (note >= 0 && note < 5)
          r1++;
        else if (note >= 5 && note < 10)
          r2++;
        else if (note >= 10 && note < 15)
          r3++;
        else if (note >= 15 && note < 20.00000001)
          r4++;
      }
      finalStats['ranges'] = {'0-5': r1, '5-10': r2, '10-15': r3, '15-20': r4};

      for (var controller in _controllers.values) controller.dispose();
      _controllers.clear();

      setState(() {
        _studentGrades = grades;
        _filteredGrades = grades;
        _stats = finalStats;
        _assignedTeacher = teacher;
        for (var g in grades) {
          final noteId = g['eleve_id'] as int;
          final noteValue = g['note']?.toString() ?? '';
          _controllers[noteId] = TextEditingController(text: noteValue);
        }
        _isLoading = false;
      });
      _filterGrades();
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erreur chargement notes: $e');
    }
  }

  void _filterGrades() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredGrades = _studentGrades.where((g) {
        final name = '${g['nom']} ${g['prenom']}'.toLowerCase();
        final matricule = g['matricule'].toString().toLowerCase();
        return name.contains(query) || matricule.contains(query);
      }).toList();
    });
  }

  Future<void> _saveAllGrades() async {
    setState(() => _isLoading = true);
    try {
      if (_lastLoadedAnneeId == null) {
        setState(() => _isLoading = false);
        return;
      }
      final anneeId = _lastLoadedAnneeId!;

      for (var entry in _controllers.entries) {
        final eleveId = entry.key;
        final value = entry.value.text;
        if (value.isNotEmpty) {
          final note = double.tryParse(value.replaceAll(',', '.'));
          if (note != null && note >= 0 && note <= 20) {
            await _dbHelper.saveGrade({
              'eleve_id': eleveId,
              'matiere_id': _selectedSubject!['id'],
              'trimestre': _selectedTrimestre,
              'sequence': _selectedSequence,
              'annee_scolaire_id': anneeId,
              'note': note,
              'coefficient': _selectedSubject!['coefficient'] ?? 1.0,
            });
          }
        }
      }
      _showSuccess('Toutes les notes ont été enregistrées');
      await _loadGrades(anneeId);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erreur sauvegarde: $e');
    }
  }

  String _getAppreciation(double note, String cycle) {
    if (note < 0) return '-';
    if (note < 5) return 'Très Faible';
    if (note < 10) return 'Insuffisant';
    if (note < 12) return 'Passable';
    if (note < 14) return 'Assez Bien';
    if (note < 16) return 'Bien';
    if (note < 18) return 'Très Bien';
    return 'Excellent';
  }

  void _showError(String msg) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSuccess(String msg) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.green),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.backgroundDark
          : AppTheme.backgroundLight,
      body: Column(
        children: [
          _buildTopBar(isDark),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isSaisieMode
                ? _buildSaisieView(isDark)
                : _buildOverviewView(isDark),
          ),
        ],
      ),
      floatingActionButton: _isSaisieMode
          ? FloatingActionButton.extended(
              onPressed: _saveAllGrades,
              backgroundColor: AppTheme.primaryColor,
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text(
                'Tout Enregistrer',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : FloatingActionButton.extended(
              onPressed: () {
                setState(() => _isSaisieMode = true);
                if (_lastLoadedAnneeId != null) {
                  _loadSaisieData(_lastLoadedAnneeId!);
                }
              },
              backgroundColor: AppTheme.primaryColor,
              icon: const Icon(Icons.add_task_rounded, color: Colors.white),
              label: const Text(
                'Saisir des Notes',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (_isSaisieMode)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: () {
                    setState(() => _isSaisieMode = false);
                    if (_lastLoadedAnneeId != null) {
                      _loadOverview(_lastLoadedAnneeId!);
                    }
                  },
                ),
              const SizedBox(width: 8),
              _buildHeaderIcon(),
              const SizedBox(width: 16),
              _buildHeaderText(isDark),
            ],
          ),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _showResultSheetSelectionModal,
                icon: const Icon(Icons.analytics_outlined, size: 20),
                label: const Text("Fiche de Résultat"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryColor,
                  elevation: 2,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _showGradeSheetSelectionModal,
                icon: const Icon(Icons.description_outlined, size: 20),
                label: const Text("Fiche de Notes"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: AppTheme.primaryColor.withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showGradeSheetSelectionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GradeSheetSelectionModal(dbHelper: _dbHelper),
    );
  }

  void _showResultSheetSelectionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ResultSheetSelectionModal(dbHelper: _dbHelper),
    );
  }

  Widget _buildHeaderIcon() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isSaisieMode
              ? [const Color(0xFF10B981), const Color(0xFF3B82F6)]
              : [const Color(0xFF6366F1), const Color(0xFFA855F7)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        _isSaisieMode ? Icons.edit_note_rounded : Icons.grade_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  Widget _buildHeaderText(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isSaisieMode ? 'Saisie des Notes' : 'Liste des Notes',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        if (_isSaisieMode)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.person_rounded,
                  size: 14,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  _assignedTeacher != null
                      ? 'Enseignant: ${_assignedTeacher!['prenom']} ${_assignedTeacher!['nom']}'
                      : 'Aucun enseignant assigné',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          )
        else
          Text(
            'Aperçu global des performances scolaires',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white60 : AppTheme.textSecondary,
            ),
          ),
      ],
    );
  }

  Widget _buildOverviewView(bool isDark) {
    if (_overviewGrades.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notes_rounded,
              size: 64,
              color: isDark ? Colors.white24 : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucune note enregistrée pour le moment',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _overviewGrades.length,
      itemBuilder: (context, index) {
        final g = _overviewGrades[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => _showGradesDetailModal(g, isDark),
            borderRadius: BorderRadius.circular(20),
            child: ListTile(
              contentPadding: const EdgeInsets.all(20),
              leading: _buildInitialCircle(g['classe_nom'][0], isDark),
              title: Row(
                children: [
                  Text(
                    g['classe_nom'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      g['matiere_nom'],
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_note_rounded,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'T${g['trimestre']} • S${g['sequence']} • ',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const Icon(
                      Icons.people_outline_rounded,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${g['count']} notes saisies',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Moyenne',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    (g['average'] as num).toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: (g['average'] as num) >= 10
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showGradesDetailModal(Map<String, dynamic> overviewData, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GradesDetailModal(
        overviewData: overviewData,
        dbHelper: _dbHelper,
        isDark: isDark,
        onSaved: () {
          if (_lastLoadedAnneeId != null) {
            _loadOverview(_lastLoadedAnneeId!);
          }
        },
      ),
    );
  }

  Widget _buildSaisieView(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildSaisieFilters(isDark),
          const SizedBox(height: 32),
          _buildStatsGrid(isDark),
          const SizedBox(height: 24),
          _buildDistributionCards(isDark),
          const SizedBox(height: 32),
          _buildGradesTable(isDark),
        ],
      ),
    );
  }

  Widget _buildSaisieFilters(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 20,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          _buildDropdown(
            'Classe',
            _selectedClass?['id'],
            _classes,
            (v) {
              setState(
                () => _selectedClass = _classes.firstWhere((c) => c['id'] == v),
              );
              if (_lastLoadedAnneeId != null) {
                _loadSubjectsForSelectedClass(
                  _lastLoadedAnneeId!,
                ).then((_) => _loadGrades(_lastLoadedAnneeId!));
              }
            },
            isDark,
            200,
          ),
          _buildDropdown(
            'Matière',
            _selectedSubject?['id'],
            _subjects,
            (v) {
              setState(
                () => _selectedSubject = _subjects.firstWhere(
                  (s) => s['id'] == v,
                ),
              );
              if (_lastLoadedAnneeId != null) {
                _loadGrades(_lastLoadedAnneeId!);
              }
            },
            isDark,
            200,
          ),
          if (_selectedSubject != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Coeff.',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardDark : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_selectedSubject!['coefficient'] ?? 1.0}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          _buildOptionToggle(
            'Trimestre',
            _selectedTrimestre,
            [1, 2, 3],
            (v) {
              setState(() => _selectedTrimestre = v);
              if (_lastLoadedAnneeId != null) {
                _loadGrades(_lastLoadedAnneeId!);
              }
            },
            isDark,
            'T',
          ),
          _buildOptionToggle(
            'Séquence',
            _selectedSequence,
            [1, 2, 3, 4, 5, 6],
            (v) {
              setState(() => _selectedSequence = v);
              if (_lastLoadedAnneeId != null) {
                _loadGrades(_lastLoadedAnneeId!);
              }
            },
            isDark,
            'S',
          ),
          if (_selectedClass != null && _selectedSubject != null)
            ElevatedButton.icon(
              onPressed: () async {
                if (_lastLoadedAnneeId != null && mounted) {
                  final anneeId = _lastLoadedAnneeId!;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GradeSheetPage(
                        classeId: _selectedClass!['id'],
                        subjectId: _selectedSubject!['id'],
                        trimestre: _selectedTrimestre,
                        sequence: _selectedSequence,
                        anneeId: anneeId,
                        className: _selectedClass!['nom'],
                        subjectName: _selectedSubject!['nom'],
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.description, size: 18),
              label: const Text("Fiche de Notes"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13daec),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    dynamic value,
    List items,
    Function(dynamic) onChanged,
    bool isDark,
    double width,
  ) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: value,
            items: items
                .map(
                  (c) => DropdownMenuItem<int>(
                    value: c['id'],
                    child: Text(c['nom']),
                  ),
                )
                .toList(),
            onChanged: onChanged,
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? AppTheme.cardDark : const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionToggle(
    String label,
    int selectedValue,
    List<int> options,
    Function(int) onTap,
    bool isDark,
    String prefix,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: options.map((opt) {
              final isSelected = selectedValue == opt;
              return InkWell(
                onTap: () => onTap(opt),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$prefix$opt',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black54),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      childAspectRatio: 2.2,
      children: [
        _buildStatCard(
          'Moyenne de Classe',
          _stats['average'].toStringAsFixed(2),
          Icons.analytics_rounded,
          const Color(0xFF3B82F6),
          isDark,
        ),
        _buildStatCard(
          'Plus Haute Note',
          _stats['maxNote'].toStringAsFixed(1),
          Icons.trending_up_rounded,
          const Color(0xFF10B981),
          isDark,
        ),
        _buildStatCard(
          'Plus Basse Note',
          _stats['minNote'].toStringAsFixed(1),
          Icons.trending_down_rounded,
          const Color(0xFFEF4444),
          isDark,
        ),
        _buildStatCard(
          'Taux de Réussite',
          '${_stats['successRate'].toStringAsFixed(1)}%',
          Icons.pie_chart_rounded,
          const Color(0xFFF59E0B),
          isDark,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionCards(bool isDark) {
    final total = (_stats['total'] ?? 0) as int;
    final ranges =
        (_stats['ranges'] ?? {'0-5': 0, '5-10': 0, '10-15': 0, '15-20': 0})
            as Map<String, int>;
    return Row(
      children: [
        Expanded(
          child: _buildDistributionCard(
            'Répartition des Performances',
            [
              _buildDistributionItem(
                'Excellent (15-20)',
                ranges['15-20'] ?? 0,
                total,
                Colors.green,
              ),
              const SizedBox(height: 12),
              _buildDistributionItem(
                'Bien/Moyen (10-15)',
                ranges['10-15'] ?? 0,
                total,
                Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildDistributionItem(
                'Faible (5-10)',
                ranges['5-10'] ?? 0,
                total,
                Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildDistributionItem(
                'Trés Faible (0-5)',
                ranges['0-5'] ?? 0,
                total,
                Colors.red,
              ),
            ],
            isDark,
            Icons.bar_chart_rounded,
            AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDistributionCard(
    String title,
    List<Widget> children,
    bool isDark,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDistributionItem(
    String label,
    int value,
    int total,
    Color color,
  ) {
    final percentage = total > 0 ? (value / total) : 0.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            Text(
              '$value élèves (${(percentage * 100).toStringAsFixed(1)}%)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildGradesTable(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => _filterGrades(),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un élève...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: isDark
                          ? AppTheme.cardDark
                          : const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${_filteredGrades.length} élèves',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white60 : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 500,
            child: ListView.separated(
              itemCount: _filteredGrades.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final student = _filteredGrades[index];
                final eleveId = student['eleve_id'] as int;
                final controller = _controllers[eleveId];
                final note = double.tryParse(controller?.text ?? '') ?? -1.0;
                final appreciation = _getAppreciation(note, '');

                return ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: _buildStudentAvatar(
                    student['photo'],
                    student['nom'][0],
                  ),
                  title: Row(
                    children: [
                      Text(
                        '${student['nom']} ${student['prenom']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (note >= 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (note >= 10 ? Colors.green : Colors.red)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            appreciation,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: note >= 10 ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text('Matricule: ${student['matricule']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectedSubject != null && note >= 0)
                        Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'TOTAL',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                (note *
                                        (_selectedSubject!['coefficient'] ??
                                            1.0))
                                    .toStringAsFixed(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primaryColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: controller,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.center,
                          onChanged: (v) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: '-',
                            filled: true,
                            fillColor: isDark
                                ? AppTheme.cardDark
                                : const Color(0xFFF3F4F6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentAvatar(String? photoPath, String initial) {
    if (photoPath != null && photoPath.isNotEmpty) {
      if (File(photoPath).existsSync()) {
        return CircleAvatar(backgroundImage: FileImage(File(photoPath)));
      }
    }
    return CircleAvatar(
      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
      child: Text(
        initial.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInitialCircle(String initial, bool isDark) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.6),
          ],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}

class _GradesDetailModal extends StatefulWidget {
  final Map<String, dynamic> overviewData;
  final DatabaseHelper dbHelper;
  final bool isDark;
  final VoidCallback onSaved;

  const _GradesDetailModal({
    required this.overviewData,
    required this.dbHelper,
    required this.isDark,
    required this.onSaved,
  });

  @override
  State<_GradesDetailModal> createState() => _GradesDetailModalState();
}

class _GradesDetailModalState extends State<_GradesDetailModal> {
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  bool _isLoading = true;
  final Map<int, TextEditingController> _controllers = {};
  Map<String, dynamic>? _assignedTeacher;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (var c in _controllers.values) c.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final activeAnnee = await widget.dbHelper.getActiveAnneeScolaire();
      int anneeId = activeAnnee?['id'] ?? 1;

      final grades = await widget.dbHelper.getGradesByClassSubject(
        widget.overviewData['classe_id'] as int,
        widget.overviewData['matiere_id'] as int,
        widget.overviewData['trimestre'] as int,
        widget.overviewData['sequence'] as int,
        anneeId,
      );

      final teacher = await widget.dbHelper.getAssignedTeacher(
        widget.overviewData['classe_id'] as int,
        widget.overviewData['matiere_id'] as int,
        anneeId,
      );

      setState(() {
        _students = grades;
        _filteredStudents = grades;
        _assignedTeacher = teacher;
        for (var g in grades) {
          _controllers[g['eleve_id']] = TextEditingController(
            text: g['note']?.toString() ?? '',
          );
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
        Navigator.pop(context);
      }
    }
  }

  void _filter(String query) {
    setState(() {
      _filteredStudents = _students.where((s) {
        final name = '${s['nom']} ${s['prenom']}'.toLowerCase();
        return name.contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final activeAnnee = await widget.dbHelper.getActiveAnneeScolaire();
      int anneeId = activeAnnee?['id'] ?? 1;

      for (var entry in _controllers.entries) {
        final val = entry.value.text;
        if (val.isNotEmpty) {
          final note = double.tryParse(val.replaceAll(',', '.'));
          if (note != null && note >= 0 && note <= 20) {
            await widget.dbHelper.saveGrade({
              'eleve_id': entry.key,
              'matiere_id': widget.overviewData['matiere_id'],
              'trimestre': widget.overviewData['trimestre'],
              'sequence': widget.overviewData['sequence'],
              'annee_scolaire_id': anneeId,
              'note': note,
              'coefficient': widget.overviewData['coefficient'] ?? 1.0,
            });
          }
        }
      }
      widget.onSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notes mises à jour'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur sauvegarde: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: widget.isDark
            ? AppTheme.backgroundDark
            : AppTheme.backgroundLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildList(),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Détails des Notes',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            '${widget.overviewData['classe_nom']} • ${widget.overviewData['matiere_nom']} • T${widget.overviewData['trimestre']} S${widget.overviewData['sequence']}',
            style: TextStyle(
              color: widget.isDark ? Colors.white60 : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final activeAnnee = await widget.dbHelper
                  .getActiveAnneeScolaire();
              final anneeId = activeAnnee?['id'];
              if (anneeId != null && mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GradeSheetPage(
                      classeId: widget.overviewData['classe_id'],
                      subjectId: widget.overviewData['matiere_id'],
                      trimestre: widget.overviewData['trimestre'],
                      sequence: widget.overviewData['sequence'],
                      anneeId: anneeId,
                      className: widget.overviewData['classe_nom'],
                      subjectName: widget.overviewData['matiere_nom'],
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.description, size: 16),
            label: const Text("Fiche de Notes"),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          if (_assignedTeacher != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Enseignant: ${_assignedTeacher!['prenom']} ${_assignedTeacher!['nom']}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: _filter,
            decoration: InputDecoration(
              hintText: 'Rechercher un élève...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: widget.isDark ? AppTheme.cardDark : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _filteredStudents.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final s = _filteredStudents[index];
        final ctrl = _controllers[s['eleve_id']];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              _buildAvatar(s['photo'], s['nom'][0]),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s['nom']} ${s['prenom']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      s['matricule'],
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Builder(
                    builder: (context) {
                      final noteText = ctrl?.text ?? '';
                      final noteValue = double.tryParse(noteText) ?? -1.0;
                      final coeff = widget.overviewData['coefficient'] ?? 1.0;
                      if (noteValue >= 0) {
                        return Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            (noteValue * coeff).toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  SizedBox(
                    width: 70,
                    child: TextField(
                      controller: ctrl,
                      textAlign: TextAlign.center,
                      onChanged: (v) => setState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        hintText: '-',
                        filled: true,
                        fillColor: widget.isDark
                            ? AppTheme.cardDark
                            : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatar(String? photo, String initial) {
    if (photo != null && photo.isNotEmpty && File(photo).existsSync()) {
      return CircleAvatar(radius: 20, backgroundImage: FileImage(File(photo)));
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
      child: Text(
        initial.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: widget.isDark ? AppTheme.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Enregistrer les modifications',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
