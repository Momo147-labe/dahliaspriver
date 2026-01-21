import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/database/database_helper.dart';
import '../../../providers/academic_year_provider.dart';
import '../../../widgets/classe/assign_teacher_modal.dart';
import '../../../widgets/classe/manage_subjects_modal.dart';

class ClassesPage extends StatefulWidget {
  const ClassesPage({super.key});

  @override
  State<ClassesPage> createState() => _ClassesPageState();
}

class _ClassesPageState extends State<ClassesPage> {
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _academicYears = [];
  bool _isLoading = true;
  String _searchTerm = '';
  String _filterNiveau = 'tous';
  String _filterCycle = 'tous';
  String _sortBy = 'nom';
  String _sortOrder = 'asc';
  String _viewMode = 'grid'; // 'grid' or 'list'
  bool _showFilters = false;
  int? _lastLoadedAnneeId;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _effMaxController = TextEditingController(text: '100');
  final _salleController = TextEditingController();
  final _searchController = TextEditingController();

  String? _selectedNiveau;
  String? _selectedCycle;
  int? _selectedAnneeId;
  int? _selectedNextClassId;
  bool _isFinalClass = false;

  final List<String> _niveaux = [
    'Petite Section',
    'Moyenne Section',
    'Grande Section',
    '1ère',
    '2ème',
    '3ème',
    '4ème',
    '5ème',
    '6ème',
    '7ème',
    '8ème',
    '9ème',
    '10ème',
    '11ème',
    '12ème',
    'Terminale',
  ];
  final List<String> _cycles = ['Maternelle', 'Primaire', 'Collège', 'Lycée'];

  @override
  void initState() {
    super.initState();
    // Data will be loaded in didChangeDependencies
  }

  @override
  void dispose() {
    _nameController.dispose();
    _effMaxController.dispose();
    _salleController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final anneeId = context.watch<AcademicYearProvider>().selectedAnneeId;
    if (anneeId != null && anneeId != _lastLoadedAnneeId) {
      _lastLoadedAnneeId = anneeId;
      _loadData(anneeId);
    }
  }

