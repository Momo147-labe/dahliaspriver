import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/database/database_helper.dart';
import '../models/student.dart';
import '../models/ecole.dart';
import '../providers/theme_provider.dart';
import '../widgets/student_id_card.dart';

class IndividualCardPage extends StatefulWidget {
  const IndividualCardPage({super.key});

  @override
  State<IndividualCardPage> createState() => _IndividualCardPageState();
}

class _IndividualCardPageState extends State<IndividualCardPage> {
  // Data
  List<Map<String, dynamic>> annees = [];
  List<Map<String, dynamic>> classes = [];
  List<Student> studentsInClass = [];
  Ecole? ecole;

  // Selection State
  String? selectedAnnee;
  String? selectedClasseId;
  Student? selectedStudent;

  // Form State (Edits)
  late TextEditingController _nameController;
  late TextEditingController _matriculeController;
  late TextEditingController _classeController;
  late TextEditingController _sexeController;
  late TextEditingController _dobController;
  late TextEditingController _lieuController;
  late TextEditingController _emergencyController; // No DB field, just UI

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _matriculeController = TextEditingController();
    _classeController = TextEditingController();
    _sexeController = TextEditingController();
    _dobController = TextEditingController();
    _lieuController = TextEditingController();
    _emergencyController = TextEditingController(
      text: "622 15 33 29",
    ); // Default from HTML
    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _matriculeController.dispose();
    _classeController.dispose();
    _sexeController.dispose();
    _dobController.dispose();
    _lieuController.dispose();
    _emergencyController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final db = await DatabaseHelper.instance.database;

    // Charger Ecole
    final ecoleList = await db.query('ecole', limit: 1);
    if (ecoleList.isNotEmpty) {
      ecole = Ecole.fromMap(ecoleList.first);
    }

    // Charger Années
    final anneesData = await db.query('annee_scolaire', orderBy: 'id DESC');
    setState(() {
      annees = anneesData;
      // Select active or latest
      final active = anneesData.where((a) => a['active'] == 1).firstOrNull;
      selectedAnnee = (active ?? anneesData.firstOrNull)?['libelle']
          ?.toString();
    });

