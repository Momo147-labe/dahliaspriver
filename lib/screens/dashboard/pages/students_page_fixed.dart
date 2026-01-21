import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/student/student_table.dart';
import '../../../models/student.dart';
import '../../../widgets/student/add_student_modal_v2.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key});

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedClass = 'Toutes';
  String _sortBy = 'nom';
  bool _isLoading = true;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _filteredStudents = [];

  final List<String> _sortOptions = ['nom', 'prenom', 'matricule', 'classe'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Charger les classes
      final classes = await db.query('classe');
      setState(() {
        _classes = [
          {'id': 'Toutes', 'nom': 'Toutes', 'niveau': ''},
          ...classes,
        ];
      });

      // Charger les élèves avec les informations de classe et d'année
      final students = await db.rawQuery('''
        SELECT 
          e.*,
          c.nom as classe_nom,
          c.niveau as classe_niveau,
          a.libelle as annee
        FROM eleve e
        LEFT JOIN classe c ON e.classe_id = c.id
        LEFT JOIN annee_scolaire a ON e.annee_scolaire_id = a.id
        ORDER BY e.nom, e.prenom
      ''');

      setState(() {
        _students = students;
        _filteredStudents = students;
        _isLoading = false;
      });

      _filterStudents();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement: $e')),
        );
      }
    }
  }

  void _filterStudents() {
    setState(() {
      _filteredStudents = _students.where((student) {
        final matchesSearch =
            student['nom'].toString().toLowerCase().contains(
              _searchController.text.toLowerCase(),
            ) ||
            student['prenom'].toString().toLowerCase().contains(
              _searchController.text.toLowerCase(),
            ) ||
            student['matricule'].toString().toLowerCase().contains(
              _searchController.text.toLowerCase(),
            );

        final matchesClass =
            _selectedClass == 'Toutes' ||
            student['classe_nom'].toString() == _selectedClass;

        return matchesSearch && matchesClass;
      }).toList();

      // Trier
      _filteredStudents.sort((a, b) {
        switch (_sortBy) {
          case 'nom':
            return a['nom'].toString().compareTo(b['nom'].toString());
          case 'prenom':
            return a['prenom'].toString().compareTo(b['prenom'].toString());
          case 'matricule':
            return a['matricule'].toString().compareTo(
              b['matricule'].toString(),
            );
          case 'classe':
            return a['classe_nom'].toString().compareTo(
              b['classe_nom'].toString(),
            );
          default:
            return 0;
        }
      });
    });
  }

  void _openAddModal() {
    showDialog(
      context: context,
      builder: (context) => AddStudentModal(
        onStudentAdded: (studentData) {
          _loadData(); // Recharger la liste des élèves
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
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
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.people, color: AppTheme.primaryColor),
                      const SizedBox(width: 12),
                      Text(
                        'Gestion des Élèves',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_filteredStudents.length} élève${_filteredStudents.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search and filters
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Rechercher un élève...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.grey[800]
                                : Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onChanged: (value) => _filterStudents(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedClass,
                            items: _classes
                                .map(
                                  (classe) => DropdownMenuItem(
                                    value: classe['nom'].toString(),
                                    child: Text(classe['nom'].toString()),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedClass = value!;
                              });
                              _filterStudents();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _sortBy,
                            items: _sortOptions
                                .map(
                                  (option) => DropdownMenuItem(
                                    value: option,
                                    child: Text(option.toUpperCase()),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _sortBy = value!;
                              });
                              _filterStudents();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Students list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredStudents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun élève trouvé',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Essayez de modifier vos filtres de recherche',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : StudentTable(
                      students: _filteredStudents
                          .map((student) => Student.fromMap(student))
                          .toList(),
                      onEdit: (student) {
                        // TODO: Implémenter la modification
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Modification à implémenter'),
                          ),
                        );
                      },
                      onDelete: (student) async {
                        // Confirmation de suppression
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Confirmer la suppression'),
                            content: Text(
                              'Voulez-vous vraiment supprimer ${student.fullName}?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Annuler'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text(
                                  'Supprimer',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          try {
                            final db = await DatabaseHelper.instance.database;
                            await db.delete(
                              'eleve',
                              where: 'id = ?',
                              whereArgs: [student.id],
                            );

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Élève supprimé avec succès'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                            _loadData();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Erreur lors de la suppression: $e',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                      onReinscrire: (student) {
                        // TODO: Implémenter la réinscription
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Réinscription à implémenter'),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddModal,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Ajouter un élève'),
      ),
    );
  }
}
