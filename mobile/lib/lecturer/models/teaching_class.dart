import 'lecturer_data.dart';

class TeachingClass {
  final String id, code, courseId, course, courseCode;
  final List<TeachingSession> sessions;
  TeachingClass({
    required this.id,
    required this.code,
    required this.courseId,
    required this.course,
    required this.courseCode,
    required List<TeachingSession> sessions,
  }) : sessions = List.unmodifiable(
         [...sessions]..sort((a, b) => a.start.compareTo(b.start)),
       );

  int get recorded => sessions.where((s) => s.attendanceSaved).length;
  int get pending => sessions
      .where((s) => !s.attendanceSaved && !s.start.isAfter(DateTime.now()))
      .length;
  int get future => sessions
      .where((s) => !s.attendanceSaved && s.start.isAfter(DateTime.now()))
      .length;
  TeachingClass withSessions(List<TeachingSession> rows) => TeachingClass(
    id: id,
    code: code,
    courseId: courseId,
    course: course,
    courseCode: courseCode,
    sessions: rows,
  );

  static List<TeachingClass> group(List<TeachingSession> rows) {
    final groups = <String, List<TeachingSession>>{};
    for (final row in rows) {
      groups.putIfAbsent(row.sectionId, () => []).add(row);
    }
    final result = [
      for (final entry in groups.entries)
        TeachingClass(
          id: entry.key,
          code: entry.value.first.section,
          courseId: entry.value.first.courseId,
          course: entry.value.first.course,
          courseCode: entry.value.first.courseCode,
          sessions: entry.value,
        ),
    ];
    result.sort((a, b) {
      final compared = a.courseCode.compareTo(b.courseCode);
      return compared != 0 ? compared : a.code.compareTo(b.code);
    });
    return result;
  }
}
