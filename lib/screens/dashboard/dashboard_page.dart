import 'package:flutter/material.dart';
import '../../widgets/dashboard/sidebar.dart';
import '../../widgets/dashboard/header.dart';
import 'pages/dashboard_overview.dart';
import 'pages/students_page.dart';
import 'pages/classes_page.dart';
import 'pages/teachers_page.dart';
import 'pages/subjects_page.dart';
import 'pages/courses_page.dart';
import 'pages/schedule_page.dart';
import 'pages/payments_page.dart';
import 'pages/grades_page.dart';
import 'pages/reports_page.dart';
import 'pages/analytics_page.dart';
import 'pages/settings_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DashboardOverview(),
    const StudentsPage(),
    const ClassesPage(),
    const TeachersPage(),
    const SubjectsPage(),
    const CoursesPage(),
    const SchedulePage(),
    const PaymentsPage(),
    const GradesPage(),
    const ReportsPage(),
    const AnalyticsPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F8),
      body: Row(
        children: [
          Sidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: (index) => setState(() => _selectedIndex = index),
          ),
          Expanded(
            child: Column(
              children: [
                const Header(pageTitle: 'Dashboard'),
                Expanded(
                  child: _selectedIndex == 0
                      ? DashboardOverview(
                          onNavigate: (index) =>
                              setState(() => _selectedIndex = index),
                        )
                      : _pages[_selectedIndex],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
