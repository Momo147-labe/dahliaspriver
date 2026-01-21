import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';

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

  // Design Tokens from Template
  final Color _primaryColor = const Color(0xFF22C3C3);
  final Color _headerEndColor = const Color(0xFF1A9B9B);
  final Color _bgLight = const Color(0xFFF9FAFA);
  final Color _bgDark = const Color(0xFF21262C);
  final Color _textMain = const Color(0xFF121717);
  final Color _textSecondary = const Color(0xFF658686);

  // Calculated Stats
  double _totalAverage = 0.0;
  double _totalBalance = 0.0;
  Map<int, double> _yearlyAverages = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    double balance = 0.0;
    for (var p in _payments) {
      balance +=
          (p['montant_total'] as num? ?? 0.0) -
          (p['montant_paye'] as num? ?? 0.0);
    }
    _totalBalance = balance;

    if (_results.isNotEmpty) {
      double sum = 0;
      for (var r in _results) sum += (r['note'] as num? ?? 0.0).toDouble();
      _totalAverage = sum / _results.length;
    }

    _yearlyAverages = {};
    for (var p in _parcours) {
      int? anneeId = p['annee_id'];
      if (anneeId == null) continue;
      var yearGrades = _results
          .where((r) => r['annee_scolaire_id'] == anneeId)
          .toList();
      if (yearGrades.isNotEmpty) {
        double yearSum = 0;
        for (var g in yearGrades)
          yearSum += (g['note'] as num? ?? 0.0).toDouble();
        _yearlyAverages[anneeId] = yearSum / yearGrades.length;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? _bgDark : _bgLight,
        body: Center(child: CircularProgressIndicator(color: _primaryColor)),
      );
    }

    if (_student == null) {
      return Scaffold(
        backgroundColor: isDark ? _bgDark : _bgLight,
        body: Center(child: Text('Élève introuvable')),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? _bgDark : _bgLight,
      body: CustomScrollView(
        slivers: [
          _buildSliverHeader(isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: _buildSummaryStatsRow(isDark),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: _buildTabNavigation(isDark),
            ),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildParcoursTab(isDark),
                _buildResultsTab(isDark),
                _buildFinanceTab(isDark),
                _buildAttendanceTab(isDark),
              ],
            ),
          ),
        ],
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
              '${_totalAverage.toStringAsFixed(2)}/20',
              isDark,
              _primaryColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryItem(
              Icons.calendar_month,
              'Assiduité',
              '95%',
              isDark,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryItem(
              Icons.account_balance_wallet,
              'Solde',
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
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : _textMain,
              fontSize: 16,
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
    return SliverToBoxAdapter(
      child: Column(
        children: [
          // Banner
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, _headerEndColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Row(
                          children: [
                            _buildBannerButton(Icons.print, 'Imprimer', () {}),
                            const SizedBox(width: 8),
                            _buildBannerButton(
                              Icons.edit,
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
              ),
              // Profile Pic Overlap
              Positioned(
                bottom: -40,
                left: 24,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? _bgDark : Colors.white,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    backgroundImage:
                        s['photo'] != null && s['photo'].toString().isNotEmpty
                        ? FileImage(File(s['photo'].toString()))
                        : null,
                    backgroundColor: Colors.grey[200],
                    child: s['photo'] == null || s['photo'].toString().isEmpty
                        ? Icon(Icons.person, size: 60, color: _textSecondary)
                        : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 50),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${s['prenom']} ${s['nom']}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : _textMain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          _buildHeaderSubtitle(
                            Icons.fingerprint,
                            s['matricule'] ?? 'N/A',
                          ),
                          _buildHeaderSeparator(),
                          _buildHeaderSubtitle(
                            Icons.school,
                            s['classe_nom'] ?? 'Sans classe',
                          ),
                          _buildHeaderSeparator(),
                          _buildStatusBadge(s['statut'] ?? 'Inscrit'),
                        ],
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.call, size: 18),
                  label: const Text('Contacter Parent'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
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
      icon: Icon(icon, size: 16, color: isWhite ? _primaryColor : Colors.white),
      label: Text(
        label,
        style: TextStyle(
          color: isWhite ? _primaryColor : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
      style: TextButton.styleFrom(
        backgroundColor: isWhite ? Colors.white : Colors.white.withOpacity(0.2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildHeaderSubtitle(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: _textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: _textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderSeparator() {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[300],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: _primaryColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTabNavigation(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelPadding: const EdgeInsets.only(right: 24),
        indicatorColor: _primaryColor,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: _primaryColor,
        unselectedLabelColor: _textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        indicatorWeight: 3,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(
            child: Row(
              children: [
                Icon(Icons.history_edu, size: 18),
                SizedBox(width: 8),
                Text('Parcours'),
              ],
            ),
          ),
          Tab(
            child: Row(
              children: [
                Icon(Icons.assessment, size: 18),
                SizedBox(width: 8),
                Text('Résultats'),
              ],
            ),
          ),
          Tab(
            child: Row(
              children: [
                Icon(Icons.payments, size: 18),
                SizedBox(width: 8),
                Text('Paiements'),
              ],
            ),
          ),
          Tab(
            child: Row(
              children: [
                Icon(Icons.calendar_month, size: 18),
                SizedBox(width: 8),
                Text('Absences'),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildBioItem(
                Icons.cake,
                'Né(e) le',
                s['date_naissance'] ?? 'Non renseigné',
                isDark,
              ),
              _buildBioItem(
                Icons.location_on,
                'Lieu',
                s['lieu_naissance'] ?? 'Non renseigné',
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildBioItem(
                Icons.wc,
                'Genre',
                s['sexe'] == 'M' ? 'Masculin' : 'Féminin',
                isDark,
              ),
              _buildBioItem(
                Icons.badge,
                'Matricule',
                s['matricule'] ?? 'N/A',
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: _primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: isDark ? Colors.white : _textMain,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
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
    if (_parcours.isEmpty) return _buildEmptyState('Aucun parcours enregistré');

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
                        color: isDark ? _bgDark : Colors.white,
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
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : _textMain,
                        ),
                      ),
                      Text(
                        p['annee_nom'] ?? 'N/A',
                        style: TextStyle(
                          color: isFirst ? _primaryColor : _textSecondary,
                          fontSize: 12,
                          fontWeight: isFirst
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isFirst
                              ? _primaryColor.withOpacity(0.05)
                              : (isDark
                                    ? Colors.white.withOpacity(0.02)
                                    : Colors.grey[50]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Moyenne Générale',
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              _yearlyAverages[p['annee_id']] != null
                                  ? '${_yearlyAverages[p['annee_id']]!.toStringAsFixed(2)} / 20'
                                  : '-- / 20',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: isFirst
                                    ? _primaryColor
                                    : (isDark ? Colors.white : _textMain),
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
        Icon(icon, color: _primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildContactCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : _textMain,
        borderRadius: BorderRadius.circular(16),
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
                  color: Colors.white.withOpacity(0.1),
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
                      'Moussa Condé',
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
    double totalDue = 0;
    double totalPaid = 0;
    for (var p in _payments) {
      totalDue += (p['montant_total'] as num?)?.toDouble() ?? 0.0;
      totalPaid += (p['montant_paye'] as num?)?.toDouble() ?? 0.0;
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
            color: _textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatCurrency(val),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color ?? (isDark ? Colors.white : _textMain),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() =>
      Container(width: 1, height: 40, color: Colors.grey[100]);

  Widget _buildPaymentsTable(bool isDark) {
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
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.5),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey[50]),
                children: [
                  _buildCell('DATE', isHeader: true),
                  _buildCell('LIBELLÉ', isHeader: true),
                  _buildCell('MONTANT', isHeader: true),
                  _buildCell('STATUT', isHeader: true),
                ],
              ),
              ..._payments.expand(
                (p) => (p['details'] as List? ?? []).map(
                  (d) => TableRow(
                    children: [
                      _buildCell(_formatDate(d['date_paiement'])),
                      _buildCell(d['type_frais'] ?? 'Paiement'),
                      _buildCell(_formatCurrency(d['montant']), isBold: true),
                      _buildCellBadge('Payé', Colors.green),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsTab(bool isDark) {
    if (_results.isEmpty) return _buildEmptyState('Aucune note enregistrée');

    final Map<int, List<Map<String, dynamic>>> grouped = {};
    for (var r in _results) {
      final t = r['trimestre'] ?? 1;
      grouped.putIfAbsent(t, () => []).add(r);
    }

    final sortedT = grouped.keys.toList()..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: sortedT
            .map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: _buildTrimesterCard(t, grouped[t]!, isDark),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTrimesterCard(
    int trimester,
    List<Map<String, dynamic>> notes,
    bool isDark,
  ) {
    double sum = 0;
    for (var n in notes) sum += (n['note'] as num? ?? 0.0).toDouble();
    double avg = sum / notes.length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
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
                  '${trimester}${trimester == 1 ? "er" : "ème"} Trimestre',
                ),
                Text(
                  'Moyenne: ${avg.toStringAsFixed(2)}/20',
                  style: TextStyle(
                    color: _primaryColor,
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
                      ? Colors.white.withOpacity(0.02)
                      : Colors.grey[50],
                ),
                children: [
                  _buildCell('MATIÈRE', isHeader: true),
                  _buildCell('COEFF', isHeader: true, alignCenter: true),
                  _buildCell('SEQ 1', isHeader: true, alignCenter: true),
                  _buildCell('SEQ 2', isHeader: true, alignCenter: true),
                  _buildCell('MOYENNE', isHeader: true, alignRight: true),
                ],
              ),
              ...notes.map(
                (r) => TableRow(
                  children: [
                    _buildCell(r['matiere_nom'] ?? 'N/A', isBold: true),
                    _buildCell('4', alignCenter: true), // Placeholder coeff
                    _buildCell(
                      r['sequence'] == 1 ? r['note'].toString() : '--',
                      alignCenter: true,
                    ),
                    _buildCell(
                      r['sequence'] == 2 ? r['note'].toString() : '--',
                      alignCenter: true,
                    ),
                    _buildCell(
                      r['note']?.toString() ?? '--',
                      alignRight: true,
                      color: _primaryColor,
                      isBold: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCell(
    String text, {
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
          color: isHeader ? _textSecondary : (color ?? _textMain),
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
            color: color.withOpacity(0.1),
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

  Widget _buildAttendanceTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildContentHeader(
            Icons.calendar_month,
            'Suivi des Présences - Janvier 2026',
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildCalendarGrid(isDark)),
              const SizedBox(width: 24),
              Expanded(flex: 1, child: _buildAttendanceSummary(isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        children: [
          // Days of Week Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          // Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: 31,
            itemBuilder: (context, index) {
              final day = index + 1;
              Color indicatorColor = Colors.green;
              if (day == 12 || day == 24) indicatorColor = Colors.red;
              if (day == 8 || day == 19) indicatorColor = Colors.orange;

              return Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : _textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: indicatorColor,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendRow(Colors.green, 'Présent'),
              const SizedBox(width: 16),
              _buildLegendRow(Colors.red, 'Absent'),
              const SizedBox(width: 16),
              _buildLegendRow(Colors.orange, 'Retard'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: _textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _buildAttendanceSummary(bool isDark) {
    return Column(
      children: [
        _buildTrendItem(
          'Taux de Présence',
          '95%',
          Icons.check_circle_outline,
          Colors.green,
          isDark,
        ),
        const SizedBox(height: 16),
        _buildTrendItem(
          'Absences Inj.',
          '2 jours',
          Icons.error_outline,
          Colors.red,
          isDark,
        ),
        const SizedBox(height: 16),
        _buildTrendItem(
          'Retards cumulés',
          '45 min',
          Icons.timer_outlined,
          Colors.orange,
          isDark,
        ),
      ],
    );
  }

  Widget _buildTrendItem(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: _textSecondary, fontSize: 11),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: isDark ? Colors.white : _textMain,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_empty, size: 48, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(msg, style: TextStyle(color: _textSecondary)),
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
