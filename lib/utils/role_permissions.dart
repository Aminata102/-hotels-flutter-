import 'package:flutter/foundation.dart';

/// Rôles gérés par l'application hôtelière
enum UserRole {
  admin,
  gerant,
  receptionniste,
  caissier,
  housekeeping,
  unknown,
}

/// Helper pour vérifier les permissions et les accès par rôle
class RolePermissions {
  /// Convertit une chaîne de caractères (depuis le backend Laravel) en enum [UserRole]
  static UserRole parseRole(String? roleStr) {
    if (roleStr == null) return UserRole.unknown;

    final normalized = roleStr.trim().toLowerCase();

    switch (normalized) {
      case 'admin':
      case 'administrateur':
        return UserRole.admin;
      case 'gérant':
      case 'gerant':
        return UserRole.gerant;
      case 'receptionniste':
      case 'réceptionniste':
      case 'receptionist':
        return UserRole.receptionniste;
      case 'caissier':
      case 'caissière':
        return UserRole.caissier;
      case 'housekeeping':
      case 'personnel de ménage':
      case 'menage':
      case 'mênage':
        return UserRole.housekeeping;
      default:
        return UserRole.unknown;
    }
  }

  // ===========================================================================
  // VÉRIFICATIONS DES PERMISSIONS
  // ===========================================================================

  /// Administrateur ou Gérant (accès de gestion globale)
  static bool isAdminOrGerant(String? roleStr) {
    final role = parseRole(roleStr);
    return role == UserRole.admin || role == UserRole.gerant;
  }

  /// ✅ Permission de gérer les Clients (Admin, Gérant, Réceptionniste)
  static bool canManageClients(String? roleStr) {
    final role = parseRole(roleStr);
    return role == UserRole.admin ||
        role == UserRole.gerant ||
        role == UserRole.receptionniste;
  }

  /// ✅ Permission de gérer les Chambres (Admin, Gérant, Réceptionniste)
  static bool canManageChambres(String? roleStr) {
    final role = parseRole(roleStr);
    return role == UserRole.admin ||
        role == UserRole.gerant ||
        role == UserRole.receptionniste;
  }

  /// ✅ Permission de gérer les Réservations (Admin, Gérant, Réceptionniste)
  static bool canManageReservations(String? roleStr) {
    final role = parseRole(roleStr);
    return role == UserRole.admin ||
        role == UserRole.gerant ||
        role == UserRole.receptionniste;
  }

  /// Permission d'accéder au module Caisses & Factures (Admin, Gérant, Caissier, Réceptionniste)
  static bool canManageBilling(String? roleStr) {
    final role = parseRole(roleStr);
    return role == UserRole.admin ||
        role == UserRole.gerant ||
        role == UserRole.caissier ||
        role == UserRole.receptionniste;
  }

  /// Permission d'accéder au module Housekeeping / Ménage (Admin, Gérant, Housekeeping)
  static bool canManageHousekeeping(String? roleStr) {
    final role = parseRole(roleStr);
    return role == UserRole.admin ||
        role == UserRole.gerant ||
        role == UserRole.housekeeping;
  }

  /// Permission d'accéder à la configuration globale / Utilisateurs (Admin & Gérant)
  static bool canManageSettings(String? roleStr) {
    return isAdminOrGerant(roleStr);
  }

  // ===========================================================================
  // AFFICHAGE & ÉTIQUETTES
  // ===========================================================================

  /// Renvoie un libellé lisible pour l'interface utilisateur
  static String getRoleLabel(String? roleStr) {
    final role = parseRole(roleStr);
    switch (role) {
      case UserRole.admin:
        return 'Administrateur';
      case UserRole.gerant:
        return 'Gérant';
      case UserRole.receptionniste:
        return 'Réceptionniste';
      case UserRole.caissier:
        return 'Caissier';
      case UserRole.housekeeping:
        return 'Personnel de Ménage';
      case UserRole.unknown:
        return roleStr ?? 'Utilisateur';
    }
  }
}