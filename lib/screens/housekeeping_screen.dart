import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String _baseUrl = 'http://10.0.2.2:8000/api';
const Color kGreen = Color(0xFF0F6E56);

// ─────────────────────────────────────────────
// MODÈLE CHAMBRE (léger, propre à cet écran)
// ─────────────────────────────────────────────
class ChambreMenage {
  final String id;
  final String numero;
  final String type;
  final int etage;
  String statut; // disponible, occupee, nettoyage, propre, maintenance

  ChambreMenage({
    required this.id,
    required this.numero,
    required this.type,
    required this.etage,
    required this.statut,
  });

  factory ChambreMenage.fromJson(Map<String, dynamic> json) {
    return ChambreMenage(
      id: json['id']?.toString() ?? '',
      numero: json['numero']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Simple',
      etage: int.tryParse(json['etage']?.toString() ?? '1') ?? 1,
      statut: (json['statut'] ?? 'disponible').toString(),
    );
  }
}

// ─────────────────────────────────────────────
// ÉCRAN PRINCIPAL HOUSEKEEPING
// ─────────────────────────────────────────────
class HousekeepingScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const HousekeepingScreen({super.key, required this.token, required this.user});

  @override
  State<HousekeepingScreen> createState() => _HousekeepingScreenState();
}

class _HousekeepingScreenState extends State<HousekeepingScreen> {
  List<ChambreMenage> _chambres = [];
  bool _loading = true;
  String _filtre = 'À nettoyer'; // À nettoyer / Propres / Toutes

  // Stockage local temporaire (pas encore d'API dédiée) :
  final List<Map<String, dynamic>> _incidentsSignales = [];
  int _nettoyeesAujourdHui = 0;

