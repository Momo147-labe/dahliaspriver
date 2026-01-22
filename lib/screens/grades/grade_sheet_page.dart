import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../core/database/database_helper.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reports/grade_sheet_pdf_helper.dart';
import '../../models/ecole.dart';

class GradeSheetPage extends StatefulWidget {
  final int classeId;
  final int subjectId;
  final int trimestre;
  final int sequence;
  final String className;
  final String subjectName;
  final int? anneeId;

  const GradeSheetPage({
    super.key,
    required this.classeId,
    required this.subjectId,
    required this.trimestre,
    required this.sequence,
    required this.className,
    required this.subjectName,
    this.anneeId,
  });

  @override
  State<GradeSheetPage> createState() => _GradeSheetPageState();
}

class _GradeSheetPageState extends State<GradeSheetPage> {
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;
  bool _isSaving = false;
  Ecole? _ecole;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final dbHelper = DatabaseHelper.instance;
      final anneeId =
          widget.anneeId ?? await dbHelper.ensureActiveAnneeCached();

      final ecole = await dbHelper.getEcole();

      if (anneeId != null) {
        final students = await dbHelper.getGradesByClassSubject(
          widget.classeId,
          widget.subjectId,
          widget.trimestre,
          widget.sequence,
          anneeId,
        );
        setState(() {
          _students = List<Map<String, dynamic>>.from(students);
          _ecole = ecole;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportPdf() async {
    if (_students.isEmpty) return;

    try {
      final activeAnnee = await DatabaseHelper.instance
          .getActiveAnneeScolaire();
      final anneeLabel = activeAnnee?['nom'] ?? '2023-2024';

      final pdf = await GradeSheetPdfHelper.generate(
        ecole: _ecole,
        className: widget.className,
        subjectName: widget.subjectName,
        sequence: widget.sequence.toString(),
        annee: anneeLabel,
        students: _students,
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Fiche_Saisie_${widget.className}_${widget.subjectName}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveGrades() async {
    setState(() => _isSaving = true);
    try {
      final dbHelper = DatabaseHelper.instance;
      final anneeId =
          widget.anneeId ?? await dbHelper.ensureActiveAnneeCached();
      if (anneeId == null) return;

      for (var student in _students) {
        if (student['note'] != null) {
          await dbHelper.saveGrade({
            'eleve_id': student['eleve_id'],
            'matiere_id': widget.subjectId,
            'note': student['note'],
            'coefficient': student['coefficient'] ?? 1.0,
            'trimestre': widget.trimestre,
            'sequence': widget.sequence,
            'annee_scolaire_id': anneeId,
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notes enregistrées avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur sauvegarde: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.backgroundDark
          : AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text('${widget.className} - ${widget.subjectName}'),
        elevation: 0,
        backgroundColor: AppTheme.primaryColor,
        actions: [
          IconButton(
            onPressed: _exportPdf,
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exporter PDF pour saisie manuelle',
          ),
          if (!_isSaving)
            TextButton(
              onPressed: _saveGrades,
              child: const Text(
                'ENREGISTRER',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppTheme.primaryColor.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHeaderBadge(
                  Icons.calendar_month,
                  'Trimestre ${widget.trimestre}',
                ),
                _buildHeaderBadge(Icons.numbers, 'Séquence ${widget.sequence}'),
                if (_students.isNotEmpty)
                  _buildHeaderBadge(
                    Icons.star,
                    'Coeff: ${_students.first['coefficient'] ?? 1.0}',
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _students.length,
                    itemBuilder: (context, index) {
                      final student = _students[index];
                      final note = student['note'] as double?;
                      final coeff =
                          (student['coefficient'] as num?)?.toDouble() ?? 1.0;

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppTheme.primaryColor
                                    .withOpacity(0.1),
                                child: Text(
                                  student['nom'][0],
                                  style: const TextStyle(
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${student['nom']} ${student['prenom']}'
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Matricule: ${student['matricule']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (note != null)
                                    Container(
                                      margin: const EdgeInsets.only(right: 12),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        (note * coeff).toStringAsFixed(1),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  SizedBox(
                                    width: 75,
                                    child: TextFormField(
                                      initialValue:
                                          student['note']?.toString() ?? '',
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: 'Note/20',
                                        labelStyle: const TextStyle(
                                          fontSize: 10,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.withOpacity(0.3),
                                          ),
                                        ),
                                      ),
                                      onChanged: (value) {
                                        final parsedNote = double.tryParse(
                                          value.replaceAll(',', '.'),
                                        );
                                        setState(() {
                                          _students[index]['note'] = parsedNote;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }
}
