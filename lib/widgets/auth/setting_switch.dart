import 'package:flutter/material.dart';

class SettingSwitch extends StatelessWidget {

  final String title;

  final String subtitle;

  final bool value;

  final Function(bool) onChanged;

  const SettingSwitch({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {

    return SwitchListTile(

      title: Text(title),

      subtitle: Text(subtitle),

      value: value,

      onChanged: onChanged,
    );
  }
}