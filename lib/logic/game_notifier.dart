import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/difficulty.dart';
import '../models/move.dart';
import '../models/sudoku_cell.dart';
import '../logic/sudoku_generator.dart';

/// Signals whether the game is idle, in progress, won, or lost.
enum GameStatus { idle, playing, won, gameOver }

/// Holds all mutable game state and exposes clean methods for game logic.
///
/// This is a [ChangeNotifier] — the UI listens to it via [ListenableBuilder]
/// and rebuilds only when [notifyListeners] is called.
class GameNotifier extends ChangeNotifier with WidgetsBindingObserver {
  GameNotifier() {
    WidgetsBinding.instance.addObserver(this);
    // Initialize with a blank dummy grid to prevent LateInitializationErrors during async generation
    grid = List.generate(
      9,
      (r) => List.generate(
        9,
        (c) => SudokuCell(correctValue: 0, currentValue: 0, isFixed: false),
      ),
    );
  }

  void initGame() {
    startNewGame(Difficulty.easy);
    _loadGame();
  }
  // -------------------------------------------------------------------------
  // State
  // -------------------------------------------------------------------------

  Difficulty difficulty = Difficulty.easy;
  late List<List<SudokuCell>> grid;
  bool isGenerating = false;
  int selectedRow = -1;
  int selectedCol = -1;
  int mistakes = 0;
  final ValueNotifier<int> secondsElapsed = ValueNotifier<int>(0);
  int hintsUsed = 0;
  GameStatus status = GameStatus.idle;
  bool showConfetti = false;
  bool isLeaderboardEligible = true;
  bool isUserPaused = false;

  final List<Move> _history = [];

  Timer? _timer;
  Timer? _confettiTimer;

  bool get isPlaying => status == GameStatus.playing && !isUserPaused;
  bool get canUndo => _history.isNotEmpty;
  bool get canUseHint => hintsUsed < 5 && !isUserPaused;

  // -------------------------------------------------------------------------
  // Game lifecycle
  // -------------------------------------------------------------------------

  void startNewGame(Difficulty diff) async {
    _timer?.cancel();
    _confettiTimer?.cancel();
    _checkTimer?.cancel();

    difficulty = diff;
    mistakes = 0;
    selectedRow = -1;
    selectedCol = -1;
    secondsElapsed.value = 0;
    hintsUsed = 0;
    status = GameStatus.idle;
    showConfetti = false;
    isLeaderboardEligible = true;
    isUserPaused = false;
    _history.clear();

    isGenerating = true;
    notifyListeners();

    try {
      final boardData = await compute(generateSudokuIsolateTask, diff);
      grid = List.generate(
        9,
        (r) => List.generate(
          9,
          (c) => SudokuCell(
            correctValue: boardData.solved[r][c],
            currentValue: boardData.puzzle[r][c],
            isFixed: boardData.puzzle[r][c] != 0,
          ),
        ),
      );
    } catch (_) {
      // Fallback if Isolate/compute fails (e.g., in unit tests or older web runtimes)
      final solved = SudokuGenerator.generateCompleted();
      final puzzle = SudokuGenerator.generatePuzzle(solved, diff);
      grid = List.generate(
        9,
        (r) => List.generate(
          9,
          (c) => SudokuCell(
            correctValue: solved[r][c],
            currentValue: puzzle[r][c],
            isFixed: puzzle[r][c] != 0,
          ),
        ),
      );
    } finally {
      isGenerating = false;
    }

    notifyListeners();
  }

