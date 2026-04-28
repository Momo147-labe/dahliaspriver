import 'package:flutter/material.dart';
import '../core/database/database_helper.dart';
import '../models/student.dart';
import '../widgets/carteele.dart';
import '../widgets/student_card_design.dart';
import '../models/ecole.dart';
import '../services/pdf/student_card_pdf_service.dart';
// import 'bulk_card_print_page.dart'; // File missing

class CarteScolairePage extends StatefulWidget {
  final Student? student;
  const CarteScolairePage({super.key, this.student});

  @override
  State<CarteScolairePage> createState() => _CarteScolairePageState();
}

class _CarteScolairePageState extends State<CarteScolairePage> {
  List<Student> students = [];
  bool isLoading = true;
  String? selectedClasseId;
  List<Map<String, dynamic>> classes = [];
  Ecole? ecole;
  String? anneeLibelle;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDesignModel = StudentCardDesign.modelClassic;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadSchoolInfo();
    await _loadClasses();
  }

  Future<void> _loadSchoolInfo() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final ecoleList = await db.query('ecole', limit: 1);
      if (ecoleList.isNotEmpty) {
        ecole = Ecole.fromMap(ecoleList.first);
      }

      final anneeList = await db.query(
        'annee_scolaire',
        where: 'active = ?',
        whereArgs: [1],
        limit: 1,
      );
      if (anneeList.isNotEmpty) {
        anneeLibelle = anneeList.first['libelle'] as String?;
      }
    } catch (e) {
      debugPrint('Error loading school info: $e');
    }
  }

  Future<void> _loadClasses() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query('classe', orderBy: 'nom');
      setState(() {
        classes = result;
        if (classes.isNotEmpty) {
          selectedClasseId = classes.first['id'].toString();
          _loadStudents();
        } else {
          isLoading = false;
        }
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadStudents() async {
    if (selectedClasseId == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.rawQuery(
        '''
        SELECT e.*, c.nom as classe_nom
        FROM eleve e
        LEFT JOIN classe c ON e.classe_id = c.id
        WHERE e.classe_id = ?
        ORDER BY e.nom, e.prenom
      ''',
        [selectedClasseId],
      );

      setState(() {
        students = result.map((e) => Student.fromMap(e)).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showStudentCard(Student student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarteScolaireGuinee(
          studentId: student.id,
          designModel: _selectedDesignModel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cartes d\'Identité Scolaire'),
        actions: [
          if (students.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.print_rounded),
              tooltip: 'Imprimer toute la classe',
              onPressed: () {
                StudentCardPdfService.generateAndPrintBulk(
                  students: students,
                  ecole: ecole,
                  anneeLibelle: anneeLibelle,
                  designModel: _selectedDesignModel,
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Sélecteur de classe et Recherche
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceVariant.withValues(alpha: 0.5),
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.class_outlined, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Classe: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButton<String>(
                          value: selectedClasseId,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: classes.map((classe) {
                            return DropdownMenuItem<String>(
                              value: classe['id'].toString(),
                              child: Text(
                                classe['nom'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedClasseId = value;
                              _loadStudents();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.style_outlined, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Modèle: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _selectedDesignModel,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(
                              value: StudentCardDesign.modelClassic,
                              child: Text('Classique'),
                            ),
                            DropdownMenuItem(
                              value: StudentCardDesign.modelModern,
                              child: Text('Portrait 1'),
                            ),
                            DropdownMenuItem(
                              value: StudentCardDesign.modelPremium,
                              child: Text('Portrait 2'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedDesignModel = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Barre de recherche
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher un élève (nom ou matricule)...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ],
              ),
            ),

            // Liste des élèves
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : () {
                      final filtered = students.where((s) {
                        final query = _searchQuery.toLowerCase();
                        return s.fullName.toLowerCase().contains(query) ||
                            s.matricule.toLowerCase().contains(query);
                      }).toList();

                      if (filtered.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _searchQuery.isEmpty
                                    ? Icons.people_outline
                                    : Icons.search_off,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'Aucun élève dans cette classe'
                                    : 'Aucun résultat pour "${_searchQuery}"',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final student = filtered[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: student.sexeColor,
                                child: Icon(
                                  student.sexeIcon,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                student.fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'Matricule: ${student.matricule} | Classe: ${student.classe}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _showStudentCard(student),
                                    icon: const Icon(Icons.badge, size: 18),
                                    label: const Text('Voir'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }(),
            ),
          ],
        ),
      ),
    );
  }
}
