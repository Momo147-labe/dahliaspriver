import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/ecole.dart';

class BulletinPdfHelper {
  static Future<pw.Document> generateSingleBulletin({
    required Map<String, dynamic> student,
    required List<Map<String, dynamic>> grades,
    required Map<String, dynamic> stats,
    required Ecole? ecole,
    required String trimestre,
    required String annee,
  }) async {
    final pdf = pw.Document();
    await _addBulletinPage(
      pdf,
      student,
      grades,
      stats,
      ecole,
      trimestre,
      annee,
    );
    return pdf;
  }

  static Future<pw.Document> generateBatchBulletins({
    required List<Map<String, dynamic>>
    studentsData, // List of {student, grades, stats}
    required Ecole? ecole,
    required String trimestre,
    required String annee,
  }) async {
    final pdf = pw.Document();
    for (var data in studentsData) {
      await _addBulletinPage(
        pdf,
        data['student'],
        data['grades'],
        data['stats'],
        ecole,
        trimestre,
        annee,
      );
    }
    return pdf;
  }

  static Future<pw.Document> generateSingleAnnualBulletin({
    required Map<String, dynamic> student,
    required List<Map<String, dynamic>> grades,
    required Map<String, dynamic> stats,
    required Ecole? ecole,
    required String annee,
  }) async {
    final pdf = pw.Document();
    await _addAnnualBulletinPage(pdf, student, grades, stats, ecole, annee);
    return pdf;
  }

  static Future<pw.Document> generateBatchAnnualBulletins({
    required List<Map<String, dynamic>> studentsData,
    required Ecole? ecole,
    required String annee,
  }) async {
    final pdf = pw.Document();
    for (var data in studentsData) {
      await _addAnnualBulletinPage(
        pdf,
        data['student'],
        data['grades'],
        data['stats'],
        ecole,
        annee,
      );
    }
    return pdf;
  }

