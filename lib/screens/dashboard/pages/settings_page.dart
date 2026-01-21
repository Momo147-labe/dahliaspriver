import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'settings/school_settings_page.dart';
import 'settings/academic_year_settings_page.dart';
import 'settings/user_settings_page.dart';
import 'settings/subpages/cycle_level_settings_page.dart';
import 'settings/subpages/grading_settings_page.dart';
import 'settings/subpages/evaluation_planning_settings_page.dart';
import 'settings/subpages/appreciation_settings_page.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback? onRetour;
  const SettingsPage({super.key, this.onRetour});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _selectedIndex = 0;

  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.arrow_back, 'label': 'Retour', 'isAction': true},
    {'icon': Icons.school, 'label': 'École', 'isAction': false},
    {
      'icon': Icons.calendar_today,
      'label': 'Année scolaire',
      'isAction': false,
    },
    {'icon': Icons.sync_alt, 'label': 'Cycles & Niveaux', 'isAction': false},
    {'icon': Icons.grading, 'label': 'Système de notation', 'isAction': false},
    {'icon': Icons.event_note, 'label': 'Planification', 'isAction': false},
    {'icon': Icons.text_fields, 'label': 'Texte & Lettre', 'isAction': false},
    {'icon': Icons.people, 'label': 'Utilisateurs', 'isAction': false},
  ];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const SchoolSettingsPage(),
      const AcademicYearSettingsPage(),
      const CycleLevelSettingsPage(),
      const GradingSettingsPage(),
      const EvaluationPlanningSettingsPage(),
      const AppreciationSettingsPage(),
      const UserSettingsPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.backgroundDark
          : AppTheme.backgroundLight,
      body: Row(
        children: [
          // Barre latérale gauche (Menu vertical fixe)
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
              border: Border(
                right: BorderSide(
                  color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'PARAMÈTRES',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _menuItems.length,
                    itemBuilder: (context, index) {
                      final item = _menuItems[index];
                      final isAction = item['isAction'] as bool;
                      final pageIndex =
                          index - 1; // Car "Retour" est à l'index 0
                      final isSelected =
                          !isAction && _selectedIndex == pageIndex;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: isSelected
                                ? AppTheme.primaryColor.withOpacity(0.1)
                                : Colors.transparent,
                            border: isSelected
                                ? const Border(
                                    left: BorderSide(
                                      color: AppTheme.primaryColor,
                                      width: 4,
                                    ),
                                  )
                                : null,
                          ),
                          child: ListTile(
                            onTap: () {
                              if (isAction) {
                                if (item['label'] == 'Retour' &&
                                    widget.onRetour != null) {
                                  widget.onRetour!();
                                }
                              } else {
                                setState(() => _selectedIndex = pageIndex);
                              }
                            },
                            leading: Icon(
                              item['icon'] as IconData,
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : (isAction
                                        ? Colors.redAccent
                                        : (isDark
                                              ? Colors.white70
                                              : AppTheme.textSecondary)),
                              size: 20,
                            ),
                            title: Text(
                              item['label'] as String,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : (isAction
                                          ? Colors.redAccent
                                          : (isDark
                                                ? Colors.white70
                                                : AppTheme.textSecondary)),
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Zone de contenu à droite
          Expanded(
            child: Container(
              color: isDark
                  ? AppTheme.backgroundDark
                  : AppTheme.backgroundLight,
              child: IndexedStack(index: _selectedIndex, children: _pages),
            ),
          ),
        ],
      ),
    );
  }
}
