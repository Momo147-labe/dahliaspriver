import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/database/database_helper.dart';
import '../../../models/matiere.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/school/add_subject_modal.dart';

class SubjectsPage extends StatefulWidget {
  const SubjectsPage({super.key});

  @override
  State<SubjectsPage> createState() => _SubjectsPageState();
}

class _SubjectsPageState extends State<SubjectsPage>
    with SingleTickerProviderStateMixin {
  List<Matiere> _subjects = [];
  List<Matiere> _filteredSubjects = [];
  List<Map<String, dynamic>> _statsData = [];
  bool _isLoading = true;
  String _searchTerm = '';
  String _sortBy = 'nom';
  bool _isAscending = true;
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
      final anneeId = await db.ensureActiveAnneeCached();
      if (anneeId == null) {
        setState(() => _isLoading = false);
        return;
      }
      // Fetch subjects with coefficients
      final subjects = await db.getMatieresByAnnee(anneeId);
      final stats = await db.getMatieresStats();

      if (mounted) {
        setState(() {
          _subjects = subjects;
          _statsData = stats;
          _filterAndSortSubjects();
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

  void _filterAndSortSubjects() {
    List<Matiere> filtered = _subjects.where((s) {
      return s.nom.toLowerCase().contains(_searchTerm.toLowerCase());
    }).toList();

    filtered.sort((a, b) {
      int comparison = 0;
      if (_sortBy == 'nom') {
        comparison = a.nom.compareTo(b.nom);
      } else if (_sortBy == 'classes') {
        final aStats = _statsData.firstWhere(
          (s) => s['id'] == a.id,
          orElse: () => {},
        );
        final bStats = _statsData.firstWhere(
          (s) => s['id'] == b.id,
          orElse: () => {},
        );
        comparison = (aStats['classes_count'] ?? 0).compareTo(
          bStats['classes_count'] ?? 0,
        );
      }
      return _isAscending ? comparison : -comparison;
    });

    setState(() {
      _filteredSubjects = filtered;
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
                  const SizedBox(height: 32),
                  _buildControls(isDark),
                  const SizedBox(height: 32),
                  _filteredSubjects.isEmpty
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryColor, Colors.purple.shade600],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Symbols.book_3,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gestion des Matières',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      foreground: Paint()
                        ..shader =
                            LinearGradient(
                              colors: [
                                AppTheme.primaryColor,
                                Colors.purple.shade600,
                                Colors.pink.shade500,
                              ],
                            ).createShader(
                              const Rect.fromLTWH(0.0, 0.0, 400.0, 70.0),
                            ),
                    ),
                  ),
                  Text(
                    'Organisez et gérez les matières enseignées dans votre école',
                    style: TextStyle(
                      fontSize: 18,
                      color: isDark ? Colors.white70 : Colors.blueGrey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () => _openAddModal(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Ajouter une matière'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 8,
              shadowColor: AppTheme.primaryColor.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(bool isDark) {
    final totalSubjects = _subjects.length;
    final activeClasses = _statsData.fold<int>(
      0,
      (sum, item) => sum + (item['classes_count'] as int? ?? 0),
    );

    // Find most used subject
    Matiere? mostUsed;
    int maxClasses = -1;
    for (var s in _subjects) {
      final stats = _statsData.firstWhere(
        (item) => item['id'] == s.id,
        orElse: () => {},
      );
      final count = stats['classes_count'] as int? ?? 0;
      if (count > maxClasses) {
        maxClasses = count;
        mostUsed = s;
      }
    }

    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      crossAxisSpacing: 24,
      mainAxisSpacing: 24,
      childAspectRatio: 1.8,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          'Total Matières',
          totalSubjects.toString(),
          Symbols.book_2,
          [Colors.blue.shade500, Colors.blue.shade700],
          isDark,
        ),
        _buildStatCard(
          'Classes Actives',
          activeClasses.toString(),
          Symbols.groups,
          [Colors.green.shade500, Colors.green.shade700],
          isDark,
        ),
        _buildStatCard(
          'Plus Utilisée',
          mostUsed?.nom ?? 'N/A',
          Symbols.trophy,
          [Colors.orange.shade500, Colors.red.shade600],
          isDark,
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
          Expanded(
            child: Column(
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
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
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
                  _filterAndSortSubjects();
                });
              },
              decoration: InputDecoration(
                hintText: 'Rechercher une matière...',
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
          _buildDropdownControl(
            value: _sortBy,
            items: {'nom': 'Trier par nom', 'classes': 'Trier par classes'},
            onChanged: (val) {
              setState(() {
                _sortBy = val!;
                _filterAndSortSubjects();
              });
            },
            isDark: isDark,
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            onPressed: () {
              setState(() {
                _isAscending = !_isAscending;
                _filterAndSortSubjects();
              });
            },
            icon: Icon(
              _isAscending
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
            ),
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(width: 12),
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

  Widget _buildDropdownControl({
    required String value,
    required Map<String, String> items,
    required Function(String?) onChanged,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items.entries.map((e) {
            return DropdownMenuItem(value: e.key, child: Text(e.value));
          }).toList(),
          onChanged: onChanged,
        ),
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
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
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
        crossAxisCount: 6,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: _filteredSubjects.length,
      itemBuilder: (context, index) {
        return _buildSubjectCard(_filteredSubjects[index], index, isDark);
      },
    );
  }

  Widget _buildListView(bool isDark) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredSubjects.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildSubjectListTile(_filteredSubjects[index], index, isDark),
        );
      },
    );
  }

  Widget _buildSubjectCard(Matiere subject, int index, bool isDark) {
    final colors = [
      [Colors.blue.shade500, Colors.blue.shade700],
      [Colors.green.shade500, Colors.green.shade700],
      [Colors.purple.shade500, Colors.purple.shade700],
      [Colors.pink.shade500, Colors.pink.shade700],
      [Colors.orange.shade500, Colors.orange.shade700],
      [Colors.indigo.shade500, Colors.indigo.shade700],
    ];
    final colorPair = colors[index % colors.length];
    final stats = _statsData.firstWhere(
      (s) => s['id'] == subject.id,
      orElse: () => {},
    );
    final classesCount = stats['classes_count'] ?? 0;

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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colorPair),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: colorPair
                                .map((c) => c.withOpacity(0.1))
                                .toList(),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Symbols.menu_book,
                          color: colorPair[0],
                          size: 20,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => _openEditModal(subject),
                            icon: const Icon(
                              Icons.edit_rounded,
                              color: Colors.blue,
                              size: 18,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.blue.withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(32, 32),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () => _handleDelete(subject),
                            icon: const Icon(
                              Icons.delete_rounded,
                              color: Colors.red,
                              size: 18,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.red.withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(32, 32),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    subject.nom,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.blueGrey.shade900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$classesCount classe${classesCount > 1 ? 's' : ''}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectListTile(Matiere subject, int index, bool isDark) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.pink,
      Colors.orange,
      Colors.indigo,
    ];
    final color = colors[index % colors.length];
    final stats = _statsData.firstWhere(
      (s) => s['id'] == subject.id,
      orElse: () => {},
    );
    final classesCount = stats['classes_count'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Symbols.menu_book, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.nom,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$classesCount classe${classesCount > 1 ? 's' : ''}',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => _openEditModal(subject),
                icon: const Icon(Icons.edit_rounded, color: Colors.blue),
              ),
              IconButton(
                onPressed: () => _handleDelete(subject),
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
          Icon(
            Symbols.search_off,
            size: 80,
            color: isDark ? Colors.white24 : Colors.blueGrey.shade100,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune matière trouvée',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Réessayez avec un autre terme ou ajoutez une nouvelle matière.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  void _openAddModal() {
    showDialog(
      context: context,
      builder: (context) => AddSubjectModal(onSuccess: () => _loadData()),
    );
  }

  void _openEditModal(Matiere subject) {
    showDialog(
      context: context,
      builder: (context) =>
          AddSubjectModal(subject: subject, onSuccess: () => _loadData()),
    );
  }

  Future<void> _handleDelete(Matiere subject) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
          'Voulez-vous vraiment supprimer la matière "${subject.nom}" ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseHelper.instance.deleteMatiere(subject.id!);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Matière supprimée avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la suppression: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
