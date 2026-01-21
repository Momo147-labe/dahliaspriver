import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/database/database_helper.dart';
import '../../models/student.dart';
import '../../models/ecole.dart';

class ResultSheetPage extends StatefulWidget {
  final int classeId;
  final int trimestre;
  final int sequence;
  final int anneeId;

  const ResultSheetPage({
    super.key,
    required this.classeId,
    required this.trimestre,
    required this.sequence,
    required this.anneeId,
  });

  @override
  State<ResultSheetPage> createState() => _ResultSheetPageState();
}

class _ResultSheetPageState extends State<ResultSheetPage> {
  bool _isLoading = true;
  Ecole? _ecole;
  Map<String, dynamic>? _classe;
  String? _anneeLibelle;

  // Data Structure
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _studentResults = [];
  Map<String, dynamic> _classStats = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Basic Info
      final ecoleList = await db.query('ecole', limit: 1);
      if (ecoleList.isNotEmpty) _ecole = Ecole.fromMap(ecoleList.first);

      final classeRes = await db.query(
        'classe',
        where: 'id = ?',
        whereArgs: [widget.classeId],
        limit: 1,
      );
      if (classeRes.isNotEmpty) _classe = classeRes.first;

      final anneeRes = await db.query(
        'annee_scolaire',
        where: 'id = ?',
        whereArgs: [widget.anneeId],
        limit: 1,
      );
      if (anneeRes.isNotEmpty)
        _anneeLibelle = anneeRes.first['libelle'] as String;

      // 2. Load Subjects for this Class
      // We need to know which subjects are taught to build columns
      // Assuming 'coefficient' table links matiere to classe or we find used grades
      // For now, let's query unique subjects found in grades or assigned to class if that table exists.
      // Better to check data structure. Let's assume we fetch all subjects for now that have grades or are linked.
      // Since we implemented "Assign Teachers", we might check assignments, but simplest is checking grades + matiere table.

      // 2. Load Subjects for this Class
      // Find subjects that have grades for students in this class
      final subjectsRes = await db.rawQuery(
        '''
        SELECT DISTINCT m.id, m.nom
        FROM matiere m
        INNER JOIN notes n ON n.matiere_id = m.id
        INNER JOIN eleve e ON n.eleve_id = e.id
        WHERE e.classe_id = ? AND n.annee_scolaire_id = ?
        ORDER BY m.nom
      ''',
        [widget.classeId, widget.anneeId],
      );

      _subjects = List<Map<String, dynamic>>.from(subjectsRes);

      // 3. Load Students
      final students = await db.rawQuery(
        'SELECT * FROM eleve WHERE classe_id = ? ORDER BY nom, prenom',
        [widget.classeId],
      );

      // 4. Calculate Results
      List<Map<String, dynamic>> calculatedResults = [];

      for (var sRow in students) {
        final student = Student.fromMap(sRow);
        Map<int, double> subjectAverages = {};
        double totalPoints = 0;

        // Fetch grades for this student
        String periodWhere = '';
        List<dynamic> periodArgs = [student.id, widget.anneeId];

        if (widget.trimestre > 0) {
          periodWhere = 'AND trimestre = ?';
          periodArgs.add(widget.trimestre);
        }

        for (var subj in _subjects) {
          final grades = await db.rawQuery(
            '''
            SELECT note FROM notes 
            WHERE eleve_id = ? AND annee_scolaire_id = ? AND matiere_id = ? $periodWhere
          ''',
            [...periodArgs, subj['id']],
          );

          if (grades.isNotEmpty) {
            // Calculate average based on stored 'note' (assuming it's already the value)
            // If weighted average within subject needed needed, logic would go here.
            // For now, simple average of all notes found for this subject/period.
            double sum = 0;
            for (var g in grades) {
              double val = (g['note'] as num).toDouble();
              sum += val;
            }
            double avg = sum / grades.length;
            subjectAverages[subj['id']] = avg;

            // Sum of averages for General Average calculation
            totalPoints += avg;
          }
        }

        // Calculate General Average
        // If coeffs: totalPoints / totalCoeffs. If not: sum(avgs) / count(subjects)
        double generalAvg = _subjects.isNotEmpty
            ? totalPoints / _subjects.length
            : 0;

        calculatedResults.add({
          'student': student,
          'subject_avgs': subjectAverages,
          'total_points': totalPoints,
          'moyenne_generale': generalAvg,
          'rang_str': '', // To be filled
        });
      }

