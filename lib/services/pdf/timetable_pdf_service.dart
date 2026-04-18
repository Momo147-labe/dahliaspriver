import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/emploi_du_temps.dart';

class TimetablePdfService {
  Future<pw.Document> generateTimetablePdf(
    String className,
    List<EmploiDuTemps> entries,
  ) async {
    final pdf = pw.Document();

    final weekdays = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
    ];
    // Assuming school starts at 8h and ends at 18h
    const startHour = 8.0;
    const endHour = 18.0;
    const totalHours = endHour - startHour;

    const pageWidth = 842.0; // A4 landscape
    const pageHeight = 595.0; // A4 landscape
    const margin = 20.0;

    final workingWidth = pageWidth - (margin * 2);
    final workingHeight = pageHeight - (margin * 2);

    const timeColumnWidth = 60.0;
    const headerHeight = 35.0;

    final columnWidth = (workingWidth - timeColumnWidth) / weekdays.length;
    final pixelsPerHour = (workingHeight - headerHeight) / totalHours;

    // Convert time string "HH:MM" to absolute vertical Y position
    double timeToY(String time) {
      try {
        final parts = time.split(':');
        final hour = int.parse(parts[0]);
        final min = int.parse(parts[1]);
        double absoluteTime = hour + (min / 60.0);
        // Clamp absolute time within the visible area
        if (absoluteTime < startHour) absoluteTime = startHour;
        if (absoluteTime > endHour) absoluteTime = endHour;

        return (absoluteTime - startHour) * pixelsPerHour;
      } catch (e) {
        return 0;
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(margin),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // Main Border Background
              pw.Positioned.fill(
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    border: pw.Border.all(color: PdfColors.grey400, width: 1),
                  ),
                ),
              ),

              // Hourly Grid lines
              ...List.generate((totalHours + 1).toInt(), (index) {
                final y = headerHeight + (index * pixelsPerHour);
                return pw.Positioned(
                  left: timeColumnWidth,
                  top: y,
                  child: pw.Container(
                    width: workingWidth - timeColumnWidth,
                    height: 1,
                    color: PdfColors.grey300,
                  ),
                );
              }),

              // Time Labels (Left Column Background & Texts)
              pw.Positioned(
                left: 0,
                top: headerHeight,
                child: pw.Container(
                  width: timeColumnWidth,
                  height: workingHeight - headerHeight,
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#4A5320'),
                  ), // Olive Dark Green
                ),
              ),
              ...(() {
                final uniqueSlots = <String>{};
                for (var e in entries) {
                  if (e.heureDebut.isNotEmpty && e.heureFin.isNotEmpty) {
                    uniqueSlots.add('${e.heureDebut}-${e.heureFin}');
                  }
                }

                return uniqueSlots.map((slot) {
                  final parts = slot.split('-');
                  final start = parts[0];
                  final end = parts[1];

                  final yStart = headerHeight + timeToY(start);
                  final yEnd = headerHeight + timeToY(end);
                  final height = yEnd - yStart;

                  return pw.Positioned(
                    left: 0,
                    top: yStart,
                    child: pw.Container(
                      width: timeColumnWidth,
                      height: height,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: PdfColor.fromHex('#6E773D'),
                          width: 0.5,
                        ),
                      ),
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text(
                            start.replaceFirst(':', 'h'),
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            end.replaceFirst(':', 'h'),
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                });
              })(),

              // Day Headers (Top Row)
              ...List.generate(weekdays.length, (index) {
                return pw.Positioned(
                  left: timeColumnWidth + (index * columnWidth),
                  top: 0,
                  child: pw.Container(
                    width: columnWidth,
                    height: headerHeight,
                    alignment: pw.Alignment.center,
                    decoration: pw.BoxDecoration(
                      color: index % 2 == 0
                          ? PdfColor.fromHex('#4A6F28')
                          : PdfColor.fromHex(
                              '#C2B04E',
                            ), // Alternating Header Colors
                      border: pw.Border.all(color: PdfColors.white, width: 2),
                      boxShadow: const [
                        pw.BoxShadow(
                          color: PdfColors.grey500,
                          offset: PdfPoint(0, 2),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    margin: const pw.EdgeInsets.symmetric(horizontal: 2),
                    child: pw.Text(
                      weekdays[index].toUpperCase(),
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }),

              // Class blocks
              ...entries.map((entry) {
                if (entry.jourSemaine < 1 || entry.jourSemaine > 6)
                  return pw.SizedBox();

                final x =
                    timeColumnWidth + ((entry.jourSemaine - 1) * columnWidth);
                final yStart = headerHeight + timeToY(entry.heureDebut);
                final yEnd = headerHeight + timeToY(entry.heureFin);
                final height = yEnd - yStart;

                // Color picking (we can hash the subject name to get a consistent color)
                int colorIndex =
                    (entry.matiereNom?.length ?? 0) % _blockColors.length;
                PdfColor blockColor = _blockColors[colorIndex];

                return pw.Positioned(
                  left: x + 2,
                  top: yStart,
                  child: pw.Container(
                    width: columnWidth - 4,
                    height: height - 1.5, // Gap to avoid exact borders overlap
                    padding: const pw.EdgeInsets.all(4),
                    decoration: pw.BoxDecoration(
                      color: blockColor,
                      border: pw.Border.all(
                        color: PdfColors.grey100,
                        width: 0.5,
                      ),
                    ),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          entry.matiereNom ?? 'Matière',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11,
                            color: PdfColors.black,
                          ),
                          textAlign: pw.TextAlign.center,
                          maxLines: 2,
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '${entry.enseignantNomComplet}',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.black,
                          ),
                          textAlign: pw.TextAlign.center,
                          maxLines: 1,
                        ),
                        if (entry.salle != null && entry.salle!.isNotEmpty)
                          pw.Text(
                            'Salle: ${entry.salle}',
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.black,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),

              // Class Name title on top left
              pw.Positioned(
                left: 0,
                top: 0,
                child: pw.Container(
                  width: timeColumnWidth,
                  height: headerHeight,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#4A5320'), // Dark Olive
                    border: pw.Border.all(color: PdfColors.white, width: 2),
                    boxShadow: const [
                      pw.BoxShadow(
                        color: PdfColors.grey500,
                        offset: PdfPoint(0, 2),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        'CLASSE',
                        style: pw.TextStyle(
                          color: PdfColor.fromHex('#DCE775'),
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        className,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static const List<PdfColor> _blockColors = [
    PdfColor.fromInt(0xFFFFF59D), // Yellow 300
    PdfColor.fromInt(0xFFFFCC80), // Orange 200
    PdfColor.fromInt(0xFFCE93D8), // Purple 200
    PdfColor.fromInt(0xFFF48FB1), // Pink 200
    PdfColor.fromInt(0xFF90CAF9), // Blue 200
    PdfColor.fromInt(0xFFA5D6A7), // Green 200
    PdfColor.fromInt(0xFFB0BEC5), // Blue Grey 200
    PdfColor.fromInt(0xFFFFAB91), // Deep Orange 200
    PdfColor.fromInt(0xFF80CBC4), // Teal 200
    PdfColor.fromInt(0xFFE6EE9C), // Lime 200
  ];
}
