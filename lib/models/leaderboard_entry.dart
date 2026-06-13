class LeaderboardEntry {
  final String name;
  final int timeInSeconds;
  final String date;

  LeaderboardEntry(this.name, this.timeInSeconds, this.date);

  Map<String, dynamic> toJson() => {
        'name': name,
        'time': timeInSeconds,
        'date': date,
      };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(json['name'], json['time'], json['date']);
  }
}
