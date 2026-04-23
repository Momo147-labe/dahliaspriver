import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../../core/database/database_helper.dart';
import '../../../theme/app_theme.dart';
import '../../widgets/reports/grade_blank_sheet_pdf_helper.dart';

class GradeSheetSelectionModal extends StatefulWidget {
  final DatabaseHelper dbHelper;

  const GradeSheetSelectionModal({super.key, required this.dbHelper});

  @override
  State<GradeSheetSelectionModal> createState() =>
      _GradeSheetSelectionModalState();
}

class _GradeSheetSelectionModalState extends State<GradeSheetSelectionModal> {
  // State
  List<Map<String, dynamic>> _classes = [];
  Map<String, dynamic>? _selectedClass;

  List<Map<String, dynamic>> _subjects = [];
  Map<String, dynamic>? _selectedSubject;

  List<int> _availableTrimesters = [];
  int? _selectedTrimestre;
  bool _isLoading = true;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final db = await widget.dbHelper.database;
      final classes = await db.query('classe');

      final anneeId = await widget.dbHelper.ensureActiveAnneeCached();
      List<int> trimesters = [];
      if (anneeId != null) {
        final sequences = await widget.dbHelper.getSequencesPlanification(
          anneeId,
        );
        final Set<int> uniqueTrimesters = sequences
            .map((s) => s['trimestre'] as int)
            .toSet();
        trimesters = uniqueTrimesters.toList()..sort();
      }

      setState(() {
        _classes = classes;
        _availableTrimesters = trimesters;
        if (trimesters.isNotEmpty) {
          _selectedTrimestre = trimesters.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading initial data: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSubjects(int classeId) async {
    setState(() {
      _selectedSubject = null;
      _subjects = [];
    });
    try {
      final anneeId = await widget.dbHelper.ensureActiveAnneeCached();
      if (anneeId != null) {
        final subjects = await widget.dbHelper.getSubjectsByClass(
          classeId,
          anneeId,
        );
        setState(() {
          _subjects = subjects;
        });
      }
    } catch (e) {
      debugPrint("Error loading subjects: $e");
    }
  }

  void _generateGradeSheet() async {
    if (_selectedClass == null ||
        _selectedSubject == null ||
        _selectedTrimestre == null)
      return;
    setState(() => _isGenerating = true);

    try {
      final anneeRes = await widget.dbHelper.getActiveAnneeScolaire();
      if (anneeRes == null) {
        throw Exception("Aucune année scolaire active");
      }
      final anneeId = anneeRes['id'] as int;
      final anneeNom = anneeRes['libelle'] as String;

      // 1. Get students
      final students = await widget.dbHelper.getElevesByClasse(
        _selectedClass!['id'] as int,
        anneeId,
      );

      // 2. Get assigned teacher
      final teacher = await widget.dbHelper.getAssignedTeacher(
        _selectedClass!['id'] as int,
        _selectedSubject!['id'] as int,
        anneeId,
      );
      final teacherName = teacher != null
          ? '${teacher['nom']} ${teacher['prenom']}'
          : 'Non assigné';

      // 3. Get school info
      final ecole = await widget.dbHelper.getEcole();

      // 4. Get sequences for the trimester
      final allSequences = await widget.dbHelper.getSequencesPlanification(
        anneeId,
      );
      final trimesterSequences = allSequences
          .where((s) => s['trimestre'] == _selectedTrimestre)
          .toList();
      trimesterSequences.sort(
        (a, b) => (a['numero_sequence'] as int).compareTo(
          b['numero_sequence'] as int,
        ),
      );

      if (trimesterSequences.isEmpty) {
        throw Exception(
          "Aucune séquence planifiée pour ce trimestre dans l'année active",
        );
      }

      // Generate PDF
      final pdf = await GradeBlankSheetPdfHelper.generate(
        ecole: ecole,
        className: _selectedClass!['nom'] as String,
        subjectName: _selectedSubject!['nom'] as String,
        teacherName: teacherName.toUpperCase(),
        trimestre: _selectedTrimestre.toString(),
        annee: anneeNom,
        students: students.map((e) => Map<String, dynamic>.from(e)).toList(),
        sequences: trimesterSequences,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close modal

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name:
            'Fiche_Notes_Vierge_${_selectedClass!['nom']}_${_selectedSubject!['nom']}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                "Fiche de Notes (Vierge)",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Trimester Dropdown
          DropdownButtonFormField<int>(
            dropdownColor: isDark ? AppTheme.surfaceDark : Colors.white,
            style: TextStyle(
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
            decoration: _buildInputDecoration("Trimestre", isDark),
            value: _selectedTrimestre,
            items: _availableTrimesters.map((t) {
              final label = t == 1 ? "1er Trimestre" : "${t}ème Trimestre";
              return DropdownMenuItem<int>(value: t, child: Text(label));
            }).toList(),
            onChanged: (val) => setState(() => _selectedTrimestre = val),
          ),
          const SizedBox(height: 16),

          // Class Dropdown
          DropdownButtonFormField<int>(
            dropdownColor: isDark ? AppTheme.surfaceDark : Colors.white,
            style: TextStyle(
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
            decoration: _buildInputDecoration("Classe", isDark),
            value: _selectedClass?['id'] as int?,
            items: _classes.map((item) {
              return DropdownMenuItem<int>(
                value: item['id'] as int,
                child: Text(item['nom'] as String),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedClass = _classes.firstWhere(
                  (item) => item['id'] == val,
                );
              });
              _loadSubjects(val!);
            },
          ),
          const SizedBox(height: 16),

          // Subject Dropdown
          DropdownButtonFormField<int>(
            dropdownColor: isDark ? AppTheme.surfaceDark : Colors.white,
            style: TextStyle(
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
            decoration: _buildInputDecoration("Matière", isDark),
            value: _selectedSubject?['id'] as int?,
            items: _subjects.map((item) {
              return DropdownMenuItem<int>(
                value: item['id'] as int,
                child: Text(item['nom'] as String),
              );
            }).toList(),
            onChanged: _selectedClass == null
                ? null
                : (val) {
                    setState(() {
                      _selectedSubject = _subjects.firstWhere(
                        (item) => item['id'] == val,
                      );
                    });
                  },
          ),

          const SizedBox(height: 32),

          ElevatedButton(
            onPressed:
                (_selectedClass != null &&
                    _selectedSubject != null &&
                    !_isGenerating)
                ? _generateGradeSheet
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isGenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    "Générer la Fiche",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? Colors.white70 : AppTheme.textSecondary,
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey),
      ),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
    );
  }
}
