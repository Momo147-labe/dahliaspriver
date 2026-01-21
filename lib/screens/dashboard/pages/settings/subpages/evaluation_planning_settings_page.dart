import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../core/database/database_helper.dart';

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

  int _nombreSequencesTrimestre = 3;
  int _nombreTrimestresAnnee = 3;
  int? _configEvalId;

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
        final configEval = await _db.getConfigurationEvaluation(annee['id']);
        if (configEval != null) {
          _configEvalId = configEval['id'];
          _nombreSequencesTrimestre =
              configEval['nombre_sequences_trimestre'] ?? 3;
          _nombreTrimestresAnnee = configEval['nombre_trimestres_annee'] ?? 3;
        }
      }
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading evaluation planning data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      final annee = await _db.getActiveAnnee();
      if (annee == null) return;

      final configEval = {
        'annee_scolaire_id': annee['id'],
        'nombre_sequences_trimestre': _nombreSequencesTrimestre,
        'nombre_trimestres_annee': _nombreTrimestresAnnee,
      };

      if (_configEvalId != null) {
        await _db.updateConfigurationEvaluation(_configEvalId!, configEval);
      } else {
        await _db.saveConfigurationEvaluation(configEval);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Planification des évaluations enregistrée'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving evaluation planning settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(Icons.event_note, 'Périodes Académiques', theme),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildNumberField(
                        'Nombre de Trimestres / Semestres',
                        _nombreTrimestresAnnee,
                        (v) => setState(() => _nombreTrimestresAnnee = v),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildNumberField(
                        'Nombre de Séquences par période',
                        _nombreSequencesTrimestre,
                        (v) => setState(() => _nombreSequencesTrimestre = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ces paramètres définissent la structure de l\'année scolaire pour le calcul des moyennes.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save),
              label: const Text('Enregistrer la planification'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(IconData icon, String title, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildNumberField(
    String label,
    dynamic value,
    Function(dynamic) onChanged,
  ) {
    return TextFormField(
      initialValue: value.toString(),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
    );
  }
}
