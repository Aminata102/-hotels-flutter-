import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String baseUrl = 'http://10.0.2.2:8000/api';
const Color kGreen = Color(0xFF0F6E56);

// ─────────────────────────────────────────────
// MODÈLE CHAMBRE
// ─────────────────────────────────────────────
class Chambre {
  final String id;
  final String numero;
  final String type; // Simple, Double, Suite, VIP
  final double prixNuit;
  final String statut; // disponible, occupee, nettoyage, maintenance
  final int etage;
  final String? description;

  Chambre({
    required this.id,
    required this.numero,
    required this.type,
    required this.prixNuit,
    required this.statut,
    required this.etage,
    this.description,
  });

  factory Chambre.fromJson(Map<String, dynamic> json) {
    return Chambre(
      id: json['id']?.toString() ?? '',
      numero: json['numero']?.toString() ?? '',
      type: json['type'] ?? 'Simple',
      prixNuit: double.tryParse(
          json['prix_nuit']?.toString() ?? json['prix_nuitee']?.toString() ?? json['prix']?.toString() ?? '0') ??
          0.0,
      statut: json['statut'] ?? 'disponible',
      etage: int.tryParse(json['etage']?.toString() ?? '1') ?? 1,
      description: json['description'],
    );
  }
}

// ─────────────────────────────────────────────
// ÉCRAN PRINCIPAL CHAMBRES
// ─────────────────────────────────────────────
class ChambresScreen extends StatefulWidget {
  final String? token;
  final Map<String, dynamic>? user;

  const ChambresScreen({super.key, this.token, this.user});

  @override
  State<ChambresScreen> createState() => _ChambresScreenState();
}

class _ChambresScreenState extends State<ChambresScreen> {
  List<Chambre> _chambres = [];
  List<Chambre> _chambresFiltrees = [];
  bool _loading = true;
  String _filtreStatut = 'Tous';

  // ── PERMISSIONS ROLES STRICTES (BLINDÉES) ──────────────
  bool get _canManageChambres {
    if (widget.user == null || widget.user!.isEmpty) return false;

    // 1. Recherche globale dans tout le JSON utilisateur (Garantit l'accès pour Admin / Gérant)
    final userJsonString = jsonEncode(widget.user).toLowerCase();
    if (userJsonString.contains('admin') ||
        userJsonString.contains('gerant') ||
        userJsonString.contains('gérant')) {
      return true;
    }

    // 2. Extraction ciblée du rôle pour les autres profils
    final rawUser = widget.user!['user'] ?? widget.user!;
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

    // 3. Exclure explicitement le caissier et le personnel d'entretien
    if (roleStr == 'caissier' || roleStr == 'housekeeping' || roleStr.contains('caissier')) {
      return false;
    }

    // 4. Autoriser le réceptionniste
    return roleStr.contains('recept') || roleStr.contains('récept');
  }

  @override
  void initState() {
    super.initState();
    _fetchChambres();
  }

