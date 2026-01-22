import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import 'result_sheet_page.dart'; // Import ResultSheetPage
import '../../../theme/app_theme.dart';

class ResultSheetSelectionModal extends StatefulWidget {
  final DatabaseHelper dbHelper;

  const ResultSheetSelectionModal({super.key, required this.dbHelper});

  @override
  State<ResultSheetSelectionModal> createState() =>
      _ResultSheetSelectionModalState();
}

class _ResultSheetSelectionModalState extends State<ResultSheetSelectionModal> {
  // State
  List<Map<String, dynamic>> _classes = [];
  Map<String, dynamic>? _selectedClass;

  // Period default (T1)
  int _selectedTrimestre = 1;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = await widget.dbHelper.database;
      final classes = await db.query('classe');

      setState(() {
        _classes = classes;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading data: $e");
      setState(() => _isLoading = false);
    }
  }

  void _generateResultSheet() async {
    if (_selectedClass == null) return;

    // Get Active Year ID
    final db = await widget.dbHelper.database;
    final anneeRes = await db.query(
      'annee_scolaire',
      where: 'active = 1',
      limit: 1,
    );
    if (anneeRes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucune année scolaire active trouvée")),
      );
      return;
    }
    final anneeId = anneeRes.first['id'] as int;

    if (!mounted) return;
    Navigator.pop(context); // Close modal
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultSheetPage(
          classeId: _selectedClass!['id'] as int,
          trimestre: _selectedTrimestre,
          sequence: 0, // Not used for now or default
          anneeId: anneeId,
        ),
      ),
    );
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
                  Icons.analytics_outlined,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                "Fiche de Résultat",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Class Dropdown
          DropdownButtonFormField<int>(
            dropdownColor: isDark ? AppTheme.surfaceDark : Colors.white,
            style: TextStyle(
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: "Classe",
              labelStyle: TextStyle(
                color: isDark ? Colors.white70 : AppTheme.textSecondary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.white24 : Colors.grey,
                ),
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey[50],
            ),
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
            },
          ),

          const SizedBox(height: 16),

          // Trimester Dropdown (Static 1, 2, 3, 4)
          DropdownButtonFormField<int>(
            dropdownColor: isDark ? AppTheme.surfaceDark : Colors.white,
            style: TextStyle(
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: "Période",
              labelStyle: TextStyle(
                color: isDark ? Colors.white70 : AppTheme.textSecondary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.white24 : Colors.grey,
                ),
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey[50],
            ),
            value: _selectedTrimestre,
            items: const [
              DropdownMenuItem(value: 1, child: Text("1er Trimestre")),
              DropdownMenuItem(value: 2, child: Text("2ème Trimestre")),
              DropdownMenuItem(value: 3, child: Text("3ème Trimestre")),
              DropdownMenuItem(value: 4, child: Text("Bilan Annuel")),
            ],
            onChanged: (val) => setState(() => _selectedTrimestre = val!),
          ),

          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _selectedClass != null ? _generateResultSheet : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              "Générer la Fiche",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24), // Bottom padding
        ],
      ),
    );
  }
}
