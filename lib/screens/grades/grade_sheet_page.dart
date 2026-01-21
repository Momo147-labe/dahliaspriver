import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/database/database_helper.dart';
import '../../theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final anneeId =
          widget.anneeId ??
          await DatabaseHelper.instance.ensureActiveAnneeCached();
      if (anneeId != null) {
        final students = await DatabaseHelper.instance.getGradesByClassSubject(
          widget.classeId,
          widget.subjectId,
          widget.trimestre,
          widget.sequence,
          anneeId,
        );
        setState(() {
          _students = students;
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

  Future<void> _saveGrades() async {
    setState(() => _isSaving = true);
    try {
      final anneeId = await DatabaseHelper.instance.ensureActiveAnneeCached();
      if (anneeId == null) return;

      for (var student in _students) {
        if (student['note'] != null) {
          await DatabaseHelper.instance.saveGrade({
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
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.className} - ${widget.subjectName}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                Text(
                  'Trimestre ${widget.trimestre} - Séquence ${widget.sequence}',
                  style: const TextStyle(fontSize: 14),
                ),
                if (_students.isNotEmpty)
                  Text(
                    'Coefficient: ${_students.first['coefficient'] ?? 1.0}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          if (!_isSaving)
            TextButton(
              onPressed: _saveGrades,
              child: const Text(
                'Enregistrer',
                style: TextStyle(color: Colors.white),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _isLoading
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
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(student['nom'][0])),
                    title: Text('${student['nom']} ${student['prenom']}'),
                    subtitle: Text('Matricule: ${student['matricule']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (note != null)
                          Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              (note * coeff).toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            initialValue: student['note']?.toString() ?? '',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Note',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            onChanged: (value) {
                              final parsedNote = double.tryParse(value);
                              setState(() {
                                _students[index]['note'] = parsedNote;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
