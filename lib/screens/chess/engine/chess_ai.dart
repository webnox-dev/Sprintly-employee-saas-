import 'dart:math';
import 'chess_engine.dart';

class ChessAI {
  static final Random _random = Random();

  // Piece values
  static const int _pawnVal = 100;
  static const int _knightVal = 320;
  static const int _bishopVal = 330;
  static const int _rookVal = 500;
  static const int _queenVal = 900;
  static const int _kingVal = 20000;

  // Piece-Square Tables (White's perspective, row 0 is top rank 8, row 7 is bottom rank 1)
  static const List<List<int>> _pawnTable = [
    [ 0,  0,  0,  0,  0,  0,  0,  0],
    [50, 50, 50, 50, 50, 50, 50, 50],
    [10, 10, 20, 30, 30, 20, 10, 10],
    [ 5,  5, 10, 25, 25, 10,  5,  5],
    [ 0,  0,  0, 20, 20,  0,  0,  0],
    [ 5, -5,-10,  0,  0,-10, -5,  5],
    [ 5, 10, 10,-20,-20, 10, 10,  5],
    [ 0,  0,  0,  0,  0,  0,  0,  0]
  ];

  static const List<List<int>> _knightTable = [
    [-50,-40,-30,-30,-30,-30,-40,-50],
    [-40,-20,  0,  0,  0,  0,-20,-40],
    [-30,  0, 10, 15, 15, 10,  0,-30],
    [-30,  5, 15, 20, 20, 15,  5,-30],
    [-30,  0, 15, 20, 20, 15,  0,-30],
    [-30,  5, 10, 15, 15, 10,  5,-30],
    [-40,-20,  0,  5,  5,  0,-20,-40],
    [-50,-40,-30,-30,-30,-30,-40,-50]
  ];

  static const List<List<int>> _bishopTable = [
    [-20,-10,-10,-10,-10,-10,-10,-20],
    [-10,  0,  0,  0,  0,  0,  0,-10],
    [-10,  0,  5, 10, 10,  5,  0,-10],
    [-10,  5,  5, 10, 10,  5,  5,-10],
    [-10,  0, 10, 10, 10, 10,  0,-10],
    [-10, 10, 10, 10, 10, 10, 10,-10],
    [-10,  5,  0,  0,  0,  0,  5,-10],
    [-20,-10,-10,-10,-10,-10,-10,-20]
  ];

  static const List<List<int>> _rookTable = [
    [ 0,  0,  0,  0,  0,  0,  0,  0],
    [ 5, 10, 10, 10, 10, 10, 10,  5],
    [-5,  0,  0,  0,  0,  0,  0, -5],
    [-5,  0,  0,  0,  0,  0,  0, -5],
    [-5,  0,  0,  0,  0,  0,  0, -5],
    [-5,  0,  0,  0,  0,  0,  0, -5],
    [-5,  0,  0,  0,  0,  0,  0, -5],
    [ 0,  0,  0,  5,  5,  0,  0,  0]
  ];

  static const List<List<int>> _queenTable = [
    [-20,-10,-10, -5, -5,-10,-10,-20],
    [-10,  0,  0,  0,  0,  0,  0,-10],
    [-10,  0,  5,  5,  5,  5,  0,-10],
    [ -5,  0,  5,  5,  5,  5,  0, -5],
    [  0,  0,  5,  5,  5,  5,  0, -5],
    [-10,  5,  5,  5,  5,  5,  5,-10],
    [-10,  0,  5,  0,  0,  5,  0,-10],
    [-20,-10,-10, -5, -5,-10,-10,-20]
  ];

  static const List<List<int>> _kingTable = [
    [-30,-40,-40,-50,-50,-40,-40,-30],
    [-30,-40,-40,-50,-50,-40,-40,-30],
    [-30,-40,-40,-50,-50,-40,-40,-30],
    [-30,-40,-40,-50,-50,-40,-40,-30],
    [-20,-30,-30,-40,-40,-30,-30,-20],
    [-10,-20,-20,-20,-20,-20,-20,-10],
    [ 20, 20,  0,  0,  0,  0, 20, 20],
    [ 20, 30, 10,  0,  0, 10, 30, 20]
  ];

  static int _getPieceValue(PieceType type) {
    switch (type) {
      case PieceType.pawn: return _pawnVal;
      case PieceType.knight: return _knightVal;
      case PieceType.bishop: return _bishopVal;
      case PieceType.rook: return _rookVal;
      case PieceType.queen: return _queenVal;
      case PieceType.king: return _kingVal;
    }
  }

  static int _getPositionValue(ChessPiece piece, int row, int col) {
    // For Black, mirror the board row vertically
    final r = piece.color == ChessColor.white ? row : (7 - row);
    final c = col;

    switch (piece.type) {
      case PieceType.pawn:
        return _pawnTable[r][c];
      case PieceType.knight:
        return _knightTable[r][c];
      case PieceType.bishop:
        return _bishopTable[r][c];
      case PieceType.rook:
        return _rookTable[r][c];
      case PieceType.queen:
        return _queenTable[r][c];
      case PieceType.king:
        return _kingTable[r][c];
    }
  }

