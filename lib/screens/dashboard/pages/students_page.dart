import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/database/daos/eleve_dao.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/file_service.dart';
import '../../../theme/app_theme.dart';
import '../../../models/student.dart';
import '../../../providers/academic_year_provider.dart';
import '../../../widgets/student/add_student_modal.dart';
import '../../../widgets/student/edit_student_modal.dart';
import './student_detail_page.dart';
import '../../carte_scolaire_page.dart';
import '../../../widgets/carteele.dart';
import 'honor_roll_page.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key});

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  bool _showFilters = false;

  // Pagination
  int _currentPage = 0;
  final int _pageSize = 50;
  int _totalItems = 0;

  // Données
  List<Map<String, dynamic>> _filteredStudents = [];
  List<String> _uniqueClasses = [];

  // Filters
  String _selectedClassPrefix = 'Toutes les classes';
  String _selectedStatus = 'Tous les statuts';
  String _selectedGender = 'Tous les sexes';

  // Stats
  int _totalEleves = 0;
  int _elevesInscrits = 0;
  int _elevesReinscrits = 0;
  int _elevesMasculins = 0;
  int _elevesFeminins = 0;
  int _ageMoyen = 0;
  int? _lastLoadedAnneeId;
  Map<String, int> _classesStats = {};
  List<Map<String, dynamic>> _allClasses =
      []; // All classes with IDs and levels

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Utiliser listen: false pour éviter que les changements du provider ne redéclenchent didChangeDependencies à l'infini
    final academicProvider = Provider.of<AcademicYearProvider>(
      context,
      listen: false,
    );
    final anneeId = academicProvider.selectedAnneeId;

    if (anneeId != null && anneeId != _lastLoadedAnneeId) {
      _lastLoadedAnneeId = anneeId;
      // On utilise Future.microtask pour s'assurer que le build actuel est terminé
      Future.microtask(() => _loadData(anneeId));
    }
  }

  Future<void> _showTransferDialog(Map<String, dynamic> student) async {
    final db = await DatabaseHelper.instance.database;
    final eleveDao = EleveDao(db);

    // Get student's current class to find its level
    final studentClassId = student['classe_id'] as int;
    final classes = await db.query(
      'classe',
      where: 'id = ?',
      whereArgs: [studentClassId],
    );

    if (classes.isEmpty) return;
    final int levelId = classes.first['niveau_id'] as int;

    if (!mounted) return;

    final int? result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        int? selectedDestId;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            // Filter classes of the same level, excluding current
            final otherClasses = _allClasses
                .where(
                  (c) => c['id'] != studentClassId && c['niveau_id'] == levelId,
                )
                .toList();

            return AlertDialog(
              title: const Text('Transférer l\'élève'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transférer ${student['nom']} ${student['prenom']} vers une autre classe du même niveau.',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int>(
                    decoration: InputDecoration(
                      labelText: 'Classe de destination',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF374151)
                          : Colors.grey[50],
                    ),
                    dropdownColor: isDark
                        ? const Color(0xFF374151)
                        : Colors.white,
                    value: selectedDestId,
                    items: otherClasses
                        .map(
                          (c) => DropdownMenuItem<int>(
                            value: c['id'] as int,
                            child: Text(c['nom'].toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedDestId = v),
                  ),
                  if (otherClasses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Aucune autre classe disponible pour ce niveau.',
                        style: TextStyle(color: Colors.red, fontSize: 11),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: selectedDestId == null
                      ? null
                      : () => Navigator.pop(ctx, selectedDestId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: const Text(
                    'Transférer',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && _lastLoadedAnneeId != null) {
      setState(() => _isLoading = true);
      try {
        await eleveDao.transfererEleve(
          eleveId: student['id'] as int,
          newClasseId: result,
          anneeId: _lastLoadedAnneeId!,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Élève transféré avec succès.'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadData(_lastLoadedAnneeId!);
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
  }

  Future<void> _loadData(int anneeId) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final eleveDao = EleveDao(await DatabaseHelper.instance.database);

      // 1. Charger les statistiques globales et par classe
      final analytics = await eleveDao.getStudentAnalytics(anneeId);

      // 2. Charger le nombre total filtré pour la pagination
      final totalCount = await eleveDao.getElevesFilteredCount(
        anneeId: anneeId,
        search: _searchController.text,
        selectedClass: _selectedClassPrefix,
        selectedStatus: _selectedStatus,
        selectedGender: _selectedGender,
      );

      // 3. Charger les élèves de la page actuelle
      final students = await eleveDao.getElevesPaginated(
        anneeId: anneeId,
        limit: _pageSize,
        offset: _currentPage * _pageSize,
        search: _searchController.text,
        selectedClass: _selectedClassPrefix,
        selectedStatus: _selectedStatus,
        selectedGender: _selectedGender,
      );

      // 4. Charger les classes uniques pour le filtre (une seule fois ou à chaque changement d'année)
      if (_uniqueClasses.length <= 1) {
        final db = await DatabaseHelper.instance.database;
        final classes = await db.query(
          'classe',
          columns: ['id', 'nom', 'niveau_id'],
          orderBy: 'nom',
        );
        _allClasses = classes;
        _uniqueClasses = [
          'Toutes les classes',
          ...classes.map((c) => c['nom'].toString()),
        ];
      }

      setState(() {
        _filteredStudents = students;
        _totalItems = totalCount;
        _updateDisplayStats(analytics);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement : $e')),
        );
      }
    }
  }

  void _updateDisplayStats(Map<String, dynamic> analytics) {
    final stats = analytics['stats'] as Map<String, dynamic>;
    _totalEleves = stats['total'] ?? 0;
    _elevesInscrits = stats['new_students'] ?? 0;
    _elevesReinscrits = stats['returning_students'] ?? 0;
    _elevesMasculins = stats['males'] ?? 0;
    _elevesFeminins = stats['females'] ?? 0;
    _ageMoyen = (stats['average_age'] ?? 0.0).round();

    _classesStats = {};
    final classDist =
        analytics['classDistribution'] as List<Map<String, dynamic>>;
    for (var item in classDist) {
      _classesStats[item['classe'].toString()] = item['count'] as int;
    }
  }

  void _filterStudents() {
    setState(() {
      _currentPage = 0;
    });
    if (_lastLoadedAnneeId != null) {
      _loadData(_lastLoadedAnneeId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF111827)
          : const Color(0xFFF9FAFB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, isDark),
                  const SizedBox(height: 32),
                  _buildStatsGrid(isDark),
                  const SizedBox(height: 24),
                  _buildDistributionCards(isDark),
                  const SizedBox(height: 32),
                  _buildSearchAndFilters(isDark),
                  const SizedBox(height: 24),
                  _buildStudentsList(context, isDark),
                  const SizedBox(height: 16),
                  _buildPaginationControls(isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    Widget titleContent = Row(
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gestion des Élèves',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  foreground: Paint()
                    ..shader = const LinearGradient(
                      colors: [
                        Color(0xFF2563EB),
                        Color(0xFF9333EA),
                        Color(0xFFDB2777),
                      ],
                    ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
                ),
              ),
              Text(
                'Gérez et suivez les informations de tous vos élèves.',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    Widget buttonsContent = Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildActionButton(
          'Inscrire un élève',
          Icons.person_add,
          const Color(0xFF9333EA),
          _openAddModal,
        ),
        _buildActionButton(
          'Tableau d\'honneur',
          Icons.stars,
          const Color(0xFF10B981),
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => HonorRollPage(isDark: isDark)),
            );
          },
        ),
        _buildActionButton(
          'Générer Cartes',
          Icons.badge,
          const Color(0xFF22C3C3),
          _openCardsModal,
        ),
      ],
    );

    if (isDesktop) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: titleContent),
          const SizedBox(width: 16),
          buttonsContent,
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [titleContent, const SizedBox(height: 16), buttonsContent],
      );
    }
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ).copyWith(overlayColor: WidgetStateProperty.all(Colors.white10)),
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        mainAxisExtent: 110,
      ),
      children: [
        _buildStatCard(
          'Total Élèves',
          _totalEleves.toString(),
          Icons.people,
          Colors.blue,
          isDark,
        ),
        _buildStatCard(
          'Inscrits',
          _elevesInscrits.toString(),
          Icons.check_circle,
          Colors.green,
          isDark,
        ),
        _buildStatCard(
          'Réinscrits',
          _elevesReinscrits.toString(),
          Icons.history_edu,
          Colors.purple,
          isDark,
        ),
        _buildStatCard(
          'Âge Moyen',
          '${_ageMoyen} ans',
          Icons.bar_chart,
          Colors.orange,
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
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionCards(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildDistributionCard(
            'Répartition par Sexe',
            [
              _buildDistributionItem(
                'Masculin',
                _elevesMasculins,
                _totalEleves,
                Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildDistributionItem(
                'Féminin',
                _elevesFeminins,
                _totalEleves,
                Colors.pink,
              ),
            ],
            isDark,
            Icons.wc_outlined,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _buildDistributionCard(
            'Répartition par Classe',
            _classesStats.entries
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          e.key,
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${e.value} élève${e.value > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            isDark,
            Icons.class_outlined,
            Colors.green,
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
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDistributionItem(
    String label,
    int count,
    int total,
    Color color,
  ) {
    final double percent = total > 0 ? (count / total) : 0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14)),
            Text(
              '$count (${(percent * 100).round()}%)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: Colors.grey.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1F2937).withOpacity(0.8)
            : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
                  onChanged: (v) => _filterStudents(),
                  decoration: InputDecoration(
                    hintText:
                        'Rechercher par nom, prénom, matricule, classe...',
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
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => setState(() => _showFilters = !_showFilters),
                icon: const Icon(Icons.filter_list),
                label: const Text('Filtres'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          if (_showFilters) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF111827)
                    : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.1),
                  style: BorderStyle.none,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildFilterDropdown(
                      'Classe',
                      _selectedClassPrefix,
                      _uniqueClasses,
                      (v) {
                        setState(() => _selectedClassPrefix = v!);
                        _filterStudents();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFilterDropdown(
                      'Statut',
                      _selectedStatus,
                      ['Tous les statuts', 'Inscrit', 'Réinscrit'],
                      (v) {
                        setState(() => _selectedStatus = v!);
                        _filterStudents();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFilterDropdown(
                      'Sexe',
                      _selectedGender,
                      ['Tous les sexes', 'Masculin', 'Féminin'],
                      (v) {
                        setState(() => _selectedGender = v!);
                        _filterStudents();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
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
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.transparent,
          ),
        ),
      ],
    );
  }

  Future<void> _onStudentTap(Map<String, dynamic> eleve) async {
    // Si déjà confirmé, on peut ouvrir le détail ou ne rien faire
    if (eleve['confirmation_statut'] != 'En attente') {
      _openDetail(int.parse(eleve['id'].toString()));
      return;
    }

    if (_lastLoadedAnneeId == null) return;

    final student = Student.fromMap(eleve);

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AddStudentModal(
          initialStudent: student,
          isValidationMode: true,
          onSuccess: () {
            if (_lastLoadedAnneeId != null) {
              _loadData(_lastLoadedAnneeId!);
            }
          },
          onClose: () => Navigator.pop(context),
        ),
      );
    }
  }

  Widget _buildStudentsList(BuildContext context, bool isDark) {
    if (MediaQuery.of(context).size.width > 1000) {
      return _buildDesktopTable(isDark);
    } else {
      return _buildMobileCards(isDark);
    }
  }

  Widget _buildDesktopTable(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
      child: SingleChildScrollView(
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
              isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
            ),
            columns: const [
              DataColumn(
                label: Text(
                  'Photo',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              DataColumn(
                label: Text(
                  'Matricule',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              DataColumn(
                label: Text(
                  'Nom & Prénom',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              DataColumn(
                label: Text(
                  'Sexe',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              DataColumn(
                label: Text(
                  'Né(e) le',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              DataColumn(
                label: Text(
                  'À',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              DataColumn(
                label: Text(
                  'Type',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              DataColumn(
                label: Text(
                  'État',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              DataColumn(
                label: Text(
                  'Classe',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              DataColumn(
                label: Text(
                  'Actions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
            rows: _filteredStudents.map((eleve) {
              final s = Student.fromMap(eleve);
              return DataRow(
                onSelectChanged: (selected) {
                  if (selected == true) {
                    _onStudentTap(eleve);
                  }
                },
                cells: [
                  DataCell(
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: s.photo.isNotEmpty
                          ? (s.photo.startsWith('/') || s.photo.contains(':\\')
                                ? FileImage(File(s.photo)) as ImageProvider
                                : AssetImage(s.photo))
                          : null,
                      child: s.photo.isEmpty
                          ? const Icon(Icons.person, size: 20)
                          : null,
                    ),
                  ),
                  DataCell(
                    Text(s.matricule, style: const TextStyle(fontSize: 14)),
                  ),
                  DataCell(
                    Text(
                      s.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  DataCell(Text(s.sexe, style: const TextStyle(fontSize: 14))),
                  DataCell(
                    Text(s.dateNaissance, style: const TextStyle(fontSize: 14)),
                  ),
                  DataCell(
                    Text(s.lieuNaissance, style: const TextStyle(fontSize: 14)),
                  ),
                  DataCell(_buildInscriptionBadge(eleve['type_inscription'])),
                  DataCell(
                    _buildConfirmationBadge(eleve['confirmation_statut']),
                  ),
                  DataCell(Text(s.classe)),
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: Colors.blue,
                          ),
                          onPressed: () => _openEditModal(s),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Colors.red,
                          ),
                          onPressed: () => _handleDelete(s),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.visibility_outlined,
                            size: 20,
                            color: Colors.grey,
                          ),
                          onPressed: () => _openDetail(int.parse(s.id)),
                        ),
                        Tooltip(
                          message: 'Carte Scolaire',
                          child: IconButton(
                            icon: const Icon(
                              Icons.badge,
                              size: 20,
                              color: Color(0xFF22C3C3),
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CarteScolaireGuinee(studentId: s.id),
                              ),
                            ),
                          ),
                        ),
                        Tooltip(
                          message: 'Transfert',
                          child: IconButton(
                            icon: const Icon(
                              Icons.swap_horiz,
                              size: 20,
                              color: Colors.orange,
                            ),
                            onPressed: () => _showTransferDialog(eleve),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildInscriptionBadge(String? type) {
    if (type == null) return const Text('-');
    Color color = Colors.blue;
    if (type == 'Redoublement') color = Colors.orange;
    if (type == 'Réinscription') color = Colors.purple;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildConfirmationBadge(String? state) {
    final bool isConfirmed = state == 'Confirmé';
    final String label = isConfirmed ? 'ACTIVE' : 'EN ATTENTE';
    final Color color = isConfirmed ? Colors.teal : Colors.amber;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConfirmed ? Icons.check_circle : Icons.timer,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
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

  Widget _buildMobileCards(bool isDark) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.3,
      ),
      itemCount: _filteredStudents.length,
      itemBuilder: (context, index) {
        final s = Student.fromMap(_filteredStudents[index]);
        return InkWell(
          onTap: () => _onStudentTap(_filteredStudents[index]),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : Colors.white,
              borderRadius: BorderRadius.circular(16),
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
                CircleAvatar(
                  radius: 35,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  backgroundImage: s.photo.isNotEmpty
                      ? (s.photo.startsWith('/') || s.photo.contains(':\\')
                            ? FileImage(File(s.photo)) as ImageProvider
                            : AssetImage(s.photo))
                      : null,
                  child: s.photo.isEmpty
                      ? const Icon(
                          Icons.person,
                          size: 40,
                          color: AppTheme.primaryColor,
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  s.fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildInscriptionBadge(
                      _filteredStudents[index]['type_inscription'],
                    ),
                    const SizedBox(width: 8),
                    _buildConfirmationBadge(
                      _filteredStudents[index]['confirmation_statut'],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Sexe: ${s.sexeDisplay} | Né(e) le: ${s.dateNaissance}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  'À ${s.lieuNaissance}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildMobileAction(
                      'Détails',
                      Icons.visibility,
                      const Color(0xFF8B5CF6),
                      () => _openDetail(int.parse(s.id)),
                    ),
                    const SizedBox(width: 8),
                    _buildMobileAction(
                      'Modifier',
                      Icons.edit,
                      Colors.blue,
                      () => _openEditModal(s),
                    ),
                    const SizedBox(width: 8),
                    _buildMobileAction(
                      'Transfert',
                      Icons.swap_horiz,
                      Colors.orange,
                      () => _showTransferDialog(_filteredStudents[index]),
                    ),
                    const SizedBox(width: 8),
                    _buildMobileAction(
                      'Supprimer',
                      Icons.delete,
                      Colors.red,
                      () => _handleDelete(s),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileAction(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      style: TextButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _openAddModal() {
    showDialog(
      context: context,
      builder: (context) => AddStudentModal(
        onSuccess: () {
          final anneeId = context.read<AcademicYearProvider>().selectedAnneeId;
          if (anneeId != null) {
            _loadData(anneeId);
          }
        },
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  void _openCardsModal() {
    if (_filteredStudents.isEmpty) return;
    final studentMap = _filteredStudents.first;
    final student = Student.fromMap(studentMap);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CarteScolairePage(student: student)),
    );
  }

  Future<void> _handleDelete(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer'),
        content: Text('Supprimer ${student.fullName} ?'),
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

    if (confirmed == true) {
      try {
        final db = await DatabaseHelper.instance.database;
        // Supprimer la photo avant de supprimer l'élève de la BD
        if (student.photo.isNotEmpty) {
          await FileService.instance.deleteFile(student.photo);
        }
        await db.delete('eleve', where: 'id = ?', whereArgs: [student.id]);
        final anneeId = context.read<AcademicYearProvider>().selectedAnneeId;
        if (anneeId != null) {
          _loadData(anneeId);
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  void _openEditModal(Student student) {
    showDialog(
      context: context,
      builder: (context) => EditStudentModal(
        student: student,
        onSuccess: () {
          final anneeId = context.read<AcademicYearProvider>().selectedAnneeId;
          if (anneeId != null) {
            _loadData(anneeId);
          }
        },
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  void _openDetail(int studentId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentDetailPage(studentId: studentId),
      ),
    );
  }

  Widget _buildPaginationControls(bool isDark) {
    if (_filteredStudents.isEmpty) return const SizedBox.shrink();

    final int totalPages = (_totalItems / _pageSize).ceil();
    final int startItem = _totalItems == 0 ? 0 : (_currentPage * _pageSize) + 1;
    final int endItem = ((_currentPage + 1) * _pageSize).clamp(0, _totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Affichage $startItem à $endItem sur $_totalItems élèves',
            style: TextStyle(
              color: isDark ? Colors.white70 : AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage--)
                    : null,
                icon: const Icon(Icons.chevron_left),
                color: AppTheme.primaryColor,
                disabledColor: Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                'Page ${_currentPage + 1} / $totalPages',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
                icon: const Icon(Icons.chevron_right),
                color: AppTheme.primaryColor,
                disabledColor: Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
