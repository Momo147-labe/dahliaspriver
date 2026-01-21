import 'dart:io';
import 'package:flutter/material.dart';
import '../core/database/database_helper.dart';
import '../models/student.dart';
import '../models/ecole.dart';

class CarteEditorScreen extends StatefulWidget {
  final String studentId;

  const CarteEditorScreen({super.key, required this.studentId});

  @override
  State<CarteEditorScreen> createState() => _CarteEditorScreenState();
}

class _CarteEditorScreenState extends State<CarteEditorScreen> {
  Student? student;
  Ecole? ecole;
  String? anneeLibelle;
  bool isLoading = true;

  // Paramètres éditables
  Color borderColor = Colors.red.shade900;
  Color headerBgColor = Colors.red.shade800;
  Color titleBgColor = Colors.red;
  double cardWidth = 500;
  double cardHeight = 300;
  double fontSize = 12;
  bool showLogo = true;
  bool showPhoto = true;
  String headerText = "RÉPUBLIQUE DE GUINÉE";
  String subHeaderText = "Travail - Justice - Solidarité";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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

      final studentData = await db.rawQuery('''
        SELECT e.*, c.nom as classe_nom
        FROM eleve e
        LEFT JOIN classe c ON e.classe_id = c.id
        WHERE e.id = ?
      ''', [widget.studentId]);

      if (studentData.isNotEmpty) {
        student = Student.fromMap(studentData.first);
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (student == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erreur')),
        body: const Center(child: Text('Élève non trouvé')),
      );
    }

    // Debug: Afficher les chemins
    print('Photo élève: ${student!.photo}');
    print('Logo école: ${ecole?.logo}');
    if (student!.photo.isNotEmpty) {
      print('Photo existe: ${File(student!.photo).existsSync()}');
    }
    if (ecole?.logo != null && ecole!.logo!.isNotEmpty) {
      print('Logo existe: ${File(ecole!.logo!).existsSync()}');
    }

    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        title: const Text('Éditeur de Carte Scolaire'),
        backgroundColor: Colors.red.shade800,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              // TODO: Implémenter l'impression
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Impression en cours...')),
              );
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Panneau de contrôle
          Container(
            width: 300,
            color: Colors.white,
            child: _buildControlPanel(),
          ),
          // Prévisualisation
          Expanded(
            child: Center(
              child: _buildCardPreview(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Personnalisation',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        // Dimensions
        const Text('Dimensions', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Largeur: '),
            Expanded(
              child: Slider(
                value: cardWidth,
                min: 400,
                max: 600,
                onChanged: (v) => setState(() => cardWidth = v),
              ),
            ),
            Text('${cardWidth.toInt()}'),
          ],
        ),
        Row(
          children: [
            const Text('Hauteur: '),
            Expanded(
              child: Slider(
                value: cardHeight,
                min: 250,
                max: 350,
                onChanged: (v) => setState(() => cardHeight = v),
              ),
            ),
            Text('${cardHeight.toInt()}'),
          ],
        ),

        const Divider(height: 32),

        // Couleurs
        const Text('Couleurs', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildColorPicker('Bordure', borderColor, (c) => setState(() => borderColor = c)),
        _buildColorPicker('Fond pied', headerBgColor, (c) => setState(() => headerBgColor = c)),
        _buildColorPicker('Titre', titleBgColor, (c) => setState(() => titleBgColor = c)),

        const Divider(height: 32),

        // Texte
        const Text('Texte', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(labelText: 'En-tête', border: OutlineInputBorder()),
          controller: TextEditingController(text: headerText),
          onChanged: (v) => setState(() => headerText = v),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(labelText: 'Sous-titre', border: OutlineInputBorder()),
          controller: TextEditingController(text: subHeaderText),
          onChanged: (v) => setState(() => subHeaderText = v),
        ),

        const Divider(height: 32),

        // Options
        const Text('Options', style: TextStyle(fontWeight: FontWeight.bold)),
        SwitchListTile(
          title: const Text('Afficher logo'),
          value: showLogo,
          onChanged: (v) => setState(() => showLogo = v),
        ),
        SwitchListTile(
          title: const Text('Afficher photo'),
          value: showPhoto,
          onChanged: (v) => setState(() => showPhoto = v),
        ),

        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              borderColor = Colors.red.shade900;
              headerBgColor = Colors.red.shade800;
              titleBgColor = Colors.red;
              cardWidth = 500;
              cardHeight = 300;
              showLogo = true;
              showPhoto = true;
            });
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Réinitialiser'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildColorPicker(String label, Color color, Function(Color) onChanged) {
    final colors = [
      Colors.red.shade900,
      Colors.red.shade800,
      Colors.red,
      Colors.green.shade900,
      Colors.green,
      Colors.blue.shade900,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.black,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: colors.map((c) {
              return GestureDetector(
                onTap: () => onChanged(c),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: c,
                    border: Border.all(
                      color: color == c ? Colors.black : Colors.grey,
                      width: color == c ? 3 : 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCardPreview() {
    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 10)],
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Stack(
        children: [
          // Fond pied de page
          Positioned(
            bottom: 0,
            child: Container(
              width: cardWidth,
              height: 60,
              decoration: BoxDecoration(
                color: headerBgColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(13),
                  bottomRight: Radius.circular(13),
                ),
              ),
            ),
          ),

          // Logo école
          if (showLogo && ecole?.logo != null && ecole!.logo!.isNotEmpty)
            Positioned(
              top: 10,
              left: 15,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[300],
                ),
                child: ClipOval(
                  child: Image.file(
                    File(ecole!.logo!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.school,
                      color: Colors.grey[600],
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),

          // En-tête
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  headerText,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  subHeaderText,
                  style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 10),
                ),
                const Text(
                  "Ministère de l'Enseignement Pré-Universitaire",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                ),
                const Text(
                  "IRE : CONAKRY / DPE : DIXINN",
                  style: TextStyle(fontSize: 9),
                ),
              ],
            ),
          ),

          // Titre
          Positioned(
            top: 75,
            left: 120,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: titleBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Text(
                "CARTE D'IDENTITÉ SCOLAIRE",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Année scolaire
          Positioned(
            top: 105,
            left: 180,
            child: Text(
              "ANNÉE SCOLAIRE ${anneeLibelle ?? '2025-2026'}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                backgroundColor: Color(0xFFFFF9C4),
              ),
            ),
          ),

          // Photo élève
          if (showPhoto)
            Positioned(
              top: 80,
              left: 15,
              child: Container(
                width: 90,
                height: 110,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 1),
                  color: Colors.grey[200],
                ),
                child: student!.photo.isNotEmpty
                    ? Image.file(
                        File(student!.photo),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.grey[600],
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.grey[600],
                      ),
              ),
            ),

          // Informations élève
          Positioned(
            top: 125,
            left: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow("Matricule:", student!.matricule),
                _infoRow("Nom & Prénom:", student!.fullName),
                _infoRow("Date de Naissance:", student!.dateNaissance),
                _infoRow("Lieu de Naissance:", student!.lieuNaissance),
                _infoRow("Sexe:", student!.sexe),
                _infoRow("Classe:", student!.classe),
              ],
            ),
          ),

          // Nom école
          Positioned(
            bottom: 8,
            right: 15,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  ecole?.nom.toUpperCase() ?? "ÉCOLE",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                if (ecole?.adresse != null)
                  Text(
                    ecole!.adresse!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Row(
        children: [
          Text(
            "$label ",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize),
          ),
          Text(value, style: TextStyle(fontSize: fontSize)),
        ],
      ),
    );
  }
}
