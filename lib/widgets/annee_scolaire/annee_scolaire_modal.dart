import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class AnneeScolaireModal extends StatefulWidget {
  final bool isEdit;
  final Map<String, dynamic> annee;
  final VoidCallback onSave;
  final VoidCallback onClose;

  const AnneeScolaireModal({
    super.key,
    required this.isEdit,
    required this.annee,
    required this.onSave,
    required this.onClose,
  });

  @override
  State<AnneeScolaireModal> createState() => _AnneeScolaireModalState();
}

class _AnneeScolaireModalState extends State<AnneeScolaireModal> {
  final TextEditingController _libelleController = TextEditingController();
  final TextEditingController _dateDebutController = TextEditingController();
  final TextEditingController _dateFinController = TextEditingController();
  String _selectedStatut = 'Inactive';

  @override
  void initState() {
    super.initState();
    _libelleController.text = widget.annee['libelle'] ?? '';
    _dateDebutController.text = widget.annee['date_debut'] ?? '';
    _dateFinController.text = widget.annee['date_fin'] ?? '';
    _selectedStatut = widget.annee['statut'] ?? 'Inactive';
  }

  @override
  void dispose() {
    _libelleController.dispose();
    _dateDebutController.dispose();
    _dateFinController.dispose();
    super.dispose();
  }

  void _saveData() {
    widget.annee['libelle'] = _libelleController.text;
    widget.annee['date_debut'] = _dateDebutController.text;
    widget.annee['date_fin'] = _dateFinController.text;
    widget.annee['statut'] = _selectedStatut;
    widget.onSave();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppTheme.cardDark : AppTheme.cardLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Text(
                  widget.isEdit
                      ? 'Modifier l\'année scolaire'
                      : 'Nouvelle année scolaire',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Formulaire
            TextField(
              controller: _libelleController,
              decoration: InputDecoration(
                labelText: 'Libellé *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dateDebutController,
                    decoration: InputDecoration(
                      labelText: 'Date de début *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.date_range),
                      hintText: 'JJ/MM/AAAA',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _dateFinController,
                    decoration: InputDecoration(
                      labelText: 'Date de fin *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.event),
                      hintText: 'JJ/MM/AAAA',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedStatut,
              onChanged: (value) => setState(() => _selectedStatut = value!),
              decoration: InputDecoration(
                labelText: 'Statut *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.toggle_on),
              ),
              items: const [
                DropdownMenuItem(value: 'Active', child: Text('Active')),
                DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
              ],
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onClose,
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _saveData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(widget.isEdit ? 'Mettre à jour' : 'Enregistrer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
