import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class WithdrawalCardTemplate {
  static Future<pw.Document> generate({
    required String studentName,
    required String unitCode,
    required String authorizedParentName,
    required List<String> otherAuthorizedPersons,
    String? studentPhotoPath,
  }) async {
    final pdf = pw.Document();

    // Load student photo if available
    pw.ImageProvider? studentPhoto;
    if (studentPhotoPath != null && File(studentPhotoPath).existsSync()) {
      final imageFile = File(studentPhotoPath);
      studentPhoto = pw.MemoryImage(imageFile.readAsBytesSync());
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Center(
            child: pw.Container(
              width: 500,
              height: 300,
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFFFF8F0), // Light beige/cream
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20)),
                border: pw.Border.all(
                  color: const PdfColor.fromInt(0xFFFF9966), // Orange
                  width: 3,
                ),
              ),
              child: pw.Stack(
                children: [
                  // Orange circle decoration in top right
                  pw.Positioned(
                    top: -30,
                    right: -30,
                    child: pw.Container(
                      width: 100,
                      height: 100,
                      decoration: const pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFFFFB380), // Light orange
                        shape: pw.BoxShape.circle,
                      ),
                    ),
                  ),

                  // Main content
                  pw.Column(
                    children: [
                      // Header
                      _buildHeader(unitCode),

                      // Content area
                      pw.Expanded(
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(20),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              // Student photo section
                              _buildStudentPhotoSection(
                                studentPhoto,
                                studentName,
                              ),

                              pw.SizedBox(width: 20),

                              // Parent section
                              _buildParentSection(authorizedParentName),

                              pw.SizedBox(width: 20),

                              // Authorized persons list
                              pw.Expanded(
                                child: _buildAuthorizedPersonsList(
                                  otherAuthorizedPersons,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Footer
                      _buildFooter(),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildHeader(String unitCode) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'AUTORISATION DE RETRAIT',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFFFF4500), // Orange-red
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'SÉCURITÉ SCOLAIRE',
                style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
              ),
            ],
          ),

          // Unit code badge
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFF22C3C3), // Teal
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Text(
              'UNITÉ: $unitCode',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildStudentPhotoSection(
    pw.ImageProvider? studentPhoto,
    String studentName,
  ) {
    return pw.Column(
      children: [
        pw.Container(
          width: 100,
          height: 100,
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFFFE4CC), // Peach/beige
            shape: pw.BoxShape.circle,
          ),
          child: studentPhoto != null
              ? pw.Image(studentPhoto, fit: pw.BoxFit.cover)
              : pw.Center(
                  child: pw.Container(
                    width: 60,
                    height: 60,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(5),
                      ),
                    ),
                  ),
                ),
        ),

        pw.SizedBox(height: 10),

        pw.Text(
          'ÉLÈVE',
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey600,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildParentSection(String authorizedParentName) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Camera icon placeholder
        pw.Container(
          width: 80,
          height: 80,
          decoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFE8E8E8), // Light gray
            shape: pw.BoxShape.circle,
          ),
          child: pw.Center(
            child: pw.Icon(
              const pw.IconData(0xe3b0), // camera icon
              size: 35,
              color: PdfColors.grey400,
            ),
          ),
        ),

        pw.SizedBox(height: 15),

        // "PARENT AUTORISÉ" label
        pw.Text(
          'PARENT AUTORISÉ',
          style: pw.TextStyle(
            fontSize: 9,
            color: PdfColors.grey600,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1,
          ),
        ),

        pw.SizedBox(height: 5),

        // Parent name
        pw.Text(
          authorizedParentName,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildAuthorizedPersonsList(List<String> persons) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF5F5F5), // Very light gray
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'AUTRES PERSONNES AUTORISÉES:',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(height: 10),

          ...persons.map(
            (person) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Row(
                children: [
                  pw.Text(
                    '• ',
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.Text(
                    person,
                    style: const pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Cette carte doit être présentée à chaque sortie.',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
              fontStyle: pw.FontStyle.italic,
            ),
          ),

          // Colored dots
          pw.Row(
            children: [
              pw.Container(
                width: 15,
                height: 15,
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF22C3C3), // Teal
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Container(
                width: 15,
                height: 15,
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFFFB3BA), // Pink
                  shape: pw.BoxShape.circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
