import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/database/database_helper.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/academic_year_provider.dart';
import '../../../models/enseignant.dart';

class TeacherPaymentsPage extends StatefulWidget {
  const TeacherPaymentsPage({super.key});

  @override
  State<TeacherPaymentsPage> createState() => _TeacherPaymentsPageState();
}

class _TeacherPaymentsPageState extends State<TeacherPaymentsPage> {
  final dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _payments = [];
  List<Enseignant> _teachers = [];
  bool _isLoading = true;
  int? _selectedAnneeId;
  int? _selectedTeacherId;
  String _selectedMonth = 'Tous';

  final List<String> _months = [
    'Tous',
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final anneeId = context.watch<AcademicYearProvider>().selectedAnneeId;
    if (anneeId != null && anneeId != _selectedAnneeId) {
      _selectedAnneeId = anneeId;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (_selectedAnneeId == null) return;
    setState(() => _isLoading = true);
    try {
      final teachersData = await dbHelper.getEnseignants();
      final payments = await dbHelper.getPaiementsEnseignant(
        _selectedTeacherId,
        _selectedAnneeId!,
      );

      if (mounted) {
        setState(() {
          _teachers = teachersData.map((e) => Enseignant.fromMap(e)).toList();
          _payments = payments;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading teacher payments: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _totalPaid {
    return _payments.fold(
      0.0,
      (sum, p) => sum + (p['montant'] as num).toDouble(),
    );
  }

  void _showPaymentModal([Map<String, dynamic>? payment]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PaiementEnseignantModal(
        teachers: _teachers,
        anneeId: _selectedAnneeId!,
        payment: payment,
        onSuccess: _loadData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Gestion des Salaires'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.black87,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCards(theme, isDark),
                  const SizedBox(height: 32),
                  _buildFilters(theme, isDark),
                  const SizedBox(height: 24),
                  Expanded(child: _buildPaymentsList(theme, isDark)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPaymentModal(),
        label: const Text('Nouveau Paiement'),
        icon: const Icon(Symbols.add_card),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildSummaryCards(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.8),
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildSummaryItem(
            'Total Payé',
            '${NumberFormat.currency(symbol: 'GNF', decimalDigits: 0).format(_totalPaid)}',
            Symbols.payments,
            Colors.white,
          ),
          const Spacer(),
          _buildSummaryItem(
            'Nombre de Paiements',
            '${_payments.length}',
            Symbols.receipt_long,
            Colors.white.withValues(alpha: 0.8),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFilters(ThemeData theme, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int?>(
            value: _selectedTeacherId,
            decoration: InputDecoration(
              labelText: 'Enseignant',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Symbols.person),
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Tous les enseignants'),
              ),
              ..._teachers.map(
                (t) => DropdownMenuItem(
                  value: t.id,
                  child: Text('${t.prenom} ${t.nom}'),
                ),
              ),
            ],
            onChanged: (val) {
              setState(() => _selectedTeacherId = val);
              _loadData();
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _selectedMonth,
            decoration: InputDecoration(
              labelText: 'Mois',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Symbols.calendar_month),
            ),
            items: _months
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (val) {
              setState(() => _selectedMonth = val!);
              // Client-side filtering could be done here, but for now we reload
              _loadData();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentsList(ThemeData theme, bool isDark) {
    if (_payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Symbols.receipt_long,
              size: 64,
              color: isDark ? Colors.white24 : Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun paiement trouvé',
              style: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final p = _payments[index];
        final bool isHoraire = p['type_calcul'] == 'Horaire';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Symbols.payments, color: Colors.green),
            ),
            title: Text(
              '${p['prenom']} ${p['nom']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Période: ${p['periode']} • ${p['date_paiement']}'),
                if (isHoraire)
                  Text(
                    '${p['nb_heures']}h x ${NumberFormat.simpleCurrency(name: 'GNF').format(p['taux_horaire'])}/h',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${NumberFormat.currency(symbol: '', decimalDigits: 0).format(p['montant'])} GNF',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  p['mode_paiement'] ?? '',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            onLongPress: () {
              // Delete confirmation
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Supprimer le paiement ?'),
                  content: const Text('Cette action est irréversible.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await dbHelper.deletePaiementEnseignant(p['id']);
                        Navigator.pop(context);
                        _loadData();
                      },
                      child: const Text(
                        'Supprimer',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _PaiementEnseignantModal extends StatefulWidget {
  final List<Enseignant> teachers;
  final int anneeId;
  final Map<String, dynamic>? payment;
  final VoidCallback onSuccess;

  const _PaiementEnseignantModal({
    required this.teachers,
    required this.anneeId,
    this.payment,
    required this.onSuccess,
  });

  @override
  State<_PaiementEnseignantModal> createState() =>
      _PaiementEnseignantModalState();
}

class _PaiementEnseignantModalState extends State<_PaiementEnseignantModal> {
  final _formKey = GlobalKey<FormState>();
  int? _teacherId;
  String _typeCalcul = 'Fixe';
  final _montantController = TextEditingController();
  final _nbHeuresController = TextEditingController();
  final _tauxHoraireController = TextEditingController();
  final _periodeController = TextEditingController();
  final _obsController = TextEditingController();
  String _modePaiement = 'Espèces';
  DateTime _datePaiement = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Default period to current month
    final now = DateTime.now();
    _periodeController.text = _getMonthName(now.month) + ' ${now.year}';

    if (widget.payment != null) {
      _teacherId = widget.payment!['enseignant_id'];
      _typeCalcul = widget.payment!['type_calcul'];
      _montantController.text = widget.payment!['montant'].toString();
      _nbHeuresController.text = widget.payment!['nb_heures']?.toString() ?? '';
      _tauxHoraireController.text =
          widget.payment!['taux_horaire']?.toString() ?? '';
      _periodeController.text = widget.payment!['periode'];
      _obsController.text = widget.payment!['observations'] ?? '';
      _modePaiement = widget.payment!['mode_paiement'];
      _datePaiement = DateTime.parse(widget.payment!['date_paiement']);
    }
  }

  String _getMonthName(int month) {
    const months = [
      '',
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre',
    ];
    return months[month];
  }

  void _onTeacherChanged(int? id) {
    if (id == null) return;
    final teacher = widget.teachers.firstWhere((t) => t.id == id);
    setState(() {
      _teacherId = id;
      _typeCalcul = teacher.typeRemuneration ?? 'Fixe';
      if (_typeCalcul == 'Fixe') {
        _montantController.text = teacher.salaireBase?.toString() ?? '0';
      } else {
        _tauxHoraireController.text = teacher.salaireBase?.toString() ?? '0';
        _calculateTotal();
      }
    });
  }

  void _calculateTotal() {
    if (_typeCalcul == 'Horaire') {
      final h = double.tryParse(_nbHeuresController.text) ?? 0;
      final t = double.tryParse(_tauxHoraireController.text) ?? 0;
      setState(() {
        _montantController.text = (h * t).toStringAsFixed(0);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_teacherId == null) return;

    setState(() => _isSaving = true);
    try {
      final data = {
        'enseignant_id': _teacherId,
        'annee_scolaire_id': widget.anneeId,
        'montant': double.parse(_montantController.text),
        'date_paiement': DateFormat('yyyy-MM-dd').format(_datePaiement),
        'mode_paiement': _modePaiement,
        'type_calcul': _typeCalcul,
        'nb_heures': _typeCalcul == 'Horaire'
            ? double.tryParse(_nbHeuresController.text)
            : null,
        'taux_horaire': _typeCalcul == 'Horaire'
            ? double.tryParse(_tauxHoraireController.text)
            : null,
        'periode': _periodeController.text,
        'observations': _obsController.text,
      };

      await DatabaseHelper.instance.addPaiementEnseignant(data);
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error saving payment: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 32,
        left: 32,
        right: 32,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nouveau Règlement de Salaire',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              DropdownButtonFormField<int>(
                value: _teacherId,
                decoration: InputDecoration(
                  labelText: 'Sélectionner l\'Enseignant',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Symbols.person),
                ),
                items: widget.teachers
                    .map(
                      (t) => DropdownMenuItem(
                        value: t.id,
                        child: Text('${t.prenom} ${t.nom}'),
                      ),
                    )
                    .toList(),
                onChanged: _onTeacherChanged,
                validator: (v) =>
                    v == null ? 'Veuillez choisir un enseignant' : null,
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _typeCalcul,
                      decoration: InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Fixe', child: Text('Fixe')),
                        DropdownMenuItem(
                          value: 'Horaire',
                          child: Text('Horaire'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _typeCalcul = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _periodeController,
                      decoration: InputDecoration(
                        labelText: 'Période (Mois)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (v) => v!.isEmpty ? 'Requis' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (_typeCalcul == 'Horaire') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nbHeuresController,
                        decoration: InputDecoration(
                          labelText: 'Heures',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _calculateTotal(),
                        validator: (v) => v!.isEmpty ? 'Requis' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _tauxHoraireController,
                        decoration: InputDecoration(
                          labelText: 'Taux Horaire',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _calculateTotal(),
                        validator: (v) => v!.isEmpty ? 'Requis' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              TextFormField(
                controller: _montantController,
                decoration: InputDecoration(
                  labelText: 'Montant Total (GNF)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Symbols.payments),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Requis' : null,
                readOnly: _typeCalcul == 'Horaire',
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _modePaiement,
                      decoration: InputDecoration(
                        labelText: 'Mode',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: ['Espèces', 'Virement', 'Mobile Money', 'Chèque']
                          .map(
                            (m) => DropdownMenuItem(value: m, child: Text(m)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _modePaiement = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _datePaiement,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null)
                          setState(() => _datePaiement = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(_datePaiement),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _obsController,
                decoration: InputDecoration(
                  labelText: 'Observations (Optionnel)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 2,
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Enregistrer le Paiement',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
