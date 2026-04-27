import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/ecole.dart';
import '../../core/utils/mention_helper.dart';

class BulletinPdfHelper {
  static Future<pw.Document> generateSingleBulletin({
    required Map<String, dynamic> student,
    required List<Map<String, dynamic>> grades,
    required Map<String, dynamic> stats,
    required Ecole? ecole,
    required String trimestre,
    required String annee,
    required List<Map<String, dynamic>> columns,
    String noteKey = 'notes_par_sequence',
    List<Map<String, dynamic>> mentions = const [],
  }) async {
    final pdf = pw.Document();

    // Load logo once
    pw.MemoryImage? logoImage;
    final logoPath = ecole?.logo;
    if (logoPath != null && File(logoPath).existsSync()) {
      logoImage = pw.MemoryImage(File(logoPath).readAsBytesSync());
    }

    await _addBulletinPage(
      pdf,
      student,
      grades,
      stats,
      ecole,
      trimestre,
      annee,
      columns,
      noteKey,
      mentions,
      logoImage: logoImage,
    );
    return pdf;
  }

  static Future<pw.Document> generateBatchBulletins({
    required List<Map<String, dynamic>>
    studentsData, // List of {student, grades, stats}
    required Ecole? ecole,
    required String trimestre,
    required String annee,
    required List<Map<String, dynamic>> columns,
    String noteKey = 'notes_par_sequence',
    List<Map<String, dynamic>> mentions = const [],
  }) async {
    final pdf = pw.Document();

    // Load logo once for the whole batch
    pw.MemoryImage? logoImage;
    final logoPath = ecole?.logo;
    if (logoPath != null && File(logoPath).existsSync()) {
      logoImage = pw.MemoryImage(File(logoPath).readAsBytesSync());
    }

    for (var data in studentsData) {
      await _addBulletinPage(
        pdf,
        data['student'],
        data['grades'],
        data['stats'],
        ecole,
        trimestre,
        annee,
        columns,
        noteKey,
        mentions,
        logoImage: logoImage,
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
    required List<Map<String, dynamic>> columns,
    String noteKey = 'notes_par_trimestre',
    List<Map<String, dynamic>> mentions = const [],
  }) async {
    final pdf = pw.Document();

    // Load logo once
    pw.MemoryImage? logoImage;
    final logoPath = ecole?.logo;
    if (logoPath != null && File(logoPath).existsSync()) {
      logoImage = pw.MemoryImage(File(logoPath).readAsBytesSync());
    }

    await _addAnnualBulletinPage(
      pdf,
      student,
      grades,
      stats,
      ecole,
      annee,
      columns,
      noteKey,
      mentions,
      logoImage: logoImage,
    );
    return pdf;
  }

  static Future<pw.Document> generateBatchAnnualBulletins({
    required List<Map<String, dynamic>> studentsData,
    required Ecole? ecole,
    required String annee,
    required List<Map<String, dynamic>> columns,
    String noteKey = 'notes_par_trimestre',
    List<Map<String, dynamic>> mentions = const [],
  }) async {
    final pdf = pw.Document();

    // Load logo once for the whole batch
    pw.MemoryImage? logoImage;
    final logoPath = ecole?.logo;
    if (logoPath != null && File(logoPath).existsSync()) {
      logoImage = pw.MemoryImage(File(logoPath).readAsBytesSync());
    }

    for (var data in studentsData) {
      await _addAnnualBulletinPage(
        pdf,
        data['student'],
        data['grades'],
        data['stats'],
        ecole,
        annee,
        columns,
        noteKey,
        mentions,
        logoImage: logoImage,
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
    List<Map<String, dynamic>> columns,
    String noteKey,
    List<Map<String, dynamic>> mentions, {
    pw.MemoryImage? logoImage,
  }) async {
    // Shared logo passed from caller or loaded if not provided
    pw.MemoryImage? finalLogo = logoImage;
    if (finalLogo == null) {
      final logoPath = ecole?.logo;
      if (logoPath != null && File(logoPath).existsSync()) {
        finalLogo = pw.MemoryImage(File(logoPath).readAsBytesSync());
      }
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
                _buildHeader(finalLogo, ecole, annee, trimestre),
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 1, color: PdfColors.black),
                pw.SizedBox(height: 10),
                _buildStudentInfoBox(student, trimestre, studentPhoto),
                pw.SizedBox(height: 20),
                _buildGradesTable(
                  grades,
                  (stats['note_max'] as num?)?.toDouble() ?? 20.0,
                  columns,
                  noteKey,
                  mentions,
                ),
                pw.SizedBox(height: 20),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: _buildAcademicSynthesis(stats, mentions),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Expanded(flex: 2, child: _buildDirectionSignature()),
                  ],
                ),
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
    List<Map<String, dynamic>> columns,
    String noteKey,
    List<Map<String, dynamic>> mentions, {
    pw.MemoryImage? logoImage,
  }) async {
    // Shared logo passed from caller or loaded if not provided
    pw.MemoryImage? finalLogo = logoImage;
    if (finalLogo == null) {
      final logoPath = ecole?.logo;
      if (logoPath != null && File(logoPath).existsSync()) {
        finalLogo = pw.MemoryImage(File(logoPath).readAsBytesSync());
      }
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
                _buildHeader(finalLogo, ecole, annee, 'BILAN ANNUEL'),
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 1, color: PdfColors.black),
                pw.SizedBox(height: 10),
                _buildStudentInfoBox(student, 'BILAN ANNUEL', studentPhoto),
                pw.SizedBox(height: 20),
                _buildGradesTable(
                  grades,
                  (stats['note_max'] as num?)?.toDouble() ?? 20.0,
                  columns,
                  noteKey,
                  mentions,
                ),
                pw.SizedBox(height: 20),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: _buildAcademicSynthesis(stats, mentions),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Expanded(flex: 2, child: _buildDirectionSignature()),
                  ],
                ),
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
              padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    final String dateNaiss = student['date_naissance']?.toString() ?? '';
    final String lieuNaiss = student['lieu_naissance']?.toString() ?? '';
    final String sexe = student['sexe']?.toString() ?? '';
    final String neLe = dateNaiss.isNotEmpty ? 'Né(e) le: $dateNaiss' : '';
    final String aLieu = lieuNaiss.isNotEmpty ? 'à $lieuNaiss' : '';
    final String sexeText = sexe.isNotEmpty ? 'Sexe: $sexe' : '';

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1),
      ),
      padding: pw.EdgeInsets.all(10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
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
                    child: pw.Text('PHOTO', style: pw.TextStyle(fontSize: 8)),
                  ),
          ),
          pw.SizedBox(width: 20),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoRow(
                  'NOM ET PRÉNOMS',
                  '${student['nom']} ${student['prenom'] ?? ''}'.toUpperCase(),
                  isBold: true,
                ),
                if (neLe.isNotEmpty || sexeText.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    '$neLe $aLieu',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                  if (sexeText.isNotEmpty)
                    pw.Text(
                      sexeText,
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey700,
                      ),
                    ),
                ],
                pw.SizedBox(height: 4),
                _infoRow('CLASSE', (student['classe_nom'] ?? '').toUpperCase()),
              ],
            ),
          ),
          pw.SizedBox(width: 20),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _infoRow('MATRICULE', (student['matricule'] ?? '').toUpperCase()),
              _infoRow('PÉRIODE', periode.toUpperCase()),
            ],
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

  static pw.Widget _buildGradesTable(
    List<Map<String, dynamic>> grades,
    double noteMax,
    List<Map<String, dynamic>> columns,
    String noteKey,
    List<Map<String, dynamic>> mentions,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.7),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(0.8),
        for (int i = 0; i < columns.length; i++)
          i + 2: const pw.FlexColumnWidth(1.3),
        columns.length + 2: const pw.FlexColumnWidth(1.5),
        columns.length + 3: const pw.FlexColumnWidth(3.5),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _tableHeader('MATIÈRES'),
            _tableHeader('COEFF.'),
            ...columns.map((col) => _tableHeader('${col['label']}')),
            _tableHeader('MOYENNE'),
            _tableHeader('APPRÉCIATIONS'),
          ],
        ),
        ...grades.map((grade) {
          final notesMap = (grade[noteKey] as Map<dynamic, dynamic>?) ?? {};
          final moy = (grade['note'] as num?)?.toDouble();

          // Map dynamic appreciation if mentions provided
          String observation = grade['obs']?.toString() ?? '';
          if (mentions.isNotEmpty && moy != null) {
            final m = MentionHelper.getMentionForGrade(moy, mentions);
            if (m != null) {
              observation = m['appreciation'] ?? m['label'] ?? '';
            }
          }

          return pw.TableRow(
            children: [
              _tableCell(grade['matiere']?.toString() ?? '', alignLeft: true),
              _tableCell(grade['coeff']?.toString() ?? '1'),
              ...columns.map((col) {
                final key = col['key'];
                final val = (notesMap[key] as num?)?.toDouble();
                return _tableCell(val?.toStringAsFixed(2) ?? '-');
              }),
              _tableCell(moy?.toStringAsFixed(2) ?? '-', isBold: true),
              _tableCell(observation, alignLeft: true),
            ],
          );
        }),
        // Totals row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey50),
          children: [
            _tableCell('TOTAUX', isBold: true),
            _tableCell(
              grades
                  .fold<double>(
                    0,
                    (p, e) => p + ((e['coeff'] as num?)?.toDouble() ?? 0.0),
                  )
                  .toStringAsFixed(0),
              isBold: true,
            ),
            ...columns.map((_) => _tableCell('')),
            _tableCell(
              grades
                  .fold<double>(
                    0,
                    (p, e) => p + ((e['total'] as num?)?.toDouble() ?? 0.0),
                  )
                  .toStringAsFixed(2),
              isBold: true,
            ),
            _tableCell(''),
          ],
        ),
      ],
    );
  }

  static pw.Widget _tableHeader(String text) {
    return _tableCell(text, isBold: true);
  }

  static pw.Widget _tableCell(
    String text, {
    bool alignLeft = false,
    bool isBold = false,
  }) {
    // Sanitization to prevent PDF font loading issues for curved apostrophes
    final sanitizedText = text.replaceAll('’', "'");

    return pw.Padding(
      padding: pw.EdgeInsets.all(5),
      child: pw.Text(
        sanitizedText,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: alignLeft ? pw.TextAlign.left : pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildAcademicSynthesis(
    Map<String, dynamic> stats,
    List<Map<String, dynamic>> mentions,
  ) {
    final double avg = (stats['average'] as num?)?.toDouble() ?? 0.0;
    final double passMark =
        (stats['moyenne_passage'] as num?)?.toDouble() ?? 10.0;
    final bool isAdmis = avg >= passMark;

    // Dynamic mention for final result
    String finalMention = '';
    if (mentions.isNotEmpty) {
      final m = MentionHelper.getMentionForGrade(avg, mentions);
      if (m != null) {
        finalMention = m['label'] ?? '';
      }
    }

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
          pw.SizedBox(height: 5),
          if (finalMention.isNotEmpty)
            _synthesisRow('Mention:', finalMention, isItalic: true),
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
                padding: pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: pw.BoxDecoration(color: PdfColors.black),
                child: pw.Text(
                  '${avg.toStringAsFixed(2)} / ${(stats['note_max'] as num?)?.toDouble().toStringAsFixed(0) ?? '20'}',
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
                padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
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
}