  // ── API ──────────────────────────────────────
  Future<void> _fetchChambres() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/chambres'),
        headers: {
          'Authorization': 'Bearer ${widget.token ?? ""}',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List list = data['data'] ?? data['chambres'] ?? data ?? [];

        setState(() {
          _chambres = list.map((c) => Chambre.fromJson(c)).toList();
          _loading = false;
        });
        _filtrerChambres();
      } else {
        _loadDemo();
      }
    } catch (e) {
      _loadDemo();
    }
  }

  Future<void> _ajouterChambre(Map<String, dynamic> data) async {
    if (!_canManageChambres) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("❌ Accès refusé : Vous n'avez pas les privilèges pour effectuer cette action."),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/chambres'),
        headers: {
          'Authorization': 'Bearer ${widget.token ?? ""}',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Chambre ajoutée avec succès !'),
              backgroundColor: kGreen,
            ),
          );
        }
        await _fetchChambres();
      } else {
        final body = jsonDecode(res.body);
        final msg = body['message'] ?? 'Erreur lors de l\'ajout';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ $msg'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur réseau : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _filtrerChambres() {
    setState(() {
      if (_filtreStatut == 'Tous') {
        _chambresFiltrees = _chambres;
      } else {
        _chambresFiltrees = _chambres.where((c) => c.statut == _filtreStatut).toList();
      }
    });
  }

  void _loadDemo() {
    setState(() {
      _chambres = [
        Chambre(id: '1', numero: '101', type: 'Simple', prixNuit: 25000, statut: 'disponible', etage: 1),
        Chambre(id: '2', numero: '102', type: 'Double', prixNuit: 35000, statut: 'occupee', etage: 1),
        Chambre(id: '3', numero: '201', type: 'Suite', prixNuit: 60000, statut: 'disponible', etage: 2),
      ];
      _chambresFiltrees = _chambres;
      _loading = false;
    });
  }

  // ── FORMULAIRE ──────────────────────────────
  void _ouvrirFormulaireNouvelleChambre() {
    if (!_canManageChambres) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Vous n'avez pas les privilèges pour ajouter une chambre."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NouvelleChambreSheet(
        onSave: (data) async {
          Navigator.pop(ctx);
          await _ajouterChambre(data);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        if (!_canManageChambres)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.amber.shade800,
            child: const Text(
              "Mode lecture seule : Vous n'avez pas les droits de gestion des chambres.",
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kGreen))
              : RefreshIndicator(
            color: kGreen,
            onRefresh: _fetchChambres,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _chambresFiltrees.length,
              itemBuilder: (context, index) {
                final chambre = _chambresFiltrees[index];
                return _buildChambreCard(chambre);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      color: kGreen,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Chambres",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          if (_canManageChambres)
            ElevatedButton.icon(
              onPressed: _ouvrirFormulaireNouvelleChambre,
              icon: const Icon(Icons.add, size: 16, color: kGreen),
              label: const Text(
                "Nouvelle Chambre",
                style: TextStyle(fontSize: 12, color: kGreen, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChambreCard(Chambre c) {
    Color badgeColor = Colors.green;
    String statusText = "Disponible";

    if (c.statut == 'occupee') {
      badgeColor = Colors.red;
      statusText = "Occupée";
    } else if (c.statut == 'maintenance') {
      badgeColor = Colors.orange;
      statusText = "Maintenance";
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: kGreen.withOpacity(0.1),
          child: Text(c.numero, style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
        ),
        title: Text("Chambre ${c.numero} - ${c.type}", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Étage ${c.etage} • ${c.prixNuit.toStringAsFixed(0)} FCFA / nuit"),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            statusText,
            style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MODALE FORMULAIRE : NOUVELLE CHAMBRE
// ─────────────────────────────────────────────
class _NouvelleChambreSheet extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic> data) onSave;
  const _NouvelleChambreSheet({required this.onSave});

  @override
  State<_NouvelleChambreSheet> createState() => _NouvelleChambreSheetState();
}

class _NouvelleChambreSheetState extends State<_NouvelleChambreSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  final _numeroCtrl = TextEditingController();
  final _prixCtrl = TextEditingController();
  final _etageCtrl = TextEditingController(text: '1');
  final _descCtrl = TextEditingController();

  String _type = 'Simple';
  String _statut = 'disponible';

  final List<String> _types = ['Simple', 'Double', 'Suite', 'VIP'];

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _prixCtrl.dispose();
    _etageCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final double valPrix = double.tryParse(_prixCtrl.text.trim()) ?? 0;

    await widget.onSave({
      'numero': _numeroCtrl.text.trim(),
      'type': _type,
      'prix_nuit': valPrix,
      'prix_nuitee': valPrix,
      'etage': int.tryParse(_etageCtrl.text.trim()) ?? 1,
      'statut': _statut,
      'description': _descCtrl.text.trim(),
    });

    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: kGreen,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.king_bed_outlined, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text("Ajouter une Chambre",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(20),
                  children: [
                    TextFormField(
                      controller: _numeroCtrl,
                      keyboardType: TextInputType.number,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Numéro requis' : null,
                      decoration: const InputDecoration(
                        labelText: 'Numéro de chambre *',
                        prefixIcon: Icon(Icons.meeting_room, color: kGreen),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _type,
                      items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _type = v ?? _type),
                      decoration: const InputDecoration(
                        labelText: 'Type de chambre',
                        prefixIcon: Icon(Icons.category, color: kGreen),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _prixCtrl,
                      keyboardType: TextInputType.number,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Prix requis' : null,
                      decoration: const InputDecoration(
                        labelText: 'Prix par nuit (FCFA) *',
                        prefixIcon: Icon(Icons.payments, color: kGreen),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _etageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Étage',
                        prefixIcon: Icon(Icons.layers, color: kGreen),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Enregistrer la Chambre', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}