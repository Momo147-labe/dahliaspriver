import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import '../../services/grade_import_service.dart';
import '../../core/database/database_helper.dart';
import '../../theme/app_theme.dart';

class GradeImportModal extends StatefulWidget {
  final int classId;
  final int subjectId;
  final int trimester;
  final int sequence;
  final int anneeId;
  final VoidCallback onSuccess;

  const GradeImportModal({
    super.key,
    required this.classId,
    required this.subjectId,
    required this.trimester,
    required this.sequence,
    required this.anneeId,
    required this.onSuccess,
  });

  @override
  State<GradeImportModal> createState() => _GradeImportModalState();
}

class _GradeImportModalState extends State<GradeImportModal> {
  bool _isParsing = false;
  bool _isImporting = false;
  File? _selectedFile;
  List<Map<String, dynamic>> _previewData = [];
  Map<int, String> _sequenceNames = {};

  String _className = '';
  String _subjectName = '';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadContextInfo();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadContextInfo() async {
    final db = DatabaseHelper.instance;
    final cls = await db.rawQuery('SELECT nom FROM classe WHERE id = ?', [
      widget.classId,
    ]);
    final mat = await db.rawQuery('SELECT nom FROM matiere WHERE id = ?', [
      widget.subjectId,
    ]);
    if (mounted) {
      setState(() {
        _className = cls.isNotEmpty ? cls.first['nom'].toString() : '';
        _subjectName = mat.isNotEmpty ? mat.first['nom'].toString() : '';
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await file_picker.FilePicker.pickFiles(
      type: file_picker.FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
    );

    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _previewData = [];
        _sequenceNames = {};
      });
      _parseFile();
    }
  }

