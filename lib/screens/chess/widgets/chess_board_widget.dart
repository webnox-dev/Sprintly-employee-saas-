import 'package:flutter/material.dart';
import '../engine/chess_engine.dart';
import 'chess_piece_widget.dart';
import 'promotion_dialog.dart';

class ChessBoardWidget extends StatelessWidget {
  final ChessEngine engine;
  final Function(ChessMove move) onMove;
  final bool isInteractive;
  final bool isFlipped;
  final Position? selectedPosition;
  final Function(Position? pos) onSelectSquare;

  const ChessBoardWidget({
    super.key,
    required this.engine,
    required this.onMove,
    this.isInteractive = true,
    this.isFlipped = false,
    this.selectedPosition,
    required this.onSelectSquare,
  });

  @override
  Widget build(BuildContext context) {
    // Get last move coordinates
    ChessMove? lastMove;
    if (engine.moveHistory.isNotEmpty) {
      lastMove = engine.moveHistory.last;
    }

    // Check if king is in check
    Position? checkKingPos;
    if (engine.isCheck(engine.activeColor)) {
      checkKingPos = engine.findKing(engine.activeColor);
    }

    // Get legal moves for the selected piece
    final selectedLegalMoves = <Position>[];
    if (selectedPosition != null) {
      final pseudo = engine.getPseudoLegalMovesAt(selectedPosition!);
      // Filter out only legal ones
      for (final move in pseudo) {
        // We need to verify the move doesn't leave the king in check
        // We use engine._isMoveLegal or similar. In ChessEngine, _isMoveLegal is private,
        // but we can call engine.getLegalMoves() and filter them!
        final isLegal = engine.getLegalMoves().any((lm) => lm.from == move.from && lm.to == move.to);
        if (isLegal) {
          selectedLegalMoves.add(move.to);
        }
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final squareSize = (boardSize - 24) / 8;

        return Center(
          child: Container(
            width: boardSize,
            height: boardSize,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.04),
                  Colors.white.withOpacity(0.01),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              children: [
                // The Grid board
                Column(
                  children: List.generate(8, (gridRow) {
                    final actualRow = isFlipped ? 7 - gridRow : gridRow;
                    return Expanded(
                      child: Row(
                        children: List.generate(8, (gridCol) {
                          final actualCol = isFlipped ? 7 - gridCol : gridCol;
                          final pos = Position(actualRow, actualCol);
                          final piece = engine.getPieceAt(pos);

                          // Colors & Highlighting
                          final isLightSquare = (actualRow + actualCol) % 2 == 0;
                          Color sqColor = isLightSquare
                              ? Colors.white.withOpacity(0.07)
                              : Colors.black.withOpacity(0.2);

                          // Highlight selected
                          final isSelected = selectedPosition == pos;
                          if (isSelected) {
                            sqColor = const Color(0xFF3B82F6).withOpacity(0.3);
                          }

                          // Highlight last move from/to
                          final isLastMoveSource = lastMove?.from == pos;
                          final isLastMoveDest = lastMove?.to == pos;
                          if (isLastMoveSource || isLastMoveDest) {
                            sqColor = const Color(0xFFEAB308).withOpacity(0.15);
                          }

                          // Highlight King in check
                          final isKingInCheck = checkKingPos == pos;
                          if (isKingInCheck) {
                            sqColor = const Color(0xFFEF4444).withOpacity(0.4);
                          }

                          final hasLegalMove = selectedLegalMoves.contains(pos);

                          return Expanded(
                            child: GestureDetector(
                              onTap: () => _handleSquareTap(context, pos, hasLegalMove),
                              child: Stack(
                                children: [
                                  // Base square background
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: sqColor,
                                      border: isSelected
                                          ? Border.all(color: const Color(0xFF3B82F6), width: 1.5)
                                          : isKingInCheck
                                              ? Border.all(color: const Color(0xFFEF4444), width: 1.5)
                                              : null,
                                    ),
                                  ),

                                  // Render coordinates on board edges
                                  if (gridCol == 0)
                                    Positioned(
                                      top: 4,
                                      left: 4,
                                      child: Text(
                                        '${8 - actualRow}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                    ),
                                  if (gridRow == 7)
                                    Positioned(
                                      bottom: 4,
                                      right: 4,
                                      child: Text(
                                        String.fromCharCode('a'.codeUnitAt(0) + actualCol),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                    ),

                                  // Chess piece representation
                                  if (piece != null)
                                    ChessPieceWidget(
                                      piece: piece,
                                      isSelected: isSelected,
                                      size: squareSize * 0.75,
                                    ),

                                  // Legal move indicators
                                  if (hasLegalMove)
                                    Center(
                                      child: Container(
                                        width: piece != null ? 24 : 14,
                                        height: piece != null ? 24 : 14,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: piece != null
                                              ? const Color(0xFFEF4444).withOpacity(0.4)
                                              : const Color(0xFF3B82F6).withOpacity(0.6),
                                          border: piece != null
                                              ? Border.all(color: const Color(0xFFEF4444), width: 2)
                                              : null,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleSquareTap(BuildContext context, Position pos, bool hasLegalMove) async {
    if (!isInteractive) return;

    if (hasLegalMove && selectedPosition != null) {
      // Complete move
      final piece = engine.getPieceAt(selectedPosition!);
      if (piece == null) return;

      // Check for pawn promotion
      bool isPromotion = false;
      if (piece.type == PieceType.pawn) {
        if ((piece.color == ChessColor.white && pos.row == 0) ||
            (piece.color == ChessColor.black && pos.row == 7)) {
          isPromotion = true;
        }
      }

      PieceType? promotionPiece;
      if (isPromotion) {
        // Show promotion dialog
        promotionPiece = await showDialog<PieceType>(
          context: context,
          barrierDismissible: false,
          builder: (context) => PromotionDialog(color: piece.color),
        );
        if (promotionPiece == null) {
          onSelectSquare(null); // Abort selection
          return;
        }
      }

      // Generate the move
      // Search the matching move in the legal moves list to preserve exact metadata
      final legalMoves = engine.getLegalMoves();
      final exactMove = legalMoves.firstWhere(
        (lm) =>
            lm.from == selectedPosition &&
            lm.to == pos &&
            (promotionPiece == null || lm.promotion == promotionPiece),
        orElse: () {
          // Fallback if not found (shouldn't happen)
          final dummyMove = ChessMove(
            from: selectedPosition!,
            to: pos,
            pieceMoved: piece,
            pieceCaptured: engine.getPieceAt(pos),
            promotion: promotionPiece,
            prevCastlingRights: engine.castlingRights,
            prevEnPassantSquare: engine.enPassantSquare,
            prevHalfmoveClock: engine.halfmoveClock,
          );
          return dummyMove;
        },
      );

      onMove(exactMove);
      onSelectSquare(null);
    } else {
      // Regular selection
      final clickedPiece = engine.getPieceAt(pos);
      if (clickedPiece != null && clickedPiece.color == engine.activeColor) {
        onSelectSquare(pos);
      } else {
        onSelectSquare(null);
      }
    }
  }
}
