class UserModel {

  String nom;

  String email;

  String telephone;

  String password;

  String role;

  bool actif;

  bool sms;

  UserModel({

    required this.nom,

    required this.email,

    required this.telephone,

    required this.password,

    required this.role,

    required this.actif,

    required this.sms,
  });

  Map<String, dynamic> toJson() {

    return {

      "nom": nom,

      "email": email,

      "telephone": telephone,

      "password": password,

      "role": role,

      "actif": actif,

      "sms": sms,

    };
  }
}