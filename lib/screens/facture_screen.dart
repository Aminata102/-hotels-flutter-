import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

// ═══════════════════════════════════════════════════════════════
// Écran "Facture" — répond au cas d'usage "Émettre une facture"
// du diagramme de cas d'utilisation du Caissier.
// Accessible en tapant sur une transaction dans l'historique de la Caisse.
// ═══════════════════════════════════════════════════════════════
class FactureScreen extends StatefulWidget {
  final String token;
  final String paiementId;
  const FactureScreen({super.key, required this.token, required this.paiementId});

  @override
  State<FactureScreen> createState() => _FactureScreenState();
}

class _FactureScreenState extends State<FactureScreen> {
  static const String baseUrl = 'http://10.0.2.2:8000/api';
  final Color primaryGreen = const Color(0xFF0F6E56);

  bool loading = true;
  Map<String, dynamic>? paiement;
  String? erreur;

  @override
  void initState() {
    super.initState();
    _chargerFacture();
  }

  Future<void> _chargerFacture() async {
    setState(() { loading = true; erreur = null; });
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/paiements/${widget.paiementId}'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        setState(() {
          paiement = jsonDecode(utf8.decode(res.bodyBytes));
          loading = false;
        });
      } else {
        setState(() { erreur = "Impossible de charger la facture (${res.statusCode})"; loading = false; });
      }
    } catch (e) {
      setState(() { erreur = "Erreur réseau : $e"; loading = false; });
    }
  }

  // Helper pour formater les montants en FCFA (ex: 140 000 FCFA)
  String _formatFcfa(num amount) {
    return "${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} FCFA";
  }

  // Construit le texte de la facture, réutilisé pour l'affichage ET pour le partage/export
  String _texteFacture() {
    if (paiement == null) return '';
    final estRemboursement = paiement!['type'] == 'remboursement';
    final reservation = paiement!['reservation'];
    final chambre = reservation?['chambre'];
    final user = paiement!['user'];

    // Extraction des montants financiers
    final double montantPaye = double.tryParse(paiement!['montant']?.toString() ?? '0') ?? 0;
    final double montantTotal = double.tryParse(reservation?['montant_total']?.toString() ?? reservation?['prix_total']?.toString() ?? '0') ?? montantPaye;
    final double cumulPaye = double.tryParse(reservation?['montant_paye']?.toString() ?? '0') ?? montantPaye;

    // Calcul du reste à payer (basé soit sur le total moins le cumul, soit sur le paiement courant si non spécifié)
    final double calculReste = montantTotal - (cumulPaye > 0 ? cumulPaye : montantPaye);
    final double resteAPayer = calculReste > 0 ? calculReste : 0;

    final date = DateTime.tryParse(paiement!['created_at'] ?? '')?.toLocal();
    final dateStr = date != null
        ? "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}"
        : '';

    return '''
HôtelManager SN — Hôtel Teranga, Dakar
${'=' * 40}
${estRemboursement ? 'REÇU DE REMBOURSEMENT' : 'FACTURE / REÇU DE PAIEMENT'}
N° ${paiement!['numero_facture'] ?? '—'}
Date : $dateStr
${'=' * 40}

Client : ${reservation?['nom_client'] ?? '—'}
Téléphone : ${reservation?['telephone_client'] ?? '—'}
${chambre != null ? "Chambre : ${chambre['numero']} — ${chambre['type']}" : ''}

Montant total : ${_formatFcfa(montantTotal)}
Montant payé  : ${estRemboursement ? '-' : ''}${_formatFcfa(montantPaye)}
Reste à payer : ${_formatFcfa(resteAPayer)}

Mode de paiement : ${paiement!['methode_paiement'] ?? '—'}
${(paiement!['note'] ?? '').toString().isNotEmpty ? "Note : ${paiement!['note']}" : ''}

Encaissé par : ${user?['prenom'] ?? ''} ${user?['nom'] ?? ''}
${'=' * 40}
Merci de votre confiance — Hôtel Teranga
'''.trim();
  }

  Future<void> _partagerFacture() async {
    final texte = _texteFacture();
    if (texte.isEmpty) return;
    await Share.share(texte, subject: 'Facture ${paiement?['numero_facture'] ?? ''}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: primaryGreen,
        title: const Text("Facture", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : erreur != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              Text(erreur!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _chargerFacture, child: const Text("Réessayer")),
            ],
          ),
        ),
      )
          : _buildFacture(),
      bottomNavigationBar: (!loading && erreur == null)
          ? SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _texteFacture()));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("📋 Facture copiée dans le presse-papiers")),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text("Copier"),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _partagerFacture,
                  icon: const Icon(Icons.ios_share, size: 18, color: Colors.white),
                  label: const Text("Partager / Exporter", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      )
          : null,
    );
  }

  Widget _buildFacture() {
    final estRemboursement = paiement!['type'] == 'remboursement';
    final reservation = paiement!['reservation'];
    final chambre = reservation?['chambre'];
    final user = paiement!['user'];

    // Extraction des montants financiers
    final double montantPaye = double.tryParse(paiement!['montant']?.toString() ?? '0') ?? 0;
    final double montantTotal = double.tryParse(reservation?['montant_total']?.toString() ?? reservation?['prix_total']?.toString() ?? '0') ?? montantPaye;
    final double cumulPaye = double.tryParse(reservation?['montant_paye']?.toString() ?? '0') ?? montantPaye;

    // Calcul du reste à payer
    final double calculReste = montantTotal - (cumulPaye > 0 ? cumulPaye : montantPaye);
    final double resteAPayer = calculReste > 0 ? calculReste : 0;

    final date = DateTime.tryParse(paiement!['created_at'] ?? '')?.toLocal();
    final dateStr = date != null
        ? "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}"
        : '—';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête hôtel
            Row(
              children: [
                Icon(Icons.hotel, color: primaryGreen, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("HôtelManager SN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryGreen)),
                      const Text("Hôtel Teranga — Dakar", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),

            // Type + numéro
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (estRemboursement ? Colors.orange : primaryGreen).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    estRemboursement ? "REÇU DE REMBOURSEMENT" : "FACTURE / REÇU DE PAIEMENT",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: estRemboursement ? Colors.orange : primaryGreen),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ligneFacture("N° facture", paiement!['numero_facture']?.toString() ?? '—', gras: true),
            _ligneFacture("Date", dateStr),
            const Divider(height: 32),

            const Text("CLIENT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
            const SizedBox(height: 8),
            _ligneFacture("Nom", reservation?['nom_client']?.toString() ?? '—'),
            _ligneFacture("Téléphone", reservation?['telephone_client']?.toString() ?? '—'),
            if (chambre != null) _ligneFacture("Chambre", "${chambre['numero']} — ${chambre['type']}"),
            const Divider(height: 32),

            const Text("PAIEMENT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
            const SizedBox(height: 8),
            _ligneFacture("Mode de paiement", paiement!['methode_paiement']?.toString() ?? '—'),
            _ligneFacture("Encaissé par", "${user?['prenom'] ?? ''} ${user?['nom'] ?? ''}".trim()),
            if ((paiement!['note'] ?? '').toString().isNotEmpty)
              _ligneFacture("Note", paiement!['note'].toString()),
            const SizedBox(height: 16),

            // Section DÉTAIL DES MONTANTS
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _ligneFacture("Montant total", _formatFcfa(montantTotal)),
                  _ligneFacture("Montant payé", "${estRemboursement ? '-' : ''}${_formatFcfa(montantPaye)}", gras: true),
                  const Divider(height: 16),
                  _ligneFacture("Reste à payer", _formatFcfa(resteAPayer), gras: true, couleurValeur: resteAPayer > 0 ? Colors.red[700] : Colors.green[700]),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text("Merci de votre confiance — Hôtel Teranga", style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ligneFacture(String label, String valeur, {bool gras = false, Color? couleurValeur}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Flexible(
            child: Text(
              valeur,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: gras ? FontWeight.bold : FontWeight.w500,
                color: couleurValeur,
              ),
            ),
          ),
        ],
      ),
    );
  }
}