  // ── PERMISSIONS ──────────────────────────────
  bool get _estMenage {
    if (widget.user.isEmpty) return false;
    final rawUser = widget.user['user'] ?? widget.user;
    final rawRole = rawUser['role'] ?? rawUser['roles'] ?? rawUser['role_name'] ?? rawUser['type'] ?? rawUser['profil'];

    String roleStr = '';
    if (rawRole is List && rawRole.isNotEmpty) {
      roleStr = rawRole.map((r) => r is Map ? (r['name'] ?? r['nom'] ?? r['code'] ?? '') : r.toString()).join(' ');
    } else if (rawRole is Map) {
      roleStr = (rawRole['code'] ?? rawRole['nom'] ?? rawRole['name'] ?? rawRole['slug'] ?? '').toString();
    } else if (rawRole != null) {
      roleStr = rawRole.toString();
    }
    roleStr = roleStr.toLowerCase().trim();

    return roleStr.contains('housekeeping') ||
        roleStr.contains('menage') ||
        roleStr.contains('ménage') ||
        roleStr.contains('femme de chambre') ||
        roleStr.contains('admin') ||
        roleStr.contains('gerant') ||
        roleStr.contains('gérant');
  }

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${widget.token}',
  };

  @override
  void initState() {
    super.initState();
    _fetchChambres();
  }

  // ── Extraction robuste List/Map ────────────────
  List<dynamic> _extraireListe(dynamic decoded, List<String> cles) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      for (final cle in cles) {
        final val = decoded[cle];
        if (val is List) return val;
      }
    }
    return [];
  }

  // ── API : récupération des chambres ────────────
  Future<void> _fetchChambres() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/chambres'), headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final list = _extraireListe(decoded, ['data', 'chambres']);
        if (mounted) {
          setState(() {
            _chambres = list.map((c) => ChambreMenage.fromJson(c)).toList();
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint("Erreur de récupération des chambres (housekeeping) : $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── API : mettre à jour le statut d'une chambre ─
  Future<void> _mettreAJourStatut(ChambreMenage chambre, String nouveauStatut) async {
    final ancienStatut = chambre.statut;
    setState(() => chambre.statut = nouveauStatut); // optimiste

    try {
      final res = await http
          .put(
        Uri.parse('$_baseUrl/chambres/${chambre.id}'),
        headers: _headers,
        body: jsonEncode({'statut': nouveauStatut}),
      )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200 || res.statusCode == 204) {
        if (nouveauStatut == 'disponible' || nouveauStatut == 'propre') {
          setState(() => _nettoyeesAujourdHui++);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ Chambre ${chambre.numero} passée au statut « $nouveauStatut »"),
              backgroundColor: kGreen,
            ),
          );
        }
      } else {
        setState(() => chambre.statut = ancienStatut); // rollback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("❌ Erreur serveur (${res.statusCode}) lors de la mise à jour"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => chambre.statut = ancienStatut); // rollback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Erreur réseau : $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  List<ChambreMenage> get _chambresFiltrees {
    switch (_filtre) {
      case 'À nettoyer':
        return _chambres.where((c) => c.statut == 'nettoyage').toList();
      case 'Propres':
      // Affiche les chambres prêtes/disponibles et propres
        return _chambres.where((c) => c.statut == 'propre' || c.statut == 'disponible').toList();
      default:
        return _chambres;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_estMenage) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "❌ Accès réservé au personnel de ménage.",
            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final aNettoyer = _chambres.where((c) => c.statut == 'nettoyage').length;

    return Column(
      children: [
        _buildHeader(),
        _buildStats(aNettoyer),
        _buildFiltres(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kGreen))
              : RefreshIndicator(
            color: kGreen,
            onRefresh: _fetchChambres,
            child: _chambresFiltrees.isEmpty
                ? ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(
                    child: Text(
                      "Aucune chambre dans cette catégorie 🎉",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _chambresFiltrees.length,
              itemBuilder: (context, i) => _buildChambreCard(_chambresFiltrees[i]),
            ),
          ),
        ),
      ],
    );
  }

  // ── HEADER ──────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: kGreen,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Planification du nettoyage",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          IconButton(
            tooltip: "Modifier mon profil",
            icon: const Icon(Icons.person_outline, color: Colors.white),
            onPressed: _ouvrirModifierProfil,
          ),
        ],
      ),
    );
  }

  void _ouvrirModifierProfil() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("➡️ Navigation vers l'écran d'édition de profil."),
      ),
    );
  }

  Widget _buildStats(int aNettoyer) {
    return Container(
      color: kGreen,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: Row(
        children: [
          _statItem(aNettoyer.toString(), "À nettoyer"),
          _statItem(_nettoyeesAujourdHui.toString(), "Nettoyées aujourd'hui"),
          _statItem(_incidentsSignales.length.toString(), "Incidents signalés"),
        ],
      ),
    );
  }

  Widget _statItem(String val, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltres() {
    final filtres = ['À nettoyer', 'Propres', 'Toutes'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filtres.map((f) {
            final isSel = _filtre == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f, style: TextStyle(fontSize: 12, color: isSel ? Colors.white : Colors.black87)),
                selected: isSel,
                onSelected: (_) => setState(() => _filtre = f),
                selectedColor: kGreen,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── CARTE CHAMBRE ────────────────────────────
  Widget _buildChambreCard(ChambreMenage c) {
    Color badgeColor;
    String label;
    switch (c.statut) {
      case 'nettoyage':
        badgeColor = Colors.orange;
        label = "À nettoyer";
        break;
      case 'propre':
      case 'disponible':
        badgeColor = Colors.green;
        label = "Disponible";
        break;
      case 'occupee':
        badgeColor = Colors.redAccent;
        label = "Occupée";
        break;
      case 'maintenance':
        badgeColor = Colors.blueGrey;
        label = "Maintenance";
        break;
      default:
        badgeColor = Colors.grey;
        label = "Disponible";
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: kGreen.withOpacity(0.1),
                  child: Text(c.numero, style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Chambre ${c.numero} - ${c.type}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text("Étage ${c.etage}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(label, style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // BOUTON ACTION PRINCIPAL : Valider le nettoyage -> Passe la chambre à "disponible"
                if (c.statut == 'nettoyage')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _mettreAJourStatut(c, 'disponible'),
                      icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                      label: const Text("Marquer nettoyée & disponible", style: TextStyle(fontSize: 11, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                // SI DEJA DISPONIBLE OU PROPRE : Possibilité de repasser en nettoyage en cas de besoin
                if (c.statut == 'disponible' || c.statut == 'propre')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _mettreAJourStatut(c, 'nettoyage'),
                      icon: const Icon(Icons.replay, size: 16, color: kGreen),
                      label: const Text("Repasser à nettoyer", style: TextStyle(fontSize: 12, color: kGreen)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kGreen),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: "Linge et fournitures",
                  onPressed: () => _ouvrirLingeEtFournitures(c),
                  icon: const Icon(Icons.checkroom, color: kGreen),
                ),
                IconButton(
                  tooltip: "Signaler un incident",
                  onPressed: () => _ouvrirSignalerIncident(c),
                  icon: const Icon(Icons.report_problem_outlined, color: Colors.redAccent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── "Gérer linge et fournitures" ──
  void _ouvrirLingeEtFournitures(ChambreMenage c) {
    final items = {
      'Draps changés': false,
      'Serviettes': false,
      'Savon / Shampoing': false,
      'Papier toilette': false,
      'Eau minérale': false,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Linge & fournitures — Ch. ${c.numero}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kGreen)),
              const SizedBox(height: 12),
              ...items.keys.map((k) => CheckboxListTile(
                value: items[k],
                onChanged: (v) => setModalState(() => items[k] = v ?? false),
                title: Text(k, style: const TextStyle(fontSize: 13)),
                activeColor: kGreen,
                contentPadding: EdgeInsets.zero,
              )),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("✅ Checklist enregistrée pour la chambre ${c.numero}")),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: kGreen),
                  child: const Text("Valider", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── "Signaler un incident" ───────────────────
  void _ouvrirSignalerIncident(ChambreMenage c) {
    final descCtrl = TextEditingController();
    String gravite = 'Faible';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.report_problem_outlined, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Text("Incident — Chambre ${c.numero}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: gravite,
                  items: ['Faible', 'Moyenne', 'Urgente']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) => setModalState(() => gravite = v ?? gravite),
                  decoration: const InputDecoration(labelText: 'Gravité'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description de l\'incident',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (descCtrl.text.trim().isEmpty) return;

                      setState(() {
                        _incidentsSignales.add({
                          'chambre_id': c.id,
                          'chambre_numero': c.numero,
                          'gravite': gravite,
                          'description': descCtrl.text.trim(),
                          'date': DateTime.now().toIso8601String(),
                        });
                      });

                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("🚨 Incident signalé pour la chambre ${c.numero}"),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    child: const Text("Signaler", style: TextStyle(color: Colors.white)),
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