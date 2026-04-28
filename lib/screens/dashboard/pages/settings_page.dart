import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../../theme/app_theme.dart';
import 'settings/school_settings_page.dart';
import 'settings/academic_year_settings_page.dart';
import 'settings/user_settings_page.dart';
import 'settings/subpages/cycle_level_settings_page.dart';
import 'settings/subpages/grading_settings_page.dart';
import 'settings/subpages/evaluation_planning_settings_page.dart';
import 'settings/subpages/appreciation_settings_page.dart';
import '../../../widgets/common/typewriter_text.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback? onRetour;
  const SettingsPage({super.key, this.onRetour});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _selectedIndex = 0;

  // Notifier incrémenté à chaque changement d'onglet pour forcer le rechargement
  final _reloadNotifier = ValueNotifier<int>(0);

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
    {
      'icon': Icons.functions,
      'label': 'Méthodes de calcul',
      'isAction': false,
    },
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
      GradingSettingsPage(reloadNotifier: _reloadNotifier),
      const EvaluationPlanningSettingsPage(),
      const AppreciationSettingsPage(),
      const GradeCalculationMethodsPage(),
      const UserSettingsPage(),
    ];
  }

  @override
  void dispose() {
    _reloadNotifier.dispose();
    super.dispose();
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
                                ? AppTheme.primaryColor.withValues(alpha: 0.1)
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
                                // Notifier les pages qui doivent se recharger
                                _reloadNotifier.value++;
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
                            title: isSelected
                                ? TypewriterText(
                                    text: item['label'] as String,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                                  )
                                : Text(
                                    item['label'] as String,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isAction
                                          ? Colors.redAccent
                                          : (isDark
                                                ? Colors.white70
                                                : AppTheme.textSecondary),
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

class GradeCalculationMethodsPage extends StatelessWidget {
  const GradeCalculationMethodsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Méthodes de calcul des notes',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cette page décrit les formules de calcul usuelles avec une notation LaTeX.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white70 : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          _FormulaCard(
            title: '1) Moyenne par matière (trimestre)',
            description:
                'On calcule la moyenne des notes obtenues dans toutes les évaluations de la matière.',
            latex: r'\bar{M}_{\text{matière}}=\frac{\sum_{i=1}^{n} N_i}{n}',
          ),
          const SizedBox(height: 16),
          _FormulaCard(
            title: '2) Moyenne pondérée par coefficient',
            description:
                'Chaque matière contribue selon son coefficient. Plus le coefficient est élevé, plus son impact est important.',
            latex:
                r'\bar{M}_{\text{générale}}=\frac{\sum_{j=1}^{m}\left(\bar{M}_j\times C_j\right)}{\sum_{j=1}^{m} C_j}',
          ),
          const SizedBox(height: 16),
          _FormulaCard(
            title: '3) Points totaux',
            description:
                'Les points d\'une matière sont la moyenne de la matière multipliée par son coefficient.',
            latex:
                r'P_{\text{total}}=\sum_{j=1}^{m}\left(\bar{M}_j\times C_j\right)',
          ),
          const SizedBox(height: 16),
          _FormulaCard(
            title: '4) Moyenne annuelle par matière',
            description:
                'Si plusieurs trimestres existent, on fait la moyenne des moyennes trimestrielles.',
            latex:
                r'\bar{M}_{\text{annuelle, matière}}=\frac{\bar{M}_{T1}+\bar{M}_{T2}+\bar{M}_{T3}}{3}',
          ),
          const SizedBox(height: 16),
          _FormulaCard(
            title: '5) Classement',
            description:
                'Le rang est déterminé par tri décroissant de la moyenne générale.',
            latex:
                r'\text{Rang}(e)=1+\left|\left\{k\mid \bar{M}_k>\bar{M}_e\right\}\right|',
          ),
          const SizedBox(height: 16),
          _FormulaCard(
            title: '6) Mention (exemple de règle)',
            description:
                'Exemple courant: la mention dépend d\'intervalles de moyenne.',
            latex:
                r'\text{Mention}=\begin{cases}\text{Très bien} & \bar{M}\geq 16\\\text{Bien} & 14\leq\bar{M}<16\\\text{Assez bien} & 12\leq\bar{M}<14\\\text{Passable} & 10\leq\bar{M}<12\\\text{Insuffisant} & \bar{M}<10\end{cases}',
          ),
        ],
      ),
    );
  }
}

class _FormulaCard extends StatelessWidget {
  final String title;
  final String description;
  final String latex;

  const _FormulaCard({
    required this.title,
    required this.description,
    required this.latex,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: isDark ? Colors.white70 : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.backgroundDark.withValues(alpha: 0.7)
                  : AppTheme.backgroundLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Math.tex(
                latex,
                textStyle: TextStyle(
                  fontSize: 17,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
