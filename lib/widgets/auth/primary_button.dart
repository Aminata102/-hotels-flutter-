import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class PrimaryButton extends StatelessWidget {

  final String text;

  final VoidCallback onPressed;

  final bool loading;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {

    return SizedBox(

      width: double.infinity,

      height: 55,

      child: ElevatedButton(

        onPressed: loading ? null : onPressed,

        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),

        child: loading
            ? const CircularProgressIndicator(
          color: Colors.white,
        )
            : Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}