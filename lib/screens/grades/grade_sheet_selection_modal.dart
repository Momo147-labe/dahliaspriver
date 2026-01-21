import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import 'grade_sheet_page.dart';
import '../../../theme/app_theme.dart';

class GradeSheetSelectionModal extends StatefulWidget {
  final DatabaseHelper dbHelper;

  const GradeSheetSelectionModal({super.key, required this.dbHelper});

  @override
  State<GradeSheetSelectionModal> createState() =>
      _GradeSheetSelectionModalState();
}

class _GradeSheetSelectionModalState extends State<GradeSheetSelectionModal> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _subjects = [];
  Map<String, dynamic>? _selectedClass;
  Map<String, dynamic>? _selectedSubject;
  int _selectedTrimestre = 1;
  int _selectedSequence = 1;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final db = await widget.dbHelper.database;
    final classes = await db.query('classe', orderBy: 'nom ASC');
    if (mounted) {
      setState(() {
        _classes = classes;
        if (_classes.isNotEmpty) {
          _selectedClass = _classes.first;
          _loadSubjects();
        } else {
          _isLoading = false;
        }
      });
    }
  }

  Future<void> _loadSubjects() async {
    if (_selectedClass == null) return;
    setState(() => _isLoading = true);
    final activeAnnee = await widget.dbHelper.ensureActiveAnneeCached();
    if (activeAnnee != null) {
      final subjects = await widget.dbHelper.getSubjectsByClass(
        _selectedClass!['id'],
        activeAnnee,
      );
      if (mounted) {
        setState(() {
          _subjects = subjects;
          if (_subjects.isNotEmpty) {
            _selectedSubject = _subjects.first;
          } else {
            _selectedSubject = null;
          }
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.backgroundDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Générer une Fiche de Notes",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_classes.isEmpty)
            const Center(child: Text("Aucune classe disponible."))
          else
            Column(
              children: [
                _buildDropdown("Classe", _selectedClass?['id'], _classes, (
                  val,
                ) {
                  setState(() {
                    _selectedClass = _classes.firstWhere((c) => c['id'] == val);
                    _selectedSubject = null;
                  });
                  _loadSubjects();
                }, isDark),
                const SizedBox(height: 16),
                _buildDropdown("Matière", _selectedSubject?['id'], _subjects, (
                  val,
                ) {
                  setState(() {
                    _selectedSubject = _subjects.firstWhere(
                      (s) => s['id'] == val,
                    );
                  });
                }, isDark),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        "Trimestre",
                        _selectedTrimestre,
                        [
                          {'id': 1, 'nom': 'Trimestre 1'},
                          {'id': 2, 'nom': 'Trimestre 2'},
                          {'id': 3, 'nom': 'Trimestre 3'},
                        ],
                        (val) => setState(() => _selectedTrimestre = val),
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDropdown(
                        "Séquence",
                        _selectedSequence,
                        List.generate(
                          6,
                          (i) => {'id': i + 1, 'nom': 'Séquence ${i + 1}'},
                        ),
                        (val) => setState(() => _selectedSequence = val),
                        isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        (_selectedClass != null && _selectedSubject != null)
                        ? () async {
                            final activeAnnee = await widget.dbHelper
                                .ensureActiveAnneeCached();
                            if (activeAnnee != null && mounted) {
                              Navigator.pop(context); // Close modal
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => GradeSheetPage(
                                    classeId: _selectedClass!['id'],
                                    subjectId: _selectedSubject!['id'],
                                    trimestre: _selectedTrimestre,
                                    sequence: _selectedSequence,
                                    anneeId: activeAnnee,
                                    className: _selectedClass!['nom'],
                                    subjectName: _selectedSubject!['nom'],
                                  ),
                                ),
                              );
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Générer la Fiche",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    dynamic value,
    List<dynamic> items,
    Function(dynamic) onChanged,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField(
          value: value,
          items: items.map((item) {
            return DropdownMenuItem(
              value: item['id'],
              child: Text(item['nom'].toString()),
            );
          }).toList(),
          onChanged: onChanged,
          dropdownColor: isDark ? AppTheme.surfaceDark : Colors.white,
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? AppTheme.surfaceDark : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}
