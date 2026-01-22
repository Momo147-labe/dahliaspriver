import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/ecole.dart';

class GradeSheetPdfHelper {
  static Future<pw.Document> generate({
    required Ecole? ecole,
    required String className,
    required String subjectName,
    required String sequence,
    required String annee,
    required List<Map<String, dynamic>> students,
  }) async {
    final pdf = pw.Document();

    final logoPath = ecole?.logo;
    pw.MemoryImage? logoImage;
    if (logoPath != null && File(logoPath).existsSync()) {
      logoImage = pw.MemoryImage(File(logoPath).readAsBytesSync());
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(logoImage, ecole, annee),
            pw.SizedBox(height: 20),
            _buildTitle(className, subjectName, sequence),
            pw.SizedBox(height: 20),
            _buildStudentsTable(students),
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
    String sequence,
  ) {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.Text(
            'FICHE DE SAISIE DE NOTES (MANUELLE)',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              decoration: pw.TextDecoration.underline,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'CLASSE: $className | MATIÈRE: $subjectName | SÉQUENCE: $sequence',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildStudentsTable(List<Map<String, dynamic>> students) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(30), // #
        1: const pw.FixedColumnWidth(100), // Matricule
        2: const pw.FlexColumnWidth(3), // Nom & Prénom
        3: const pw.FixedColumnWidth(60), // Note
        4: const pw.FlexColumnWidth(2), // Observations
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tableHeader('N°'),
            _tableHeader('Matricule'),
            _tableHeader('Nom & Prénoms'),
            _tableHeader('Note /20'),
            _tableHeader('Observations'),
          ],
        ),
        // Rows
        ...List.generate(students.length, (index) {
          final s = students[index];
          return pw.TableRow(
            children: [
              _tableCell((index + 1).toString()),
              _tableCell(s['matricule'] ?? ''),
              _tableCell(
                '${s['nom']} ${s['prenom']}'.toUpperCase(),
                alignLeft: true,
              ),
              _tableCell(''), // Empty for manual entry
              _tableCell(''), // Empty for manual entry
            ],
          );
        }),
      ],
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