  // Evaluate board. Positive = White advantage, Negative = Black advantage.
  static int evaluateBoard(ChessEngine engine) {
    if (engine.isCheckmate()) {
      return engine.activeColor == ChessColor.white ? -999999 : 999999;
    }
    if (engine.isDraw()) {
      return 0;
    }

    int score = 0;
    final board = engine.board;

    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final piece = board[r][c];
        if (piece == null) continue;

        final val = _getPieceValue(piece.type);
        final posVal = _getPositionValue(piece, r, c);

        if (piece.color == ChessColor.white) {
          score += (val + posVal);
        } else {
          score -= (val + posVal);
        }
      }
    }
    return score;
  }

  // Get best move based on difficulty
  static ChessMove? getBestMove(ChessEngine engine, String difficulty) {
    final legalMoves = engine.getLegalMoves();
    if (legalMoves.isEmpty) return null;

    final diff = difficulty.toLowerCase();

    if (diff == 'easy') {
      // 35% chance of making a random move
      if (_random.nextDouble() < 0.35) {
        return legalMoves[_random.nextInt(legalMoves.length)];
      }
      return _searchBestMove(engine, 1);
    } else if (diff == 'medium') {
      // 10% chance of making a random move, otherwise search to depth 2
      if (_random.nextDouble() < 0.10) {
        return legalMoves[_random.nextInt(legalMoves.length)];
      }
      return _searchBestMove(engine, 2);
    } else {
      // Hard: search depth 3
      return _searchBestMove(engine, 3);
    }
  }

  static ChessMove _searchBestMove(ChessEngine engine, int depth) {
    final moves = engine.getLegalMoves();
    _orderMoves(moves, engine);

    ChessMove bestMove = moves[0];
    final isWhite = engine.activeColor == ChessColor.white;

    if (isWhite) {
      int bestScore = -1000000;
      for (final move in moves) {
        engine.makeMove(move);
        final score = _minimax(engine, depth - 1, -1000000, 1000000, false);
        engine.undoMove();
        if (score > bestScore) {
          bestScore = score;
          bestMove = move;
        }
      }
    } else {
      int bestScore = 1000000;
      for (final move in moves) {
        engine.makeMove(move);
        final score = _minimax(engine, depth - 1, -1000000, 1000000, true);
        engine.undoMove();
        if (score < bestScore) {
          bestScore = score;
          bestMove = move;
        }
      }
    }
    return bestMove;
  }

  static int _minimax(ChessEngine engine, int depth, int alpha, int beta, bool isMaximizing) {
    if (depth == 0 || engine.isDraw() || engine.isCheckmate() || engine.isStalemate()) {
      return evaluateBoard(engine);
    }

    final moves = engine.getLegalMoves();
    _orderMoves(moves, engine);

    if (isMaximizing) {
      int maxEval = -1000000;
      for (final move in moves) {
        engine.makeMove(move);
        final eval = _minimax(engine, depth - 1, alpha, beta, false);
        engine.undoMove();
        maxEval = max(maxEval, eval);
        alpha = max(alpha, eval);
        if (beta <= alpha) {
          break; // Prune
        }
      }
      return maxEval;
    } else {
      int minEval = 1000000;
      for (final move in moves) {
        engine.makeMove(move);
        final eval = _minimax(engine, depth - 1, alpha, beta, true);
        engine.undoMove();
        minEval = min(minEval, eval);
        beta = min(beta, eval);
        if (beta <= alpha) {
          break; // Prune
        }
      }
      return minEval;
    }
  }

  static void _orderMoves(List<ChessMove> moves, ChessEngine engine) {
    moves.sort((a, b) {
      final scoreA = _getMoveHeuristicScore(a, engine);
      final scoreB = _getMoveHeuristicScore(b, engine);
      return scoreB.compareTo(scoreA); // Descending (highest score first)
    });
  }

  static int _getMoveHeuristicScore(ChessMove move, ChessEngine engine) {
    int score = 0;

    // Promotion bonus
    if (move.promotion != null) {
      score += 9000 + _getPieceValue(move.promotion!);
    }

    // Capture bonus (MVV-LVA)
    if (move.pieceCaptured != null) {
      final victimVal = _getPieceValue(move.pieceCaptured!.type);
      final attackerVal = _getPieceValue(move.pieceMoved.type);
      // Higher score if low value attacker captures high value victim
      score += 10000 + (victimVal - (attackerVal ~/ 100));
    }

    // Castling bonus
    if (move.isCastling) {
      score += 1000;
    }

    // Positional shift bonus
    final fromPosScore = _getPositionValue(move.pieceMoved, move.from.row, move.from.col);
    final toPosScore = _getPositionValue(move.pieceMoved, move.to.row, move.to.col);
    score += (toPosScore - fromPosScore);

    return score;
  }
}
