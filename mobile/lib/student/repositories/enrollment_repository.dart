import '../../core/api/api_client.dart';
import '../models/enrollment_data.dart';

class EnrollmentRepository {
  const EnrollmentRepository(this.api);

  final ApiClient api;

  List<Map<String, dynamic>> _rows(dynamic value) => (value as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();

  Future<EnrollmentData> load() async {
    String? availableError;
    final availableRequest = api
        .request('GET', '/sections/available')
        .catchError((Object error) {
          availableError = error.toString();
          return <dynamic>[];
        });
    final results = await Future.wait([
      availableRequest,
      api.request('GET', '/me/enrollments'),
      api.request('GET', '/sections'),
      api.request('GET', '/courses'),
      api.request('GET', '/semesters'),
    ]);
    final mySections = _rows(results[2]).map(SectionOption.fromJson);
    return EnrollmentData(
      available: _rows(results[0]).map(SectionOption.fromJson).toList(),
      availableError: availableError,
      enrollments: _rows(results[1]).map(EnrollmentRecord.fromJson).toList(),
      mySections: {for (final row in mySections) row.id: row},
      courseNames: {
        for (final row in _rows(results[3]))
          row['id'] as String: row['name']?.toString() ?? 'Môn học',
      },
      semesterNames: {
        for (final row in _rows(results[4]))
          row['id'] as String: row['name']?.toString() ?? 'Học kỳ',
      },
    );
  }

  Future<List<SectionSessionPreview>> sessions(String sectionId) async {
    final rows = _rows(
      await api.request('GET', '/sections/$sectionId/sessions'),
    );
    final sessions = rows.map(SectionSessionPreview.fromJson).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return sessions;
  }

  Future<void> register(String sectionId) async {
    await api.request('POST', '/sections/$sectionId/enrollments', {});
  }

  Future<void> withdraw({
    required String sectionId,
    required String studentId,
    required int version,
  }) async {
    await api.request(
      'POST',
      '/sections/$sectionId/enrollments/$studentId/withdraw',
      {'version': version},
    );
  }
}
