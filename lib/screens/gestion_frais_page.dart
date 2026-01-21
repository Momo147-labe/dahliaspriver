import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/database/database_helper.dart';
import '../../theme/app_theme.dart';
import '../../widgets/frais/frais_modal.dart';

class GestionFraisPage extends StatefulWidget {
  const GestionFraisPage({super.key});

  @override
  State<GestionFraisPage> createState() => _GestionFraisPageState();
}

class _GestionFraisPageState extends State<GestionFraisPage> {
  List<Map<String, dynamic>> _classesWithFrais = [];
  List<Map<String, dynamic>> _allClasses = [];
  Map<String, dynamic>? _activeAnnee;
  Map<String, dynamic>? _fraisStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final activeAnnee = await DatabaseHelper.instance.getActiveAnnee();
      if (activeAnnee != null) {
        final classesWithFrais = await DatabaseHelper.instance.getClassesWithFrais(activeAnnee['id']);
        final allClasses = await DatabaseHelper.instance.getClassesByAnnee(activeAnnee['id']);
        final fraisStats = await DatabaseHelper.instance.getFraisStatistics(activeAnnee['id']);
        
        setState(() {
          _activeAnnee = activeAnnee;
          _classesWithFrais = classesWithFrais;
          _allClasses = allClasses;
          _fraisStats = fraisStats;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMultiClasseModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => FraisModal(
        isEdit: false,
        frais: {
          'annee_scolaire_id': _activeAnnee!['id'],
          'inscription': 0.0,
          'reinscription': 0.0,
          'tranche1': 0.0,
          'tranche2': 0.0,
          'tranche3': 0.0,
        },
        classes: _allClasses,
        allowMultipleClasses: true,
        onSave: () {
          Navigator.of(context).pop();
          _loadData();
        },
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  void _showEditFraisModal(Map<String, dynamic> frais) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => FraisModal(
        isEdit: true,
        frais: Map<String, dynamic>.from(frais),
        classes: _allClasses,
        onSave: () async {
          try {
            await DatabaseHelper.instance.update(
              'frais_scolarite',
              frais,
              'id = ?',
              [frais['frais_id']],
            );
            if (mounted) {
              Navigator.of(context).pop();
              _loadData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Frais mis à jour avec succès'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erreur: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  Future<void> _duplicateFrais(Map<String, dynamic> sourceFrais) async {
    final availableClasses = _classesWithFrais
        .where((c) => c['frais_id'] == null)
        .toList();

    if (availableClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Toutes les classes ont déjà des frais configurés'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedClasses = await showDialog<List<int>>(
      context: context,
      builder: (context) => _ClassSelectionDialog(
        classes: availableClasses,
        title: 'Dupliquer vers les classes',
      ),
    );

    if (selectedClasses != null && selectedClasses.isNotEmpty) {
      try {
        await DatabaseHelper.instance.duplicateFraisToClasses(
          sourceFrais['id'],
          selectedClasses,
          _activeAnnee!['id'],
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Frais dupliqués vers ${selectedClasses.length} classe(s)'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Gestion des Frais Scolaires',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatsCards(isDark),
                _buildActionButtons(isDark),
                Expanded(child: _buildClassesList(isDark)),
              ],
            ),
    );
  }

  Widget _buildStatsCards(bool isDark) {
    if (_fraisStats == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Classes configurées',
              '${_fraisStats!['classes_with_fees']}/${_fraisStats!['total_classes']}',
              Symbols.school,
              Colors.blue,
              isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Frais moyen',
              '${(_fraisStats!['average_fees'] as num?)?.toStringAsFixed(0) ?? '0'} FG',
              Symbols.payments,
              Colors.green,
              isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Revenus attendus',
              '${(_fraisStats!['total_expected_revenue'] as num?)?.toStringAsFixed(0) ?? '0'} FG',
              Symbols.account_balance,
              Colors.orange,
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _showMultiClasseModal,
              icon: const Icon(Symbols.add),
              label: const Text('Configurer Frais Multi-Classes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _showEditFraisModal({
              'classe_id': null,
              'annee_scolaire_id': _activeAnnee!['id'],
              'inscription': 0.0,
              'reinscription': 0.0,
              'tranche1': 0.0,
              'tranche2': 0.0,
              'tranche3': 0.0,
            }),
            icon: const Icon(Symbols.school),
            label: const Text('Classe unique'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              debugPrint('Classes disponibles: ${_allClasses.length}');
              for (var classe in _allClasses) {
                debugPrint('- ${classe['nom']} (ID: ${classe['id']})');
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${_allClasses.length} classes trouvées. Voir console.'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            ),
            child: const Text('Debug'),
          ),
        ],
      ),
    );
  }

  Widget _buildClassesList(bool isDark) {
    if (_classesWithFrais.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Symbols.school,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune classe trouvée',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _classesWithFrais.length,
      itemBuilder: (context, index) {
        final classe = _classesWithFrais[index];
        final hasFrais = classe['frais_id'] != null;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasFrais 
                  ? AppTheme.primaryColor.withOpacity(0.3)
                  : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasFrais 
                    ? AppTheme.primaryColor.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Symbols.school,
                color: hasFrais ? AppTheme.primaryColor : Colors.grey,
              ),
            ),
            title: Text(
              classe['nom'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Niveau: ${classe['niveau'] ?? 'N/A'}'),
                Text('Élèves: ${classe['nb_eleves']}'),
                if (hasFrais)
                  Text(
                    'Frais total: ${classe['montant_total']?.toStringAsFixed(0) ?? '0'} FG',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            trailing: hasFrais
                ? PopupMenuButton(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: const Row(
                          children: [
                            Icon(Symbols.edit),
                            SizedBox(width: 8),
                            Text('Modifier'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'duplicate',
                        child: const Row(
                          children: [
                            Icon(Symbols.content_copy),
                            SizedBox(width: 8),
                            Text('Dupliquer'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: const Row(
                          children: [
                            Icon(Symbols.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Supprimer', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _showEditFraisModal(classe);
                          break;
                        case 'duplicate':
                          _duplicateFrais(classe);
                          break;
                        case 'delete':
                          _confirmDeleteFrais(classe);
                          break;
                      }
                    },
                  )
                : IconButton(
                    onPressed: () => _showEditFraisModal({
                      'classe_id': classe['id'],
                      'annee_scolaire_id': _activeAnnee!['id'],
                      'inscription': 0.0,
                      'reinscription': 0.0,
                      'tranche1': 0.0,
                      'tranche2': 0.0,
                      'tranche3': 0.0,
                    }),
                    icon: const Icon(Symbols.add),
                    tooltip: 'Configurer les frais',
                  ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteFrais(Map<String, dynamic> classe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous supprimer les frais de la classe ${classe['nom']} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseHelper.instance.delete(
          'frais_scolarite',
          'id = ?',
          [classe['frais_id']],
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Frais supprimés avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class _ClassSelectionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> classes;
  final String title;

  const _ClassSelectionDialog({
    required this.classes,
    required this.title,
  });

  @override
  State<_ClassSelectionDialog> createState() => _ClassSelectionDialogState();
}

class _ClassSelectionDialogState extends State<_ClassSelectionDialog> {
  final Set<int> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.classes.length,
          itemBuilder: (context, index) {
            final classe = widget.classes[index];
            final isSelected = _selectedIds.contains(classe['id']);
            
            return CheckboxListTile(
              title: Text(classe['nom']),
              subtitle: Text('Niveau: ${classe['niveau'] ?? 'N/A'}'),
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedIds.add(classe['id']);
                  } else {
                    _selectedIds.remove(classe['id']);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _selectedIds.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selectedIds.toList()),
          child: Text('Sélectionner (${_selectedIds.length})'),
        ),
      ],
    );
  }
}