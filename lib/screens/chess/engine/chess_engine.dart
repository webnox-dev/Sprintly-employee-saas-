enum ChessColor { white, black }

enum PieceType { pawn, knight, bishop, rook, queen, king }

class Position {
  final int row;
  final int col;

  const Position(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Position &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;

  @override
  String toString() {
    final file = String.fromCharCode('a'.codeUnitAt(0) + col);
    final rank = 8 - row;
    return '$file$rank';
  }

  static Position? fromString(String str) {
    if (str.length != 2) return null;
    final fileChar = str[0].toLowerCase();
    final rankChar = str[1];
    
    final col = fileChar.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.tryParse(rankChar);
    if (rank == null) return null;
    final row = 8 - rank;
    
    if (row < 0 || row > 7 || col < 0 || col > 7) return null;
    return Position(row, col);
  }

  bool get isValid => row >= 0 && row < 8 && col >= 0 && col < 8;
}

class ChessPiece {
  final ChessColor color;
  final PieceType type;

  const ChessPiece(this.color, this.type);

  String get unicodeSymbol {
    switch (type) {
      case PieceType.king:
        return color == ChessColor.white ? '♔\uFE0E' : '♚\uFE0E';
      case PieceType.queen:
        return color == ChessColor.white ? '♕\uFE0E' : '♛\uFE0E';
      case PieceType.rook:
        return color == ChessColor.white ? '♖\uFE0E' : '♜\uFE0E';
      case PieceType.bishop:
        return color == ChessColor.white ? '♗\uFE0E' : '♝\uFE0E';
      case PieceType.knight:
        return color == ChessColor.white ? '♘\uFE0E' : '♞\uFE0E';
      case PieceType.pawn:
        return color == ChessColor.white ? '♙\uFE0E' : '♟\uFE0E';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChessPiece &&
          runtimeType == other.runtimeType &&
          color == other.color &&
          type == other.type;

  @override
  int get hashCode => color.hashCode ^ type.hashCode;

  @override
  String toString() => '${color == ChessColor.white ? "W" : "B"}-${type.name.toUpperCase()}';
}

class CastlingRights {
  final bool whiteKingSide;
  final bool whiteQueenSide;
  final bool blackKingSide;
  final bool blackQueenSide;

  const CastlingRights({
    required this.whiteKingSide,
    required this.whiteQueenSide,
    required this.blackKingSide,
    required this.blackQueenSide,
  });

  CastlingRights copyWith({
    bool? whiteKingSide,
    bool? whiteQueenSide,
    bool? blackKingSide,
    bool? blackQueenSide,
  }) {
    return CastlingRights(
      whiteKingSide: whiteKingSide ?? this.whiteKingSide,
      whiteQueenSide: whiteQueenSide ?? this.whiteQueenSide,
      blackKingSide: blackKingSide ?? this.blackKingSide,
      blackQueenSide: blackQueenSide ?? this.blackQueenSide,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CastlingRights &&
          whiteKingSide == other.whiteKingSide &&
          whiteQueenSide == other.whiteQueenSide &&
          blackKingSide == other.blackKingSide &&
          blackQueenSide == other.blackQueenSide;

  @override
  int get hashCode =>
      whiteKingSide.hashCode ^
      whiteQueenSide.hashCode ^
      blackKingSide.hashCode ^
      blackQueenSide.hashCode;
}

class ChessMove {
  final Position from;
  final Position to;
  final PieceType? promotion;
  final ChessPiece pieceMoved;
  final ChessPiece? pieceCaptured;
  final bool isCastling;
  final bool isEnPassant;
  
  // Undo info
  final CastlingRights prevCastlingRights;
  final Position? prevEnPassantSquare;
  final int prevHalfmoveClock;

  const ChessMove({
    required this.from,
    required this.to,
    this.promotion,
    required this.pieceMoved,
    this.pieceCaptured,
    this.isCastling = false,
    this.isEnPassant = false,
    required this.prevCastlingRights,
    this.prevEnPassantSquare,
    required this.prevHalfmoveClock,
  });

  @override
  String toString() {
    final promoStr = promotion != null ? '=${promotion!.name[0].toUpperCase()}' : '';
    return '$from$to$promoStr';
  }
}

class ChessEngine {
  late List<List<ChessPiece?>> _board;
  late ChessColor _activeColor;
  late CastlingRights _castlingRights;
  late Position? _enPassantSquare;
  late int _halfmoveClock;
  late int _fullmoveNumber;
  late List<ChessMove> _moveHistory;

  // Track positions for 3-fold repetition (FEN strings minus clocks)
  final Map<String, int> _positionCounts = {};

  ChessEngine() {
    reset();
  }

  // Getters
  List<List<ChessPiece?>> get board => _board;
  ChessColor get activeColor => _activeColor;
  CastlingRights get castlingRights => _castlingRights;
  Position? get enPassantSquare => _enPassantSquare;
  int get halfmoveClock => _halfmoveClock;
  int get fullmoveNumber => _fullmoveNumber;
  List<ChessMove> get moveHistory => _moveHistory;

  void reset() {
    _board = List.generate(8, (_) => List.filled(8, null));
    _activeColor = ChessColor.white;
    _castlingRights = const CastlingRights(
      whiteKingSide: true,
      whiteQueenSide: true,
      blackKingSide: true,
      blackQueenSide: true,
    );
    _enPassantSquare = null;
    _halfmoveClock = 0;
    _fullmoveNumber = 1;
    _moveHistory = [];
    _positionCounts.clear();

    // Set up board
    _setupInitialPieces();
    _recordPositionState();
  }

  void _setupInitialPieces() {
    // Rooks
    _board[0][0] = const ChessPiece(ChessColor.black, PieceType.rook);
    _board[0][7] = const ChessPiece(ChessColor.black, PieceType.rook);
    _board[7][0] = const ChessPiece(ChessColor.white, PieceType.rook);
    _board[7][7] = const ChessPiece(ChessColor.white, PieceType.rook);

    // Knights
    _board[0][1] = const ChessPiece(ChessColor.black, PieceType.knight);
    _board[0][6] = const ChessPiece(ChessColor.black, PieceType.knight);
    _board[7][1] = const ChessPiece(ChessColor.white, PieceType.knight);
    _board[7][6] = const ChessPiece(ChessColor.white, PieceType.knight);

    // Bishops
    _board[0][2] = const ChessPiece(ChessColor.black, PieceType.bishop);
    _board[0][5] = const ChessPiece(ChessColor.black, PieceType.bishop);
    _board[7][2] = const ChessPiece(ChessColor.white, PieceType.bishop);
    _board[7][5] = const ChessPiece(ChessColor.white, PieceType.bishop);

    // Queens
    _board[0][3] = const ChessPiece(ChessColor.black, PieceType.queen);
    _board[7][3] = const ChessPiece(ChessColor.white, PieceType.queen);

    // Kings
    _board[0][4] = const ChessPiece(ChessColor.black, PieceType.king);
    _board[7][4] = const ChessPiece(ChessColor.white, PieceType.king);

    // Pawns
    for (int col = 0; col < 8; col++) {
      _board[1][col] = const ChessPiece(ChessColor.black, PieceType.pawn);
      _board[6][col] = const ChessPiece(ChessColor.white, PieceType.pawn);
    }
  }

  // Generate a key that identifies the board state (for threefold repetition)
  String _getStateKey() {
    final sb = StringBuffer();
    // Board state
    for (int r = 0; r < 8; r++) {
      int emptyCount = 0;
      for (int c = 0; c < 8; c++) {
        final p = _board[r][c];
        if (p == null) {
          emptyCount++;
        } else {
          if (emptyCount > 0) {
            sb.write(emptyCount);
            emptyCount = 0;
          }
          final letter = _getPieceLetter(p);
          sb.write(letter);
        }
      }
      if (emptyCount > 0) {
        sb.write(emptyCount);
      }
      if (r < 7) sb.write('/');
    }
    
    // Active Color
    sb.write(_activeColor == ChessColor.white ? ' w ' : ' b ');

    // Castling Rights
    bool anyCastling = false;
    if (_castlingRights.whiteKingSide) { sb.write('K'); anyCastling = true; }
    if (_castlingRights.whiteQueenSide) { sb.write('Q'); anyCastling = true; }
    if (_castlingRights.blackKingSide) { sb.write('k'); anyCastling = true; }
    if (_castlingRights.blackQueenSide) { sb.write('q'); anyCastling = true; }
    if (!anyCastling) sb.write('-');

    // En Passant
    sb.write(' ');
    sb.write(_enPassantSquare != null ? _enPassantSquare.toString() : '-');

    return sb.toString();
  }

  void _recordPositionState() {
    final key = _getStateKey();
    _positionCounts[key] = (_positionCounts[key] ?? 0) + 1;
  }

  void _removePositionState(String key) {
    if (_positionCounts.containsKey(key)) {
      final count = _positionCounts[key]!;
      if (count == 1) {
        _positionCounts.remove(key);
      } else {
        _positionCounts[key] = count - 1;
      }
    }
  }

  String _getPieceLetter(ChessPiece p) {
    final letter = () {
      switch (p.type) {
        case PieceType.pawn: return 'p';
        case PieceType.knight: return 'n';
        case PieceType.bishop: return 'b';
        case PieceType.rook: return 'r';
        case PieceType.queen: return 'q';
        case PieceType.king: return 'k';
      }
    }();
    return p.color == ChessColor.white ? letter.toUpperCase() : letter;
  }

  ChessPiece? getPieceAt(Position pos) {
    if (!pos.isValid) return null;
    return _board[pos.row][pos.col];
  }

  // Load state from FEN
  bool loadFEN(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return false;

    try {
      final boardPart = parts[0];
      final newBoard = List.generate(8, (_) => List<ChessPiece?>.filled(8, null));
      final rows = boardPart.split('/');
      if (rows.length != 8) return false;

      for (int r = 0; r < 8; r++) {
        final rowStr = rows[r];
        int c = 0;
        for (int i = 0; i < rowStr.length; i++) {
          final char = rowStr[i];
          final digit = int.tryParse(char);
          if (digit != null) {
            c += digit;
          } else {
            final color = char == char.toUpperCase() ? ChessColor.white : ChessColor.black;
            final lowerChar = char.toLowerCase();
            final PieceType type;
            if (lowerChar == 'p') {
              type = PieceType.pawn;
            } else if (lowerChar == 'n') {
              type = PieceType.knight;
            } else if (lowerChar == 'b') {
              type = PieceType.bishop;
            } else if (lowerChar == 'r') {
              type = PieceType.rook;
            } else if (lowerChar == 'q') {
              type = PieceType.queen;
            } else if (lowerChar == 'k') {
              type = PieceType.king;
            } else {
              return false;
            }

            newBoard[r][c] = ChessPiece(color, type);
            c++;
          }
        }
        if (c != 8) return false;
      }

      // 2. Active Color
      ChessColor newActiveColor = ChessColor.white;
      if (parts.length > 1) {
        newActiveColor = parts[1] == 'b' ? ChessColor.black : ChessColor.white;
      }

      // 3. Castling Rights
      bool wK = false, wQ = false, bK = false, bQ = false;
      if (parts.length > 2) {
        final rights = parts[2];
        if (rights.contains('K')) wK = true;
        if (rights.contains('Q')) wQ = true;
        if (rights.contains('k')) bK = true;
        if (rights.contains('q')) bQ = true;
      } else {
        wK = wQ = bK = bQ = true;
      }

      // 4. En Passant Square
      Position? newEnPassant;
      if (parts.length > 3 && parts[3] != '-') {
        newEnPassant = Position.fromString(parts[3]);
      }

      // 5. Halfmove Clock
      int newHalfmove = 0;
      if (parts.length > 4) {
        newHalfmove = int.tryParse(parts[4]) ?? 0;
      }

      // 6. Fullmove Number
      int newFullmove = 1;
      if (parts.length > 5) {
        newFullmove = int.tryParse(parts[5]) ?? 1;
      }

      // Set state
      _board = newBoard;
      _activeColor = newActiveColor;
      _castlingRights = CastlingRights(
        whiteKingSide: wK,
        whiteQueenSide: wQ,
        blackKingSide: bK,
        blackQueenSide: bQ,
      );
      _enPassantSquare = newEnPassant;
      _halfmoveClock = newHalfmove;
      _fullmoveNumber = newFullmove;
      _moveHistory = [];
      _positionCounts.clear();
      _recordPositionState();
      return true;
    } catch (_) {
      return false;
    }
  }

  // Export state to FEN
  String toFEN() {
    final sb = StringBuffer();
    // Board state
    for (int r = 0; r < 8; r++) {
      int emptyCount = 0;
      for (int c = 0; c < 8; c++) {
        final p = _board[r][c];
        if (p == null) {
          emptyCount++;
        } else {
          if (emptyCount > 0) {
            sb.write(emptyCount);
            emptyCount = 0;
          }
          sb.write(_getPieceLetter(p));
        }
      }
      if (emptyCount > 0) {
        sb.write(emptyCount);
      }
      if (r < 7) sb.write('/');
    }

    // Active Color
    sb.write(_activeColor == ChessColor.white ? ' w ' : ' b ');

    // Castling Rights
    bool anyCastling = false;
    if (_castlingRights.whiteKingSide) { sb.write('K'); anyCastling = true; }
    if (_castlingRights.whiteQueenSide) { sb.write('Q'); anyCastling = true; }
    if (_castlingRights.blackKingSide) { sb.write('k'); anyCastling = true; }
    if (_castlingRights.blackQueenSide) { sb.write('q'); anyCastling = true; }
    if (!anyCastling) sb.write('-');

    // En Passant
    sb.write(' ');
    sb.write(_enPassantSquare != null ? _enPassantSquare.toString() : '-');

    // Halfmove & Fullmove
    sb.write(' $_halfmoveClock $_fullmoveNumber');

    return sb.toString();
  }

  // Find King position
  Position findKing(ChessColor color) {
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = _board[r][c];
        if (p != null && p.type == PieceType.king && p.color == color) {
          return Position(r, c);
        }
      }
    }
    // Fallback (should never happen in normal play)
    return const Position(0, 0);
  }

  // Check if a square is attacked by an opponent
  bool isSquareAttacked(Position square, ChessColor attackerColor) {
    // We check all directions/knights jumps from 'square' and see if they map to attacker pieces
    
    // 1. Knight attacks
    final knightOffsets = [
      [-2, -1], [-2, 1], [-1, -2], [-1, 2],
      [1, -2], [1, 2], [2, -1], [2, 1]
    ];
    for (final off in knightOffsets) {
      final target = Position(square.row + off[0], square.col + off[1]);
      if (target.isValid) {
        final p = getPieceAt(target);
        if (p != null && p.color == attackerColor && p.type == PieceType.knight) {
          return true;
        }
      }
    }

    // 2. Straight attacks (Rook/Queen)
    final straightDirs = [[-1, 0], [1, 0], [0, -1], [0, 1]];
    for (final dir in straightDirs) {
      int r = square.row + dir[0];
      int c = square.col + dir[1];
      while (r >= 0 && r < 8 && c >= 0 && c < 8) {
        final p = _board[r][c];
        if (p != null) {
          if (p.color == attackerColor && (p.type == PieceType.rook || p.type == PieceType.queen)) {
            return true;
          }
          break; // Blocked
        }
        r += dir[0];
        c += dir[1];
      }
    }

    // 3. Diagonal attacks (Bishop/Queen)
    final diagDirs = [[-1, -1], [-1, 1], [1, -1], [1, 1]];
    for (final dir in diagDirs) {
      int r = square.row + dir[0];
      int c = square.col + dir[1];
      while (r >= 0 && r < 8 && c >= 0 && c < 8) {
        final p = _board[r][c];
        if (p != null) {
          if (p.color == attackerColor && (p.type == PieceType.bishop || p.type == PieceType.queen)) {
            return true;
          }
          break; // Blocked
        }
        r += dir[0];
        c += dir[1];
      }
    }

    // 4. Pawn attacks
    final pawnRowOffset = attackerColor == ChessColor.white ? 1 : -1;
    final pawnLeft = Position(square.row + pawnRowOffset, square.col - 1);
    final pawnRight = Position(square.row + pawnRowOffset, square.col + 1);
    for (final pPos in [pawnLeft, pawnRight]) {
      if (pPos.isValid) {
        final p = getPieceAt(pPos);
        if (p != null && p.color == attackerColor && p.type == PieceType.pawn) {
          return true;
        }
      }
    }

    // 5. King attacks (adjacent)
    final kingDirs = [
      [-1, -1], [-1, 0], [-1, 1],
      [0, -1],           [0, 1],
      [1, -1],  [1, 0],  [1, 1]
    ];
    for (final dir in kingDirs) {
      final target = Position(square.row + dir[0], square.col + dir[1]);
      if (target.isValid) {
        final p = getPieceAt(target);
        if (p != null && p.color == attackerColor && p.type == PieceType.king) {
          return true;
        }
      }
    }

    return false;
  }

  // Is active color in check?
  bool isCheck(ChessColor color) {
    final kingPos = findKing(color);
    final opponent = color == ChessColor.white ? ChessColor.black : ChessColor.white;
    return isSquareAttacked(kingPos, opponent);
  }

  // Generate pseudo-legal moves for a specific piece
  List<ChessMove> getPseudoLegalMovesAt(Position from) {
    final piece = getPieceAt(from);
    if (piece == null || piece.color != _activeColor) return [];

    final List<ChessMove> moves = [];
    final r = from.row;
    final c = from.col;

    switch (piece.type) {
      case PieceType.pawn:
        final dir = piece.color == ChessColor.white ? -1 : 1;
        final startRow = piece.color == ChessColor.white ? 6 : 1;
        final promotionRow = piece.color == ChessColor.white ? 0 : 7;

        // 1 step forward
        final oneStep = Position(r + dir, c);
        if (oneStep.isValid && getPieceAt(oneStep) == null) {
          if (oneStep.row == promotionRow) {
            for (final type in [PieceType.queen, PieceType.rook, PieceType.bishop, PieceType.knight]) {
              moves.add(_createMove(from, oneStep, promotion: type));
            }
          } else {
            moves.add(_createMove(from, oneStep));
            
            // 2 steps forward
            final twoStep = Position(r + 2 * dir, c);
            if (r == startRow && getPieceAt(twoStep) == null) {
              moves.add(_createMove(from, twoStep));
            }
          }
        }

        // Standard Captures & En Passant
        for (final colOffset in [-1, 1]) {
          final target = Position(r + dir, c + colOffset);
          if (target.isValid) {
            final targetPiece = getPieceAt(target);
            if (targetPiece != null && targetPiece.color != piece.color) {
              if (target.row == promotionRow) {
                for (final type in [PieceType.queen, PieceType.rook, PieceType.bishop, PieceType.knight]) {
                  moves.add(_createMove(from, target, promotion: type, pieceCaptured: targetPiece));
                }
              } else {
                moves.add(_createMove(from, target, pieceCaptured: targetPiece));
              }
            } else if (_enPassantSquare != null && target == _enPassantSquare) {
              final capturedPawn = getPieceAt(Position(r, c + colOffset));
              moves.add(_createMove(from, target, pieceCaptured: capturedPawn, isEnPassant: true));
            }
          }
        }
        break;

      case PieceType.knight:
        final offsets = [
          [-2, -1], [-2, 1], [-1, -2], [-1, 2],
          [1, -2], [1, 2], [2, -1], [2, 1]
        ];
        for (final off in offsets) {
          final target = Position(r + off[0], c + off[1]);
          if (target.isValid) {
            final targetPiece = getPieceAt(target);
            if (targetPiece == null || targetPiece.color != piece.color) {
              moves.add(_createMove(from, target, pieceCaptured: targetPiece));
            }
          }
        }
        break;

      case PieceType.bishop:
        _addSlidingMoves(moves, from, [[-1, -1], [-1, 1], [1, -1], [1, 1]]);
        break;

      case PieceType.rook:
        _addSlidingMoves(moves, from, [[-1, 0], [1, 0], [0, -1], [0, 1]]);
        break;

      case PieceType.queen:
        _addSlidingMoves(moves, from, [
          [-1, -1], [-1, 1], [1, -1], [1, 1],
          [-1, 0], [1, 0], [0, -1], [0, 1]
        ]);
        break;

      case PieceType.king:
        final dirs = [
          [-1, -1], [-1, 0], [-1, 1],
          [0, -1],           [0, 1],
          [1, -1],  [1, 0],  [1, 1]
        ];
        for (final dir in dirs) {
          final target = Position(r + dir[0], c + dir[1]);
          if (target.isValid) {
            final targetPiece = getPieceAt(target);
            if (targetPiece == null || targetPiece.color != piece.color) {
              moves.add(_createMove(from, target, pieceCaptured: targetPiece));
            }
          }
        }

        // Castling
        final isWhite = piece.color == ChessColor.white;
        final backRow = isWhite ? 7 : 0;
        final oppColor = isWhite ? ChessColor.black : ChessColor.white;

        if (r == backRow && c == 4) {
          // King-side
          final canKingSide = isWhite ? _castlingRights.whiteKingSide : _castlingRights.blackKingSide;
          if (canKingSide) {
            final f5 = getPieceAt(Position(backRow, 5));
            final f6 = getPieceAt(Position(backRow, 6));
            if (f5 == null && f6 == null) {
              if (!isSquareAttacked(Position(backRow, 4), oppColor) &&
                  !isSquareAttacked(Position(backRow, 5), oppColor) &&
                  !isSquareAttacked(Position(backRow, 6), oppColor)) {
                moves.add(_createMove(from, Position(backRow, 6), isCastling: true));
              }
            }
          }

          // Queen-side
          final canQueenSide = isWhite ? _castlingRights.whiteQueenSide : _castlingRights.blackQueenSide;
          if (canQueenSide) {
            final f3 = getPieceAt(Position(backRow, 3));
            final f2 = getPieceAt(Position(backRow, 2));
            final f1 = getPieceAt(Position(backRow, 1));
            if (f3 == null && f2 == null && f1 == null) {
              if (!isSquareAttacked(Position(backRow, 4), oppColor) &&
                  !isSquareAttacked(Position(backRow, 3), oppColor) &&
                  !isSquareAttacked(Position(backRow, 2), oppColor)) {
                moves.add(_createMove(from, Position(backRow, 2), isCastling: true));
              }
            }
          }
        }
        break;
    }

    return moves;
  }

  void _addSlidingMoves(List<ChessMove> moves, Position from, List<List<int>> dirs) {
    final piece = getPieceAt(from)!;
    for (final dir in dirs) {
      int r = from.row + dir[0];
      int c = from.col + dir[1];
      while (r >= 0 && r < 8 && c >= 0 && c < 8) {
        final target = Position(r, c);
        final targetPiece = getPieceAt(target);
        if (targetPiece == null) {
          moves.add(_createMove(from, target));
        } else {
          if (targetPiece.color != piece.color) {
            moves.add(_createMove(from, target, pieceCaptured: targetPiece));
          }
          break; // Blocked
        }
        r += dir[0];
        c += dir[1];
      }
    }
  }

  ChessMove _createMove(
    Position from,
    Position to, {
    PieceType? promotion,
    ChessPiece? pieceCaptured,
    bool isCastling = false,
    bool isEnPassant = false,
  }) {
    return ChessMove(
      from: from,
      to: to,
      promotion: promotion,
      pieceMoved: getPieceAt(from)!,
      pieceCaptured: pieceCaptured,
      isCastling: isCastling,
      isEnPassant: isEnPassant,
      prevCastlingRights: _castlingRights,
      prevEnPassantSquare: _enPassantSquare,
      prevHalfmoveClock: _halfmoveClock,
    );
  }

  // Get all legal moves for active player
  List<ChessMove> getLegalMoves() {
    final List<ChessMove> legalMoves = [];
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = _board[r][c];
        if (p != null && p.color == _activeColor) {
          final pseudo = getPseudoLegalMovesAt(Position(r, c));
          for (final move in pseudo) {
            if (_isMoveLegal(move)) {
              legalMoves.add(move);
            }
          }
        }
      }
    }
    return legalMoves;
  }

