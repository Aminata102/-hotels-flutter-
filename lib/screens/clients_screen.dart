import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String baseUrl = 'http://10.0.2.2:8000/api';
const Color kGreen = Color(0xFF0F6E56);

// ─────────────────────────────────────────────
// MODÈLE CLIENT
// ─────────────────────────────────────────────
class Client {
  final String id;
  final String nom;
  final String prenom;
  final String telephone;
  final String? email;
  final String? numeroCni;
  final String? nationalite;
  final String? ville;
  final String? statut; // en_sejour, recent, fidele
  final int? nombreSejours;
  final String? chambre;
  final String? typeChambre;
  final String? dateDepart;
  final String? statutPaiement;

  Client({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.telephone,
    this.email,
    this.numeroCni,
    this.nationalite,
    this.ville,
    this.statut,
    this.nombreSejours,
    this.chambre,
    this.typeChambre,
    this.dateDepart,
    this.statutPaiement,
  });

  String get nomComplet => '$prenom $nom';
  String get initiales {
    final p = prenom.isNotEmpty ? prenom[0].toUpperCase() : '';
    final n = nom.isNotEmpty ? nom[0].toUpperCase() : '';
    return '$p$n';
  }

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id']?.toString() ?? '',
      nom: json['nom'] ?? '',
      prenom: json['prenom'] ?? '',
      telephone: json['telephone'] ?? '',
      email: json['email'],
      numeroCni: json['numero_cni'] ?? json['cni'],
      nationalite: json['nationalite'],
      ville: json['ville'],
      statut: json['statut'],
      nombreSejours: json['nombre_sejours'] != null
          ? int.tryParse(json['nombre_sejours'].toString())
          : null,
      chambre: json['chambre']?['numero']?.toString(),
      typeChambre: json['chambre']?['type'],
      dateDepart: json['date_depart'],
      statutPaiement: json['statut_paiement'],
    );
  }
}

// ─────────────────────────────────────────────
// ÉCRAN PRINCIPAL
// ─────────────────────────────────────────────
class ClientsScreen extends StatefulWidget {
  final String? token;
  final Map<String, dynamic>? user;

  const ClientsScreen({super.key, this.token, this.user});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  String selectedFilter = 'Tous';
  List<Client> _clients = [];
  List<Client> _clientsFiltres = [];
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();

  // Stats
  int _totalClients = 0;
  int _enSejour = 0;
  int _fideles = 0;

  // ── RÔLES & PERMISSIONS STRICTES ──────────────
  bool get _canManageClients {
    if (widget.user == null || widget.user!.isEmpty) return false;

    final rawUser = widget.user!['user'] ?? widget.user!;
    final rawRole = rawUser['role'] ?? rawUser['role_name'] ?? rawUser['type'] ?? rawUser['profil'];

    String roleStr = '';

    if (rawRole is Map) {
      roleStr = (rawRole['code'] ?? rawRole['nom'] ?? rawRole['name'] ?? rawRole['slug'] ?? '').toString();
    } else if (rawRole != null) {
      roleStr = rawRole.toString();
    }

    roleStr = roleStr.toLowerCase().trim();

    if (roleStr == 'caissier' || roleStr == 'housekeeping' || roleStr.contains('caissier')) {
      return false;
    }

    return roleStr.contains('admin') ||
        roleStr.contains('gerant') ||
        roleStr.contains('gérant') ||
        roleStr.contains('recept') ||
        roleStr.contains('récept');
  }

