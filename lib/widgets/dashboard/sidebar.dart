import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../common/typewriter_text.dart';
import 'school_profile_card.dart';

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final bool isCollapsed;
  final VoidCallback onToggle;
  final Map<String, dynamic>? schoolData;
  final bool isLoading;
  final List<String> titles;
  final List<IconData> icons;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.isCollapsed,
    required this.onToggle,
    required this.schoolData,
    required this.isLoading,
    required this.titles,
    required this.icons,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sidebarWidth = isCollapsed ? 80.0 : 250.0;

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
              if (!isCollapsed)
                SchoolProfileCard(
                  school: schoolData,
                  isDark: isDark,
                  isLoading: isLoading,
                )
              else
                const SizedBox(height: 56),
              Expanded(child: _buildMenu(isDark)),
            ],
          ),

          // Bouton de réduction en position absolue
          Positioned(
            top: 12,
            right: isCollapsed ? 0 : 12,
            left: isCollapsed ? 0 : null,
            child: Align(
              alignment: isCollapsed ? Alignment.center : Alignment.centerRight,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white10
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    child: Icon(
                      isCollapsed ? Icons.chevron_right : Icons.chevron_left,
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

  Widget _buildMenu(bool isDark) {
    return ScrollConfiguration(
      behavior: const ScrollBehavior().copyWith(scrollbars: false),
      child: ListView.builder(
        padding: EdgeInsets.symmetric(
          horizontal: isCollapsed ? 8 : 12,
          vertical: 8,
        ),
        itemCount: titles.length,
        itemBuilder: (_, i) {
          final selected = selectedIndex == i;

          // Mode Réduit
          if (isCollapsed) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Tooltip(
                message: titles[i],
                preferBelow: false,
                child: InkWell(
                  onTap: () => onItemSelected(i),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: selected
                          ? AppTheme.primaryColor.withValues(alpha: 0.15)
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
                    ? AppTheme.primaryColor.withValues(alpha: 0.15)
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
                    onTap: () => onItemSelected(i),
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
                            child: selected
                                ? TypewriterText(
                                    text: titles[i],
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryColor,
                                    ),
                                  )
                                : Text(
                                    titles[i],
                                    overflow: TextOverflow.clip,
                                    softWrap: false,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
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
}