  void startGame() {
    if (status != GameStatus.idle) return;
    status = GameStatus.playing;
    _startTimer();
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Selection
  // -------------------------------------------------------------------------

  void selectCell(int r, int c) {
    selectedRow = r;
    selectedCol = c;
    notifyListeners();
  }

  /// Moves the selection by [dr] rows and [dc] columns.
  /// If nothing is selected yet, starts at (0, 0).
  void moveSelection(int dr, int dc) {
    selectedRow = (selectedRow == -1 ? 0 : selectedRow + dr).clamp(0, 8);
    selectedCol = (selectedCol == -1 ? 0 : selectedCol + dc).clamp(0, 8);
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Input
  // -------------------------------------------------------------------------

  /// Inputs [num] into the selected cell. Use 0 to erase.
  void inputNumber(int num) {
    if (!isPlaying || selectedRow == -1 || selectedCol == -1) return;
    final cell = grid[selectedRow][selectedCol];
    if (cell.isFixed) return;

    // Record state for undo before making any changes
    _history.add(Move(
      row: selectedRow,
      col: selectedCol,
      previousValue: cell.currentValue,
      previousHasMistake: cell.hasMistake,
    ));

    if (num == 0) {
      // Erase — clear the penalty flag so the next entry is a fresh attempt.
      cell.currentValue = 0;
      cell.hasMistake = false;
    } else if (num == cell.correctValue) {
      // Correct value entered.
      cell.currentValue = num;
      cell.hasMistake = false;
    } else {
      // Wrong value — only penalise once per uncleared mistake (no double-count).
      if (!cell.hasMistake) {
        mistakes++;
        cell.hasMistake = true;
      }
      cell.currentValue = num;
    }

    if (mistakes >= 3) {
      _timer?.cancel();
      status = GameStatus.gameOver;
      _saveGame(); // Clears the save
    } else {
      _checkWinCondition();
    }

    notifyListeners();
  }

  /// Fills the selected cell with its correct value. Max 5 hints.
  void useHint() {
    if (!isPlaying || selectedRow == -1 || selectedCol == -1 || hintsUsed >= 5) return;
    final cell = grid[selectedRow][selectedCol];
    if (cell.isFixed || cell.currentValue == cell.correctValue) return;

    // Hints are undoable, but the disqualification remains!
    _history.add(Move(
      row: selectedRow,
      col: selectedCol,
      previousValue: cell.currentValue,
      previousHasMistake: cell.hasMistake,
    ));

    isLeaderboardEligible = false;
    hintsUsed++;
    cell.currentValue = cell.correctValue;
    cell.hasMistake = false;
    _checkWinCondition();
    notifyListeners();
  }

  void togglePause() {
    if (status != GameStatus.playing) return;
    isUserPaused = !isUserPaused;
    if (isUserPaused) {
      _timer?.cancel();
    } else {
      _startTimer();
    }
    notifyListeners();
  }

  bool isNumberExhausted(int num) {
    if (status != GameStatus.playing) return false;
    int count = 0;
    for (final row in grid) {
      for (final cell in row) {
        if (cell.currentValue == num && cell.currentValue == cell.correctValue) {
          count++;
        }
      }
    }
    return count == 9;
  }

  /// Reverts the most recent move.
  void undo() {
    if (!isPlaying || _history.isEmpty) return;

    final lastMove = _history.removeLast();
    final cell = grid[lastMove.row][lastMove.col];

    cell.currentValue = lastMove.previousValue;
    cell.hasMistake = lastMove.previousHasMistake;

    // Move selection back to the undone cell for convenience
    selectedRow = lastMove.row;
    selectedCol = lastMove.col;

    notifyListeners();
  }

  Timer? _checkTimer;

  /// Highlights all incorrect non-empty cells for 2 seconds.
  void useCheck() {
    if (!isPlaying) return;
    _checkTimer?.cancel();
    for (final row in grid) {
      for (final cell in row) {
        if (!cell.isFixed &&
            cell.currentValue != 0 &&
            cell.currentValue != cell.correctValue) {
          cell.isErrorHighlight = true;
        }
      }
    }
    notifyListeners();

    _checkTimer = Timer(const Duration(seconds: 2), () {
      for (final row in grid) {
        for (final cell in row) {
          cell.isErrorHighlight = false;
        }
      }
      notifyListeners();
    });
  }

  // -------------------------------------------------------------------------
  // Win celebration
  // -------------------------------------------------------------------------

  /// Triggers the confetti overlay for 4 seconds.
  /// Called by the screen after it has handled the [GameStatus.won] event.
  void triggerConfetti() {
    _confettiTimer?.cancel();
    showConfetti = true;
    notifyListeners();
    _confettiTimer = Timer(const Duration(seconds: 4), () {
      showConfetti = false;
      notifyListeners();
    });
  }

  // -------------------------------------------------------------------------
  // Utilities
  // -------------------------------------------------------------------------

  /// Formats [seconds] as MM:SS.
  static String formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (isPlaying) {
        secondsElapsed.value++;
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _timer?.cancel();
      _saveGame();
    } else if (state == AppLifecycleState.resumed) {
      if (isPlaying) {
        _startTimer();
      }
    }
  }

  Future<void> _saveGame() async {
    final prefs = await SharedPreferences.getInstance();
    if (status != GameStatus.playing) {
      await prefs.remove('saved_game');
      return;
    }
    
    final data = {
      'difficulty': difficulty.name,
      'mistakes': mistakes,
      'secondsElapsed': secondsElapsed.value,
      'hintsUsed': hintsUsed,
      'isLeaderboardEligible': isLeaderboardEligible,
      'grid': grid.map((row) => row.map((c) => c.toJson()).toList()).toList(),
    };
    await prefs.setString('saved_game', jsonEncode(data));
  }

  Future<void> _loadGame() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('saved_game');
    if (saved != null) {
      try {
        final data = jsonDecode(saved);
        difficulty = Difficulty.values.firstWhere((d) => d.name == data['difficulty']);
        mistakes = data['mistakes'];
        secondsElapsed.value = data['secondsElapsed'];
        hintsUsed = data['hintsUsed'] ?? 0;
        isLeaderboardEligible = data['isLeaderboardEligible'] ?? true;
        _history.clear(); // Transient history resets on load
        
        final List dynamicGrid = data['grid'];
        grid = dynamicGrid.map((row) => (row as List).map((c) => SudokuCell.fromJson(c)).toList()).toList();
        
        status = GameStatus.playing;
        showConfetti = false;
        selectedRow = -1;
        selectedCol = -1;
        
        _startTimer();
        notifyListeners();
      } catch (e) {
        // If save is corrupted, the default game we started in initGame() remains.
        await prefs.remove('saved_game');
      }
    }
  }

  void _checkWinCondition() {
    for (final row in grid) {
      for (final cell in row) {
        if (cell.currentValue != cell.correctValue) return;
      }
    }
    _timer?.cancel();
    status = GameStatus.won;
    _saveGame(); // Clears the save because status != playing
  }

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _confettiTimer?.cancel();
    _checkTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
