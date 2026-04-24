import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../../../core/database/database_helper.dart';
import '../../../../providers/academic_year_provider.dart';
import '../../../../theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  String _schoolName = 'Gestion Scolaire';

  @override
  void initState() {
    super.initState();
    _loadSchoolName();
  }

  Future<void> _loadSchoolName() async {
    try {
      final info = await DatabaseHelper.instance.getEcoleInfo();
      if (mounted) {
        setState(() {
          _schoolName = info['nom']?.toString() ?? 'Gestion Scolaire';
        });
      }
    } catch (_) {}
  }

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
    setState(() {
      _selectedEleve = eleve;
      _fraisClasse = null; // Reset while loading
      _totalPaid = 0;
      _lastPaymentInfo = null;
    });

    try {
      if (_selectedAnneeId != null) {
        // Load class fees
        final fees = await dbHelper.getFraisByClasse(
          eleve['classe_id'],
          _selectedAnneeId!,
        );

        // Load individual payment records for this year
        final payments = await dbHelper.getPaiementsByEleve(
          eleve['id'],
          _selectedAnneeId!,
        );

        double paid = 0;
        for (var p in payments) {
          // Individual records from paiement_detail use 'montant'
          paid += (p['montant'] as num?)?.toDouble() ?? 0.0;
        }

        String? lastInfo;
        if (payments.isNotEmpty) {
          final last = payments.first; // Already sorted by date DESC in DAO
          final dateStr = last['date_paiement'];
          if (dateStr != null) {
            final date = DateTime.parse(dateStr);
            lastInfo =
                'Dernier: ${DateFormat('dd MMM yyyy', 'fr_FR').format(date)} (${last['type_frais']?.toString().toUpperCase() ?? ''})';
          }
        }

        setState(() {
          _fraisClasse = fees;
          _totalPaid = paid;
          _lastPaymentInfo = lastInfo;
        });

        if (mounted && fees != null) {
          final double inscription =
              (fees['inscription'] as num?)?.toDouble() ?? 0.0;
          final double reinscription =
              (fees['reinscription'] as num?)?.toDouble() ?? 0.0;
          final double t1 = (fees['tranche1'] as num?)?.toDouble() ?? 0.0;
          final double t2 = (fees['tranche2'] as num?)?.toDouble() ?? 0.0;
          final double t3 = (fees['tranche3'] as num?)?.toDouble() ?? 0.0;

          final bool isReinscrit =
              eleve['statut'] == 'reinscrit' ||
              eleve['eleve_statut'] == 'reinscrit';
          final double totalDue =
              (isReinscrit ? reinscription : inscription) + t1 + t2 + t3;
          final double remaining = totalDue - paid;

          if (remaining <= 0 && totalDue > 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                final anneeLabel =
                    context
                        .read<AcademicYearProvider>()
                        .selectedAnnee?['libelle'] ??
                    'cette année';
                final nom = '${eleve['prenom']} ${eleve['nom']}';
                final matricule = eleve['matricule'] ?? '';
                final classe = eleve['classe_nom'] ?? '';

                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Information'),
                    content: Text(
                      "L'élève $nom de matricule $matricule de la classe de $classe a déjà tout payé pour l'année scolaire $anneeLabel.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading student financials: $e');
    }
  }

  Future<void> _validatePayment() async {
    if (_selectedEleve == null) return;
    if (!_formKey.currentState!.validate()) return;

    final montant = double.tryParse(_montantController.text.trim()) ?? 0;
    if (montant <= 0) return;

    if (_fraisClasse != null) {
      final double inscription =
          (_fraisClasse!['inscription'] as num?)?.toDouble() ?? 0.0;
      final double reinscription =
          (_fraisClasse!['reinscription'] as num?)?.toDouble() ?? 0.0;
      final double t1 = (_fraisClasse!['tranche1'] as num?)?.toDouble() ?? 0.0;
      final double t2 = (_fraisClasse!['tranche2'] as num?)?.toDouble() ?? 0.0;
      final double t3 = (_fraisClasse!['tranche3'] as num?)?.toDouble() ?? 0.0;

      final bool isReinscrit =
          _selectedEleve!['statut'] == 'reinscrit' ||
          _selectedEleve!['eleve_statut'] == 'reinscrit';
      final double totalDue =
          (isReinscrit ? reinscription : inscription) + t1 + t2 + t3;

      final double remaining = totalDue - _totalPaid;

      if (remaining <= 0) {
        if (mounted) {
          final anneeLabel =
              context.read<AcademicYearProvider>().selectedAnnee?['libelle'] ??
              'cette année';
          final nom = '${_selectedEleve!['prenom']} ${_selectedEleve!['nom']}';
          final matricule = _selectedEleve!['matricule'] ?? '';
          final classe = _selectedEleve!['classe_nom'] ?? '';

          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Information'),
              content: Text(
                "L'élève $nom de matricule $matricule de la classe de $classe a déjà tout payé pour l'année scolaire $anneeLabel.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Compris'),
                ),
              ],
            ),
          );
        }
        return;
      } else if (montant > remaining) {
        if (mounted) {
          final formattedRemaining = NumberFormat.currency(
            locale: 'fr_FR',
            symbol: 'GNF',
            decimalDigits: 0,
          ).format(remaining > 0 ? remaining : 0);
          final formattedSaisi = NumberFormat.currency(
            locale: 'fr_FR',
            symbol: 'GNF',
            decimalDigits: 0,
          ).format(montant);
          final nom = '${_selectedEleve!['prenom']} ${_selectedEleve!['nom']}';

          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text(
                'Montant incorrect',
                style: TextStyle(color: Color(0xFFEF4444)),
              ),
              content: Text(
                "Il reste à payer $formattedRemaining pour l'élève $nom, et non $formattedSaisi.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Compris'),
                ),
              ],
            ),
          );
        }
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      if (_selectedAnneeId != null) {
        final prefs = await SharedPreferences.getInstance();
        final int? userId = prefs.getInt('userId');

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
          'created_by_id': userId,
        });

        // Update confirmation status to 'Confirmé' if it's the first payment and currently 'En attente'
        if (_totalPaid == 0 &&
            _selectedEleve!['confirmation_statut'] == 'En attente') {
          await dbHelper.updateEleveParcoursStatut(
            _selectedEleve!['id'],
            _selectedAnneeId!,
            'Confirmé',
          );
        }

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
    final primaryColor = AppTheme.primaryColor;
    final bgColor = isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight;

    return Scaffold(
      backgroundColor: bgColor,
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
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.surfaceLight,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      centerTitle: false,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: isDark ? AppTheme.textDarkPrimary : AppTheme.textPrimary,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Icon(Symbols.school, color: primaryColor),
          const SizedBox(width: 12),
          Text(
            _schoolName,
            style: TextStyle(
              color: isDark ? AppTheme.textDarkPrimary : AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {},
          icon: Icon(
            Symbols.notifications,
            size: 20,
            color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        CircleAvatar(
          radius: 18,
          backgroundColor: isDark
              ? AppTheme.cardDark
              : AppTheme.primaryColor.withValues(alpha: 0.1),
          child: Icon(
            Icons.person,
            size: 18,
            color: isDark ? AppTheme.textDarkSecondary : AppTheme.primaryColor,
          ),
        ),
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
            color: isDark ? AppTheme.textDarkPrimary : AppTheme.textPrimary,
          ),
        ),
        Text(
          'Enregistrez un nouveau paiement de scolarité.',
          style: TextStyle(
            color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSecondary,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildStudentCard(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppTheme.borderDark.withValues(alpha: 0.3)
              : AppTheme.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
          ),
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
                    color: isDark
                        ? AppTheme.textDarkPrimary
                        : AppTheme.textPrimary,
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
                        ? AppTheme.cardDark
                        : AppTheme.hoverLight,
                    foregroundColor: isDark
                        ? AppTheme.textDarkPrimary
                        : AppTheme.textPrimary,
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
        color: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(6),
        border: isDark
            ? Border.all(color: AppTheme.borderDark.withValues(alpha: 0.2))
            : null,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppTheme.textDarkSecondary
                  : AppTheme.textSecondary,
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
        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppTheme.borderDark.withValues(alpha: 0.3)
              : AppTheme.borderLight,
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
                    color: isDark
                        ? AppTheme.textDarkPrimary
                        : AppTheme.textPrimary,
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
            color: isDark ? AppTheme.textDarkPrimary : AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedTranche,
          decoration: _inputDecoration(isDark),
          items: const [
            DropdownMenuItem(
              value: 'inscription',
              child: Text('Frais d\'Inscription'),
            ),
            DropdownMenuItem(
              value: 'reinscription',
              child: Text('Frais de Réinscription'),
            ),
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
            color: isDark ? AppTheme.textDarkPrimary : AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _montantController,
          keyboardType: TextInputType.number,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.textDarkPrimary : AppTheme.textPrimary,
          ),
          decoration: _inputDecoration(isDark).copyWith(
            suffixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'GNF',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppTheme.textDarkSecondary
                      : AppTheme.textSecondary,
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
            color: isDark ? AppTheme.textDarkPrimary : AppTheme.textPrimary,
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
              ? primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark
                      ? AppTheme.borderDark.withValues(alpha: 0.3)
                      : AppTheme.borderLight),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? primaryColor
                  : (isDark
                        ? AppTheme.textDarkSecondary
                        : AppTheme.textSecondary),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? (isDark ? AppTheme.textDarkPrimary : AppTheme.textPrimary)
                    : (isDark
                          ? AppTheme.textDarkSecondary
                          : AppTheme.textSecondary),
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
            color: isDark ? AppTheme.textDarkPrimary : AppTheme.textPrimary,
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
      fillColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark
              ? AppTheme.borderDark.withValues(alpha: 0.3)
              : AppTheme.borderLight,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark
              ? AppTheme.borderDark.withValues(alpha: 0.3)
              : AppTheme.borderLight,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(
        color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSecondary,
      ),
      hintStyle: TextStyle(
        color: isDark
            ? AppTheme.textDarkSecondary.withValues(alpha: 0.5)
            : AppTheme.textMuted,
      ),
    );
  }

  Widget _buildSubmitSection(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.1)),
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
                  color: isDark
                      ? AppTheme.textDarkSecondary
                      : AppTheme.textSecondary,
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
    final String rawStatut =
        _selectedEleve?['statut']?.toString().toLowerCase() ?? '';
    final bool isReinscrit =
        rawStatut.contains('rein') || rawStatut.contains('réin');

    final String enrollmentLabel = isReinscrit
        ? 'Réinscription'
        : 'Inscription';
    final double enrollmentFee = _fraisClasse != null
        ? (isReinscrit
              ? (_fraisClasse!['reinscription'] as num?)?.toDouble() ?? 0.0
              : (_fraisClasse!['inscription'] as num?)?.toDouble() ?? 0.0)
        : 0.0;

    final double totalDue = _fraisClasse != null
        ? enrollmentFee +
              ((_fraisClasse!['tranche1'] as num?)?.toDouble() ?? 0.0) +
              ((_fraisClasse!['tranche2'] as num?)?.toDouble() ?? 0.0) +
              ((_fraisClasse!['tranche3'] as num?)?.toDouble() ?? 0.0)
        : 0.0;

    final double paid = _totalPaid;
    final double remaining = totalDue - paid;
    final double progress = totalDue > 0
        ? (paid / totalDue).clamp(0.0, 1.0)
        : 0;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppTheme.borderDark.withValues(alpha: 0.3)
              : AppTheme.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedEleve != null && _fraisClasse == null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Symbols.error, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Attention: Aucun frais configuré pour la classe de cet élève cette année.',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          Text(
            'État financier',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.textDarkPrimary : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          _statusItem(
            'Frais $enrollmentLabel',
            enrollmentFee,
            isDark,
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _statusItem(
            'Scolarité (T1+T2+T3)',
            totalDue - enrollmentFee,
            isDark,
            null,
          ),
          const Divider(height: 32),
          _statusItem('TOTAL DÛ (Année)', totalDue, isDark, null, isBold: true),
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
                  ? AppTheme.warningColor.withValues(alpha: 0.1)
                  : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? AppTheme.warningColor.withValues(alpha: 0.3)
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
                    color: AppTheme.warningColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${NumberFormat('#,###', 'fr_FR').format(remaining)} GNF',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.warningColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Divider(
            height: 1,
            color: isDark
                ? AppTheme.borderDark.withValues(alpha: 0.3)
                : AppTheme.borderLight,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Symbols.info,
                size: 14,
                color: isDark
                    ? AppTheme.textDarkSecondary
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _lastPaymentInfo ?? 'Aucun paiement enregistré',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : AppTheme.textSecondary,
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
    bool isBold = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${NumberFormat('#,###', 'fr_FR').format(value)} GNF',
          style: TextStyle(
            fontSize: isBold ? 24 : 20,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color:
                color ??
                (isDark ? AppTheme.textDarkPrimary : AppTheme.textPrimary),
          ),
        ),
        if (progress != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: isDark
                  ? AppTheme.cardDark
                  : AppTheme.backgroundLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                color ?? AppTheme.primaryColor,
              ),
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
            primaryColor.withValues(alpha: 0.05),
            primaryColor.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(Symbols.receipt_long, color: primaryColor, size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            'Génération de reçu',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.textDarkPrimary : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Un reçu numérique sera généré automatiquement après validation.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppTheme.textDarkSecondary
                  : AppTheme.textSecondary,
            ),
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
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.rawQuery('''
        SELECT e.*, c.nom as classe_nom
        FROM eleve e
        LEFT JOIN classe c ON e.classe_id = c.id
        ORDER BY e.nom ASC
        LIMIT 30
      ''');
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _search(String query) async {
    if (query.isEmpty) {
      _fetchInitialResults();
      return;
    }
    if (query.length < 2) return;

    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.rawQuery(
        '''
        SELECT e.*, c.nom as classe_nom
        FROM eleve e
        LEFT JOIN classe c ON e.classe_id = c.id
        WHERE e.nom LIKE ? OR e.prenom LIKE ? OR e.matricule LIKE ?
        ORDER BY e.nom ASC
        LIMIT 30
      ''',
        ['%$query%', '%$query%', '%$query%'],
      );
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.backgroundDark : AppTheme.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
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
                fillColor: isDark ? AppTheme.surfaceDark : AppTheme.hoverLight,
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
                          backgroundColor: AppTheme.primaryColor.withValues(
                            alpha: 0.1,
                          ),
                          child: Text(
                            eleve['nom'][0],
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          '${eleve['prenom']} ${eleve['nom']}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppTheme.textDarkPrimary
                                : AppTheme.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${eleve['matricule']} • ${eleve['classe_nom'] ?? 'N/A'}',
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.textDarkSecondary
                                : AppTheme.textSecondary,
                          ),
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
