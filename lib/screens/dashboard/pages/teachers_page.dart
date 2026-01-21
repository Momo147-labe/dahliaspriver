import 'dart:io';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/database/database_helper.dart';
import '../../../models/enseignant.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/teacher/teacher_modal.dart';

class TeachersPage extends StatefulWidget {
  const TeachersPage({super.key});

  @override
  State<TeachersPage> createState() => _TeachersPageState();
}

class _TeachersPageState extends State<TeachersPage>
    with SingleTickerProviderStateMixin {
  List<Enseignant> _teachers = [];
  List<Enseignant> _filteredTeachers = [];
  Map<int, List<Map<String, dynamic>>> _teacherClasses = {}; // enseignant_id -> classes
  Map<String, dynamic> _stats = {
    'total_enseignants': 0,
    'total_specialites': 0,
    'assignments_count': 0,
  };

  // Advanced Stats
  int _totalEnseignants = 0;
  int _enseignantsMasculins = 0;
  int _enseignantsFeminins = 0;
  int _ageMoyen = 0;
  Map<String, int> _specialiteStats = {};

  bool _isLoading = true;
  String _searchTerm = '';
  String _viewMode = 'grid'; // 'grid' or 'list'
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = DatabaseHelper.instance;
      final teachersData = await db.getEnseignants();
      final stats = await db.getEnseignantsStats();
      final anneeId = await db.ensureActiveAnneeCached();

      // Charger les classes pour chaque enseignant
      Map<int, List<Map<String, dynamic>>> teacherClasses = {};
      if (anneeId != null) {
        for (var teacherData in teachersData) {
          final classes = await db.getClassesByTeacher(teacherData['id'], anneeId);
          teacherClasses[teacherData['id']] = classes;
        }
      }

      if (mounted) {
        setState(() {
          _teachers = teachersData.map((e) => Enseignant.fromMap(e)).toList();
          _teacherClasses = teacherClasses;
          _stats = stats;
          _calculateStats(_teachers);
          _filterTeachers();
          _isLoading = false;
        });
        _animationController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _calculateStats(List<Enseignant> teachers) {
    _totalEnseignants = teachers.length;
    _enseignantsMasculins = teachers.where((e) => e.sexe == 'M').length;
    _enseignantsFeminins = teachers.where((e) => e.sexe == 'F').length;

    double totalAge = 0;
    int teachersWithAge = 0;
    _specialiteStats = {};

    for (var t in teachers) {
      if (t.dateNaissance != null && t.dateNaissance!.isNotEmpty) {
        try {
          final dt = DateTime.parse(t.dateNaissance!);
          totalAge += DateTime.now().year - dt.year;
          teachersWithAge++;
        } catch (_) {}
      }

      final String spec = t.specialite?.isNotEmpty == true
          ? t.specialite!
          : 'Non défini';
      _specialiteStats[spec] = (_specialiteStats[spec] ?? 0) + 1;
    }

    _ageMoyen = teachersWithAge > 0 ? (totalAge / teachersWithAge).round() : 0;
  }

  void _filterTeachers() {
    setState(() {
      _filteredTeachers = _teachers.where((t) {
        final searchMatch =
            t.nom.toLowerCase().contains(_searchTerm.toLowerCase()) ||
            t.prenom.toLowerCase().contains(_searchTerm.toLowerCase()) ||
            (t.specialite?.toLowerCase().contains(_searchTerm.toLowerCase()) ??
                false);
        return searchMatch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isDark),
                  const SizedBox(height: 32),
                  _buildStatsSection(isDark),
                  const SizedBox(height: 24),
                  _buildDistributionCards(isDark),
                  const SizedBox(height: 32),
                  _buildControls(isDark),
                  const SizedBox(height: 32),
                  _filteredTeachers.isEmpty
                      ? _buildEmptyState(isDark)
                      : _viewMode == 'grid'
                      ? _buildGridView(isDark)
                      : _buildListView(isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return FadeTransition(
      opacity: _animationController,
      child: Row(
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
                child: const Icon(
                  Symbols.person,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gestion des Enseignants',
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
                    'Gérez le personnel enseignant et leurs spécialités',
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
                'Ajouter un enseignant',
                Icons.person_add,
                const Color(0xFF9333EA),
                _openAddModal,
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                'Affecter à une classe',
                Icons.assignment_ind,
                const Color(0xFF10B981),
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fonctionnalité d\'affectation à venir...'),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
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

  Widget _buildStatsSection(bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 4,
      crossAxisSpacing: 24,
      mainAxisSpacing: 24,
      childAspectRatio: 2.2,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          'Total Enseignants',
          _totalEnseignants.toString(),
          Symbols.groups,
          [Colors.blue.shade500, Colors.blue.shade700],
          isDark,
        ),
        _buildStatCard('Âge Moyen', '$_ageMoyen ans', Symbols.bar_chart, [
          Colors.orange.shade500,
          Colors.orange.shade700,
        ], isDark),
        _buildStatCard(
          'Spécialités',
          _stats['total_specialites'].toString(),
          Symbols.school,
          [Colors.teal.shade500, Colors.teal.shade700],
          isDark,
        ),
        _buildStatCard(
          'Cours Assignés',
          _stats['assignments_count'].toString(),
          Symbols.calendar_today,
          [Colors.purple.shade500, Colors.purple.shade700],
          isDark,
        ),
      ],
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
                _enseignantsMasculins,
                _totalEnseignants,
                Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildDistributionItem(
                'Féminin',
                _enseignantsFeminins,
                _totalEnseignants,
                Colors.pink,
              ),
            ],
            isDark,
            Symbols.wc,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _buildDistributionCard(
            'Répartition par Spécialité',
            _specialiteStats.entries
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
                          '${e.value} enseignant${e.value > 1 ? 's' : ''}',
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
            Symbols.school,
            Colors.teal,
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
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
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    List<Color> colors,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors[0].withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
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
          Icon(icon, color: Colors.white, size: 32),
        ],
      ),
    );
  }

  Widget _buildControls(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchTerm = val;
                  _filterTeachers();
                });
              },
              decoration: InputDecoration(
                hintText: 'Rechercher un enseignant...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildViewModeToggle('grid', Icons.grid_view_rounded, isDark),
                _buildViewModeToggle('list', Icons.view_list_rounded, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeToggle(String mode, IconData icon, bool isDark) {
    final isSelected = _viewMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _viewMode = mode),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white10 : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isSelected
              ? AppTheme.primaryColor
              : (isDark ? Colors.white54 : Colors.grey),
          size: 24,
        ),
      ),
    );
  }

  Widget _buildGridView(bool isDark) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: 1.2,
      ),
      itemCount: _filteredTeachers.length,
      itemBuilder: (context, index) =>
          _buildTeacherCard(_filteredTeachers[index], index, isDark),
    );
  }

  Widget _buildListView(bool isDark) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredTeachers.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _buildTeacherListTile(_filteredTeachers[index], index, isDark),
      ),
    );
  }

  Widget _buildTeacherCard(Enseignant teacher, int index, bool isDark) {
    final colors = [
      Colors.blue,
      Colors.teal,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.indigo,
    ];
    final color = colors[index % colors.length];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: color.withOpacity(0.1),
                      backgroundImage:
                          (teacher.photo != null && teacher.photo!.isNotEmpty)
                          ? (teacher.photo!.startsWith('/') ||
                                    teacher.photo!.contains(':\\')
                                ? FileImage(File(teacher.photo!))
                                      as ImageProvider
                                : AssetImage(teacher.photo!))
                          : null,
                      child: (teacher.photo == null || teacher.photo!.isEmpty)
                          ? Text(
                              teacher.nom[0] +
                                  (teacher.prenom.isNotEmpty
                                      ? teacher.prenom[0]
                                      : ''),
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            )
                          : null,
                    ),
                    if (teacher.sexe != null)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: teacher.sexe == 'M'
                                ? Colors.blue
                                : Colors.pink,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            teacher.sexe == 'M' ? Symbols.male : Symbols.female,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _openEditModal(teacher),
                      icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue.withOpacity(0.1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _handleDelete(teacher),
                      icon: const Icon(Icons.delete_rounded, color: Colors.red),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              teacher.nomComplet,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              teacher.specialite ?? 'Sans spécialité',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            // Afficher les classes assignées
            if (_teacherClasses[teacher.id] != null && _teacherClasses[teacher.id]!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Classes assignées:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _teacherClasses[teacher.id]!
                    .take(3) // Limiter à 3 classes pour éviter l'overflow
                    .map((classe) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: color.withOpacity(0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            classe['nom'],
                            style: TextStyle(
                              fontSize: 10,
                              color: color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ))
                    .toList(),
              ),
              if (_teacherClasses[teacher.id]!.length > 3)
                Text(
                  '+${_teacherClasses[teacher.id]!.length - 3} autres',
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ] else
              Text(
                'Aucune classe assignée',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            if (teacher.telephone != null && teacher.telephone!.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.phone_rounded, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    teacher.telephone!,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            if (teacher.email != null && teacher.email!.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.email_rounded, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      teacher.email!,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherListTile(Enseignant teacher, int index, bool isDark) {
    final colors = [
      Colors.blue,
      Colors.teal,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.indigo,
    ];
    final color = colors[index % colors.length];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withOpacity(0.1),
            backgroundImage:
                (teacher.photo != null && teacher.photo!.isNotEmpty)
                ? (teacher.photo!.startsWith('/') ||
                          teacher.photo!.contains(':\\')
                      ? FileImage(File(teacher.photo!)) as ImageProvider
                      : AssetImage(teacher.photo!))
                : null,
            child: (teacher.photo == null || teacher.photo!.isEmpty)
                ? Text(
                    teacher.nom[0],
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      teacher.nomComplet,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (teacher.sexe != null) ...[
                      const SizedBox(width: 8),
                      Icon(
                        teacher.sexe == 'M' ? Symbols.male : Symbols.female,
                        size: 14,
                        color: teacher.sexe == 'M' ? Colors.blue : Colors.pink,
                      ),
                    ],
                  ],
                ),
                Text(
                  teacher.specialite ?? 'Sans spécialité',
                  style: TextStyle(color: color, fontSize: 12),
                ),
                if (_teacherClasses[teacher.id] != null && _teacherClasses[teacher.id]!.isNotEmpty)
                  Text(
                    'Classes: ${_teacherClasses[teacher.id]!.map((c) => c['nom']).join(', ')}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            teacher.telephone ?? '',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(width: 16),
          Row(
            children: [
              IconButton(
                onPressed: () => _openEditModal(teacher),
                icon: const Icon(Icons.edit_rounded, color: Colors.blue),
              ),
              IconButton(
                onPressed: () => _handleDelete(teacher),
                icon: const Icon(Icons.delete_rounded, color: Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        children: [
          Icon(Symbols.person_off, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Aucun enseignant trouvé',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  void _openAddModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TeacherModal(onSuccess: _loadData),
    );
  }

  void _openEditModal(Enseignant teacher) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          TeacherModal(teacher: teacher, onSuccess: _loadData),
    );
  }

  void _handleDelete(Enseignant teacher) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation'),
        content: Text('Voulez-vous vraiment supprimer ${teacher.nomComplet} ?'),
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
      await DatabaseHelper.instance.deleteEnseignant(teacher.id!);
      _loadData();
    }
  }
}
