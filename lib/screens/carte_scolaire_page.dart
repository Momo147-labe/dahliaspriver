import 'package:flutter/material.dart';
import '../core/database/database_helper.dart';
import '../models/student.dart';
import '../widgets/carteele.dart';
import 'carte_editor_screen.dart';
import 'bulk_card_print_page.dart';

class CarteScolairePage extends StatefulWidget {
  const CarteScolairePage({super.key});

  @override
  State<CarteScolairePage> createState() => _CarteScolairePageState();
}

class _CarteScolairePageState extends State<CarteScolairePage> {
  List<Student> students = [];
  bool isLoading = true;
  String? selectedClasseId;
  List<Map<String, dynamic>> classes = [];

  @override
  void initState() {
    super.initState();
    _loadClasses();
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
        builder: (context) => CarteScolaireGuinee(studentId: student.id),
      ),
    );
  }

  void _editStudentCard(Student student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarteEditorScreen(studentId: student.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header Replacement (Minimal)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cartes d\'Identité Scolaire',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.print),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BulkCardPrintPage(),
                        ),
                      );
                    },
                    tooltip: 'Impression en série',
                  ),
                ],
              ),
            ),

            // Sélecteur de classe
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[200],
              child: Row(
                children: [
                  const Text(
                    'Classe: ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButton<String>(
                      value: selectedClasseId,
                      isExpanded: true,
                      items: classes.map((classe) {
                        return DropdownMenuItem<String>(
                          value: classe['id'].toString(),
                          child: Text(classe['nom'] as String),
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
            ),

            // Liste des élèves
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : students.isEmpty
                  ? const Center(child: Text('Aucun élève dans cette classe'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final student = students[index];
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
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () => _editStudentCard(student),
                                  icon: const Icon(Icons.edit, size: 18),
                                  label: const Text('Éditer'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade800,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
