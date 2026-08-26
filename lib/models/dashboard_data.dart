import 'dart:convert';

class DashboardData {
  final int chambresOccupees;
  final int chambresLibres;
  final int totalChambres;
  final int tauxOccupation;
  final double recettesJour;
  final int checkIns;
  final int checkOuts;
  final List<RecentReservation> reservations;
  final Map<String, dynamic> alerte;

  DashboardData({
    required this.chambresOccupees,
    required this.chambresLibres,
    required this.totalChambres,
    required this.tauxOccupation,
    required this.recettesJour,
    required this.checkIns,
    required this.checkOuts,
    required this.reservations,
    required this.alerte,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    var data = json['data'];
    var stats = data['stats'];
    var resList = data['reservations'] as List;

    return DashboardData(
      // ✅ Fix Bug 2 : Laravel peut renvoyer des String au lieu d'int
      chambresOccupees: int.parse((stats['chambres_occupees'] ?? 0).toString()),
      chambresLibres: int.parse((stats['chambres_libres'] ?? 0).toString()),
      totalChambres: int.parse((stats['total_chambres'] ?? 0).toString()),
      tauxOccupation: int.parse((stats['taux_occupation'] ?? 0).toString()),
      recettesJour: double.parse((stats['recettes_jour'] ?? 0).toString()),
      checkIns: int.parse((stats['check_ins'] ?? 0).toString()),
      checkOuts: int.parse((stats['check_outs'] ?? 0).toString()),
      reservations: resList.map((i) => RecentReservation.fromJson(i)).toList(),
      alerte: data['alerte'] ?? {},
    );
  }
}

class RecentReservation {
  final String id; // ✅ Fix : l'API renvoie un UUID (String), pas un int
  final String nomClient;
  final String numeroChambre;
  final String typeChambre;
  final int nombreNuits;
  final String statut;
  final String statutPaiement; // ✅ Ajouté : présent dans l'API

  RecentReservation({
    required this.id,
    required this.nomClient,
    required this.numeroChambre,
    required this.typeChambre,
    required this.nombreNuits,
    required this.statut,
    required this.statutPaiement,
  });

  factory RecentReservation.fromJson(Map<String, dynamic> json) {
    final chambre = json['chambre'] as Map<String, dynamic>? ?? {};

    // ✅ Calcul des nuits à partir des dates si nombre_nuits absent
    int nuits = 1;
    if (json['nombre_nuits'] != null) {
      nuits = int.parse(json['nombre_nuits'].toString());
    } else if (json['date_arrivee'] != null && json['date_depart'] != null) {
      final arrivee = DateTime.tryParse(json['date_arrivee']);
      final depart = DateTime.tryParse(json['date_depart']);
      if (arrivee != null && depart != null) {
        nuits = depart.difference(arrivee).inDays;
      }
    }

    return RecentReservation(
      id: json['id'].toString(), // ✅ UUID → String
      nomClient: json['nom_client'] ?? json['client_name'] ?? "Client Inconnu", // ✅ bon champ API
      numeroChambre: chambre['numero']?.toString() ?? "N/A",
      typeChambre: chambre['type'] ?? "Standard",
      nombreNuits: nuits,
      statut: json['statut'] ?? "En attente",
      statutPaiement: json['statut_paiement'] ?? "Inconnu", // ✅ ajouté
    );
  }
}