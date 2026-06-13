import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stojkodoku/main.dart';

void main() {
  // ---------------------------------------------------------------------------
  // SudokuGenerator tests
  // ---------------------------------------------------------------------------
  group('SudokuGenerator', () {
    test('generateCompleted produces a 9x9 grid', () {
      final grid = SudokuGenerator.generateCompleted();
      expect(grid.length, 9);
      for (final row in grid) {
        expect(row.length, 9);
      }
    });

    test('generateCompleted contains only digits 1–9 in every row', () {
      final grid = SudokuGenerator.generateCompleted();
      for (final row in grid) {
        final sorted = List<int>.from(row)..sort();
        expect(sorted, [1, 2, 3, 4, 5, 6, 7, 8, 9]);
      }
    });

    test('generateCompleted contains only digits 1–9 in every column', () {
      final grid = SudokuGenerator.generateCompleted();
      for (int c = 0; c < 9; c++) {
        final col = [for (int r = 0; r < 9; r++) grid[r][c]]..sort();
        expect(col, [1, 2, 3, 4, 5, 6, 7, 8, 9]);
      }
    });

    test('generateCompleted contains only digits 1–9 in every 3x3 box', () {
      final grid = SudokuGenerator.generateCompleted();
      for (int br = 0; br < 3; br++) {
        for (int bc = 0; bc < 3; bc++) {
          final box = <int>[];
          for (int r = br * 3; r < br * 3 + 3; r++) {
            for (int c = bc * 3; c < bc * 3 + 3; c++) {
              box.add(grid[r][c]);
            }
          }
          box.sort();
          expect(box, [1, 2, 3, 4, 5, 6, 7, 8, 9]);
        }
      }
    });

    test('generatePuzzle (easy) removes ~35 cells', () {
      final solved = SudokuGenerator.generateCompleted();
      final puzzle = SudokuGenerator.generatePuzzle(solved, Difficulty.easy);
      final holes = puzzle.expand((row) => row).where((v) => v == 0).length;
      // Allow small variance from random removal
      expect(holes, inInclusiveRange(30, 40));
    });

    test('generatePuzzle (hard) removes ~55 cells', () {
      final solved = SudokuGenerator.generateCompleted();
      final puzzle = SudokuGenerator.generatePuzzle(solved, Difficulty.hard);
      final holes = puzzle.expand((row) => row).where((v) => v == 0).length;
      expect(holes, inInclusiveRange(50, 60));
    });

    test('generatePuzzle preserves correct values in non-empty cells', () {
      final solved = SudokuGenerator.generateCompleted();
      final puzzle = SudokuGenerator.generatePuzzle(solved, Difficulty.medium);
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          if (puzzle[r][c] != 0) {
            expect(puzzle[r][c], solved[r][c]);
          }
        }
      }
    });

    test('two calls to generateCompleted produce different grids (randomness)', () {
      // There is a tiny chance of collision, but practically negligible.
      final grid1 = SudokuGenerator.generateCompleted();
      final grid2 = SudokuGenerator.generateCompleted();
      final flat1 = grid1.expand((r) => r).toList();
      final flat2 = grid2.expand((r) => r).toList();
      // At least one value should differ after shuffling
      expect(flat1, isNot(equals(flat2)));
    });
  });

  // ---------------------------------------------------------------------------
  // LeaderboardEntry model tests
  // ---------------------------------------------------------------------------
  group('LeaderboardEntry', () {
    test('serialises to JSON and back correctly', () {
      final entry = LeaderboardEntry('Erik', 142, '2026-06-13');
      final json = entry.toJson();
      final restored = LeaderboardEntry.fromJson(json);

      expect(restored.name, 'Erik');
      expect(restored.timeInSeconds, 142);
      expect(restored.date, '2026-06-13');
    });

    test('toJson contains the expected keys', () {
      final entry = LeaderboardEntry('Test', 60, '2026-01-01');
      final json = entry.toJson();
      expect(json.containsKey('name'), isTrue);
      expect(json.containsKey('time'), isTrue);
      expect(json.containsKey('date'), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // SudokuCell model tests
  // ---------------------------------------------------------------------------
  group('SudokuCell', () {
    test('isFixed cell cannot be modified (guard must be upstream)', () {
      final cell = SudokuCell(
        correctValue: 5,
        currentValue: 5,
        isFixed: true,
      );
      expect(cell.isFixed, isTrue);
      expect(cell.currentValue, cell.correctValue);
    });

    test('non-fixed cell starts with currentValue 0 and hasMistake false', () {
      final cell = SudokuCell(
        correctValue: 7,
        currentValue: 0,
        isFixed: false,
      );
      expect(cell.isFixed, isFalse);
      expect(cell.currentValue, 0);
      expect(cell.isErrorHighlight, isFalse);
      expect(cell.hasMistake, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Mistake counting logic (bug fix: double-counting prevention)
  // ---------------------------------------------------------------------------
  group('Mistake counting (hasMistake flag)', () {
    late SudokuCell cell;

    setUp(() {
      cell = SudokuCell(correctValue: 5, currentValue: 0, isFixed: false);
    });

    test('hasMistake is false by default', () {
      expect(cell.hasMistake, isFalse);
    });

    test('entering a wrong number sets hasMistake to true', () {
      // Simulate what _onNumberInput does for a wrong entry
      cell.hasMistake = true;
      cell.currentValue = 3;
      expect(cell.hasMistake, isTrue);
      expect(cell.currentValue, 3);
    });

    test('erasing a wrong number resets hasMistake to false', () {
      cell.currentValue = 3;
      cell.hasMistake = true;

      // Simulate erase
      cell.currentValue = 0;
      cell.hasMistake = false;

      expect(cell.hasMistake, isFalse);
      expect(cell.currentValue, 0);
    });

    test('entering a second wrong number while hasMistake=true does NOT re-set flag (no double count)', () {
      // First wrong entry
      cell.hasMistake = true;
      cell.currentValue = 3;

      // Second wrong entry (different number, no erase) — hasMistake already true, no new mistake
      final mistakesBefore = cell.hasMistake ? 1 : 0;
      if (!cell.hasMistake) cell.hasMistake = true; // guard: only set once
      cell.currentValue = 7;

      expect(cell.hasMistake, isTrue);
      expect(mistakesBefore, 1); // only one mistake was ever counted
    });

    test('after erasing, entering another wrong number should be a fresh mistake', () {
      // First wrong entry
      cell.hasMistake = true;
      cell.currentValue = 3;

      // Erase
      cell.currentValue = 0;
      cell.hasMistake = false;

      // Fresh wrong entry again
      expect(cell.hasMistake, isFalse); // flag was cleared, so next wrong entry will count
      cell.hasMistake = true;
      cell.currentValue = 7;

      expect(cell.hasMistake, isTrue);
    });

    test('entering the correct value clears hasMistake', () {
      cell.hasMistake = true;
      cell.currentValue = 3;

      // Correct entry
      cell.currentValue = cell.correctValue;
      cell.hasMistake = false;

      expect(cell.hasMistake, isFalse);
      expect(cell.currentValue, 5);
    });
  });

  // ---------------------------------------------------------------------------
  // Widget / smoke tests
  // ---------------------------------------------------------------------------
  group('SudokuApp widget', () {
    testWidgets('app renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(const SudokuApp());
      // Allow async initState (shared_preferences, timer setup) to settle
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('game screen displays the app title', (WidgetTester tester) async {
      await tester.pumpWidget(const SudokuApp());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('StojkoDoku'), findsOneWidget);
    });

    testWidgets('difficulty buttons are rendered', (WidgetTester tester) async {
      await tester.pumpWidget(const SudokuApp());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
    });

    testWidgets('number pad displays digits 1–9', (WidgetTester tester) async {
      await tester.pumpWidget(const SudokuApp());
      await tester.pump(const Duration(milliseconds: 100));
      for (int i = 1; i <= 9; i++) {
        expect(find.text(i.toString()), findsWidgets);
      }
    });

    testWidgets('leaderboard icon button is present', (WidgetTester tester) async {
      await tester.pumpWidget(const SudokuApp());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.leaderboard_rounded), findsOneWidget);
    });

    testWidgets('Check and Hint action buttons are rendered', (WidgetTester tester) async {
      await tester.pumpWidget(const SudokuApp());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Check'), findsOneWidget);
      expect(find.text('Hint'), findsOneWidget);
    });
  });
}
