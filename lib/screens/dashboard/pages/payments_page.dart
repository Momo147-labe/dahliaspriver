import 'dart:io';
import 'dart:math' as Math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/database/database_helper.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/academic_year_provider.dart';
import '../../../widgets/reports/payment_receipt_pdf.dart';
import 'payment/new_payment_page.dart';
import 'payment/payment_control_page.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage>
    with TickerProviderStateMixin {
  final dbHelper = DatabaseHelper.instance;

  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _recoveryByClass = [];
  List<Map<String, dynamic>> _paymentMethods = [];
  List<Map<String, dynamic>> _recentTransactions = [];

  bool _isLoading = true;
  bool _isLoadingPayments = false;
  int? _lastLoadedAnneeId;
  int _currentPage = 1;
  final int _itemsPerPage = 50;
  int _totalPayments = 0;
  String _searchQuery = '';
  String _selectedModeFilter = 'Tous';
  final TextEditingController _searchController = TextEditingController();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final anneeId = context.watch<AcademicYearProvider>().selectedAnneeId;
    if (anneeId != null && anneeId != _lastLoadedAnneeId) {
      _lastLoadedAnneeId = anneeId;
      _refreshDashboard(anneeId);
    }
  }

  Future<void> _refreshDashboard(int anneeId) async {
    setState(() {
      _isLoading = true;
      _currentPage = 1; // Reset to first page
    });
    try {
      final summary = await dbHelper.getFinancialSummary(anneeId);
      final recovery = await dbHelper.getRecoveryByClass(anneeId);
      final methods = await dbHelper.getPaymentMethodsBreakdown(anneeId);

      // Load first page of transactions and total count
      final total = await dbHelper.countPayments(anneeId);
      final transactions = await dbHelper.getRecentTransactions(
        anneeId,
        limit: _itemsPerPage,
        offset: 0,
      );

      setState(() {
        _summary = summary;
        _recoveryByClass = recovery;
        _paymentMethods = methods;
        _recentTransactions = transactions;
        _totalPayments = total;
        _isLoading = false;
      });
      _fadeController.forward(from: 0.0);
    } catch (e) {
      debugPrint('Error refreshing dashboard: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPaginatedPayments() async {
    if (_lastLoadedAnneeId == null) return;

    setState(() => _isLoadingPayments = true);
    try {
      final offset = (_currentPage - 1) * _itemsPerPage;

      // Update totals in case filters changed
      final total = await dbHelper.countPayments(
        _lastLoadedAnneeId!,
        searchQuery: _searchQuery,
        modeFilter: _selectedModeFilter,
      );

      final transactions = await dbHelper.getRecentTransactions(
        _lastLoadedAnneeId!,
        limit: _itemsPerPage,
        offset: offset,
        searchQuery: _searchQuery,
        modeFilter: _selectedModeFilter,
      );

      setState(() {
        _recentTransactions = transactions;
        _totalPayments = total;
        _isLoadingPayments = false;
      });
    } catch (e) {
      debugPrint('Error loading paginated payments: $e');
      setState(() => _isLoadingPayments = false);
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _currentPage = 1;
    });
    _loadPaginatedPayments();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showNewPaymentForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NewPaymentPage()),
    );
    if (result == true) {
      if (_lastLoadedAnneeId != null) {
        _refreshDashboard(_lastLoadedAnneeId!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(isDark, theme),
                    const SizedBox(height: 32),
                    _buildStatsGrid(isDark, theme),
                    const SizedBox(height: 32),
                    _buildChartsSection(isDark, theme),
                    const SizedBox(height: 32),
                    _buildRecentTransactions(isDark, theme),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(bool isDark, ThemeData theme) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    final titleSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Vue d'ensemble des paiements",
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
        ),
        Text(
          'Gestion financière et recouvrement des frais de scolarité',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );

    final actionButtons = Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: isDesktop ? WrapAlignment.end : WrapAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: _showNewPaymentForm,
          icon: const Icon(Symbols.add, size: 24),
          label: const Text('Nouveau paiement'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            shadowColor: AppTheme.primaryColor.withValues(alpha: 0.4),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PaymentControlPage(),
              ),
            );
          },
          icon: const Icon(Symbols.assignment_ind, size: 24),
          label: const Text('Contrôle de paiement'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.primaryColor),
            ),
            elevation: 2,
          ),
        ),
        OutlinedButton.icon(
          onPressed: () {}, // Implementation later
          icon: const Icon(Symbols.download),
          label: const Text('Exporter'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );

    if (isDesktop) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: titleSection),
          const SizedBox(width: 24),
          actionButtons,
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [titleSection, const SizedBox(height: 24), actionButtons],
      );
    }
  }

  Widget _buildStatsGrid(bool isDark, ThemeData theme) {
    if (_summary == null) return const SizedBox.shrink();

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total attendu',
          '${NumberFormat('#,###', 'fr_FR').format(_summary!['expected'])} GNF',
          Symbols.payments,
          Colors.blue,
          'Prévisionnel annuel',
          isDark,
        ),
        _buildStatCard(
          'Total recouvré',
          '${NumberFormat('#,###', 'fr_FR').format(_summary!['collected'])} GNF',
          Symbols.account_balance_wallet,
          Colors.green,
          '${_summary!['growth'] >= 0 ? '+' : ''}${_summary!['growth'].toStringAsFixed(1)}% vs mois dernier',
          isDark,
          highlight: true,
        ),
        _buildStatCard(
          'Reste à percevoir',
          '${NumberFormat('#,###', 'fr_FR').format(_summary!['remaining'])} GNF',
          Symbols.pending_actions,
          Colors.orange,
          'Retards de paiement',
          isDark,
        ),
        _buildProgressCard(
          'Recouvrement',
          '${_summary!['recoveryRate'].toStringAsFixed(1)}%',
          Symbols.analytics,
          AppTheme.primaryColor,
          _summary!['recoveryRate'] / 100,
          isDark,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
    bool isDark, {
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: highlight
              ? color.withValues(alpha: 0.5)
              : (isDark ? Colors.white10 : Colors.grey.shade200),
          width: highlight ? 2 : 1,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: isDark ? Colors.white54 : AppTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: highlight ? color : Colors.grey,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(
    String title,
    String value,
    IconData icon,
    Color color,
    double progress,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: isDark ? Colors.white54 : AppTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection(bool isDark, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bar Chart - Recovery by class
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(32),
            height: 400,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recouvrement par classe',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Comparatif des paiements effectués par niveau d\'étude',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _recoveryByClass.isEmpty
                        ? [const Center(child: Text('Aucune donnée'))]
                        : _recoveryByClass.map((c) {
                            final double rate = (c['expected'] ?? 0) > 0
                                ? (c['paid'] ?? 0) / c['expected']
                                : 0.0;
                            return _buildBarItem(c['nom'], rate, isDark);
                          }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 32),
        // Pie/Ring Chart - Payment Methods
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(32),
            height: 400,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Modes de paiement',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Répartition des flux par canal',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Spacer(),
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: CircularProgressIndicator(
                          value: 0.7, // Dummy for visually similar ring
                          strokeWidth: 20,
                          backgroundColor: Colors.orange.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            _summary != null
                                ? NumberFormat.compact(
                                    locale: 'fr_FR',
                                  ).format(_summary!['collected'])
                                : '0',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text(
                            'TOTAL',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _buildMethodLegend(isDark),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBarItem(String label, double rate, bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
            width: 40,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: rate.clamp(0.01, 1.0),
              child: Container(
                width: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildMethodLegend(bool isDark) {
    if (_paymentMethods.isEmpty) return const SizedBox.shrink();

    return Column(
      children: _paymentMethods.map((m) {
        final String mode = m['mode']?.toString() ?? 'Inconnu';
        final int count = (m['count'] as num?)?.toInt() ?? 0;
        final double total = (m['total'] as num?)?.toDouble() ?? 0.0;
        final double allTotal = _summary?['collected'] ?? 1.0;
        final int percent = ((total / allTotal) * 100).round();

        Color color = Colors.grey;
        if (mode.toLowerCase().contains('esp')) color = AppTheme.primaryColor;
        if (mode.toLowerCase().contains('mob') ||
            mode.toLowerCase().contains('ora'))
          color = Colors.orange;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _legendItem('$mode ($count)', percent, color),
        );
      }).toList(),
    );
  }

  Widget _legendItem(String label, int percent, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        Text(
          '$percent%',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildRecentTransactions(bool isDark, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transactions récentes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _searchQuery.isEmpty && _selectedModeFilter == 'Tous'
                          ? 'Historique des $_totalPayments paiements enregistrés'
                          : '$_totalPayments résultats trouvés',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                Row(
                  children: [
                    SizedBox(
                      width: 250,
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Rechercher un élève...',
                          prefixIcon: const Icon(Symbols.search, size: 20),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade300,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade300,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        setState(() {
                          _selectedModeFilter = value;
                          _currentPage = 1;
                        });
                        _loadPaginatedPayments();
                      },
                      itemBuilder: (context) =>
                          [
                            'Tous',
                            'Espèces',
                            'Orange Money',
                            'Virement',
                            'Chèque',
                          ].map((mode) {
                            return PopupMenuItem(
                              value: mode,
                              child: Row(
                                children: [
                                  if (_selectedModeFilter == mode)
                                    const Icon(
                                      Symbols.check,
                                      size: 18,
                                      color: AppTheme.primaryColor,
                                    )
                                  else
                                    const SizedBox(width: 18),
                                  const SizedBox(width: 8),
                                  Text(mode),
                                ],
                              ),
                            );
                          }).toList(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedModeFilter != 'Tous'
                                ? AppTheme.primaryColor
                                : (isDark
                                      ? Colors.white10
                                      : Colors.grey.shade300),
                          ),
                          color: _selectedModeFilter != 'Tous'
                              ? AppTheme.primaryColor.withValues(alpha: 0.1)
                              : null,
                        ),
                        child: Row(
                          children: [
                            const Icon(Symbols.tune, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _selectedModeFilter == 'Tous'
                                  ? 'Filtres'
                                  : _selectedModeFilter,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildTransactionTable(isDark, theme),
          _buildPaginationControls(isDark),
        ],
      ),
    );
  }

  Widget _buildPaginationControls(bool isDark) {
    if (_totalPayments == 0) return const SizedBox.shrink();

    final totalPages = (_totalPayments / _itemsPerPage).ceil();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Affichage de ${(_currentPage - 1) * _itemsPerPage + 1} à ${Math.min(_currentPage * _itemsPerPage, _totalPayments)} sur $_totalPayments transactions',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Row(
            children: [
              _pageBtn(
                icon: Symbols.chevron_left,
                onPressed: _currentPage > 1 && !_isLoadingPayments
                    ? () {
                        setState(() => _currentPage--);
                        _loadPaginatedPayments();
                      }
                    : null,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Page $_currentPage sur $totalPages',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _pageBtn(
                icon: Symbols.chevron_right,
                onPressed: _currentPage < totalPages && !_isLoadingPayments
                    ? () {
                        setState(() => _currentPage++);
                        _loadPaginatedPayments();
                      }
                    : null,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pageBtn({
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isDark,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.shade100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildTransactionTable(bool isDark, ThemeData theme) {
    if (_isLoadingPayments) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width - 64,
        ),
        child: DataTable(
          horizontalMargin: 32,
          columnSpacing: 40,
          dataRowMaxHeight: 75,
          dataRowMinHeight: 65,
          headingRowHeight: 60,
          headingRowColor: WidgetStateProperty.all(
            isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50,
          ),
          columns: const [
            DataColumn(
              label: Text(
                'ÉLÈVE',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'CLASSE',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'DATE',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'MONTANT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              numeric: true,
            ),
            DataColumn(
              label: Text(
                'MODE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'STATUT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'ACTION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
          rows: _recentTransactions.map((t) {
            final date = DateTime.parse(t['date_paiement']);
            return DataRow(
              cells: [
                DataCell(
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.primaryColor.withValues(
                          alpha: 0.1,
                        ),
                        backgroundImage:
                            t['eleve_photo'] != null &&
                                t['eleve_photo'].isNotEmpty
                            ? FileImage(File(t['eleve_photo']))
                            : null,
                        child:
                            t['eleve_photo'] != null &&
                                t['eleve_photo'].isNotEmpty
                            ? null
                            : Text(
                                t['eleve_nom'][0],
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${t['eleve_prenom']} ${t['eleve_nom']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(Text(t['classe_nom'] ?? 'N/A')),
                DataCell(
                  Text(DateFormat('dd MMM, yyyy', 'fr_FR').format(date)),
                ),
                DataCell(
                  Text(
                    '${NumberFormat('#,###', 'fr_FR').format(t['montant'])} GNF',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      t['mode_paiement'].toString().toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Complété',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(
                      Icons.print,
                      color: Colors.blue,
                    ), // Replaced Symbols.print with Icons.print if Symbols not available, but Symbols was imported. Sticking to Symbols if needed but Icons is safer standard.
                    tooltip: 'Imprimer le reçu',
                    onPressed: () => _generateReceipt(t),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _generateReceipt(Map<String, dynamic> transaction) async {
    setState(() => _isLoading = true);
    try {
      final anneeId = context.read<AcademicYearProvider>().selectedAnneeId;
      if (anneeId == null) throw Exception("Année scolaire non sélectionnée");

      final annee = context.read<AcademicYearProvider>().allAnnees.firstWhere(
        (a) => a['id'] == anneeId,
      );

      // 1. Fetch School Info
      final schoolInfo = await dbHelper.getEcoleInfo();
      Uint8List? schoolLogo;
      if (schoolInfo['logo'] != null && File(schoolInfo['logo']).existsSync()) {
        schoolLogo = await File(schoolInfo['logo']).readAsBytes();
      }

      // 2. Fetch Student Photo
      Uint8List? studentPhoto;
      if (transaction['eleve_photo'] != null &&
          File(transaction['eleve_photo']).existsSync()) {
        studentPhoto = await File(transaction['eleve_photo']).readAsBytes();
      }

      // 3. Fetch Financial Status
      final financialStatus = await dbHelper.getStudentFinancialStatus(
        transaction['eleve_id'],
        anneeId,
      );

      // 4. Fetch Payment History
      final history = await dbHelper.getPaymentHistory(
        transaction['eleve_id'],
        anneeId,
      );

      // 5. Generate PDF
      await PaymentReceiptPdf.generateAndPrint(
        transaction: transaction,
        history: history,
        financialStatus: financialStatus,
        schoolInfo: schoolInfo,
        schoolLogo: schoolLogo,
        studentPhoto: studentPhoto,
        anneeScolaire: annee['annee']?.toString() ?? '',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la génération du reçu : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
