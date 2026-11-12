import 'teaching_class.dart';

class TeachingCourse {
  final String id, code, name;
  final List<TeachingClass> classes;
  TeachingCourse({
    required this.id,
    required this.code,
    required this.name,
    required List<TeachingClass> classes,
  }) : classes = List.unmodifiable(
         [...classes]..sort((a, b) => a.code.compareTo(b.code)),
       );
  String get title => [code, name].where((s) => s.isNotEmpty).join(' · ');
  int get sessions =>
      classes.fold(0, (total, section) => total + section.sessions.length);
  int get recorded =>
      classes.fold(0, (total, section) => total + section.recorded);
  static List<TeachingCourse> group(List<TeachingClass> sections) {
    final groups = <String, List<TeachingClass>>{};
    // Dùng ID môn làm khóa để nhiều lớp của cùng môn chỉ hiện một thẻ môn.
    for (final section in sections) {
      groups.putIfAbsent(section.courseId, () => []).add(section);
    }
    final result = [
      for (final entry in groups.entries)
        TeachingCourse(
          id: entry.key,
          code: entry.value.first.courseCode,
          name: entry.value.first.course,
          classes: entry.value,
        ),
    ];
    result.sort((a, b) => a.title.compareTo(b.title));
    return result;
  }
}
