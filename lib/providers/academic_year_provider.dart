import 'package:flutter/material.dart';
import '../core/database/database_helper.dart';

class AcademicYearProvider extends ChangeNotifier {
  int? _selectedAnneeId;
  Map<String, dynamic>? _selectedAnnee;
  List<Map<String, dynamic>> _allAnnees = [];
  bool _isLoading = false;

  int? get selectedAnneeId => _selectedAnneeId;
  Map<String, dynamic>? get selectedAnnee => _selectedAnnee;
  List<Map<String, dynamic>> get allAnnees => _allAnnees;
  bool get isLoading => _isLoading;

  AcademicYearProvider() {
    _init();
  }

  Future<void> _init() async {
    await loadAnnees();
    final active = await DatabaseHelper.instance.getActiveAnnee();
    if (active != null) {
      _selectedAnneeId = active['id'];
      _selectedAnnee = active;
      notifyListeners();
    } else if (_allAnnees.isNotEmpty) {
      _selectedAnneeId = _allAnnees.first['id'];
      _selectedAnnee = _allAnnees.first;
      notifyListeners();
    }
  }

  Future<void> loadAnnees() async {
    _isLoading = true;
    notifyListeners();
    try {
      final db = await DatabaseHelper.instance.database;
      _allAnnees = await db.query('annee_scolaire', orderBy: 'date_debut DESC');
    } catch (e) {
      debugPrint('Error loading academic years: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setSelectedAnnee(int id) async {
    if (_selectedAnneeId == id) return;

    final annee = _allAnnees.firstWhere(
      (element) => element['id'] == id,
      orElse: () => {},
    );
    if (annee.isNotEmpty) {
      _selectedAnneeId = id;
      _selectedAnnee = annee;

      // We also update the database active state to persist it across restarts
      await DatabaseHelper.instance.setActiveAnnee(id);

      notifyListeners();
    }
  }
}
