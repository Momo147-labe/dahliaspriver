import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';
import '../core/database/database_helper.dart';
import '../widgets/dashboard/header.dart';
import '../widgets/dashboard/sidebar.dart';

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
          ? Drawer(
              child: Sidebar(
                selectedIndex: _currentIndex,
                onItemSelected: (index) {
                  setState(() => _currentIndex = index);
                  Navigator.pop(context);
                },
                isCollapsed: false,
                onToggle: () {},
                schoolData: schoolData,
                isLoading: _isLoading,
                titles: titles,
                icons: icons,
              ),
            )
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
            Sidebar(
              selectedIndex: _currentIndex,
              onItemSelected: (index) => setState(() => _currentIndex = index),
              isCollapsed: _isCollapsed,
              onToggle: () => setState(() => _isCollapsed = !_isCollapsed),
              schoolData: schoolData,
              isLoading: _isLoading,
              titles: titles,
              icons: icons,
            ),
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
}