  // Helper to check if pseudo-legal move leaves king in check
  bool _isMoveLegal(ChessMove move) {
    // Make move (low-level board swap only, no history)
    final from = move.from;
    final to = move.to;
    final tempPiece = _board[to.row][to.col];
    
    // Perform temporary movement
    _board[to.row][to.col] = _board[from.row][from.col];
    _board[from.row][from.col] = null;
    
    // For en passant, remove pawn temporarily
    ChessPiece? epPawn;
    Position? epPawnPos;
    if (move.isEnPassant) {
      epPawnPos = Position(from.row, to.col);
      epPawn = _board[epPawnPos.row][epPawnPos.col];
      _board[epPawnPos.row][epPawnPos.col] = null;
    }

    final kingCheck = isCheck(_activeColor);

    // Revert
    if (move.isEnPassant && epPawnPos != null) {
      _board[epPawnPos.row][epPawnPos.col] = epPawn;
    }
    _board[from.row][from.col] = _board[to.row][to.col];
    _board[to.row][to.col] = tempPiece;

    return !kingCheck;
  }

  // Make move on engine
  void makeMove(ChessMove move) {
    final from = move.from;
    final to = move.to;
    final piece = move.pieceMoved;

    // Increment/reset halfmove clock
    if (piece.type == PieceType.pawn || move.pieceCaptured != null) {
      _halfmoveClock = 0;
    } else {
      _halfmoveClock++;
    }

    // Handle normal captures & moves
    _board[from.row][from.col] = null;
    if (move.promotion != null) {
      _board[to.row][to.col] = ChessPiece(piece.color, move.promotion!);
    } else {
      _board[to.row][to.col] = piece;
    }

    // En Passant capture
    if (move.isEnPassant) {
      _board[from.row][to.col] = null;
    }

    // Castling rook move
    if (move.isCastling) {
      final isKingSide = to.col == 6;
      final backRow = piece.color == ChessColor.white ? 7 : 0;
      if (isKingSide) {
        // Move Rook from col 7 to col 5
        _board[backRow][5] = _board[backRow][7];
        _board[backRow][7] = null;
      } else {
        // Move Rook from col 0 to col 3
        _board[backRow][3] = _board[backRow][0];
        _board[backRow][0] = null;
      }
    }

    // Update Castling Rights
    // If king moved
    if (piece.type == PieceType.king) {
      if (piece.color == ChessColor.white) {
        _castlingRights = _castlingRights.copyWith(whiteKingSide: false, whiteQueenSide: false);
      } else {
        _castlingRights = _castlingRights.copyWith(blackKingSide: false, blackQueenSide: false);
      }
    }
    // If rook moved or was captured
    if (from.row == 7 && from.col == 0 || to.row == 7 && to.col == 0) {
      _castlingRights = _castlingRights.copyWith(whiteQueenSide: false);
    }
    if (from.row == 7 && from.col == 7 || to.row == 7 && to.col == 7) {
      _castlingRights = _castlingRights.copyWith(whiteKingSide: false);
    }
    if (from.row == 0 && from.col == 0 || to.row == 0 && to.col == 0) {
      _castlingRights = _castlingRights.copyWith(blackQueenSide: false);
    }
    if (from.row == 0 && from.col == 7 || to.row == 0 && to.col == 7) {
      _castlingRights = _castlingRights.copyWith(blackKingSide: false);
    }

    // En Passant square candidate update
    if (piece.type == PieceType.pawn && (to.row - from.row).abs() == 2) {
      _enPassantSquare = Position((from.row + to.row) ~/ 2, from.col);
    } else {
      _enPassantSquare = null;
    }

    // Increment fullmove
    if (_activeColor == ChessColor.black) {
      _fullmoveNumber++;
    }

    // Swap active color
    _activeColor = _activeColor == ChessColor.white ? ChessColor.black : ChessColor.white;

    // Add to history
    _moveHistory.add(move);

    // Record new position state
    _recordPositionState();
  }

