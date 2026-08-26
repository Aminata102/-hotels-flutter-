import 'package:flutter/material.dart';
import '../../models/role_model.dart';
import '../../utils/app_colors.dart';

class RoleCard extends StatelessWidget {

  final RoleModel role;

  final bool selected;

  final VoidCallback onTap;

  const RoleCard({
    super.key,
    required this.role,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {

    return InkWell(

      onTap: onTap,

      child: AnimatedContainer(

        duration: const Duration(milliseconds: 300),

        decoration: BoxDecoration(

          color: selected
              ? AppColors.primary.withOpacity(.1)
              : Colors.white,

          borderRadius: BorderRadius.circular(20),

          border: Border.all(

            color: selected
                ? AppColors.primary
                : Colors.grey.shade300,

            width: 2,
          ),
        ),

        child: Column(

          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            Icon(
              role.icon,
              size: 40,
              color: selected
                  ? AppColors.primary
                  : Colors.grey,
            ),

            const SizedBox(height: 15),

            Text(
              role.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: selected
                    ? AppColors.primary
                    : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}