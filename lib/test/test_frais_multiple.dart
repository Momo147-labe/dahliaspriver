import 'package:flutter/material.dart';
import '../widgets/frais/frais_modal.dart';
import '../core/database/database_helper.dart';

class TestFraisMultipleWidget extends StatefulWidget {
  const TestFraisMultipleWidget({super.key});

  @override
  State<TestFraisMultipleWidget> createState() => _TestFraisMultipleWidgetState();
}

class _TestFraisMultipleWidgetState extends State<TestFraisMultipleWidget> {
  List<Map<String, dynamic>> _classes = [];
  Map<String, dynamic>? _activeAnnee;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final activeAnnee = await DatabaseHelper.instance.getActiveAnnee();
      if (activeAnnee != null) {
        final classes = await DatabaseHelper.instance.getClassesByAnnee(activeAnnee['id']);
        setState(() {
          _activeAnnee = activeAnnee;
          _classes = classes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showTestModal() {
    if (_activeAnnee == null) return;
    
    showDialog(
      context: context,
      builder: (context) => FraisModal(
        isEdit: false,
        frais: {
          'annee_scolaire_id': _activeAnnee!['id'],
          'inscription': 0.0,
          'reinscription': 0.0,
          'tranche1': 0.0,
          'tranche2': 0.0,
          'tranche3': 0.0,
        },
        classes: _classes,
        allowMultipleClasses: true,
        onSave: () {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Test réussi ! Frais sauvegardés.'),
              backgroundColor: Colors.green,
            ),
          );
        },
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Frais Multiple'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Test de Sélection Multiple',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Classes disponibles: ${_classes.length}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  if (_classes.isNotEmpty)
                    Column(
                      children: _classes.take(3).map((classe) => 
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text('• ${classe['nom']} - ${classe['niveau']}'),
                        )
                      ).toList(),
                    ),
                  if (_classes.length > 3)
                    Text('... et ${_classes.length - 3} autres'),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: _classes.isEmpty ? null : _showTestModal,
                    icon: const Icon(Icons.school),
                    label: const Text('Tester Sélection Multiple'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}