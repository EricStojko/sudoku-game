import 'dart:math';
import '../models/difficulty.dart';

/// Generates valid Sudoku boards by shuffling a known-valid base grid.
class SudokuGenerator {
  SudokuGenerator._(); // static-only class

  static List<List<int>> generateCompleted() {
    // Valid base matrix — all rows, columns, and 3×3 boxes are correct.
    List<List<int>> grid = [
      [1, 2, 3, 4, 5, 6, 7, 8, 9],
      [4, 5, 6, 7, 8, 9, 1, 2, 3],
      [7, 8, 9, 1, 2, 3, 4, 5, 6],
      [2, 3, 1, 5, 6, 4, 8, 9, 7],
      [5, 6, 4, 8, 9, 7, 2, 3, 1],
      [8, 9, 7, 2, 3, 1, 5, 6, 4],
      [3, 1, 2, 6, 4, 5, 9, 7, 8],
      [6, 4, 5, 9, 7, 8, 3, 1, 2],
      [9, 7, 8, 3, 1, 2, 6, 4, 5],
    ];

    final rand = Random();

    // 1. Shuffle digit mappings (relabel 1–9 randomly).
    final digits = [1, 2, 3, 4, 5, 6, 7, 8, 9]..shuffle(rand);
    List<List<int>> newGrid = List.generate(9, (_) => List.filled(9, 0));
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        newGrid[r][c] = digits[grid[r][c] - 1];
      }
    }
    grid = newGrid;

    // 2. Shuffle rows within each 3×3 row-band.
    for (int i = 0; i < 3; i++) {
      int r1 = i * 3 + rand.nextInt(3);
      int r2 = i * 3 + rand.nextInt(3);
      final temp = grid[r1];
      grid[r1] = grid[r2];
      grid[r2] = temp;
    }

    // 3. Shuffle columns within each 3×3 column-band.
    for (int i = 0; i < 3; i++) {
      int c1 = i * 3 + rand.nextInt(3);
      int c2 = i * 3 + rand.nextInt(3);
      for (int r = 0; r < 9; r++) {
        final temp = grid[r][c1];
        grid[r][c1] = grid[r][c2];
        grid[r][c2] = temp;
      }
    }

    // 4. Shuffle whole 3×3 row-bands.
    final br1 = rand.nextInt(3);
    final br2 = rand.nextInt(3);
    if (br1 != br2) {
      for (int i = 0; i < 3; i++) {
        final temp = grid[br1 * 3 + i];
        grid[br1 * 3 + i] = grid[br2 * 3 + i];
        grid[br2 * 3 + i] = temp;
      }
    }

    // 5. Shuffle whole 3×3 column-bands.
    final bc1 = rand.nextInt(3);
    final bc2 = rand.nextInt(3);
    if (bc1 != bc2) {
      for (int i = 0; i < 3; i++) {
        for (int r = 0; r < 9; r++) {
          final temp = grid[r][bc1 * 3 + i];
          grid[r][bc1 * 3 + i] = grid[r][bc2 * 3 + i];
          grid[r][bc2 * 3 + i] = temp;
        }
      }
    }

    return grid;
  }

  static List<List<int>> generatePuzzle(
    List<List<int>> solvedGrid,
    Difficulty difficulty,
  ) {
    final puzzle = solvedGrid.map((row) => List<int>.from(row)).toList();
    final rand = Random();

    final int targetHoles = switch (difficulty) {
      Difficulty.easy => 35,
      Difficulty.medium => 45,
      Difficulty.hard => 55,
    };

    final positions = List.generate(81, (i) => i)..shuffle(rand);

    int holes = 0;
    for (int pos in positions) {
      if (holes >= targetHoles) break;

      int r = pos ~/ 9;
      int c = pos % 9;

      if (puzzle[r][c] != 0) {
        int backup = puzzle[r][c];
        puzzle[r][c] = 0;

        // Check if removing this cell leaves exactly one solution
        if (_countSolutions(puzzle) == 1) {
          holes++;
        } else {
          // If multiple solutions exist, we must keep this clue
          puzzle[r][c] = backup;
        }
      }
    }
    return puzzle;
  }

  /// Backtracking solver to count how many solutions exist for the grid.
  /// Used to ensure the generated puzzle has exactly 1 unique solution.
  static int _countSolutions(List<List<int>> grid) {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (grid[r][c] == 0) {
          int count = 0;
          for (int n = 1; n <= 9; n++) {
            if (_isValid(grid, r, c, n)) {
              grid[r][c] = n;
              count += _countSolutions(grid);
              grid[r][c] = 0;
              // Optimization: if we find more than 1 solution, stop searching
              if (count > 1) return count;
            }
          }
          return count;
        }
      }
    }
    // Base case: board is full, one solution found
    return 1;
  }

  static bool _isValid(List<List<int>> grid, int r, int c, int n) {
    for (int i = 0; i < 9; i++) {
      if (grid[r][i] == n) return false;
      if (grid[i][c] == n) return false;
    }
    int br = (r ~/ 3) * 3;
    int bc = (c ~/ 3) * 3;
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if (grid[br + i][bc + j] == n) return false;
      }
    }
    return true;
  }

  /// Entry point for running generation on a background Isolate.
  static SudokuBoardData generate(Difficulty difficulty) {
    final solved = generateCompleted();
    final puzzle = generatePuzzle(solved, difficulty);
    return SudokuBoardData(solved: solved, puzzle: puzzle);
  }
}

class SudokuBoardData {
  final List<List<int>> solved;
  final List<List<int>> puzzle;
  const SudokuBoardData({required this.solved, required this.puzzle});
}

/// Top-level task for compute Isolate execution
SudokuBoardData generateSudokuIsolateTask(Difficulty difficulty) {
  return SudokuGenerator.generate(difficulty);
}
