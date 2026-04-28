import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../theme/app_theme.dart';
import '../../grades/result_sheet_selection_modal.dart';
import '../../grades/grade_sheet_selection_modal.dart';
import 'global_ranking_page.dart';
import 'package:provider/provider.dart';
import '../../../providers/academic_year_provider.dart';
import '../../../../widgets/grades/grade_import_modal.dart';

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

  // Dynamic Configuration
  List<Map<String, dynamic>> _sequences = [];
  List<int> _trimesters = [];

  int _selectedTrimestre = 1;
  int _selectedSequence = 1;

  double _currentCycleMin = 0.0;
  double _currentCycleMax = 20.0;
  double _currentCyclePassage = 10.0;

  Map<String, dynamic>? _assignedTeacher;

  Map<String, dynamic> _stats = {
    'average': 0.0,
    'maxNote': 0.0,
    'minNote': 0.0,
    'successRate': 0.0,
    'total': 0,
    'ranges': {'0-5': 0, '5-10': 0, '10-15': 0, '15-20': 0},
  };
  final Map<String, TextEditingController> _controllers = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Data will be loaded in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<AcademicYearProvider>(context);
    final anneeId = provider.selectedAnneeId;

    if (anneeId != null && anneeId != _lastLoadedAnneeId) {
      _lastLoadedAnneeId = anneeId;

      // Reset state on year change
      setState(() {
        _isLoading = true;
        _overviewGrades = [];
        _studentGrades = [];
        _filteredGrades = [];
        _controllers.clear();
        _selectedClass = null;
        _selectedSubject = null;
        _stats = {
          'average': 0.0,
          'maxNote': 0.0,
          'minNote': 0.0,
          'successRate': 0.0,
          'total': 0,
        };
      });

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
      await _loadConfig(anneeId);

      final overviewRows = await _dbHelper.getGradesOverview(anneeId);
      final Map<String, Map<String, dynamic>> grouped = {};

      for (var row in overviewRows) {
        final key =
            '${row['classe_id']}_${row['matiere_id']}_${row['trimestre']}';
        if (!grouped.containsKey(key)) {
          grouped[key] = {
            'classe_id': row['classe_id'],
            'classe_nom': row['classe_nom'],
            'matiere_id': row['matiere_id'],
            'matiere_nom': row['matiere_nom'],
            'trimestre': row['trimestre'],
            'coefficient': row['coefficient'] ?? 1.0,
            'count': 0,
            'sequences': <int, double>{},
          };
        }

        final seqNum = row['sequence'] as int?;
        if (seqNum != null) {
          grouped[key]!['sequences'][seqNum] = (row['average'] as num)
              .toDouble();
        }

        final currentCount = grouped[key]!['count'] as int;
        final count = row['count'] as int? ?? 0;
        if (count > currentCount) {
          grouped[key]!['count'] = count;
        }
      }

      for (var g in grouped.values) {
        final seqs = g['sequences'] as Map<int, double>;
        if (seqs.isNotEmpty) {
          g['average'] = seqs.values.reduce((a, b) => a + b) / seqs.length;
        } else {
          g['average'] = 0.0;
        }
      }

      setState(() {
        _overviewGrades = grouped.values.toList();
        // Tri par trimestre (décroissant) et nom de classe (croissant)
        _overviewGrades.sort((a, b) {
          int tComp = (b['trimestre'] as int).compareTo(a['trimestre'] as int);
          if (tComp != 0) return tComp;
          return (a['classe_nom'] as String).compareTo(b['classe_nom'] as String);
        });
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erreur chargement aperçu: $e');
    }
  }

  Future<void> _loadClasses() async {
    final db = await _dbHelper.database;
    final classes = await db.rawQuery('''
      SELECT c.*, cy.nom as cycle_nom, cy.note_min, cy.note_max, cy.moyenne_passage
      FROM classe c
      LEFT JOIN cycles_scolaires cy ON c.cycle_id = cy.id
      ORDER BY c.nom ASC
    ''');
    setState(() {
      _classes = classes;
    });
  }

  Future<void> _loadSaisieData(int anneeId) async {
    setState(() => _isLoading = true);
    try {
      // 1. Charger la configuration
      await _loadConfig(anneeId);

      // 2. Charger les classes
      await _loadClasses();

      // 3. Sélection par défaut si vide
      if (_classes.isNotEmpty && _selectedClass == null) {
        setState(() {
          _selectedClass = _classes[0];
          _updateCycleConfig();
        });
      }

      if (_classes.isNotEmpty) {
        await _loadSubjectsForSelectedClass();
      } else {
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

  Future<void> _loadConfig(int anneeId) async {
    final seqs = await _dbHelper.getSequences(anneeId);
    final trim = await _dbHelper.getTrimesters(anneeId);

    setState(() {
      _sequences = seqs;
      _trimesters = trim;

      // Set default selections if available
      if (!_trimesters.contains(_selectedTrimestre)) {
        _selectedTrimestre = _trimesters.isNotEmpty ? _trimesters.first : 1;
      }

      // Check if current selected sequence exists in the new list
      bool seqExists = _sequences.any(
        (s) =>
            s['numero_sequence'] == _selectedSequence &&
            s['trimestre'] == _selectedTrimestre,
      );
      if (!seqExists) {
        final trimesterSeqs = _sequences
            .where((s) => s['trimestre'] == _selectedTrimestre)
            .toList();
        _selectedSequence = trimesterSeqs.isNotEmpty
            ? (trimesterSeqs.first['numero_sequence'] as int)
            : 1;
      }
    });
  }

  void _updateCycleConfig() {
    if (_selectedClass == null) return;
    setState(() {
      _currentCycleMin =
          (_selectedClass!['note_min'] as num?)?.toDouble() ?? 0.0;
      _currentCycleMax =
          (_selectedClass!['note_max'] as num?)?.toDouble() ?? 20.0;
      _currentCyclePassage =
          (_selectedClass!['moyenne_passage'] as num?)?.toDouble() ?? 10.0;
    });
  }

  Future<void> _loadSubjectsForSelectedClass() async {
    if (_selectedClass == null) return;
    try {
      final subjects = await _dbHelper.getSubjectsByClass(
        _selectedClass!['id'],
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
      final grades = await _dbHelper.getTrimesterGradesByClassSubject(
        _selectedClass!['id'],
        _selectedSubject!['id'],
        _selectedTrimestre,
        anneeId,
      );

      // Fetch aggregated statistics for the entire trimester
      final stats = await _dbHelper.getTrimesterGradesStats(
        _selectedClass!['id'],
        _selectedSubject!['id'],
        _selectedTrimestre,
        anneeId,
        passingGrade: _currentCyclePassage,
      );

      final teacher = await _dbHelper.getAssignedTeacher(
        _selectedClass!['id'],
        _selectedSubject!['id'],
      );

      final Map<String, dynamic> finalStats = Map<String, dynamic>.from(stats);

      // Group grades by student
      Map<int, Map<String, dynamic>> studentMap = {};
      for (var row in grades) {
        int eleveId = row['eleve_id'] as int;
        if (!studentMap.containsKey(eleveId)) {
          studentMap[eleveId] = {
            'eleve_id': eleveId,
            'nom': row['nom'],
            'prenom': row['prenom'],
            'matricule': row['matricule'],
            'photo': row['photo'],
            'coefficient': row['coefficient'],
            'notes': <int, dynamic>{}, // sequence -> note
          };
        }
        if (row['sequence'] != null) {
          studentMap[eleveId]!['notes'][row['sequence']] = row['note'];
        }
      }

      final groupedGrades = studentMap.values.toList();

      for (var controller in _controllers.values) controller.dispose();
      _controllers.clear();

      // Get sequences for this trimester to initialize controllers
      final currentTrimesterSeqs = _sequences
          .where((s) => s['trimestre'] == _selectedTrimestre)
          .map((s) => s['numero_sequence'] as int)
          .toList();

      setState(() {
        _studentGrades = groupedGrades;
        _filteredGrades = groupedGrades;
        _stats = finalStats;
        _assignedTeacher = teacher;

        for (var student in groupedGrades) {
          final eleveId = student['eleve_id'] as int;
          for (var seqNum in currentTrimesterSeqs) {
            final key = '${eleveId}_$seqNum';
            final noteValue = student['notes'][seqNum]?.toString() ?? '';
            _controllers[key] = TextEditingController(text: noteValue);
          }
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
        final keyParts = entry.key.split('_');
        if (keyParts.length != 2) continue;

        final eleveId = int.parse(keyParts[0]);
        final sequenceNum = int.parse(keyParts[1]);
        final value = entry.value.text;

        if (value.isNotEmpty) {
          final note = double.tryParse(value.replaceAll(',', '.'));
          if (note != null &&
              note >= _currentCycleMin &&
              note <= _currentCycleMax) {
            await _dbHelper.saveGrade({
              'eleve_id': eleveId,
              'matiere_id': _selectedSubject!['id'],
              'trimestre': _selectedTrimestre,
              'sequence': sequenceNum,
              'annee_scolaire_id': anneeId,
              'note': note,
              'coefficient': _selectedSubject!['coefficient'] ?? 1.0,
            });
          } else if (note != null) {
            _showError(
              'Note invalide pour l\'élève ID $eleveId, Séquence $sequenceNum (doit être entre $_currentCycleMin et $_currentCycleMax)',
            );
            setState(() => _isLoading = false);
            return;
          }
        } else {
          // If the field was cleared, delete the existing note (if any)
          await _dbHelper.deleteGrade(
            eleveId: eleveId,
            matiereId: _selectedSubject!['id'],
            trimestre: _selectedTrimestre,
            sequence: sequenceNum,
            anneeId: anneeId,
          );
        }
      }
      _showSuccess('Toutes les notes ont été enregistrées');
      await _loadGrades(anneeId);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erreur sauvegarde: $e');
    }
  }

  Future<void> _deleteSequenceGrades(Map<String, dynamic> item, int sequence) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation de suppression'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Text(
          'Voulez-vous vraiment supprimer toutes les notes de ${item['matiere_nom']} '
          'pour la séquence $sequence du trimestre ${item['trimestre']} '
          'dans la classe ${item['classe_nom']} ?\n\n'
          'Cette action est irréversible et recalculera les rangs de la classe.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Supprimer tout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _dbHelper.deleteAllGradesForSubjectSequence(
          classeId: item['classe_id'],
          matiereId: item['matiere_id'],
          trimestre: item['trimestre'],
          sequence: sequence,
          anneeId: _lastLoadedAnneeId!,
        );
        _showSuccess('Notes supprimées avec succès');
        await _loadOverview(_lastLoadedAnneeId!);
      } catch (e) {
        setState(() => _isLoading = false);
        _showError('Erreur lors de la suppression: $e');
      }
    }
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
          Expanded(
            child: Row(
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
          ),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GlobalRankingPage(isDark: isDark),
                    ),
                  );
                },
                icon: const Icon(Icons.military_tech_rounded, size: 20),
                label: const Text("Vue Globale"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  foregroundColor: AppTheme.primaryColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                  shadowColor: AppTheme.primaryColor.withValues(alpha: 0.4),
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
              if (_isSaisieMode) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _showImportModal,
                  icon: const Icon(Icons.file_upload_outlined, size: 20),
                  label: const Text("Importer Notes"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    foregroundColor: Colors.blue,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showImportModal() {
    if (_lastLoadedAnneeId == null ||
        _selectedClass == null ||
        _selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Veuillez sélectionner une classe et une matière avant d'importer",
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GradeImportModal(
        classId: _selectedClass!['id'],
        subjectId: _selectedSubject!['id'],
        trimester: _selectedTrimestre,
        sequence: _selectedSequence,
        anneeId: _lastLoadedAnneeId!,
        onSuccess: () => _loadGrades(_lastLoadedAnneeId!),
      ),
    );
  }

  void _showGradeSheetSelectionModal() {
    final anneeId = Provider.of<AcademicYearProvider>(
      context,
      listen: false,
    ).selectedAnneeId;
    if (anneeId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          GradeSheetSelectionModal(dbHelper: _dbHelper, anneeId: anneeId),
    );
  }

  void _showResultSheetSelectionModal() {
    final anneeId = Provider.of<AcademicYearProvider>(
      context,
      listen: false,
    ).selectedAnneeId;
    if (anneeId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          ResultSheetSelectionModal(dbHelper: _dbHelper, anneeId: anneeId),
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
            color: Colors.indigo.withValues(alpha: 0.2),
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
    return Expanded(
      child: Column(
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (_isSaisieMode)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
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
                  Flexible(
                    child: Text(
                      _assignedTeacher != null
                          ? 'Enseignant: ${_assignedTeacher!['prenom']} ${_assignedTeacher!['nom']}'
                          : 'Aucun enseignant assigné',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
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
      ),
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
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      itemCount: _overviewGrades.length,
      itemBuilder: (context, index) {
        final g = _overviewGrades[index];

        // Logic to show Trimester header
        bool showTrimHeader = false;
        if (index == 0 ||
            _overviewGrades[index - 1]['trimestre'] != g['trimestre']) {
          showTrimHeader = true;
        }

        // Logic to show Class header (secondary grouping)
        bool showClassHeader = false;
        if (index == 0 ||
            _overviewGrades[index - 1]['classe_id'] != g['classe_id'] ||
            showTrimHeader) {
          showClassHeader = true;
        }

        final currentClass = _classes.firstWhere(
          (c) => c['id'] == g['classe_id'],
          orElse: () => {'note_max': 20.0, 'moyenne_passage': 10.0},
        );
        final noteMax = (currentClass['note_max'] as num?)?.toDouble() ?? 20.0;
        final passingGrade = (currentClass['moyenne_passage'] as num?)?.toDouble() ?? (noteMax / 2);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTrimHeader) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.primaryColor.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      'TRIMESTRE ${g['trimestre']}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Divider(indent: 16, thickness: 1.5),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (showClassHeader) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.class_outlined,
                        size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Classe: ${g['classe_nom']}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white70 : Colors.blueGrey[800],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => _openTrimesterDetail(g),
            borderRadius: BorderRadius.circular(20),
            child: ListTile(
              contentPadding: const EdgeInsets.all(20),
              leading: _buildInitialCircle(
                g['classe_nom'] != null && g['classe_nom'].toString().isNotEmpty
                    ? g['classe_nom'].toString().runes.first.toString()
                    : '?',
                isDark,
              ),
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
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
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
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Coef ${g['coefficient']}',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.event_note_rounded,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'T${g['trimestre']} • ',
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
                    const SizedBox(height: 8),
                    if ((g['sequences'] as Map<int, double>).isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: (g['sequences'] as Map<int, double>).entries
                            .map((e) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.05,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.primaryColor.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                                child: Builder(
                                    builder: (context) {
                                      final seqName = _sequences.firstWhere(
                                        (s) =>
                                            s['numero_sequence'] == e.key &&
                                            s['trimestre'] == g['trimestre'],
                                        orElse: () => {'nom': 'Seq ${e.key}'},
                                      )['nom'];
                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '$seqName: ${e.value.toStringAsFixed(1)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          GestureDetector(
                                            onTap: () => _deleteSequenceGrades(
                                                g, e.key),
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: Colors.red
                                                    .withValues(alpha: 0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close_rounded,
                                                size: 12,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                              );
                            })
                            .toList(),
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
                      color: (g['average'] as num) >= passingGrade
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openTrimesterDetail(Map<String, dynamic> overviewData) async {
    setState(() => _isLoading = true);

    try {
      // 1. S'assurer que les classes et la config sont chargées
      if (_classes.isEmpty) {
        await _loadClasses();
      }
      await _loadConfig(_lastLoadedAnneeId!);

      setState(() {
        _isSaisieMode = true;
        try {
          _selectedClass = _classes.firstWhere(
            (c) => c['id'] == overviewData['classe_id'],
          );
          _updateCycleConfig();
        } catch (e) {
          _selectedClass = null;
        }
        _selectedTrimestre = overviewData['trimestre'];
        _selectedSequence = overviewData['sequence'] ?? 1;
      });

      if (_lastLoadedAnneeId != null) {
        // 2. Charger les matières pour la classe sélectionnée
        await _loadSubjectsForSelectedClass();

        if (!mounted) return;

        setState(() {
          try {
            _selectedSubject = _subjects.firstWhere(
              (s) => s['id'] == overviewData['matiere_id'],
            );
          } catch (e) {
            _selectedSubject = null;
          }
        });

        // 3. Charger les notes
        await _loadGrades(_lastLoadedAnneeId!);
      }
    } catch (e) {
      debugPrint('Error opening trimester detail: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSaisieView(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildSaisieFilters(isDark),
          const SizedBox(height: 32),
          _buildStatsGrid(isDark),
          const SizedBox(height: 32),
          _buildGradesTable(isDark),
          const SizedBox(height: 100),
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
            color: Colors.black.withValues(alpha: 0.05),
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
              _updateCycleConfig();

              if (_lastLoadedAnneeId != null) {
                _loadSubjectsForSelectedClass().then(
                  (_) => _loadGrades(_lastLoadedAnneeId!),
                );
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
            _trimesters.isNotEmpty ? _trimesters : [1, 2, 3],
            (v) {
              setState(() {
                _selectedTrimestre = v;
                if (_sequences.isNotEmpty) {
                  final validSeqs = _sequences
                      .where((s) => s['trimestre'] == v)
                      .map((s) => s['numero_sequence'] as int)
                      .toList();
                  if (validSeqs.isNotEmpty &&
                      !validSeqs.contains(_selectedSequence)) {
                    _selectedSequence = validSeqs.first;
                  }
                }
              });
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
            _sequences
                .where((s) => s['trimestre'] == _selectedTrimestre)
                .map((s) => s['numero_sequence'] as int)
                .toList(),
            (v) {
              setState(() => _selectedSequence = v);
              if (_lastLoadedAnneeId != null) {
                _loadGrades(_lastLoadedAnneeId!);
              }
            },
            isDark,
            'S',
            itemLabelBuilder: (v) {
              final seq = _sequences.firstWhere(
                (s) =>
                    s['numero_sequence'] == v &&
                    s['trimestre'] == _selectedTrimestre,
                orElse: () => {},
              );
              return seq['nom'] ?? 'S$v';
            },
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
            isExpanded: true,
            value: value,
            items: items
                .map(
                  (c) => DropdownMenuItem<int>(
                    value: c['id'],
                    child: Text(c['nom'], overflow: TextOverflow.ellipsis),
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
    String prefix, {
    String Function(int)? itemLabelBuilder,
  }) {
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
                      itemLabelBuilder != null
                          ? itemLabelBuilder(opt)
                          : '$prefix$opt',
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
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 : 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        mainAxisExtent: 110,
      ),
      children: [
        _buildStatCard(
          'Moyenne de Classe',
          _stats['average'].toStringAsFixed(2),
          Icons.analytics_rounded,
          const Color(0xFF3B82F6),
          isDark,
        ),
        _buildStatCard(
          'Taux de Réussite',
          '${_stats['successRate'].toStringAsFixed(1)}%',
          Icons.pie_chart_rounded,
          const Color(0xFF10B981),
          isDark,
        ),
        _buildStatCard(
          'Barème (Min - Max)',
          '${_currentCycleMin.toStringAsFixed(0)} - ${_currentCycleMax.toStringAsFixed(0)}',
          Icons.straighten_rounded,
          const Color(0xFFEF4444),
          isDark,
        ),
        _buildStatCard(
          'Note de Passage',
          _currentCyclePassage.toStringAsFixed(1),
          Icons.flag_rounded,
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
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
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
                  color: color.withValues(alpha: 0.1),
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

  Widget _buildGradesTable(bool isDark) {
    final currentTrimesterSeqs =
        _sequences.where((s) => s['trimestre'] == _selectedTrimestre).toList()
          ..sort(
            (a, b) => (a['numero_sequence'] as int).compareTo(
              b['numero_sequence'] as int,
            ),
          );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.grey[50],
            child: Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Text(
                    'Nom de l\'élève',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                ...currentTrimesterSeqs.expand(
                  (s) => [
                    Container(
                      width: 70,
                      margin: const EdgeInsets.only(left: 8),
                      alignment: Alignment.center,
                      child: Text(
                        s['nom'] ?? 'Seq ${s['numero_sequence']}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    Container(
                      width: 60,
                      margin: const EdgeInsets.only(left: 8),
                      alignment: Alignment.center,
                      child: const Text(
                        'N × C',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredGrades.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final student = _filteredGrades[index];
              final eleveId = student['eleve_id'] as int;
              final currentTrimesterSeqs =
                  _sequences
                      .where((s) => s['trimestre'] == _selectedTrimestre)
                      .toList()
                    ..sort(
                      (a, b) => (a['numero_sequence'] as int).compareTo(
                        b['numero_sequence'] as int,
                      ),
                    );

              return ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: _buildStudentAvatar(
                  student['photo'],
                  student['nom'] != null &&
                          student['nom'].toString().runes.isNotEmpty
                      ? String.fromCharCode(
                          student['nom'].toString().runes.first,
                        )
                      : '?',
                ),
                title: Text(
                  '${student['nom']} ${student['prenom']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Matricule: ${student['matricule']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...currentTrimesterSeqs.expand((s) {
                      final seqNum = s['numero_sequence'] as int;
                      final key = '${eleveId}_$seqNum';
                      final controller = _controllers[key];
                      final noteValue = controller?.text ?? '';
                      final noteValueNum = double.tryParse(noteValue) ?? -1.0;
                      final coef =
                          (_selectedSubject?['coefficient'] as num?)
                              ?.toDouble() ??
                          1.0;
                      final noteTimesCoef = (noteValueNum != -1.0)
                          ? (noteValueNum * coef).toStringAsFixed(1)
                          : '-';

                      return [
                        Container(
                          width: 70,
                          margin: const EdgeInsets.only(left: 8),
                          child: TextField(
                            controller: controller,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textAlign: TextAlign.center,
                            onChanged: (v) => setState(() {}),
                            style: TextStyle(
                              color:
                                  (noteValueNum != -1.0 &&
                                      (noteValueNum < _currentCycleMin ||
                                          noteValueNum > _currentCycleMax))
                                  ? Colors.red
                                  : (isDark ? Colors.white : Colors.black),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: '-',
                              filled: true,
                              fillColor:
                                  (noteValueNum != -1.0 &&
                                      (noteValueNum < _currentCycleMin ||
                                          noteValueNum > _currentCycleMax))
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : (isDark
                                        ? AppTheme.cardDark
                                        : const Color(0xFFF3F4F6)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    (noteValueNum != -1.0 &&
                                        (noteValueNum < _currentCycleMin ||
                                            noteValueNum > _currentCycleMax))
                                    ? const BorderSide(
                                        color: Colors.red,
                                        width: 1,
                                      )
                                    : BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 60,
                          height: 48,
                          margin: const EdgeInsets.only(left: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            noteTimesCoef,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ];
                    }),
                  ],
                ),
              );
            },
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
      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
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
            AppTheme.primaryColor.withValues(alpha: 0.6),
          ],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
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
