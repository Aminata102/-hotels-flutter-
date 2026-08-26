class Validators {

  static String? requiredField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Ce champ est obligatoire";
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return "Veuillez entrer votre email";
    }

    final regex = RegExp(
      r'^[\w\-\.]+@([\w\-]+\.)+[\w]{2,4}$',
    );

    if (!regex.hasMatch(value)) {
      return "Adresse email invalide";
    }

    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.isEmpty) {
      return "Numéro obligatoire";
    }

    if (value.length < 9) {
      return "Numéro invalide";
    }

    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return "Mot de passe obligatoire";
    }

    if (value.length < 8) {
      return "Minimum 8 caractères";
    }

    return null;
  }
}