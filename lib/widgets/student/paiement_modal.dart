import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../theme/app_theme.dart';

class PaiementModal extends StatefulWidget {
  final Map<String, dynamic> eleve;
  final Map<String, dynamic> classe;
  final Map<String, dynamic> frais;
  final String typeInscription; // 'inscription' ou 'reinscription'
  final VoidCallback onPaiementComplete;

  const PaiementModal({
    super.key,
    required this.eleve,
    required this.classe,
    required this.frais,
    required this.typeInscription,
    required this.onPaiementComplete,
  });

  @override
  State<PaiementModal> createState() => _PaiementModalState();
}

class _PaiementModalState extends State<PaiementModal> {
  final TextEditingController _montantController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _observationController = TextEditingController();
  String _modePaiement = 'Espèces';
  bool _isLoading = false;

  // Calcul des montants
  double get _montantInscription {
    return widget.typeInscription == 'inscription' 
        ? (widget.frais['inscription'] ?? 0.0).toDouble()
        : (widget.frais['reinscription'] ?? 0.0).toDouble();
  }

  double get _montantTotal {
    return _montantInscription + 
           (widget.frais['tranche1'] ?? 0.0).toDouble() +
           (widget.frais['tranche2'] ?? 0.0).toDouble() +
           (widget.frais['tranche3'] ?? 0.0).toDouble();
  }

  double get _montantRestant {
    return _montantTotal - (_montantController.text.isNotEmpty ? double.parse(_montantController.text) : 0.0);
  }

  @override
  void initState() {
    super.initState();
    _montantController.text = _montantInscription.toStringAsFixed(2);
  }

  Future<void> _effectuerPaiement() async {
    if (_montantController.text.isEmpty || 
        double.parse(_montantController.text) <= 0) {
      _showError('Veuillez entrer un montant valide');
      return;
    }

    if (double.parse(_montantController.text) < _montantInscription) {
      _showError('Le montant minimum pour ${widget.typeInscription} est de ${_montantInscription.toStringAsFixed(2)}');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;
      
      // Créer l'enregistrement de paiement
      await db.insert('paiements', {
        'eleve_id': widget.eleve['id'],
        'classe_id': widget.classe['id'],
        'frais_id': widget.frais['id'],
        'montant_total': _montantTotal,
        'montant_paye': double.parse(_montantController.text),
        'montant_restant': _montantRestant,
        'mode_paiement': _modePaiement,
        'reference_paiement': _referenceController.text,
        'observation': _observationController.text,
        'date_paiement': DateTime.now().toIso8601String(),
        'type_paiement': widget.typeInscription,
        'statut': _montantRestant <= 0 ? 'complet' : 'partiel',
      });

      // Mettre à jour le statut de l'élève
      await db.update(
        'eleve',
        {'statut': widget.typeInscription == 'inscription' ? 'inscrit' : 'reinscrit'},
        where: 'id = ?',
        whereArgs: [widget.eleve['id']],
      );

      setState(() => _isLoading = false);
      
      if (mounted) {
        Navigator.pop(context);
        widget.onPaiementComplete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Paiement de ${_montantController.text} enregistré avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erreur lors du paiement: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppTheme.cardDark : AppTheme.cardLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.payments, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Text(
                  'Paiement - ${widget.typeInscription == 'inscription' ? 'Inscription' : 'Réinscription'}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Informations élève et classe
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Élève: ${widget.eleve['nom']} ${widget.eleve['prenom']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Classe: ${widget.classe['nom']} - ${widget.classe['niveau']}',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Détails des frais
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Détail des frais',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildFraisItem('Frais d\'${widget.typeInscription}', _montantInscription),
                  if (widget.typeInscription == 'inscription') ...[
                    _buildFraisItem('Tranche 1', (widget.frais['tranche1'] ?? 0.0).toDouble()),
                    _buildFraisItem('Tranche 2', (widget.frais['tranche2'] ?? 0.0).toDouble()),
                    _buildFraisItem('Tranche 3', (widget.frais['tranche3'] ?? 0.0).toDouble()),
                  ],
                  const Divider(),
                  _buildFraisItem('Total', _montantTotal, isTotal: true),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Formulaire de paiement
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _montantController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Montant à payer *',
                      hintText: 'Montant minimum: ${_montantInscription.toStringAsFixed(2)}',
                      prefixIcon: const Icon(Icons.attach_money),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _modePaiement,
                    onChanged: (value) => setState(() => _modePaiement = value!),
                    decoration: InputDecoration(
                      labelText: 'Mode de paiement',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: ['Espèces', 'Chèque', 'Virement', 'Mobile Money'].map((mode) {
                      return DropdownMenuItem(value: mode, child: Text(mode));
                    }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _referenceController,
              decoration: InputDecoration(
                labelText: 'Référence de paiement',
                hintText: 'Numéro de chèque, référence virement...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _observationController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Observations',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),

            // Résumé du paiement
            if (_montantController.text.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _montantRestant <= 0 ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Reste à payer:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      '${_montantRestant.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: _montantRestant <= 0 ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _effectuerPaiement,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Confirmer le paiement'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFraisItem(String label, double montant, {bool isTotal = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            '${montant.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
              color: isTotal ? AppTheme.primaryColor : (isDark ? Colors.white70 : Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
