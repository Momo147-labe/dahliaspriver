import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../core/database/database_helper.dart';
import '../models/student.dart';
import '../models/ecole.dart';

class BulkCardPrintPage extends StatefulWidget {
  const BulkCardPrintPage({super.key});

  @override
  State<BulkCardPrintPage> createState() => _BulkCardPrintPageState();
}

class _BulkCardPrintPageState extends State<BulkCardPrintPage> {
  List<Student> students = [];
  List<Map<String, dynamic>> classes = [];
  Ecole? ecole;
  String? anneeLibelle;
  String? selectedClasseId;
  bool isLoading = true;
  final GlobalKey _printKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = await DatabaseHelper.instance.database;

    final ecoleList = await db.query('ecole', limit: 1);
    if (ecoleList.isNotEmpty) ecole = Ecole.fromMap(ecoleList.first);

    final anneeList = await db.query(
      'annee_scolaire',
      where: 'active = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (anneeList.isNotEmpty)
      anneeLibelle = anneeList.first['libelle'] as String?;

    final classesList = await db.query('classe', orderBy: 'nom');
    setState(() {
      classes = classesList;
      if (classes.isNotEmpty) {
        selectedClasseId = classes.first['id'].toString();
        _loadStudents();
      } else {
        isLoading = false;
      }
    });
  }

  Future<void> _loadStudents() async {
    if (selectedClasseId == null) return;
    setState(() => isLoading = true);

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
  }

  Future<void> _exportToPDF() async {
    try {
      final pdf = pw.Document();

      for (int i = 0; i < students.length; i += 8) {
        final pageStudents = students.skip(i).take(8).toList();
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            build: (context) => pw.Wrap(
              spacing: 20,
              runSpacing: 20,
              children: pageStudents.map((s) => _buildPdfCard(s)).toList(),
            ),
          ),
        );
      }

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  pw.Widget _buildPdfCard(Student student) {
    return pw.Container(
      width: 240,
      height: 153,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Stack(
        children: [
          pw.Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: pw.Container(
              height: 35,
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFce1126),
                borderRadius: pw.BorderRadius.only(
                  bottomLeft: pw.Radius.circular(4),
                  bottomRight: pw.Radius.circular(4),
                ),
              ),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    ecole?.nom.toUpperCase() ?? 'GUINÉE ÉCOLE',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Travail - Justice - Solidarité',
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFce1126),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(15),
                    ),
                  ),
                  child: pw.Text(
                    'CARTE D\'IDENTITÉ SCOLAIRE',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: pw.BoxDecoration(
                      color: const PdfColor.fromInt(0xFFfcd116),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(3),
                      ),
                    ),
                    child: pw.Text(
                      'ANNÉE ${anneeLibelle ?? '2023-2024'}',
                      style: pw.TextStyle(
                        fontSize: 6,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 60,
                      height: 70,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: PdfColors.grey300,
                          width: 1.5,
                        ),
                        color: PdfColors.grey100,
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _pdfInfoLine('Matricule:', student.matricule),
                          _pdfInfoLine(
                            'Nom & Prénom:',
                            student.fullName.toUpperCase(),
                          ),
                          _pdfInfoLine(
                            'Né(e) le:',
                            '${student.dateNaissance} à ${student.lieuNaissance}',
                          ),
                          _pdfInfoLine('Sexe:', student.sexe),
                          _pdfInfoLine('Classe:', student.classe),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfInfoLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1.5),
      child: pw.RichText(
        text: pw.TextSpan(
          style: const pw.TextStyle(fontSize: 6, color: PdfColors.black),
          children: [
            pw.TextSpan(
              text: '$label ',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey600,
              ),
            ),
            pw.TextSpan(
              text: value,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],

      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Container(
              color: const Color(0xFF0d6073),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Impression en Série',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Prêt pour l\'impression',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.picture_as_pdf,
                          color: Colors.white,
                        ),
                        onPressed: _exportToPDF,
                        tooltip: 'Exporter en PDF',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  _buildSidebar(),
                  Expanded(child: _buildMainContent()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 300,
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CONFIGURATION',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 20),
          const Text('Classe', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedClasseId,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: classes
                .map(
                  (c) => DropdownMenuItem(
                    value: c['id'].toString(),
                    child: Text(c['nom'] as String),
                  ),
                )
                .toList(),
            onChanged: (v) {
              setState(() {
                selectedClasseId = v;
                _loadStudents();
              });
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Année Scolaire',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            anneeLibelle ?? '2023-2024',
            style: const TextStyle(fontSize: 14),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Élèves sélectionnés',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '${students.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0d6073),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: students.length / 40,
                  backgroundColor: Colors.grey[300],
                  color: const Color(0xFF0d6073),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: RepaintBoundary(
          key: _printKey,
          child: Container(
            width: 794,
            padding: const EdgeInsets.all(38),
            color: Colors.white,
            child: Wrap(
              spacing: 38,
              runSpacing: 45,
              children: students.take(8).map((s) => _buildCard(s)).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Student student) {
    return Container(
      width: 320,
      height: 204,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 45,
              decoration: const BoxDecoration(
                color: Color(0xFFce1126),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    ecole?.nom.toUpperCase() ?? 'GUINÉE ÉCOLE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Text(
                    'Travail - Justice - Solidarité',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (ecole?.logo != null && ecole!.logo!.isNotEmpty)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                child: ClipOval(
                  child: Image.file(
                    File(ecole!.logo!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.school, size: 16),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFce1126),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'CARTE D\'IDENTITÉ SCOLAIRE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFfcd116),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Text(
                      'ANNÉE SCOLAIRE ${anneeLibelle ?? '2023-2024'}',
                      style: const TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 75,
                      height: 90,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!, width: 2),
                        color: Colors.grey[100],
                      ),
                      child: student.photo.isNotEmpty
                          ? Image.file(
                              File(student.photo),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.person, size: 40),
                            )
                          : const Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.grey,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoLine('Matricule:', student.matricule),
                          _infoLine(
                            'Nom & Prénom:',
                            student.fullName.toUpperCase(),
                          ),
                          _infoLine(
                            'Né(e) le:',
                            '${student.dateNaissance} à ${student.lieuNaissance}',
                          ),
                          _infoLine('Sexe:', student.sexe),
                          _infoLine('Classe:', student.classe),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 7.5, color: Colors.black),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
