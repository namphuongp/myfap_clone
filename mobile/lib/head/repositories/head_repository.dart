import '../../core/academic/academic_repository.dart';
export '../../core/academic/academic_repository.dart' show Json;

class HeadRepository extends AcademicRepository {
  HeadRepository(super.api);
  Future<Json> options() async => Map<String, dynamic>.from(
    await api.request('GET', '/head/options') as Map,
  );
  Future<Json> list(
    String kind, {
    String search = '',
    String? semester,
    String? course,
    int page = 1,
  }) async => Map<String, dynamic>.from(
    await api.request(
      'GET',
      '/head/$kind?${Uri(queryParameters: {'search': search, 'page': '$page', 'semester_id': ?semester, 'course_id': ?course}).query}',
    ) as Map,
  );
  Future<void> saveCourse(Json? row, String code, String name) async {
    await api.request(
      row == null ? 'POST' : 'PATCH',
      row == null ? '/head/courses' : '/head/courses/${row['id']}',
      {'code': code, 'name': name, if (row != null) 'version': row['version']},
    );
  }

  Future<void> assign(Json row, String lecturer) async {
    await api.request('PATCH', '/head/sections/${row['id']}/lecturer', {
      'version': row['version'],
      'lecturer_id': lecturer,
    });
  }

  Future<Json> report(
    String path,
    Map<String, String> filters,
  ) async => Map<String, dynamic>.from(
    await api.request(
      'GET',
      '$path${filters.isEmpty ? '' : '?${Uri(queryParameters: filters).query}'}',
    ) as Map,
  );
}
