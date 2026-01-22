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
  String _modeCalcul = 'trimestrielle';
  bool _includeConduite = true;

  List<Map<String, dynamic>> _cycles = [];
  int? _selectedCycleId;
  List<Map<String, dynamic>> _mentions = [];

  int? _configEcoleId;

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
        // Configuration école
        final configEcole = await _db.getConfigurationEcole(annee['id']);
        if (configEcole != null) {
          _configEcoleId = configEcole['id'];
          _baseNotation = (configEcole['base_notation'] ?? 20.0).toDouble();
          _modeCalcul = configEcole['mode_calcul_moyenne'] ?? 'trimestrielle';
          _includeConduite = (configEcole['include_conduite'] ?? 1) == 1;
        }

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
    final mentions = await _db.getMentionsByCycle(_selectedCycleId);
    setState(() {
      _mentions = List<Map<String, dynamic>>.from(mentions);
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      final annee = await _db.getActiveAnnee();
      if (annee == null) return;

      final configData = {
        'annee_scolaire_id': annee['id'],
        'base_notation': _baseNotation,
        'mode_calcul_moyenne': _modeCalcul,
        'include_conduite': _includeConduite ? 1 : 0,
      };

      if (_configEcoleId != null) {
        await _db.updateConfigurationEcole(_configEcoleId!, configData);
      } else {
        await _db.saveConfigurationEcole(configData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paramètres enregistrés avec succès'),
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Colonne Gauche: Configuration Fondamentale
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    _buildFundamentalConfigCard(isDark),
                    const SizedBox(height: 24),
                    _buildConduiteCard(isDark),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Colonne Droite: Mentions
              Expanded(flex: 2, child: _buildMentionsCard(isDark)),
            ],
          ),
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
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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

  Widget _buildFundamentalConfigCard(bool isDark) {
    return _buildPremiumCard(
      title: 'Configuration Fondamentale',
      icon: Icons.settings_suggest,
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Base de notation globale',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [10, 20, 100].map((base) {
                bool isSelected = _baseNotation == base.toDouble();
                return Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _baseNotation = base.toDouble()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          'Sur $base',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.grey : Colors.black87),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Mode de calcul des moyennes',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              _buildRadioOption('Trimestrielle', 'trimestrielle', isDark),
              _buildRadioOption('Semestrielle', 'semestrielle', isDark),
              _buildRadioOption('Annuelle uniquement', 'annuelle', isDark),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Enregistrer les modifications'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOption(String label, String value, bool isDark) {
    bool isSelected = _modeCalcul == value;
    return GestureDetector(
      onTap: () => setState(() => _modeCalcul = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : (isDark ? Colors.white12 : Colors.grey[300]!),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.primaryColor : Colors.grey,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? AppTheme.primaryColor
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConduiteCard(bool isDark) {
    return _buildPremiumCard(
      title: 'Comportement & Conduite',
      icon: Icons.gavel_rounded,
      isDark: isDark,
      iconColor: Colors.orange,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Inclure la note de conduite',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'La note de conduite sera comptabilisée dans la moyenne générale.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _includeConduite,
                onChanged: (v) => setState(() => _includeConduite = v),
                activeColor: AppTheme.primaryColor,
              ),
            ],
          ),
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
          // En-tête de section avec sélecteur de cycle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Seuils & Appréciations',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
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
                ..._mentions
                    .map(
                      (m) => _MentionCard(
                        key: ValueKey('mention_${m['id']}'),
                        mention: m,
                        isDark: isDark,
                        baseNotation: _baseNotation,
                        onChanged: (key, val) =>
                            _updateMentionValue(m['id'], key, val),
                        onEdit: () => _showEditMentionDialog(m),
                        onDelete: () => _deleteMention(m['id']),
                      ),
                    )
                    .toList(),
                const SizedBox(height: 12),
                _buildAddMentionButton(isDark),
              ],
            ),
        ],
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

  Future<void> _updateMentionValue(int id, String key, dynamic value) async {
    final index = _mentions.indexWhere((m) => m['id'] == id);
    if (index != -1) {
      final updated = {..._mentions[index], key: value};
      setState(() {
        _mentions[index] = updated;
      });
      // Save to DB (non-blocking)
      _db.saveMention(updated);
    }
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
                    m['label'][0], // Première lettre
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
      builder: (context) => AlertDialog(
        title: Text(
          mention == null ? 'Ajouter une mention' : 'Modifier la mention',
        ),
        content: Column(
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
                    decoration: const InputDecoration(labelText: 'Note Min'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: maxCtrl,
                    decoration: const InputDecoration(labelText: 'Note Max'),
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
            const Text('Icône', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: ['excellent', 'star', 'thumb', 'medal'].map((icon) {
                return GestureDetector(
                  onTap: () => setState(() => selectedIcon = icon),
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
                      onTap: () => setState(() => selectedColor = hex),
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
              if (mounted) Navigator.pop(context);
              _loadMentions();
            },
            child: const Text('Enregistrer'),
          ),
        ],
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

    final defaults = [
      {
        'label': 'Excellent',
        'note_min': 16.0,
        'note_max': 20.0,
        'couleur': '#9C27B0',
        'icone': 'excellent',
        'appreciation': 'Félicitations du conseil de classe.',
      },
      {
        'label': 'Très bien',
        'note_min': 14.0,
        'note_max': 16.0,
        'couleur': '#4CAF50',
        'icone': 'star',
        'appreciation': 'Travail d\'une grande rigueur. Continuez ainsi.',
      },
      {
        'label': 'Bien',
        'note_min': 12.0,
        'note_max': 14.0,
        'couleur': '#2196F3',
        'icone': 'thumb',
        'appreciation': 'Bon travail, des efforts à poursuivre.',
      },
      {
        'label': 'Assez bien',
        'note_min': 10.0,
        'note_max': 12.0,
        'couleur': '#00BCD4',
        'icone': 'medal',
        'appreciation': 'Résultats satisfaisants.',
      },
      {
        'label': 'Passable',
        'note_min': 8.0,
        'note_max': 10.0,
        'couleur': '#FF9800',
        'icone': 'star',
        'appreciation': 'Résultats justes, redoublez d\'efforts.',
      },
      {
        'label': 'Insuffisant',
        'note_min': 0.0,
        'note_max': 8.0,
        'couleur': '#F44336',
        'icone': 'star',
        'appreciation': 'Travail insuffisant.',
      },
    ];

    for (var m in defaults) {
      await _db.saveMention({...m, 'cycle_id': _selectedCycleId});
    }
    _loadMentions();
  }
}

class _MentionCard extends StatefulWidget {
  final Map<String, dynamic> mention;
  final bool isDark;
  final double baseNotation;
  final Function(String, dynamic) onChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MentionCard({
    super.key,
    required this.mention,
    required this.isDark,
    required this.baseNotation,
    required this.onChanged,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_MentionCard> createState() => _MentionCardState();
}

class _MentionCardState extends State<_MentionCard> {
  late TextEditingController _appreciationController;

  @override
  void initState() {
    super.initState();
    _appreciationController = TextEditingController(
      text: widget.mention['appreciation'] ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _MentionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mention['appreciation'] != widget.mention['appreciation']) {
      if (_appreciationController.text != widget.mention['appreciation']) {
        _appreciationController.text = widget.mention['appreciation'] ?? '';
      }
    }
  }

  @override
  void dispose() {
    _appreciationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.mention;
    final isDark = widget.isDark;
    final color = _parseColor(m['couleur'] ?? '#2196F3');
    final noteMin = (m['note_min'] as num?)?.toDouble() ?? 0.0;
    final label = m['label'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
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
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_getIconData(m['icone']), color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Text(
                'SEUIL MIN : ',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Text(
                  noteMin.toStringAsFixed(1),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '/ ${widget.baseNotation.toInt()}',
                style: TextStyle(
                  color: color.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.1),
              thumbColor: color,
              overlayColor: color.withOpacity(0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: noteMin.clamp(0.0, widget.baseNotation),
              min: 0,
              max: widget.baseNotation,
              onChanged: (val) => widget.onChanged('note_min', val),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'APPRÉCIATION PAR DÉFAUT',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey[200]!,
              ),
            ),
            child: TextField(
              controller: _appreciationController,
              maxLines: 2,
              onChanged: (val) => widget.onChanged('appreciation', val),
              style: const TextStyle(fontSize: 14, height: 1.4),
              decoration: const InputDecoration(
                hintText: 'Saisissez l\'appréciation par défaut...',
                border: InputBorder.none,
                isDense: true,
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: widget.onEdit,
                icon: Icon(
                  Icons.settings_outlined,
                  size: 18,
                  color: Colors.grey[400],
                ),
                tooltip: 'Paramètres avancés',
              ),
              IconButton(
                onPressed: widget.onDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Colors.red[300],
                ),
                tooltip: 'Supprimer',
              ),
            ],
          ),
        ],
      ),
    );
  }
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

Color _parseColor(String hex) {
  try {
    return Color(int.parse(hex.replaceAll('#', '0xFF')));
  } catch (e) {
    return Colors.grey;
  }
}
