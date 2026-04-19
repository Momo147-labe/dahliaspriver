import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/ecole.dart';

class GradeBlankSheetPdfHelper {
  static Future<pw.Document> generate({
    required Ecole? ecole,
    required String className,
    required String subjectName,
    required String teacherName,
    required String trimestre,
    required String annee,
    required List<Map<String, dynamic>> students,
    required List<Map<String, dynamic>> sequences,
  }) async {
    final pdf = pw.Document();

    final logoPath = ecole?.logo;
    pw.MemoryImage? logoImage;
    if (logoPath != null && File(logoPath).existsSync()) {
      try {
        logoImage = pw.MemoryImage(File(logoPath).readAsBytesSync());
      } catch (e) {
        // Ignorer l'erreur si l'image ne peut pas être chargée
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(logoImage, ecole, annee),
            pw.SizedBox(height: 20),
            _buildTitle(className, subjectName, teacherName, trimestre),
            pw.SizedBox(height: 20),
            _buildStudentsTable(students, sequences),
            pw.SizedBox(height: 30),
            _buildSignatures(),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Page ${context.pageNumber} sur ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
            ),
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildHeader(
    pw.MemoryImage? logo,
    Ecole? ecole,
    String annee,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'RÉPUBLIQUE DE GUINÉE',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'TRAVAIL - JUSTICE - SOLIDARITÉ',
              style: const pw.TextStyle(fontSize: 7),
            ),
            pw.SizedBox(height: 5),
            if (logo != null)
              pw.Container(width: 40, height: 40, child: pw.Image(logo)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              ecole?.nom.toUpperCase() ?? 'GROUPE SCOLAIRE',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              ecole?.adresse ?? '',
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Text(
              'Année Scolaire: $annee',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildTitle(
    String className,
    String subjectName,
    String teacherName,
    String trimestre,
  ) {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.Text(
            'FICHE DE SAISIE DE NOTES (VIERGE)',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              decoration: pw.TextDecoration.underline,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'TRIMESTRE: $trimestre | CLASSE: $className | MATIÈRE: $subjectName',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Enseignant: $teacherName',
            style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildStudentsTable(
    List<Map<String, dynamic>> students,
    List<Map<String, dynamic>> sequences,
  ) {
    final Map<int, pw.TableColumnWidth> columnWidths = {
      0: const pw.FixedColumnWidth(30), // N°
      1: const pw.FixedColumnWidth(80), // Matricule
      2: const pw.FlexColumnWidth(3), // Nom & Prénoms
    };

    int colIndex = 3;
    for (int i = 0; i < sequences.length; i++) {
      columnWidths[colIndex] = const pw.FixedColumnWidth(50);
      colIndex++;
    }
    columnWidths[colIndex] = const pw.FlexColumnWidth(2); // Observations

    final List<pw.Widget> headers = [
      _tableHeader('N°'),
      _tableHeader('Matricule'),
      _tableHeader('Nom & Prénoms'),
    ];
    for (var seq in sequences) {
      headers.add(_tableHeader(seq['nom'] ?? 'Seq'));
    }
    headers.add(_tableHeader('Observations'));

    final pw.TableRow headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: headers,
    );

    // Rows
    final List<pw.TableRow> rows = [headerRow];
    for (int i = 0; i < students.length; i++) {
      final s = students[i];
      final List<pw.Widget> cells = [
        _tableCell((i + 1).toString()),
        _tableCell(s['matricule'] ?? ''),
        _tableCell('${s['nom']} ${s['prenom']}'.toUpperCase(), alignLeft: true),
      ];
      // blank cols for sequences
      for (int k = 0; k < sequences.length; k++) {
        cells.add(_tableCell(''));
      }
      cells.add(_tableCell('')); // Observations

      rows.add(pw.TableRow(children: cells));
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: columnWidths,
      children: rows,
    );
  }

  static pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _tableCell(String text, {bool alignLeft = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9),
        textAlign: alignLeft ? pw.TextAlign.left : pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildSignatures() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          children: [
            pw.Text(
              'L\'Enseignant',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 40),
            pw.Container(
              width: 100,
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
              ),
            ),
          ],
        ),
        pw.Column(
          children: [
            pw.Text(
              'Le Censeur / Surveillant',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 40),
            pw.Container(
              width: 100,
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
              ),
            ),
          ],
        ),
        pw.Column(
          children: [
            pw.Text(
              'La Direction',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 40),
            pw.Container(
              width: 100,
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
