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

      final classeRes = await DatabaseHelper.instance.getClasseWithCycle(
        widget.classeId,
      );
      if (classeRes != null) _classe = classeRes;

      // 1.1 Load Mentions for this cycle (optional, removed if unused)
      // final int? cycleId = _classe?['cycle_id'];
      // _mentions = await DatabaseHelper.instance.getMentionsByCycle(cycleId);

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

        if (widget.trimestre > 0 && widget.trimestre < 4) {
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
            double sum = 0;
            for (var g in grades) {
              double val = (g['note'] as num).toDouble();
              sum += val;
            }
            double avg = sum / grades.length;
            subjectAverages[subj['id']] = avg;
            totalPoints += avg;
          }
        }

        double generalAvg = _subjects.isNotEmpty
            ? totalPoints / _subjects.length
            : 0;

        final double passMark =
            (_classe?['moyenne_passage'] as num?)?.toDouble() ?? 10.0;
        final bool isAdmis = generalAvg >= passMark;

        calculatedResults.add({
          'student': student,
          'subject_avgs': subjectAverages,
          'total_points': totalPoints,
          'moyenne_generale': generalAvg,
          'rang_str': '',
          'is_admis': isAdmis,
          'decision': isAdmis ? 'ADMIS' : 'REDOUBLE',
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Republic Logo
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 25,
                      color: const Color(0xFFCE1126),
                    ),
                    const SizedBox(width: 2),
                    Container(
                      width: 8,
                      height: 25,
                      color: const Color(0xFFFCD116),
                    ),
                    const SizedBox(width: 2),
                    Container(
                      width: 8,
                      height: 25,
                      color: const Color(0xFF009460),
                    ),
                  ],
                ),
                const Text(
                  'RÉPUBLIQUE DE GUINÉE',
                  style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'TRAVAIL - JUSTICE - SOLIDARITÉ',
                  style: TextStyle(fontSize: 5),
                ),
              ],
            ),
            // Center: School Info
            Column(
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
                Text(
                  _ecole?.nom.toUpperCase() ?? 'GROUPE SCOLAIRE',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _ecole?.adresse ?? '',
                  style: const TextStyle(fontSize: 7),
                ),
                const SizedBox(height: 5),
                const Text(
                  "FICHE DE RÉSULTAT OFFICIELLE",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            // Right: Academic Info
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'ANNÉE SCOLAIRE',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                ),
                Text(
                  _anneeLibelle ?? '',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF13DAEC),
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(border: Border.all(width: 1)),
                  child: Text(
                    "CLASSE: ${_classe?['nom'] ?? ''}",
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'PÉRIODE: ${widget.trimestre == 4 ? 'Bilan Annuel' : 'Trimestre ${widget.trimestre}'}',
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 5),
        const Divider(color: Colors.black, thickness: 1),
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
              _th("Décision", w: 50, bg: Colors.grey[50]),
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
                    _td(
                      res['decision'] ?? '',
                      w: 50,
                      bg: res['is_admis'] ? Colors.green[50] : Colors.red[50],
                      bold: true,
                      fontSize: 8,
                      align: Alignment.center,
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
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';
    return Column(
      children: [
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Recap Box
            Container(
              width: 180,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RÉCAPITULATIF DE CLASSE',
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    height: 1,
                    color: Colors.black,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  _recapRow(
                    'Effectif total:',
                    '${_classStats['effectif']} Élèves',
                  ),
                  _recapRow(
                    'Moyenne de la classe:',
                    '${(_classStats['moyenne_classe'] as double? ?? 0).toStringAsFixed(2)} / 20',
                  ),
                  _recapRow(
                    'Taux de réussite:',
                    '${(_classStats['taux_reussite'] as double? ?? 0).toStringAsFixed(1)}%',
                  ),
                ],
              ),
            ),
            // Right: Signature Box
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'CACHET DU DIRECTEUR',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const SizedBox(height: 40),
                Container(width: 180, height: 1, color: Colors.black),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Document généré par Guinée École le $dateStr',
              style: const TextStyle(fontSize: 6, color: Colors.grey),
            ),
            const Text(
              'Page 1/1',
              style: TextStyle(fontSize: 6, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _recapRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 7)),
          Text(
            value,
            style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold),
          ),
        ],
      ),
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
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left: Republic Logo (matching bulletin design)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 10,
                      height: 30,
                      color: PdfColor.fromInt(0xFFCE1126),
                    ),
                    pw.SizedBox(width: 2),
                    pw.Container(
                      width: 10,
                      height: 30,
                      color: PdfColor.fromInt(0xFFFCD116),
                    ),
                    pw.SizedBox(width: 2),
                    pw.Container(
                      width: 10,
                      height: 30,
                      color: PdfColor.fromInt(0xFF009460),
                    ),
                  ],
                ),
                pw.Text(
                  'RÉPUBLIQUE DE GUINÉE',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'TRAVAIL - JUSTICE - SOLIDARITÉ',
                  style: const pw.TextStyle(fontSize: 5),
                ),
              ],
            ),
            // Center: School Info
            pw.Column(
              children: [
                if (logo != null)
                  pw.Container(width: 50, height: 50, child: pw.Image(logo)),
                pw.Text(
                  _ecole?.nom.toUpperCase() ?? 'GROUPE SCOLAIRE',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  _ecole?.adresse ?? '',
                  style: const pw.TextStyle(fontSize: 8),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  "FICHE DE RÉSULTAT OFFICIELLE",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                  child: pw.Text(
                    "CLASSE: ${_classe?['nom'] ?? ''}",
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            // Right: Academic Info
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'ANNÉE SCOLAIRE',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  _anneeLibelle ?? '',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF13DAEC),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'PÉRIODE: ${widget.trimestre == 4 ? 'Bilan Annuel' : 'Trimestre ${widget.trimestre}'}',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Divider(thickness: 1, color: PdfColors.black),
      ],
    );
  }

  pw.Widget _buildPdfTable(Map<String, pw.MemoryImage> photos) {
    final Map<int, pw.TableColumnWidth> columnWidths = {
      0: const pw.FixedColumnWidth(25), // Rang
      1: const pw.FixedColumnWidth(25), // Photo
      2: const pw.FixedColumnWidth(55), // Matricule
      3: const pw.FlexColumnWidth(3), // Nom
    };

    int colIdx = 4;
    for (var i = 0; i < _subjects.length; i++) {
      columnWidths[colIdx++] = const pw.FixedColumnWidth(30);
    }
    columnWidths[colIdx++] = const pw.FixedColumnWidth(35); // Total Points
    columnWidths[colIdx++] = const pw.FixedColumnWidth(40); // Moyenne
    columnWidths[colIdx++] = const pw.FixedColumnWidth(45); // Decision

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: columnWidths,
      children: [
        // Header Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _pdfHeaderCell("Rang"),
            _pdfHeaderCell("Photo"),
            _pdfHeaderCell("Matricule"),
            _pdfHeaderCell("Nom et Prénoms", align: pw.Alignment.centerLeft),
            ..._subjects.map((s) {
              String name = s['nom'].toString();
              return _pdfHeaderCell(
                name.substring(0, min(name.length, 4)).toUpperCase(),
              );
            }),
            _pdfHeaderCell("Total\nPoints"),
            _pdfHeaderCell("Moyenne\nGénérale"),
            _pdfHeaderCell("Décision"),
          ],
        ),
        // Data Rows
        ..._studentResults.map((res) {
          final student = res['student'] as Student;
          final avgs = res['subject_avgs'] as Map<int, double>;

          return pw.TableRow(
            verticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              _pdfDataCell(res['rang_str'], bold: true),
              photos.containsKey(student.id)
                  ? pw.Container(
                      width: 18,
                      height: 18,
                      child: pw.Image(
                        photos[student.id]!,
                        fit: pw.BoxFit.cover,
                      ),
                    )
                  : pw.Container(
                      width: 18,
                      height: 18,
                      color: PdfColors.grey200,
                    ),
              _pdfDataCell(student.matricule, fontSize: 6),
              _pdfDataCell(
                student.fullName.toUpperCase(),
                align: pw.Alignment.centerLeft,
                bold: true,
                fontSize: 7,
              ),
              ..._subjects.map((s) {
                final avg = avgs[s['id']];
                return _pdfDataCell(avg != null ? avg.toStringAsFixed(2) : "-");
              }),
              _pdfDataCell(
                (res['total_points'] as double).toStringAsFixed(2),
                bold: true,
              ),
              _pdfDataCell(
                (res['moyenne_generale'] as double).toStringAsFixed(2),
                bold: true,
              ),
              _pdfDataCell(res['decision'] ?? '', bold: true, fontSize: 6),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _pdfHeaderCell(
    String text, {
    pw.Alignment align = pw.Alignment.center,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(3),
      alignment: align,
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _pdfDataCell(
    String text, {
    bool bold = false,
    pw.Alignment align = pw.Alignment.center,
    double fontSize = 7,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(3),
      alignment: align,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _buildPdfFooter() {
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';

    return pw.Column(
      children: [
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left: Recap Box
            pw.Container(
              width: 180,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'RÉCAPITULATIF DE CLASSE',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Container(
                    height: 1,
                    color: PdfColors.black,
                    margin: const pw.EdgeInsets.symmetric(vertical: 4),
                  ),
                  _recapPdfRow(
                    'Effectif total:',
                    '${_classStats['effectif']} Élèves',
                  ),
                  _recapPdfRow(
                    'Moyenne de la classe:',
                    '${(_classStats['moyenne_classe'] as double? ?? 0).toStringAsFixed(2)} / 20',
                  ),
                  _recapPdfRow(
                    'Taux de réussite:',
                    '${(_classStats['taux_reussite'] as double? ?? 0).toStringAsFixed(1)}%',
                  ),
                ],
              ),
            ),
            // Right: Signature Box
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'CACHET DU DIRECTEUR',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
                pw.SizedBox(height: 40),
                pw.Container(width: 180, height: 1, color: PdfColors.black),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Document généré par Guinée École le $dateStr',
              style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey),
            ),
            pw.Text(
              'Page 1/1',
              style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _recapPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 7)),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
