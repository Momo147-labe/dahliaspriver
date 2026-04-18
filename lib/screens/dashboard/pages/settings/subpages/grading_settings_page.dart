import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../core/database/database_helper.dart';

class GradingSettingsPage extends StatefulWidget {
  const GradingSettingsPage({super.key});

  @override
  State<GradingSettingsPage> createState() => _GradingSettingsPageState();
}

class _GradingSettingsPageState extends State<GradingSettingsPage> {
  final _db = DatabaseHelper.instance;
  bool _isLoading = true;

  double _baseNotation = 20.0;

  List<Map<String, dynamic>> _cycles = [];
  int? _selectedCycleId;
  List<Map<String, dynamic>> _mentions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final annee = await _db.getActiveAnnee();
      if (annee != null) {
        // Cycles
        _cycles = await _db.getCyclesScolaires();
        if (_cycles.isNotEmpty) {
          _selectedCycleId = _cycles.first['id'];
          await _loadMentions();
        }
      }
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading grading data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMentions() async {
    if (_selectedCycleId == null) return;

    // Load cycle data to get its specific note_max
    final cycle = await _db.configDao.getCycleById(_selectedCycleId!);
    if (cycle != null) {
      _baseNotation = (cycle['note_max'] as num?)?.toDouble() ?? 20.0;
    }

    final mentions = await _db.getMentionsByCycle(_selectedCycleId);
    setState(() {
      _mentions = List<Map<String, dynamic>>.from(mentions);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(),
          const SizedBox(height: 24),
          _buildMentionsCard(isDark),
          const SizedBox(height: 32),
          Center(
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tous les paramètres ont été enregistrés'),
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  );
                },
                icon: const Icon(Icons.save),
                label: const Text(
                  'Sauvegarder les modifications',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 100), // Extra space for scrolling
        ],
      ),
    );
  }

  Widget _buildPageHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Paramètres',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            const Text(
              'Système de Notation',
              style: TextStyle(color: AppTheme.primaryColor, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Système de Notation',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildPremiumCard({
    required String title,
    required IconData icon,
    required Widget child,
    required bool isDark,
    Color? iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (iconColor ?? AppTheme.primaryColor).withOpacity(
                      0.1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }

  Widget _buildMentionsCard(bool isDark) {
    return _buildPremiumCard(
      title: 'Appréciations & Mentions',
      icon: Icons.workspace_premium_rounded,
      isDark: isDark,
      iconColor: Colors.purple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de section avec sélecteurs
          Wrap(
            spacing: 24,
            runSpacing: 16,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Seuils & Appréciations',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Configurez les mentions pour chaque cycle',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sélecteur de Cycle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedCycleId,
                        items: _cycles.map((c) {
                          return DropdownMenuItem<int>(
                            value: c['id'],
                            child: Text(c['nom']),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedCycleId = val);
                          _loadMentions();
                        },
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Sélecteur de Base de Notation
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [10, 20].map((base) {
                        bool isSelected = _baseNotation == base.toDouble();
                        return GestureDetector(
                          onTap: () async {
                            if (_selectedCycleId != null) {
                              setState(() => _baseNotation = base.toDouble());
                              final cycle = _cycles.firstWhere(
                                (c) => c['id'] == _selectedCycleId,
                              );
                              await _db.configDao.updateCycle(
                                _selectedCycleId!,
                                {...cycle, 'note_max': base.toDouble()},
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Base de notation mise à jour',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                              _cycles = await _db.getCyclesScolaires();
                              _loadMentions(); // Reload to refresh relative ranges
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '/$base',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? Colors.grey : Colors.black54),
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Barre de prévisualisation visuelle
          const Text(
            'Aperçu visuel des seuils',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 12),
          _buildVisualBarPreview(),
          const SizedBox(height: 32),
          // Liste des mentions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Configuration des mentions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              TextButton.icon(
                onPressed: _showAddMentionDialog,
                icon: const Icon(Icons.add),
                label: const Text('Nouvelle mention'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_mentions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Aucune mention configurée pour ce cycle.',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _seedDefaultMentions,
                      child: const Text('Générer les mentions par défaut'),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                _buildMentionsTable(isDark),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: _buildAddMentionButton(isDark)),
                    const SizedBox(width: 12),
                    _buildActionButton(
                      icon: Icons.auto_awesome_outlined,
                      tooltip: 'Générer par défaut',
                      onTap: _seedDefaultMentions,
                      isDark: isDark,
                      color: Colors.purple,
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: Icons.delete_sweep_outlined,
                      tooltip: 'Tout effacer',
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Confirmer'),
                            content: const Text(
                              'Voulez-vous vraiment supprimer toutes les mentions de ce cycle ?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Annuler'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Supprimer tout'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          for (var m in _mentions) {
                            await _db.deleteMention(m['id']);
                          }
                          _loadMentions();
                        }
                      },
                      isDark: isDark,
                      color: Colors.red,
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMentionsTable(bool isDark) {
    if (_mentions.isEmpty) return const SizedBox.shrink();

    // Sort mentions by note_min descending for the table
    final sorted = List<Map<String, dynamic>>.from(_mentions)
      ..sort((a, b) => (b['note_min'] as num).compareTo(a['note_min'] as num));

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth:
                  MediaQuery.of(context).size.width -
                  88, // 24*2 (padding) + 20*2 (card padding)
            ),
            child: DataTable(
              columnSpacing: 24,
              headingRowColor: WidgetStateProperty.all(
                isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
              ),
              columns: [
                DataColumn(
                  label: Text(
                    'Moyenne /${_baseNotation.toInt()}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Mention',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Appréciation Type',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Actions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              rows: sorted.map((m) {
                final color = _parseColor(m['couleur'] ?? '#2196F3');
                final noteMin = (m['note_min'] as num?)?.toDouble() ?? 0.0;
                final noteMax =
                    (m['note_max'] as num?)?.toDouble() ?? _baseNotation;

                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        '${noteMin.toStringAsFixed(1)} à < ${noteMax.toStringAsFixed(1)}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            m['label'] ?? '',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Text(
                          m['appreciation'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _showEditMentionDialog(m),
                            tooltip: 'Modifier',
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Colors.red[300],
                            ),
                            onPressed: () => _deleteMention(m['id']),
                            tooltip: 'Supprimer',
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
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
      ),
    );
  }

  Widget _buildAddMentionButton(bool isDark) {
    return InkWell(
      onTap: _showAddMentionDialog,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.grey[300]!,
            style: BorderStyle
                .solid, // I'll use a custom painter for dashed if needed, but solid is fine for now
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: Colors.grey[500], size: 20),
            const SizedBox(width: 8),
            Text(
              'Ajouter une nouvelle mention',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualBarPreview() {
    if (_mentions.isEmpty)
      return Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
      );

    // Trier les mentions par note_min ascendante pour l'affichage
    final sorted = List<Map<String, dynamic>>.from(_mentions)
      ..sort((a, b) => (a['note_min'] as num).compareTo(b['note_min']));

    return Container(
      height: 40,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: sorted.map((m) {
            double min = (m['note_min'] as num).toDouble();
            double max = (m['note_max'] as num).toDouble();
            double weight = (max - min);
            if (weight <= 0) weight = 0.1;

            Color color = _parseColor(m['couleur'] ?? '#CCCCCC');

            return Expanded(
              flex: (weight * 10).toInt(),
              child: Container(
                color: color,
                child: Center(
                  child: Text(
                    m['label'].runes.isNotEmpty
                        ? String.fromCharCode(m['label'].runes.first)
                        : '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
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

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }

  void _showAddMentionDialog() {
    _showMentionDialog(null);
  }

  void _showEditMentionDialog(Map<String, dynamic> mention) {
    _showMentionDialog(mention);
  }

  void _showMentionDialog(Map<String, dynamic>? mention) {
    final labelCtrl = TextEditingController(text: mention?['label'] ?? '');
    final minCtrl = TextEditingController(
      text: mention?['note_min']?.toString() ?? '',
    );
    final maxCtrl = TextEditingController(
      text: mention?['note_max']?.toString() ?? '',
    );
    final appreciationCtrl = TextEditingController(
      text: mention?['appreciation'] ?? '',
    );
    String selectedColor = mention?['couleur'] ?? '#2196F3';
    String selectedIcon = mention?['icone'] ?? 'star';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              mention == null ? 'Ajouter une mention' : 'Modifier la mention',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Libellé (ex: Excellent)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Note Min',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: maxCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Note Max',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: appreciationCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Appréciation par défaut',
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Sélecteur d'icône
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Icône', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    children: ['excellent', 'star', 'thumb', 'medal'].map((
                      icon,
                    ) {
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedIcon = icon),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: selectedIcon == icon
                                ? AppTheme.primaryColor.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selectedIcon == icon
                                  ? AppTheme.primaryColor
                                  : Colors.grey[300]!,
                            ),
                          ),
                          child: Icon(
                            _getIconData(icon),
                            size: 20,
                            color: selectedIcon == icon
                                ? AppTheme.primaryColor
                                : Colors.grey,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  // Sélecteur de couleur simplifié
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Couleur', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children:
                        [
                          '#F44336',
                          '#FF9800',
                          '#FFEB3B',
                          '#4CAF50',
                          '#2196F3',
                          '#9C27B0',
                          '#795548',
                        ].map((hex) {
                          return GestureDetector(
                            onTap: () =>
                                setDialogState(() => selectedColor = hex),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: _parseColor(hex),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selectedColor == hex
                                      ? Colors.black
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newMention = {
                    if (mention != null) 'id': mention['id'],
                    'label': labelCtrl.text,
                    'note_min': double.tryParse(minCtrl.text) ?? 0.0,
                    'note_max': double.tryParse(maxCtrl.text) ?? 0.0,
                    'appreciation': appreciationCtrl.text,
                    'icone': selectedIcon,
                    'couleur': selectedColor,
                    'cycle_id': _selectedCycleId,
                  };
                  await _db.saveMention(newMention);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Mention enregistrée avec succès'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadMentions();
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteMention(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer cette mention ?'),
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

    if (confirm == true) {
      await _db.deleteMention(id);
      _loadMentions();
    }
  }

  Future<void> _seedDefaultMentions() async {
    if (_selectedCycleId == null) return;

    final List<Map<String, dynamic>> defaults;

    if (_baseNotation == 10.0) {
      defaults = [
        {
          'label': 'Très Bien',
          'note_min': 9.0,
          'note_max': 10.0,
          'couleur': '#9C27B0',
          'icone': 'excellent',
          'appreciation': 'Excellent travail, continue ainsi',
        },
        {
          'label': 'Bien',
          'note_min': 8.0,
          'note_max': 9.0,
          'couleur': '#4CAF50',
          'icone': 'star',
          'appreciation': 'Bon travail, quelques efforts encore',
        },
        {
          'label': 'Assez Bien',
          'note_min': 7.0,
          'note_max': 8.0,
          'couleur': '#2196F3',
          'icone': 'thumb',
          'appreciation': 'Travail satisfaisant, peut mieux faire',
        },
        {
          'label': 'Passable',
          'note_min': 5.0,
          'note_max': 7.0,
          'couleur': '#FF9800',
          'icone': 'medal',
          'appreciation': 'Résultats moyens, doit faire plus d’efforts',
        },
        {
          'label': 'Insuffisant',
          'note_min': 0.0,
          'note_max': 5.0,
          'couleur': '#F44336',
          'icone': 'star',
          'appreciation': 'Travail insuffisant, beaucoup d’efforts nécessaires',
        },
      ];
    } else {
      // Default to /20 barème
      defaults = [
        {
          'label': 'Très Bien',
          'note_min': 16.0,
          'note_max': 20.0,
          'couleur': '#9C27B0',
          'icone': 'excellent',
          'appreciation': 'Excellent travail, élève sérieux et régulier',
        },
        {
          'label': 'Bien',
          'note_min': 14.0,
          'note_max': 16.0,
          'couleur': '#4CAF50',
          'icone': 'star',
          'appreciation': 'Bon niveau, participation active',
        },
        {
          'label': 'Assez Bien',
          'note_min': 12.0,
          'note_max': 14.0,
          'couleur': '#2196F3',
          'icone': 'thumb',
          'appreciation': 'Ensemble satisfaisant, peut progresser',
        },
        {
          'label': 'Passable',
          'note_min': 10.0,
          'note_max': 12.0,
          'couleur': '#FF9800',
          'icone': 'medal',
          'appreciation': 'Niveau juste, manque d’efforts',
        },
        {
          'label': 'Insuffisant',
          'note_min': 0.0,
          'note_max': 10.0,
          'couleur': '#F44336',
          'icone': 'star',
          'appreciation': 'Résultats faibles, travail insuffisant',
        },
      ];
    }

    for (var m in defaults) {
      await _db.saveMention({...m, 'cycle_id': _selectedCycleId});
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mentions par défaut générées'),
          backgroundColor: Colors.green,
        ),
      );
    }
    _loadMentions();
  }

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'excellent':
        return Icons.workspace_premium;
      case 'star':
        return Icons.stars;
      case 'thumb':
        return Icons.thumb_up;
      case 'medal':
        return Icons.military_tech;
      default:
        return Icons.stars;
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required bool isDark,
    required Color color,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}
