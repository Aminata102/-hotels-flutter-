import 'package:flutter/material.dart';

class PasswordField extends StatefulWidget {

  final TextEditingController controller;

  final String label;

  final String? Function(String?)? validator;

  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {

  bool obscure = true;

  @override
  Widget build(BuildContext context) {

    return TextFormField(

      controller: widget.controller,

      obscureText: obscure,

      validator: widget.validator,

      decoration: InputDecoration(

        labelText: widget.label,

        prefixIcon: const Icon(Icons.lock),

        suffixIcon: IconButton(

          icon: Icon(
            obscure
                ? Icons.visibility_off
                : Icons.visibility,
          ),

          onPressed: () {

            setState(() {

              obscure = !obscure;

            });

          },
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}