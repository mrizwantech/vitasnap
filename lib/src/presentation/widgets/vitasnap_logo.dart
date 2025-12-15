import 'package:flutter/material.dart';

/// VitaSnap branding logo widget - text-based logo.
class VitaSnapLogo extends StatelessWidget {
  final double fontSize;
  final bool showTagline;

  const VitaSnapLogo({
    super.key,
    this.fontSize = 24,
    this.showTagline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Vita',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00C17B),
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Snap',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        if (showTagline)
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Text(
              'Scan. Know. Thrive.',
              style: TextStyle(
                fontSize: fontSize * 0.4,
                color: Colors.grey.shade600,
                letterSpacing: 0.5,
              ),
            ),
          ),
      ],
    );
  }
}