  // Undo last move
  void undoMove() {
    if (_moveHistory.isEmpty) return;

    final keyBefore = _getStateKey();
    _removePositionState(keyBefore);

    final move = _moveHistory.removeLast();
    final from = move.from;
    final to = move.to;
    final piece = move.pieceMoved;

    // Restore previous general values
    _castlingRights = move.prevCastlingRights;
    _enPassantSquare = move.prevEnPassantSquare;
    _halfmoveClock = move.prevHalfmoveClock;

    // Reverse color swap
    _activeColor = _activeColor == ChessColor.white ? ChessColor.black : ChessColor.white;

    // Reverse fullmove increment
    if (_activeColor == ChessColor.black) {
      _fullmoveNumber--;
    }

    // Restore board
    _board[from.row][from.col] = piece;
    _board[to.row][to.col] = move.pieceCaptured;

    // Undo En Passant capture details
    if (move.isEnPassant) {
      // Re-place captured pawn back on its square
      final capColor = _activeColor == ChessColor.white ? ChessColor.black : ChessColor.white;
      _board[from.row][to.col] = ChessPiece(capColor, PieceType.pawn);
      _board[to.row][to.col] = null; // empty EP square
    }

    // Undo Castling rook move
    if (move.isCastling) {
      final isKingSide = to.col == 6;
      final backRow = piece.color == ChessColor.white ? 7 : 0;
      if (isKingSide) {
        // Move Rook back from col 5 to col 7
        _board[backRow][7] = _board[backRow][5];
        _board[backRow][5] = null;
      } else {
        // Move Rook back from col 3 to col 0
        _board[backRow][0] = _board[backRow][3];
        _board[backRow][3] = null;
      }
    }
  }

