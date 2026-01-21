import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/database/database_helper.dart';
import '../../../models/frais_scolaire.dart';
import '../../../theme/app_theme.dart';

class FraisMultiClasseModal extends StatefulWidget {
  final VoidCallback onSave;
  final VoidCallback onClose;

  const FraisMultiClasseModal({
    super.key,
    required this.onSave,
    required this.onClose,
  });

  @override
  State<FraisMultiClasseModal> createState() => _FraisMultiClasseModalState();
}

class _FraisMultiClasseModalState extends State<FraisMultiClasseModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _inscriptionController = TextEditingController();
  final TextEditingController _reinscriptionController = TextEditingController();
  final TextEditingController _tranche1Controller = TextEditingController();
  final TextEditingController _tranche2Controller = TextEditingController();
  final TextEditingController _tranche3Controller = TextEditingController();
  final TextEditingController _dateLimite1Controller = TextEditingController();
  final TextEditingController _dateLimite2Controller = TextEditingController();
  final TextEditingController _dateLimite3Controller = TextEditingController();

  DateTime? _dateLimite1;
  DateTime? _dateLimite2;
  DateTime? _dateLimite3;

  List<Map<String, dynamic>> _classes = [];
  List<int> _selectedClassIds = [];
  Map<String, dynamic>? _activeAnnee;
  bool _isLoading = false;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final activeAnnee = await DatabaseHelper.instance.getActiveAnnee();
      final classes = await DatabaseHelper.instance.getClassesByAnnee(activeAnnee?['id'] ?? 0);
      
      setState(() {
        _activeAnnee = activeAnnee;
        _classes = classes;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
  }

  Future<void> _selectDate(int trancheNumber) async {
    DateTime initialDate = DateTime.now();

    if (trancheNumber == 1 && _dateLimite1 != null) initialDate = _dateLimite1!;
    if (trancheNumber == 2 && _dateLimite2 != null) initialDate = _dateLimite2!;
    if (trancheNumber == 3 && _dateLimite3 != null) initialDate = _dateLimite3!;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('fr', 'FR'),
    );

    if (picked != null) {
      setState(() {
        final formatted = _dateFormat.format(picked);
        if (trancheNumber == 1) {
          _dateLimite1 = picked;
          _dateLimite1Controller.text = formatted;
        } else if (trancheNumber == 2) {
          _dateLimite2 = picked;
          _dateLimite2Controller.text = formatted;
        } else if (trancheNumber == 3) {
          _dateLimite3 = picked;
          _dateLimite3Controller.text = formatted;
        }
      });
    }
  }

  double get _montantTotal {
    return (double.tryParse(_inscriptionController.text) ?? 0.0) +
        (double.tryParse(_reinscriptionController.text) ?? 0.0) +
        (double.tryParse(_tranche1Controller.text) ?? 0.0) +
        (double.tryParse(_tranche2Controller.text) ?? 0.0) +
        (double.tryParse(_tranche3Controller.text) ?? 0.0);
  }

  Future<void> _saveFrais() async {
    if (!_formKey.currentState!.validate() || _selectedClassIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner au moins une classe'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = DatabaseHelper.instance;
      
      for (int classeId in _selectedClassIds) {
        final frais = FraisScolaire(
          classeId: classeId,
          anneeScolaireId: _activeAnnee!['id'],
          inscription: double.tryParse(_inscriptionController.text) ?? 0.0,
          reinscription: double.tryParse(_reinscriptionController.text) ?? 0.0,
          tranche1: double.tryParse(_tranche1Controller.text) ?? 0.0,
          dateLimiteT1: _dateLimite1Controller.text.isEmpty ? null : _dateLimite1Controller.text,
          tranche2: double.tryParse(_tranche2Controller.text) ?? 0.0,
          dateLimiteT2: _dateLimite2Controller.text.isEmpty ? null : _dateLimite2Controller.text,
          tranche3: double.tryParse(_tranche3Controller.text) ?? 0.0,
          dateLimiteT3: _dateLimite3Controller.text.isEmpty ? null : _dateLimite3Controller.text,
          montantTotal: _montantTotal,
        );

        // Vérifier si des frais existent déjà pour cette classe
        final existing = await db.getFraisByClasse(classeId, _activeAnnee!['id']);
        
        if (existing != null) {
          // Mettre à jour
          await db.update(
            'frais_scolarite',
            frais.toMap(),
            'id = ?',
            [existing['id']],
          );
        } else {
          // Créer nouveau
          await db.insert('frais_scolarite', frais.toMap());
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Frais configurés pour ${_selectedClassIds.length} classe(s)'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSave();
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: 900,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(isDark),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        'Sélection des Classes',
                        Symbols.school,
                        Colors.blue,
                        isDark,
                      ),
                      const SizedBox(height: 16),
                      _buildClassSelection(isDark),
                      const SizedBox(height: 32),
                      _buildSectionHeader(
                        'Frais d\'Inscription',
                        Symbols.account_balance_wallet,
                        Colors.orange,
                        isDark,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _inscriptionController,
                              label: 'Inscription',
                              icon: Symbols.person_add,
                              keyboardType: TextInputType.number,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _reinscriptionController,
                              label: 'Réinscription',
                              icon: Symbols.sync_alt,
                              keyboardType: TextInputType.number,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _buildSectionHeader(
                        'Échéancier de Paiement',
                        Symbols.schedule,
                        Colors.purple,
                        isDark,
                      ),
                      const SizedBox(height: 16),
                      _buildTrancheRow(1, _tranche1Controller, _dateLimite1Controller, Colors.blue, isDark),
                      const SizedBox(height: 12),
                      _buildTrancheRow(2, _tranche2Controller, _dateLimite2Controller, Colors.green, isDark),
                      const SizedBox(height: 12),
                      _buildTrancheRow(3, _tranche3Controller, _dateLimite3Controller, Colors.purple, isDark),
                      const SizedBox(height: 32),
                      _buildTotalSummary(isDark),
                    ],
                  ),
                ),
              ),
            ),
            _buildActions(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, Colors.orange.shade600],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Symbols.payments,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configurer les Frais Scolaires',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Sélectionnez plusieurs classes avec les mêmes frais',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassSelection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: _selectedClassIds.length == _classes.length && _classes.isNotEmpty,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedClassIds = _classes.map((c) => c['id'] as int).toList();
                    } else {
                      _selectedClassIds.clear();
                    }
                  });
                },
              ),
              const Text(
                'Sélectionner toutes les classes',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _classes.map((classe) {
              final isSelected = _selectedClassIds.contains(classe['id']);
              return InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedClassIds.remove(classe['id']);
                    } else {
                      _selectedClassIds.add(classe['id']);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppTheme.primaryColor.withOpacity(0.1)
                        : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected 
                          ? AppTheme.primaryColor
                          : (isDark ? Colors.white10 : Colors.grey.shade200),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.primaryColor,
                          size: 18,
                        ),
                      if (isSelected) const SizedBox(width: 8),
                      Text(
                        '${classe['nom']} - ${classe['niveau'] ?? ''}',
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppTheme.primaryColor : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (_selectedClassIds.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_selectedClassIds.length} classe(s) sélectionnée(s)',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, bool isDark) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white.withOpacity(0.9) : Colors.blueGrey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.blueGrey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 16),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              size: 20,
              color: isDark ? Colors.white30 : Colors.grey.shade400,
            ),
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildTrancheRow(
    int number,
    TextEditingController amountCtrl,
    TextEditingController dateCtrl,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: _buildTextField(
              controller: amountCtrl,
              label: 'Montant Tranche $number',
              icon: Symbols.payments,
              keyboardType: TextInputType.number,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Date Limite',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _selectDate(number),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Symbols.calendar_today,
                          size: 18,
                          color: Colors.blueGrey,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          dateCtrl.text.isEmpty ? 'Sélectionner une date' : dateCtrl.text,
                          style: TextStyle(
                            color: dateCtrl.text.isEmpty
                                ? Colors.grey
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSummary(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            Colors.orange.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MONTANT TOTAL CALCULÉ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pour ${_selectedClassIds.length} classe(s) sélectionnée(s)',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          Text(
            '${_montantTotal.toStringAsFixed(0)} FG',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: widget.onClose,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Annuler'),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _saveFrais,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Enregistrer les Frais'),
          ),
        ],
      ),
    );
  }
}