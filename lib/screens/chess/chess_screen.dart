import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'engine/chess_engine.dart';
import 'engine/chess_ai.dart';
import 'widgets/chess_board_widget.dart';
import 'widgets/chess_piece_widget.dart';
import 'package:webnox_taskops/utils/responsive_utils.dart';
import 'package:provider/provider.dart';
import '../../view_model/team_sync_view_model.dart';
import '../../view_model/auth_view_model.dart';
import '../../services/chat_websocket_service.dart';
import '../../services/local_storage_service.dart';

class ChessScreen extends StatefulWidget {
  const ChessScreen({super.key});

  @override
  State<ChessScreen> createState() => _ChessScreenState();
}

class _ChessScreenState extends State<ChessScreen> {
  late ChessEngine _engine;
  Position? _selectedSquare;
  bool _gameStarted = false;
  String _gameMode = 'computer'; // 'computer', 'employee', 'employee_online'
  String _difficulty = 'medium'; // 'easy', 'medium', 'hard'
  ChessColor _playerColor = ChessColor.white;
  bool _aiThinking = false;
  bool _boardFlipped = false;
  
  // Game state
  ChessColor? _winner;
  bool _isDraw = false;
  String _drawReason = '';

  final ScrollController _moveHistoryScrollController = ScrollController();

  StreamSubscription? _chessSubscription;
  String? _gameId;
  String? _opponentId;
  String? _opponentType;
  bool _isSearchingEmployees = false;
  