      // 5. Ranking (Ex-Aequo)
      calculatedResults.sort(
        (a, b) => (b['moyenne_generale'] as double).compareTo(
          a['moyenne_generale'] as double,
        ),
      );

      int currentRank = 1;
      for (int i = 0; i < calculatedResults.length; i++) {
        final current = calculatedResults[i];

        // Check tie with previous
        if (i > 0 &&
            (current['moyenne_generale'] as double) ==
                (calculatedResults[i - 1]['moyenne_generale'] as double)) {
          // Tie found
          String prevRank = calculatedResults[i - 1]['rang_str'];
          if (!prevRank.contains('ex')) {
            calculatedResults[i - 1]['rang_str'] =
                "$prevRank ex"; // Mark previous as ex
          }
          current['rang_str'] =
              "${calculatedResults[i - 1]['rang_str']}"; // Copy rank
        } else {
          // No tie, rank is i + 1
          currentRank = i + 1;
          current['rang_str'] =
              "${currentRank}${currentRank == 1 ? 'er' : 'ème'}";
        }
      }

      _studentResults = calculatedResults;

      // 6. Statistics
      if (_studentResults.isNotEmpty) {
        double classSum = _studentResults.fold(
          0,
          (sum, item) => sum + (item['moyenne_generale'] as double),
        );
        double classAvg = classSum / _studentResults.length;
        int passedCount = _studentResults
            .where((item) => (item['moyenne_generale'] as double) >= 10)
            .length;
        double successRate = (passedCount / _studentResults.length) * 100;

        _classStats = {
          'effectif': _studentResults.length,
          'moyenne_classe': classAvg,
          'taux_reussite': successRate,
        };
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Error loading result sheet: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF102022)
          : const Color(0xFFf6f8f8),
      appBar: AppBar(
        title: const Text('Fiche de Résultat Officielle'),
        backgroundColor: isDark ? const Color(0xFF102022) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.table_view),
            onPressed: _exportExcel,
            tooltip: "Export Excel",
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => _exportPdf(printOpen: false),
            tooltip: 'Exporter PDF',
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _exportPdf(printOpen: true),
            tooltip: 'Imprimer',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Preview Container
            Container(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: AspectRatio(
                aspectRatio: 1.414, // A4 Landscape
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Watermark
                      Center(
                        child: Transform.rotate(
                          angle: -0.26,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.1),
                                width: 8,
                              ),
                              borderRadius: BorderRadius.circular(1000),
                            ),
                            padding: const EdgeInsets.all(40),
                            child: Text(
                              "DIRECTION GÉNÉRALE\nGUINÉE ÉCOLE\nOFFICIEL",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 60,
                                fontWeight: FontWeight.w900,
                                color: Colors.grey.withOpacity(0.05),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Content
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 16),
                            Expanded(child: _buildTable()),
                            const SizedBox(height: 16),
                            _buildFooter(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI Widgets ---

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Ministry & School
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child:
                        _ecole?.logo != null && File(_ecole!.logo!).existsSync()
                        ? Image.file(File(_ecole!.logo!), fit: BoxFit.contain)
                        : const Icon(Icons.school, color: Colors.grey),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Ministère de l'Éducation Nationale et de l'Alphabétisation",
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          "Inspection Régionale de Conakry",
                          style: TextStyle(fontSize: 8),
                        ),
                        if (_ecole != null)
                          Text(
                            _ecole!.nom.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Center: Title
            Expanded(
              child: Column(
                children: [
                  const Text(
                    "FICHE DE RÉSULTAT OFFICIELLE",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    "Année Scolaire: ${_anneeLibelle ?? ''}",
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black),
                    ),
                    child: Text(
                      "Classe: ${_classe?['nom'] ?? ''}",
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Right: Republic
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Icon(Icons.verified_outlined, size: 24),
                  const Text(
                    "RÉPUBLIQUE DE GUINÉE",
                    style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    "Travail — Justice — Solidarité",
                    style: TextStyle(fontSize: 7),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Divider(color: Colors.black, thickness: 2, height: 16),
      ],
    );
  }

  Widget _buildTable() {
    return Column(
      children: [
        // Header
        Container(
          height: 35,
          color: Colors.grey[100],
          child: Row(
            children: [
              _th("Rang", w: 30),
              _th("Photo", w: 30),
              _th("Matricule", w: 60),
              Expanded(
                child: _th("Nom et Prénoms", align: Alignment.centerLeft),
              ),
              ..._subjects.map(
                (s) => _th(
                  s['nom']
                      .toString()
                      .substring(0, min(s['nom'].toString().length, 4))
                      .toUpperCase(),
                  w: 35,
                ),
              ),
              _th("Total", w: 40, bg: Colors.grey[50]),
              _th("Moy\nGén", w: 45, bg: Colors.grey[200]),
            ],
          ),
        ),
        // Rows
        Expanded(
          child: ListView.builder(
            itemCount: _studentResults.length,
            itemBuilder: (context, index) {
              final res = _studentResults[index];
              final student = res['student'] as Student;
              final avgs = res['subject_avgs'] as Map<int, double>;
              final isEven = index % 2 == 0;

              return Container(
                height: 30,
                color: isEven ? Colors.white : Colors.grey[50],
                child: Row(
                  children: [
                    _td(
                      res['rang_str'],
                      w: 30,
                      bold: true,
                      align: Alignment.center,
                    ),
                    _tdPhoto(student.photo),
                    _td(student.matricule, w: 60, fontSize: 8),
                    Expanded(
                      child: _td(
                        student.fullName,
                        align: Alignment.centerLeft,
                        bold: true,
                      ),
                    ),
                    ..._subjects.map((s) {
                      final avg = avgs[s['id']];
                      return _td(
                        avg != null ? avg.toStringAsFixed(2) : "-",
                        w: 35,
                        align: Alignment.center,
                      );
                    }),
                    _td(
                      (res['total_points'] as double).toStringAsFixed(2),
                      w: 40,
                      bg: Colors.grey[50],
                      bold: true,
                    ),
                    _td(
                      (res['moyenne_generale'] as double).toStringAsFixed(2),
                      w: 45,
                      bg: Colors.grey[200],
                      bold: true,
                      fontSize: 10,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _th(
    String text, {
    double? w,
    Alignment align = Alignment.center,
    Color? bg,
  }) {
    return Container(
      width: w,
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: Colors.grey[300]!, width: 0.5),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _td(
    String text, {
    double? w,
    Alignment align = Alignment.center,
    bool bold = false,
    double fontSize = 9,
    Color? bg,
  }) {
    return Container(
      width: w,
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: Colors.grey[300]!, width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _tdPhoto(String path) {
    return Container(
      width: 30,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!, width: 0.5),
      ),
      padding: const EdgeInsets.all(1),
      child: path.isNotEmpty && File(path).existsSync()
          ? Image.file(File(path), fit: BoxFit.cover)
          : const Icon(Icons.person, size: 12),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Stats
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[50],
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Récapitulatif de Classe",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Effectif: ${_classStats['effectif']} Élèves",
                    style: const TextStyle(fontSize: 8),
                  ),
                  Text(
                    "Moyenne: ${(_classStats['moyenne_classe'] as double? ?? 0).toStringAsFixed(2)} / 20",
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Taux de réussite: ${(_classStats['taux_reussite'] as double? ?? 0).toStringAsFixed(1)}%",
                    style: const TextStyle(fontSize: 8),
                  ),
                ],
              ),
            ),
            // Signatures
            Padding(
              padding: const EdgeInsets.only(right: 32),
              child: Column(
                children: [
                  const Text(
                    "Cachet du Directeur",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Mock stamp
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Document généré par Guinée École",
              style: TextStyle(fontSize: 7, color: Colors.grey),
            ),
            const Text(
              "Page 1/1",
              style: TextStyle(fontSize: 7, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  int min(int a, int b) => a < b ? a : b;

  // --- Export Logic ---

  Future<void> _exportExcel() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Export Excel cours d'implémentation (Package requis)"),
      ),
    );
  }

  Future<void> _exportPdf({bool printOpen = false}) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    // Pre-load images
    pw.MemoryImage? logoImage;
    if (_ecole?.logo != null && File(_ecole!.logo!).existsSync()) {
      logoImage = pw.MemoryImage(File(_ecole!.logo!).readAsBytesSync());
    }

    final Map<String, pw.MemoryImage> photos = {};
    for (var res in _studentResults) {
      final s = res['student'] as Student;
      if (s.photo.isNotEmpty && File(s.photo).existsSync()) {
        photos[s.id] = pw.MemoryImage(File(s.photo).readAsBytesSync());
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return [
            _buildPdfHeader(logoImage),
            pw.SizedBox(height: 10),
            _buildPdfTable(photos),
            pw.SizedBox(height: 10),
            _buildPdfFooter(),
          ];
        },
      ),
    );

    if (printOpen) {
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } else {
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'fiche_resultat_officielle.pdf',
      );
    }
  }

  // --- PDF Widgets ---

  pw.Widget _buildPdfHeader(pw.MemoryImage? logo) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Row(
                children: [
                  if (logo != null)
                    pw.Container(width: 40, height: 40, child: pw.Image(logo)),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "Ministère de l'Éducation Nationale...",
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          "Inspection Régionale de Conakry",
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                        if (_ecole != null)
                          pw.Text(
                            _ecole!.nom.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Text(
                    "FICHE DE RÉSULTAT OFFICIELLE",
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    "Année Scolaire: ${_anneeLibelle ?? ''}",
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Container(
                    margin: const pw.EdgeInsets.only(top: 4),
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    decoration: pw.BoxDecoration(border: pw.Border.all()),
                    child: pw.Text(
                      "Classe: ${_classe?['nom'] ?? ''}",
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    "RÉPUBLIQUE DE GUINÉE",
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    "Travail — Justice — Solidarité",
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.Divider(),
      ],
    );
  }

  pw.Widget _buildPdfTable(Map<String, pw.MemoryImage> photos) {
    final headers = [
      "Rang",
      "Photo",
      "Matricule",
      "Nom et Prénoms",
      ..._subjects.map(
        (s) => s['nom']
            .toString()
            .substring(0, min(s['nom'].toString().length, 4))
            .toUpperCase(),
      ),
      "Total",
      "Moy\nGén",
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey800, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(25), // Rang
        1: const pw.FixedColumnWidth(25), // Photo
        2: const pw.FixedColumnWidth(50), // Mat
        3: const pw.FlexColumnWidth(), // Nom
        // Dynamic cols will be auto/flex in standard table logic or fixed if we knew count.
        // PDF Table columnWidths map matches index.
        // We must generate the map dynamically.
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: headers
              .map(
                (h) => pw.Container(
                  padding: const pw.EdgeInsets.all(2),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    h,
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        // Rows
        ..._studentResults.map((res) {
          final student = res['student'] as Student;
          final avgs = res['subject_avgs'] as Map<int, double>;

          return pw.TableRow(
            verticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              _pdfCell(res['rang_str'], bold: true),
              photos.containsKey(student.id)
                  ? pw.Container(
                      width: 20,
                      height: 20,
                      child: pw.Image(
                        photos[student.id]!,
                        fit: pw.BoxFit.cover,
                      ),
                    )
                  : pw.Container(
                      width: 20,
                      height: 20,
                      color: PdfColors.grey200,
                    ),
              _pdfCell(student.matricule),
              _pdfCell(
                student.fullName,
                align: pw.Alignment.centerLeft,
                bold: true,
              ),
              ..._subjects.map((s) {
                final avg = avgs[s['id']];
                return _pdfCell(avg != null ? avg.toStringAsFixed(2) : "-");
              }),
              _pdfCell(
                (res['total_points'] as double).toStringAsFixed(2),
                bold: true,
              ),
              _pdfCell(
                (res['moyenne_generale'] as double).toStringAsFixed(2),
                bold: true,
              ),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _pdfCell(
    String text, {
    bool bold = false,
    pw.Alignment align = pw.Alignment.center,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(2),
      alignment: align,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _buildPdfFooter() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(5),
          decoration: pw.BoxDecoration(border: pw.Border.all()),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Récapitulatif",
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                "Effectif: ${_classStats['effectif']}",
                style: const pw.TextStyle(fontSize: 7),
              ),
              pw.Text(
                "Moyenne: ${(_classStats['moyenne_classe'] as double? ?? 0).toStringAsFixed(2)}",
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                "Taux: ${(_classStats['taux_reussite'] as double? ?? 0).toStringAsFixed(1)}%",
                style: const pw.TextStyle(fontSize: 7),
              ),
            ],
          ),
        ),
        pw.Column(
          children: [
            pw.Text(
              "Cachet du Directeur",
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                decoration: pw.TextDecoration.underline,
              ),
            ),
            pw.SizedBox(height: 30),
          ],
        ),
      ],
    );
  }
}
