import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../../../core/database/database_helper.dart';
import '../../../../providers/academic_year_provider.dart';
import 'package:provider/provider.dart';

class NewPaymentPage extends StatefulWidget {
  const NewPaymentPage({super.key});

  @override
  State<NewPaymentPage> createState() => _NewPaymentPageState();
}

class _NewPaymentPageState extends State<NewPaymentPage> {
  final dbHelper = DatabaseHelper.instance;
  final _formKey = GlobalKey<FormState>();

  Map<String, dynamic>? _selectedEleve;
  Map<String, dynamic>? _fraisClasse;
  double _totalPaid = 0;
  String? _lastPaymentInfo;
  int? _selectedAnneeId;

  final _montantController = TextEditingController();
  final _refController = TextEditingController();
  String _selectedTranche = 't1';
  String _modePaiement = 'Espèces';

  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final anneeId = context.watch<AcademicYearProvider>().selectedAnneeId;
    if (anneeId != null && anneeId != _selectedAnneeId) {
      _selectedAnneeId = anneeId;
      if (_selectedEleve != null) {
        _loadStudentFinancials(_selectedEleve!);
      }
    }
  }

  @override
  void dispose() {
    _montantController.dispose();
    _refController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentFinancials(Map<String, dynamic> eleve) async {
    try {
      if (_selectedAnneeId != null) {
        // Load class fees
        final fees = await dbHelper.getFraisByClasse(
          eleve['classe_id'],
          _selectedAnneeId!,
        );

        // Load already paid amount for this student
        final payments = await dbHelper.getPaiementsByEleve(
          eleve['id'],
          _selectedAnneeId!,
        );
        double paid = 0;
        for (var p in payments) {
          paid += (p['montant'] as num).toDouble();
        }

        String? lastInfo;
        if (payments.isNotEmpty) {
          final last = payments.last;
          final dateStr = last['date_paiement'];
          if (dateStr != null) {
            final date = DateTime.parse(dateStr);
            lastInfo =
                'Dernier: ${DateFormat('dd MMM yyyy', 'fr_FR').format(date)} (${last['type_frais']?.toString().toUpperCase() ?? ''})';
          }
        }

        setState(() {
          _selectedEleve = eleve;
          _fraisClasse = fees;
          _totalPaid = paid;
          _lastPaymentInfo = lastInfo;
        });
      }
    } catch (e) {
      debugPrint('Error loading student financials: $e');
    } finally {
      // Done loading
    }
  }

  Future<void> _validatePayment() async {
    if (_selectedEleve == null) return;
    if (!_formKey.currentState!.validate()) return;

    final montant = double.tryParse(_montantController.text.trim()) ?? 0;
    if (montant <= 0) return;

    setState(() => _isSaving = true);
    try {
      if (_selectedAnneeId != null) {
        await dbHelper.addPaiement({
          'eleve_id': _selectedEleve!['id'],
          'classe_id': _selectedEleve!['classe_id'],
          'frais_id': _fraisClasse?['id'],
          'annee_scolaire_id': _selectedAnneeId!,
          'montant': montant,
          'date_paiement': DateTime.now().toIso8601String(),
          'mode_paiement': _modePaiement,
          'type_frais': _selectedTranche,
          'mois': DateFormat('MMMM', 'fr_FR').format(DateTime.now()),
          'observation': _refController.text.trim(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Paiement validé avec succès !'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      debugPrint('Error saving payment: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Erreur'),
            content: Text(
              'Une erreur est survenue lors de l\'enregistrement du paiement: $e',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF13daec);
    final bgLight = const Color(0xFFf6f8f8);
    final bgDark = const Color(0xFF102022);

    return Scaffold(
      backgroundColor: isDark ? bgDark : bgLight,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(isDark, primaryColor),
          SliverToBoxAdapter(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1200),
                padding: const EdgeInsets.all(40),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Main Form
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPageHeading(isDark),
                          const SizedBox(height: 32),
                          _buildStudentCard(isDark, primaryColor),
                          const SizedBox(height: 24),
                          _buildPaymentDetailsCard(isDark, primaryColor),
                          const SizedBox(height: 24),
                          _buildSubmitSection(isDark, primaryColor),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    // Right Column: Sidebar
                    SizedBox(
                      width: 320,
                      child: Column(
                        children: [
                          _buildFinancialStatusCard(isDark, primaryColor),
                          const SizedBox(height: 24),
                          _buildIllustrationCard(isDark, primaryColor),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(bool isDark, Color primaryColor) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF111718) : Colors.white,
      elevation: 1,
      centerTitle: false,
      title: Row(
        children: [
          Icon(Symbols.school, color: primaryColor),
          const SizedBox(width: 12),
          Text(
            'Guinée École',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF111718),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Symbols.cloud_done, size: 20),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Symbols.notifications, size: 20),
        ),
        const SizedBox(width: 12),
        const CircleAvatar(radius: 18, backgroundColor: Colors.grey),
        const SizedBox(width: 20),
      ],
    );
  }

  Widget _buildPageHeading(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Encaissement des Frais',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF111718),
          ),
        ),
        const Text(
          'Enregistrez un nouveau paiement de scolarité.',
          style: TextStyle(color: Color(0xFF618689), fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildStudentCard(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1a2b2d) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFdbe5e6),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ÉLÈVE SÉLECTIONNÉ',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedEleve != null
                      ? '${_selectedEleve!['prenom']} ${_selectedEleve!['nom']}'
                      : 'Veuillez sélectionner un élève',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF111718),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildBadge(
                      Symbols.school,
                      _selectedEleve?['classe_nom'] ?? 'Aucune classe',
                      isDark,
                    ),
                    const SizedBox(width: 12),
                    _buildBadge(
                      Symbols.id_card,
                      _selectedEleve?['matricule'] ?? 'N/A',
                      isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: _showStudentSearch,
                  icon: const Icon(Symbols.person_search, size: 18),
                  label: const Text("Changer d'élève"),
                  style: TextButton.styleFrom(
                    backgroundColor: isDark
                        ? const Color(0xFF1c2e30)
                        : const Color(0xFFf0f4f4),
                    foregroundColor: isDark
                        ? Colors.white
                        : const Color(0xFF111718),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildStudentPhoto(),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111718) : const Color(0xFFf6f8f8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF618689)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF618689),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentPhoto() {
    final photoPath = _selectedEleve?['photo'];
    final hasPhoto =
        photoPath != null &&
        photoPath.toString().isNotEmpty &&
        File(photoPath.toString()).existsSync();

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: hasPhoto
            ? Image.file(File(photoPath.toString()), fit: BoxFit.cover)
            : Center(
                child: Icon(
                  Symbols.person,
                  size: 60,
                  color: Colors.grey.shade400,
                ),
              ),
      ),
    );
  }

  Widget _buildPaymentDetailsCard(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1a2b2d) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFdbe5e6),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Row(
              children: [
                Icon(Symbols.payments, color: primaryColor),
                const SizedBox(width: 12),
                Text(
                  'Détails du paiement',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF111718),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildTrancheSelector(isDark)),
                const SizedBox(width: 24),
                Expanded(child: _buildAmountInput(isDark)),
              ],
            ),
            const SizedBox(height: 24),
            _buildModePaiementSelector(isDark, primaryColor),
            const SizedBox(height: 24),
            _buildReferenceInput(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildTrancheSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tranche de paiement',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isDark ? Colors.white : const Color(0xFF111718),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedTranche,
          decoration: _inputDecoration(isDark),
          items: const [
            DropdownMenuItem(value: 't1', child: Text('1ère Tranche (T1)')),
            DropdownMenuItem(value: 't2', child: Text('2ème Tranche (T2)')),
            DropdownMenuItem(value: 't3', child: Text('3ème Tranche (T3)')),
            DropdownMenuItem(value: 'full', child: Text('Scolarité Complète')),
          ],
          onChanged: (v) => setState(() => _selectedTranche = v ?? 't1'),
        ),
      ],
    );
  }

  Widget _buildAmountInput(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Montant versé (GNF)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isDark ? Colors.white : const Color(0xFF111718),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _montantController,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          decoration: _inputDecoration(isDark).copyWith(
            suffixIcon: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'GNF',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF618689),
                ),
              ),
            ),
          ),
          validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
        ),
      ],
    );
  }

  Widget _buildModePaiementSelector(bool isDark, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mode de paiement',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isDark ? Colors.white : const Color(0xFF111718),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _modeButtonItem('Espèces', Symbols.payments, isDark, primaryColor),
          ],
        ),
      ],
    );
  }

  Widget _modeButtonItem(
    String label,
    IconData icon,
    bool isDark,
    Color primaryColor,
  ) {
    final isSelected = _modePaiement == label;
    return InkWell(
      onTap: () => setState(() => _modePaiement = label),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark ? Colors.white10 : const Color(0xFFdbe5e6)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? primaryColor : const Color(0xFF618689),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF111718))
                    : const Color(0xFF618689),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceInput(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Numéro de référence (Optionnel)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isDark ? Colors.white : const Color(0xFF111718),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _refController,
          decoration: _inputDecoration(
            isDark,
          ).copyWith(hintText: 'Ex: OM-4859202'),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(bool isDark) {
    return InputDecoration(
      filled: true,
      fillColor: isDark ? const Color(0xFF111718) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.white10 : const Color(0xFFdbe5e6),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.white10 : const Color(0xFFdbe5e6),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF13daec), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildSubmitSection(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Symbols.offline_pin, color: primaryColor, size: 20),
              const SizedBox(width: 12),
              Text(
                'Mode hors-ligne: Données synchronisées localement.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF111718),
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _validatePayment,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Icon(Symbols.check_circle, color: Colors.black),
            label: Text(
              _isSaving ? 'VALIDATION...' : 'VALIDER LE PAIEMENT',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.black,
                fontSize: 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialStatusCard(bool isDark, Color primaryColor) {
    final double totalDue =
        (_fraisClasse?['montant_total'] as num?)?.toDouble() ?? 0;
    final double paid = _totalPaid;
    final double remaining = totalDue - paid;
    final double progress = totalDue > 0
        ? (paid / totalDue).clamp(0.0, 1.0)
        : 0;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1a2b2d) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFdbe5e6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'État financier',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _statusItem('Total dû (Année)', totalDue, isDark, null),
          const SizedBox(height: 24),
          _statusItem(
            'Déjà payé',
            paid,
            isDark,
            Colors.green,
            progress: progress,
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.orange.withOpacity(0.1)
                  : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.orange.withOpacity(0.3)
                    : const Color(0xFFFFEDD5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RESTE À PAYER',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${NumberFormat('#,###', 'fr_FR').format(remaining)} GNF',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Symbols.info, size: 14, color: Color(0xFF618689)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _lastPaymentInfo ?? 'Aucun paiement enregistré',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF618689),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusItem(
    String label,
    double value,
    bool isDark,
    Color? color, {
    double? progress,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(0xFF618689),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${NumberFormat('#,###', 'fr_FR').format(value)} GNF',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color ?? (isDark ? Colors.white : const Color(0xFF111718)),
          ),
        ),
        if (progress != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: isDark
                  ? Colors.white10
                  : const Color(0xFFf0f4f4),
              valueColor: AlwaysStoppedAnimation<Color>(color!),
              minHeight: 8,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildIllustrationCard(bool isDark, Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withOpacity(0.05),
            primaryColor.withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(Symbols.receipt_long, color: primaryColor, size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            'Génération de reçu',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF111718),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Un reçu numérique sera généré automatiquement après validation.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF618689)),
          ),
        ],
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
          _loadStudentFinancials(eleve);
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
    final results = await DatabaseHelper.instance.rawQuery('''
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
        color: isDark ? const Color(0xFF111718) : Colors.white,
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
                hintText: 'Rechercher un élève...',
                prefixIcon: const Icon(Symbols.search),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : const Color(0xFFf0f4f4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(24),
              ),
            ),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          Expanded(
            child: _results.isEmpty && !_isLoading
                ? const Center(child: Text('Aucun résultat trouvé'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final eleve = _results[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(
                            0xFF13daec,
                          ).withOpacity(0.1),
                          child: Text(
                            eleve['nom'][0],
                            style: const TextStyle(
                              color: Color(0xFF13daec),
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
