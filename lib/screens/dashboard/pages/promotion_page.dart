import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../theme/app_theme.dart';

class PromotionPage extends StatefulWidget {
  const PromotionPage({super.key});

  @override
  State<PromotionPage> createState() => _PromotionPageState();
}

class _PromotionPageState extends State<PromotionPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  bool _isLoading = false;

  // Filter state
  List<Map<String, dynamic>> _annees = [];
  int? _oldAnneeId;
  int? _newAnneeId;

  List<Map<String, dynamic>> _classes = [];
  int? _oldClasseId;
  int? _newClasseId;

  // Students list with averages
  List<Map<String, dynamic>> _students = [];
  Set<int> _selectedAdmisIds = {};
  Set<int> _selectedRedoublantIds = {};

  // Cycle pass mark
  double _moyennePassage = 10.0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final db = await _dbHelper.database;
      _annees = await db.query('annee_scolaire', orderBy: 'date_debut DESC');

      if (_annees.isNotEmpty) {
        // Default: newest year is the destination
        _newAnneeId = _annees.first['id'];
        // Use annee_precedente_id to auto-select the source year
        final prevId = _annees.first['annee_precedente_id'];
        if (prevId != null) {
          _oldAnneeId = prevId as int;
        } else if (_annees.length > 1) {
          _oldAnneeId = _annees[1]['id'];
        } else {
          _oldAnneeId = _annees.first['id'];
        }
      }

      await _loadClasses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadClasses() async {
    if (_oldAnneeId == null) return;
    try {
      _classes = await _dbHelper.classeDao.getClassesByAnnee(_oldAnneeId!);
      if (_classes.isNotEmpty) {
        _oldClasseId = _classes.first['id'];
        // Use next_class_id to auto-select the destination class
        await _resolveNextClass(_oldClasseId!);
        await _loadStudentsWithAverages();
      } else {
        _oldClasseId = null;
        _newClasseId = null;
        _students = [];
        _selectedAdmisIds.clear();
        _selectedRedoublantIds.clear();
      }
      setState(() {});
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  /// Resolves next_class_id from the database for a given class
  Future<void> _resolveNextClass(int classeId) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'classe',
      columns: ['next_class_id'],
      where: 'id = ?',
      whereArgs: [classeId],
    );
    if (result.isNotEmpty && result.first['next_class_id'] != null) {
      _newClasseId = result.first['next_class_id'] as int;
    } else {
      // Fallback: keep same class (redoublement case)
      _newClasseId = classeId;
    }
  }

  Future<void> _loadStudentsWithAverages() async {
    if (_oldClasseId == null || _oldAnneeId == null) return;
    setState(() => _isLoading = true);
    try {
      // 1. Get the moyenne_passage from the cycle linked to the class
      final db = await _dbHelper.database;
      final cycleResult = await db.rawQuery(
        '''SELECT cy.moyenne_passage 
           FROM classe c 
           JOIN cycles_scolaires cy ON c.cycle_id = cy.id 
           WHERE c.id = ?''',
        [_oldClasseId],
      );
      _moyennePassage = cycleResult.isNotEmpty
          ? (cycleResult.first['moyenne_passage'] as num?)?.toDouble() ?? 10.0
          : 10.0;

      // 2. Get students
      final rawStudents = await _dbHelper.eleveDao.getElevesByClasse(
        _oldClasseId!,
      );

      // 3. Calculate average for each student
      final studentsWithAvg = <Map<String, dynamic>>[];
      for (var student in rawStudents) {
        final moyenne = await _dbHelper.notesDao.calculerMoyenneGenerale(
          student['id'] as int,
          _oldAnneeId!,
        );
        studentsWithAvg.add({
          ...student,
          'moyenne': moyenne,
          'isAdmis': moyenne >= _moyennePassage,
        });
      }

      // Sort by average descending
      studentsWithAvg.sort(
        (a, b) => (b['moyenne'] as double).compareTo(a['moyenne'] as double),
      );

      _students = studentsWithAvg;

      // Auto-select: admis go to promotion, redoublants go to redoublement
      _selectedAdmisIds = _students
          .where((s) => s['isAdmis'] == true)
          .map((s) => s['id'] as int)
          .toSet();
      _selectedRedoublantIds = _students
          .where((s) => s['isAdmis'] == false)
          .map((s) => s['id'] as int)
          .toSet();
    } catch (e) {
      debugPrint('Error loading students with averages: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _executePromotion() async {
    if (_selectedAdmisIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun élève admis sélectionné.')),
      );
      return;
    }
    if (_newClasseId == null || _newAnneeId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la promotion'),
        content: Text(
          'Promouvoir ${_selectedAdmisIds.length} élève(s) admis vers la classe de destination ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
            child: const Text(
              'Confirmer',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _dbHelper.eleveDao.executeBulkPromotion(
        eleveIds: _selectedAdmisIds.toList(),
        oldClasseId: _oldClasseId!,
        oldAnneeId: _oldAnneeId!,
        newClasseId: _newClasseId!,
        newAnneeId: _newAnneeId!,
        decision: 'Admis',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedAdmisIds.length} élève(s) promu(s) avec succès.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadStudentsWithAverages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _executeRedoublement() async {
    if (_selectedRedoublantIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun élève redoublant sélectionné.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer le redoublement'),
        content: Text(
          'Enregistrer ${_selectedRedoublantIds.length} élève(s) comme redoublant(s) ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            child: const Text(
              'Confirmer',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _dbHelper.eleveDao.executeBulkPromotion(
        eleveIds: _selectedRedoublantIds.toList(),
        oldClasseId: _oldClasseId!,
        oldAnneeId: _oldAnneeId!,
        newClasseId: _oldClasseId!, // Same class for redoublement
        newAnneeId: _newAnneeId!,
        decision: 'Redoublant',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedRedoublantIds.length} élève(s) enregistré(s) comme redoublant(s).',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      await _loadStudentsWithAverages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.backgroundDark
          : AppTheme.backgroundLight,
      body: _isLoading && _annees.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildControls(isDark),
                  const SizedBox(height: 12),
                  _buildPassMarkBanner(isDark),
                  const SizedBox(height: 12),
                  _buildActionButtons(isDark),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _isLoading && _annees.isNotEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : _buildStudentsList(isDark),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPassMarkBanner(bool isDark) {
    final admisCount = _students.where((s) => s['isAdmis'] == true).length;
    final redoublantCount = _students.length - admisCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 13,
                ),
                children: [
                  const TextSpan(text: 'Note de passage du cycle : '),
                  TextSpan(
                    text: '${_moyennePassage.toStringAsFixed(1)} / 20',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: '  •  '),
                  TextSpan(
                    text: '$admisCount Admis',
                    style: TextStyle(
                      color: Colors.green[400],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const TextSpan(text: '  •  '),
                  TextSpan(
                    text: '$redoublantCount Redoublant(s)',
                    style: TextStyle(
                      color: Colors.red[400],
                      fontWeight: FontWeight.bold,
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

  Widget _buildActionButtons(bool isDark) {
    return Row(
      children: [
        const Spacer(),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[700],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _isLoading ? null : _executeRedoublement,
          icon: const Icon(Icons.replay, size: 18),
          label: Text('Redoubler (${_selectedRedoublantIds.length})'),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _isLoading ? null : _executePromotion,
          icon: const Icon(Icons.arrow_upward, size: 18),
          label: Text('Promouvoir (${_selectedAdmisIds.length})'),
        ),
      ],
    );
  }

  Widget _buildControls(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // FROM block
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ORIGINE',
                        style: TextStyle(
                          color: Colors.blue[400],
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  decoration: InputDecoration(
                    labelText: 'Année de Départ',
                    labelStyle: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF374151)
                        : Colors.grey[50],
                  ),
                  dropdownColor: isDark
                      ? const Color(0xFF374151)
                      : Colors.white,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  value: _oldAnneeId,
                  items: _annees
                      .map(
                        (a) => DropdownMenuItem<int>(
                          value: a['id'] as int,
                          child: Text(a['libelle'].toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() => _oldAnneeId = v);
                    _loadClasses();
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  decoration: InputDecoration(
                    labelText: 'Classe de Départ',
                    labelStyle: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF374151)
                        : Colors.grey[50],
                  ),
                  dropdownColor: isDark
                      ? const Color(0xFF374151)
                      : Colors.white,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  value: _oldClasseId,
                  items: _classes
                      .map(
                        (c) => DropdownMenuItem<int>(
                          value: c['id'] as int,
                          child: Text(c['nom'].toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (v) async {
                    setState(() => _oldClasseId = v);
                    if (v != null) await _resolveNextClass(v);
                    await _loadStudentsWithAverages();
                    setState(() {});
                  },
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                size: 24,
                color: AppTheme.primaryColor,
              ),
            ),
          ),

          // TO block
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'DESTINATION',
                        style: TextStyle(
                          color: Colors.green[400],
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  decoration: InputDecoration(
                    labelText: 'Année de Destination',
                    labelStyle: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF374151)
                        : Colors.grey[50],
                  ),
                  dropdownColor: isDark
                      ? const Color(0xFF374151)
                      : Colors.white,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  value: _newAnneeId,
                  items: _annees
                      .map(
                        (a) => DropdownMenuItem<int>(
                          value: a['id'] as int,
                          child: Text(a['libelle'].toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() => _newAnneeId = v);
                    // Auto-resolve source year via annee_precedente_id
                    if (v != null) {
                      final selectedYear = _annees.firstWhere(
                        (a) => a['id'] == v,
                        orElse: () => <String, dynamic>{},
                      );
                      final prevId = selectedYear['annee_precedente_id'];
                      if (prevId != null) {
                        setState(() => _oldAnneeId = prevId as int);
                        _loadClasses();
                      }
                    }
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  decoration: InputDecoration(
                    labelText: 'Classe de Destination',
                    labelStyle: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF374151)
                        : Colors.grey[50],
                  ),
                  dropdownColor: isDark
                      ? const Color(0xFF374151)
                      : Colors.white,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  value: _newClasseId,
                  items: _classes
                      .map(
                        (c) => DropdownMenuItem<int>(
                          value: c['id'] as int,
                          child: Text(c['nom'].toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _newClasseId = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsList(bool isDark) {
    if (_students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 64,
              color: isDark ? Colors.white24 : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun élève trouvé dans cette classe.',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    '#',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Expanded(
                  flex: 3,
                  child: Text(
                    'Élève',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const Expanded(
                  flex: 1,
                  child: Text(
                    'Matricule',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    'Moy. Annuelle',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    'Décision',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(width: 40), // checkbox space
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: _students.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark ? Colors.white10 : Colors.grey[200],
              ),
              itemBuilder: (context, index) {
                final student = _students[index];
                final isAdmis = student['isAdmis'] as bool;
                final moyenne = student['moyenne'] as double;
                final studentId = student['id'] as int;
                final isSelected = isAdmis
                    ? _selectedAdmisIds.contains(studentId)
                    : _selectedRedoublantIds.contains(studentId);

                return Container(
                  color: isSelected
                      ? (isAdmis
                            ? Colors.green.withOpacity(0.05)
                            : Colors.red.withOpacity(0.05))
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: isAdmis
                                  ? Colors.green.withOpacity(0.15)
                                  : Colors.red.withOpacity(0.15),
                              child: Text(
                                (student['nom']?.toString() ?? '?')[0]
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: isAdmis
                                      ? Colors.green[700]
                                      : Colors.red[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${student['nom']} ${student['prenom']}',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          student['matricule']?.toString() ?? '-',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isAdmis
                                  ? Colors.green.withOpacity(0.12)
                                  : Colors.red.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              moyenne.toStringAsFixed(2),
                              style: TextStyle(
                                color: isAdmis
                                    ? Colors.green[700]
                                    : Colors.red[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isAdmis
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isAdmis
                                    ? Colors.green.withOpacity(0.3)
                                    : Colors.red.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isAdmis ? Icons.check_circle : Icons.cancel,
                                  size: 14,
                                  color: isAdmis
                                      ? Colors.green[600]
                                      : Colors.red[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isAdmis ? 'Admis' : 'Redoublant',
                                  style: TextStyle(
                                    color: isAdmis
                                        ? Colors.green[700]
                                        : Colors.red[700],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Checkbox(
                          value: isSelected,
                          activeColor: isAdmis ? Colors.green : Colors.red,
                          onChanged: (val) {
                            setState(() {
                              if (isAdmis) {
                                if (val == true) {
                                  _selectedAdmisIds.add(studentId);
                                } else {
                                  _selectedAdmisIds.remove(studentId);
                                }
                              } else {
                                if (val == true) {
                                  _selectedRedoublantIds.add(studentId);
                                } else {
                                  _selectedRedoublantIds.remove(studentId);
                                }
                              }
                            });
                          },
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
}
