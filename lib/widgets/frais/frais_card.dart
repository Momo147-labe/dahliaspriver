import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../theme/app_theme.dart';

class FraisCard extends StatelessWidget {
  final Map<String, dynamic> frais;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const FraisCard({
    super.key,
    required this.frais,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, Colors.orange.shade400],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isDark),
                  const SizedBox(height: 24),
                  _buildMainFees(isDark),
                  const SizedBox(height: 24),
                  _buildInstallments(isDark),
                  const SizedBox(height: 24),
                  _buildFooter(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Symbols.school, color: AppTheme.primaryColor, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${frais['classe_nom']} - ${frais['classe_niveau']}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.blueGrey.shade900,
                ),
              ),
              Text(
                'Année Scolaire: ${frais['annee_libelle']}',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.blueGrey.shade400,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: onEdit,
              icon: const Icon(Symbols.edit, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: Colors.blue.withOpacity(0.1),
                foregroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: onDelete,
              icon: const Icon(Symbols.delete, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.1),
                foregroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainFees(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildFeeBadge(
            'Inscription',
            '${(frais['inscription'] ?? 0.0).toStringAsFixed(0)} FG',
            Symbols.badge,
            AppTheme.primaryColor,
            isDark,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildFeeBadge(
            'Réinscription',
            '${(frais['reinscription'] ?? 0.0).toStringAsFixed(0)} FG',
            Symbols.sync_alt,
            Colors.orange,
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildFeeBadge(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.blueGrey.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstallments(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Symbols.calendar_month,
              size: 18,
              color: Colors.blueGrey,
            ),
            const SizedBox(width: 8),
            Text(
              'Tranches de paiement',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.blueGrey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildTrancheItem(
              'T1',
              (frais['tranche1'] ?? 0.0),
              frais['date_limite_t1'] ?? '',
              Colors.blue,
              isDark,
            ),
            const SizedBox(width: 12),
            _buildTrancheItem(
              'T2',
              (frais['tranche2'] ?? 0.0),
              frais['date_limite_t2'] ?? '',
              Colors.green,
              isDark,
            ),
            const SizedBox(width: 12),
            _buildTrancheItem(
              'T3',
              (frais['tranche3'] ?? 0.0),
              frais['date_limite_t3'] ?? '',
              Colors.purple,
              isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrancheItem(
    String label,
    double amount,
    String date,
    Color color,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.blueGrey.shade900,
              ),
            ),
            if (date.isNotEmpty)
              Text(
                date,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white38 : Colors.blueGrey.shade300,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            Colors.orange.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Symbols.account_balance,
                color: AppTheme.primaryColor,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                'Montant Total',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.blueGrey.shade700,
                ),
              ),
            ],
          ),
          Text(
            '${(frais['montant_total'] ?? 0.0).toStringAsFixed(0)} FG',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