  @override
  void initState() {
    super.initState();
    debugPrint("DEBUG - USER DANS CLIENTS_SCREEN: ${widget.user}");
    _fetchClients();
    _searchController.addListener(_applySearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── API ──────────────────────────────────────
  Future<void> _fetchClients() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/clients'),
        headers: {
          'Authorization': 'Bearer ${widget.token ?? ""}',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List list = data['data'] ?? data['clients'] ?? data ?? [];
        final stats = data['stats'] ?? {};

        setState(() {
          _clients = list.map((c) => Client.fromJson(c)).toList();
          _totalClients = int.tryParse(stats['total']?.toString() ?? '') ?? _clients.length;
          _enSejour = int.tryParse(stats['en_sejour']?.toString() ?? '') ??
              _clients.where((c) => c.statut == 'en_sejour').length;
          _fideles = int.tryParse(stats['fideles']?.toString() ?? '') ??
              _clients.where((c) => (c.nombreSejours ?? 0) >= 3).length;
          _loading = false;
        });
        _applyFilters();
      } else {
        _loadDemo();
      }
    } catch (e) {
      _loadDemo();
    }
  }

  Future<void> _ajouterClient(Map<String, String> data) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/clients'),
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
              content: Text('✅ Client ajouté avec succès !'),
              backgroundColor: kGreen,
            ),
          );
        }
        await _fetchClients();
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

  // ── FILTRES & RECHERCHE ────────────────────
  void _applySearch() => _applyFilters();

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _clientsFiltres = _clients.where((c) {
        final matchSearch = query.isEmpty ||
            c.nomComplet.toLowerCase().contains(query) ||
            c.telephone.contains(query) ||
            (c.numeroCni?.toLowerCase().contains(query) ?? false);

        final matchFilter = selectedFilter == 'Tous' ||
            (selectedFilter == 'En séjour' && c.statut == 'en_sejour') ||
            (selectedFilter == 'Fidèles' && (c.nombreSejours ?? 0) >= 3) ||
            (selectedFilter == 'Sénégalais' &&
                (c.nationalite?.toLowerCase() == 'sénégal' ||
                    c.nationalite?.toLowerCase() == 'senegal' ||
                    c.nationalite?.toLowerCase() == 'sénégalaise' ||
                    c.nationalite?.toLowerCase() == 'senegalaise')) ||
            (selectedFilter == 'Étrangers' &&
                c.nationalite?.toLowerCase() != 'sénégal' &&
                c.nationalite?.toLowerCase() != 'senegal' &&
                c.nationalite?.toLowerCase() != 'sénégalaise' &&
                c.nationalite?.toLowerCase() != 'senegalaise' &&
                c.nationalite != null);

        return matchSearch && matchFilter;
      }).toList();
    });
  }

  void _loadDemo() {
    final demoClients = [
      Client(id: '1', nom: 'Ndiaye', prenom: 'Aby', telephone: '+221 77 345 67 89',
          statut: 'en_sejour', nationalite: 'Sénégal', ville: 'Dakar',
          chambre: '07', typeChambre: 'Suite', dateDepart: '17 avr.',
          statutPaiement: 'du', nombreSejours: 1),
      Client(id: '2', nom: 'Kon', prenom: 'Oabu', telephone: '+221 76 123 45 67',
          statut: 'recent', nationalite: 'Sénégal', ville: 'Thiès',
          nombreSejours: 2),
    ];
    setState(() {
      _clients = demoClients;
      _totalClients = 2;
      _enSejour = 0;
      _fideles = 0;
      _loading = false;
    });
    _applyFilters();
  }

  // ── MODALE "+ NOUVEAU" ─────────────────────
  void _ouvrirFormulaireNouveauClient() {
    if (!_canManageClients) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Accès refusé : Seuls les réceptionnistes et gérants peuvent ajouter un client."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NouveauClientSheet(
        onSave: (data) async {
          Navigator.pop(ctx);
          await _ajouterClient(data);
        },
      ),
    );
  }

  // ── BUILD ─────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        if (!_canManageClients)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.amber.shade800,
            child: const Text(
              "Mode lecture seule : Vous n'avez pas les droits pour ajouter des clients.",
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
        _buildStatsTop(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kGreen))
              : RefreshIndicator(
            color: kGreen,
            onRefresh: _fetchClients,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 16),
                  _buildFilterChips(),
                  const SizedBox(height: 24),
                  _buildListeClients(),
                  const SizedBox(height: 24),
                  _buildRepartitionCard(),
                  const SizedBox(height: 24),
                ],
              ),
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
            "Clients",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (_canManageClients)
            ElevatedButton.icon(
              onPressed: _ouvrirFormulaireNouveauClient,
              icon: const Icon(Icons.add, size: 16, color: kGreen),
              label: const Text(
                "Nouveau Client",
                style: TextStyle(
                  fontSize: 12,
                  color: kGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsTop() {
    return Container(
      color: kGreen,
      padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      child: Row(
        children: [
          _statTopItem(_totalClients.toString(), "Total clients"),
          _statTopItem(_enSejour.toString(), "En séjour"),
          _statTopItem(_fideles.toString(), "Fidèles"),
        ],
      ),
    );
  }

  Widget _statTopItem(String val, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: "Rechercher par nom, téléphone ou CNI...",
        prefixIcon: const Icon(Icons.search, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['Tous', 'En séjour', 'Fidèles', 'Sénégalais', 'Étrangers'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters
            .map((f) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(f,
                style: TextStyle(
                    color: selectedFilter == f ? Colors.white : Colors.black87,
                    fontSize: 12)),
            selected: selectedFilter == f,
            onSelected: (s) {
              setState(() => selectedFilter = f);
              _applyFilters();
            },
            selectedColor: kGreen,
            backgroundColor: Colors.white,
            shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade300)),
          ),
        ))
            .toList(),
      ),
    );
  }

  Widget _buildListeClients() {
    final enSejour = _clientsFiltres.where((c) => c.statut == 'en_sejour').toList();
    final autres = _clientsFiltres.where((c) => c.statut != 'en_sejour').toList();

    if (_clientsFiltres.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.people_outline, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text('Aucun client trouvé',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (enSejour.isNotEmpty) ...[
          const Text("EN SÉJOUR ACTUELLEMENT",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          ...enSejour.map((c) => _buildClientCard(c)).toList(),
          const SizedBox(height: 24),
        ],
        if (autres.isNotEmpty) ...[
          const Text("CLIENTS RÉCENTS",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          ...autres.map((c) => _buildClientCard(c)).toList(),
        ],
      ],
    );
  }

  Widget _buildClientCard(Client c) {
    final badges = _buildBadges(c);
    final details = _buildDetails(c);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.withOpacity(0.1),
            child: Text(c.initiales,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(c.nomComplet,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(width: 8),
                  ...badges,
                ]),
                const SizedBox(height: 4),
                Text(details,
                    style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.4)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
        ],
      ),
    );
  }

  List<Widget> _buildBadges(Client c) {
    final badges = <Widget>[];
    if (c.statut == 'en_sejour') badges.add(_badge("En séjour", Colors.green));
    if (c.statut == 'checkout') badges.add(_badge("Check-out", Colors.blue));
    if (c.statutPaiement == 'du') badges.add(_badge("Paiement dû", Colors.orange));
    if ((c.nombreSejours ?? 0) >= 3) badges.add(_badge("Fidèle", Colors.deepPurple));
    if (c.nationalite != null &&
        c.nationalite!.toLowerCase() != 'sénégal' &&
        c.nationalite!.toLowerCase() != 'senegal' &&
        c.nationalite!.toLowerCase() != 'sénégalaise' &&
        c.nationalite!.toLowerCase() != 'senegalaise') {
      badges.add(_badge("Étranger", Colors.grey));
    }
    return badges;
  }

  String _buildDetails(Client c) {
    if (c.statut == 'en_sejour' || c.statut == 'checkout') {
      return 'Ch. ${c.chambre ?? '?'} · ${c.typeChambre ?? ''} · Départ ${c.dateDepart ?? '?'}\n${c.telephone} · ${c.ville ?? ''}';
    }
    return '${c.nombreSejours ?? 0} séjour(s) · ${c.telephone}\n${c.ville ?? ''}';
  }

  Widget _badge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildRepartitionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Répartition des clients",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          _progressRow("Sénégalais", 0.68, "68%", kGreen),
          _progressRow("Africains (hors SN)", 0.18, "18%", Colors.blue),
          _progressRow("Européens", 0.11, "11%", Colors.deepPurple),
          _progressRow("Autres", 0.03, "3%", Colors.grey),
        ],
      ),
    );
  }

  Widget _progressRow(String label, double val, String percent, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(percent, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
              value: val,
              backgroundColor: Colors.grey[100],
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// BOTTOM SHEET — FORMULAIRE NOUVEAU CLIENT
// ─────────────────────────────────────────────
class _NouveauClientSheet extends StatefulWidget {
  final Future<void> Function(Map<String, String> data) onSave;
  const _NouveauClientSheet({required this.onSave});

  @override
  State<_NouveauClientSheet> createState() => _NouveauClientSheetState();
}

class _NouveauClientSheetState extends State<_NouveauClientSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  final _prenomCtrl = TextEditingController();
  final _nomCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _cniCtrl = TextEditingController();
  final _villeCtrl = TextEditingController();

  // Valeur par défaut mise à jour vers 'Sénégal'
  String _pays = 'Sénégal';

  // Liste remplacée par les noms de pays
  final List<String> _paysList = [
    'Sénégal',
    'Mali',
    'Guinée',
    'Côte d\'Ivoire',
    'Mauritanie',
    'Gambie',
    'France',
    'Autre',
  ];

  @override
  void dispose() {
    _prenomCtrl.dispose();
    _nomCtrl.dispose();
    _telCtrl.dispose();
    _emailCtrl.dispose();
    _cniCtrl.dispose();
    _villeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    await widget.onSave({
      'prenom': _prenomCtrl.text.trim(),
      'nom': _nomCtrl.text.trim(),
      'telephone': _telCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'numero_cni': _cniCtrl.text.trim(),
      'nationalite': _pays, // Envoie le pays sélectionné
      'ville': _villeCtrl.text.trim(),
    });

    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
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
                child: Column(
                  children: [
                    Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: Colors.white38, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Icon(Icons.person_add_outlined, color: Colors.white, size: 22),
                        SizedBox(width: 8),
                        Text("Nouveau client",
                            style: TextStyle(
                                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            controller: _prenomCtrl,
                            label: 'Prénom *',
                            icon: Icons.person_outline,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(
                            controller: _nomCtrl,
                            label: 'Nom *',
                            icon: Icons.person_outline,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _field(
                      controller: _telCtrl,
                      label: 'Téléphone *',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      hint: '+221 77 000 00 00',
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                    ),
                    const SizedBox(height: 16),

                    _field(
                      controller: _emailCtrl,
                      label: 'Email (optionnel)',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),

                    _field(
                      controller: _cniCtrl,
                      label: 'N° CNI / Passeport',
                      icon: Icons.badge_outlined,
                      hint: 'Ex: 1 234 567 890',
                    ),
                    const SizedBox(height: 16),

                    // Champ déroulant mis à jour avec le label 'Pays' et la liste des pays
                    DropdownButtonFormField<String>(
                      value: _pays,
                      decoration: InputDecoration(
                        labelText: 'Pays',
                        prefixIcon: const Icon(Icons.flag_outlined, color: kGreen),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: kGreen, width: 2)),
                      ),
                      items: _paysList
                          .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                          .toList(),
                      onChanged: (v) => setState(() => _pays = v ?? _pays),
                    ),
                    const SizedBox(height: 16),

                    _field(
                      controller: _villeCtrl,
                      label: 'Ville',
                      icon: Icons.location_city_outlined,
                      hint: 'Ex: Dakar',
                    ),
                    const SizedBox(height: 28),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.grey.shade400),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Annuler',
                                style: TextStyle(color: Colors.grey, fontSize: 14)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kGreen,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _saving
                                ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                                : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check, color: Colors.white, size: 18),
                                SizedBox(width: 6),
                                Text('Enregistrer',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: kGreen, size: 20),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kGreen, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red)),
      ),
    );
  }
}