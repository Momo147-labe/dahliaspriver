import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PaymentReceiptPdf {
  static Future<void> generateAndPrint({
    required Map<String, dynamic> transaction,
    required Map<String, double> financialStatus,
    required Map<String, dynamic> schoolInfo,
    Uint8List? schoolLogo,
    Uint8List? studentPhoto,
    required String anneeScolaire,
    required List<Map<String, dynamic>> history,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fontItalic = await PdfGoogleFonts.robotoItalic();

    // Configuration des couleurs du modèle
    final primaryBlue = PdfColor.fromHex('#0a3d54');
    final secondaryOrange = PdfColor.fromHex('#f5a623');

    DateTime date;
    try {
      date = DateTime.parse(
        transaction['date_paiement']?.toString() ??
            DateTime.now().toIso8601String(),
      );
    } catch (_) {
      date = DateTime.now();
    }
    final formattedDate = DateFormat('dd/MM/yyyy').format(date);
    final amount = (transaction['montant'] as num?)?.toDouble() ?? 0.0;
    final amountFormatted = NumberFormat('#,###', 'fr_FR').format(amount);
    final amountWords = _numberToWords(amount.toInt());

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          21.0 * PdfPageFormat.cm,
          10.5 * PdfPageFormat.cm,
          marginAll: 0,
        ),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // --- DÉCORATIONS D'ANGLES ---
              // Coin Haut Gauche (Bleu sombre)
              pw.Positioned(
                top: -45,
                left: -45,
                child: pw.Transform.rotate(
                  angle: math.pi / 4.5,
                  child: pw.Container(
                    width: 220,
                    height: 70,
                    color: primaryBlue,
                  ),
                ),
              ),
              // Coin Bas Gauche (Orange)
              pw.Positioned(
                bottom: -15,
                left: 0,
                child: pw.Container(
                  width: 120,
                  height: 12,
                  decoration: pw.BoxDecoration(
                    color: secondaryOrange,
                    borderRadius: const pw.BorderRadius.only(
                      topRight: pw.Radius.circular(15),
                    ),
                  ),
                ),
              ),
              // Coin Bas Droit (Bleu sombre et Orange)
              pw.Positioned(
                bottom: -45,
                right: -45,
                child: pw.Transform.rotate(
                  angle: math.pi / 4.5,
                  child: pw.Container(
                    width: 260,
                    height: 80,
                    color: primaryBlue,
                  ),
                ),
              ),
              pw.Positioned(
                bottom: 5,
                right: 100,
                child: pw.Transform.rotate(
                  angle: math.pi / 4.5,
                  child: pw.Container(
                    width: 160,
                    height: 25,
                    color: secondaryOrange,
                  ),
                ),
              ),
              // Rappel orange en haut à droite
              pw.Positioned(
                top: 0,
                right: 0,
                child: pw.Container(
                  width: 280,
                  height: 30,
                  color: secondaryOrange,
                ),
              ),

              // --- CONTENU PRINCIPAL ---
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 35,
                  vertical: 15,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // 1. EN-TÊTE TRIPARTITE
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // GAUCHE : LOGO ET SLOGAN
                        pw.Expanded(
                          flex: 1,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              if (schoolLogo != null)
                                pw.Container(
                                  width: 50,
                                  height: 50,
                                  child: pw.Image(pw.MemoryImage(schoolLogo)),
                                )
                              else
                                pw.Container(
                                  width: 50,
                                  height: 50,
                                  color: PdfColors.grey200,
                                  child: pw.Center(
                                    child: pw.Text(
                                      'LOGO',
                                      style: const pw.TextStyle(fontSize: 8),
                                    ),
                                  ),
                                ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                schoolInfo['slogan'] ?? 'EXCELLENCE & SAVOIR',
                                style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 7,
                                  color: PdfColors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // CENTRE : TITRE ET CONTACTS
                        pw.Expanded(
                          flex: 2,
                          child: pw.Column(
                            children: [
                              pw.Text(
                                'REÇU DE PAIEMENT',
                                style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 20,
                                  color: primaryBlue,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                children: [
                                  pw.Text(
                                    'Tél: ${schoolInfo['telephone'] ?? '0000-000000'}',
                                    style: pw.TextStyle(
                                      font: font,
                                      fontSize: 8,
                                      color: primaryBlue,
                                    ),
                                  ),
                                  pw.SizedBox(width: 10),
                                  pw.Text(
                                    'Email: ${schoolInfo['email'] ?? 'contact@ecole.gn'}',
                                    style: pw.TextStyle(
                                      font: font,
                                      fontSize: 8,
                                      color: primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // DROITE : INFOS ÉCOLE
                        pw.Expanded(
                          flex: 1,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                (schoolInfo['nom'] ?? 'NOM DE L\'ÉCOLE')
                                    .toUpperCase(),
                                style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 8,
                                  color: PdfColors.black,
                                ),
                                textAlign: pw.TextAlign.right,
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                schoolInfo['adresse'] ??
                                    'Adresse de l\'établissement, Guinée',
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 7,
                                  color: PdfColors.black,
                                ),
                                textAlign: pw.TextAlign.right,
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 10),

                    // 2. N° ET DATE
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _buildLinedField(
                          'N°',
                          (transaction['numero_recu'] ??
                                  transaction['id'].toString().padLeft(4, '0'))
                              .toString(),
                          font,
                          fontBold,
                          width: 130,
                        ),
                        _buildLinedField(
                          'Date',
                          formattedDate,
                          font,
                          fontBold,
                          width: 130,
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 8),

                    // 3. CHAMPS DU REÇU
                    _buildLinedField(
                      'Reçu avec remerciements de',
                      '${transaction['eleve_prenom']} ${transaction['eleve_nom']}'
                          .toUpperCase(),
                      font,
                      fontBold,
                    ),
                    pw.SizedBox(height: 6),
                    _buildLinedField(
                      'Montant',
                      '$amountFormatted GNF',
                      font,
                      fontBold,
                    ),
                    pw.SizedBox(height: 6),
                    _buildLinedField(
                      'En toutes lettres',
                      amountWords.toUpperCase() + ' GNF',
                      font,
                      fontItalic,
                      fontSize: 9,
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: _buildLinedField(
                            'Pour',
                            transaction['motif'] ?? 'Frais de Scolarité',
                            font,
                            fontBold,
                          ),
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 10),

                    // 4. RÉCAPITULATIF FINANCIER ET SIGNATURES
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        // Bloc financier (COMPTE, PAYÉ, DU)
                        pw.Expanded(
                          flex: 4,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Row(
                                mainAxisAlignment:
                                    pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildSimpleCol(
                                    'COMPTE',
                                    NumberFormat(
                                      '#,###',
                                      'fr_FR',
                                    ).format(financialStatus['totalExpected']),
                                    font,
                                    fontBold,
                                  ),
                                  _buildSimpleCol(
                                    'PAYÉ',
                                    NumberFormat(
                                      '#,###',
                                      'fr_FR',
                                    ).format(financialStatus['totalPaid']),
                                    font,
                                    fontBold,
                                  ),
                                  _buildSimpleCol(
                                    'DU (RESTE)',
                                    NumberFormat(
                                      '#,###',
                                      'fr_FR',
                                    ).format(financialStatus['balance']),
                                    font,
                                    fontBold,
                                  ),
                                ],
                              ),
                              pw.SizedBox(height: 8),
                              // Encadré Montant=
                              pw.Row(
                                children: [
                                  pw.Text(
                                    'Montant = ',
                                    style: pw.TextStyle(
                                      font: fontBold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: pw.BoxDecoration(
                                      border: pw.Border.all(
                                        color: PdfColors.black,
                                        width: 1,
                                      ),
                                    ),
                                    child: pw.Text(
                                      '$amountFormatted GNF',
                                      style: pw.TextStyle(
                                        font: fontBold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 30),
                        // Signatures
                        pw.Expanded(
                          flex: 3,
                          child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Column(
                                children: [
                                  pw.Text(
                                    (transaction['agent_nom'] ??
                                            transaction['agent_pseudo'] ??
                                            'Administrateur')
                                        .toString()
                                        .toUpperCase(),
                                    style: pw.TextStyle(
                                      font: fontBold,
                                      fontSize: 8,
                                    ),
                                  ),
                                  _buildDottedLine(70),
                                  pw.Text(
                                    'Reçu par',
                                    style: pw.TextStyle(
                                      font: font,
                                      fontSize: 8,
                                    ),
                                  ),
                                ],
                              ),
                              pw.Column(
                                children: [
                                  _buildDottedLine(90),
                                  pw.Text(
                                    'Signature Autorisée',
                                    style: pw.TextStyle(
                                      font: font,
                                      fontSize: 8,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
      name: 'Recu_${transaction['eleve_nom']}_$formattedDate',
    );
  }

  // Helper pour les champs avec lignes pointillées
  static pw.Widget _buildLinedField(
    String label,
    String value,
    pw.Font font,
    pw.Font fontBold, {
    double? width,
    double fontSize = 10,
  }) {
    return pw.Container(
      width: width,
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            '$label ',
            style: pw.TextStyle(font: font, fontSize: fontSize),
          ),
          pw.Expanded(
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(style: pw.BorderStyle.dotted, width: 1),
                ),
              ),
              padding: const pw.EdgeInsets.only(bottom: 1, left: 3),
              child: pw.Text(
                value,
                style: pw.TextStyle(font: fontBold, fontSize: fontSize),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSimpleCol(
    String label,
    String value,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 8,
            color: PdfColors.grey700,
          ),
        ),
        pw.Container(
          width: 70,
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(style: pw.BorderStyle.dotted, width: 1),
            ),
          ),
          child: pw.Text(
            value,
            style: pw.TextStyle(font: fontBold, fontSize: 10),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildDottedLine(double width) {
    return pw.Container(
      width: width,
      margin: const pw.EdgeInsets.only(bottom: 3),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(style: pw.BorderStyle.dotted, width: 1),
        ),
      ),
    );
  }

  // --- LOGIQUE CONVERSION CHIFFRES EN LETTRES (FRANÇAIS) ---
  static String _numberToWords(int number) {
    if (number == 0) return "zéro";

    final List<String> units = [
      "",
      "un",
      "deux",
      "trois",
      "quatre",
      "cinq",
      "six",
      "sept",
      "huit",
      "neuf",
    ];
    final List<String> teens = [
      "dix",
      "onze",
      "douze",
      "treize",
      "quatorze",
      "quinze",
      "seize",
      "dix-sept",
      "dix-huit",
      "dix-neuf",
    ];
    final List<String> tens = [
      "",
      "dix",
      "vingt",
      "trente",
      "quarante",
      "cinquante",
      "soixante",
      "soixante-dix",
      "quatre-vingt",
      "quatre-vingt-dix",
    ];

    String convert(int n) {
      if (n < 10) return units[n];
      if (n < 20) return teens[n - 10];
      if (n < 100) {
        int t = n ~/ 10;
        int u = n % 10;
        if (t == 7 || t == 9) {
          return tens[t - 1] + "-" + convert(u + 10);
        }
        if (u == 0) return tens[t];
        if (u == 1 && t != 8) return tens[t] + " et un";
        return tens[t] + "-" + units[u];
      }
      if (n < 1000) {
        int h = n ~/ 100;
        int r = n % 100;
        String s = (h == 1) ? "cent" : units[h] + " cent";
        if (r == 0) return (h > 1) ? s + "s" : s;
        return s + " " + convert(r);
      }
      if (n < 1000000) {
        int k = n ~/ 1000;
        int r = n % 1000;
        String s = (k == 1) ? "mille" : convert(k) + " mille";
        if (r == 0) return s;
        return s + " " + convert(r);
      }
      if (n < 1000000000) {
        int m = n ~/ 1000000;
        int r = n % 1000000;
        String s = (m == 1) ? "un million" : convert(m) + " millions";
        if (r == 0) return s;
        return s + " " + convert(r);
      }
      return n.toString();
    }

    return convert(number);
  }
}
