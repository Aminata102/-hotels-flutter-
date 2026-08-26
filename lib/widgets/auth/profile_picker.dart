import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../utils/app_colors.dart';

class ProfilePicker extends StatefulWidget {
  final Function(File?) onImageSelected;

  const ProfilePicker({
    super.key,
    required this.onImageSelected,
  });

  @override
  State<ProfilePicker> createState() => _ProfilePickerState();
}

class _ProfilePickerState extends State<ProfilePicker> {
  final ImagePicker _picker = ImagePicker();

  File? _image;

  Future<void> _pickImage(ImageSource source) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );

    if (file != null) {
      setState(() {
        _image = File(file.path);
      });

      widget.onImageSelected(_image);
    }
  }

  void _showPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [

              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text("Prendre une photo"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),

              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text("Choisir dans la galerie"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),

            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [

        Stack(
          children: [

            CircleAvatar(
              radius: 60,
              backgroundColor: AppColors.primary,
              backgroundImage:
              _image != null ? FileImage(_image!) : null,
              child: _image == null
                  ? const Icon(
                Icons.person,
                color: Colors.white,
                size: 60,
              )
                  : null,
            ),

            Positioned(
              right: 0,
              bottom: 0,
              child: InkWell(
                onTap: _showPicker,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        TextButton.icon(
          onPressed: _showPicker,
          icon: const Icon(Icons.photo_camera),
          label: const Text("Ajouter une photo"),
        ),
      ],
    );
  }
}