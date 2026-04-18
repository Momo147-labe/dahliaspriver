import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class Sidebar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> with SingleTickerProviderStateMixin {
  bool _isCollapsed = false;

  static const double _expandedWidth = 288;
  static const double _collapsedWidth = 72;

  late final AnimationController _animController;
  late final Animation<double> _widthAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _widthAnimation = Tween<double>(begin: _expandedWidth, end: _collapsedWidth)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
        );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isCollapsed = !_isCollapsed;
      if (_isCollapsed) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _widthAnimation,
      builder: (context, child) {
        final currentWidth = _widthAnimation.value;
        final isNarrow = currentWidth < (_expandedWidth + _collapsedWidth) / 2;

        return Container(
          width: currentWidth,
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
            border: Border(
              right: BorderSide(
                color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.2)
                    : Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(2, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildTopToggle(isDark, isNarrow),
              _buildHeader(isDark, isNarrow),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isNarrow ? 8 : 16),
                  child: Column(
                    children: [
                      _buildNavItem(
                        0,
                        Icons.dashboard,
                        'Dashboard',
                        isDark,
                        isNarrow,
                      ),
                      _buildNavItem(1, Icons.group, 'Élèves', isDark, isNarrow),
                      _buildNavItem(
                        2,
                        Icons.meeting_room,
                        'Classes',
                        isDark,
                        isNarrow,
                      ),
                      _buildNavItem(
                        3,
                        Icons.person,
                        'Enseignants',
                        isDark,
                        isNarrow,
                      ),
                      _buildNavItem(
                        4,
                        Icons.menu_book,
                        'Matières',
                        isDark,
                        isNarrow,
                      ),
                      _buildNavItem(
                        5,
                        Icons.history_edu,
                        'Cours',
                        isDark,
                        isNarrow,
                      ),
                      _buildNavItem(
                        6,
                        Icons.calendar_today,
                        'Emploi du temps',
                        isDark,
                        isNarrow,
                      ),
                      _buildNavItem(
                        7,
                        Icons.how_to_reg,
                        'Présences',
                        isDark,
                        isNarrow,
                      ),
                      const SizedBox(height: 16),
                      if (!isNarrow)
                        _buildSectionHeader(
                          'Finance \u0026 Académique',
                          isDark,
                        ),
                      if (isNarrow)
                        Divider(
                          color: (isDark
                              ? AppTheme.borderDark
                              : AppTheme.borderLight),
                          height: 24,
                        ),
                      _buildNavItem(
                        8,
                        Icons.account_balance,
                        'Frais Scolaire',
                        isDark,
                        isNarrow,
                      ),
                      _buildNavItem(
                        9,
                        Icons.fact_check,
                        'Contrôle de Paiements',
                        isDark,
                        isNarrow,
                      ),
                      _buildNavItem(10, Icons.grade, 'Notes', isDark, isNarrow),
                      _buildNavItem(
                        11,
                        Icons.description,
                        'Bulletins',
                        isDark,
                        isNarrow,
                      ),
                      _buildNavItem(
                        12,
                        Icons.analytics,
                        'Rapport',
                        isDark,
                        isNarrow,
                      ),
                      const SizedBox(height: 16),
                      _buildNavItem(
                        13,
                        Icons.settings,
                        'Paramètres',
                        isDark,
                        isNarrow,
                      ),
                    ],
                  ),
                ),
              ),
              _buildLogoutButton(isDark, isNarrow),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopToggle(bool isDark, bool isNarrow) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 12, vertical: 8),
      width: double.infinity,
      child: Align(
        alignment: isNarrow ? Alignment.center : Alignment.centerRight,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggleSidebar,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Icon(
                isNarrow
                    ? Icons.chevron_right_rounded
                    : Icons.chevron_left_rounded,
                size: 20,
                color: isDark
                    ? AppTheme.textDarkSecondary
                    : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, bool isNarrow) {
    return Container(
      padding: EdgeInsets.only(
        top: 0,
        left: isNarrow ? 8 : 16,
        right: isNarrow ? 8 : 16,
        bottom: 12,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: isNarrow
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.school, color: Colors.white, size: 20),
              ),
              if (!isNarrow) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Guinée École',
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.textDarkPrimary
                              : AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'GESTION SCOLAIRE',
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.textDarkSecondary
                              : AppTheme.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
            height: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String title,
    bool isDark,
    bool isNarrow,
  ) {
    final isSelected = widget.selectedIndex == index;

    final child = Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primaryColor.withOpacity(0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
                width: 1,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onItemSelected(index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 0 : 16,
              vertical: 12,
            ),
            child: isNarrow
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        size: 20,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                  ? AppTheme.textDarkSecondary
                                  : AppTheme.textSecondary),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          size: 20,
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                    ? AppTheme.textDarkSecondary
                                    : AppTheme.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : (isDark
                                      ? AppTheme.textDarkPrimary
                                      : AppTheme.textPrimary),
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );

    // Tooltip on collapsed mode
    if (isNarrow) {
      return Tooltip(
        message: title,
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 400),
        child: child,
      );
    }
    return child;
  }

  Widget _buildLogoutButton(bool isDark, bool isNarrow) {
    final button = Container(
      padding: EdgeInsets.all(isNarrow ? 8 : 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
            width: 1,
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isNarrow ? 0 : 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.errorColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: isNarrow
                  ? Center(
                      child: Icon(
                        Icons.logout,
                        size: 20,
                        color: AppTheme.errorColor,
                      ),
                    )
                  : Row(
                      children: [
                        Icon(
                          Icons.logout,
                          size: 20,
                          color: AppTheme.errorColor,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Déconnexion',
                          style: TextStyle(
                            color: AppTheme.errorColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );

    if (isNarrow) {
      return Tooltip(
        message: 'Déconnexion',
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 400),
        child: button,
      );
    }
    return button;
  }
}
