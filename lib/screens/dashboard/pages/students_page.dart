import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/database/database_helper.dart';
import '../../../theme/app_theme.dart';
import '../../../models/student.dart';
import '../../../providers/academic_year_provider.dart';
import '../../../widgets/student/add_student_modal.dart';
import '../../../widgets/student/edit_student_modal.dart';
import '../../badge_generator_page.dart';
import './student_detail_page.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key});

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  bool _showFilters = false;

  List<Map<String, dynamic>> _students = [];
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
      final db = await DatabaseHelper.instance.database;

      final students = await db.rawQuery(
        '''
        SELECT 
          e.*,
          c.nom as classe_nom,
          n.nom as classe_niveau
        FROM eleve e
        LEFT JOIN classe c ON e.classe_id = c.id
        LEFT JOIN niveaux n ON c.niveau_id = n.id
        WHERE e.annee_scolaire_id = ?
        ORDER BY e.nom, e.prenom
      ''',
        [anneeId],
      );

      setState(() {
        _students = students;
        _filteredStudents = students;
        _calculateStats(students);

        _uniqueClasses = [
          'Toutes les classes',
          ...students
              .map((e) => e['classe_nom']?.toString() ?? 'Non défini')
              .toSet()
              .toList(),
        ];
        _isLoading = false;
      });

      _filterStudents();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  void _calculateStats(List<Map<String, dynamic>> students) {
    _totalEleves = students.length;
    _elevesInscrits = students.where((e) => e['statut'] == 'inscrit').length;
    _elevesReinscrits = students
        .where((e) => e['statut'] == 'reinscrit')
        .length;
    _elevesMasculins = students.where((e) => e['sexe'] == 'M').length;
    _elevesFeminins = students.where((e) => e['sexe'] == 'F').length;

    double totalAge = 0;
    _classesStats = {};

    for (var s in students) {
      final String birthDate = s['date_naissance']?.toString() ?? '';
      if (birthDate.isNotEmpty) {
        try {
          final dt = DateTime.parse(birthDate);
          totalAge += DateTime.now().year - dt.year;
        } catch (_) {}
      }

      final String cls = s['classe_nom']?.toString() ?? 'Non assigné';
      _classesStats[cls] = (_classesStats[cls] ?? 0) + 1;
    }

    _ageMoyen = _totalEleves > 0 ? (totalAge / _totalEleves).round() : 0;
  }

  void _filterStudents() {
    setState(() {
      _filteredStudents = _students.where((student) {
        final searchText = _searchController.text.toLowerCase();
        final matchesSearch =
            (student['nom']?.toString().toLowerCase().contains(searchText) ??
                false) ||
            (student['prenom']?.toString().toLowerCase().contains(searchText) ??
                false) ||
            (student['matricule']?.toString().toLowerCase().contains(
                  searchText,
                ) ??
                false) ||
            (student['classe_nom']?.toString().toLowerCase().contains(
                  searchText,
                ) ??
                false);

        final matchesClass =
            _selectedClassPrefix == 'Toutes les classes' ||
            student['classe_nom'] == _selectedClassPrefix;
        final matchesStatus =
            _selectedStatus == 'Tous les statuts' ||
            student['statut'] == _selectedStatus.toLowerCase();
        final matchesGender =
            _selectedGender == 'Tous les sexes' ||
            student['sexe'] == (_selectedGender == 'Masculin' ? 'M' : 'F');

        return matchesSearch && matchesClass && matchesStatus && matchesGender;
      }).toList();
    });
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
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddModal(),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
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
                  'Gestion des Élèves',
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
                            const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0),
                          ),
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
          ],
        ),
        Row(
          children: [
            _buildActionButton(
              'Inscrire un élève',
              Icons.person_add,
              const Color(0xFF9333EA),
              _openAddModal,
            ),
            const SizedBox(width: 12),
            _buildActionButton(
              'Tableau d\'honneur',
              Icons.stars,
              const Color(0xFF10B981),
              () {},
            ),
            const SizedBox(width: 12),
            _buildActionButton(
              'Générer Cartes',
              Icons.badge,
              const Color(0xFF22C3C3),
              _openCardsModal,
            ),
          ],
        ),
      ],
    );
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
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      childAspectRatio: 2.5,
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
          Column(
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
                  'Date de Naiss.',
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
                  'Statut',
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
                  DataCell(Text(s.dateNaissance)),
                  DataCell(Text(s.classe)),
                  DataCell(_buildStatusBadge(s.statut)),
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

  Widget _buildStatusBadge(String status) {
    final bool isInscrit = status.toLowerCase() == 'inscrit';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isInscrit
            ? Colors.green.withOpacity(0.1)
            : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: isInscrit ? Colors.green : Colors.blue,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
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
        return Container(
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
              const SizedBox(height: 4),
              _buildStatusBadge(s.statut),
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
                    'Supprimer',
                    Icons.delete,
                    Colors.red,
                    () => _handleDelete(s),
                  ),
                ],
              ),
            ],
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BadgeGeneratorPage()),
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
}
