import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/student.dart';
import '../../models/ecole.dart';

class StudentCardPdfService {
  static const double cardWidth = 280.0;
  static const double cardHeight = 200.0;

  static Future<void> generateAndPrintBulk({
    required List<Student> students,
    required Ecole? ecole,
    required String? anneeLibelle,
  }) async {
    final doc = pw.Document();

    pw.ImageProvider? logoProvider;
    pw.ImageProvider? timbreProvider;

    if (ecole != null) {
      if (ecole.logo != null && ecole.logo!.isNotEmpty) {
        final logoFile = File(ecole.logo!);
        if (logoFile.existsSync()) {
          logoProvider = pw.MemoryImage(logoFile.readAsBytesSync());
        }
      }
      if (ecole.timbre != null && ecole.timbre!.isNotEmpty) {
        final timbreFile = File(ecole.timbre!);
        if (timbreFile.existsSync()) {
          timbreProvider = pw.MemoryImage(timbreFile.readAsBytesSync());
        }
      }
    }

    for (var i = 0; i < students.length; i += 8) {
      final chunk = students.sublist(
        i,
        i + 8 > students.length ? students.length : i + 8,
      );

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          build: (context) {
            return pw.Wrap(
              spacing: 12,
              runSpacing: 8,
              children: chunk
                  .map(
                    (s) => _buildCard(
                      s,
                      ecole,
                      anneeLibelle,
                      logoProvider,
                      timbreProvider,
                    ),
                  )
                  .toList(),
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Cartes_Scolaires_En_Serie.pdf',
    );
  }

  static Future<void> generateAndPrintSingle({
    required Student student,
    required Ecole? ecole,
    required String? anneeLibelle,
  }) async {
    final doc = pw.Document();

    pw.ImageProvider? logoProvider;
    pw.ImageProvider? timbreProvider;

    if (ecole != null) {
      if (ecole.logo != null && ecole.logo!.isNotEmpty) {
        final logoFile = File(ecole.logo!);
        if (logoFile.existsSync()) {
          logoProvider = pw.MemoryImage(logoFile.readAsBytesSync());
        }
      }
      if (ecole.timbre != null && ecole.timbre!.isNotEmpty) {
        final timbreFile = File(ecole.timbre!);
        if (timbreFile.existsSync()) {
          timbreProvider = pw.MemoryImage(timbreFile.readAsBytesSync());
        }
      }
    }

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(cardWidth + 40, cardHeight + 40),
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return _buildCard(
            student,
            ecole,
            anneeLibelle,
            logoProvider,
            timbreProvider,
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Carte_Scolaire_${student.matricule}.pdf',
    );
  }

  static pw.Widget _buildCard(
    Student student,
    Ecole? ecole,
    String? anneeLibelle,
    pw.ImageProvider? logo,
    pw.ImageProvider? timbre,
  ) {
    // PDF colors
    final blueColor = PdfColor.fromInt(0xFF002D62);
    final redColor = PdfColor.fromInt(0xFFCE1126);
    final yellowColor = PdfColor.fromInt(0xFFFCD116);
    final greenColor = PdfColor.fromInt(0xFF009460);
    final bgColor = PdfColor.fromInt(0xFFE8F4F8);

    pw.ImageProvider? photo;
    if (student.photo.isNotEmpty && File(student.photo).existsSync()) {
      photo = pw.MemoryImage(File(student.photo).readAsBytesSync());
    }

    return pw.Container(
      width: cardWidth,
      height: cardHeight,
      decoration: pw.BoxDecoration(
        color: bgColor,
        border: pw.Border.all(color: PdfColors.grey300, width: 1.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Stack(
        children: [
          // Blue vertical stripe on the left
          pw.Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: pw.Container(
              width: 8,
              decoration: pw.BoxDecoration(
                color: blueColor,
                borderRadius: const pw.BorderRadius.only(
                  topLeft: pw.Radius.circular(8),
                  bottomLeft: pw.Radius.circular(8),
                ),
              ),
            ),
          ),

          // Red footer
          pw.Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: pw.Container(
              height: 35,
              decoration: pw.BoxDecoration(
                color: redColor,
                borderRadius: const pw.BorderRadius.only(
                  bottomLeft: pw.Radius.circular(8),
                  bottomRight: pw.Radius.circular(8),
                ),
              ),
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    ecole?.nom.toUpperCase() ?? 'NOM DE L\'ÉCOLE',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    ecole?.slogan?.isNotEmpty == true
                        ? ecole!.slogan!.toUpperCase()
                        : 'DISCIPLINE - TRAVAIL - PROGRÈS',
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 6),
                  ),
                ],
              ),
            ),
          ),

          // Ministry logo (top left)
          if (logo != null)
            pw.Positioned(
              top: 8,
              left: 14,
              child: pw.Container(
                width: 45,
                height: 45,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  color: PdfColors.white,
                  border: pw.Border.all(color: blueColor, width: 1.5),
                ),
                child: pw.ClipOval(child: pw.Image(logo, fit: pw.BoxFit.cover)),
              ),
            ),

          // Guinea flag (top right)
          pw.Positioned(
            top: 8,
            right: 12,
            child: pw.Container(
              width: 40,
              height: 28,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(child: pw.Container(color: redColor)),
                  pw.Expanded(child: pw.Container(color: yellowColor)),
                  pw.Expanded(child: pw.Container(color: greenColor)),
                ],
              ),
            ),
          ),

          // Header text
          pw.Positioned(
            top: 10,
            left: 70,
            right: 60,
            child: pw.Column(
              children: [
                pw.Text(
                  'République de Guinée',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Text(
                  'Travail-Justice-Solidarité',
                  style: pw.TextStyle(
                    fontSize: 6,
                    fontStyle: pw.FontStyle.italic,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Ministère de l\'enseignement \n pré-universitaire et de l\'alphabétisation',
                  style: const pw.TextStyle(fontSize: 7),
                  textAlign: pw.TextAlign.center,
                  maxLines: 2,
                ),
              ],
            ),
          ),

          // Banner
          pw.Positioned(
            top: 55,
            left: 12,
            right: 12,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 2,
                horizontal: 8,
              ),
              decoration: pw.BoxDecoration(
                color: redColor,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.Text(
                'CARTE D\'IDENTITÉ SCOLAIRE',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ),

          // Academic year badge
          pw.Positioned(
            top: 75,
            left: 83,
            child: pw.Text(
              'ANNÉE SCOLAIRE ${anneeLibelle ?? '2023-2024'}',
              style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
            ),
          ),

          // Student photo
          pw.Positioned(
            top: 75,
            left: 12,
            child: pw.Container(
              width: 65,
              height: 75,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: blueColor, width: 1.5),
                color: PdfColors.grey200,
              ),
              child: photo != null
                  ? pw.Image(photo, fit: pw.BoxFit.cover)
                  : pw.Center(child: pw.PdfLogo()), // Placeholder if no photo
            ),
          ),

          // Student information
          pw.Positioned(
            top: 85,
            left: 85,
            right: 8,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Matricule:', student.matricule),
                _buildInfoRow(
                  'Nom et Prénom:',
                  student.fullName.toUpperCase(),
                  isBold: true,
                ),
                _buildInfoRow('Date de Naiss. :', student.dateNaissance),
                _buildInfoRow('Lieu de Naiss.:', student.lieuNaissance),
                _buildInfoRow('Sexe:', student.sexe == 'M' ? 'Homme' : 'Femme'),
                _buildInfoRow('Classe:', student.classe),
                if (student.contactUrgence != null &&
                    student.contactUrgence!.isNotEmpty)
                  _buildInfoRow(
                    'Urgence:',
                    '${student.personneAPrevenir ?? ''} ${student.contactUrgence ?? ''}',
                  ),
              ],
            ),
          ),

          // Stamp
          if (timbre != null)
            pw.Positioned(
              top: 120,
              left: 25,
              child: pw.Opacity(
                opacity: 0.6,
                child: pw.Container(
                  width: 35,
                  height: 35,
                  child: pw.Image(timbre, fit: pw.BoxFit.cover),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoRow(
    String label,
    String value, {
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1),
      child: pw.RichText(
        text: pw.TextSpan(
          style: const pw.TextStyle(fontSize: 6, color: PdfColors.black),
          children: [
            pw.TextSpan(
              text: '$label ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.TextSpan(
              text: value,
              style: pw.TextStyle(
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
