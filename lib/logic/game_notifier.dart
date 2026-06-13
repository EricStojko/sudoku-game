import 'dart:async';
import 'package:flutter/material.dart';
import '../models/difficulty.dart';
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
  }
  // -------------------------------------------------------------------------
  // State
  // -------------------------------------------------------------------------

  Difficulty difficulty = Difficulty.easy;
  late List<List<SudokuCell>> grid;
  int selectedRow = -1;
  int selectedCol = -1;
  int mistakes = 0;
  int secondsElapsed = 0;
  GameStatus status = GameStatus.idle;
  bool showConfetti = false;

  Timer? _timer;
  Timer? _confettiTimer;

  bool get isPlaying => status == GameStatus.playing;

  // -------------------------------------------------------------------------
  // Game lifecycle
  // -------------------------------------------------------------------------

  /// Starts a fresh game with [diff] difficulty. Cancels any running timer.
  void startNewGame(Difficulty diff) {
    _timer?.cancel();
    _confettiTimer?.cancel();

    difficulty = diff;
    mistakes = 0;
    selectedRow = -1;
    selectedCol = -1;
    secondsElapsed = 0;
    status = GameStatus.playing;
    showConfetti = false;

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
    } else {
      _checkWinCondition();
    }

    notifyListeners();
  }

  /// Fills the selected cell with its correct value.
  void useHint() {
    if (!isPlaying || selectedRow == -1 || selectedCol == -1) return;
    final cell = grid[selectedRow][selectedCol];
    if (cell.isFixed || cell.currentValue == cell.correctValue) return;

    cell.currentValue = cell.correctValue;
    cell.hasMistake = false;
    _checkWinCondition();
    notifyListeners();
  }

  /// Highlights all incorrect non-empty cells for 2 seconds.
  void useCheck() {
    if (!isPlaying) return;
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

    Future.delayed(const Duration(seconds: 2), () {
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
        secondsElapsed++;
        notifyListeners();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _timer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      if (isPlaying) {
        _startTimer();
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _confettiTimer?.cancel();
    super.dispose();
  }
}
