import 'package:flutter/material.dart';

class StatBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  final double iconSize;
  final double fontSize;

  const StatBadge({
    super.key,
    required this.icon,
    required this.text,
    this.color,
    this.iconSize = 13.0,
    this.fontSize = 11.0,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).hintColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: c),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            color: c,
            fontSize: fontSize,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
