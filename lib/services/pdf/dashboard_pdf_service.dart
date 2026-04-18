import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_helper.dart';

class DashboardPdfService {
  static final _currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'GNF',
    decimalDigits: 0,
  );

  static const List<PdfColor> _chartColors = [
    PdfColors.indigo400,
    PdfColors.orange400,
    PdfColors.green400,
    PdfColors.purple400,
    PdfColors.teal400,
    PdfColors.red400,
    PdfColors.cyan400,
  ];

  // ─── Entry Point ────────────────────────────────────────────────────────────

  static Future<void> generateDashboardReport(
    Map<String, dynamic> stats,
  ) async {
    final pdf = pw.Document();

    Map<String, dynamic>? schoolData;
    try {
      final appDb = await DatabaseHelper.instance.database;
      final schools = await appDb.query('ecole', limit: 1);
      if (schools.isNotEmpty) schoolData = schools.first;
    } catch (_) {}

    final financial = Map<String, dynamic>.from(stats['financial'] ?? {});
    final recoveryRate = (financial['recoveryRate'] as num?)?.toDouble() ?? 0.0;
    final collected = (financial['collected'] as num?)?.toDouble() ?? 0.0;
    final remaining = (financial['remaining'] as num?)?.toDouble() ?? 0.0;
    final thisMonth = financial['thisMonth'] ?? 0;
    final growth = (financial['growth'] as num?)?.toDouble() ?? 0.0;

    final genderStats = List<Map<String, dynamic>>.from(
      stats['genderStats'] ?? [],
    );
    final cycleStats = List<Map<String, dynamic>>.from(
      stats['cycleStats'] ?? [],
    );
    final classStats = List<Map<String, dynamic>>.from(
      stats['classStats'] ?? [],
    );
    final monthlyStats = List<Map<String, dynamic>>.from(
      stats['paymentMonthlyStats'] ?? [],
    );
    final recentPays = List<Map<String, dynamic>>.from(
      stats['recentPayments'] ?? [],
    );

    final chronoMonthly = monthlyStats.reversed.toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        build: (pw.Context ctx) => [
          // Header
          _schoolHeader(schoolData),
          pw.SizedBox(height: 8),
          _pageTitle('Rapport du Tableau de Bord Global'),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 16),

          // ── 1. Stats générales ──────────────────────────────────────────────
          _sectionTitle('1. Statistiques Générales'),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
            },
            children: [
              _tableRow(['Indicateur', 'Valeur'], header: true),
              _tableRow([
                'Effectif total (Élèves)',
                '${stats['students'] ?? 0}',
              ]),
              _tableRow([
                'Personnel (Enseignants & Staff)',
                '${stats['teachers'] ?? 0}',
              ]),
              _tableRow([
                'Taux de recouvrement global',
                '${recoveryRate.toStringAsFixed(1)} %',
              ]),
              _tableRow([
                'Collecte ce mois-ci',
                _currencyFormat.format(thisMonth),
              ]),
              _tableRow([
                'Croissance vs mois précédent',
                '${growth >= 0 ? '+' : ''}${growth.toStringAsFixed(1)} %',
              ]),
              _tableRow(['Total perçu', _currencyFormat.format(collected)]),
              _tableRow([
                'Total impayé restant',
                _currencyFormat.format(remaining),
              ]),
              _tableRow([
                'Moyenne Générale (École)',
                '${(stats['academic']?['average'] as num?)?.toStringAsFixed(2) ?? '0.00'}/20',
              ]),
              _tableRow([
                'Taux de Réussite Global',
                '${(stats['academic']?['successRate'] as num?)?.toStringAsFixed(1) ?? '0.0'} %',
              ]),
            ],
          ),
          pw.SizedBox(height: 24),

          // ── 2. Répartition par Sexe + Cycle (côte à côte) ──────────────────
          _sectionTitle('2. Répartitions (Sexe & Cycle)'),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Par Sexe',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    if (genderStats.isNotEmpty) ...[
                      _pieChart(
                        data: genderStats
                            .map((e) => (e['count'] as num).toDouble())
                            .toList(),
                        labels: genderStats
                            .map((e) => e['sexe'] == 'M' ? 'Garçons' : 'Filles')
                            .toList(),
                        size: 120,
                      ),
                      pw.SizedBox(height: 6),
                      _legend(
                        labels: genderStats
                            .map((e) => e['sexe'] == 'M' ? 'Garçons' : 'Filles')
                            .toList(),
                        values: genderStats
                            .map((e) => '${e['count']}')
                            .toList(),
                      ),
                    ] else
                      pw.Text(
                        'Pas de données',
                        style: const pw.TextStyle(color: PdfColors.grey),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Par Cycle',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    if (cycleStats.isNotEmpty) ...[
                      _pieChart(
                        data: cycleStats
                            .map((e) => (e['count'] as num).toDouble())
                            .toList(),
                        labels: cycleStats
                            .map((e) => '${e['cycle'] ?? 'N/A'}')
                            .toList(),
                        size: 120,
                      ),
                      pw.SizedBox(height: 6),
                      _legend(
                        labels: cycleStats
                            .map((e) => '${e['cycle'] ?? 'N/A'}')
                            .toList(),
                        values: cycleStats.map((e) => '${e['count']}').toList(),
                      ),
                    ] else
                      pw.Text(
                        'Pas de données',
                        style: const pw.TextStyle(color: PdfColors.grey),
                      ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 24),

          // ── 3. Situation Financière (Pie) ───────────────────────────────────
          _sectionTitle('3. Situation Financière (Payé / Impayé)'),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              _pieChart(
                data: [collected, remaining],
                labels: ['Payé', 'Impayé'],
                size: 130,
                colors: [PdfColors.green400, PdfColors.red400],
              ),
              pw.SizedBox(width: 24),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _legendItem(
                    'Payé',
                    _currencyFormat.format(collected),
                    PdfColors.green400,
                  ),
                  pw.SizedBox(height: 6),
                  _legendItem(
                    'Impayé',
                    _currencyFormat.format(remaining),
                    PdfColors.red400,
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    collected + remaining > 0
                        ? 'Taux : ${((collected / (collected + remaining)) * 100).toStringAsFixed(1)} %'
                        : 'Taux : — %',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 24),

          // ── 4. Effectif par Classe (Bar chart) ──────────────────────────────
          if (classStats.isNotEmpty) ...[
            _sectionTitle('4. Effectif par Classe'),
            pw.SizedBox(height: 8),
            _barChart(
              labels: classStats.map((e) => '${e['nom'] ?? '?'}').toList(),
              values: classStats
                  .map((e) => (e['count'] as num).toDouble())
                  .toList(),
              height: 180,
            ),
            pw.SizedBox(height: 24),
          ],

          // ── 5. Tendance des Paiements Mensuels (Line chart) ─────────────────
          if (chronoMonthly.isNotEmpty) ...[
            _sectionTitle('5. Tendance des Paiements Mensuels'),
            pw.SizedBox(height: 8),
            _lineChart(
              labels: chronoMonthly.map((e) => '${e['month'] ?? ''}').toList(),
              values: chronoMonthly
                  .map((e) => (e['total'] as num?)?.toDouble() ?? 0.0)
                  .toList(),
              height: 160,
            ),
            pw.SizedBox(height: 24),
          ],

          // ── 6. Paiements Récents ─────────────────────────────────────────────
          if (recentPays.isNotEmpty) ...[
            _sectionTitle('6. Paiements Récents (20 derniers)'),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
              },
              children: [
                _tableRow(['Élève', 'Montant', 'Date'], header: true),
                ...recentPays.take(20).map((e) {
                  final nom = '${e['prenom'] ?? ''} ${e['nom'] ?? ''}'.trim();
                  final montant = _currencyFormat.format(e['montant'] ?? 0);
                  final date = e['date_paiement'] != null
                      ? DateFormat('dd/MM/yyyy').format(
                          DateTime.tryParse(e['date_paiement'].toString()) ??
                              DateTime.now(),
                        )
                      : 'N/A';
                  return _tableRow([nom, montant, date]);
                }),
              ],
            ),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Rapport_TableauDeBord.pdf',
    );
  }

  // ─── Chart Widgets ──────────────────────────────────────────────────────────

  /// Draws a simple pie/donut chart using canvas arcs
  static pw.Widget _pieChart({
    required List<double> data,
    required List<String> labels,
    double size = 120,
    List<PdfColor>? colors,
  }) {
    final total = data.fold(0.0, (a, b) => a + b);
    if (total == 0) return pw.SizedBox(height: size);
    final palette = colors ?? _chartColors;

    return pw.SizedBox(
      width: size,
      height: size,
      child: pw.CustomPaint(
        painter: (PdfGraphics canvas, PdfPoint s) {
          final cx = s.x / 2;
          final cy = s.y / 2;
          final r = min(cx, cy) * 0.9;
          double startAngle = -pi / 2;

          for (int i = 0; i < data.length; i++) {
            final sweep = (data[i] / total) * 2 * pi;
            final color = palette[i % palette.length];

            canvas
              ..setFillColor(color)
              ..moveTo(cx, cy)
              ..bezierArc(
                cx + r * cos(startAngle),
                cy + r * sin(startAngle),
                r,
                r,
                cx + r * cos(startAngle + sweep),
                cy + r * sin(startAngle + sweep),
                large: sweep > pi,
                sweep: true,
              )
              ..lineTo(cx, cy)
              ..fillPath();

            startAngle += sweep;
          }

          // Inner white circle for donut effect
          canvas
            ..setFillColor(PdfColors.white)
            ..drawEllipse(cx, cy, r * 0.45, r * 0.45)
            ..fillPath();
        },
      ),
    );
  }

  /// Draws a vertical bar chart
  static pw.Widget _barChart({
    required List<String> labels,
    required List<double> values,
    double height = 160,
  }) {
    if (values.isEmpty) return pw.SizedBox(height: height);
    final maxVal = values.reduce(max);

    return pw.Column(
      children: [
        pw.SizedBox(
          height: height,
          child: pw.CustomPaint(
            painter: (PdfGraphics canvas, PdfPoint size) {
              const leftPad = 8.0;
              const botPad = 4.0;
              const topPad = 8.0;
              final chartW = size.x - leftPad;
              final chartH = size.y - botPad - topPad;
              final barW = (chartW / values.length) * 0.6;
              final gapW = chartW / values.length;

              for (int i = 0; i < values.length; i++) {
                final barH = maxVal > 0 ? (values[i] / maxVal) * chartH : 0.0;
                final x = leftPad + i * gapW + (gapW - barW) / 2;

                canvas
                  ..setFillColor(_chartColors[i % _chartColors.length])
                  ..drawRect(x, size.y - botPad - barH, barW, barH)
                  ..fillPath();
              }

              // X axis line
              canvas
                ..setStrokeColor(PdfColors.grey400)
                ..setLineWidth(0.5)
                ..moveTo(leftPad, size.y - botPad)
                ..lineTo(size.x, size.y - botPad)
                ..strokePath();
            },
          ),
        ),
        // Labels row below bars
        pw.Row(
          children: labels.map((l) {
            final short = l.length > 7 ? '${l.substring(0, 6)}…' : l;
            return pw.Expanded(
              child: pw.Center(
                child: pw.Text(short, style: const pw.TextStyle(fontSize: 7)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Draws a simple line chart
  static pw.Widget _lineChart({
    required List<String> labels,
    required List<double> values,
    double height = 140,
  }) {
    if (values.isEmpty) return pw.SizedBox(height: height);
    final maxVal = values.reduce(max);
    final minVal = values.reduce(min);
    final range = (maxVal - minVal) == 0 ? 1.0 : maxVal - minVal;

    return pw.Column(
      children: [
        pw.SizedBox(
          height: height,
          child: pw.CustomPaint(
            painter: (PdfGraphics canvas, PdfPoint size) {
              const leftPad = 8.0;
              const botPad = 4.0;
              const topPad = 8.0;
              final chartW = size.x - leftPad;
              final chartH = size.y - botPad - topPad;
              final stepX =
                  chartW / (values.length - 1 == 0 ? 1 : values.length - 1);

              final points = <PdfPoint>[];
              for (int i = 0; i < values.length; i++) {
                final x = leftPad + i * stepX;
                final y =
                    topPad + chartH - ((values[i] - minVal) / range) * chartH;
                points.add(PdfPoint(x, y));
              }

              // Filled area
              canvas.setFillColor(PdfColors.indigo100);
              canvas.moveTo(points.first.x, size.y - botPad);
              for (final p in points) canvas.lineTo(p.x, p.y);
              canvas.lineTo(points.last.x, size.y - botPad);
              canvas.fillPath();

              // Line
              canvas
                ..setStrokeColor(PdfColors.indigo400)
                ..setLineWidth(1.5)
                ..moveTo(points.first.x, points.first.y);
              for (final p in points) canvas.lineTo(p.x, p.y);
              canvas.strokePath();

              // Dots
              for (final p in points) {
                canvas
                  ..setFillColor(PdfColors.indigo600)
                  ..drawEllipse(p.x, p.y, 2.5, 2.5)
                  ..fillPath();
              }

              // X axis
              canvas
                ..setStrokeColor(PdfColors.grey400)
                ..setLineWidth(0.5)
                ..moveTo(leftPad, size.y - botPad)
                ..lineTo(size.x, size.y - botPad)
                ..strokePath();
            },
          ),
        ),
        pw.Row(
          children: labels.map((l) {
            final short = l.length > 5 ? l.substring(0, 4) : l;
            return pw.Expanded(
              child: pw.Center(
                child: pw.Text(short, style: const pw.TextStyle(fontSize: 7)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Shared Helpers ─────────────────────────────────────────────────────────

  static pw.Widget _legend({
    required List<String> labels,
    required List<String> values,
  }) {
    return pw.Wrap(
      spacing: 8,
      runSpacing: 4,
      children: List.generate(
        labels.length,
        (i) => _legendItem(
          labels[i],
          values[i],
          _chartColors[i % _chartColors.length],
        ),
      ),
    );
  }

  static pw.Widget _legendItem(String label, String value, PdfColor color) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(width: 10, height: 10, color: color),
        pw.SizedBox(width: 4),
        pw.Text('$label: $value', style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  static pw.Widget _schoolHeader(Map<String, dynamic>? s) {
    if (s == null) return pw.SizedBox();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          s['nom'] ?? 'ÉTABLISSEMENT SCOLAIRE',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#4A148C'),
          ),
        ),
        if (s['adresse'] != null)
          pw.Text(
            s['adresse'].toString(),
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
        if (s['telephone'] != null || s['email'] != null)
          pw.Text(
            '${s['telephone'] ?? ''} • ${s['email'] ?? ''}',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
      ],
    );
  }

  static pw.Widget _pageTitle(String title) {
    final date = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'Généré le $date',
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 4),
      ],
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 13,
        fontWeight: pw.FontWeight.bold,
        color: PdfColor.fromHex('#4A148C'),
      ),
    );
  }

  static pw.TableRow _tableRow(List<String> cells, {bool header = false}) {
    return pw.TableRow(
      decoration: header
          ? const pw.BoxDecoration(color: PdfColors.grey200)
          : null,
      children: cells
          .map(
            (c) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              child: pw.Text(
                c,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: header
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
