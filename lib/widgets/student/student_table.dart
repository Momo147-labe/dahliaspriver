import 'package:flutter/material.dart';
import '../../../models/student.dart';

class StudentTable extends StatelessWidget {
  final List<Student> students;
  final Function(Student) onEdit;
  final Function(Student) onDelete;
  final Function(Student) onReinscrire;

  const StudentTable({
    super.key,
    required this.students,
    required this.onEdit,
    required this.onDelete,
    required this.onReinscrire,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1f2937) : const Color(0xFFffffff),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFe5e7eb),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // En-tête du tableau - bg-gray-50 dark:bg-gray-700
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF374151) : const Color(0xFFf9fafb),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF4b5563) : const Color(0xFFe5e7eb),
                  width: 1,
                ),
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1200),
              child: Row(
                children: [
                  // Photo
                  SizedBox(
                    width: 80,
                    child: Text(
                      'Photo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFd1d5db) : const Color(0xFF6b7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  // Matricule
                  SizedBox(
                    width: 150,
                    child: Text(
                      'Matricule',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFd1d5db) : const Color(0xFF6b7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  // Nom & Prénom
                  SizedBox(
                    width: 200,
                    child: Text(
                      'Nom & Prénom',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFd1d5db) : const Color(0xFF6b7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  // Date
                  SizedBox(
                    width: 120,
                    child: Text(
                      'Date',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFd1d5db) : const Color(0xFF6b7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  // Lieu
                  SizedBox(
                    width: 120,
                    child: Text(
                      'Lieu',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFd1d5db) : const Color(0xFF6b7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  // Sexe
                  SizedBox(
                    width: 60,
                    child: Text(
                      'Sexe',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFd1d5db) : const Color(0xFF6b7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  // Année
                  SizedBox(
                    width: 120,
                    child: Text(
                      'Année',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFd1d5db) : const Color(0xFF6b7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  // Classe
                  SizedBox(
                    width: 100,
                    child: Text(
                      'Classe',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFd1d5db) : const Color(0xFF6b7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  // Statut
                  SizedBox(
                    width: 100,
                    child: Text(
                      'Statut',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFd1d5db) : const Color(0xFF6b7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  // Actions
                  SizedBox(
                    width: 120,
                    child: Text(
                      'Actions',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFd1d5db) : const Color(0xFF6b7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Corps du tableau avec scroll
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 1200),
                  child: Column(
                    children: students.map((student) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark 
                            ? (students.indexOf(student) % 2 == 0) 
                              ? const Color(0xFF1f2937) 
                              : const Color(0xFF111827) 
                            : (students.indexOf(student) % 2 == 0) 
                              ? const Color(0xFFffffff) 
                              : const Color(0xFFf9fafb),
                          border: Border(
                            bottom: BorderSide(
                              color: isDark ? const Color(0xFF374151) : const Color(0xFFe5e7eb),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Photo
                            SizedBox(
                              width: 80,
                              child: Center(
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundImage: student.photo.isNotEmpty
                                      ? NetworkImage(student.photo)
                                      : null,
                                  child: student.photo.isEmpty
                                      ? Icon(
                                          Icons.person,
                                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                          size: 20,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          // Matricule
                          SizedBox(
                            width: 150,
                            child: Text(
                              student.matricule,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? const Color(0xFFf9fafb) : const Color(0xFF111827),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          // Nom & Prénom
                          SizedBox(
                            width: 200,
                            child: Text(
                              '${student.nom} ${student.prenom}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? const Color(0xFFf9fafb) : const Color(0xFF111827),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          // Date
                          SizedBox(
                            width: 120,
                            child: Text(
                              student.dateNaissance,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? const Color(0xFFf9fafb) : const Color(0xFF111827),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          // Lieu
                          SizedBox(
                            width: 120,
                            child: Text(
                              student.lieuNaissance,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? const Color(0xFFf9fafb) : const Color(0xFF111827),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          // Sexe
                          SizedBox(
                            width: 60,
                            child: Text(
                              student.sexe,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? const Color(0xFFf9fafb) : const Color(0xFF111827),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          // Année
                          SizedBox(
                            width: 120,
                            child: Text(
                              student.annee.isNotEmpty ? student.annee : 'Non défini',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? const Color(0xFFf9fafb) : const Color(0xFF111827),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          // Classe
                          SizedBox(
                            width: 100,
                            child: Text(
                              student.classe,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? const Color(0xFFf9fafb) : const Color(0xFF111827),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          // Statut
                          SizedBox(
                            width: 100,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(student.statut).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                student.statut,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: _getStatusColor(student.statut),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          // Actions
                          SizedBox(
                            width: 120,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                // Bouton Modifier
                                IconButton(
                                  onPressed: () => onEdit(student),
                                  icon: Icon(
                                    Icons.edit,
                                    color: const Color(0xFF3b82f6),
                                    size: 18,
                                  ),
                                  tooltip: 'Modifier',
                                  style: IconButton.styleFrom(
                                    backgroundColor: const Color(0xFF3b82f6).withOpacity(0.1),
                                    padding: const EdgeInsets.all(6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    minimumSize: const Size(32, 32),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Bouton Supprimer
                                IconButton(
                                  onPressed: () => onDelete(student),
                                  icon: Icon(
                                    Icons.delete,
                                    color: const Color(0xFFef4444),
                                    size: 18,
                                  ),
                                  tooltip: 'Supprimer',
                                  style: IconButton.styleFrom(
                                    backgroundColor: const Color(0xFFef4444).withOpacity(0.1),
                                    padding: const EdgeInsets.all(6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    minimumSize: const Size(32, 32),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Inscrit':
        return const Color(0xFF10b981);
      case 'Réinscrit':
        return const Color(0xFF3b82f6);
      case 'Suspendu':
        return const Color(0xFFf59e0b);
      default:
        return const Color(0xFF6b7280);
    }
  }
}
