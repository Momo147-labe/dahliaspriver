import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import '../../../core/database/database_helper.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/academic_year_provider.dart';
import '../../../widgets/frais/frais_modal.dart';
import '../../../widgets/frais/frais_card.dart';

class FraisPage extends StatefulWidget {
  const FraisPage({super.key});

  @override
  State<FraisPage> createState() => _FraisPageState();
}

class _FraisPageState extends State<FraisPage> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _frais = [];
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _filteredFrais = [];
  final TextEditingController _searchController = TextEditingController();
  String _selectedClass = 'Toutes';
  String _selectedAnnee = 'Toutes';
  bool _isLoading = true;
  int? _lastLoadedAnneeId;

  // Modal states
  bool _showAddModal = false;
  bool _showEditModal = false;
  Map<String, dynamic> _newFrais = {};
  Map<String, dynamic> _editFraisData = {};

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _initializeNewFrais();
  }

  void _initializeNewFrais() {
    _newFrais = {
      'classe_id': null,
      'annee_scolaire_id': null,
      'inscription': 0.0,
      'reinscription': 0.0,
      'tranche1': 0.0,
      'date_limite_t1': '',
      'tranche2': 0.0,
      'date_limite_t2': '',
      'tranche3': 0.0,
      'date_limite_t3': '',
      'montant_total': 0.0,
    };
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
      final db = await DatabaseHelper.instance.database;

      // Charger les frais avec les informations de classe et d'année
      final fraisResult = await db.rawQuery(
        '''
        SELECT fs.*, c.nom as classe_nom, n.nom as classe_niveau, 
               an.libelle as annee_libelle
        FROM frais_scolarite fs
        LEFT JOIN classe c ON fs.classe_id = c.id
        LEFT JOIN niveaux n ON c.niveau_id = n.id
        LEFT JOIN annee_scolaire an ON fs.annee_scolaire_id = an.id
        WHERE fs.annee_scolaire_id = ?
        ORDER BY an.libelle DESC, c.nom ASC
      ''',
        [anneeId],
      );

      // Charger les classes avec leurs niveaux
      final classesResult = await db.rawQuery('''
        SELECT c.*, n.nom as niveau
        FROM classe c
        LEFT JOIN niveaux n ON c.niveau_id = n.id
        ORDER BY c.nom ASC
      ''');

      if (mounted) {
        setState(() {
          _frais = fraisResult;
          _classes = classesResult;
          _filterFrais();
          _isLoading = false;
        });
        _fadeController.forward(from: 0.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterFrais() {
    setState(() {
      _filteredFrais = _frais.where((frais) {
        final searchLower = _searchController.text.toLowerCase();
        final matchesSearch =
            (frais['classe_nom']?.toString().toLowerCase() ?? '').contains(
              searchLower,
            ) ||
            (frais['classe_niveau']?.toString().toLowerCase() ?? '').contains(
              searchLower,
            ) ||
            (frais['annee_libelle']?.toString().toLowerCase() ?? '').contains(
              searchLower,
            );

        final matchesClass =
            _selectedClass == 'Toutes' || frais['classe_nom'] == _selectedClass;

        final matchesAnnee =
            _selectedAnnee == 'Toutes' ||
            frais['annee_libelle'] == _selectedAnnee;

        return matchesSearch && matchesClass && matchesAnnee;
      }).toList();
    });
  }

  Future<void> _addFrais() async {
    try {
      final montantTotal =
          (_newFrais['inscription'] ?? 0.0) +
          (_newFrais['reinscription'] ?? 0.0) +
          (_newFrais['tranche1'] ?? 0.0) +
          (_newFrais['tranche2'] ?? 0.0) +
          (_newFrais['tranche3'] ?? 0.0);

      _newFrais['montant_total'] = montantTotal;

      final db = await DatabaseHelper.instance.database;
      await db.insert('frais_scolarite', _newFrais);

      setState(() => _showAddModal = false);
      if (_lastLoadedAnneeId != null) {
        await _loadData(_lastLoadedAnneeId!);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration des frais enregistrée'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateFrais() async {
    try {
      final montantTotal =
          (_editFraisData['inscription'] ?? 0.0) +
          (_editFraisData['reinscription'] ?? 0.0) +
          (_editFraisData['tranche1'] ?? 0.0) +
          (_editFraisData['tranche2'] ?? 0.0) +
          (_editFraisData['tranche3'] ?? 0.0);

      _editFraisData['montant_total'] = montantTotal;

      final db = await DatabaseHelper.instance.database;
      await db.update(
        'frais_scolarite',
        _editFraisData,
        where: 'id = ?',
        whereArgs: [_editFraisData['id']],
      );

      setState(() => _showEditModal = false);
      if (_lastLoadedAnneeId != null) {
        await _loadData(_lastLoadedAnneeId!);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Frais mis à jour avec succès'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteFrais(int id) async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Vérifier s'il y a des élèves associés
      final elevesResult = await db.query(
        'eleve',
        where: 'frais_id = ?',
        whereArgs: [id],
      );

      if (elevesResult.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Impossible de supprimer: déjà assigné à des élèves',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      await db.delete('frais_scolarite', where: 'id = ?', whereArgs: [id]);
      if (_lastLoadedAnneeId != null) {
        await _loadData(_lastLoadedAnneeId!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration supprimée'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openEditModal(Map<String, dynamic> frais) {
    setState(() {
      _editFraisData = Map.from(frais);
      _showEditModal = true;
    });
  }

  void _showMultiClassModal() async {
    final activeAnnee = await DatabaseHelper.instance.getActiveAnnee();
    if (activeAnnee == null) return;

    showDialog(
      context: context,
      builder: (context) => FraisModal(
        isEdit: false,
        frais: {
          'annee_scolaire_id': activeAnnee['id'],
          'inscription': 0.0,
          'reinscription': 0.0,
          'tranche1': 0.0,
          'tranche2': 0.0,
          'tranche3': 0.0,
        },
        classes: _classes,
        allowMultipleClasses: true,
        onSave: () {
          Navigator.of(context).pop();
          if (_lastLoadedAnneeId != null) {
            _loadData(_lastLoadedAnneeId!);
          }
        },
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(isDark),
                        const SizedBox(height: 32),
                        _buildStatsDashboard(isDark),
                        const SizedBox(height: 32),
                        _buildControls(isDark),
                        const SizedBox(height: 24),
                        _filteredFrais.isEmpty
                            ? _buildEmptyState(isDark)
                            : _buildFraisList(isDark),
                      ],
                    ),
                  ),
                ),
          if (_showAddModal) _buildAddModal(),
          if (_showEditModal) _buildEditModal(),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            onPressed: _showMultiClassModal,
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            heroTag: "multi",
            label: const Text('Multi-Classes'),
            icon: const Icon(Symbols.school),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            onPressed: () {
              _initializeNewFrais();
              setState(() => _showAddModal = true);
            },
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            heroTag: "single",
            label: const Text('Classe unique'),
            icon: const Icon(Symbols.add),
          ),
        ],
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, Colors.orange.shade600],
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
                Symbols.account_balance_wallet,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Frais de Scolarité',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    foreground: Paint()
                      ..shader =
                          LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              Colors.orange.shade700,
                            ],
                          ).createShader(
                            const Rect.fromLTWH(0.0, 0.0, 400.0, 70.0),
                          ),
                  ),
                ),
                Text(
                  'Configurez et suivez les montants d\'inscription et les tranches par classe',
                  style: TextStyle(
                    fontSize: 18,
                    color: isDark ? Colors.white70 : Colors.blueGrey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsDashboard(bool isDark) {
    final totalClasses = _classes.length;
    final classesWithFrais = _frais.map((f) => f['classe_id']).toSet().length;
    final totalMontant = _frais.fold<double>(
      0.0,
      (sum, frais) => sum + (frais['montant_total'] ?? 0.0),
    );
    final avgMontant = classesWithFrais > 0
        ? totalMontant / _frais.length
        : 0.0;

    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 4,
      crossAxisSpacing: 24,
      mainAxisSpacing: 24,
      childAspectRatio: 1.8,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          'Total Classes',
          totalClasses.toString(),
          Symbols.school,
          [Colors.blue.shade500, Colors.blue.shade700],
          isDark,
        ),
        _buildStatCard(
          'Classes Configurées',
          classesWithFrais.toString(),
          Symbols.check_circle,
          [Colors.green.shade500, Colors.green.shade700],
          isDark,
        ),
        _buildStatCard(
          'Moyenne Scolarité',
          '${avgMontant.toStringAsFixed(0)} FG',
          Symbols.trending_up,
          [Colors.orange.shade500, Colors.orange.shade700],
          isDark,
        ),
        _buildStatCard(
          'Config. Actives',
          _frais.length.toString(),
          Symbols.settings,
          [Colors.purple.shade500, Colors.purple.shade700],
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
              controller: _searchController,
              onChanged: (_) => _filterFrais(),
              decoration: InputDecoration(
                hintText: 'Rechercher par classe, niveau ou année...',
                prefixIcon: const Icon(Symbols.search),
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
            value: _selectedClass,
            items: [
              'Toutes',
              ..._classes.map((c) => c['nom'] as String),
            ].toSet().toList(),
            onChanged: (val) {
              setState(() {
                _selectedClass = val!;
                _filterFrais();
              });
            },
            isDark: isDark,
            label: 'Classe',
          ),
          const SizedBox(width: 16),
          _buildDropdownControl(
            value: _selectedAnnee,
            items: [
              'Toutes',
              ..._frais.map((f) => f['annee_libelle'] as String).toSet(),
            ].toList(),
            onChanged: (val) {
              setState(() {
                _selectedAnnee = val!;
                _filterFrais();
              });
            },
            isDark: isDark,
            label: 'Année',
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownControl({
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
    required bool isDark,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          hint: Text(label),
          items: items.map((e) {
            return DropdownMenuItem(value: e, child: Text(e));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildFraisList(bool isDark) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredFrais.length,
      itemBuilder: (context, index) {
        final frais = _filteredFrais[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: FraisCard(
            frais: frais,
            onEdit: () => _openEditModal(frais),
            onDelete: () => _showDeleteConfirmation(frais['id']),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          children: [
            Icon(
              Symbols.search_off,
              size: 80,
              color: isDark ? Colors.white24 : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune configuration trouvée',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white54 : Colors.grey[500],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajustez vos filtres ou ajoutez une nouvelle configuration',
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text(
          'Voulez-vous vraiment supprimer cette configuration de frais ? Elle ne doit pas être utilisée par des élèves.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteFrais(id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Widget _buildAddModal() {
    return FraisModal(
      isEdit: false,
      frais: _newFrais,
      classes: _classes,
      onSave: _addFrais,
      onClose: () => setState(() => _showAddModal = false),
    );
  }

  Widget _buildEditModal() {
    return FraisModal(
      isEdit: true,
      frais: _editFraisData,
      classes: _classes,
      onSave: _updateFrais,
      onClose: () => setState(() => _showEditModal = false),
    );
  }
}
