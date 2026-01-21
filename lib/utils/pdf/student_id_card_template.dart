import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class StudentIdCardTemplate {
  static Future<pw.Document> generate({
    required String schoolName,
    required String schoolCountry,
    required String academicYear,
    required String studentName,
    required String birthDate,
    required String className,
    required String studentId,
    String? studentPhotoPath,
    String? schoolLogoPath,
    String? parentName,
    String? parentPhone,
  }) async {
    final pdf = pw.Document();

    // Load images if available
    pw.ImageProvider? studentPhoto;
    pw.ImageProvider? schoolLogo;

    if (studentPhotoPath != null && File(studentPhotoPath).existsSync()) {
      final imageFile = File(studentPhotoPath);
      studentPhoto = pw.MemoryImage(imageFile.readAsBytesSync());
    }

    if (schoolLogoPath != null && File(schoolLogoPath).existsSync()) {
      final logoFile = File(schoolLogoPath);
      schoolLogo = pw.MemoryImage(logoFile.readAsBytesSync());
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
                color: PdfColors.white,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20)),
                border: pw.Border.all(color: PdfColors.grey300, width: 1),
              ),
              child: pw.Column(
                children: [
                  // Header with teal background
                  _buildHeader(
                    schoolCountry: schoolCountry,
                    schoolName: schoolName,
                    academicYear: academicYear,
                    schoolLogo: schoolLogo,
                  ),

                  // Main content area
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(20),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Student photo section
                          _buildPhotoSection(studentPhoto),

                          pw.SizedBox(width: 20),

                          // Student information section
                          pw.Expanded(
                            child: _buildStudentInfo(
                              studentName: studentName,
                              birthDate: birthDate,
                              className: className,
                              studentId: studentId,
                              parentName: parentName,
                              parentPhone: parentPhone,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Footer with stamp and signature placeholders
                  _buildFooter(),
                ],
              ),
            ),
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildHeader({
    required String schoolCountry,
    required String schoolName,
    required String academicYear,
    pw.ImageProvider? schoolLogo,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFF22C3C3), // Teal color
        borderRadius: pw.BorderRadius.only(
          topLeft: pw.Radius.circular(20),
          topRight: pw.Radius.circular(20),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              // School logo
              if (schoolLogo != null)
                pw.Container(
                  width: 50,
                  height: 50,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(10),
                    ),
                  ),
                  child: pw.Center(
                    child: pw.Image(schoolLogo, width: 40, height: 40),
                  ),
                )
              else
                pw.Container(
                  width: 50,
                  height: 50,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(10),
                    ),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'GE',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF22C3C3),
                      ),
                    ),
                  ),
                ),

              pw.SizedBox(width: 15),

              // School name
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    schoolCountry.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    schoolName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Academic year
          pw.Text(
            'ANNÉE $academicYear',
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPhotoSection(pw.ImageProvider? studentPhoto) {
    return pw.Container(
      width: 120,
      height: 160,
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFF8B6F5C), // Brown/burgundy
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(15)),
      ),
      child: studentPhoto != null
          ? pw.Image(studentPhoto, fit: pw.BoxFit.cover)
          : pw.Center(
              child: pw.Icon(
                const pw.IconData(0xe7fd), // person icon
                size: 60,
                color: PdfColors.white,
              ),
            ),
    );
  }

  static pw.Widget _buildStudentInfo({
    required String studentName,
    required String birthDate,
    required String className,
    required String studentId,
    String? parentName,
    String? parentPhone,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // "ÉLÈVE" label
        pw.Text(
          'ÉLÈVE',
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey600,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),

        pw.SizedBox(height: 8),

        // Student name
        pw.Text(
          studentName,
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),

        pw.SizedBox(height: 15),

        // Birth date
        pw.Text(
          'Né le: $birthDate',
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),

        pw.SizedBox(height: 5),

        // Class
        pw.Text(
          'Classe: $className',
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),

        pw.SizedBox(height: 5),

        // Student ID
        pw.Text(
          'ID: $studentId',
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),

        // Add spacing before parent info if available
        if (parentName != null || parentPhone != null) ...[
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(
                0xFFF0F9FF,
              ), // Light blue background
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (parentName != null)
                  pw.Row(
                    children: [
                      pw.Icon(
                        const pw.IconData(0xe7fd), // person icon
                        size: 12,
                        color: const PdfColor.fromInt(0xFF22C3C3),
                      ),
                      pw.SizedBox(width: 4),
                      pw.Text(
                        'Parent: $parentName',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey800,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                if (parentPhone != null) ...[
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.Icon(
                        const pw.IconData(0xe0cd), // phone icon
                        size: 12,
                        color: const PdfColor.fromInt(0xFF22C3C3),
                      ),
                      pw.SizedBox(width: 4),
                      pw.Text(
                        parentPhone,
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // School stamp placeholder
          pw.Container(
            width: 80,
            height: 80,
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFB8E6B8), // Light green
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            ),
          ),

          // Director signature placeholder
          pw.Column(
            children: [
              pw.Container(
                width: 60,
                height: 60,
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFB8D8E6), // Light blue
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'SCEAU DIRECTEUR',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