  // Timer State
  Timer? _gameTimer;
  String _timerOption = 'none'; // 'none', '10min', '30min'
  Duration _whiteTimeRemaining = Duration.zero;
  Duration _blackTimeRemaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _engine = ChessEngine();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initWebSocketAndPresence();
    });
  }

  @override
  void dispose() {
    _stopGameTimer();
    _chessSubscription?.cancel();
    _moveHistoryScrollController.dispose();
    super.dispose();
  }

  void _stopGameTimer() {
    _gameTimer?.cancel();
    _gameTimer = null;
  }

  void _startGameTimer() {
    _stopGameTimer(); // Reset existing timer if any
    
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_gameStarted || _winner != null || _isDraw) {
        _stopGameTimer();
        return;
      }

      setState(() {
        if (_engine.activeColor == ChessColor.white) {
          final newSeconds = _whiteTimeRemaining.inSeconds - 1;
          if (newSeconds <= 0) {
            _whiteTimeRemaining = Duration.zero;
            _winner = ChessColor.black;
            _drawReason = 'Timeout';
            _stopGameTimer();
            _showGameOverDialog('White ran out of time! Black wins.');
          } else {
            _whiteTimeRemaining = Duration(seconds: newSeconds);
          }
        } else {
          final newSeconds = _blackTimeRemaining.inSeconds - 1;
          if (newSeconds <= 0) {
            _blackTimeRemaining = Duration.zero;
            _winner = ChessColor.white;
            _drawReason = 'Timeout';
            _stopGameTimer();
            _showGameOverDialog('Black ran out of time! White wins.');
          } else {
            _blackTimeRemaining = Duration(seconds: newSeconds);
          }
        }
      });
    });
  }

  Future<void> _initWebSocketAndPresence() async {
    final teamSyncVM = context.read<TeamSyncViewModel>();
    
    // Connect to WebSocket if not already initialized
    if (!teamSyncVM.isInitialized) {
      final authVM = context.read<AuthViewModel>();
      final localStorage = LocalStorageService();
      final employeeDetails = await authVM.getCurrentEmployeeDetails();
      final userId = employeeDetails?['employee_id'] as String?;
      final token = localStorage.accessToken;
      if (userId != null && token.isNotEmpty) {
        await teamSyncVM.initialize(
          token: token,
          userId: userId,
          userType: 'Employee',
          userName: authVM.currentUserProfile?.name,
          userImage: authVM.currentUserProfile?.img,
        );
      }
    }
    
    // Subscribe to chess events
    _chessSubscription = teamSyncVM.chessEventsStream.listen(_handleChessEvent);
  }

  void _handleChessEvent(ChatEvent event) {
    final data = event.data;
    if (data == null) return;

    switch (event.type) {
      case ChatEventType.chessChallengeReceived:
        final challengerId = data['challengerId'] as String?;
        final challengerType = data['challengerType'] as String? ?? 'Employee';
        final challengerName = data['challengerName'] as String? ?? 'An employee';
        
        _showChallengeRequestDialog(challengerId, challengerType, challengerName);
        break;

      case ChatEventType.chessGameStarted:
        final gameId = data['gameId'] as String?;
        final opponentId = data['opponentId'] as String?;
        final opponentType = data['opponentType'] as String? ?? 'Employee';
        final colorStr = data['color'] as String?;
        
        Navigator.of(context).popUntil((route) => route.isFirst); // Dismiss dialogs
        _stopGameTimer();
        
        setState(() {
          _gameId = gameId;
          _opponentId = opponentId;
          _opponentType = opponentType;
          _playerColor = colorStr == 'white' ? ChessColor.white : ChessColor.black;
          _gameMode = 'employee_online';
          _timerOption = 'none'; // Force untimed for online games
          
          _engine.reset();
          _selectedSquare = null;
          _winner = null;
          _isDraw = false;
          _drawReason = '';
          _gameStarted = true;
          _boardFlipped = (_playerColor == ChessColor.black);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Game started! Good luck!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        break;

      case ChatEventType.chessChallengeDeclined:
        Navigator.of(context).popUntil((route) => route.isFirst); // Dismiss waiting dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Challenge was declined.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        break;

      case ChatEventType.chessMoveReceived:
        final moveData = data['move'];
        if (moveData != null) {
          final fromRow = moveData['fromRow'] as int?;
          final fromCol = moveData['fromCol'] as int?;
          final toRow = moveData['toRow'] as int?;
          final toCol = moveData['toCol'] as int?;
          final promotionStr = moveData['promotion'] as String?;
          
          if (fromRow != null && fromCol != null && toRow != null && toCol != null) {
            final from = Position(fromRow, fromCol);
            final to = Position(toRow, toCol);
            PieceType? promotion;
            if (promotionStr != null) {
              promotion = PieceType.values.firstWhere(
                (e) => e.name == promotionStr,
                orElse: () => PieceType.queen,
              );
            }
            
            final legalMoves = _engine.getLegalMoves();
            final matchingMove = legalMoves.firstWhere(
              (lm) => lm.from == from && lm.to == to && (promotion == null || lm.promotion == promotion),
              orElse: () => ChessMove(
                from: from,
                to: to,
                pieceMoved: _engine.getPieceAt(from)!,
                pieceCaptured: _engine.getPieceAt(to),
                promotion: promotion,
                prevCastlingRights: _engine.castlingRights,
                prevEnPassantSquare: _engine.enPassantSquare,
                prevHalfmoveClock: _engine.halfmoveClock,
              ),
            );
            
            setState(() {
              _engine.makeMove(matchingMove);
              _checkGameEnd();
            });
            _scrollToBottom();
          }
        }
        break;

      case ChatEventType.chessGameOverReceived:
        final reason = data['reason'] as String? ?? 'resigned';
        setState(() {
          _winner = _playerColor; // Opponent resigned or left, so we win!
          _drawReason = reason;
        });
        _showGameOverDialog('Opponent $reason. You win!');
        break;

      default:
        break;
    }
  }

  void _showChallengeRequestDialog(String? challengerId, String challengerType, String challengerName) {
    if (challengerId == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A).withOpacity(0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withOpacity(0.08),
            width: 1.5,
          ),
        ),
        title: Row(
          children: [
            const Icon(Icons.sports_esports_rounded, color: Color(0xFF3B82F6), size: 28),
            const SizedBox(width: 10),
            Text(
              'Chess Challenge!',
              style: GoogleFonts.lexend(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          '$challengerName has challenged you to a game of Chess. Do you accept?',
          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.8), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ChatWebSocketService.instance.declineChessChallenge(challengerId: challengerId);
            },
            child: Text(
              'Decline',
              style: GoogleFonts.lexend(color: const Color(0xFFEF4444)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ChatWebSocketService.instance.acceptChessChallenge(
                challengerId: challengerId,
                challengerType: challengerType,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Accept',
              style: GoogleFonts.lexend(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showWaitingForOpponentDialog(String opponentName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A).withOpacity(0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withOpacity(0.08),
            width: 1.5,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
            ),
            const SizedBox(height: 24),
            Text(
              'Challenging $opponentName...',
              style: GoogleFonts.lexend(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Waiting for them to accept the challenge',
              style: GoogleFonts.inter(color: Colors.white.withOpacity(0.5), fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.lexend(color: const Color(0xFFEF4444)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGameOverDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: Text('Game Over', style: GoogleFonts.lexend(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(message, style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetToSetup();
            },
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  void _startGame() {
    _engine.reset();
    _stopGameTimer();

    setState(() {
      _selectedSquare = null;
      _winner = null;
      _isDraw = false;
      _drawReason = '';
      _gameStarted = true;
      _boardFlipped = (_gameMode == 'computer' && _playerColor == ChessColor.black);

      // Initialize clock durations
      if (_timerOption == '10min') {
        _whiteTimeRemaining = const Duration(minutes: 10);
        _blackTimeRemaining = const Duration(minutes: 10);
      } else if (_timerOption == '30min') {
        _whiteTimeRemaining = const Duration(minutes: 30);
        _blackTimeRemaining = const Duration(minutes: 30);
      } else {
        _whiteTimeRemaining = Duration.zero;
        _blackTimeRemaining = Duration.zero;
      }
    });

    if (_timerOption != 'none') {
      _startGameTimer();
    }

    // If player is Black, Computer is White, trigger AI move immediately
    if (_gameMode == 'computer' && _playerColor == ChessColor.black) {
      _triggerAIMove();
    }
  }

  void _triggerAIMove() {
    setState(() {
      _aiThinking = true;
    });

    // Soft thinking delay to feel natural
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted || !_gameStarted || _winner != null || _isDraw) return;

      final bestMove = ChessAI.getBestMove(_engine, _difficulty);
      if (bestMove != null) {
        _engine.makeMove(bestMove);
        _checkGameEnd();
      }

      setState(() {
        _aiThinking = false;
      });

      _scrollToBottom();
    });
  }

  void _handlePlayerMove(ChessMove move) {
    if (_aiThinking || _winner != null || _isDraw) return;

    setState(() {
      _engine.makeMove(move);
      _checkGameEnd();
    });

    _scrollToBottom();

    if (_gameMode == 'employee_online' && _gameId != null && _opponentId != null && _opponentType != null) {
      ChatWebSocketService.instance.sendChessMove(
        gameId: _gameId!,
        opponentId: _opponentId!,
        opponentType: _opponentType!,
        move: {
          'fromRow': move.from.row,
          'fromCol': move.from.col,
          'toRow': move.to.row,
          'toCol': move.to.col,
          'promotion': move.promotion?.name,
        },
      );
      
      // If the move ended the game, send game over notification
      if (_winner != null || _isDraw) {
        String reason = 'completed';
        if (_winner != null) {
          reason = _winner == ChessColor.white ? 'white_win' : 'black_win';
        } else if (_isDraw) {
          reason = _drawReason.toLowerCase().replaceAll(' ', '_');
        }
        ChatWebSocketService.instance.sendChessGameOver(
          gameId: _gameId!,
          opponentId: _opponentId!,
          opponentType: _opponentType!,
          reason: reason,
        );
      }
    } else if (_gameMode == 'computer' && _winner == null && !_isDraw) {
      _triggerAIMove();
    }
  }

  void _checkGameEnd() {
    if (_engine.isCheckmate()) {
      // The player whose turn it WAS has lost (i.e. active color is mated)
      _winner = _engine.activeColor == ChessColor.white ? ChessColor.black : ChessColor.white;
      _stopGameTimer();
    } else if (_engine.isStalemate()) {
      _isDraw = true;
      _drawReason = 'Stalemate';
      _stopGameTimer();
    } else if (_engine.isFiftyMoveRule()) {
      _isDraw = true;
      _drawReason = '50-Move Rule';
      _stopGameTimer();
    } else if (_engine.isThreefoldRepetition()) {
      _isDraw = true;
      _drawReason = 'Threefold Repetition';
      _stopGameTimer();
    } else if (_engine.isInsufficientMaterial()) {
      _isDraw = true;
      _drawReason = 'Insufficient Material';
      _stopGameTimer();
    }
  }

  void _undoMove() {
    if (_aiThinking) return;

    setState(() {
      if (_gameMode == 'computer') {
        // Undo twice so it goes back to the player's turn
        if (_engine.moveHistory.length >= 2) {
          _engine.undoMove();
          _engine.undoMove();
        }
      } else {
        // Local 2-player: undo once
        if (_engine.moveHistory.isNotEmpty) {
          _engine.undoMove();
        }
      }
      _winner = null;
      _isDraw = false;
      _drawReason = '';
      _selectedSquare = null;
    });
  }

  void _resign() {
    _stopGameTimer();
    setState(() {
      _winner = _engine.activeColor == ChessColor.white ? ChessColor.black : ChessColor.white;
    });
    
    if (_gameMode == 'employee_online' && _gameId != null && _opponentId != null && _opponentType != null) {
      ChatWebSocketService.instance.sendChessGameOver(
        gameId: _gameId!,
        opponentId: _opponentId!,
        opponentType: _opponentType!,
        reason: 'resigned',
      );
    }
  }

  void _resetToSetup() {
    _stopGameTimer();
    setState(() {
      _gameStarted = false;
      _winner = null;
      _isDraw = false;
      _drawReason = '';
      _selectedSquare = null;
    });
  }

  void _scrollToBottom() {
    if (_moveHistoryScrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 50), () {
        _moveHistoryScrollController.animateTo(
          _moveHistoryScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  // Get captured pieces of a specific color
  List<ChessPiece> _getCapturedPieces(ChessColor color) {
    final initialCount = <PieceType, int>{
      PieceType.pawn: 8,
      PieceType.knight: 2,
      PieceType.bishop: 2,
      PieceType.rook: 2,
      PieceType.queen: 1,
      PieceType.king: 1,
    };

    final currentCount = <PieceType, int>{
      PieceType.pawn: 0,
      PieceType.knight: 0,
      PieceType.bishop: 0,
      PieceType.rook: 0,
      PieceType.queen: 0,
      PieceType.king: 0,
    };

    final board = _engine.board;
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = board[r][c];
        if (p != null && p.color == color) {
          currentCount[p.type] = (currentCount[p.type] ?? 0) + 1;
        }
      }
    }

    final captured = <ChessPiece>[];
    initialCount.forEach((type, count) {
      final diff = count - (currentCount[type] ?? 0);
      for (int i = 0; i < diff; i++) {
        captured.add(ChessPiece(color, type));
      }
    });

    final typeOrder = {
      PieceType.pawn: 1,
      PieceType.knight: 2,
      PieceType.bishop: 3,
      PieceType.rook: 4,
      PieceType.queen: 5,
      PieceType.king: 6,
    };
    captured.sort((a, b) => typeOrder[a.type]!.compareTo(typeOrder[b.type]!));

    return captured;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF020617)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _gameStarted ? _buildGameView(isMobile) : _buildSetupView(),
        ),
      ),
    );
  }

  // GAME SETUP VIEW
  Widget _buildSetupView() {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.04),
                Colors.white.withValues(alpha: 0.015),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.sports_esports_rounded,
                    color: Color(0xFF3B82F6),
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Sprintly Chess',
                    style: GoogleFonts.lexend(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Play chess with the computer or a colleague',
                style: GoogleFonts.lexend(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Game Mode Toggle
              Text(
                'GAME MODE',
                style: GoogleFonts.lexend(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildSelectButton(
                      label: 'VS Computer',
                      isSelected: _gameMode == 'computer',
                      onTap: () => setState(() => _gameMode = 'computer'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSelectButton(
                      label: 'VS Employee',
                      isSelected: _gameMode == 'employee',
                      onTap: () {
                        setState(() => _gameMode = 'employee');
                        context.read<TeamSyncViewModel>().loadChatUsers();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Time Limit Segment
              Text(
                'TIME LIMIT',
                style: GoogleFonts.lexend(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildSelectButton(
                      label: 'Untimed',
                      isSelected: _timerOption == 'none',
                      onTap: () => setState(() => _timerOption = 'none'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSelectButton(
                      label: '10 Mins',
                      isSelected: _timerOption == '10min',
                      onTap: () => setState(() => _timerOption = '10min'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSelectButton(
                      label: '30 Mins',
                      isSelected: _timerOption == '30min',
                      onTap: () => setState(() => _timerOption = '30min'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Vs Computer Setup Controls
              if (_gameMode == 'computer') ...[
                // Difficulty
                Text(
                  'DIFFICULTY',
                  style: GoogleFonts.lexend(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildSelectButton(
                        label: 'Easy',
                        isSelected: _difficulty == 'easy',
                        onTap: () => setState(() => _difficulty = 'easy'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSelectButton(
                        label: 'Medium',
                        isSelected: _difficulty == 'medium',
                        onTap: () => setState(() => _difficulty = 'medium'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSelectButton(
                        label: 'Hard',
                        isSelected: _difficulty == 'hard',
                        onTap: () => setState(() => _difficulty = 'hard'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Player Color selection
                Text(
                  'YOUR PIECE COLOR',
                  style: GoogleFonts.lexend(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildSelectButton(
                        label: 'White (Starts)',
                        isSelected: _playerColor == ChessColor.white,
                        onTap: () => setState(() => _playerColor = ChessColor.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSelectButton(
                        label: 'Black',
                        isSelected: _playerColor == ChessColor.black,
                        onTap: () => setState(() => _playerColor = ChessColor.black),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Play Button
                ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 8,
                    shadowColor: const Color(0xFF3B82F6).withOpacity(0.4),
                  ),
                  child: Text(
                    'START GAME',
                    style: GoogleFonts.lexend(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],

              // Vs Employee Online Matchmaking
              if (_gameMode == 'employee') ...[
                Text(
                  'ONLINE EMPLOYEES',
                  style: GoogleFonts.lexend(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Consumer<TeamSyncViewModel>(
                    builder: (context, teamSyncVM, child) {
                      final onlineEmployees = teamSyncVM.chatUsers
                          .where((u) => u.isOnline && u.id != teamSyncVM.currentUserId)
                          .toList();

                      if (onlineEmployees.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline_rounded, color: Colors.white.withOpacity(0.2), size: 36),
                                const SizedBox(height: 8),
                                Text(
                                  'No other employees online',
                                  style: GoogleFonts.lexend(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: onlineEmployees.length,
                        itemBuilder: (context, index) {
                          final emp = onlineEmployees[index];
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFF3B82F6).withOpacity(0.1),
                              backgroundImage: emp.image != null && emp.image!.isNotEmpty
                                  ? NetworkImage(emp.image!)
                                  : null,
                              child: emp.image == null || emp.image!.isEmpty
                                  ? Text(
                                      emp.name.substring(0, 1).toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontSize: 14),
                                    )
                                  : null,
                            ),
                            title: Text(
                              emp.name,
                              style: GoogleFonts.lexend(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              emp.designation ?? 'Team Member',
                              style: GoogleFonts.inter(color: Colors.white.withOpacity(0.4), fontSize: 11),
                            ),
                            trailing: ElevatedButton(
                              onPressed: () {
                                _showWaitingForOpponentDialog(emp.name);
                                final currentUserName = context.read<AuthViewModel>().currentUserProfile?.name ?? 'Colleague';
                                ChatWebSocketService.instance.sendChessChallenge(
                                  targetId: emp.id,
                                  challengerName: currentUserName,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3B82F6),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text(
                                'Challenge',
                                style: GoogleFonts.lexend(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        setState(() => _isSearchingEmployees = true);
                        await context.read<TeamSyncViewModel>().loadChatUsers();
                        setState(() => _isSearchingEmployees = false);
                      },
                      icon: _isSearchingEmployees
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 1.5, valueColor: AlwaysStoppedAnimation(Colors.white54)),
                            )
                          : const Icon(Icons.refresh_rounded, size: 16, color: Colors.white54),
                      label: Text(
                        'Refresh List',
                        style: GoogleFonts.lexend(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _startGame,
                      icon: const Icon(Icons.screen_rotation_rounded, size: 16, color: Colors.white54),
                      label: Text(
                        'Play Offline Locally',
                        style: GoogleFonts.lexend(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3B82F6).withOpacity(0.15)
              : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3B82F6)
                : Colors.white.withOpacity(0.05),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.lexend(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ACTIVE GAME VIEW
  Widget _buildGameView(bool isMobile) {
    // Current turn text
    String turnText;
    if (_winner != null) {
      turnText = _winner == ChessColor.white ? 'White Wins!' : 'Black Wins!';
    } else if (_isDraw) {
      turnText = 'Draw ($_drawReason)';
    } else if (_aiThinking) {
      turnText = 'Computer is thinking...';
    } else {
      if (_gameMode == 'computer') {
        final isPlayersTurn = _engine.activeColor == _playerColor;
        turnText = isPlayersTurn ? 'Your Turn' : 'Computer\'s Turn';
      } else if (_gameMode == 'employee_online') {
        final isPlayersTurn = _engine.activeColor == _playerColor;
        turnText = isPlayersTurn ? 'Your Turn' : 'Opponent\'s Turn';
      } else {
        turnText = _engine.activeColor == ChessColor.white ? 'White\'s Turn' : 'Black\'s Turn';
      }
    }

    final boardWidget = ChessBoardWidget(
      engine: _engine,
      isFlipped: _boardFlipped,
      isInteractive: !_aiThinking && _winner == null && !_isDraw &&
          (_gameMode == 'employee' || _engine.activeColor == _playerColor),
      selectedPosition: _selectedSquare,
      onSelectSquare: (pos) {
        setState(() {
          _selectedSquare = pos;
        });
      },
      onMove: _handlePlayerMove,
    );

    final controlPanel = _buildControlPanel(turnText, isMobile);

    if (isMobile) {
      return SingleChildScrollView(
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: boardWidget,
            ),
            const SizedBox(height: 16),
            controlPanel,
          ],
        ),
      );
    } else {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: boardWidget,
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 2,
            child: controlPanel,
          ),
        ],
      );
    }
  }

  Widget _buildControlPanel(String turnText, bool isMobile) {
    // Captured pieces of both colors
    final capturedWhite = _getCapturedPieces(ChessColor.white);
    final capturedBlack = _getCapturedPieces(ChessColor.black);

    // Calculate score difference
    final whiteVal = capturedBlack.fold(0, (sum, p) => sum + _getPieceValScore(p.type));
    final blackVal = capturedWhite.fold(0, (sum, p) => sum + _getPieceValScore(p.type));
    final scoreDiff = whiteVal - blackVal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.03),
            Colors.white.withValues(alpha: 0.01),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Turn and status banner
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: _winner != null
                  ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                  : _isDraw
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFF3B82F6).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _winner != null
                    ? const Color(0xFFEF4444)
                    : _isDraw
                        ? Colors.white.withValues(alpha: 0.1)
                        : const Color(0xFF3B82F6),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_aiThinking) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Text(
                  turnText.toUpperCase(),
                  style: GoogleFonts.lexend(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Chess Clock display (if timed)
          if (_timerOption != 'none') ...[
            _buildChessClock(),
            const SizedBox(height: 16),
          ],

          // Captured Pieces Displays
          _buildCapturedSection('Captured from White', capturedWhite, scoreDiff < 0 ? '+${-scoreDiff}' : ''),
          const SizedBox(height: 8),
          _buildCapturedSection('Captured from Black', capturedBlack, scoreDiff > 0 ? '+$scoreDiff' : ''),
          const SizedBox(height: 16),

          // Action Controls
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.undo_rounded,
                  label: 'Undo',
                  onTap: _gameMode != 'employee_online' && _engine.moveHistory.isNotEmpty && !_aiThinking ? _undoMove : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.flip_camera_android_rounded,
                  label: 'Flip',
                  onTap: () => setState(() => _boardFlipped = !_boardFlipped),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.flag_rounded,
                  label: 'Resign',
                  onTap: _winner == null && !_isDraw ? _resign : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Move History panel
          isMobile
              ? SizedBox(
                  height: 180,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.04),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'MOVE HISTORY',
                          style: GoogleFonts.lexend(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _buildMoveHistoryList(),
                        ),
                      ],
                    ),
                  ),
                )
              : Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.04),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'MOVE HISTORY',
                          style: GoogleFonts.lexend(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _buildMoveHistoryList(),
                        ),
                      ],
                    ),
                  ),
                ),
          const SizedBox(height: 16),

          // Return to Menu / New Game Button
          ElevatedButton(
            onPressed: _resetToSetup,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.05),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              elevation: 0,
            ),
            child: Text(
              'NEW GAME SETUP',
              style: GoogleFonts.lexend(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapturedSection(String title, List<ChessPiece> pieces, String scoreText) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.015),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                if (pieces.isEmpty)
                  Text(
                    'None',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  Wrap(
                    spacing: 2,
                    children: pieces.map((p) => Opacity(
                      opacity: p.color == ChessColor.white ? 1.0 : 0.6,
                      child: ChessPieceWidget(
                        piece: p,
                        size: 18,
                      ),
                    )).toList(),
                  ),
              ],
            ),
          ),
          if (scoreText.isNotEmpty)
            Text(
              scoreText,
              style: GoogleFonts.lexend(
                color: const Color(0xFF3B82F6),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: disabled ? Colors.white.withValues(alpha: 0.01) : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: disabled ? Colors.transparent : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: disabled ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.7),
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.lexend(
                color: disabled ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoveHistoryList() {
    final history = _engine.moveHistory;
    if (history.isEmpty) {
      return Center(
        child: Text(
          'No moves played yet',
          style: GoogleFonts.lexend(
            color: Colors.white.withValues(alpha: 0.2),
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    final doublePlies = <String>[];
    for (int i = 0; i < history.length; i += 2) {
      final wMove = history[i].toString();
      final bMove = (i + 1 < history.length) ? history[i + 1].toString() : '';
      doublePlies.add('${(i ~/ 2) + 1}. $wMove   $bMove');
    }

    return ListView.builder(
      controller: _moveHistoryScrollController,
      itemCount: doublePlies.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            doublePlies[index],
            style: GoogleFonts.lexend(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        );
      },
    );
  }

  int _getPieceValScore(PieceType type) {
    switch (type) {
      case PieceType.pawn: return 1;
      case PieceType.knight: return 3;
      case PieceType.bishop: return 3;
      case PieceType.rook: return 5;
      case PieceType.queen: return 9;
      case PieceType.king: return 0;
    }
  }

  Widget _buildChessClock() {
    return Row(
      children: [
        // White Player Timer
        Expanded(
          child: _buildPlayerClock(
            label: 'White',
            time: _whiteTimeRemaining,
            isActive: _engine.activeColor == ChessColor.white && _winner == null && !_isDraw && !_aiThinking,
            isWhite: true,
          ),
        ),
        const SizedBox(width: 12),
        // Black Player Timer
        Expanded(
          child: _buildPlayerClock(
            label: 'Black',
            time: _blackTimeRemaining,
            isActive: _engine.activeColor == ChessColor.black && _winner == null && !_isDraw,
            isWhite: false,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerClock({
    required String label,
    required Duration time,
    required bool isActive,
    required bool isWhite,
  }) {
    final minutes = time.inMinutes.toString().padLeft(2, '0');
    final seconds = (time.inSeconds % 60).toString().padLeft(2, '0');
    final lowTime = time.inSeconds < 30; // red pulsing if less than 30s

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: isActive
            ? (lowTime
                ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                : const Color(0xFF3B82F6).withValues(alpha: 0.15))
            : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? (lowTime ? const Color(0xFFEF4444) : const Color(0xFF3B82F6))
              : Colors.white.withValues(alpha: 0.05),
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: (lowTime ? const Color(0xFFEF4444) : const Color(0xFF3B82F6))
                      .withValues(alpha: 0.1),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 14,
                color: isActive
                    ? (lowTime ? const Color(0xFFEF4444) : const Color(0xFF3B82F6))
                    : Colors.white.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 4),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.lexend(
                  color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$minutes:$seconds',
            style: GoogleFonts.shareTechMono(
              color: isActive
                  ? (lowTime ? const Color(0xFFEF4444) : Colors.white)
                  : Colors.white.withValues(alpha: 0.6),
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
