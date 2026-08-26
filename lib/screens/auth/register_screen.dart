import 'dart:io';

import '../../services/auth_service.dart';

import 'package:flutter/material.dart';

import '../../models/role_model.dart';
import '../../utils/app_colors.dart';
import '../../utils/validators.dart';

import '../../widgets/auth/custom_text_field.dart';
import '../../widgets/auth/password_field.dart';
import '../../widgets/auth/password_strength.dart';
import '../../widgets/auth/profile_picker.dart';
import '../../widgets/auth/role_card.dart';
import '../../widgets/auth/setting_switch.dart';
import '../../widgets/auth/primary_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {

  final _formKey = GlobalKey<FormState>();

  final nomController = TextEditingController();
  final emailController = TextEditingController();
  final telephoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  File? profileImage;

  bool compteActif = true;
  bool envoyerSms = false;
  bool loading = false;

  String selectedRole = "receptionniste";

  // ✅ Correction des valeurs de rôle pour correspondance exacte avec le backend
  final List<RoleModel> roles = [
    RoleModel(
      id: 1,
      name: "Administrateur",
      value: "administrateur", // ou "administrateur" selon votre backend
      icon: Icons.admin_panel_settings,
    ),
    RoleModel(
      id: 2,
      name: "Réceptionniste",
      value: "receptionniste", // 👈 Coquille "receptionnworiste" corrigée
      icon: Icons.support_agent,
    ),
    RoleModel(
      id: 3,
      name: "Caissier",
      value: "caissier",
      icon: Icons.payments,
    ),
    RoleModel(
      id: 4,
      name: "Housekeeping",
      value: "housekeeping",
      icon: Icons.cleaning_services,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // ✅ Re-render automatique à la saisie pour actualiser la jauge PasswordStrength
    passwordController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    nomController.dispose();
    emailController.dispose();
    telephoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    print("=== Début register ===");

    if (!_formKey.currentState!.validate()) {
      print("❌ Formulaire invalide");
      return;
    }

    print("✅ Formulaire valide");

    if (passwordController.text != confirmPasswordController.text) {
      print("❌ Les mots de passe sont différents");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Les mots de passe ne correspondent pas"),
        ),
      );
      return;
    }

    print("📤 Envoi de la requête...");

    setState(() {
      loading = true;
    });

    try {
      final response = await AuthService().register(
        nom: nomController.text.trim(),
        email: emailController.text.trim(),
        telephone: telephoneController.text.trim(),
        password: passwordController.text,
        role: selectedRole,
        actif: compteActif,
        sms: envoyerSms,
      );

      print("✅ Réponse serveur : $response");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response["message"] ?? "Compte créé avec succès !"),
        ),
      );

      // Réinitialiser le formulaire en cas de succès
      _formKey.currentState!.reset();
      nomController.clear();
      emailController.clear();
      telephoneController.clear();
      passwordController.clear();
      confirmPasswordController.clear();

    } catch (e) {
      print("❌ Exception : $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la création : $e"),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text("Créer un compte"),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),

      body: Form(

        key: _formKey,

        child: SingleChildScrollView(

          padding: const EdgeInsets.all(20),

          child: Column(

            children: [

              ProfilePicker(
                onImageSelected: (image) {
                  profileImage = image;
                },
              ),

              const SizedBox(height: 30),

              CustomTextField(
                label: "Nom complet",
                hint: "Entrer le nom",
                icon: Icons.person,
                controller: nomController,
                validator: Validators.requiredField,
              ),

              const SizedBox(height: 20),

              CustomTextField(
                label: "Email",
                hint: "email@hotel.com",
                icon: Icons.email,
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
              ),

              const SizedBox(height: 20),

              CustomTextField(
                label: "Téléphone",
                hint: "77xxxxxxx",
                icon: Icons.phone,
                controller: telephoneController,
                keyboardType: TextInputType.phone,
                validator: Validators.phone,
              ),

              const SizedBox(height: 20),

              PasswordField(
                label: "Mot de passe",
                controller: passwordController,
                validator: Validators.password,
              ),

              const SizedBox(height: 10),

              PasswordStrength(
                password: passwordController.text,
              ),

              const SizedBox(height: 20),

              PasswordField(
                label: "Confirmer le mot de passe",
                controller: confirmPasswordController,
                validator: Validators.password,
              ),

              const SizedBox(height: 30),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Choisir un rôle",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 15),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: roles.length,
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.2,
                ),
                itemBuilder: (_, index) {
                  final role = roles[index];
                  return RoleCard(
                    role: role,
                    selected: selectedRole == role.value,
                    onTap: () {
                      setState(() {
                        selectedRole = role.value;
                      });
                    },
                  );
                },
              ),

              const SizedBox(height: 20),

              SettingSwitch(

                title: "Compte actif",

                subtitle: "Autoriser la connexion",

                value: compteActif,

                onChanged: (v) {

                  setState(() {

                    compteActif = v;

                  });

                },
              ),

              SettingSwitch(

                title: "Envoyer les identifiants",
                subtitle: "SMS automatique",
                value: envoyerSms,
                onChanged: (v) {
                  setState(() {
                    envoyerSms = v;
                  });
                },
              ),

              const SizedBox(height: 30),
              PrimaryButton(
                text: "Créer le compte",
                loading: loading,
                onPressed: () {
                  print("BOUTON CLIQUÉ");
                  register();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}