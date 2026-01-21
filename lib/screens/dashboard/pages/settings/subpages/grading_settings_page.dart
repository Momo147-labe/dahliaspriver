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

  double _noteMaximale = 20.0;
  double _noteMinimale = 0.0;
  String _modeCalculMoyenne = 'trimestrielle';
  int? _configEcoleId;
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
        final configEcole = await _db.getConfigurationEcole(annee['id']);
        if (configEcole != null) {
          _configEcoleId = configEcole['id'];
          _modeCalculMoyenne =
              configEcole['mode_calcul_moyenne'] ?? 'trimestrielle';
        }

        final configEval = await _db.getConfigurationEvaluation(annee['id']);
        if (configEval != null) {
          _configEvalId = configEval['id'];
          _noteMaximale = configEval['note_maximale'] ?? 20.0;
          _noteMinimale = configEval['note_minimale'] ?? 0.0;
        }
      }
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading grading data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      final annee = await _db.getActiveAnnee();
      if (annee == null) return;

      final configEcole = {
        'annee_scolaire_id': annee['id'],
        'mode_calcul_moyenne': _modeCalculMoyenne,
      };

      if (_configEcoleId != null) {
        await _db.updateConfigurationEcole(_configEcoleId!, configEcole);
      } else {
        await _db.saveConfigurationEcole(configEcole);
      }

      final configEval = {
        'annee_scolaire_id': annee['id'],
        'note_maximale': _noteMaximale,
        'note_minimale': _noteMinimale,
      };

      if (_configEvalId != null) {
        await _db.updateConfigurationEvaluation(_configEvalId!, configEval);
      } else {
        await _db.saveConfigurationEvaluation(configEval);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paramètres de notation enregistrés')),
        );
      }
    } catch (e) {
      debugPrint('Error saving grading settings: $e');
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
                _buildHeader(Icons.grading, 'Limites de Notes', theme),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildNumberField(
                        'Note Minimale',
                        _noteMinimale,
                        (v) => setState(() => _noteMinimale = v.toDouble()),
                        isDecimal: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildNumberField(
                        'Note Maximale',
                        _noteMaximale,
                        (v) => setState(() => _noteMaximale = v.toDouble()),
                        isDecimal: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
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
                _buildHeader(Icons.calculate_outlined, 'Mode de Calcul', theme),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _modeCalculMoyenne,
                  decoration: const InputDecoration(
                    labelText: 'Mode de calcul des moyennes',
                    prefixIcon: Icon(Icons.settings_suggest),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'trimestrielle',
                      child: Text('Trimestrielle'),
                    ),
                    DropdownMenuItem(
                      value: 'semestrielle',
                      child: Text('Semestrielle'),
                    ),
                    DropdownMenuItem(
                      value: 'annuelle',
                      child: Text('Annuelle'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _modeCalculMoyenne = value!),
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
              label: const Text('Enregistrer le système'),
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
    Function(dynamic) onChanged, {
    bool isDecimal = false,
  }) {
    return TextFormField(
      initialValue: value.toString(),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
      onChanged: (v) {
        if (isDecimal) {
          onChanged(double.tryParse(v) ?? 0.0);
        } else {
          onChanged(int.tryParse(v) ?? 0);
        }
      },
    );
  }
}
