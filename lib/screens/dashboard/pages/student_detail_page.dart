import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../../../models/student.dart';
import '../../../theme/app_theme.dart';

class StudentDetailPage extends StatefulWidget {
  final int studentId;

  const StudentDetailPage({super.key, required this.studentId});

  @override
  State<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage>
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  bool _isLoading = true;
  late TabController _tabController;

  Map<String, dynamic>? _student;
  List<Map<String, dynamic>> _parcours = [];
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _results = [];

  // Design Tokens (Refined for Premium look)
  static const Color _accentColor = Color(
    0xFF22C3C3,
  ); // Keeping the teal accent
  final Color _primaryColor = AppTheme.primaryColor;
  final Color _textSecondary = AppTheme.textSecondary;

  // Calculated Stats
  double _totalAverage = 0.0;
  double _totalBalance = 0.0;
  Map<int, double> _yearlyAverages = {};
  int? _activeAnneeId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final student = await _dbHelper.getStudentById(widget.studentId);
      final parcours = await _dbHelper.getStudentParcours(widget.studentId);
      final payments = await _dbHelper.getStudentPayments(widget.studentId);
      final results = await _dbHelper.getStudentResults(widget.studentId);
      final activeAnnee = await _dbHelper.getActiveAnnee();

      // Fetch payment details for each aggregate payment
      List<Map<String, dynamic>> updatedPayments = [];
      for (var p in payments) {
        final details = await _dbHelper.getStudentPaymentDetails(
          widget.studentId,
          anneeId: p['annee_scolaire_id'],
        );
        var pMap = Map<String, dynamic>.from(p);
        pMap['details'] = details;
        updatedPayments.add(pMap);
      }

