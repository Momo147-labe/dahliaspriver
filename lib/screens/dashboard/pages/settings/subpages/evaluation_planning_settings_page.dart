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
        if (data.isEmpty) {
          _sequences = [];
        } else {
          _sequences = data.map((e) => Map<String, dynamic>.from(e)).toList();
        }
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
        'poids': 50.0,
        'statut': 'Planifiée',
      });
    });
  }

  void _deleteSequence(int index) {
    setState(() {
      _sequences.removeAt(index);
    });
  }

  void _resetToDefaults() {
    if (_anneeId == null) return;
    setState(() {
      _sequences = List.generate(6, (index) {
        int trimester = (index ~/ 2) + 1;
        return {
          'annee_scolaire_id': _anneeId,
          'trimestre': trimester,
          'numero_sequence': index + 1,
          'nom': 'Séquence ${index + 1}',
          'date_debut': DateTime.now().toIso8601String(),
          'date_fin': DateTime.now()
              .add(const Duration(days: 30))
              .toIso8601String(),
          'poids': 50.0,
          'statut': index == 0 ? 'Ouverte' : 'Planifiée',
        };
      });
    });
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

  double _getTrimesterTotal(int trimester) {
    return _sequences
        .where((s) => s['trimestre'] == trimester)
        .fold(0.0, (sum, s) => sum + (s['poids'] ?? 0.0));
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          // Grid des trimestres
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  _buildTrimesterColumn(1, constraints.maxWidth, isDark),
                  _buildTrimesterColumn(2, constraints.maxWidth, isDark),
                  _buildTrimesterColumn(3, constraints.maxWidth, isDark),
                ],
              );
            },
          ),
          const SizedBox(height: 40),
          _buildBottomActionCard(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Planification des Séquences',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Configurez les dates charnières et les coefficients pour chaque évaluation.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 16),
                ),
              ],
            ),
            Row(
              children: [
                if (_sequences.isEmpty)
                  _buildHeaderButton(
                    'Générer par défaut',
                    Icons.auto_awesome_outlined,
                    onPressed: _resetToDefaults,
                    isPrimary: true,
                  )
                else
                  _buildHeaderButton(
                    'Réinitialiser',
                    Icons.refresh,
                    onPressed: _resetToDefaults,
                    isPrimary: false,
                  ),
                const SizedBox(width: 12),
                _buildHeaderButton(
                  'Aperçu global',
                  Icons.visibility_outlined,
                  onPressed: () {},
                  isPrimary: false,
                ),
                const SizedBox(width: 12),
                _buildHeaderButton(
                  'Enregistrer le calendrier',
                  Icons.save_outlined,
                  onPressed: _saveSettings,
                  isPrimary: true,
                ),
              ],
            ),
          ],
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
              : BorderSide(color: Colors.grey.withOpacity(0.2)),
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
    final total = _getTrimesterTotal(trimester);
    final isValid = total == 100.0;

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
                        : Colors.grey.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  trimester == 1
                      ? 'Premier Trimestre'
                      : (trimester == 2
                            ? 'Deuxième Trimestre'
                            : 'Troisième Trimestre'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...trimesterSeqs.map((seq) {
            final index = _sequences.indexOf(seq);
            return _buildSequenceCard(seq, index, isDark);
          }).toList(),
          _buildAddSequenceButton(trimester, isDark),
          const SizedBox(height: 12),
          _buildTrimesterFooter(total, isValid, isDark),
        ],
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
            color: AppTheme.primaryColor.withOpacity(0.3),
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
            SizedBox(width: 8),
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
              ? Colors.white.withOpacity(0.05)
              : Colors.grey.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Carte
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
                      TextFormField(
                        initialValue: seq['nom'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Nom de la séquence',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (v) => seq['nom'] = v,
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(seq['statut']),
                IconButton(
                  onPressed: () => _deleteSequence(index),
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.red[400],
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Formulaire
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
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
                      child: _buildDateField(
                        'Date fin',
                        seq,
                        'date_fin',
                        isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildWeightSlider(seq, isDark),
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
        bg = Colors.green.withOpacity(0.1);
        text = Colors.green[700]!;
        break;
      case 'Planifiée':
        bg = Colors.orange.withOpacity(0.1);
        text = Colors.orange[700]!;
        break;
      default:
        bg = Colors.grey.withOpacity(0.1);
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
          onTap: () async {
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
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
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
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeightSlider(Map<String, dynamic> seq, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Poids dans le trimestre (%)',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  activeTrackColor: AppTheme.primaryColor,
                  inactiveTrackColor: AppTheme.primaryColor.withOpacity(0.1),
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                    elevation: 2,
                  ),
                  overlayColor: AppTheme.primaryColor.withOpacity(0.1),
                ),
                child: Slider(
                  value: (seq['poids'] ?? 0.0).toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  onChanged: (v) {
                    setState(() {
                      seq['poids'] = v;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 50,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${(seq['poids'] ?? 0).toInt()}%',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrimesterFooter(double total, bool isValid, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: (isValid ? Colors.green : Colors.red).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isValid
            ? 'TOTAL TRIMESTRE: 100% ✓'
            : 'ERREUR: TOTAL ${total.toInt()}% (DOIT ÊTRE 100%)',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isValid
              ? (isDark ? Colors.green[400] : Colors.green[700])
              : (isDark ? Colors.red[400] : Colors.red[700]),
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildBottomActionCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
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
                  'Information Importante',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Toute modification impactera le calcul automatique des moyennes de fin d\'année.',
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
              shadowColor: AppTheme.primaryColor.withOpacity(0.4),
            ),
            child: const Text(
              'Finaliser le Calendrier',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
