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
    return Row(
      children: [
        Expanded(
          child: _buildGlassStatCard(
            'Total Payé',
            NumberFormat.currency(
              symbol: 'GNF',
              decimalDigits: 0,
            ).format(_totalPaid),
            Symbols.payments,
            const [Color(0xFF6366F1), Color(0xFF4F46E5)],
            isDark,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildGlassStatCard(
            'Paiements',
            '${_payments.length}',
            Symbols.receipt_long,
            const [Color(0xFF10B981), Color(0xFF059669)],
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassStatCard(
    String label,
    String value,
    IconData icon,
    List<Color> gradient,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: gradient[0].withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white60 : AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<int?>(
                value: _selectedTeacherId,
                decoration: InputDecoration(
                  hintText: 'Filtrer par Enseignant',
                  prefixIcon: const Icon(Symbols.person, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Tous')),
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
          ),
          Container(
            width: 1,
            height: 30,
            color: isDark ? Colors.white10 : Colors.black12,
          ),
          Expanded(
            flex: 1,
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<String>(
                value: _selectedMonth,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Symbols.calendar_month, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                items: _months
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (val) {
                  setState(() => _selectedMonth = val!);
                  _loadData();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsList(ThemeData theme, bool isDark) {
    if (_payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.grey.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Symbols.receipt_long,
                size: 64,
                color: isDark ? Colors.white24 : Colors.grey.shade300,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun règlement pour cette période',
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final p = _payments[index];
        final bool isHoraire = p['type_calcul'] == 'Horaire';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onLongPress: () => _showDeleteConfirmation(p),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : AppTheme.primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Symbols.account_balance_wallet,
                      color: isDark ? Colors.white70 : AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p['prenom']} ${p['nom']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Symbols.calendar_today,
                              size: 14,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              p['periode'],
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Symbols.sell,
                              size: 14,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              p['mode_paiement'] ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                        if (isHoraire) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${p['nb_heures']}h x ${NumberFormat.decimalPattern().format(p['taux_horaire'])}',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: isDark
                                  ? Colors.amber.withValues(alpha: 0.7)
                                  : Colors.amber.shade800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${NumberFormat.decimalPattern().format(p['montant'])}',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'GNF',
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer le paiement ?'),
        content: const Text(
          'Voulez-vous vraiment supprimer ce règlement ? Cette action est irréversible.',
        ),
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
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
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
  final ScrollController _scrollController = ScrollController();

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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _onTeacherChanged(int? id) async {
    if (id == null) return;
    final teacher = widget.teachers.firstWhere((t) => t.id == id);

    // Fetch weekly hours from timetable
    final weeklyHours = await DatabaseHelper.instance.getTeacherWeeklyHours(
      id,
      widget.anneeId,
    );

    if (mounted) {
      setState(() {
        _teacherId = id;
        _typeCalcul = teacher.typeRemuneration ?? 'Fixe';
        if (_typeCalcul == 'Fixe') {
          _montantController.text = teacher.salaireBase?.toString() ?? '0';
        } else {
          _tauxHoraireController.text = teacher.salaireBase?.toString() ?? '0';
          // Auto-set hours for the month (approx 4 weeks)
          if (weeklyHours > 0) {
            _nbHeuresController.text = (weeklyHours * 4).toStringAsFixed(0);
          }
          _calculateTotal();
        }
      });
    }
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
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              controller: _scrollController,
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
                            DropdownMenuItem(
                              value: 'Fixe',
                              child: Text('Fixe'),
                            ),
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

                  _buildModernTextField(
                    controller: _montantController,
                    label: 'Montant Total (GNF)',
                    icon: Symbols.payments,
                    keyboardType: TextInputType.number,
                    readOnly: _typeCalcul == 'Horaire',
                    validator: (v) => v!.isEmpty ? 'Requis' : null,
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
                          items:
                              ['Espèces', 'Virement', 'Mobile Money', 'Chèque']
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(m),
                                    ),
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
                  _buildModernTextField(
                    controller: _obsController,
                    label: 'Observations (Optionnel)',
                    icon: Symbols.notes,
                    maxLines: 2,
                  ),

                  const SizedBox(height: 40),

                  _buildSaveButton(isDark),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
    VoidCallback? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: (_) => onChanged?.call(),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.grey.withValues(alpha: 0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.primaryColor),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildSaveButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Confirmer le Règlement',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }
}
