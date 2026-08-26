import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hotels/screens/facture_screen.dart'; // ✅ AJOUTÉ — pour "Émettre une facture"

// ═══════════════════════════════════════════════════════════════
// ✅ Contrôle d'accès — à utiliser dans votre écran de navigation
// (bottom nav / drawer) pour n'afficher l'onglet Caisse qu'aux
// utilisateurs Caissier, Admin ou Gérant.
//
// Exemple d'utilisation dans votre dashboard_screen.dart :
//
//   if (CaissePermissions.peutAccederCaisse(widget.user['role']))
//     BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: 'Caisse'),
//
// ═══════════════════════════════════════════════════════════════
class CaissePermissions {
  static bool peutAccederCaisse(String? role) {
    if (role == null) return false;
    final r = role.toLowerCase().trim();
    // ✅ Ajout de 'administrateur' dans les rôles autorisés
    return r == 'administrateur' || r == 'admin' || r == 'caissier' || r == 'gerant' || r == 'gérant';
  }
}

class CaisseScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;
  const CaisseScreen({super.key, required this.token, required this.user});

  @override
  State<CaisseScreen> createState() => _CaisseScreenState();
}

class _CaisseScreenState extends State<CaisseScreen> {
  static const String baseUrl = 'http://10.0.2.2:8000/api';
  final Color primaryGreen = const Color(0xFF0F6E56);

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${widget.token}',
  };

  bool loading = true;
  bool caisseOuverte = false;
  Map<String, dynamic>? sessionActuelle;
  double montantTheorique = 0;
  double totalEncaisseSession = 0;
  double totalRembourseSession = 0;

  Map<String, dynamic>? statsJour;
  List<dynamic> reservations = [];
  List<dynamic> historiquePaiements = [];

  @override
  void initState() {
    super.initState();
    chargerTout();
  }

  Future<void> chargerTout() async {
    setState(() => loading = true);
    await Future.wait([
      fetchStatutCaisse(),
      fetchStatsJour(),
      fetchReservations(),
      fetchHistoriquePaiements(),
    ]);
    if (mounted) setState(() => loading = false);
  }

  // ── Statut de la session de caisse ──────────────────────────
  Future<void> fetchStatutCaisse() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/caisse/statut'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (mounted) {
          setState(() {
            caisseOuverte = data['ouverte'] == true;
            sessionActuelle = data['session'];
            montantTheorique = double.tryParse(data['montant_theorique']?.toString() ?? '0') ?? 0;
            totalEncaisseSession = double.tryParse(data['total_encaisse']?.toString() ?? '0') ?? 0;
            totalRembourseSession = double.tryParse(data['total_rembourse']?.toString() ?? '0') ?? 0;
          });
        }
      }
    } catch (e) {
      print("Erreur statut caisse : $e");
    }
  }

  // ── Recette du jour (tous caissiers confondus) ──────────────
  Future<void> fetchStatsJour() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/paiements/stats'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200 && mounted) {
        setState(() => statsJour = jsonDecode(utf8.decode(res.bodyBytes)));
      }
    } catch (e) {
      print("Erreur stats jour : $e");
    }
  }

  Future<void> fetchReservations() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/reservations'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200 && mounted) {
        setState(() => reservations = jsonDecode(utf8.decode(res.bodyBytes)));
      }
    } catch (e) {
      print("Erreur réservations : $e");
    }
  }

  Future<void> fetchHistoriquePaiements() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/paiements?date=${DateTime.now().toIso8601String().split('T')[0]}'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200 && mounted) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        setState(() => historiquePaiements = decoded['data'] ?? []);
      }
    } catch (e) {
      print("Erreur historique paiements : $e");
    }
  }

  // ── Ouvrir la caisse ─────────────────────────────────────────
  Future<void> ouvrirCaisse(double fondOuverture) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/caisse/ouvrir'),
        headers: _headers,
        body: jsonEncode({'fond_ouverture': fondOuverture}),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 201) {
        _snack("✅ Caisse ouverte avec succès !", primaryGreen);
        await chargerTout();
      } else {
        _snack("❌ ${data['message'] ?? 'Erreur'}", Colors.red);
      }
    } catch (e) {
      _snack("❌ Erreur réseau : impossible de joindre le serveur", Colors.red);
    }
  }

  // ── Fermer la caisse ─────────────────────────────────────────
  Future<void> fermerCaisse(double montantReel, String note) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/caisse/fermer'),
        headers: _headers,
        body: jsonEncode({'montant_reel': montantReel, 'note': note}),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200) {
        final session = data['session'];
        final ecart = double.tryParse(session['ecart']?.toString() ?? '0') ?? 0;
        _snack(
          ecart == 0
              ? "✅ Caisse clôturée — aucun écart"
              : "⚠️ Caisse clôturée — écart de ${ecart.toStringAsFixed(0)} F",
          ecart == 0 ? primaryGreen : Colors.orange,
        );
        await chargerTout();
      } else {
        _snack("❌ ${data['message'] ?? 'Erreur'}", Colors.red);
      }
    } catch (e) {
      _snack("❌ Erreur réseau : impossible de joindre le serveur", Colors.red);
    }
  }

  // ── Enregistrer un paiement ──────────────────────────────────
  Future<bool> enregistrerPaiement({
    required String reservationId,
    required double montant,
    required String mode,
    String? note,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/paiements'),
        headers: _headers,
        body: jsonEncode({
          'reservation_id': reservationId,
          'montant': montant,
          'methode_paiement': mode,
          'note': note,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 201) {
        _snack("✅ Paiement de ${montant.toStringAsFixed(0)} F enregistré !", primaryGreen);
        await chargerTout();
        return true;
      } else {
        _snack("❌ ${data['message'] ?? 'Erreur'}", Colors.red);
        return false;
      }
    } catch (e) {
      _snack("❌ Erreur réseau : impossible de joindre le serveur", Colors.red);
      return false;
    }
  }

  // ── Enregistrer un remboursement ─────────────────────────────
  Future<bool> enregistrerRemboursement({
    required String reservationId,
    required double montant,
    required String mode,
    required String note,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/paiements/remboursement'),
        headers: _headers,
        body: jsonEncode({
          'reservation_id': reservationId,
          'montant': montant,
          'methode_paiement': mode,
          'note': note,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 201) {
        _snack("✅ Remboursement de ${montant.toStringAsFixed(0)} F enregistré !", Colors.orange);
        await chargerTout();
        return true;
      } else {
        _snack("❌ ${data['message'] ?? 'Erreur'}", Colors.red);
        return false;
      }
    } catch (e) {
      _snack("❌ Erreur réseau : impossible de joindre le serveur", Colors.red);
      return false;
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Garde-fou côté écran, en plus du filtrage de navigation
    if (!CaissePermissions.peutAccederCaisse(widget.user['role'])) {
      return Scaffold(
        appBar: AppBar(title: const Text("Caisse"), backgroundColor: primaryGreen),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              "🔒 Accès réservé au caissier, à l'admin ou au gérant.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: RefreshIndicator(
        onRefresh: chargerTout,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!caisseOuverte) _buildCaisseFermeeCard() else ...[
                      _buildSessionCard(),
                      const SizedBox(height: 16),
                      _buildActionsRow(),
                      const SizedBox(height: 24),
                    ],
                    _buildRecetteJourCard(),
                    const SizedBox(height: 24),
                    const Text("HISTORIQUE DU JOUR",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey, letterSpacing: 1.1)),
                    const SizedBox(height: 12),
                    if (historiquePaiements.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text("Aucune transaction aujourd'hui", style: TextStyle(color: Colors.grey))),
                      )
                    else
                      ...historiquePaiements.map((p) => _buildTransactionTile(p)),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: primaryGreen,
      padding: const EdgeInsets.only(top: 50, bottom: 20, left: 20, right: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.point_of_sale, color: Colors.white, size: 22),
              SizedBox(width: 10),
              Text("Caisse", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: caisseOuverte ? Colors.white : Colors.red.shade400,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              caisseOuverte ? "● Ouverte" : "● Fermée",
              style: TextStyle(
                color: caisseOuverte ? primaryGreen : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaisseFermeeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Icon(Icons.lock_clock, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text("La caisse est fermée", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          const Text("Ouvrez une session pour enregistrer des paiements", style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showOuvrirCaisseModal,
              icon: const Icon(Icons.lock_open, size: 18, color: Colors.white),
              label: const Text("Ouvrir la caisse", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: primaryGreen, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Montant théorique en caisse", style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text("${montantTheorique.toStringAsFixed(0)} FCFA",
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _sessionStat("Encaissé", "+${totalEncaisseSession.toStringAsFixed(0)} F")),
              Expanded(child: _sessionStat("Remboursé", "-${totalRembourseSession.toStringAsFixed(0)} F")),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sessionStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActionsRow() {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            icon: Icons.add_card,
            label: "Paiement",
            color: primaryGreen,
            onTap: _showPaiementModal,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionButton(
            icon: Icons.undo,
            label: "Remboursement",
            color: Colors.orange,
            onTap: _showRemboursementModal,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionButton(
            icon: Icons.lock,
            label: "Clôturer",
            color: Colors.redAccent,
            onTap: _showFermerCaisseModal,
          ),
        ),
      ],
    );
  }

  Widget _actionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildRecetteJourCard() {
    final total = double.tryParse(statsJour?['total_encaisse']?.toString() ?? '0') ?? 0;
    final rembourse = double.tryParse(statsJour?['total_rembourse']?.toString() ?? '0') ?? 0;
    final net = double.tryParse(statsJour?['recette_nette']?.toString() ?? '0') ?? 0;
    final repartition = (statsJour?['repartition_par_mode'] as List?) ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("RECETTE DU JOUR (tous caissiers)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey, letterSpacing: 1)),
          const SizedBox(height: 10),
          Text("${net.toStringAsFixed(0)} FCFA net", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryGreen)),
          const SizedBox(height: 4),
          Text("Encaissé : ${total.toStringAsFixed(0)} F · Remboursé : ${rembourse.toStringAsFixed(0)} F",
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          if (repartition.isNotEmpty) ...[
            const Divider(height: 24),
            ...repartition.map((r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(r['methode_paiement'] ?? '', style: const TextStyle(fontSize: 12)),
                  Text("${double.tryParse(r['total'].toString())?.toStringAsFixed(0) ?? 0} F",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> p) {
    final estRemboursement = p['type'] == 'remboursement';
    final nom = p['reservation']?['nom_client'] ?? 'Client';
    final montant = double.tryParse(p['montant']?.toString() ?? '0') ?? 0;
    final heure = DateTime.tryParse(p['created_at'] ?? '')?.toLocal();

    return InkWell(
      onTap: () {
        final id = p['id']?.toString();
        if (id == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => FactureScreen(token: widget.token, paiementId: id)),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: (estRemboursement ? Colors.orange : primaryGreen).withOpacity(0.1),
              child: Icon(estRemboursement ? Icons.undo : Icons.check, color: estRemboursement ? Colors.orange : primaryGreen, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nom, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  Text("${p['methode_paiement'] ?? ''} · ${p['numero_facture'] ?? ''}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${estRemboursement ? '-' : '+'}${montant.toStringAsFixed(0)} F",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: estRemboursement ? Colors.orange : primaryGreen),
                ),
                if (heure != null)
                  Text("${heure.hour.toString().padLeft(2, '0')}:${heure.minute.toString().padLeft(2, '0')}",
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey), // ✅ indique que la ligne est cliquable
          ],
        ),
      ),
    );
  }

  // ═══════════════════════ MODALS ═══════════════════════

  void _showOuvrirCaisseModal() {
    final fondController = TextEditingController(text: '0');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, top: 24, left: 20, right: 20),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Ouvrir la caisse", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryGreen)),
            const SizedBox(height: 16),
            TextField(
              controller: fondController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Fond de caisse initial (FCFA)",
                prefixIcon: const Icon(Icons.wallet, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final fond = double.tryParse(fondController.text.trim()) ?? 0;
                  Navigator.pop(ctx);
                  ouvrirCaisse(fond);
                },
                style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("Confirmer l'ouverture", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFermerCaisseModal() {
    final montantController = TextEditingController();
    final noteController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, top: 24, left: 20, right: 20),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Clôturer la caisse", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.redAccent)),
            const SizedBox(height: 8),
            Text("Montant théorique attendu : ${montantTheorique.toStringAsFixed(0)} F", style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: montantController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Montant réellement compté (FCFA)",
                prefixIcon: const Icon(Icons.calculate, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: "Note (optionnel)",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final montant = double.tryParse(montantController.text.trim());
                  if (montant == null) {
                    _snack("❌ Entrez un montant valide", Colors.red);
                    return;
                  }
                  Navigator.pop(ctx);
                  fermerCaisse(montant, noteController.text.trim());
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("Confirmer la clôture", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaiementModal() => _showTransactionModal(estRemboursement: false);
  void _showRemboursementModal() => _showTransactionModal(estRemboursement: true);

  void _showTransactionModal({required bool estRemboursement}) {
    String? reservationId;
    final montantController = TextEditingController();
    final noteController = TextEditingController();
    String mode = 'Espèces';
    final modes = ['Espèces', 'Orange Money', 'Wave', 'Carte bancaire'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, top: 24, left: 20, right: 20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  estRemboursement ? "Effectuer un remboursement" : "Enregistrer un paiement",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: estRemboursement ? Colors.orange : primaryGreen),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: reservationId,
                  hint: const Text("Sélectionner une réservation"),
                  isExpanded: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.receipt_long, color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: reservations.map<DropdownMenuItem<String>>((r) {
                    return DropdownMenuItem<String>(
                      value: r['id'].toString(),
                      child: Text(
                        "${r['nom_client']} — ${r['statut_paiement'] ?? 'Non payé'} (${r['montant_total']} F)",
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setModalState(() => reservationId = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: montantController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Montant (FCFA)",
                    prefixIcon: const Icon(Icons.payments, color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: mode,
                  decoration: InputDecoration(
                    labelText: "Mode de paiement",
                    prefixIcon: const Icon(Icons.wallet, color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: modes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setModalState(() => mode = v ?? 'Espèces'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: estRemboursement ? "Motif du remboursement (obligatoire)" : "Note (optionnel)",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final montant = double.tryParse(montantController.text.trim());
                      if (reservationId == null || montant == null || montant <= 0) {
                        _snack("❌ Sélectionnez une réservation et un montant valide", Colors.red);
                        return;
                      }
                      if (estRemboursement && noteController.text.trim().isEmpty) {
                        _snack("❌ Le motif est obligatoire pour un remboursement", Colors.red);
                        return;
                      }

                      bool ok;
                      if (estRemboursement) {
                        ok = await enregistrerRemboursement(
                          reservationId: reservationId!,
                          montant: montant,
                          mode: mode,
                          note: noteController.text.trim(),
                        );
                      } else {
                        ok = await enregistrerPaiement(
                          reservationId: reservationId!,
                          montant: montant,
                          mode: mode,
                          note: noteController.text.trim(),
                        );
                      }
                      if (ok && ctx.mounted) Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: estRemboursement ? Colors.orange : primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      estRemboursement ? "Confirmer le remboursement" : "Confirmer le paiement",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
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