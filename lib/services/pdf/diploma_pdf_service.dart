import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_helper.dart';

class DiplomaPdfService {
  static Future<void> generateDiploma({
    required Map<String, dynamic> studentData,
    required String anneeScolaire,
    required String classeNom,
    double noteMax = 20.0,
  }) async {
    final pdf = pw.Document();

    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;
    final ecoleRows = await db.query('ecole', limit: 1);

    String ecoleNom = 'MON ÉCOLE';
    String ecoleDirecteur = 'Le Directeur';
    String ecoleFondateur = 'Le Fondateur';
    String ecoleAdresse = '';

    if (ecoleRows.isNotEmpty) {
      ecoleNom = ecoleRows.first['nom']?.toString().toUpperCase() ?? ecoleNom;
      ecoleDirecteur =
          ecoleRows.first['directeur']?.toString() ?? ecoleDirecteur;
      ecoleFondateur =
          ecoleRows.first['fondateur']?.toString() ?? ecoleFondateur;
      ecoleAdresse = ecoleRows.first['adresse']?.toString() ?? ecoleAdresse;
    }

    final rang = studentData['rang'] as int;
    final nom = studentData['nom']?.toString() ?? '';
    final prenom = studentData['prenom']?.toString() ?? '';
    final fullName = '$nom $prenom'.toUpperCase();

    final rangText = rang == 1 ? '1er' : '${rang}ème';

    // Premium Colors
    final navyBlue = PdfColor.fromHex('#0b3b60');
    final goldCol = PdfColor.fromHex('#d4af37');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(0),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // Background Artwork
              pw.Positioned.fill(
                child: pw.CustomPaint(
                  painter: (PdfGraphics canvas, PdfPoint size) {
                    final w = size.x;
                    final h = size.y;

                    // Borders
                    canvas.drawRect(0, 0, w, h);
                    canvas.setFillColor(PdfColors.white);
                    canvas.fillPath();

                    // Outer Border Frame
                    final margin = 20.0;
                    canvas.drawRect(
                      margin,
                      margin,
                      w - margin * 2,
                      h - margin * 2,
                    );
                    canvas.setStrokeColor(navyBlue);
                    canvas.setLineWidth(2);
                    canvas.strokePath();

                    double largeSize = 250;
                    double smallSize = 150;

                    // Corners Artwork
                    // Top Left
                    canvas.setFillColor(goldCol);
                    canvas.moveTo(0, 0);
                    canvas.lineTo(largeSize, 0);
                    canvas.lineTo(0, largeSize);
                    canvas.fillPath();
                    canvas.setFillColor(navyBlue);
                    canvas.moveTo(0, 0);
                    canvas.lineTo(smallSize, 0);
                    canvas.lineTo(0, smallSize);
                    canvas.fillPath();

                    // Top Right
                    canvas.setFillColor(goldCol);
                    canvas.moveTo(w, 0);
                    canvas.lineTo(w - largeSize, 0);
                    canvas.lineTo(w, largeSize);
                    canvas.fillPath();
                    canvas.setFillColor(navyBlue);
                    canvas.moveTo(w, 0);
                    canvas.lineTo(w - smallSize, 0);
                    canvas.lineTo(w, smallSize);
                    canvas.fillPath();

                    // Bottom Left
                    canvas.setFillColor(goldCol);
                    canvas.moveTo(0, h);
                    canvas.lineTo(largeSize, h);
                    canvas.lineTo(0, h - largeSize);
                    canvas.fillPath();
                    canvas.setFillColor(navyBlue);
                    canvas.moveTo(0, h);
                    canvas.lineTo(smallSize, h);
                    canvas.lineTo(0, h - smallSize);
                    canvas.fillPath();

                    // Bottom Right
                    canvas.setFillColor(goldCol);
                    canvas.moveTo(w, h);
                    canvas.lineTo(w - largeSize, h);
                    canvas.lineTo(w, h - largeSize);
                    canvas.fillPath();
                    canvas.setFillColor(navyBlue);
                    canvas.moveTo(w, h);
                    canvas.lineTo(w - smallSize, h);
                    canvas.lineTo(w, h - smallSize);
                    canvas.fillPath();
                  },
                ),
              ),

              // Top-Left Seal Decoration
              pw.Positioned(
                top: 50,
                left: 50,
                child: pw.Stack(
                  alignment: pw.Alignment.center,
                  children: [
                    pw.Container(
                      width: 50,
                      height: 100,
                      margin: const pw.EdgeInsets.only(top: 40),
                      child: pw.CustomPaint(
                        painter: (PdfGraphics canvas, PdfPoint size) {
                          canvas.setFillColor(goldCol);
                          canvas.moveTo(5, 0);
                          canvas.lineTo(20, size.y);
                          canvas.lineTo(10, size.y - 15);
                          canvas.lineTo(0, size.y);
                          canvas.fillPath();
                          canvas.moveTo(45, 0);
                          canvas.lineTo(50, size.y);
                          canvas.lineTo(40, size.y - 15);
                          canvas.lineTo(30, size.y);
                          canvas.fillPath();
                        },
                      ),
                    ),
                    pw.Container(
                      width: 100,
                      height: 100,
                      decoration: pw.BoxDecoration(
                        color: goldCol,
                        shape: pw.BoxShape.circle,
                        boxShadow: [
                          pw.BoxShadow(
                            color: PdfColors.black,
                            blurRadius: 10,
                            offset: const PdfPoint(0, 4),
                          ),
                        ],
                      ),
                      alignment: pw.Alignment.center,
                      child: pw.Container(
                        width: 80,
                        height: 80,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          border: pw.Border.all(
                            color: PdfColors.white,
                            style: pw.BorderStyle.dashed,
                            width: 2,
                          ),
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text(
                              'EXCELLENCE',
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              anneeScolaire.length >= 4
                                  ? anneeScolaire.substring(0, 4)
                                  : anneeScolaire,
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Main Content
              pw.Center(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Spacer(flex: 2),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Container(
                          width: 40,
                          height: 40,
                          decoration: pw.BoxDecoration(
                            color: navyBlue,
                            shape: pw.BoxShape.circle,
                          ),
                          alignment: pw.Alignment.center,
                          child: pw.Text(
                            ecoleNom.isNotEmpty
                                ? ecoleNom.substring(0, 1)
                                : "E",
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Text(
                          ecoleNom,
                          style: pw.TextStyle(
                            fontSize: 16,
                            color: navyBlue,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    if (ecoleAdresse.isNotEmpty)
                      pw.Text(
                        ecoleAdresse,
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),

                    pw.Spacer(flex: 1),
                    pw.Text(
                      "DIPLÔME D'EXCELLENCE",
                      style: pw.TextStyle(
                        fontSize: 36,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey900,
                        letterSpacing: 4.0,
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Text(
                      "Ceci certifie que",
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey800,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Text(
                      fullName,
                      style: pw.TextStyle(
                        fontSize: 32,
                        fontWeight: pw.FontWeight.bold,
                        color: navyBlue,
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 100),
                      child: pw.Text(
                        "A accompli avec succès l'année scolaire $anneeScolaire au sein de $ecoleNom en se classant $rangText de la classe $classeNom avec une moyenne de ${studentData['moyenne_generale']?.toStringAsFixed(2) ?? '0.00'}/${noteMax.toStringAsFixed(0)}, et se voit décerner ce DIPLÔME avec mention.",
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey800,
                          lineSpacing: 2.0,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 15),
                    pw.Text(
                      "$ecoleNom lui souhaite une excellente continuation !",
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey800,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 15),
                    pw.Text(
                      "Fait le ${DateFormat('dd MMMM yyyy', 'fr_FR').format(DateTime.now())}.",
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey700,
                      ),
                    ),

                    pw.Spacer(flex: 2),
                    pw.Container(
                      width: 600,
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Column(
                            children: [
                              pw.SizedBox(
                                width: 150,
                                child: pw.Divider(color: PdfColors.grey500),
                              ),
                              pw.SizedBox(height: 5),
                              pw.Text(
                                ecoleDirecteur,
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey800,
                                ),
                              ),
                              pw.Text(
                                "Le Directeur",
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.grey700,
                                ),
                              ),
                            ],
                          ),
                          pw.Column(
                            children: [
                              pw.SizedBox(
                                width: 150,
                                child: pw.Divider(color: PdfColors.grey500),
                              ),
                              pw.SizedBox(height: 5),
                              pw.Text(
                                ecoleFondateur,
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey800,
                                ),
                              ),
                              pw.Text(
                                "Le Fondateur",
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.grey700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.Spacer(flex: 1),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Diplome_${fullName.replaceAll(' ', '_')}.pdf',
    );
  }
}
