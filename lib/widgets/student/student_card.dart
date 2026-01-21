import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/student.dart';

class StudentCard extends StatelessWidget {
  final Student student;
  final Function(Student) onEdit;
  final Function(Student) onDelete;
  final Function(Student) onReinscrire;

  const StudentCard({
    super.key,
    required this.student,
    required this.onEdit,
    required this.onDelete,
    required this.onReinscrire,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 16),
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
        children: [
          // Photo et informations principales
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: student.photo.isNotEmpty
                    ? NetworkImage(student.photo)
                    : null,
                backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                child: student.photo.isEmpty
                    ? Icon(
                        Icons.person, 
                        color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSecondary, 
                        size: 40
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${student.nom} ${student.prenom}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.textDarkPrimary : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Matricule: ${student.matricule}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Classe: ${student.classe}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Statut et actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(student.statut).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  student.statut,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _getStatusColor(student.statut),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSecondary,
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Modifier',
                          style: TextStyle(
                            color: isDark ? AppTheme.textDarkPrimary : AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'reinscrire',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, color: AppTheme.infoColor),
                        const SizedBox(width: 8),
                        Text(
                          'Réinscrire',
                          style: TextStyle(
                            color: isDark ? AppTheme.textDarkPrimary : AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: AppTheme.errorColor),
                        const SizedBox(width: 8),
                        Text(
                          'Supprimer',
                          style: TextStyle(
                            color: isDark ? AppTheme.textDarkPrimary : AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit(student);
                      break;
                    case 'reinscrire':
                      onReinscrire(student);
                      break;
                    case 'delete':
                      onDelete(student);
                      break;
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Inscrit':
        return AppTheme.successColor;
      case 'Réinscrit':
        return AppTheme.infoColor;
      case 'Suspendu':
        return AppTheme.warningColor;
      default:
        return AppTheme.textSecondary;
    }
  }
}
