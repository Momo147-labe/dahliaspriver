import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_helper.dart';
import '../../theme/app_theme.dart';

class PaymentFormModal extends StatefulWidget {
  final VoidCallback onSaved;
  const PaymentFormModal({super.key, required this.onSaved});

  @override
  State<PaymentFormModal> createState() => _PaymentFormModalState();
}

class _PaymentFormModalState extends State<PaymentFormModal> {
  final _formKey = GlobalKey<FormState>();
  final dbHelper = DatabaseHelper.instance;

  Map<String, dynamic>? _selectedEleve;
  Map<String, dynamic>? _fraisClasse;

  final _montantController = TextEditingController();
  final _obsController = TextEditingController();
  String _modePaiement = 'Espèces';
  String _typeFrais = 'inscription';

  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _montantController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _loadEleveFees(Map<String, dynamic> eleve) async {
    setState(() => _isLoading = true);
    try {
      final anneeId = await dbHelper.ensureActiveAnneeCached();
      if (anneeId != null) {
        final fees = await dbHelper.getFraisByClasse(
          eleve['classe_id'],
          anneeId,
        );
        setState(() {
          _fraisClasse = fees;
          _selectedEleve = eleve;
        });
      }
    } catch (e) {
      debugPrint('Error loading fees: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePayment() async {
    if (_selectedEleve == null) return;
    if (!_formKey.currentState!.validate()) return;

    final montantStr = _montantController.text.trim();
    final montant = double.tryParse(montantStr);
    if (montant == null || montant <= 0) return;

    setState(() => _isSaving = true);
    try {
      final anneeId = await dbHelper.ensureActiveAnneeCached();
      if (anneeId == null) return;

      await dbHelper.addPaiement({
        'eleve_id': _selectedEleve!['id'],
        'annee_scolaire_id': anneeId,
        'montant': montant,
        'date_paiement': DateTime.now().toIso8601String(),
        'mode_paiement': _modePaiement,
        'type_frais': _typeFrais,
        'mois': DateFormat('MMMM', 'fr_FR').format(DateTime.now()),
        'observation': _obsController.text.trim(),
      });

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paiement enregistré avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving payment: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(isDark, theme),
              const SizedBox(height: 32),

              _buildFieldLabel('Rechercher un élève', isDark),
              _buildEleveSelector(isDark, theme),
              const SizedBox(height: 24),

              if (_selectedEleve != null) ...[
                _buildEleveSummary(isDark, theme),
                const SizedBox(height: 24),

                _buildFieldLabel('Type de frais', isDark),
                _buildTypeSelector(isDark),
                const SizedBox(height: 24),

                _buildFieldLabel('Montant du versement (GNF)', isDark),
                _buildAmountField(isDark, theme),
                const SizedBox(height: 24),

                _buildFieldLabel('Mode de paiement', isDark),
                _buildModeSelector(isDark),
                const SizedBox(height: 32),

                _buildSubmitButton(isDark, theme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, ThemeData theme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Symbols.add_card, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nouveau Paiement',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              const Text(
                'Enregistrement d\'un nouveau versement scolaire',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Symbols.close),
          style: IconButton.styleFrom(
            backgroundColor: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.shade100,
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white70 : Colors.blueGrey.shade700,
        ),
      ),
    );
  }

  Widget _buildEleveSelector(bool isDark, ThemeData theme) {
    return InkWell(
      onTap: () => _showStudentSearch(),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _selectedEleve == null
                ? Colors.transparent
                : AppTheme.primaryColor.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _selectedEleve == null ? Symbols.search : Symbols.person,
              color: _selectedEleve == null
                  ? Colors.grey
                  : AppTheme.primaryColor,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _selectedEleve == null
                    ? 'Cliquer pour sélectionner un élève'
                    : '${_selectedEleve!['prenom']} ${_selectedEleve!['nom']}',
                style: TextStyle(
                  color: _selectedEleve == null
                      ? Colors.grey
                      : (isDark ? Colors.white : AppTheme.textPrimary),
                  fontWeight: _selectedEleve == null
                      ? FontWeight.normal
                      : FontWeight.bold,
                ),
              ),
            ),
            if (_selectedEleve != null)
              const Icon(Symbols.check_circle, color: Colors.green, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEleveSummary(bool isDark, ThemeData theme) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_fraisClasse == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total scolarité:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                '${NumberFormat('#,###', 'fr_FR').format(_fraisClasse!['montant_total'])} GNF',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Text(
            'Classe: ${_selectedEleve!['classe_nom'] ?? 'N/A'}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _typeFrais,
          isExpanded: true,
          items: const [
            DropdownMenuItem(
              value: 'inscription',
              child: Text('Inscription / Réinscription'),
            ),
            DropdownMenuItem(value: 'tranche 1', child: Text('Tranche 1')),
            DropdownMenuItem(value: 'tranche 2', child: Text('Tranche 2')),
            DropdownMenuItem(value: 'tranche 3', child: Text('Tranche 3')),
          ],
          onChanged: (val) => setState(() => _typeFrais = val!),
        ),
      ),
    );
  }

  Widget _buildAmountField(bool isDark, ThemeData theme) {
    return TextFormField(
      controller: _montantController,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
      decoration: InputDecoration(
        prefixIcon: const Icon(Symbols.payments, size: 28),
        hintText: '0',
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(24),
      ),
    );
  }

  Widget _buildModeSelector(bool isDark) {
    return Row(
      children: [
        Expanded(child: _modeButton('Espèces', Symbols.payments, isDark)),
        const SizedBox(width: 12),
        Expanded(child: _modeButton('Mobile', Symbols.phone_android, isDark)),
        const SizedBox(width: 12),
        Expanded(
          child: _modeButton('Virement', Symbols.account_balance, isDark),
        ),
      ],
    );
  }

  Widget _modeButton(String mode, IconData icon, bool isDark) {
    final isSelected = _modePaiement == mode;
    return InkWell(
      onTap: () => setState(() => _modePaiement = mode),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : (isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primaryColor : Colors.grey),
            const SizedBox(height: 8),
            Text(
              mode,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primaryColor : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(bool isDark, ThemeData theme) {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, Color(0xFF0EA5E9)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _savePayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Symbols.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text(
                    'ENREGISTRER LE PAIEMENT',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _showStudentSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StudentSearchModal(
        onSelect: (eleve) {
          Navigator.pop(context);
          _loadEleveFees(eleve);
        },
      ),
    );
  }
}

class _StudentSearchModal extends StatefulWidget {
  final Function(Map<String, dynamic>) onSelect;
  const _StudentSearchModal({required this.onSelect});

  @override
  State<_StudentSearchModal> createState() => _StudentSearchModalState();
}

class _StudentSearchModalState extends State<_StudentSearchModal> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialResults();
  }

  void _fetchInitialResults() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper.instance;
    final results = await db.rawQuery('''
      SELECT e.*, c.nom as classe_nom 
      FROM eleve e
      LEFT JOIN classe c ON e.classe_id = c.id
      LIMIT 20
    ''');
    setState(() {
      _results = results;
      _isLoading = false;
    });
  }

  void _search(String query) async {
    if (query.isEmpty) {
      _fetchInitialResults();
      return;
    }
    if (query.length < 2) return;

    setState(() => _isLoading = true);
    final results = await DatabaseHelper.instance.searchEleves(query);
    setState(() {
      _results = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(32),
            child: TextField(
              controller: _searchController,
              onChanged: _search,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Rechercher un élève (Nom, Prénom ou Matricule)...',
                prefixIcon: const Icon(Symbols.search),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(20),
              ),
            ),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          Expanded(
            child: _results.isEmpty && !_isLoading
                ? Center(
                    child: Text(
                      'Aucun résultat trouvé',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final eleve = _results[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor.withOpacity(
                            0.1,
                          ),
                          child: Text(
                            eleve['nom'][0].toUpperCase(),
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          '${eleve['prenom']} ${eleve['nom']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${eleve['matricule']} • ${eleve['classe_nom'] ?? 'N/A'}',
                        ),
                        onTap: () => widget.onSelect(eleve),
                        trailing: const Icon(
                          Symbols.chevron_right,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
