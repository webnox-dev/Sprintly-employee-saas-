import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flip_card/flip_card.dart';

class RecreatedStatsCard extends StatefulWidget {
  final String title;
  final String value;
  final String? badgeText;
  final bool isGrowth; // true for positive green, false for neutral gray
  final String imagePath;
  final String backSubtitle;
  final IconData icon;
  final Color accentColor;
  final String subtitle;

  const RecreatedStatsCard({
    super.key,
    required this.title,
    required this.value,
    this.badgeText,
    this.isGrowth = true,
    required this.imagePath,
    required this.backSubtitle,
    required this.icon,
    required this.accentColor,
    required this.subtitle,
  });

  @override
  State<RecreatedStatsCard> createState() => _RecreatedStatsCardState();
}

class _RecreatedStatsCardState extends State<RecreatedStatsCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: widget.accentColor.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
        ),
        child: FlipCard(
          fill: Fill.fillBack,
          direction: FlipDirection.HORIZONTAL,
          front: _buildCardFace(isFront: true),
          back: _buildCardFace(isFront: false),
        ),
      ),
    );
  }

  Widget _buildCardFace({required bool isFront}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.accentColor.withOpacity(0.06),
                Colors.white.withOpacity(0.015),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered 
                  ? widget.accentColor.withOpacity(0.5)
                  : widget.accentColor.withOpacity(0.3),
              width: 1.0,
            ),
          ),
          child: isFront ? _buildFrontContent() : _buildBackContent(),
        ),
      ),
    );
  }

  Widget _buildFrontContent() {
    return Stack(
      children: [
        // Watermark in bottom right corner (AssetImage)
        Positioned(
          right: -15,
          bottom: -15,
          child: Opacity(
            opacity: 0.08,
            child: Image.asset(
              widget.imagePath,
              width: 90,
              height: 90,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Title & Action Button Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: GoogleFonts.lexend(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: widget.accentColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  // Top-right Icon Button Container
                  Container(
                    height: 28,
                    width: 28,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.accentColor,
                      size: 15,
                    ),
                  ),
                ],
              ),
              
              // Value & Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    widget.value,
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                  if (widget.badgeText != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      widget.badgeText!,
                      style: GoogleFonts.inter(
                        color: widget.isGrowth
                            ? const Color(0xFF10B981) // Green accent color
                            : Colors.white.withOpacity(0.4), // Neutral gray
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              
              // Subtitle
              Text(
                widget.subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(widget.imagePath),
          fit: BoxFit.contain,
          opacity: 0.12,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            widget.imagePath,
            width: 44,
            height: 44,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Icon(
              widget.icon,
              size: 36,
              color: widget.accentColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.title,
            style: GoogleFonts.lexend(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.backSubtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
