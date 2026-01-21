import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/ecole.dart';
import '../core/database/database_helper.dart';
import 'student_id_card.dart';

class CarteScolaireGuinee extends StatefulWidget {
  final String? studentId;

  const CarteScolaireGuinee({super.key, this.studentId});

  @override
  State<CarteScolaireGuinee> createState() => _CarteScolaireGuineeState();
}

class _CarteScolaireGuineeState extends State<CarteScolaireGuinee> {
  Student? student;
  Ecole? ecole;
  String? anneeLibelle;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Charger l'école
      final ecoleList = await db.query('ecole', limit: 1);
      if (ecoleList.isNotEmpty) {
        ecole = Ecole.fromMap(ecoleList.first);
      }

      // Charger l'année scolaire active
      final anneeList = await db.query(
        'annee_scolaire',
        where: 'active = ?',
        whereArgs: [1],
        limit: 1,
      );
      if (anneeList.isNotEmpty) {
        anneeLibelle = anneeList.first['libelle'] as String?;
      }

      // Charger l'élève si ID fourni
      if (widget.studentId != null) {
        final studentData = await db.rawQuery(
          '''
          SELECT e.*, c.nom as classe_nom
          FROM eleve e
          LEFT JOIN classe c ON e.classe_id = c.id
          WHERE e.id = ?
        ''',
          [widget.studentId],
        );

        if (studentData.isNotEmpty) {
          student = Student.fromMap(studentData.first);
        }
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (student == null) {
      return const Scaffold(
        body: Center(child: Text('Aucun élève sélectionné')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[300],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          scrollDirection: Axis.horizontal,
          child: StudentIdCard(
            student: student,
            ecole: ecole,
            anneeLibelle: anneeLibelle,
            scale:
                0.8, // Slightly smaller for the view mode maybe? Or 1.0. Let's keep 1.0 logic or allow fitting.
            // But user wants same design.
          ),
        ),
      ),
    );
  }
}
