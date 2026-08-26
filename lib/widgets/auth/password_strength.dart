import 'package:flutter/material.dart';

class PasswordStrength extends StatelessWidget {

  final String password;

  const PasswordStrength({
    super.key,
    required this.password,
  });

  @override
  Widget build(BuildContext context) {

    double strength = 0;

    String text = "Faible";

    Color color = Colors.red;

    if (password.length >= 8) {
      strength = 0.4;
      text = "Moyen";
      color = Colors.orange;
    }

    if (password.length >= 10 &&
        password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[0-9]'))) {
      strength = 0.7;
      text = "Bon";
      color = Colors.blue;
    }

    if (password.length >= 12 &&
        password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) {
      strength = 1;
      text = "Excellent";
      color = Colors.green;
    }

    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        LinearProgressIndicator(
          value: strength,
          color: color,
        ),

        const SizedBox(height: 5),

        Text(
          text,
          style: TextStyle(color: color),
        )
      ],
    );
  }
}