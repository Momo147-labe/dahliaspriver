import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/database/database_helper.dart';
import '../../../theme/app_theme.dart';

class ManageClassSubjectsModal extends StatefulWidget {
  final Map<String, dynamic> classe;
  final VoidCallback onSuccess;

  const ManageClassSubjectsModal({
    super.key,
    required this.classe,
    required this.onSuccess,
  });

  @override
  State<ManageClassSubjectsModal> createState() =>
      _ManageClassSubjectsModalState();
}

class _ManageClassSubjectsModalState extends State<ManageClassSubjectsModal> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _allSubjects = [];
  Map<int, double> _selectedSubjects = {}; // matiereId -> coefficient
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final anneeId = await _dbHelper.ensureActiveAnneeCached();
      if (anneeId == null) return;

      final allSubjects = await _dbHelper.getAllSubjects();
      final classSubjects = await _dbHelper.getSubjectsByClass(
        widget.classe['id'],
        anneeId,
      );

      setState(() {
        _allSubjects = allSubjects;
        _selectedSubjects = {
          for (var s in classSubjects)
            s['id'] as int: (s['coefficient'] as num?)?.toDouble() ?? 1.0,
        };
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading subjects for class: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final anneeId = await _dbHelper.ensureActiveAnneeCached();
      if (anneeId == null) return;

      final List<Map<String, dynamic>> data = _selectedSubjects.entries.map((
        e,
      ) {
        return {'id': e.key, 'coefficient': e.value};
      }).toList();

      await _dbHelper.saveClassSubjects(widget.classe['id'], anneeId, data);

      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error saving class subjects: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 500,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Symbols.book_5,
                      color: Colors.blue,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Matières de la Classe',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Classe: ${widget.classe['nom']}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Symbols.close),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_allSubjects.isEmpty)
            const Expanded(
              child: Center(
                child: Text('Aucune matière configurée dans l\'école.'),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: _allSubjects.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final subject = _allSubjects[index];
                  final isSelected = _selectedSubjects.containsKey(
                    subject['id'],
                  );
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.02)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor.withOpacity(0.3)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          activeColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedSubjects[subject['id']] = 1.0;
                              } else {
                                _selectedSubjects.remove(subject['id']);
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Symbols.book,
                          color: isSelected
                              ? AppTheme.primaryColor
                              : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            subject['nom'],
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 80,
                            child: TextFormField(
                              initialValue:
                                  _selectedSubjects[subject['id']]
                                      ?.toString() ??
                                  '1.0',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Coef',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onChanged: (val) {
                                final d = double.tryParse(val);
                                if (d != null) {
                                  _selectedSubjects[subject['id']] = d;
                                }
                              },
                            ),
                          ),
                        ],
                      ],
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
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Enregistrer',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
