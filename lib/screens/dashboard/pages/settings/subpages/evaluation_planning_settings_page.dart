import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../core/database/database_helper.dart';
import 'package:intl/intl.dart';

class EvaluationPlanningSettingsPage extends StatefulWidget {
  const EvaluationPlanningSettingsPage({super.key});

  @override
  State<EvaluationPlanningSettingsPage> createState() =>
      _EvaluationPlanningSettingsPageState();
}

class _EvaluationPlanningSettingsPageState
    extends State<EvaluationPlanningSettingsPage> {
  final _db = DatabaseHelper.instance;
  bool _isLoading = true;
  bool _isLocked = true;
  List<Map<String, dynamic>> _sequences = [];
  int? _anneeId;

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
        _anneeId = annee['id'];
        final data = await _db.getSequencesPlanification(_anneeId!);
        _sequences = data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        _anneeId = null;
        _sequences = [];
      }
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading evaluation planning: $e');
      setState(() => _isLoading = false);
    }
  }

  void _addSequence(int trimester) {
    setState(() {
      int maxNum = _sequences.isEmpty
          ? 0
          : _sequences
                .map((s) => s['numero_sequence'] as int)
                .reduce((a, b) => a > b ? a : b);

      _sequences.add({
        'annee_scolaire_id': _anneeId,
        'trimestre': trimester,
        'numero_sequence': maxNum + 1,
        'nom': 'Séquence ${maxNum + 1}',
        'date_debut': DateTime.now().toIso8601String(),
        'date_fin': DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String(),
        'statut': 'Planifiée',
      });
    });
  }

  void _addTrimester() {
    int maxTrimester = _sequences.isEmpty
        ? 0
        : _sequences
              .map((s) => s['trimestre'] as int)
              .reduce((a, b) => a > b ? a : b);
    _addSequence(maxTrimester + 1);
  }

  Future<void> _deleteSequence(int index) async {
    final seq = _sequences[index];
    if (seq['id'] != null) {
      final hasGrades = await _db.hasGradesForSequence(
        _anneeId!,
        seq['trimestre'],
        seq['numero_sequence'],
      );

      if (hasGrades) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Impossible de supprimer : cette séquence contient déjà des notes saisies.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    // Confirmation modal
    if (mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: Text('Voulez-vous vraiment supprimer la "${seq['nom']}" ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Supprimer',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        setState(() {
          _sequences.removeAt(index);
        });
      }
    }
  }

  Future<void> _deleteTrimester(int trimester) async {
    final trimesterSeqs = _sequences
        .where((s) => s['trimestre'] == trimester)
        .toList();

    // Check if any sequence has grades
    for (final seq in trimesterSeqs) {
      if (seq['id'] != null) {
        final hasGrades = await _db.hasGradesForSequence(
          _anneeId!,
          seq['trimestre'],
          seq['numero_sequence'],
        );
        if (hasGrades) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Impossible de supprimer le Trimestre $trimester : la "${seq['nom']}" contient déjà des notes.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }
    }

    if (mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Supprimer le Trimestre'),
          content: Text(
            'Voulez-vous vraiment supprimer tout le Trimestre $trimester ainsi que ses séquences ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Supprimer tout',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        setState(() {
          _sequences.removeWhere((s) => s['trimestre'] == trimester);
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      await _db.saveSequencesPlanification(_sequences);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Calendrier de planification enregistré avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadData();
      setState(() => _isLocked = true);
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
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_anneeId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 64,
              color: Colors.orange[300],
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucune année scolaire active trouvée',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Veuillez activer une année scolaire dans les paramètres généraux.',
            ),
          ],
        ),
      );
    }

    final trimesters =
        _sequences.map((s) => s['trimestre'] as int).toSet().toList()..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  ...trimesters.map(
                    (t) =>
                        _buildTrimesterColumn(t, constraints.maxWidth, isDark),
                  ),
                  if (!_isLocked) _buildAddTrimesterCard(isDark),
                ],
              );
            },
          ),
          const SizedBox(height: 40),
          if (!_isLocked) _buildBottomActionCard(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    final titleSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Planification des Séquences',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              _isLocked ? Icons.lock_outline : Icons.lock_open_outlined,
              color: _isLocked ? Colors.grey : AppTheme.primaryColor,
              size: 24,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _isLocked
              ? 'Mode consultation. Déverrouillez pour modifier le calendrier.'
              : 'Mode édition activé. Gérez les dates des évaluations.',
          style: TextStyle(
            color: _isLocked ? Colors.grey[500] : AppTheme.primaryColor,
            fontSize: 16,
            fontWeight: _isLocked ? FontWeight.normal : FontWeight.w600,
          ),
        ),
      ],
    );

    final actionButtons = Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: isDesktop ? WrapAlignment.end : WrapAlignment.start,
      children: [
        _buildHeaderButton(
          _isLocked ? 'Déverrouiller' : 'Verrouiller',
          _isLocked ? Icons.edit_outlined : Icons.lock_outline,
          onPressed: () {
            setState(() => _isLocked = !_isLocked);
          },
          isPrimary: !_isLocked,
        ),
        _buildHeaderButton(
          'Aperçu global',
          Icons.visibility_outlined,
          onPressed: () {},
          isPrimary: false,
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Paramètres',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            const Text(
              'Calendrier',
              style: TextStyle(color: AppTheme.primaryColor, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (isDesktop)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titleSection),
              const SizedBox(width: 24),
              actionButtons,
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleSection, const SizedBox(height: 16), actionButtons],
          ),
      ],
    );
  }

  Widget _buildHeaderButton(
    String label,
    IconData icon, {
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary
            ? AppTheme.primaryColor
            : (Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.surfaceDark
                  : Colors.white),
        foregroundColor: isPrimary
            ? Colors.white
            : (Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87),
        elevation: isPrimary ? 4 : 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isPrimary
              ? BorderSide.none
              : BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildTrimesterColumn(int trimester, double maxWidth, bool isDark) {
    double columnWidth = (maxWidth - 48) / 3;
    if (maxWidth < 1000) columnWidth = maxWidth;

    final trimesterSeqs = _sequences
        .where((s) => s['trimestre'] == trimester)
        .toList();

    return SizedBox(
      width: columnWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: trimester == 1
                        ? AppTheme.primaryColor
                        : Colors.grey.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    trimester == 1
                        ? 'Premier Trimestre'
                        : (trimester == 2
                              ? 'Deuxième Trimestre'
                              : (trimester == 3
                                    ? 'Troisième Trimestre'
                                    : 'Trimestre $trimester')),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!_isLocked)
                  IconButton(
                    icon: Icon(
                      Icons.delete_sweep_outlined,
                      color: Colors.red[300],
                      size: 20,
                    ),
                    onPressed: () => _deleteTrimester(trimester),
                    tooltip: 'Supprimer le trimestre',
                  ),
              ],
            ),
          ),
          ...trimesterSeqs.map((seq) {
            final index = _sequences.indexOf(seq);
            return _buildSequenceCard(seq, index, isDark);
          }).toList(),
          if (!_isLocked) ...[
            const SizedBox(height: 8),
            _buildAddSequenceButton(trimester, isDark),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildAddTrimesterCard(bool isDark) {
    return InkWell(
      onTap: _addTrimester,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 300,
        height: 150,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            style: BorderStyle.solid,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_to_photos_outlined,
              size: 32,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 12),
            Text(
              'Ajouter un Trimestre',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddSequenceButton(int trimester, bool isDark) {
    return InkWell(
      onTap: () => _addSequence(trimester),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 20,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              'Ajouter une séquence',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSequenceCard(Map<String, dynamic> seq, int index, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SÉQUENCE ${seq['numero_sequence']}',
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_isLocked)
                        Text(
                          seq['nom'] ?? '',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else
                        TextFormField(
                          initialValue: seq['nom'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                          ),
                          onChanged: (v) => seq['nom'] = v,
                        ),
                    ],
                  ),
                ),
                if (!_isLocked)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red[300],
                      size: 20,
                    ),
                    onPressed: () => _deleteSequence(index),
                  )
                else
                  _buildStatusBadge(seq['statut']),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    'Date début',
                    seq,
                    'date_debut',
                    isDark,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDateField('Date fin', seq, 'date_fin', isDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String statut) {
    Color bg;
    Color text;
    switch (statut) {
      case 'Ouverte':
        bg = Colors.green.withValues(alpha: 0.1);
        text = Colors.green[700]!;
        break;
      case 'Planifiée':
        bg = Colors.orange.withValues(alpha: 0.1);
        text = Colors.orange[700]!;
        break;
      default:
        bg = Colors.grey.withValues(alpha: 0.1);
        text = Colors.grey[700]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: text, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            statut,
            style: TextStyle(
              color: text,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(
    String label,
    Map<String, dynamic> seq,
    String field,
    bool isDark,
  ) {
    DateTime date = DateTime.tryParse(seq[field] ?? '') ?? DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _isLocked
              ? null
              : () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() {
                      seq[field] = picked.toIso8601String();
                    });
                  }
                },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isLocked
                    ? Colors.grey.withValues(alpha: 0.1)
                    : AppTheme.primaryColor.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('yyyy-MM-dd').format(date),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: _isLocked ? Colors.grey[400] : AppTheme.primaryColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.info_outline, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enregistrement requis',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Les modifications ne seront effectives qu\'après avoir cliqué sur Enregistrer.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: AppTheme.primaryColor.withValues(alpha: 0.4),
            ),
            child: const Text(
              'Enregistrer les modifications',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
