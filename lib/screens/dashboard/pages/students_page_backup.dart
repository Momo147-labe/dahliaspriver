import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/student/student_table.dart';
import '../../../models/student.dart';
import '../../../widgets/student/add_student_modal.dart';

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
    setState(() => _isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;

      final classes = await db.query('classe');
      _classes = [
        {'id': 'Toutes', 'nom': 'Toutes', 'niveau': ''},
        ...classes,
      ];

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

      _students = students;
      _filteredStudents = students;

      _filterStudents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterStudents() {
    _filteredStudents = _students.where((student) {
      final nom = student['nom']?.toString().toLowerCase() ?? '';
      final prenom = student['prenom']?.toString().toLowerCase() ?? '';
      final matricule = student['matricule']?.toString().toLowerCase() ?? '';
      final classeNom = student['classe_nom']?.toString() ?? '';
      final search = _searchController.text.toLowerCase();

      final matchesSearch =
          nom.contains(search) ||
          prenom.contains(search) ||
          matricule.contains(search);

      final matchesClass =
          _selectedClass == 'Toutes' || classeNom == _selectedClass;

      return matchesSearch && matchesClass;
    }).toList();

    _filteredStudents.sort((a, b) {
      switch (_sortBy) {
        case 'prenom':
          return (a['prenom'] ?? '').compareTo(b['prenom'] ?? '');
        case 'matricule':
          return (a['matricule'] ?? '').compareTo(b['matricule'] ?? '');
        case 'classe':
          return (a['classe_nom'] ?? '').compareTo(b['classe_nom'] ?? '');
        case 'nom':
        default:
          return (a['nom'] ?? '').compareTo(b['nom'] ?? '');
      }
    });

    setState(() {});
  }

  void _openAddModal() {
    showDialog(
      context: context,
      builder: (_) => AddStudentModal(
        onSuccess: _loadData,
        onClose: () => Navigator.pop(context),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Gestion des Élèves'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => _filterStudents(),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Rechercher un élève',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _classes.any(
                                (c) => c['nom'] == _selectedClass)
                            ? _selectedClass
                            : 'Toutes',
                        items: _classes
                            .map(
                              (c) => DropdownMenuItem<String>(
                                value: c['nom'].toString(),
                                child: Text(c['nom'].toString()),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          _selectedClass = v!;
                          _filterStudents();
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StudentTable(
                    students: _filteredStudents.map((s) {
                      return Student(
                        id: s['id']?.toString() ?? '0',
                        matricule: s['matricule'] ?? '',
                        nom: s['nom'] ?? '',
                        prenom: s['prenom'] ?? '',
                        dateNaissance: s['date_naissance'] ?? '',
                        lieuNaissance: s['lieu_naissance'] ?? '',
                        sexe: s['sexe'] ?? 'M',
                        classe: s['classe_nom'] ?? '',
                        annee: s['annee'] ?? '',
                        statut: s['statut'] ?? 'inscrit',
                        photo: s['photo'] ?? '',
                      );
                    }).toList(),
                    onEdit: (_) {},
                    onDelete: (_) {},
                    onReinscrire: (_) {},
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddModal,
        icon: const Icon(Icons.person_add),
        label: const Text('Ajouter un élève'),
      ),
    );
  }
}
