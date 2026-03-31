import 'package:flutter/material.dart';

class PrimaryActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}