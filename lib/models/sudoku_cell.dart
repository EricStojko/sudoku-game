class SudokuCell {
  final int correctValue;
  int currentValue;
  final bool isFixed;
  bool isErrorHighlight;

  /// Tracks whether a mistake has already been counted for the current wrong
  /// value in this cell. Prevents double-counting when the user erases and
  /// re-enters a wrong number without a correct attempt in between.
  bool hasMistake;

  SudokuCell({
    required this.correctValue,
    required this.currentValue,
    required this.isFixed,
    this.isErrorHighlight = false,
    this.hasMistake = false,
  });

  Map<String, dynamic> toJson() => {
        'correctValue': correctValue,
        'currentValue': currentValue,
        'isFixed': isFixed,
        'isErrorHighlight': isErrorHighlight,
        'hasMistake': hasMistake,
      };

  factory SudokuCell.fromJson(Map<String, dynamic> json) {
    return SudokuCell(
      correctValue: json['correctValue'] as int,
      currentValue: json['currentValue'] as int,
      isFixed: json['isFixed'] as bool,
      isErrorHighlight: json['isErrorHighlight'] as bool? ?? false,
      hasMistake: json['hasMistake'] as bool? ?? false,
    );
  }
}
