import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';

class PaymentModal extends StatefulWidget {
  final Map<String, dynamic>? payment;
  final List<Map<String, dynamic>> eleves;
  final VoidCallback onSaved;

  const PaymentModal({
    super.key,
    this.payment,
    required this.eleves,
    required this.onSaved,
  });

  @override
  State<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal> {
  final _formKey = GlobalKey<FormState>();

  final _montantTotalCtrl = TextEditingController();
  final _montantPayeCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _observationCtrl = TextEditingController();

  int? _selectedEleveId;
  int? _selectedClasseId;
  int? _selectedFraisId;

  String _modePaiement = 'Espèces';
  String _typePaiement = 'inscription';

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.payment;

    if (p != null) {
      _selectedEleveId = p['eleve_id'];
      _selectedClasseId = p['classe_id'];
      _selectedFraisId = p['frais_id'];
      _montantTotalCtrl.text = p['montant_total'].toString();
      _montantPayeCtrl.text = p['montant_paye'].toString();
      _referenceCtrl.text = p['reference_paiement'] ?? '';
      _observationCtrl.text = p['observation'] ?? '';
      _modePaiement = p['mode_paiement'];
      _typePaiement = p['type_paiement'];
    }
  }

  @override
  void dispose() {
    _montantTotalCtrl.dispose();
    _montantPayeCtrl.dispose();
    _referenceCtrl.dispose();
    _observationCtrl.dispose();
    super.dispose();
  }

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) return;

    final montantTotal = double.parse(_montantTotalCtrl.text);
    final montantPaye = double.parse(_montantPayeCtrl.text);

    if (montantPaye > montantTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le montant payé dépasse le total')),
      );
      return;
    }

    setState(() => _loading = true);

    final db = await DatabaseHelper.instance.database;

    final paiement = {
      'eleve_id': _selectedEleveId,
      'classe_id': _selectedClasseId,
      'frais_id': _selectedFraisId,
      'montant_total': montantTotal,
      'montant_paye': montantPaye,
      'montant_restant': montantTotal - montantPaye,
      'mode_paiement': _modePaiement,
      'reference_paiement': _referenceCtrl.text,
      'observation': _observationCtrl.text,
      'date_paiement': DateTime.now().toIso8601String(),
      'type_paiement': _typePaiement,
      'statut': montantPaye == montantTotal ? 'complet' : 'partiel',
    };

    if (widget.payment != null) {
      await db.update(
        'paiements',
        paiement,
        where: 'id = ?',
        whereArgs: [widget.payment!['id']],
      );
    } else {
      await db.insert('paiements', paiement);
    }

    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paiement scolarité',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                /// ÉLÈVE
                DropdownButtonFormField<int>(
                  value: _selectedEleveId,
                  decoration: const InputDecoration(
                    labelText: 'Élève *',
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: widget.eleves.map<DropdownMenuItem<int>>((e) {
                    return DropdownMenuItem<int>(
                      value: e['id'],
                      child: Text('${e['nom']} ${e['prenom']}'),
                    );
                  }).toList(),
                  onChanged: (v) {
                    final eleve = widget.eleves.firstWhere((e) => e['id'] == v);
                    setState(() {
                      _selectedEleveId = v;
                      _selectedClasseId = eleve['classe_id'];
                      _selectedFraisId = eleve['frais_id'];
                    });
                  },
                  validator: (v) => v == null ? 'Sélection obligatoire' : null,
                ),

                const SizedBox(height: 16),

                /// MONTANT TOTAL
                TextFormField(
                  controller: _montantTotalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Montant total *',
                    prefixIcon: Icon(Icons.account_balance),
                  ),
                  validator: (v) => v!.isEmpty ? 'Champ requis' : null,
                ),

                const SizedBox(height: 16),

                /// MONTANT PAYÉ
                TextFormField(
                  controller: _montantPayeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Montant payé *',
                    prefixIcon: Icon(Icons.payments),
                  ),
                  validator: (v) => v!.isEmpty ? 'Champ requis' : null,
                ),

                const SizedBox(height: 16),

                /// MODE
                DropdownButtonFormField<String>(
                  value: _modePaiement,
                  decoration: const InputDecoration(
                    labelText: 'Mode de paiement',
                    prefixIcon: Icon(Icons.credit_card),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Espèces', child: Text('Espèces')),
                    DropdownMenuItem(
                      value: 'Mobile Money',
                      child: Text('Mobile Money'),
                    ),
                    DropdownMenuItem(
                      value: 'Virement',
                      child: Text('Virement'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _modePaiement = v!),
                ),

                const SizedBox(height: 16),

                /// TYPE
                DropdownButtonFormField<String>(
                  value: _typePaiement,
                  decoration: const InputDecoration(
                    labelText: 'Type de paiement',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'inscription',
                      child: Text('Inscription'),
                    ),
                    DropdownMenuItem(
                      value: 'reinscription',
                      child: Text('Réinscription'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _typePaiement = v!),
                ),

                const SizedBox(height: 16),

                /// RÉFÉRENCE
                TextFormField(
                  controller: _referenceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Référence',
                    prefixIcon: Icon(Icons.receipt),
                  ),
                ),

                const SizedBox(height: 16),

                /// OBSERVATION
                TextFormField(
                  controller: _observationCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Observation',
                    prefixIcon: Icon(Icons.note),
                  ),
                ),

                const SizedBox(height: 24),

                /// BOUTON
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _savePayment,
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text('Enregistrer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
