import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../core/database/database_helper.dart';

class AppreciationSettingsPage extends StatefulWidget {
  const AppreciationSettingsPage({super.key});

  @override
  State<AppreciationSettingsPage> createState() =>
      _AppreciationSettingsPageState();
}

class _AppreciationSettingsPageState extends State<AppreciationSettingsPage> {
  final _db = DatabaseHelper.instance;
  bool _isLoading = true;

  bool _appreciationAutomatique = true;
  bool _useCustomMentions = true;
  int? _configEcoleId;
  int? _configEvalId;

  // Appréciations
  String _appExcellent = 'Excellent';
  String _appTresBien = 'Très bien';
  String _appBien = 'Bien';
  String _appABien = 'Assez bien';
  String _appPassable = 'Passable';
  String _appInsuffisant = 'Insuffisant';

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
        final configEcole = await _db.getConfigurationEcole(annee['id']);
        if (configEcole != null) {
          _configEcoleId = configEcole['id'];
          _useCustomMentions = configEcole['use_custom_mentions'] == 1;
          _appExcellent = configEcole['appreciation_excellent'] ?? 'Excellent';
          _appTresBien = configEcole['appreciation_tres_bien'] ?? 'Très bien';
          _appBien = configEcole['appreciation_bien'] ?? 'Bien';
          _appABien = configEcole['appreciation_abien'] ?? 'Assez bien';
          _appPassable = configEcole['appreciation_passable'] ?? 'Passable';
          _appInsuffisant =
              configEcole['appreciation_insuffisant'] ?? 'Insuffisant';
        }

        final configEval = await _db.getConfigurationEvaluation(annee['id']);
        if (configEval != null) {
          _configEvalId = configEval['id'];
          _appreciationAutomatique =
              configEval['appreciation_automatique'] == 1;
        }
      }
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading appreciation data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      final annee = await _db.getActiveAnnee();
      if (annee == null) return;

      final configEcole = {
        'annee_scolaire_id': annee['id'],
        'use_custom_mentions': _useCustomMentions ? 1 : 0,
        'appreciation_excellent': _appExcellent,
        'appreciation_tres_bien': _appTresBien,
        'appreciation_bien': _appBien,
        'appreciation_abien': _appABien,
        'appreciation_passable': _appPassable,
        'appreciation_insuffisant': _appInsuffisant,
      };

      if (_configEcoleId != null) {
        await _db.updateConfigurationEcole(_configEcoleId!, configEcole);
      } else {
        await _db.saveConfigurationEcole(configEcole);
      }

      final configEval = {
        'annee_scolaire_id': annee['id'],
        'appreciation_automatique': _appreciationAutomatique ? 1 : 0,
      };

      if (_configEvalId != null) {
        await _db.updateConfigurationEvaluation(_configEvalId!, configEval);
      } else {
        await _db.saveConfigurationEvaluation(configEval);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paramètres des textes et appréciations enregistrés'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving appreciation settings: $e');
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
                _buildHeader(
                  Icons.text_fields_outlined,
                  'Textes & Appréciations',
                  theme,
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  title: const Text('Appréciation Automatique'),
                  subtitle: const Text(
                    'Générer selon les tranches de notes lors de la saisie',
                  ),
                  value: _appreciationAutomatique,
                  onChanged: (v) =>
                      setState(() => _appreciationAutomatique = v),
                ),
                SwitchListTile(
                  title: const Text('Utiliser des Mentions Personnalisées'),
                  subtitle: const Text(
                    'Activer les mentions par tranches de notes sur les bulletins',
                  ),
                  value: _useCustomMentions,
                  onChanged: (v) => setState(() => _useCustomMentions = v),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_useCustomMentions)
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
                  _buildHeader(Icons.edit_note, 'Édition des Mentions', theme),
                  const SizedBox(height: 20),
                  _buildMentionField(
                    'Excellent (16-20)',
                    _appExcellent,
                    (v) => _appExcellent = v,
                  ),
                  _buildMentionField(
                    'Très bien (14-16)',
                    _appTresBien,
                    (v) => _appTresBien = v,
                  ),
                  _buildMentionField(
                    'Bien (12-14)',
                    _appBien,
                    (v) => _appBien = v,
                  ),
                  _buildMentionField(
                    'Assez bien (10-12)',
                    _appABien,
                    (v) => _appABien = v,
                  ),
                  _buildMentionField(
                    'Passable (8-10)',
                    _appPassable,
                    (v) => _appPassable = v,
                  ),
                  _buildMentionField(
                    'Insuffisant (<8)',
                    _appInsuffisant,
                    (v) => _appInsuffisant = v,
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
              label: const Text('Enregistrer les textes'),
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

  Widget _buildMentionField(
    String label,
    String initialValue,
    Function(String) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: initialValue,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
