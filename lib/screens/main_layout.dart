import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';
import '../core/database/database_helper.dart';
import '../widgets/dashboard/header.dart';
import '../widgets/dashboard/school_profile_card.dart';

// Pages dashboard
import 'dashboard/pages/dashboard_overview.dart';
import 'dashboard/pages/students_page.dart';
import 'dashboard/pages/promotion_page.dart';
import 'dashboard/pages/classes_page.dart';
import 'dashboard/pages/teachers_page.dart';
import 'dashboard/pages/subjects_page.dart';
import 'dashboard/pages/courses_page.dart';
import 'dashboard/pages/schedule_page.dart';
import 'dashboard/pages/frais_page.dart';
import 'dashboard/pages/payments_page.dart';
import 'dashboard/pages/grades_page.dart';
import 'dashboard/pages/reports_page.dart';
import 'dashboard/pages/analytics_page.dart';
import 'dashboard/pages/settings_page.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  Map<String, dynamic>? schoolData;
  bool _isLoading = true;
  bool _isCollapsed = false; // État de réduction du sidebar
  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();
    _loadSchool();
    pages = [
      DashboardOverview(
        onNavigate: (index) {
          if (index >= 0 && index < titles.length) {
            setState(() => _currentIndex = index);
          }
        },
      ),
      const StudentsPage(),
      const PromotionPage(),
      const ClassesPage(),
      const TeachersPage(),
      const SubjectsPage(),
      const CoursesPage(),
      const SchedulePage(),
      const FraisPage(),
      const PaymentsPage(),
      const GradesPage(),
      const ReportsPage(),
      const AnalyticsPage(),
      SettingsPage(onRetour: () => setState(() => _currentIndex = 0)),
    ];
  }

  Future<void> _loadSchool() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('ecole', limit: 1);
    if (result.isNotEmpty) schoolData = result.first;
    setState(() => _isLoading = false);
  }

  // ===================== TITRES =====================
  final List<String> titles = [
    'Dashboard',
    'Élèves',
    'Promotions',
    'Classes',
    'Enseignants',
    'Matières',
    'Cours',
    'Emploi du temps',
    'Frais scolaires',
    'Paiements',
    'Notes',
    'Bulletins & Rapports',
    'Analytique',
    'Paramètres',
  ];

  // ===================== ICONES =====================
  final List<IconData> icons = [
    Icons.dashboard,
    Icons.group,
    Icons.auto_awesome_motion,
    Icons.class_,
    Icons.person,
    Icons.menu_book,
    Icons.school,
    Icons.calendar_month,
    Icons.how_to_reg,
    Icons.attach_money,
    Icons.payment,
    Icons.grade,
    Icons.description,
    Icons.analytics,
    Icons.settings,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.backgroundDark
          : AppTheme.backgroundLight,
      drawer: isMobile && titles[_currentIndex] != 'Paramètres'
          ? _mobileDrawer(isDark)
          : null,
      appBar: isMobile && titles[_currentIndex] != 'Paramètres'
          ? AppBar(
              title: Text(titles[_currentIndex]),
              actions: [
                IconButton(
                  icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                  onPressed: () => context.read<ThemeProvider>().toggleTheme(),
                ),
              ],
            )
          : null,
      body: Row(
        children: [
          if (!isMobile && titles[_currentIndex] != 'Paramètres')
            _sidebar(isDark),
          Expanded(
            child: Column(
              children: [
                if (!isMobile && titles[_currentIndex] != 'Paramètres')
                  Header(pageTitle: titles[_currentIndex]),
                Expanded(child: pages[_currentIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===================== SIDEBAR =====================
  Widget _sidebar(bool isDark) {
    final sidebarWidth = _isCollapsed ? 80.0 : 250.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
        border: Border(
          right: BorderSide(
            color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          ),
        ),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              if (!_isCollapsed)
                SchoolProfileCard(
                  school: schoolData,
                  isDark: isDark,
                  isLoading: _isLoading,
                )
              else
                const SizedBox(
                  height: 56,
                ), // Réserve l'espace pour le bouton en mode réduit
              Expanded(child: _menu(isDark)),
            ],
          ),

          // Bouton de réduction en position absolue
          Positioned(
            top: 12,
            right: _isCollapsed ? 0 : 12,
            left: _isCollapsed ? 0 : null,
            child: Align(
              alignment: _isCollapsed
                  ? Alignment.center
                  : Alignment.centerRight,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    debugPrint('Sidebar toggle clicked: !$_isCollapsed');
                    setState(() => _isCollapsed = !_isCollapsed);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white10
                          : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    child: Icon(
                      _isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                      size: 20,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===================== MENU =====================
  Widget _menu(bool isDark) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView.builder(
        padding: EdgeInsets.symmetric(
          horizontal: _isCollapsed ? 8 : 12,
          vertical: 8,
        ),
        itemCount: titles.length,
        itemBuilder: (_, i) {
          final selected = _currentIndex == i;

          // Mode Réduit
          if (_isCollapsed) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Tooltip(
                message: titles[i],
                preferBelow: false,
                child: InkWell(
                  onTap: () => setState(() => _currentIndex = i),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: selected
                          ? AppTheme.primaryColor.withOpacity(0.15)
                          : Colors.transparent,
                    ),
                    child: Center(
                      child: Icon(
                        icons[i],
                        size: 24,
                        color: selected
                            ? AppTheme.primaryColor
                            : isDark
                            ? Colors.white70
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          // Mode Étendu
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: selected
                    ? AppTheme.primaryColor.withOpacity(0.15)
                    : Colors.transparent,
                border: selected
                    ? const Border(
                        left: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 3,
                        ),
                      )
                    : null,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  width: 250,
                  child: InkWell(
                    onTap: () => setState(() => _currentIndex = i),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icons[i],
                            size: 20,
                            color: selected
                                ? AppTheme.primaryColor
                                : isDark
                                ? Colors.white70
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              titles[i],
                              overflow: TextOverflow.clip,
                              softWrap: false,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: selected
                                    ? AppTheme.primaryColor
                                    : isDark
                                    ? Colors.white70
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ===================== DRAWER MOBILE =====================
  Drawer _mobileDrawer(bool isDark) {
    return Drawer(
      child: Column(
        children: [
          SchoolProfileCard(
            school: schoolData,
            isDark: isDark,
            isLoading: _isLoading,
          ),
          Expanded(child: _menu(isDark)),
        ],
      ),
    );
  }
}
