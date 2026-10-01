import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hotels/screens/chambres_screen.dart';
import 'package:hotels/screens/reservations_screen.dart';
import 'package:hotels/screens/clients_screen.dart';
import 'package:hotels/screens/parametres_screen.dart';
import 'package:hotels/screens/caisse_screen.dart';
import 'package:hotels/screens/housekeeping_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hotels/models/dashboard_data.dart';

const String baseUrl = 'http://10.0.2.2:8000/api';

const Color kGreen = Color(0xFF0F6E56);
const Color kAmber = Color(0xFFBA7517);
const Color kBlue  = Color(0xFF185FA5);
const Color kBg    = Color(0xFFF5F5F0);
const Color kCard  = Color(0xFFFFFFFF);

// Structure pour décrire un onglet de navigation
class _NavEntry {
  final IconData icon;
  final String label;
  final Widget Function() builder;
  const _NavEntry({required this.icon, required this.label, required this.builder});
}

class DashboardScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;
  const DashboardScreen({super.key, required this.token, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  DashboardData? _dashboardData;
  bool _loading = true;

  bool get _peutVoirCaisse {
    final role = _roleStr;
    return CaissePermissions.peutAccederCaisse(role) || role.contains('caissier') || role.contains('caisse') || role.contains('administrateur') || role.contains('admin');
  }

  // Extraction du rôle brut (réutilisée par les getters de permissions)
  String get _roleStr {
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
    return roleStr.toLowerCase().trim();
  }

  // 🧹 Rôle Housekeeping / Ménage : navigation dédiée et restreinte
  bool get _estMenage {
    return _roleStr.contains('housekeeping') ||
        _roleStr.contains('menage') ||
        _roleStr.contains('ménage') ||
        _roleStr.contains('femme de chambre');
  }

  // 💳 Rôle Caissier : restreint la vue aux onglets Accueil, Caisse et Params
  bool get _estCaissier {
    return _roleStr.contains('caissier') || _roleStr.contains('caisse');
  }

  // 👑 Admin / Gérant : accès total, y compris l'onglet Ménage
  bool get _estAdminOuGerant {
    return _roleStr.contains('admin') || _roleStr.contains('gerant') || _roleStr.contains('gérant');
  }

  late final List<_NavEntry> _navEntries = _buildNavEntries();

  List<_NavEntry> _buildNavEntries() {
    // 🧹 Navigation restreinte pour le personnel de ménage
    if (_estMenage) {
      return [
        _NavEntry(icon: Icons.grid_view_rounded, label: 'Accueil', builder: () => _buildHomeContent()),
        _NavEntry(
          icon: Icons.cleaning_services_outlined,
          label: 'Ménage',
          builder: () => HousekeepingScreen(token: widget.token, user: widget.user),
        ),
        _NavEntry(icon: Icons.settings_outlined, label: 'Params', builder: () => ParametresScreen(user: widget.user, token: widget.token)),
      ];
    }

    // 💳 Navigation restreinte pour le rôle Caissier :
    // Uniquement Accueil, Caisse et Paramètres
    if (_estCaissier) {
      return [
        _NavEntry(icon: Icons.grid_view_rounded, label: 'Accueil', builder: () => _buildHomeContent()),
        _NavEntry(
          icon: Icons.point_of_sale,
          label: 'Caisse',
          builder: () => CaisseScreen(token: widget.token, user: widget.user),
        ),
        _NavEntry(icon: Icons.settings_outlined, label: 'Params', builder: () => ParametresScreen(user: widget.user, token: widget.token)),
      ];
    }

    // 🔵 Navigation complète (Admin, Gérant, Réceptionniste, etc.)
    final entries = <_NavEntry>[
      _NavEntry(icon: Icons.grid_view_rounded, label: 'Accueil', builder: () => _buildHomeContent()),
      _NavEntry(icon: Icons.bed_outlined, label: 'Chambres', builder: () => ChambresScreen(token: widget.token, user: widget.user)),
      _NavEntry(icon: Icons.calendar_month, label: 'Réservations', builder: () => ReservationsScreen(token: widget.token, user: widget.user)),
      _NavEntry(icon: Icons.people_outline, label: 'Clients', builder: () => ClientsScreen(token: widget.token, user: widget.user)),
    ];

    if (_peutVoirCaisse) {
      entries.add(_NavEntry(
        icon: Icons.point_of_sale,
        label: 'Caisse',
        builder: () => CaisseScreen(token: widget.token, user: widget.user),
      ));
    }

    // 🧹 L'admin/gérant garde aussi accès à l'onglet Ménage
    if (_estAdminOuGerant) {
      entries.add(_NavEntry(
        icon: Icons.cleaning_services_outlined,
        label: 'Ménage',
        builder: () => HousekeepingScreen(token: widget.token, user: widget.user),
      ));
    }

    entries.add(_NavEntry(icon: Icons.settings_outlined, label: 'Params', builder: () => ParametresScreen(user: widget.user, token: widget.token)));

    return entries;
  }

  int _indexOf(String label) => _navEntries.indexWhere((e) => e.label == label);

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  // --- ACTIONS EXTERNES ---
  Future<void> _ouvrirVitrineWeb() async {
    final Uri url = Uri.parse('https://www.youtube.com');

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir l\'espace médias')),
      );
    }
  }

  // --- LOGIQUE DE NAVIGATION ---
  Widget _getBodyContent() {
    if (_currentIndex < 0 || _currentIndex >= _navEntries.length) {
      return _buildHomeContent();
    }
    return _navEntries[_currentIndex].builder();
  }

  // --- CONTENU PRINCIPAL DU DASHBOARD (ACCUEIL) ---
  Widget _buildHomeContent() {
    if (_loading || _dashboardData == null) {
      return const Center(child: CircularProgressIndicator(color: kGreen));
    }
    return RefreshIndicator(
      color: kGreen,
      onRefresh: _fetchDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGreeting(),
            const SizedBox(height: 16),
            _buildStatsGrid(),
            const SizedBox(height: 16),
            _buildAccesRapide(),
            const SizedBox(height: 16),
            _buildVitrineBanner(),
            const SizedBox(height: 16),
            _buildReservationsCard(),
            const SizedBox(height: 16),
            _buildAlertes(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _getBodyContent(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // --- FONCTIONS DE DONNÉES ---
  Future<void> _fetchDashboard() async {
    if (!mounted) return;
    setState(() { _loading = true; });

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/dashboard'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final decodedData = jsonDecode(res.body);
        setState(() {
          _dashboardData = DashboardData.fromJson(decodedData);
          _loading = false;
        });
      } else {
        _loadDemo();
      }
    } catch (e) {
      print('Erreur de connexion : $e');
      _loadDemo();
    }
  }

  void _loadDemo() {
    setState(() {
      _dashboardData = DashboardData.fromJson(_demoData());
      _loading = false;
    });
  }

  // --- WIDGETS DE COMPOSANTS ---

  Widget _buildHeader() {
    final prenom = widget.user['prenom'] ?? 'Admin';
    final hotel  = widget.user['hotel']?['nom'] ?? 'Hôtel Africa Queen';
    return Container(
      color: kGreen,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12, left: 16, right: 16,
      ),
      child: Row(
        children: [
          const Icon(Icons.hotel, color: Colors.white, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AfricaQueen SN',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                Text('$hotel — Somone',
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white24,
            child: Text(
              (prenom != null && prenom.isNotEmpty) ? prenom[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    final prenom = widget.user['prenom'] ?? 'Admin';
    return Text('Bonjour, $prenom 👋',
        style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500));
  }

  Widget _buildStatsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _statCard(
              titre: 'Occupées',
              valeur: '${_dashboardData!.chambresOccupees}',
              suffix: '/${_dashboardData!.totalChambres}',
              sub: '${_dashboardData!.tauxOccupation}% occupation',
              subColor: kAmber,
              progress: _dashboardData!.tauxOccupation / 100.0,
            )),
            const SizedBox(width: 12),
            Expanded(child: _statCard(
              titre: 'Libres',
              valeur: '${_dashboardData!.chambresLibres}',
              suffix: '',
              sub: 'Disponibles',
              subColor: kGreen,
              icon: Icons.check_circle_outline,
            )),
          ],
        ),
        const SizedBox(height: 12),
        _statCard(
          titre: 'Recettes du jour',
          valeur: _formatFcfa(_dashboardData!.recettesJour),
          suffix: '',
          sub: 'Total encaissé',
          subColor: kBlue,
        ),
      ],
    );
  }

  Widget _statCard({required String titre, required String valeur, required String suffix, required String sub, required Color subColor, double? progress, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(valeur, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(suffix, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress, backgroundColor: Colors.grey[200], valueColor: AlwaysStoppedAnimation(subColor), minHeight: 4),
          ],
          const SizedBox(height: 6),
          Text(sub, style: TextStyle(fontSize: 10, color: subColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAccesRapide() {
    // 🧹 Accès rapide adapté au rôle ménage
    if (_estMenage) {
      final idxMenage = _indexOf('Ménage');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Accès rapide", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            children: [
              if (idxMenage != -1)
                _quickActionItem(Icons.cleaning_services_outlined, "Ménage", idxMenage),
            ],
          ),
        ],
      );
    }

    // 💳 Accès rapide adapté au rôle caissier
    if (_estCaissier) {
      final idxCaisse = _indexOf('Caisse');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Accès rapide", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            children: [
              if (idxCaisse != -1)
                _quickActionItem(Icons.point_of_sale, "Caisse", idxCaisse),
            ],
          ),
        ],
      );
    }

    final items = <Widget>[
      _quickActionItem(Icons.bed_outlined, "Chambres", _indexOf('Chambres')),
      _quickActionItem(Icons.calendar_month, "Réservations", _indexOf('Réservations')),
      _quickActionItem(Icons.people_outline, "Clients", _indexOf('Clients')),
      if (_peutVoirCaisse)
        _quickActionItem(Icons.point_of_sale, "Caisse", _indexOf('Caisse')),
      if (_estAdminOuGerant)
        _quickActionItem(Icons.cleaning_services_outlined, "Ménage", _indexOf('Ménage')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Accès rapide", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: items
                .map((w) => Padding(padding: const EdgeInsets.only(right: 10), child: w))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _quickActionItem(IconData icon, String label, int index) {
    if (index == -1) return const SizedBox();
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.21,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          children: [
            Icon(icon, color: kGreen, size: 22),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildVitrineBanner() {
    return InkWell(
      onTap: _ouvrirVitrineWeb,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [kGreen, Color(0xFF148A6C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: kGreen.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 28),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Espace Vitrine & Médias",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Découvrir la restauration, les activités et vidéos",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildReservationsCard() {
    final list = _dashboardData?.reservations ?? [];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Réservations du jour', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          if (list.isEmpty) const Text('Aucune réservation', style: TextStyle(color: Colors.grey, fontSize: 12))
          else ...list.map((r) => _reservationTile(r)).toList(),
        ],
      ),
    );
  }

  Widget _reservationTile(RecentReservation r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: kGreen.withOpacity(0.1), child: Text(r.nomClient[0], style: const TextStyle(color: kGreen, fontSize: 12))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.nomClient, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Text('${r.numeroChambre} · ${r.typeChambre}', style: const TextStyle(fontSize: 10)),
          ])),
          const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildAlertes() {
    final alerte = _dashboardData?.alerte;
    if (alerte == null || alerte.isEmpty) return const SizedBox();

    final client = alerte['client'];
    if (client == null || client.toString().isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAmber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: kAmber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Paiement attendu : $client',
              style: const TextStyle(fontSize: 11, color: Color(0xFF633806)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: kGreen,
      unselectedItemColor: Colors.grey,
      selectedFontSize: 10,
      unselectedFontSize: 10,
      currentIndex: _currentIndex,
      onTap: (i) => setState(() => _currentIndex = i),
      items: _navEntries
          .map((e) => BottomNavigationBarItem(icon: Icon(e.icon), label: e.label))
          .toList(),
    );
  }

  String _formatFcfa(num amount) => "${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} F";

  Map<String, dynamic> _demoData() => {
    'data': {
      'stats': {'chambres_occupees': 18, 'total_chambres': 24, 'taux_occupation': 75, 'recettes_jour': 485000},
      'reservations': [{'nom_client': 'Moussa Fall', 'chambre': {'numero': '12', 'type': 'Standard'}}],
      'alerte': {'client': 'Aïssatou Diallo'}
    }
  };
}