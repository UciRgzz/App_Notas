class AudioNote {
  final String path;
  final DateTime date;
  String title;
  final Duration duration;

  AudioNote({
    required this.path,
    required this.date,
    required this.title,
    required this.duration,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'date': date.toIso8601String(),
        'title': title,
        'durationMs': duration.inMilliseconds,
      };

  factory AudioNote.fromJson(Map<String, dynamic> json) => AudioNote(
        path: json['path'] as String,
        date: DateTime.parse(json['date'] as String),
        title: json['title'] as String,
        duration: Duration(milliseconds: json['durationMs'] as int),
      );
}
