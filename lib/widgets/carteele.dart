import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/ecole.dart';
import '../core/database/database_helper.dart';
import '../services/pdf/student_card_pdf_service.dart';
import 'student_card_design.dart';

class CarteScolaireGuinee extends StatefulWidget {
  final String? studentId;
  final String designModel;

  const CarteScolaireGuinee({
    super.key,
    this.studentId,
    this.designModel = StudentCardDesign.modelClassic,
  });

  @override
  State<CarteScolaireGuinee> createState() => _CarteScolaireGuineeState();
}

class _CarteScolaireGuineeState extends State<CarteScolaireGuinee> {
  Student? student;
  Ecole? ecole;
  String? anneeLibelle;
  bool isLoading = true;
  late String _selectedDesignModel;

  @override
  void initState() {
    super.initState();
    _selectedDesignModel = widget.designModel;
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
      appBar: AppBar(
        title: const Text('Carte d\'Identité Scolaire'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              if (student != null) {
                StudentCardPdfService.generateAndPrintSingle(
                  student: student!,
                  ecole: ecole,
                  anneeLibelle: anneeLibelle,
                  designModel: _selectedDesignModel,
                );
              }
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Modèle de carte',
            icon: const Icon(Icons.style),
            onSelected: (value) {
              setState(() {
                _selectedDesignModel = value;
              });
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: StudentCardDesign.modelClassic,
                child: Text('Classique'),
              ),
              PopupMenuItem(
                value: StudentCardDesign.modelModern,
                child: Text('Portrait 1'),
              ),
              PopupMenuItem(
                value: StudentCardDesign.modelPremium,
                child: Text('Portrait 2'),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: StudentCardDesign(
            student: student,
            ecole: ecole,
            anneeLibelle: anneeLibelle,
            scale: 1.5,
            designModel: _selectedDesignModel,
          ),
        ),
      ),
    );
  }
}
