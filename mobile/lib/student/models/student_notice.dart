class StudentNotice {
  const StudentNotice({
    required this.id,
    required this.title,
    required this.content,
    required this.audience,
    required this.publishedAt,
    required this.expiresAt,
  });

  final String id;
  final String title;
  final String content;
  final String audience;
  final DateTime? publishedAt;
  final DateTime? expiresAt;

  factory StudentNotice.fromJson(Map<String, dynamic> json) => StudentNotice(
    id: json['id'] as String,
    title: json['title']?.toString() ?? 'Thông báo học vụ',
    content: json['content']?.toString() ?? '',
    audience: json['audience']?.toString() ?? 'ALL_STUDENTS',
    publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? '')
        ?.toUtc(),
    expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? '')?.toUtc(),
  );
}
