import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String baseUrl = "http://10.0.2.2:8000/api";

class AuthService {

  // ── LOGIN ──────────────────────────────────────
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/login"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      );

      final data = jsonDecode(response.body);

      // Si login réussi → sauvegarder le token
      if (response.statusCode == 200 && data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('user_nom', data['user']['nom'] ?? '');
        await prefs.setString('user_email', data['user']['email'] ?? '');
        await prefs.setString('user_role', data['user']['role'] ?? '');
        await prefs.setInt('user_id', data['user']['id'] ?? 0);
      }

      return data;

    } catch (e) {
      return {
        "success": false,
        "message": "Impossible de joindre le serveur : ${e.toString()}",
      };
    }
  }

  // ── REGISTER ───────────────────────────────────
  Future<Map<String, dynamic>> register({
    required String nom,
    required String email,
    required String telephone,
    required String password,
    required String role,
    required bool actif,
    required bool sms,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/register"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "nom": nom,
          "email": email,
          "telephone": telephone,
          "password": password,
          "role": role,
          "actif": actif,
          "sms": sms,
        }),
      );

      return jsonDecode(response.body);

    } catch (e) {
      return {
        "success": false,
        "message": e.toString(),
      };
    }
  }

  // ── LOGOUT ─────────────────────────────────────
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ── GET TOKEN ──────────────────────────────────
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // ── EST CONNECTÉ ? ─────────────────────────────
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}