  static Future<void> _addBulletinPage(
    pw.Document pdf,
    Map<String, dynamic> student,
    List<Map<String, dynamic>> grades,
    Map<String, dynamic> stats,
    Ecole? ecole,
    String trimestre,
    String annee,
  ) async {
    // Load logo if available
    final logoPath = ecole?.logo;
    pw.MemoryImage? logoImage;
    if (logoPath != null && File(logoPath).existsSync()) {
      logoImage = pw.MemoryImage(File(logoPath).readAsBytesSync());
    }

    // Load student photo if available
    final photoPath = student['photo'];
    pw.MemoryImage? studentPhoto;
    if (photoPath != null && File(photoPath).existsSync()) {
      studentPhoto = pw.MemoryImage(File(photoPath).readAsBytesSync());
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: pw.EdgeInsets.all(30),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildHeader(logoImage, ecole, annee, trimestre),
                pw.SizedBox(height: 10),
                // Header underline as in requested design (conversion entete sans modifier)
                // Actually the user said keep header, modify after.
                pw.Divider(thickness: 1, color: PdfColors.black),
                pw.SizedBox(height: 10),
                _buildStudentInfoBox(student, trimestre, studentPhoto),
                pw.SizedBox(height: 20),
                _buildGradesTable(grades),
                pw.SizedBox(height: 20),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(flex: 3, child: _buildAcademicSynthesis(stats)),
                    pw.SizedBox(width: 20),
                    pw.Expanded(flex: 2, child: _buildDirectionSignature()),
                  ],
                ),
                pw.Spacer(),
                _buildPdfBottomFooter(student, annee),
              ],
            ),
          );
        },
      ),
    );
  }

  static Future<void> _addAnnualBulletinPage(
    pw.Document pdf,
    Map<String, dynamic> student,
    List<Map<String, dynamic>> grades,
    Map<String, dynamic> stats,
    Ecole? ecole,
    String annee,
  ) async {
    // Load logo if available
    final logoPath = ecole?.logo;
    pw.MemoryImage? logoImage;
    if (logoPath != null && File(logoPath).existsSync()) {
      logoImage = pw.MemoryImage(File(logoPath).readAsBytesSync());
    }

    // Load student photo if available
    final photoPath = student['photo'];
    pw.MemoryImage? studentPhoto;
    if (photoPath != null && File(photoPath).existsSync()) {
      studentPhoto = pw.MemoryImage(File(photoPath).readAsBytesSync());
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: pw.EdgeInsets.all(30),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildHeader(logoImage, ecole, annee, 'BILAN ANNUEL'),
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 1, color: PdfColors.black),
                pw.SizedBox(height: 10),
                _buildStudentInfoBox(student, 'BILAN ANNUEL', studentPhoto),
                pw.SizedBox(height: 20),
                _buildAnnualGradesTable(grades),
                pw.SizedBox(height: 20),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(flex: 3, child: _buildAcademicSynthesis(stats)),
                    pw.SizedBox(width: 20),
                    pw.Expanded(flex: 2, child: _buildDirectionSignature()),
                  ],
                ),
                pw.Spacer(),
                _buildPdfBottomFooter(student, annee),
              ],
            ),
          );
        },
      ),
    );
  }

  static pw.Widget _buildHeader(
    pw.MemoryImage? logo,
    Ecole? ecole,
    String annee,
    String trimestre,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Republic Logo
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
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'TRAVAIL - JUSTICE - SOLIDARITÉ',
              style: pw.TextStyle(fontSize: 5),
            ),
          ],
        ),
        // School Info
        pw.Expanded(
          child: pw.Column(
            children: [
              if (logo != null)
                pw.Container(width: 40, height: 40, child: pw.Image(logo)),
              pw.Text(
                ecole?.nom.toUpperCase() ?? 'GROUPE SCOLAIRE',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                ecole?.adresse ?? '',
                style: pw.TextStyle(fontSize: 7),
                textAlign: pw.TextAlign.center,
              ),
              if (ecole?.telephone != null)
                pw.Text(
                  'Tél: ${ecole!.telephone}',
                  style: pw.TextStyle(fontSize: 7),
                ),
            ],
          ),
        ),
        // Academic Info
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'ANNÉE SCOLAIRE',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              annee,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF13DAEC),
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Container(
              padding: pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Text(
                trimestre,
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildStudentInfoBox(
    Map<String, dynamic> student,
    String periode,
    pw.MemoryImage? photo,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1),
      ),
      padding: pw.EdgeInsets.all(10),
      child: pw.Row(
        children: [
          pw.Container(
            width: 70,
            height: 70,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: photo != null
                ? pw.Image(photo, fit: pw.BoxFit.cover)
                : pw.Center(
                    child: pw.Text(
                      'PHOTO',
                      style: pw.TextStyle(fontSize: 8),
                    ),
                  ),
          ),
          pw.SizedBox(width: 20),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoRow(
                  'NOM ET PRÉNOMS',
                  (student['nom'] + ' ' + (student['prenom'] ?? ''))
                      .toUpperCase(),
                  isBold: true,
                ),
                _infoRow('CLASSE', (student['classe_nom'] ?? '').toUpperCase()),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoRow(
                  'MATRICULE',
                  (student['matricule'] ?? '').toUpperCase(),
                ),
                _infoRow('PÉRIODE', periode.toUpperCase()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Container(height: 0.5, color: PdfColors.grey300, width: 150),
        ],
      ),
    );
  }

  static pw.Widget _buildGradesTable(List<Map<String, dynamic>> grades) {
    // Group grades by subject to split Control and Comp
    Map<String, Map<String, dynamic>> grouped = {};
    for (var g in grades) {
      String mId = g['matiere_id']?.toString() ?? g['matiere_nom'];
      if (!grouped.containsKey(mId)) {
        grouped[mId] = {
          'nom': g['matiere_nom'],
          'coeff': (g['coefficient'] as num?)?.toDouble() ?? 1.0,
          'control': null,
          'comp': null,
        };
      }

      double note = (g['note'] as num?)?.toDouble() ?? 0.0;
      int seq = g['sequence'] ?? 1;

      // Heuristic: sequence 3, 6, 9 are usually composition
      if (seq % 3 == 0) {
        grouped[mId]!['comp'] = note;
      } else {
        // Handle multiple controls by averaging them if needed, or taking one
        if (grouped[mId]!['control'] == null) {
          grouped[mId]!['control'] = note;
        } else {
          grouped[mId]!['control'] = (grouped[mId]!['control'] + note) / 2;
        }
      }
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: {
        0: pw.FlexColumnWidth(3), // Matières
        1: pw.FixedColumnWidth(40), // Coeff
        2: pw.FixedColumnWidth(60), // Contrôle
        3: pw.FixedColumnWidth(60), // Comp
        4: pw.FixedColumnWidth(60), // Moyenne
        5: pw.FlexColumnWidth(3), // Appreciations
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _tableHeader('MATIÈRES'),
            _tableHeader('COEFF.'),
            _tableHeader('NOTE DE\nCONTRÔLE'),
            _tableHeader('NOTE DE\nCOMP.'),
            _tableHeader('MOYENNE\nPONDÉRÉE'),
            _tableHeader('APPRÉCIATIONS'),
          ],
        ),
        ...grouped.values.map((g) {
          final noteCtrl = g['control'] as double?;
          final noteComp = g['comp'] as double?;
          final coeff = g['coeff'] as double;

          // Calculate weighted average for the subject
          // Usually (2*Ctrl + Comp) / 3 or just Avg.
          // If only Ctrl exists, it is the average. If both, depends on school.
          // In Guinea often: (Ctrl + Comp) / 2 or (Ctrl*2 + Comp)/3.
          // Let's use simple (Ctrl + Comp)/2 if both exist for now.
          double? subjectAvg;
          if (noteCtrl != null && noteComp != null) {
            subjectAvg = (noteCtrl + noteComp) / 2;
          } else {
            subjectAvg = noteCtrl ?? noteComp;
          }

          return pw.TableRow(
            children: [
              _tableCell(g['nom'] ?? '', alignLeft: true, isBold: true),
              _tableCell(coeff.toStringAsFixed(0)),
              _tableCell(noteCtrl?.toStringAsFixed(2) ?? '-'),
              _tableCell(noteComp?.toStringAsFixed(2) ?? '-'),
              _tableCell(subjectAvg?.toStringAsFixed(2) ?? '-', isBold: true),
              _tableCell(_getObservation(subjectAvg ?? 0.0), alignLeft: true),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildAnnualGradesTable(List<Map<String, dynamic>> grades) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: {
        0: pw.FlexColumnWidth(3), // Matières
        1: pw.FlexColumnWidth(1), // Coeff
        2: pw.FlexColumnWidth(1), // Tot T1
        3: pw.FlexColumnWidth(1), // Tot T2
        4: pw.FlexColumnWidth(1), // Tot T3
        5: pw.FlexColumnWidth(1.2), // Moy An
        6: pw.FlexColumnWidth(1), // Rang
        7: pw.FlexColumnWidth(2), // Appreciation
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tableHeader('Matières'),
            _tableHeader('Coeff'),
            _tableHeader('Moy T1'),
            _tableHeader('Moy T2'),
            _tableHeader('Moy T3'),
            _tableHeader('Moy An'),
            _tableHeader('Rang'),
            _tableHeader('Appréciation'),
          ],
        ),
        ...grades.map((g) {
          final t1 = (g['moy_t1'] as num?)?.toDouble();
          final t2 = (g['moy_t2'] as num?)?.toDouble();
          final t3 = (g['moy_t3'] as num?)?.toDouble();
          final moyAn = (g['moy_annuelle'] as num?)?.toDouble() ?? 0.0;

          return pw.TableRow(
            children: [
              _tableCell(g['matiere_nom'] ?? '', alignLeft: true),
              _tableCell('${g['coefficient']}'),
              _tableCell(t1?.toStringAsFixed(2) ?? '-'),
              _tableCell(t2?.toStringAsFixed(2) ?? '-'),
              _tableCell(t3?.toStringAsFixed(2) ?? '-'),
              _tableCell(moyAn.toStringAsFixed(2), isBold: true),
              _tableCell('${g['rang']}e'),
              _tableCell(g['appreciation'] ?? ''),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _tableCell(
    String text, {
    bool alignLeft = false,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: alignLeft ? pw.TextAlign.left : pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildAcademicSynthesis(Map<String, dynamic> stats) {
    final double avg = (stats['average'] as num?)?.toDouble() ?? 0.0;
    // Decision logic: if eleve is admin or non depende de la configuration de cycle
    final double passMark =
        (stats['moyenne_passage'] as num?)?.toDouble() ?? 10.0;
    final bool isAdmis = avg >= passMark;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1),
      ),
      padding: pw.EdgeInsets.all(10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'SYNTHÈSE ACADÉMIQUE',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              decoration: pw.TextDecoration.underline,
            ),
          ),
          pw.SizedBox(height: 8),
          _synthesisRow(
            'Total des points:',
            '${(stats['totalPoints'] ?? 0.0).toStringAsFixed(2)}',
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Moyenne Générale:',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Container(
                padding: pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: pw.BoxDecoration(color: PdfColors.black),
                child: pw.Text(
                  '${avg.toStringAsFixed(2)} / 20',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          _synthesisRow(
            'Rang:',
            '${stats['rank'] ?? '-'}',
            valueColor: PdfColors.blue,
            isItalic: true,
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'RÉSULTAT FINAL:',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Container(
                padding: pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: pw.BoxDecoration(
                  color: isAdmis ? PdfColors.green100 : PdfColors.red100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  isAdmis ? 'ADMIS' : 'REDOUBLE',
                  style: pw.TextStyle(
                    color: isAdmis ? PdfColors.green700 : PdfColors.red700,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _synthesisRow(
    String label,
    String value, {
    PdfColor? valueColor,
    bool isItalic = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: valueColor ?? PdfColors.black,
            fontStyle: isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildDirectionSignature() {
    return pw.Container(
      height: 120,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            padding: pw.EdgeInsets.symmetric(vertical: 4),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.black, width: 1),
              ),
            ),
            child: pw.Text(
              'LA DIRECTION',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Spacer(),
          pw.Padding(
            padding: pw.EdgeInsets.all(4),
            child: pw.Text(
              'Signature & Cachet',
              style: pw.TextStyle(
                fontSize: 6,
                color: PdfColors.grey700,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfBottomFooter(
    Map<String, dynamic> student,
    String annee,
  ) {
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';
    return pw.Column(
      children: [
        pw.Divider(thickness: 0.5, color: PdfColors.grey),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'ID: BULT-$annee-${student['matricule']}',
              style: pw.TextStyle(fontSize: 6, color: PdfColors.grey),
            ),
            pw.Text(
              'ÉMIS PAR GUINÉE ÉCOLE LE $dateStr',
              style: pw.TextStyle(fontSize: 6, color: PdfColors.grey),
            ),
            pw.Text(
              'PAGE 1 / 1',
              style: pw.TextStyle(fontSize: 6, color: PdfColors.grey),
            ),
          ],
        ),
      ],
    );
  }

  static String _getObservation(double note) {
    if (note >= 16) return 'Très Bien';
    if (note >= 14) return 'Bien';
    if (note >= 12) return 'Assez Bien';
    if (note >= 10) return 'Passable';
    return 'Insuffisant';
  }
}
