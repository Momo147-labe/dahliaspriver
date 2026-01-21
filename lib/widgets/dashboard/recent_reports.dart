import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

import 'package:intl/intl.dart';

class RecentReports extends StatelessWidget {
  final List<Map<String, dynamic>> recentPayments;
  const RecentReports({super.key, required this.recentPayments});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'GNF',
      decimalDigits: 0,
    );

    final List<Map<String, dynamic>> reports = recentPayments
        .map<Map<String, dynamic>>((p) {
          final date = DateTime.parse(p['date_paiement']);
          final dateStr = DateFormat('dd MMM, HH:mm', 'fr_FR').format(date);

          return <String, dynamic>{
            'title': '${p['prenom']} ${p['nom']}',
            'subtitle':
                'Paiement: ${currencyFormat.format(p['montant'])} • $dateStr',
            'icon': Icons.payments_rounded,
            'iconColor': Colors.green,
            'iconBackgroundColor': Colors.green.withOpacity(0.1),
          };
        })
        .toList();

    if (reports.isEmpty) {
      reports.add(<String, dynamic>{
        'title': 'Aucune activité récente',
        'subtitle': 'Gérez vos paiements pour voir l\'historique',
        'icon': Icons.info_outline_rounded,
        'iconColor': Colors.grey,
        'iconBackgroundColor': Colors.grey.withOpacity(0.1),
      });
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Section Rapports Récents
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // En-tête
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.05),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? AppTheme.borderDark
                            : AppTheme.borderLight,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Activités Récentes',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                      Icon(
                        Icons.description,
                        color: AppTheme.primaryColor,
                        size: 16,
                      ),
                    ],
                  ),
                ),

                // Liste des rapports
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: reports.asMap().entries.map((entry) {
                      final index = entry.key;
                      final report = entry.value;
                      final isLast = index == reports.length - 1;

                      return Column(
                        children: [
                          InkWell(
                            onTap: () {
                              // TODO: Ouvrir le rapport
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: report['iconBackgroundColor'],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      report['icon'],
                                      color: report['iconColor'],
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          report['title'],
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          report['subtitle'],
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: AppTheme.textSecondary,
                                                fontSize: 10,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (!isLast)
                            Container(
                              margin: const EdgeInsets.only(
                                left: 12,
                                right: 12,
                                bottom: 12,
                              ),
                              height: 1,
                              color: isDark
                                  ? AppTheme.hoverDark
                                  : AppTheme.hoverLight,
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),

                // Bouton d'accès
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        // TODO: Accéder au centre de rapports
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text(
                        'Accéder au centre de rapports',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Notification Mode Hors Ligne
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.green.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.offline_pin, color: Colors.green, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Mode Hors Ligne Actif',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Les données de présence sont stockées localement et seront synchronisées dès que la connexion sera rétablie.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.green.shade700.withOpacity(0.8),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
