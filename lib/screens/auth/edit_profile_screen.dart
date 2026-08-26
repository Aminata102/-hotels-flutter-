import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class EditProfileScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;
  final String baseUrl;

  const EditProfileScreen({
    Key? key,
    required this.token,
    required this.user,
    this.baseUrl = 'http://10.0.2.2:8000/api',
  }) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final Color primaryGreen = const Color(0xFF176F54);
  final _formKey = GlobalKey<FormState>();

  late TextEditingController nomController;
  late TextEditingController prenomController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  final TextEditingController passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    nomController = TextEditingController(text: widget.user['nom'] ?? '');
    prenomController = TextEditingController(text: widget.user['prenom'] ?? '');
    emailController = TextEditingController(text: widget.user['email'] ?? '');
    phoneController = TextEditingController(text: widget.user['telephone'] ?? '');
  }

  @override
  void dispose() {
    nomController.dispose();
    prenomController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final bodyData = <String, dynamic>{
      'nom': nomController.text.trim(),
      'prenom': prenomController.text.trim(),
      'email': emailController.text.trim(),
      'telephone': phoneController.text.trim(),
    };

    if (passwordController.text.isNotEmpty) {
      bodyData['password'] = passwordController.text;
    }

    try {
      final response = await http.put(
        Uri.parse('${widget.baseUrl}/profile/update'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode(bodyData),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _showSnack('Profil mis à jour avec succès');
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;

        Navigator.pop(context, data['user']);
      } else {
        final msg = data['message'] ?? 'Erreur lors de la mise à jour';
        _showSnack(msg, isError: true);
      }
    } catch (e) {
      _showSnack('Impossible de contacter le serveur', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red[700] : primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Modifier son profil', style: TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: primaryGreen.withOpacity(0.15),
                  child: Icon(Icons.person, size: 40, color: primaryGreen),
                ),
              ),
              const SizedBox(height: 24),

              // Nom
              _label('Nom'),
              const SizedBox(height: 6),
              TextFormField(
                controller: nomController,
                decoration: _inputDeco(hint: 'Nom', icon: Icons.person_outline),
                validator: (val) => val == null || val.trim().isEmpty ? 'Ce champ est requis' : null,
              ),
              const SizedBox(height: 16),

              // Prénom
              _label('Prénom'),
              const SizedBox(height: 6),
              TextFormField(
                controller: prenomController,
                decoration: _inputDeco(hint: 'Prénom', icon: Icons.person_outline),
              ),
              const SizedBox(height: 16),

              // Email
              _label('Email'),
              const SizedBox(height: 6),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDeco(hint: 'Email', icon: Icons.email_outlined),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Ce champ est requis';
                  if (!val.contains('@')) return 'Email invalide';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Téléphone
              _label('Téléphone'),
              const SizedBox(height: 6),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: _inputDeco(hint: 'Numéro de téléphone', icon: Icons.phone_outlined),
                validator: (val) => val == null || val.trim().isEmpty ? 'Ce champ est requis' : null,
              ),
              const SizedBox(height: 16),

              // Mot de passe (optionnel)
              _label('Nouveau mot de passe (optionnel)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: passwordController,
                obscureText: _obscurePassword,
                decoration: _inputDeco(
                  hint: 'Laisser vide pour conserver',
                  icon: Icons.lock_outline,
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (val) {
                  if (val != null && val.isNotEmpty && val.length < 6) {
                    return 'Au moins 6 caractères requis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _updateProfile,
                  child: _isLoading
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Text('Enregistrer les modifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13));

  InputDecoration _inputDeco({required String hint, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400]),
      prefixIcon: Icon(icon, color: Colors.grey[500]),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryGreen, width: 1.5)),
    );
  }
}