  // Game End conditions
  bool isCheckmate() {
    return isCheck(_activeColor) && getLegalMoves().isEmpty;
  }

  bool isStalemate() {
    return !isCheck(_activeColor) && getLegalMoves().isEmpty;
  }

  // 50-move rule
  bool isFiftyMoveRule() {
    return _halfmoveClock >= 100; // 50 moves for each side = 100 plies
  }

  // Threefold repetition
  bool isThreefoldRepetition() {
    final key = _getStateKey();
    return (_positionCounts[key] ?? 0) >= 3;
  }

  // Insufficient material check
  bool isInsufficientMaterial() {
    final pieces = <ChessPiece>[];
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = _board[r][c];
        if (p != null) pieces.add(p);
      }
    }

    // King vs King
    if (pieces.length == 2) return true;

    // King + Bishop vs King OR King + Knight vs King
    if (pieces.length == 3) {
      return pieces.any((p) => p.type == PieceType.bishop || p.type == PieceType.knight);
    }

    // King + Bishop vs King + Bishop (on same square color)
    if (pieces.length == 4) {
      final bishops = <Position>[];
      for (int r = 0; r < 8; r++) {
        for (int c = 0; c < 8; c++) {
          final p = _board[r][c];
          if (p != null && p.type == PieceType.bishop) {
            bishops.add(Position(r, c));
          }
        }
      }
      if (bishops.length == 2) {
        // Check if bishops are on the same square color: (row + col) % 2 is same
        final color1 = (bishops[0].row + bishops[0].col) % 2;
        final color2 = (bishops[1].row + bishops[1].col) % 2;
        return color1 == color2;
      }
    }

    return false;
  }

  bool isDraw() {
    return isStalemate() || isFiftyMoveRule() || isThreefoldRepetition() || isInsufficientMaterial();
  }
}
