import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AttendanceTable extends StatelessWidget {
  final List<Map<String, dynamic>> levelStats;
  const AttendanceTable({super.key, required this.levelStats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final List<Map<String, dynamic>> attendanceData = levelStats.map((stat) {
      final total = stat['count'] as int? ?? 0;
      // Mocking presence for now as there is no attendance table yet
      final present = (total * 0.95).round();
      final absent = total - present;
      final rate = total > 0 ? (present / total * 100) : 0.0;

      return {
        'level': stat['niveau'] ?? 'Inconnu',
        'total': total,
        'present': present,
        'absent': absent,
        'rate': double.parse(rate.toStringAsFixed(1)),
      };
    }).toList();

    return Container(
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
          // En-tête du tableau
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.hoverDark : AppTheme.hoverLight,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Niveau / Cycle',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                      letterSpacing: 1.2,
                      fontSize: 10,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Effectif',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                      letterSpacing: 1.2,
                      fontSize: 10,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Présents',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                      letterSpacing: 1.2,
                      fontSize: 10,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Absents',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                      letterSpacing: 1.2,
                      fontSize: 10,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Taux',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                      letterSpacing: 1.2,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Corps du tableau
          if (attendanceData.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'Aucune donnée d\'effectif disponible',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ...attendanceData.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            final isLast = index == attendanceData.length - 1;

            return InkWell(
              onTap: () {
                // TODO: Action lors du clic sur une ligne
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? AppTheme.borderDark
                          : AppTheme.borderLight,
                      width: isLast ? 0 : 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        data['level'],
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        data['total'].toString(),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        data['present'].toString(),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        data['absent'].toString(),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getRateColor(data['rate']).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${data['rate']}%',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: _getRateColor(data['rate']),
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Color _getRateColor(double rate) {
    if (rate >= 95) return Colors.green;
    if (rate >= 90) return Colors.blue;
    return Colors.orange;
  }
}
