import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class StudentSearchBar extends StatelessWidget {
  final String searchTerm;
  final Function(String) onSearchChanged;
  final bool showFilters;
  final VoidCallback onFiltersToggle;
  final String selectedClass;
  final String selectedStatus;
  final String selectedGender;
  final Function(String) onClassChanged;
  final Function(String) onStatusChanged;
  final Function(String) onGenderChanged;
  final List<String> availableClasses;

  const StudentSearchBar({
    super.key,
    required this.searchTerm,
    required this.onSearchChanged,
    required this.showFilters,
    required this.onFiltersToggle,
    required this.selectedClass,
    required this.selectedStatus,
    required this.selectedGender,
    required this.onClassChanged,
    required this.onStatusChanged,
    required this.onGenderChanged,
    required this.availableClasses,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un élève...',
                    prefixIcon: Icon(Icons.search, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSecondary),
                    filled: true,
                    fillColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                    ),
                    hintStyle: TextStyle(
                      color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSecondary,
                    ),
                  ),
                  style: TextStyle(
                    color: isDark ? AppTheme.textDarkPrimary : AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: onFiltersToggle,
                icon: Icon(showFilters ? Icons.filter_list_off : Icons.filter_list),
                label: Text('Filtres'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: showFilters ? AppTheme.primaryColor : (isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight),
                  foregroundColor: showFilters ? Colors.white : (isDark ? AppTheme.textDarkPrimary : AppTheme.textPrimary),
                  side: BorderSide(
                    color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                  ),
                ),
              ),
            ],
          ),
          if (showFilters) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedClass.isEmpty ? null : selectedClass,
                    decoration: InputDecoration(
                      labelText: 'Classe',
                      filled: true,
                      fillColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                      ),
                      labelStyle: TextStyle(
                        color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSecondary,
                      ),
                    ),
                    items: availableClasses.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: TextStyle(
                            color: isDark ? AppTheme.textDarkPrimary : AppTheme.textPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) onClassChanged(newValue);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedStatus.isEmpty ? null : selectedStatus,
                    decoration: InputDecoration(
                      labelText: 'Statut',
                      filled: true,
                      fillColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                      ),
                      labelStyle: TextStyle(
                        color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSecondary,
                      ),
                    ),
                    items: ['Inscrit', 'Réinscrit', 'Suspendu'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: TextStyle(
                            color: isDark ? AppTheme.textDarkPrimary : AppTheme.textPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) onStatusChanged(newValue);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedGender.isEmpty ? null : selectedGender,
                    decoration: InputDecoration(
                      labelText: 'Sexe',
                      filled: true,
                      fillColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                      ),
                      labelStyle: TextStyle(
                        color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSecondary,
                      ),
                    ),
                    items: ['Masculin', 'Féminin'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: TextStyle(
                            color: isDark ? AppTheme.textDarkPrimary : AppTheme.textPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) onGenderChanged(newValue);
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
