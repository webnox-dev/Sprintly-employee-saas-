import 'package:flutter/material.dart';
import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import '../engine/chess_engine.dart';

class ChessPieceWidget extends StatelessWidget {
  final ChessPiece piece;
  final bool isSelected;
  final double size;

  const ChessPieceWidget({
    super.key,
    required this.piece,
    this.isSelected = false,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isSelected ? 1.15 : 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutBack,
      child: Center(
        child: Container(
          width: size,
          height: size,
          decoration: isSelected
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: piece.color == ChessColor.white
                          ? Colors.white.withValues(alpha: 0.2)
                          : const Color(0xFF475569).withValues(alpha: 0.2),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                )
              : null,
          child: _buildVectorPiece(piece, size),
        ),
      ),
    );
  }

  Widget _buildVectorPiece(ChessPiece piece, double size) {
    final isWhite = piece.color == ChessColor.white;
    
    // Modern curated color palette matching the existing design:
    // White pieces: pure white fill with a solid slate outline for clean contrast.
    // Black pieces: deep slate-blue fill with a subtle light-grey outline.
    final fillColor = isWhite ? Colors.white : const Color(0xFF334155);
    final strokeColor = isWhite ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    switch (piece.type) {
      case PieceType.king:
        return isWhite
            ? WhiteKing(size: size, fillColor: fillColor, strokeColor: strokeColor)
            : BlackKing(size: size, fillColor: fillColor, strokeColor: strokeColor);
      case PieceType.queen:
        return isWhite
            ? WhiteQueen(size: size, fillColor: fillColor, strokeColor: strokeColor)
            : BlackQueen(size: size, fillColor: fillColor, strokeColor: strokeColor);
      case PieceType.rook:
        return isWhite
            ? WhiteRook(size: size, fillColor: fillColor, strokeColor: strokeColor)
            : BlackRook(size: size, fillColor: fillColor, strokeColor: strokeColor);
      case PieceType.bishop:
        return isWhite
            ? WhiteBishop(size: size, fillColor: fillColor, strokeColor: strokeColor)
            : BlackBishop(size: size, fillColor: fillColor, strokeColor: strokeColor);
      case PieceType.knight:
        return isWhite
            ? WhiteKnight(size: size, fillColor: fillColor, strokeColor: strokeColor)
            : BlackKnight(size: size, fillColor: fillColor, strokeColor: strokeColor);
      case PieceType.pawn:
        return isWhite
            ? WhitePawn(size: size, fillColor: fillColor, strokeColor: strokeColor)
            : BlackPawn(size: size, fillColor: fillColor, strokeColor: strokeColor);
    }
  }
}