      setState(() {
        _student = student;
        _parcours = parcours;
        _payments = updatedPayments;
        _results = results;
        _activeAnneeId = activeAnnee?['id'] as int?;
        _calculateStats();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading student details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
        Navigator.pop(context);
      }
    }
  }

  void _calculateStats() {
    // Compute balance for active year only
    final activePayments = _activeAnneeId != null
        ? _payments
              .where((p) => p['annee_scolaire_id'] == _activeAnneeId)
              .toList()
        : _payments;

    double totalPaid = 0.0;
    double totalDue = 0.0;
    bool counted = false;
    for (var p in activePayments) {
      for (var d in (p['details'] as List? ?? [])) {
        totalPaid += (d['montant'] as num? ?? 0.0);
      }
      if (!counted) {
        totalDue = (p['montant_total'] as num?)?.toDouble() ?? 0.0;
        counted = true;
      }
    }
    _totalBalance = totalDue - totalPaid;

    _yearlyAverages = {};
    for (var p in _parcours) {
      int? anneeId = p['annee_scolaire_id'];
      if (anneeId == null) continue;

      var yearGrades = _results
          .where((r) => r['annee_scolaire_id'] == anneeId)
          .toList();

      if (yearGrades.isNotEmpty) {
        // Correct Weighted Average Calculation
        Map<int, List<Map<String, dynamic>>> byMatiere = {};
        for (var g in yearGrades) {
          byMatiere.putIfAbsent(g['matiere_id'], () => []).add(g);
        }

        double totalPoints = 0;
        double totalCoeff = 0;

        byMatiere.forEach((matiereId, matNotes) {
          double matiereSum = 0;
          for (var n in matNotes) matiereSum += (n['note'] as num).toDouble();
          double matiereAvg = matiereSum / matNotes.length;
          double coeff = (matNotes.first['coefficient'] as num? ?? 1.0)
              .toDouble();
          totalPoints += matiereAvg * coeff;
          totalCoeff += coeff;
        });

        _yearlyAverages[anneeId] = totalCoeff > 0
            ? totalPoints / totalCoeff
            : 0.0;
      }
    }

    // Overall Average (Weighted across all subjects recorded)
    if (_results.isNotEmpty) {
      Map<int, List<Map<String, dynamic>>> byMatiere = {};
      for (var g in _results) {
        byMatiere.putIfAbsent(g['matiere_id'], () => []).add(g);
      }
      double totalPoints = 0;
      double totalCoeff = 0;
      byMatiere.forEach((matiereId, matNotes) {
        double matiereSum = 0;
        for (var n in matNotes) matiereSum += (n['note'] as num).toDouble();
        double matiereAvg = matiereSum / matNotes.length;
        double coeff = (matNotes.first['coefficient'] as num? ?? 1.0)
            .toDouble();
        totalPoints += matiereAvg * coeff;
        totalCoeff += coeff;
      });
      _totalAverage = totalCoeff > 0 ? totalPoints / totalCoeff : 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark
            ? AppTheme.backgroundDark
            : AppTheme.backgroundLight,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    if (_student == null) {
      return Scaffold(
        backgroundColor: isDark
            ? AppTheme.backgroundDark
            : AppTheme.backgroundLight,
        body: const Center(child: Text('Élève introuvable')),
      );
    }

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.backgroundDark
          : AppTheme.backgroundLight,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildSliverHeader(isDark),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: _buildSummaryStatsRow(isDark),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(_buildTabNavigation(isDark)),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildParcoursTab(isDark),
            _buildResultsTab(isDark),
            _buildFinanceTab(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStatsRow(bool isDark) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              Icons.analytics,
              'Moyenne',
              '${_totalAverage.toStringAsFixed(2)}/${_parcours.isNotEmpty ? _parcours.first['note_max'] ?? 20 : 20}',
              isDark,
              _primaryColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryItem(
              Icons.account_balance_wallet,
              'Reste à payer',
              _formatCurrency(_totalBalance),
              isDark,
              _totalBalance > 0 ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    IconData icon,
    String label,
    String value,
    bool isDark,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? AppTheme.borderDark.withValues(alpha: 0.2)
              : Colors.grey[100]!,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black26
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: isDark
                  ? AppTheme.textDarkSecondary
                  : AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverHeader(bool isDark) {
    final s = _student!;
    final Color headerColor = isDark ? AppTheme.surfaceDark : _primaryColor;
    final Color headerEnd = isDark
        ? AppTheme.backgroundDark
        : const Color(0xFF4F46E5);

    return SliverToBoxAdapter(
      child: Column(
        children: [
          // Banner with Glassmorphism and better Profile Pic
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 200,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [headerColor, headerEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Abstract pattern decoration
                    Positioned(
                      right: -50,
                      top: -50,
                      child: CircleAvatar(
                        radius: 100,
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.arrow_back_ios_new,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                            Row(
                              children: [
                                _buildBannerButton(
                                  Icons.print_outlined,
                                  'Imprimer',
                                  () {},
                                ),
                                const SizedBox(width: 8),
                                _buildBannerButton(
                                  Icons.edit_outlined,
                                  'Modifier',
                                  () {},
                                  isWhite: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Profile Pic Overlap - Centered slightly on mobile/Desktop
              Positioned(
                bottom: -50,
                left: 24,
                child: Hero(
                  tag: 'student_photo_${widget.studentId}',
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppTheme.backgroundDark : Colors.white,
                        width: 5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(65),
                      child: Container(
                        color: isDark ? AppTheme.cardDark : Colors.grey[100],
                        child:
                            s['photo'] != null &&
                                s['photo'].toString().isNotEmpty
                            ? Image.file(
                                File(s['photo'].toString()),
                                fit: BoxFit.cover,
                              )
                            : Icon(
                                Icons.person,
                                size: 70,
                                color: isDark
                                    ? AppTheme.textDarkSecondary
                                    : AppTheme.textSecondary,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 60),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${s['prenom']} ${s['nom']}',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _buildHeaderSubtitle(
                            Icons.fingerprint,
                            s['matricule'] ?? 'N/A',
                            isDark,
                          ),
                          _buildHeaderSeparator(isDark),
                          _buildHeaderSubtitle(
                            Icons.school_outlined,
                            s['classe_nom'] ?? 'Sans classe',
                            isDark,
                          ),
                          _buildHeaderSeparator(isDark),
                          _buildStatusBadge(s['statut'] ?? 'Inscrit'),
                        ],
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.phone_in_talk_outlined, size: 18),
                  label: const Text('Contacter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 5,
                    shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerButton(
    IconData icon,
    String label,
    VoidCallback onPressed, {
    bool isWhite = false,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 16,
        color: isWhite ? AppTheme.primaryColor : Colors.white,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: isWhite ? AppTheme.primaryColor : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
      style: TextButton.styleFrom(
        backgroundColor: isWhite
            ? Colors.white
            : Colors.white.withValues(alpha: 0.2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildHeaderSubtitle(IconData icon, String text, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSecondary,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderSeparator(bool isDark) {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? AppTheme.borderDark : Colors.grey[300],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: _accentColor,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildTabNavigation(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? AppTheme.borderDark.withValues(alpha: 0.1)
                : Colors.grey[200]!,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelPadding: const EdgeInsets.symmetric(horizontal: 20),
        indicatorColor: AppTheme.primaryColor,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: isDark
            ? AppTheme.textDarkSecondary
            : AppTheme.textSecondary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 14,
          letterSpacing: 0.2,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        indicatorWeight: 4,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(
            height: 50,
            child: Row(
              children: [
                Icon(Icons.history_edu_outlined, size: 20),
                SizedBox(width: 10),
                Text('Parcours'),
              ],
            ),
          ),
          Tab(
            height: 50,
            child: Row(
              children: [
                Icon(Icons.analytics_outlined, size: 20),
                SizedBox(width: 10),
                Text('Résultats'),
              ],
            ),
          ),
          Tab(
            height: 50,
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined, size: 20),
                SizedBox(width: 10),
                Text('Finances'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParcoursTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildContentHeader(
                  Icons.person_outline,
                  'Informations Personnelles',
                ),
                const SizedBox(height: 16),
                _buildBioCard(isDark),
                const SizedBox(height: 32),
                _buildContentHeader(
                  Icons.family_restroom_outlined,
                  'Informations Parentales',
                ),
                const SizedBox(height: 16),
                _buildParentCard(isDark),
                const SizedBox(height: 32),
                _buildContentHeader(Icons.timeline, 'Cycle Scolaire'),
                const SizedBox(height: 24),
                _buildTimeline(isDark),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(flex: 1, child: _buildContactCard(isDark)),
        ],
      ),
    );
  }

  Widget _buildBioCard(bool isDark) {
    final s = _student!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? AppTheme.borderDark.withValues(alpha: 0.2)
              : Colors.grey[100]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildBioItem(
                Icons.cake_outlined,
                'Né(e) le',
                s['date_naissance'] ?? 'Non renseigné',
                isDark,
              ),
              const SizedBox(width: 16),
              _buildBioItem(
                Icons.location_on_outlined,
                'Lieu de naissance',
                s['lieu_naissance'] ?? 'Non renseigné',
                isDark,
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              _buildBioItem(
                Icons.wc_outlined,
                'Sexe / Genre',
                s['sexe'] == 'M' ? 'Masculin' : 'Féminin',
                isDark,
              ),
              const SizedBox(width: 16),
              _buildBioItem(
                Icons.badge_outlined,
                'Matricule Scolaire',
                s['matricule'] ?? 'N/A',
                isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParentCard(bool isDark) {
    final s = _student!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? AppTheme.borderDark.withValues(alpha: 0.2)
              : Colors.grey[100]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildBioItem(
                Icons.person_pin_outlined,
                'Père',
                '${s['prenom_pere'] ?? ""} ${s['nom_pere'] ?? ""}'
                        .trim()
                        .isEmpty
                    ? 'Non renseigné'
                    : '${s['prenom_pere'] ?? ""} ${s['nom_pere'] ?? ""}',
                isDark,
              ),
              const SizedBox(width: 16),
              _buildBioItem(
                Icons.person_pin_outlined,
                'Mère',
                '${s['prenom_mere'] ?? ""} ${s['nom_mere'] ?? ""}'
                        .trim()
                        .isEmpty
                    ? 'Non renseigné'
                    : '${s['prenom_mere'] ?? ""} ${s['nom_mere'] ?? ""}',
                isDark,
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              _buildBioItem(
                Icons.emergency_outlined,
                'Urgence (Nom)',
                s['personne_a_prevenir'] ?? 'Non renseigné',
                isDark,
              ),
              const SizedBox(width: 16),
              _buildBioItem(
                Icons.phone_android_outlined,
                'Urgence (Contact)',
                s['contact_urgence'] ?? 'Non renseigné',
                isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBioItem(IconData icon, String label, String value, bool isDark) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(bool isDark) {
    if (_parcours.isEmpty)
      return _buildEmptyState('Aucun parcours enregistré', isDark);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _parcours.length,
      itemBuilder: (context, index) {
        final p = _parcours[index];
        final bool isFirst = index == 0;
        final bool isLast = index == _parcours.length - 1;

        return IntrinsicHeight(
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFirst
                          ? _primaryColor
                          : (isDark ? Colors.grey[800] : Colors.grey[100]),
                      border: Border.all(
                        color: isDark ? AppTheme.surfaceDark : Colors.white,
                        width: 4,
                      ),
                    ),
                    child: Icon(
                      isFirst ? Icons.school : Icons.history,
                      size: 18,
                      color: isFirst ? Colors.white : _textSecondary,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(width: 2, color: Colors.grey[200]),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['classe_nom'] ?? 'N/A',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        p['annee_nom'] ?? 'N/A',
                        style: TextStyle(
                          color: isFirst
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: isFirst
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isFirst
                              ? AppTheme.primaryColor.withValues(alpha: 0.06)
                              : (isDark
                                    ? AppTheme.cardDark
                                    : AppTheme.backgroundLight),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: isFirst
                                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                                : (isDark
                                      ? AppTheme.borderDark
                                      : Colors.grey[200]!),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Moyenne Générale',
                              style: TextStyle(
                                color: isDark
                                    ? AppTheme.textDarkSecondary
                                    : AppTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _yearlyAverages[p['annee_id']] != null
                                  ? '${_yearlyAverages[p['annee_id']]!.toStringAsFixed(2)} / 20'
                                  : '-- / 20',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: isFirst
                                    ? AppTheme.primaryColor
                                    : (isDark
                                          ? Colors.white
                                          : AppTheme.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContentHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 22),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildContactCard(bool isDark) {
    final studentObj = _student != null ? Student.fromMap(_student!) : null;
    final parentName = studentObj?.parentName ?? 'Non défini';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : AppTheme.textPrimary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONTACT URGENT',
            style: TextStyle(
              color: _primaryColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Parent / Tuteur',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      parentName,
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildDarkIconRow(Icons.phone, '+224 6XX XX XX XX'),
          const SizedBox(height: 12),
          _buildDarkIconRow(Icons.location_on, 'Conakry, Guinée'),
        ],
      ),
    );
  }

  Widget _buildDarkIconRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: _primaryColor, size: 18),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }

  Widget _buildFinanceTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildFinancialSummary(isDark),
          const SizedBox(height: 24),
          _buildPaymentsTable(isDark),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(bool isDark) {
    // Only show data for the active year
    final activePayments = _activeAnneeId != null
        ? _payments
              .where((p) => p['annee_scolaire_id'] == _activeAnneeId)
              .toList()
        : _payments;

    double totalPaid = 0;
    double totalDue = 0;
    bool counted = false;
    for (var p in activePayments) {
      for (var d in (p['details'] as List? ?? [])) {
        totalPaid += (d['montant'] as num?)?.toDouble() ?? 0.0;
      }
      // Count totalDue only once (same year → same montant_total)
      if (!counted) {
        totalDue = (p['montant_total'] as num?)?.toDouble() ?? 0.0;
        counted = true;
      }
    }
    double remaining = totalDue - totalPaid;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildFinanceStat('Frais Totaux', totalDue, isDark),
          _buildDivider(),
          _buildFinanceStat(
            'Montant Payé',
            totalPaid,
            isDark,
            color: Colors.green,
          ),
          _buildDivider(),
          _buildFinanceStat(
            'Reste à Payer',
            remaining,
            isDark,
            color: remaining > 0 ? Colors.red : Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceStat(
    String label,
    double val,
    bool isDark, {
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatCurrency(val),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color ?? (isDark ? Colors.white : AppTheme.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() =>
      Container(width: 1, height: 40, color: Colors.grey[100]);

  Widget _buildPaymentsTable(bool isDark) {
    // Group payments by annee_scolaire
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var p in _payments) {
      final anneeLabel = (p['annee_nom'] ?? 'Année inconnue') as String;
      final details = (p['details'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      if (details.isEmpty) continue;
      grouped.putIfAbsent(anneeLabel, () => []).addAll(details);
    }

    if (grouped.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Center(
          child: Text(
            'Aucun paiement enregistré',
            style: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildContentHeader(
              Icons.receipt_long,
              'Historique des Paiements',
            ),
          ),
          const Divider(height: 1),
          ...grouped.entries.map((entry) {
            final anneeLabel = entry.key;
            final details = entry.value;
            final anneeTotal = details.fold<double>(
              0,
              (sum, d) => sum + ((d['montant'] as num?)?.toDouble() ?? 0),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Year header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.grey[50],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            anneeLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatCurrency(anneeTotal),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.green[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Table header
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1.5),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(1.5),
                    3: FlexColumnWidth(1),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? Colors.white12 : Colors.grey[200]!,
                          ),
                        ),
                      ),
                      children: [
                        _buildCell('DATE', isDark: isDark, isHeader: true),
                        _buildCell('LIBELLÉ', isDark: isDark, isHeader: true),
                        _buildCell('MONTANT', isDark: isDark, isHeader: true),
                        _buildCell('STATUT', isDark: isDark, isHeader: true),
                      ],
                    ),
                    ...details.map(
                      (d) => TableRow(
                        children: [
                          _buildCell(
                            _formatDate(d['date_paiement']),
                            isDark: isDark,
                          ),
                          _buildCell(
                            d['type_frais'] ?? 'Paiement',
                            isDark: isDark,
                          ),
                          _buildCell(
                            _formatCurrency(d['montant']),
                            isBold: true,
                            isDark: isDark,
                          ),
                          _buildCellBadge('Payé', Colors.green),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResultsTab(bool isDark) {
    if (_results.isEmpty)
      return _buildEmptyState('Aucune note enregistrée', isDark);

    // Group by year
    final Map<int, Map<String, dynamic>> yearMeta = {};
    final Map<int, Map<int, List<Map<String, dynamic>>>> byYearTrimestre = {};

    for (var r in _results) {
      final anneeId = r['annee_scolaire_id'] as int? ?? 0;
      final anneeNom = r['annee_nom'] as String? ?? 'Année inconnue';
      final trimestre = r['trimestre'] as int? ?? 1;

      yearMeta[anneeId] ??= {'nom': anneeNom, 'id': anneeId};
      byYearTrimestre.putIfAbsent(anneeId, () => {});
      byYearTrimestre[anneeId]!.putIfAbsent(trimestre, () => []).add(r);
    }

    // Sort years descending (most recent first)
    final sortedYears = yearMeta.keys.toList()..sort((a, b) => b.compareTo(a));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: sortedYears.map((anneeId) {
          final anneeNom = yearMeta[anneeId]!['nom'] as String;
          final trimestreMap = byYearTrimestre[anneeId]!;
          final sortedT = trimestreMap.keys.toList()..sort();

          // Compute year average
          Map<int, List<Map<String, dynamic>>> byMatiere = {};
          for (var r in _results.where(
            (r) => r['annee_scolaire_id'] == anneeId,
          )) {
            byMatiere.putIfAbsent(r['matiere_id'] as int, () => []).add(r);
          }
          double totalPts = 0, totalCoeff = 0;
          byMatiere.forEach((_, notes) {
            double s = 0;
            for (var n in notes) s += (n['note'] as num).toDouble();
            double coeff = (notes.first['coefficient'] as num? ?? 1).toDouble();
            totalPts += (s / notes.length) * coeff;
            totalCoeff += coeff;
          });
          final yearAvg = totalCoeff > 0 ? totalPts / totalCoeff : 0.0;

          final isActiveYear = anneeId == _activeAnneeId;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Year header
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isActiveYear
                        ? [
                            AppTheme.primaryColor.withValues(alpha: 0.15),
                            AppTheme.primaryColor.withValues(alpha: 0.05),
                          ]
                        : [
                            Colors.grey.withValues(alpha: 0.1),
                            Colors.grey.withValues(alpha: 0.03),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActiveYear
                        ? AppTheme.primaryColor.withValues(alpha: 0.4)
                        : Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 18,
                          color: isActiveYear
                              ? AppTheme.primaryColor
                              : Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          anneeNom,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isActiveYear
                                ? AppTheme.primaryColor
                                : (isDark ? Colors.white70 : Colors.grey[700]),
                          ),
                        ),
                        if (isActiveYear) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      'Moy. ${yearAvg.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isActiveYear
                            ? AppTheme.primaryColor
                            : (isDark ? Colors.white60 : Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
              // Trimester cards
              ...sortedT.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildTrimesterCard(t, trimestreMap[t]!, isDark),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTrimesterCard(
    int trimester,
    List<Map<String, dynamic>> notes,
    bool isDark,
  ) {
    // Proper Weighted Average calculation per trimester
    Map<int, List<Map<String, dynamic>>> byMatiere = {};
    for (var n in notes) {
      byMatiere.putIfAbsent(n['matiere_id'], () => []).add(n);
    }

    double totalPoints = 0;
    double totalCoeff = 0;

    byMatiere.forEach((matiereId, matNotes) {
      double matiereSum = 0;
      for (var n in matNotes) {
        matiereSum += (n['note'] as num).toDouble();
      }
      double matiereAvg = matiereSum / matNotes.length;
      double coeff = (matNotes.first['coefficient'] as num? ?? 1.0).toDouble();
      totalPoints += matiereAvg * coeff;
      totalCoeff += coeff;
    });

    double avg = totalCoeff > 0 ? totalPoints / totalCoeff : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey[100]!,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildContentHeader(
                  Icons.analytics,
                  '$trimester${trimester == 1 ? "er" : "ème"} Trimestre',
                ),
                Text(
                  'Moyenne: ${avg.toStringAsFixed(2)}/${notes.first['note_max'] ?? 20}',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FixedColumnWidth(60),
              2: FixedColumnWidth(80),
              3: FixedColumnWidth(80),
              4: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.02)
                      : Colors.grey[50],
                ),
                children: [
                  _buildCell('MATIÈRE', isDark: isDark, isHeader: true),
                  _buildCell(
                    'COEFF',
                    isDark: isDark,
                    isHeader: true,
                    alignCenter: true,
                  ),
                  _buildCell(
                    'SEQ 1',
                    isDark: isDark,
                    isHeader: true,
                    alignCenter: true,
                  ),
                  _buildCell(
                    'SEQ 2',
                    isDark: isDark,
                    isHeader: true,
                    alignCenter: true,
                  ),
                  _buildCell(
                    'MOYENNE',
                    isDark: isDark,
                    isHeader: true,
                    alignRight: true,
                  ),
                ],
              ),
              ...byMatiere.entries.map((entry) {
                final matNotes = entry.value;
                final r = matNotes.first;

                // Group by sequence for this subject
                double? seq1 = matNotes
                    .where((n) => n['sequence'] == 1)
                    .map((n) => (n['note'] as num).toDouble())
                    .fold<double?>(null, (p, c) => c);
                double? seq2 = matNotes
                    .where((n) => n['sequence'] == 2)
                    .map((n) => (n['note'] as num).toDouble())
                    .fold<double?>(null, (p, c) => c);

                double matiereMoy = 0;
                if (matNotes.isNotEmpty) {
                  double mSum = 0;
                  for (var n in matNotes) mSum += (n['note'] as num).toDouble();
                  matiereMoy = mSum / matNotes.length;
                }

                return TableRow(
                  children: [
                    _buildCell(
                      r['matiere_nom'] ?? 'N/A',
                      isBold: true,
                      isDark: isDark,
                    ),
                    _buildCell(
                      r['coefficient']?.toString() ?? '1',
                      alignCenter: true,
                      isDark: isDark,
                    ),
                    _buildCell(
                      seq1?.toString() ?? '--',
                      alignCenter: true,
                      isDark: isDark,
                    ),
                    _buildCell(
                      seq2?.toString() ?? '--',
                      alignCenter: true,
                      isDark: isDark,
                    ),
                    _buildCell(
                      matiereMoy.toStringAsFixed(2),
                      isDark: isDark,
                      alignRight: true,
                      color: AppTheme.primaryColor,
                      isBold: true,
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCell(
    String text, {
    required bool isDark,
    bool isHeader = false,
    bool alignCenter = false,
    bool alignRight = false,
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        text,
        textAlign: alignCenter
            ? TextAlign.center
            : (alignRight ? TextAlign.right : TextAlign.left),
        style: TextStyle(
          fontSize: isHeader ? 11 : 13,
          fontWeight: isHeader || isBold ? FontWeight.bold : FontWeight.normal,
          color: isHeader
              ? (isDark ? AppTheme.textDarkSecondary : AppTheme.textSecondary)
              : (color ?? (isDark ? Colors.white : AppTheme.textPrimary)),
        ),
      ),
    );
  }

  Widget _buildCellBadge(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_empty, size: 48, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            msg,
            style: TextStyle(
              color: isDark
                  ? AppTheme.textDarkSecondary
                  : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dt = DateTime.parse(date.toString());
      return DateFormat('dd MMM yyyy', 'fr_FR').format(dt);
    } catch (e) {
      return date.toString();
    }
  }

  String _formatCurrency(dynamic amount) {
    final formatter = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'GNF',
      decimalDigits: 0,
    );
    return formatter.format(amount ?? 0);
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final Widget _tabBar;

  @override
  double get minExtent => 52; // Hauteur approximative du TabBar + bordure
  @override
  double get maxExtent => 52;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return _tabBar;
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
