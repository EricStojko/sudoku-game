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

    final int holes = switch (difficulty) {
      Difficulty.easy => 35,
      Difficulty.medium => 45,
      Difficulty.hard => 55,
    };

    int count = 0;
    while (count < holes) {
      final r = rand.nextInt(9);
      final c = rand.nextInt(9);
      if (puzzle[r][c] != 0) {
        puzzle[r][c] = 0;
        count++;
      }
    }
    return puzzle;
  }
}
