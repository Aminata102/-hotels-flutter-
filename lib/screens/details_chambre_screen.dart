import 'package:flutter/material.dart';

class DetailsChambreScreen extends StatelessWidget {
  final Map<String, dynamic> chambre;

  const DetailsChambreScreen({super.key, required this.chambre});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F6E56),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Chambre ${chambre['numero']} — ${chambre['type']}",
            style: const TextStyle(color: Colors.white, fontSize: 18)),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
            child: Center(child: Text(chambre['statut'], style: const TextStyle(color: Colors.white, fontSize: 12))),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER VERT ---
            Container(
              color: const Color(0xFF0F6E56),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _headerInfo("Étage", "1er"),
                  _headerInfo("Capacité", "2 personnes"),
                  _headerInfo("Tarif / nuit", "${chambre['prix']}"),
                ],
              ),
            ),

            // --- ALERTE PAIEMENT ---
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade100),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Paiement en attente", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF874D00))),
                        Text("Solde restant de 45 000 FCFA non réglé. Départ prévu demain.",
                            style: TextStyle(color: Colors.orange.shade900, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _buildSection("CLIENT", _buildClientInfo()),
            _buildSection("DÉTAILS DU SÉJOUR", _buildSejourInfo()),
            _buildSection("ÉQUIPEMENTS", _buildEquipements()),

            // --- BOUTONS D'ACTION ---
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.payments_outlined, color: Colors.white),
                    label: const Text("Enregistrer le paiement ↗", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F6E56),
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Prolonger séjour", style: TextStyle(color: Colors.black87)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFF1F0),
                            side: const BorderSide(color: Color(0xFFFFA39E)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Check-out", style: TextStyle(color: Color(0xFFCF1322))),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerInfo(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildClientInfo() {
    return Column(
      children: [
        Row(
          children: [
            const CircleAvatar(radius: 24, backgroundColor: Color(0xFFF0F5FF), child: Text("AD", style: TextStyle(color: Color(0xFF2F54EB)))),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Aïssatou Diallo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("+221 77 345 67 89 · Dakar, Sénégal", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
        const Divider(height: 32),
        Row(
          children: [
            Expanded(child: _miniInfo("Pièce d'identité", "CNI · 1234567890")),
            Expanded(child: _miniInfo("Nationalité", "Sénégalaise")),
          ],
        ),
      ],
    );
  }

  Widget _buildSejourInfo() {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Arrivée", style: TextStyle(color: Colors.grey, fontSize: 12)), Text("15 avr.", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text("14:00", style: TextStyle(color: Colors.grey))]),
            Text("2 nuits", style: TextStyle(color: Colors.grey)),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text("Départ", style: TextStyle(color: Colors.grey, fontSize: 12)), Text("17 avr.", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text("12:00", style: TextStyle(color: Colors.grey))]),
          ],
        ),
        const Divider(height: 32),
        _priceRow("2 nuits × 45 000 FCFA", "90 000 FCFA"),
        _priceRow("Petit-déjeuner (×2)", "5 000 FCFA"),
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
        _priceRow("Total", "95 000 FCFA", isBold: true),
        _priceRow("Déjà payé", "- 50 000 FCFA", color: Colors.green),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFFFF7E6), borderRadius: BorderRadius.circular(8)),
          child: _priceRow("Solde restant", "45 000 FCFA", isBold: true, color: const Color(0xFFD48806)),
        ),
      ],
    );
  }

  Widget _buildEquipements() {
    return Wrap(
      spacing: 8,
      children: ["Climatisation", "Wi-Fi", "TV satellite", "Salle de bain", "Vue mer"].map((e) => Chip(
        label: Text(e, style: const TextStyle(fontSize: 12)),
        backgroundColor: Colors.grey.shade100,
        side: BorderSide(color: Colors.grey.shade200),
      )).toList(),
    );
  }

  // Enlève "static" ici
  Widget _miniInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _priceRow(String label, String price, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isBold ? Colors.black : Colors.grey.shade700)),
          Text(price, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color ?? Colors.black)),
        ],
      ),
    );
  }
}