  Future<void> _parseFile() async {
    if (_selectedFile == null) return;
    setState(() => _isParsing = true);

    try {
      final String extension = _selectedFile!.path
          .split('.')
          .last
          .toLowerCase();
      List<Map<String, dynamic>> data;
      Map<int, String> extractedSeqNames = {};

      if (extension == 'xlsx' || extension == 'xls') {
        // Fetch class & subject names for metadata validation
        final dbHelper = DatabaseHelper.instance;

        final classeData = await dbHelper.rawQuery(
          'SELECT nom FROM classe WHERE id = ?',
          [widget.classId],
        );
        final expectedClassName = classeData.isNotEmpty
            ? classeData.first['nom'].toString()
            : '';

        final matiereData = await dbHelper.rawQuery(
          'SELECT nom FROM matiere WHERE id = ?',
          [widget.subjectId],
        );
        final expectedSubjectName = matiereData.isNotEmpty
            ? matiereData.first['nom'].toString()
            : null;

        final rawResults = await GradeImportService.instance.parseGradeExcel(
          _selectedFile!,
          trimester: widget.trimester,
          sequence: widget.sequence,
          anneeId: widget.anneeId,
          expectedClassName: expectedClassName,
          expectedSubjectName: expectedSubjectName,
        );
        data = rawResults['students'] as List<Map<String, dynamic>>;
        extractedSeqNames =
            rawResults['sequenceNames'] as Map<int, String>? ?? {};
      } else {
        data = await GradeImportService.instance.parseGradeCSV(_selectedFile!);
      }

      setState(() {
        _previewData = data;
        _sequenceNames = extractedSeqNames;
        _isParsing = false;
      });
    } catch (e) {
      setState(() {
        _isParsing = false;
        _selectedFile = null; // Reset so user must re-pick a valid file
      });
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.error_outline, color: Colors.red, size: 48),
            title: const Text(
              'Fichier incorrect',
              style: TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            content: Text(
              e.toString().replaceAll('Exception: ', ''),
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close),
                label: const Text('Fermer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _import() async {
    if (_previewData.isEmpty) return;

    // Check for existing grades before overwriting
    setState(() => _isImporting = true);
    final existingCount = await GradeImportService.instance.countExistingGrades(
      parsedData: _previewData,
      subjectId: widget.subjectId,
      trimester: widget.trimester,
      anneeId: widget.anneeId,
    );
    setState(() => _isImporting = false);

    if (existingCount > 0 && mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 48,
          ),
          title: const Text(
            'Notes existantes détectées',
            style: TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Text(
            '$existingCount note(s) existent déjà pour $_subjectName – Trimestre ${widget.trimester}.\n\n'
            'Continuer va remplacer ces notes par les nouvelles valeurs du fichier.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(ctx, false),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.upload_rounded),
              label: const Text('Remplacer quand même'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return; // User cancelled
    }

    setState(() => _isImporting = true);
    try {
      final results = await GradeImportService.instance.importGrades(
        parsedData: _previewData,
        subjectId: widget.subjectId,
        trimester: widget.trimester,
        sequence: widget.sequence,
        anneeId: widget.anneeId,
      );

      if (mounted) {
        setState(() => _isImporting = false);
        _showSuccess(
          'Importation réussie: ${results['success']} succès, ${results['failure']} échecs.',
        );
        widget.onSuccess();
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isImporting = false);
      _showError('Erreur lors de l\'importation: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Importer des Notes',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Context info chips
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _InfoChip(
                icon: Icons.school_outlined,
                label: 'Trimestre ${widget.trimester}',
                color: Colors.indigo,
              ),
              if (_className.isNotEmpty)
                _InfoChip(
                  icon: Icons.class_outlined,
                  label: _className,
                  color: Colors.teal,
                ),
              if (_subjectName.isNotEmpty)
                _InfoChip(
                  icon: Icons.menu_book_outlined,
                  label: _subjectName,
                  color: Colors.orange,
                ),
            ],
          ),
          const Divider(height: 28),

          if (_selectedFile == null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.upload_file_rounded,
                      size: 64,
                      color: AppTheme.primaryColor.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.file_open),
                      label: const Text('Choisir un fichier (CSV ou Excel)'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Text(
              'Fichier: ${_selectedFile!.path.split('/').last}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isParsing
                  ? const Center(child: CircularProgressIndicator())
                  : _previewData.isEmpty
                  ? const Center(child: Text('Aucune donnée valide trouvée.'))
                  : ListView.separated(
                      controller: _scrollController,
                      itemCount: _previewData.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = _previewData[index];
                        final Map<int, double>? multiNotes =
                            item['notes'] as Map<int, double>?;
                        final double? singleNote = item['note'] as double?;
                        final String? studentName = item['nom'] as String?;

                        final bool hasError =
                            (multiNotes == null || multiNotes.isEmpty) &&
                            singleNote == null;

                        String displayNotes = 'Note invalide';
                        if (!hasError) {
                          if (multiNotes != null && multiNotes.isNotEmpty) {
                            displayNotes = multiNotes.entries
                                .map((e) {
                                  final seqName =
                                      _sequenceNames[e.key] ?? 'S${e.key}';
                                  return '$seqName: ${e.value}';
                                })
                                .join(' | ');
                          } else {
                            displayNotes = 'Note: $singleNote';
                          }
                        }

                        final String titleText =
                            studentName != null && studentName.isNotEmpty
                            ? '${item['matricule'] ?? 'Inconnu'} - $studentName'
                            : item['matricule'] ?? 'Inconnu';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: hasError
                                ? Colors.red.shade100
                                : Colors.blue.shade100,
                            child: Icon(
                              hasError
                                  ? Icons.error_outline
                                  : Icons.person_outline,
                              color: hasError ? Colors.red : Colors.blue,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            titleText,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            displayNotes,
                            style: TextStyle(
                              color: hasError ? Colors.red : null,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickFile,
                    child: const Text('Changer de fichier'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isImporting || _previewData.isEmpty
                        ? null
                        : _import,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: _isImporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Lancer l\'importation'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Small colored chip used in the import modal header.
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
