import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double? size;
  final double? fontSize;

  const EmptyStateWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.size,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Empty State Illustration
          Container(
            height: size ?? 140,
            width: size ?? 140,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/empty_task.png'),
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Title
          Text(
            title,
            style: GoogleFonts.lexend(
              fontSize: fontSize ?? 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.4),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