    // Charger Classes
    final classesData = await db.query('classe');
    setState(() {
      classes = classesData;
      if (classes.isNotEmpty) {
        // Don't auto select class, let user choose
        // But for UX maybe select first?
        // selectedClasseId = classes.first['id'].toString();
        // _loadStudentsForClass(selectedClasseId!);
      }
      isLoading = false;
    });
  }

  Future<void> _loadStudentsForClass(String classeId) async {
    final db = await DatabaseHelper.instance.database;
    final results = await db.rawQuery(
      '''
      SELECT e.*, c.nom as classe_nom
      FROM eleve e
      JOIN classe c ON e.classe_id = c.id
      WHERE e.classe_id = ?
    ''',
      [classeId],
    );

    setState(() {
      studentsInClass = results.map((e) => Student.fromMap(e)).toList();
      selectedStudent = null; // Reset selection
    });
  }

  void _onStudentSelected(Student? student) {
    setState(() {
      selectedStudent = student;
      if (student != null) {
        _nameController.text = "${student.nom} ${student.prenom}";
        _matriculeController.text = student.matricule;
        _classeController.text =
            student.classe; // Or use class name from selection
        _sexeController.text = student.sexe;
        _dobController.text = student.dateNaissance;
        _lieuController.text = student.lieuNaissance;
        // Keep existing emergency or default if empty
        if (_emergencyController.text.isEmpty)
          _emergencyController.text = "622 15 33 29";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0f172a) : const Color(0xFFf8fafc);
    final cardBg = isDark ? const Color(0xFF1e293b) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0f172a);
    final subText = isDark ? Colors.grey[400] : Colors.grey[500];

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Custom Header / Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.badge,
                        color: Color(0xFFe11d48),
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                      Text.rich(
                        TextSpan(
                          text: "Guinée ",
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                          children: const [
                            TextSpan(
                              text: "École",
                              style: TextStyle(color: Color(0xFFe11d48)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                        onPressed: () {
                          Provider.of<ThemeProvider>(
                            context,
                            listen: false,
                          ).toggleTheme();
                        },
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _exportPdf,
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text("Exporter en PDF"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1e293b),
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _printCard,
                        icon: const Icon(Icons.print, size: 18),
                        label: const Text("Imprimer"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFe11d48),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Filters
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        label: "Année Scolaire",
                        value: selectedAnnee,
                        items: annees
                            .map((e) => e['libelle'].toString())
                            .toList(),
                        onChanged: (val) {
                          setState(() => selectedAnnee = val);
                        },
                        textColor: textColor,
                        subText: subText,
                        bg: isDark
                            ? const Color(0xFF1e293b)
                            : const Color(0xFFf8fafc),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDropdown(
                        label: "Classe",
                        value: selectedClasseId,
                        items: classes.map((e) => e['id'].toString()).toList(),
                        itemLabels: classes
                            .map((e) => e['nom'].toString())
                            .toList(),
                        isMap: true,
                        onChanged: (val) {
                          setState(() => selectedClasseId = val);
                          if (val != null) _loadStudentsForClass(val);
                        },
                        textColor: textColor,
                        subText: subText,
                        bg: isDark
                            ? const Color(0xFF1e293b)
                            : const Color(0xFFf8fafc),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStudentSearch(
                        textColor,
                        subText,
                        isDark
                            ? const Color(0xFF1e293b)
                            : const Color(0xFFf8fafc),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Main Content
              LayoutBuilder(
                builder: (context, constraints) {
                  // Responsive Switch
                  if (constraints.maxWidth > 900) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: _buildEditorForm(cardBg, textColor, subText),
                        ),
                        const SizedBox(width: 32),
                        Expanded(flex: 8, child: _buildCardPreview()),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _buildEditorForm(cardBg, textColor, subText),
                        const SizedBox(height: 32),
                        _buildCardPreview(),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    List<String>? itemLabels,
    required Function(String?) onChanged,
    required Color textColor,
    required Color? subText,
    required Color bg,
    bool isMap = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: subText,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: bg,
              items: items.asMap().entries.map((entry) {
                int idx = entry.key;
                String val = entry.value;
                String label = isMap && itemLabels != null
                    ? itemLabels[idx]
                    : val;
                return DropdownMenuItem(
                  value: val,
                  child: Text(label, style: TextStyle(color: textColor)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentSearch(Color textColor, Color? subText, Color bg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "RECHERCHER UN ÉLÈVE",
          style: TextStyle(
            color: subText,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: Autocomplete<Student>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text == '') {
                return const Iterable<Student>.empty();
              }
              return studentsInClass.where((Student option) {
                return option.fullName.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    ) ||
                    option.matricule.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    );
              });
            },
            displayStringForOption: (Student option) =>
                "${option.fullName} (${option.matricule})",
            onSelected: _onStudentSelected,
            fieldViewBuilder:
                (context, textController, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: textController,
                    focusNode: focusNode,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "Nom ou matricule...",
                      hintStyle: TextStyle(color: subText),
                      icon: Icon(Icons.search, color: subText),
                    ),
                  );
                },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4.0,
                  color: bg,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 200,
                    ), // Limit height
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (BuildContext context, int index) {
                        final Student option = options.elementAt(index);
                        return InkWell(
                          onTap: () {
                            onSelected(option);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              "${option.fullName} (${option.matricule})",
                              style: TextStyle(color: textColor),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEditorForm(Color bg, Color textColor, Color? subText) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note, color: Color(0xFFe11d48)),
              const SizedBox(width: 8),
              Text(
                "Informations de l'élève",
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInput("Nom et Prénom", _nameController, textColor, subText),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInput(
                  "Matricule",
                  _matriculeController,
                  textColor,
                  subText,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInput(
                  "Classe",
                  _classeController,
                  textColor,
                  subText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInput("Sexe", _sexeController, textColor, subText),
              ), // Could be dropdown
              const SizedBox(width: 16),
              Expanded(
                child: _buildInput(
                  "Date Naiss.",
                  _dobController,
                  textColor,
                  subText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInput("Lieu de Naissance", _lieuController, textColor, subText),
          const SizedBox(height: 16),
          _buildInput(
            "Contact d'urgence",
            _emergencyController,
            textColor,
            subText,
          ),

          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Sélectionnez un élève en haut pour charger ses données ou modifiez les champs manuellement.",
                    style: TextStyle(color: Colors.blue[800], fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(
    String label,
    TextEditingController controller,
    Color textColor,
    Color? subText,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: subText,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF0f172a)
                : const Color(0xFFf8fafc),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFe11d48)),
            ),
          ),
          onChanged: (val) {
            setState(() {}); // Trigget rebuild for card preview
          },
        ),
      ],
    );
  }

  // --- CARD UI ---
  Widget _buildCardPreview() {
    // Create a temporary student object with current form values
    Student? displayStudent;
    if (selectedStudent != null || _nameController.text.isNotEmpty) {
      displayStudent =
          selectedStudent?.copyWith(
            nom: _nameController.text
                .split(' ')
                .first, // Rough approximation if manual edit
            prenom: _nameController.text.split(' ').skip(1).join(' '),
            matricule: _matriculeController.text,
            classe: _classeController.text,
            sexe: _sexeController.text,
            dateNaissance: _dobController.text,
            lieuNaissance: _lieuController.text,
          ) ??
          Student(
            id: 'tmp',
            matricule: _matriculeController.text,
            nom: _nameController.text,
            prenom: '',
            dateNaissance: _dobController.text,
            lieuNaissance: _lieuController.text,
            sexe: _sexeController.text,
            classe: _classeController.text,
            statut: 'Inscrit',
          );
    }
    // We need to pass the full student with photo. If selectedStudent is null, photo is empty.
    if (selectedStudent != null) {
      // If we are editing, we are just changing text fields, photo remains same
      displayStudent = selectedStudent;
    }

    return Center(
      child: StudentIdCard(
        student: displayStudent,
        ecole: ecole,
        anneeLibelle: selectedAnnee,
      ),
    );
  }

  // --- PRINT / PDF ---
  Future<void> _printCard() async {
    final pdf = await _generatePdfDocument();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> _exportPdf() async {
    final pdf = await _generatePdfDocument();
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'carte_${_nameController.text}.pdf',
    );
  }

  Future<pw.Document> _generatePdfDocument() async {
    final doc = pw.Document();

    // Load fonts / images
    // Note: For PDF we need to load fonts usually, otherwise it uses default.
    // We'll use standard fonts for simplicity or provided ones if available.

    final fontBold = await PdfGoogleFonts.interBold();
    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBlack = await PdfGoogleFonts.interBlack();

    // Image Providers
    pw.MemoryImage? logoImage;
    pw.MemoryImage? photoImage;

    if (ecole?.logo != null && File(ecole!.logo!).existsSync()) {
      logoImage = pw.MemoryImage(File(ecole!.logo!).readAsBytesSync());
    }

    if (selectedStudent != null &&
        selectedStudent!.photo.isNotEmpty &&
        File(selectedStudent!.photo).existsSync()) {
      photoImage = pw.MemoryImage(
        File(selectedStudent!.photo).readAsBytesSync(),
      );
    }
    // We can't easily get the 'controller' values if user manually edited them without saving to DB.
    // But controllers are valid.

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Container(
              width: 500, // PDF units
              height: 500 / 1.6,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                color: PdfColors.white,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(15)),
              ),
              child: pw.Stack(
                children: [
                  // Header
                  pw.Positioned(
                    top: 10,
                    left: 15,
                    right: 15,
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: 40,
                          height: 40,
                          decoration: const pw.BoxDecoration(
                            shape: pw.BoxShape.circle,
                            color: PdfColors.grey100,
                          ),
                          child: logoImage != null
                              ? pw.ClipOval(child: pw.Image(logoImage))
                              : pw.Container(),
                        ),
                        pw.Column(
                          children: [
                            pw.Text(
                              "REPUBLIQUE DE GUINEE",
                              style: pw.TextStyle(
                                font: fontBlack,
                                fontSize: 10,
                              ),
                            ),
                            pw.Text(
                              "Travail - Justice - Solidarité",
                              style: pw.TextStyle(
                                font: fontRegular,
                                fontSize: 8,
                                fontStyle: pw.FontStyle.italic,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.Text(
                              "Ministère de l'Education Nationale et de l'Alphabétisation",
                              style: pw.TextStyle(
                                font: fontRegular,
                                fontSize: 6,
                                color: PdfColors.grey600,
                              ),
                            ),
                          ],
                        ),
                        pw.Container(
                          width: 40,
                          height: 40,
                        ), // Placeholder for arms
                      ],
                    ),
                  ),

                  // Badge Text
                  pw.Positioned(
                    top: 60,
                    left: 0,
                    right: 0,
                    child: pw.Center(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex("#e11d48"),
                          borderRadius: pw.BorderRadius.circular(20),
                        ),
                        child: pw.Text(
                          "CARTE D'IDENTITÉ SCOLAIRE",
                          style: pw.TextStyle(
                            font: fontBlack,
                            color: PdfColors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),

                  pw.Positioned(
                    top: 85,
                    left: 0,
                    right: 0,
                    child: pw.Center(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex("#fff7d1"),
                          borderRadius: pw.BorderRadius.circular(2),
                          border: pw.Border.all(
                            color: PdfColor.fromHex("#eab308"),
                          ),
                        ),
                        child: pw.Text(
                          "ANNÉE SCOLAIRE ${selectedAnnee ?? '2023-2024'}",
                          style: pw.TextStyle(
                            font: fontBold,
                            color: PdfColor.fromHex("#854d0e"),
                            fontSize: 8,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Main Content
                  pw.Positioned(
                    top: 110,
                    left: 20,
                    right: 20,
                    child: pw.Row(
                      children: [
                        pw.Container(
                          width: 80,
                          height: 100,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.black),
                          ),
                          child: photoImage != null
                              ? pw.Image(photoImage, fit: pw.BoxFit.cover)
                              : pw.Container(),
                        ),
                        pw.SizedBox(width: 20),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildPdfRow(
                              "Matricule:",
                              _matriculeController.text,
                              fontBold,
                              fontBlack,
                            ),
                            _buildPdfRow(
                              "Nom et Prénom:",
                              _nameController.text.toUpperCase(),
                              fontBold,
                              fontBlack,
                            ),
                            _buildPdfRow(
                              "Date de Nais.:",
                              _dobController.text,
                              fontBold,
                              fontBlack,
                            ),
                            _buildPdfRow(
                              "Classe:",
                              _classeController.text,
                              fontBold,
                              fontBlack,
                            ),
                            pw.Divider(),
                            _buildPdfRow(
                              "Prév. d'urgence:",
                              _emergencyController.text,
                              fontBold,
                              fontBlack,
                              color: PdfColor.fromHex("#e11d48"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Bottom Red Bar
                  pw.Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: pw.Container(
                      height: 40,
                      color: PdfColor.fromHex("#e11d48"),
                      alignment: pw.Alignment.bottomCenter,
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            "GUINÉE ÉCOLE",
                            style: pw.TextStyle(
                              font: fontBlack,
                              color: PdfColors.white,
                              fontSize: 14,
                              fontStyle: pw.FontStyle.italic,
                            ),
                          ),
                          pw.Text(
                            "TRAVAIL - JUSTICE - SOLIDARITÉ",
                            style: pw.TextStyle(
                              font: fontBold,
                              color: PdfColors.white,
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    return doc;
  }

  pw.Widget _buildPdfRow(
    String label,
    String value,
    pw.Font labelFont,
    pw.Font valueFont, {
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 70,
            child: pw.Text(
              label,
              style: pw.TextStyle(font: labelFont, fontSize: 8),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(font: valueFont, fontSize: 8, color: color),
          ),
        ],
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final Color color;
  WavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    var path = Path();
    // d="M0,288L80,266.7C160,245,320,203,480,197.3C640,192,800,224,960,224C1120,224,1280,192,1360,176L1440,160L1440,320L1360,320C1280,320,1120,320,960,320C800,320,640,320,480,320C320,320,160,320,80,320L0,320Z"
    // The SVG viewport is 1440x320. We need to scale it to fit our size height.
    // The Wave in HTML is at bottom.

    // Scale factors
    double scaleX = size.width / 1440;
    double scaleY = size.height / 320;

    // Reconstruct simplified path relative to size
    path.moveTo(0, 288 * scaleY);
    path.cubicTo(
      80 * scaleX,
      266.7 * scaleY,
      160 * scaleX,
      245 * scaleY,
      480 * scaleX,
      197.3 * scaleY,
    );
    // ... This manual transcription is painful and error prone.
    // Let's use a simplified wave or just the raw path.
    // A simper wave:
    path.reset();
    path.moveTo(0, size.height);
    path.lineTo(0, size.height * 0.4);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.5,
      size.width * 0.5,
      size.height * 0.4,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.3,
      size.width,
      size.height * 0.45,
    );
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
