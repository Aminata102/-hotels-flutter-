import 'package:flutter/material.dart';
import 'dart:convert';
import '../utils/app_colors.dart';
import 'package:http/http.dart' as http;

class ReservationsScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;
  const ReservationsScreen({super.key, required this.token, required this.user});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  // --- VARIABLES D'ÉTAT GLOBALES ---
  String selectedFilter = 'Toutes';
  String searchQuery = '';
  List<Map<String, dynamic>> mesChambres = [];        // Chambres libres uniquement
  List<Map<String, dynamic>> toutesLesChambres = [];  // Toutes les chambres
  List<dynamic> mesReservations = [];

  final TextEditingController nomController = TextEditingController();
  final TextEditingController telController = TextEditingController();
  final TextEditingController cniController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  final FocusNode nomFocusNode = FocusNode();

  String? selectedChambreId;
  Map<String, dynamic>? reservationEnEdition;
  bool submittingReservation = false;

  int nombreAdultes = 1;
  int nombreEnfants = 0;
  String modePaiement = 'Espèces';
  final List<String> modesPaiement = const ['Espèces', 'Orange Money', 'Wave', 'Carte bancaire'];

  DateTime dateArrivee = DateTime.now();
  DateTime dateDepart = DateTime.now().add(const Duration(days: 2));

  // 🔴 VÉRIFICATION STRICTE DE PRIVILÈGE
  bool get _peutGererReservations {
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

    if (roleStr.isEmpty) return false;

    return roleStr.contains('admin') ||
        roleStr.contains('gerant') ||
        roleStr.contains('gérant') ||
        roleStr.contains('receptionniste') ||
        roleStr.contains('réceptionniste');
  }

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${widget.token}',
  };

  @override
  void initState() {
    super.initState();
    fetchChambres();
    fetchReservations();
  }

  @override
  void dispose() {
    nomController.dispose();
    nomFocusNode.dispose();
    telController.dispose();
    cniController.dispose();
    noteController.dispose();
    super.dispose();
  }

  List<Map<String, String>> get clientsConnus {
    final Map<String, Map<String, String>> uniques = {};
    for (var r in mesReservations) {
      final nom = (r['nom_client'] ?? '').toString().trim();
      if (nom.isEmpty) continue;
      uniques[nom] = {
        'nom': nom,
        'telephone': (r['telephone_client'] ?? '').toString(),
        'cni': (r['cni_client'] ?? '').toString(),
      };
    }
    return uniques.values.toList();
  }

  /// Filtre les réservations selon l'onglet sélectionné :
  /// - "Toutes"     : toutes les réservations, quel que soit le paiement (payé, non payé, partiel)
  /// - "Confirmées" : réservations entièrement payées (validées)
  /// - "En attente" : réservations non payées OU avec un solde restant (paiement partiel)
  /// - "Check-in"   : séjours terminés, càd le client a déjà quitté l'hôtel
  ///                  (date de départ passée, ou statut explicitement marqué comme
  ///                  terminé/check-out côté backend)
  List<dynamic> get _reservationsSelonOnglet {
    switch (selectedFilter) {
      case 'Confirmées':
        return mesReservations.where((r) {
          final statutPaiement = (r['statut_paiement'] ?? '').toString();
          return statutPaiement == 'Payé';
        }).toList();

      case 'En attente':
        return mesReservations.where((r) {
          final statutPaiement = (r['statut_paiement'] ?? '').toString();
          return statutPaiement == 'Non payé' || statutPaiement == 'Partiel';
        }).toList();

      case 'Check-in':
        return mesReservations.where((r) {
          final statut = (r['statut'] ?? '').toString();
          final depart = DateTime.tryParse(r['date_depart']?.toString() ?? '');
          final estTermineParStatut =
              statut == 'Terminée' || statut == 'Terminé' || statut == 'Check-out';
          final estTermineParDate = depart != null && depart.isBefore(DateTime.now());
          return estTermineParStatut || estTermineParDate;
        }).toList();

      case 'Annulées':
        return mesReservations.where((r) {
          final statut = (r['statut'] ?? '').toString();
          return statut == 'Annulée' || statut == 'Annulé';
        }).toList();

      default: // 'Toutes'
        return mesReservations;
    }
  }

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

  Future<void> fetchChambres() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/api/chambres'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> data = _extraireListe(decoded, ['data', 'chambres']);

        if (mounted) {
          setState(() {
            mesChambres = data
                .where((item) =>
            item['statut'].toString().toLowerCase() == 'libre' ||
                item['statut'].toString().toLowerCase() == 'disponible')
                .map((item) => {
              "id": item['id'],
              "numero": item['numero'],
              "type": item['type'],
              "prix": item['prix_nuitee'] ?? item['prix_nuit'] ?? item['prix'],
            }).toList();
          });
        }
      }
    } catch (e) {
      print("Erreur de récupération des chambres : $e");
    }
  }

  Future<void> fetchReservations() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/api/reservations'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> data = _extraireListe(decoded, ['data', 'reservations']);

        if (mounted) {
          setState(() {
            mesReservations = data;
          });
        }
      }
    } catch (e) {
      print("❌ Erreur de récupération : $e");
    }
  }

  Future<void> _soumettreReservation(
      BuildContext modalContext,
      StateSetter setModalState,
      Function(String?) setErrorMessage,
      ) async {
    if (!_peutGererReservations) {
      setModalState(() {
        setErrorMessage("❌ Accès refusé : Le rôle caissier ne peut pas effectuer de réservation.");
      });
      return;
    }

    if (nomController.text.trim().isEmpty || selectedChambreId == null) {
      setModalState(() {
        setErrorMessage("Veuillez remplir le nom du client et choisir une chambre.");
      });
      return;
    }

    // Réinitialiser le message d'erreur et activer l'indicateur de chargement
    setModalState(() {
      setErrorMessage(null);
      submittingReservation = true;
    });
    setState(() => submittingReservation = true);

    final isEdit = reservationEnEdition != null;
    final url = isEdit
        ? 'http://10.0.2.2:8000/api/reservations/${reservationEnEdition!['id']}'
        : 'http://10.0.2.2:8000/api/reservations';

    int nuits = dateDepart.difference(dateArrivee).inDays;
    if (nuits <= 0) nuits = 1;

    double prixBase = 0.0;
    if (selectedChambreId != null) {
      final chambre = mesChambres.firstWhere(
            (c) => c['id'].toString() == selectedChambreId,
        orElse: () => {},
      );
      prixBase = double.tryParse(chambre['prix']?.toString() ?? '0') ?? 0.0;
    }
    final double montantTotalCalcule = nuits * prixBase;

    final body = jsonEncode({
      'chambre_id': int.parse(selectedChambreId!),
      'nom_client': nomController.text.trim(),
      'telephone_client': telController.text.trim(),
      'cni_client': cniController.text.trim(),
      'nombre_adultes': nombreAdultes,
      'nombre_enfants': nombreEnfants,
      'mode_paiement': modePaiement,
      'acompte': 0,
      'note': noteController.text.trim(),
      'date_arrivee': dateArrivee.toIso8601String().split('T')[0],
      'date_depart': dateDepart.toIso8601String().split('T')[0],
      'montant_total': montantTotalCalcule,
    });

    try {
      final response = isEdit
          ? await http.put(Uri.parse(url), headers: _headers, body: body)
          : await http.post(Uri.parse(url), headers: _headers, body: body);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(modalContext); // Fermer le modal
        fetchReservations();
        fetchChambres();

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? "Réservation modifiée avec succès !" : "Réservation enregistrée avec succès !"),
            backgroundColor: const Color(0xFF0F6E56),
          ),
        );
      } else {
        String messageErreur = "Erreur serveur : ${response.statusCode}";

        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map) {
            if (errorData.containsKey('message')) {
              messageErreur = errorData['message'].toString();
            } else if (errorData.containsKey('errors') && errorData['errors'] is Map) {
              final Map<String, dynamic> errors = errorData['errors'];
              if (errors.isNotEmpty) {
                final firstKey = errors.keys.first;
                final firstList = errors[firstKey];
                if (firstList is List && firstList.isNotEmpty) {
                  messageErreur = "$firstKey : ${firstList.first}";
                }
              }
            }
          }
        } catch (_) {}

        // 🔴 Injection de l'erreur dans le modal
        setModalState(() {
          setErrorMessage(messageErreur);
        });
      }
    } catch (e) {
      if (mounted) {
        setModalState(() {
          setErrorMessage("Erreur de connexion au serveur : $e");
        });
      }
    } finally {
      if (mounted) {
        setState(() => submittingReservation = false);
        setModalState(() => submittingReservation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reservationsParStatut = _reservationsSelonOnglet;

    final q = searchQuery.trim().toLowerCase();
    final reservationsFiltrees = q.isEmpty
        ? reservationsParStatut
        : reservationsParStatut.where((r) {
      final nom = (r['nom_client'] ?? '').toString().toLowerCase();
      final numChambre = (r['chambre'] != null ? r['chambre']['numero'].toString() : '').toLowerCase();
      return nom.contains(q) || numChambre.contains(q);
    }).toList();

    return Column(
      children: [
        _buildTopHeader(),
        if (!_peutGererReservations)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.amber.shade800,
            child: const Text(
              "Mode consultation : Le caissier ne peut pas ajouter ou modifier de réservations.",
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
        _buildTopStats(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchBar(),
                const SizedBox(height: 16),
                _buildStatusFilters(),
                const SizedBox(height: 24),
                const Text("TOUTES LES RÉSERVATIONS",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey, letterSpacing: 1.1)),
                const SizedBox(height: 12),

                if (reservationsFiltrees.isEmpty)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text("Aucune réservation trouvée", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ))
                else
                  ...reservationsFiltrees.map((res) {
                    DateTime arrivee = DateTime.parse(res['date_arrivee']);
                    DateTime depart = DateTime.parse(res['date_depart']);
                    int nuits = depart.difference(arrivee).inDays;
                    if (nuits <= 0) nuits = 1;

                    String nom = res['nom_client'] ?? "Client";
                    String initiale = nom.isNotEmpty ? nom.substring(0, 1).toUpperCase() : "C";

                    String numChambre = res['chambre'] != null ? res['chambre']['numero'].toString() : "??";
                    String typeChambre = res['chambre'] != null ? res['chambre']['type'] : "Standard";

                    return _buildDetailedReservationCard(
                      reservation: res,
                      nom: nom,
                      initiale: initiale,
                      chambre: numChambre,
                      type: typeChambre,
                      nuits: nuits,
                      arrivee: "${arrivee.day}/${arrivee.month}/${arrivee.year}",
                      depart: "${depart.day}/${depart.month}/${depart.year}",
                      total: "${res['montant_total']} F",
                      statut: res['statut'] ?? "En attente",
                      statutPaiement: res['statut_paiement'] ?? "Non payé",
                      montantRestant: double.tryParse(res['montant_restant']?.toString() ?? '0') ?? 0,
                      color: res['statut'] == 'Confirmée' ? Colors.green : Colors.orange,
                    );
                  }).toList(),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- WIDGETS DE L'INTERFACE PRINCIPALE ---
  Widget _buildTopHeader() {
    return Container(
      color: const Color(0xFF0F6E56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Réservations",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (_peutGererReservations)
            ElevatedButton.icon(
              onPressed: () async {
                setState(() {
                  reservationEnEdition = null;
                  nomController.clear();
                  telController.clear();
                  cniController.clear();
                  noteController.clear();
                  selectedChambreId = null;
                });
                await fetchChambres();
                _showAddReservationModal();
              },
              icon: const Icon(Icons.add, size: 16, color: Color(0xFF0F6E56)),
              label: const Text(
                "Nouvelle",
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF0F6E56),
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopStats() {
    final enAttente = mesReservations.where((r) => r['statut'] == 'En attente').length;
    return Container(
      color: const Color(0xFF0F6E56),
      padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      child: Row(
        children: [
          _topStatItem(mesReservations.length.toString(), "Ce mois"),
          _topStatItem(enAttente.toString(), "En attente"),
          _topStatItem("5", "Aujourd'hui"),
        ],
      ),
    );
  }

  Widget _topStatItem(String val, String label) {
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
      onChanged: (value) => setState(() => searchQuery = value),
      decoration: InputDecoration(
        hintText: "Rechercher un client ou une chambre...",
        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
        prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
        suffixIcon: searchQuery.isNotEmpty
            ? IconButton(
          icon: const Icon(Icons.close, size: 18, color: Colors.grey),
          onPressed: () => setState(() => searchQuery = ''),
        )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      ),
    );
  }

  Widget _buildStatusFilters() {
    List<String> filters = ['Toutes', 'Confirmées', 'En attente', 'Check-in', 'Annulées'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          bool isSel = selectedFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f, style: TextStyle(fontSize: 12, color: isSel ? Colors.white : Colors.black87)),
              selected: isSel,
              onSelected: (s) => setState(() => selectedFilter = f),
              selectedColor: const Color(0xFF0F6E56),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey.shade200),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDetailedReservationCard({
    required Map<String, dynamic> reservation,
    required String nom, required String initiale, required String chambre, required String type,
    required int nuits, required String arrivee, required String depart, required String total,
    required String statut, required String statutPaiement, required double montantRestant, required Color color,
  }) {
    Color couleurPaiement;
    IconData iconePaiement;
    String texteePaiement;
    switch (statutPaiement) {
      case 'Payé':
        couleurPaiement = Colors.green;
        iconePaiement = Icons.check_circle;
        texteePaiement = "Payé";
        break;
      case 'Partiel':
        couleurPaiement = Colors.orange;
        iconePaiement = Icons.timelapse;
        texteePaiement = "Restant : ${montantRestant.toStringAsFixed(0)} FCFA";
        break;
      default:
        couleurPaiement = Colors.redAccent;
        iconePaiement = Icons.error_outline;
        texteePaiement = "Non payé";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Text(initiale, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold))),
            title: Text(nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text("Ch. $chambre · $type · $nuits nuits", style: const TextStyle(fontSize: 11, color: Colors.grey)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(statut, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 4),
                if (_peutGererReservations) ...[
                  IconButton(
                    onPressed: () => _ouvrirModalEdition(reservation),
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0F6E56)),
                    visualDensity: VisualDensity.compact,
                    tooltip: "Modifier",
                  ),
                  IconButton(
                    onPressed: () => _confirmerSuppression(reservation),
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    visualDensity: VisualDensity.compact,
                    tooltip: "Supprimer",
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF2F2F2)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _dateInfo("Arrivée", arrivee),
                _dateInfo("Départ", depart),
                _dateInfo("Total", total, isBold: true),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: couleurPaiement.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(iconePaiement, size: 14, color: couleurPaiement),
                const SizedBox(width: 6),
                Text(
                  texteePaiement,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: couleurPaiement),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateInfo(String label, String date, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(date, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: isBold ? const Color(0xFF0F6E56) : Colors.black87)),
      ],
    );
  }

  void _ouvrirModalEdition(Map<String, dynamic> res) async {
    if (!_peutGererReservations) return;

    await fetchChambres();

    setState(() {
      reservationEnEdition = res;
      nomController.text = res['nom_client'] ?? '';
      telController.text = res['telephone_client'] ?? '';
      cniController.text = res['cni_client']?.toString() ?? '';
      noteController.text = res['note']?.toString() ?? '';
      nombreAdultes = int.tryParse(res['nombre_adultes']?.toString() ?? '') ?? 1;
      nombreEnfants = int.tryParse(res['nombre_enfants']?.toString() ?? '') ?? 0;
      modePaiement = modesPaiement.contains(res['mode_paiement']) ? res['mode_paiement'] : 'Espèces';
      dateArrivee = DateTime.tryParse(res['date_arrivee'] ?? '') ?? DateTime.now();
      dateDepart = DateTime.tryParse(res['date_depart'] ?? '') ?? DateTime.now().add(const Duration(days: 1));
      selectedChambreId = res['chambre_id']?.toString() ?? res['chambre']?['id']?.toString();

      if (res['chambre'] != null && !mesChambres.any((c) => c['id'].toString() == selectedChambreId)) {
        mesChambres.add({
          "id": res['chambre']['id'],
          "numero": res['chambre']['numero'],
          "type": res['chambre']['type'],
          "prix": res['chambre']['prix_nuitee'] ?? res['chambre']['prix'],
        });
      }
    });

    _showAddReservationModal();
  }

  void _confirmerSuppression(Map<String, dynamic> res) {
    if (!_peutGererReservations) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Supprimer la réservation ?"),
        content: Text("Voulez-vous vraiment supprimer la réservation de ${res['nom_client'] ?? 'ce client'} ? Cette action est irréversible."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _supprimerReservation(res);
            },
            child: const Text("Supprimer", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _supprimerReservation(Map<String, dynamic> res) async {
    if (!_peutGererReservations) return;

    final id = res['id'];
    if (id == null) return;

    try {
      final response = await http.delete(
        Uri.parse('http://10.0.2.2:8000/api/reservations/$id'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchReservations();
        await fetchChambres();
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🗑️ Réservation supprimée"), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      print("Erreur réseau (suppression) : $e");
    }
  }

  // --- LE MODAL DE SAISIE COMPLET ET CORRIGÉ ---
  void _showAddReservationModal() {
    if (!_peutGererReservations) return;

    String? errorMessage; // 🔴 Variable pour l'affichage de l'erreur dans le modal

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          int nuits = dateDepart.difference(dateArrivee).inDays;
          if (nuits <= 0) nuits = 1;

          double prixBase = 0.0;
          if (selectedChambreId != null) {
            final chambre = mesChambres.firstWhere(
                  (c) => c['id'].toString() == selectedChambreId,
              orElse: () => {},
            );
            prixBase = double.tryParse(chambre['prix']?.toString() ?? '0') ?? 0.0;
          }
          double montantTotal = nuits * prixBase;

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
              top: 20, left: 20, right: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: const BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.all(Radius.circular(2)))),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(modalContext),
                        icon: const Icon(Icons.arrow_back, color: Color(0xFF0F6E56)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      Text(
                        reservationEnEdition == null ? "Nouvelle Réservation" : "Modifier la Réservation",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F6E56)),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(modalContext),
                        icon: const Icon(Icons.close, color: Colors.grey),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (errorMessage != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        errorMessage!,
                        style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                      ),
                    ),

                  // 1. NOM DU CLIENT (Autocomplete)
                  Autocomplete<Map<String, String>>(
                    textEditingController: nomController,
                    focusNode: nomFocusNode,
                    optionsBuilder: (TextEditingValue value) {
                      if (value.text.trim().isEmpty) return const Iterable<Map<String, String>>.empty();
                      return clientsConnus.where((c) => c['nom']!.toLowerCase().contains(value.text.toLowerCase()));
                    },
                    displayStringForOption: (option) => option['nom'] ?? '',
                    onSelected: (selection) {
                      setModalState(() {
                        telController.text = selection['telephone'] ?? '';
                        if ((selection['cni'] ?? '').isNotEmpty) cniController.text = selection['cni']!;
                      });
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: "Nom complet du client",
                          prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // 2. TÉLÉPHONE ET CNI
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: telController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: "Téléphone",
                            prefixIcon: const Icon(Icons.phone_outlined, color: Colors.grey),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: cniController,
                          decoration: InputDecoration(
                            labelText: "CNI / Passeport",
                            prefixIcon: const Icon(Icons.badge_outlined, color: Colors.grey),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 3. SÉLECTION DE LA CHAMBRE
                  DropdownButtonFormField<String>(
                    value: selectedChambreId,
                    isExpanded: true, // ✅ FIX : évite l'overflow quand le texte de la chambre est long
                    decoration: InputDecoration(
                      labelText: "Chambre",
                      prefixIcon: const Icon(Icons.king_bed_outlined, color: Colors.grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    ),
                    items: mesChambres.map((chambre) {
                      return DropdownMenuItem<String>(
                        value: chambre['id'].toString(),
                        child: Text(
                          "Chambre ${chambre['numero']} (${chambre['type']}) - ${chambre['prix']} FCFA",
                          overflow: TextOverflow.ellipsis, // ✅ FIX : tronque proprement si trop long
                          maxLines: 1,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setModalState(() {
                        selectedChambreId = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // 4. DATES D'ARRIVÉE ET DÉPART
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: modalContext,
                              initialDate: dateArrivee,
                              firstDate: DateTime.now().subtract(const Duration(days: 30)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setModalState(() {
                                dateArrivee = picked;
                                if (dateDepart.isBefore(dateArrivee)) {
                                  dateDepart = dateArrivee.add(const Duration(days: 1));
                                }
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: "Arrivée",
                              prefixIcon: const Icon(Icons.calendar_today, color: Colors.grey),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text("${dateArrivee.day}/${dateArrivee.month}/${dateArrivee.year}"),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: modalContext,
                              initialDate: dateDepart,
                              firstDate: dateArrivee,
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setModalState(() {
                                dateDepart = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: "Départ",
                              prefixIcon: const Icon(Icons.calendar_today, color: Colors.grey),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text("${dateDepart.day}/${dateDepart.month}/${dateDepart.year}"),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 5. ADULTES ET ENFANTS
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: nombreAdultes,
                          decoration: InputDecoration(
                            labelText: "Adultes",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: List.generate(5, (i) => i + 1)
                              .map((n) => DropdownMenuItem(value: n, child: Text("$n adulte(s)")))
                              .toList(),
                          onChanged: (val) => setModalState(() => nombreAdultes = val ?? 1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: nombreEnfants,
                          decoration: InputDecoration(
                            labelText: "Enfants",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: List.generate(6, (i) => i)
                              .map((n) => DropdownMenuItem(value: n, child: Text("$n enfant(s)")))
                              .toList(),
                          onChanged: (val) => setModalState(() => nombreEnfants = val ?? 0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 6. MODE DE PAIEMENT
                  DropdownButtonFormField<String>(
                    value: modePaiement,
                    decoration: InputDecoration(
                      labelText: "Mode de paiement",
                      prefixIcon: const Icon(Icons.payment, color: Colors.grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: modesPaiement
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (val) => setModalState(() => modePaiement = val ?? 'Espèces'),
                  ),
                  const SizedBox(height: 12),

                  // 7. NOTE / REMARQUE
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: "Note (optionnel)",
                      prefixIcon: const Icon(Icons.note_outlined, color: Colors.grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // RECAPITULATIF DU PRIX
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F6E56).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("$nuits nuit(s) × ${prixBase.toStringAsFixed(0)} FCFA",
                            style: const TextStyle(fontSize: 13, color: Colors.black87)),
                        Text(
                          "${montantTotal.toStringAsFixed(0)} FCFA",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F6E56)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // BOUTON DE SOUMISSION
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: submittingReservation
                          ? null
                          : () => _soumettreReservation(
                        modalContext,
                        setModalState,
                            (msg) => errorMessage = msg,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F6E56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: submittingReservation
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : Text(
                        reservationEnEdition == null ? "Enregistrer la réservation" : "Mettre à jour",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}