  Future<void> _loadData(int anneeId) async {
    setState(() => _isLoading = true);
    try {
      // Charger les années scolaires
      final db = await DatabaseHelper.instance.database;
      final years = await db.query(
        'annee_scolaire',
        orderBy: 'date_debut DESC',
      );

      await _loadClasses(anneeId);
      setState(() {
        _selectedAnneeId = anneeId;
        _academicYears = years;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  void _showAssignTeacherModal(Map<String, dynamic> classe) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: AssignTeacherModal(
          classe: classe,
          onSuccess: () => _loadClasses(_selectedAnneeId!),
        ),
      ),
    );
  }

  void _showManageSubjectsModal(Map<String, dynamic> classe) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ManageClassSubjectsModal(
          classe: classe,
          onSuccess: () => _loadClasses(_selectedAnneeId!),
        ),
      ),
    );
  }

  Future<void> _loadClasses(int anneeId) async {
    final db = await DatabaseHelper.instance.database;
    final classes = await db.rawQuery(
      '''
      SELECT 
        c.*, 
        a.libelle as annee_libelle,
        (SELECT COUNT(*) FROM eleve WHERE classe_id = c.id AND annee_scolaire_id = ?) as eleve_count
      FROM classe c
      LEFT JOIN annee_scolaire a ON c.annee_scolaire_id = a.id
    ''',
      [anneeId],
    );
    setState(() => _classes = classes);
  }

  // --- Statistics ---
  Map<String, dynamic> _getStats() {
    if (_classes.isEmpty) {
      return {
        'totalClasses': 0,
        'totalEleves': 0,
        'totalCapacite': 0,
        'tauxOccupation': 0,
        'classesCompletes': 0,
        'classesVides': 0,
        'moyenneEffectif': 0,
        'niveauPrincipal': 'N/A',
      };
    }

    int totalEleves = _classes.fold(
      0,
      (sum, c) => sum + (c['eleve_count'] as int? ?? 0),
    );
    int totalCapacite = _classes.fold(
      0,
      (sum, c) => sum + (c['eff_max'] as int? ?? 0),
    );
    int classesCompletes = _classes
        .where(
          (c) => (c['eleve_count'] as int? ?? 0) >= (c['eff_max'] as int? ?? 0),
        )
        .length;
    int classesVides = _classes
        .where((c) => (c['eleve_count'] as int? ?? 0) == 0)
        .length;

    Map<String, int> niveauCounts = {};
    for (var c in _classes) {
      String nv = c['niveau'] ?? 'N/A';
      niveauCounts[nv] = (niveauCounts[nv] ?? 0) + 1;
    }
    String level = 'N/A';
    if (niveauCounts.isNotEmpty) {
      level = niveauCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    return {
      'totalClasses': _classes.length,
      'totalEleves': totalEleves,
      'totalCapacite': totalCapacite,
      'tauxOccupation': totalCapacite > 0
          ? (totalEleves / totalCapacite * 100).round()
          : 0,
      'classesCompletes': classesCompletes,
      'classesVides': classesVides,
      'moyenneEffectif': (totalEleves / _classes.length).round(),
      'niveauPrincipal': level,
    };
  }

  List<Map<String, dynamic>> _getFilteredClasses() {
    List<Map<String, dynamic>> filtered = _classes.where((c) {
      final name = (c['nom'] ?? '').toString().toLowerCase();
      final matchesSearch = name.contains(_searchTerm.toLowerCase());
      final matchesNiveau =
          _filterNiveau == 'tous' || c['niveau'] == _filterNiveau;
      final matchesCycle = _filterCycle == 'tous' || c['cycle'] == _filterCycle;
      return matchesSearch && matchesNiveau && matchesCycle;
    }).toList();

    filtered.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'nom':
          comparison = (a['nom'] ?? '').compareTo(b['nom'] ?? '');
          break;
        case 'niveau':
          comparison = (a['niveau'] ?? '').compareTo(b['niveau'] ?? '');
          break;
        case 'effectif':
          comparison = (a['eleve_count'] as int).compareTo(
            b['eleve_count'] as int,
          );
          break;
        case 'tauxOccupation':
          double tA = (a['eff_max'] as int) > 0
              ? (a['eleve_count'] as int) / (a['eff_max'] as int)
              : 0;
          double tB = (b['eff_max'] as int) > 0
              ? (b['eleve_count'] as int) / (b['eff_max'] as int)
              : 0;
          comparison = tA.compareTo(tB);
          break;
      }
      return _sortOrder == 'asc' ? comparison : -comparison;
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final stats = _getStats();
    final filtered = _getFilteredClasses();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF111827)
          : const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildHeader(isDark),
            const SizedBox(height: 32),
            _buildStatsGrid(stats, isDark),
            const SizedBox(height: 16),
            _buildSecondaryStats(stats, isDark),
            const SizedBox(height: 32),
            _buildControls(isDark),
            const SizedBox(height: 24),
            _viewMode == 'grid'
                ? _buildGridView(filtered, isDark)
                : _buildListView(filtered, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF9333EA)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.school, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gestion des Classes',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    foreground: Paint()
                      ..shader =
                          const LinearGradient(
                            colors: [
                              Color(0xFF2563EB),
                              Color(0xFF9333EA),
                              Color(0xFFDB2777),
                            ],
                          ).createShader(
                            const Rect.fromLTWH(0.0, 0.0, 300.0, 70.0),
                          ),
                  ),
                ),
                Text(
                  'Organisez et gérez les classes de votre école',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => _showAddModal(),
          icon: const Icon(Icons.add),
          label: const Text('Créer une classe'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            shadowColor: Colors.blue.withOpacity(0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> stats, bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      childAspectRatio: 2.2,
      children: [
        _buildGradientStatCard(
          'Total Classes',
          stats['totalClasses'].toString(),
          Icons.class_outlined,
          [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
        ),
        _buildGradientStatCard(
          'Total Élèves',
          stats['totalEleves'].toString(),
          Icons.people_outline,
          [const Color(0xFF10B981), const Color(0xFF059669)],
        ),
        _buildGradientStatCard(
          'Taux Occupation',
          '${stats['tauxOccupation']}%',
          Icons.bar_chart,
          [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
        ),
        _buildGradientStatCard(
          'Classes Complètes',
          stats['classesCompletes'].toString(),
          Icons.emoji_events_outlined,
          [const Color(0xFFF59E0B), const Color(0xFFD97706)],
        ),
      ],
    );
  }

  Widget _buildGradientStatCard(
    String title,
    String value,
    IconData icon,
    List<Color> colors,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.last.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryStats(Map<String, dynamic> stats, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildSimpleStatCard(
            'Classes Vides',
            stats['classesVides'].toString(),
            Icons.domain_disabled,
            isDark,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSimpleStatCard(
            'Moyenne Effectif',
            stats['moyenneEffectif'].toString(),
            Icons.groups_outlined,
            isDark,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSimpleStatCard(
            'Niveau Principal',
            stats['niveauPrincipal'],
            Icons.military_tech_outlined,
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleStatCard(
    String title,
    String value,
    IconData icon,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.blue, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937).withOpacity(0.8) : Colors.white,
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchTerm = v),
                  decoration: InputDecoration(
                    hintText: 'Rechercher une classe...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF374151)
                        : const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildIconButton(
                Icons.filter_list,
                () => setState(() => _showFilters = !_showFilters),
                isDark,
              ),
              const SizedBox(width: 8),
              _buildViewToggler(isDark),
            ],
          ),
          if (_showFilters) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    'Niveau',
                    _filterNiveau,
                    ['tous', ..._niveaux],
                    (v) => setState(() => _filterNiveau = v!),
                    isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    'Cycle',
                    _filterCycle,
                    ['tous', ..._cycles],
                    (v) => setState(() => _filterCycle = v!),
                    isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    'Trier par',
                    _sortBy,
                    ['nom', 'niveau', 'effectif', 'tauxOccupation'],
                    (v) => setState(() => _sortBy = v!),
                    isDark,
                  ),
                ),
                const SizedBox(width: 12),
                _buildIconButton(
                  _sortOrder == 'asc'
                      ? Icons.sort_by_alpha
                      : Icons.sort_by_alpha_outlined,
                  () => setState(
                    () => _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc',
                  ),
                  isDark,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onPressed, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.blue),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildViewToggler(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildToggleBtn('grid', Icons.grid_view, isDark),
          _buildToggleBtn('list', Icons.list, isDark),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String mode, IconData icon, bool isDark) {
    final active = _viewMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _viewMode = mode),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: active
              ? (isDark ? Colors.blue.withOpacity(0.2) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active && !isDark
              ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]
              : null,
        ),
        child: Icon(icon, color: active ? Colors.blue : Colors.grey, size: 20),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: value,
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, style: const TextStyle(fontSize: 14)),
                ),
              )
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF374151)
                : const Color(0xFFF3F4F6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGridView(List<Map<String, dynamic>> classes, bool isDark) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 1200
            ? 4
            : (MediaQuery.of(context).size.width > 800 ? 3 : 1),
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        mainAxisExtent: 320,
      ),
      itemCount: classes.length,
      itemBuilder: (context, i) => _buildClassCard(classes[i], isDark, i),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> c, bool isDark, int index) {
    final int count = c['eleve_count'] as int;
    final int max = c['eff_max'] as int;
    final double percent = max > 0 ? (count / max).clamp(0.0, 1.0) : 0;

    final List<Color> cardColors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFFF59E0B),
    ];
    final color = cardColors[index % cardColors.length];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.school, color: color, size: 24),
              ),
              Row(
                children: [
                  _buildSmallActionBtn(
                    Icons.person_add_alt_1_outlined,
                    Colors.purple,
                    () => _showAssignTeacherModal(c),
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildSmallActionBtn(
                    Icons.book_outlined,
                    Colors.orange,
                    () => _showManageSubjectsModal(c),
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildSmallActionBtn(
                    Icons.edit_outlined,
                    Colors.blue,
                    () => _showAddModal(classe: c),
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildSmallActionBtn(
                    Icons.delete_outline,
                    Colors.red,
                    () => _deleteClass(c['id']),
                    isDark,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            c['nom'],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            '${c['niveau']} • $count/${max} élèves',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 14,
            ),
          ),
          if (c['next_class_id'] != null) ...[
            const SizedBox(height: 4),
            Text(
              '→ ${_classes.firstWhere((cls) => cls['id'] == c['next_class_id'], orElse: () => {'nom': 'N/A'})['nom']}',
              style: TextStyle(
                color: Colors.green[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const Spacer(),
          _buildProgressBar(percent, count, max),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.meeting_room_outlined,
            'Salle',
            c['salle'] ?? 'N/A',
            isDark,
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.calendar_today_outlined,
            'Année',
            c['annee_libelle'] ?? 'N/A',
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double percent, int count, int max) {
    Color barColor = Colors.green;
    if (percent >= 1.0)
      barColor = Colors.red;
    else if (percent >= 0.8)
      barColor = Colors.orange;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Effectif',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            Text(
              '${(percent * 100).round()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: Colors.grey.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation(barColor),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800]!.withOpacity(0.5) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallActionBtn(
    IconData icon,
    Color color,
    VoidCallback onTap,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> classes, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: classes.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
        itemBuilder: (context, i) {
          final c = classes[i];
          return ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.school, color: Colors.blue),
            ),
            title: Text(
              c['nom'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${c['niveau']} • ${c['eleve_count']}/${c['eff_max']} élèves',
                  style: const TextStyle(fontSize: 12),
                ),
                if (c['next_class_id'] != null)
                  Text(
                    '→ ${_classes.firstWhere((cls) => cls['id'] == c['next_class_id'], orElse: () => {'nom': 'N/A'})['nom']}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (c['is_final_class'] == 1)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'FINALE',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSmallActionBtn(
                  Icons.person_add_alt_1_outlined,
                  Colors.purple,
                  () => _showAssignTeacherModal(c),
                  isDark,
                ),
                const SizedBox(width: 8),
                _buildSmallActionBtn(
                  Icons.book_outlined,
                  Colors.orange,
                  () => _showManageSubjectsModal(c),
                  isDark,
                ),
                const SizedBox(width: 8),
                _buildSmallActionBtn(
                  Icons.edit_outlined,
                  Colors.blue,
                  () => _showAddModal(classe: c),
                  isDark,
                ),
                const SizedBox(width: 8),
                _buildSmallActionBtn(
                  Icons.delete_outline,
                  Colors.red,
                  () => _deleteClass(c['id']),
                  isDark,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddModal({Map<String, dynamic>? classe}) {
    if (classe != null) {
      _nameController.text = classe['nom'];
      _effMaxController.text = classe['eff_max'].toString();
      _salleController.text = classe['salle'] ?? '';
      _selectedNiveau = classe['niveau'];
      _selectedCycle = classe['cycle'];
      _selectedAnneeId = classe['annee_scolaire_id'];
      _selectedNextClassId = classe['next_class_id'];
      _isFinalClass = classe['is_final_class'] == 1;
    } else {
      _nameController.clear();
      _effMaxController.text = '100';
      _salleController.clear();
      _selectedNiveau = null;
      _selectedCycle = null;
      _selectedAnneeId = DatabaseHelper.activeAnneeId;
      _selectedNextClassId = null;
      _isFinalClass = false;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2937) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              Container(
                height: 120,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF9333EA)],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        classe == null ? Icons.add_circle_outline : Icons.edit,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          classe == null
                              ? 'Nouvelle Classe'
                              : 'Modifier la Classe',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          classe == null
                              ? 'Ajoutez une nouvelle section scolaire'
                              : 'Mettez à jour les informations',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildInputField(
                          'Nom de la classe *',
                          _nameController,
                          Icons.label_outline,
                          isDark,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _buildModalDropdown(
                                'Niveau *',
                                _selectedNiveau,
                                _niveaux,
                                (v) => setModalState(() => _selectedNiveau = v),
                                isDark,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _buildModalDropdown(
                                'Cycle *',
                                _selectedCycle,
                                _cycles,
                                (v) => setModalState(() => _selectedCycle = v),
                                isDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInputField(
                                'Effectif Max *',
                                _effMaxController,
                                Icons.groups_outlined,
                                isDark,
                                type: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _buildInputField(
                                'Salle *',
                                _salleController,
                                Icons.meeting_room_outlined,
                                isDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          'Année Scolaire',
                          TextEditingController(
                            text: _academicYears.isNotEmpty
                                ? _academicYears
                                          .firstWhere(
                                            (a) => a['id'] == _selectedAnneeId,
                                            orElse: () => {'libelle': 'N/A'},
                                          )['libelle']
                                          ?.toString() ??
                                      'N/A'
                                : 'N/A',
                          ),
                          Icons.calendar_today,
                          isDark,
                          readOnly: true,
                        ),
                        const SizedBox(height: 20),
                        _buildModalDropdown(
                          'Classe Suivante',
                          _selectedNextClassId != null
                              ? _classes.firstWhere(
                                  (c) => c['id'] == _selectedNextClassId,
                                  orElse: () => {'nom': 'Aucune'},
                                )['nom']
                              : 'Aucune',
                          [
                            'Aucune',
                            ..._classes
                                .where(
                                  (c) =>
                                      classe == null || c['id'] != classe['id'],
                                )
                                .map((c) => c['nom'] as String),
                          ],
                          (v) => setModalState(() {
                            if (v == null || v == 'Aucune') {
                              _selectedNextClassId = null;
                            } else {
                              final selected = _classes.firstWhere(
                                (c) => c['nom'] == v,
                              );
                              _selectedNextClassId = selected['id'];
                            }
                          }),
                          isDark,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: CheckboxListTile(
                                title: const Text('Classe Finale'),
                                subtitle: const Text(
                                  'Cocher si c\'est la dernière classe du cycle',
                                ),
                                value: _isFinalClass,
                                onChanged: (value) => setModalState(
                                  () => _isFinalClass = value ?? false,
                                ),
                                activeColor: const Color(0xFF2563EB),
                                checkColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _buildBtn(
                                'Annuler',
                                isDark ? Colors.grey[700]! : Colors.grey[100]!,
                                Colors.grey,
                                () => Navigator.pop(context),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildBtn(
                                classe == null
                                    ? 'Créer la classe'
                                    : 'Enregistrer',
                                const Color(0xFF2563EB),
                                Colors.white,
                                () =>
                                    _save(classe == null ? null : classe['id']),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    IconData icon,
    bool isDark, {
    TextInputType type = TextInputType.text,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: type,
          readOnly: readOnly,
          validator: (v) => (v == null || v.isEmpty) ? 'Champ requis' : null,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.blue),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF374151)
                : const Color(0xFFF3F4F6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModalDropdown(
    String label,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
          validator: (v) => v == null ? 'Requis' : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark
                ? const Color(0xFF374151)
                : const Color(0xFFF3F4F6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBtn(String label, Color bg, Color text, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: text,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _save(int? id) async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'nom': _nameController.text,
      'cycle': _selectedCycle,
      'salle': _salleController.text,
      'niveau': _selectedNiveau,
      'eff_max': int.tryParse(_effMaxController.text) ?? 100,
      'next_class_id': _selectedNextClassId,
      'is_final_class': _isFinalClass ? 1 : 0,
      'annee_scolaire_id': _selectedAnneeId,
    };

    try {
      if (id == null) {
        await DatabaseHelper.instance.insert('classe', data);
      } else {
        await DatabaseHelper.instance.update('classe', data, 'id = ?', [id]);
      }
      Navigator.pop(context);
      _loadClasses(_selectedAnneeId!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(id == null ? 'Classe créée' : 'Classe mise à jour'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteClass(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer'),
        content: const Text('Voulez-vous vraiment supprimer cette classe ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DatabaseHelper.instance.delete('classe', 'id = ?', [id]);
        _loadClasses(_selectedAnneeId!);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
