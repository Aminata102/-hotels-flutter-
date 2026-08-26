import 'package:flutter/material.dart';
import 'package:hotels/screens/auth/edit_profile_screen.dart'; // Adaptez l'import selon l'emplacement du fichier
import 'package:hotels/main.dart'; // Pour accéder à LoginPage
import '../services/auth_service.dart'; // ⚠️ Adapte ce chemin si auth_service.dart est ailleurs

class ParametresScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String token; // Ajout du token nécessaire à la requête API

  const ParametresScreen({
    super.key,
    required this.user,
    required this.token,
  });

  @override
  State<ParametresScreen> createState() => _ParametresScreenState();
}

class _ParametresScreenState extends State<ParametresScreen> {
  late Map<String, dynamic> currentUser;
  final AuthService _authService = AuthService();
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    currentUser = widget.user;
  }

  // Méthode pour ouvrir l'écran d'édition et récupérer le profil mis à jour
  Future<void> _navigateToEditProfile() async {
    final updatedUser = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          token: widget.token,
          user: currentUser,
        ),
      ),
    );

    // Si la mise à jour a réussi dans EditProfileScreen
    if (updatedUser != null) {
      setState(() {
        currentUser = updatedUser;
      });
    }
  }

  // ── DÉCONNEXION ──────────────────────────────
  Future<void> _confirmerDeconnexion() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Se déconnecter ?"),
        content: const Text("Vous devrez vous reconnecter avec votre email et mot de passe."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Se déconnecter", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirme == true) {
      await _deconnecter();
    }
  }

  Future<void> _deconnecter() async {
    setState(() => _loggingOut = true);

    // 1. Vide le token + les infos utilisateur stockées en local
    await _authService.logout();

    if (!mounted) return;

    // 2. Retour à l'écran de connexion en vidant toute la pile de navigation
    //    (empêche de revenir en arrière vers le dashboard avec le bouton "retour")
    //    ⚠️ Ton app n'utilise pas de routes nommées : on navigue donc directement
    //    vers le widget LoginPage (défini dans main.dart).
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginPage()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Extraction sécurisée des champs
    final prenom = currentUser['prenom'] ?? '';
    final nom = currentUser['nom'] ?? '';
    final email = currentUser['email'] ?? '';

    // Si la relation hotel est un objet ou une simple chaîne
    final hotel = currentUser['hotel'] is Map
        ? (currentUser['hotel']['nom'] ?? 'Hôtel Teranga')
        : 'Hôtel Teranga';

    final displayName = prenom.isNotEmpty ? '$prenom $nom' : (nom.isNotEmpty ? nom : 'Utilisateur');

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Section Profil interactive
                InkWell(
                  onTap: _navigateToEditProfile,
                  borderRadius: BorderRadius.circular(16),
                  child: _buildProfileCard(displayName, email, hotel),
                ),
                const SizedBox(height: 24),

                // Groupes d'options
                _buildSectionTitle("APPLICATION"),
                _menuItem(Icons.notifications_none_rounded, "Notifications", "Activées"),
                _menuItem(Icons.language_rounded, "Langue", "Français"),
                _menuItem(Icons.dark_mode_outlined, "Mode sombre", "Désactivé"),

                const SizedBox(height: 24),
                _buildSectionTitle("HÔTEL & SYSTÈME"),
                _menuItem(Icons.business_rounded, "Informations de l'hôtel", ""),
                _menuItem(
                  Icons.security_rounded,
                  "Sécurité & Mot de passe",
                  "",
                  onTap: _navigateToEditProfile,
                ),
                _menuItem(Icons.help_outline_rounded, "Support technique", ""),

                const SizedBox(height: 32),

                // Bouton Déconnexion
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loggingOut ? null : _confirmerDeconnexion,
                    icon: _loggingOut
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                    )
                        : const Icon(Icons.logout_rounded),
                    label: Text(_loggingOut ? "Déconnexion..." : "Se déconnecter"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[50],
                      foregroundColor: Colors.red,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text("Version 1.0.2", style: TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFF0F6E56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      width: double.infinity,
      child: const Text(
        "Paramètres",
        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildProfileCard(String displayName, String email, String hotel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF0F6E56).withOpacity(0.1),
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: const TextStyle(color: Color(0xFF0F6E56), fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(email, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    hotel,
                    style: TextStyle(color: Colors.blue[700], fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.edit_outlined, color: Colors.grey, size: 20),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
      ),
    );
  }

  Widget _menuItem(IconData icon, String title, String trailing, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: const Color(0xFF0F6E56), size: 22),
        title: Text(title, style: const TextStyle(fontSize: 14)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailing.isNotEmpty)
              Text(trailing, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }
}