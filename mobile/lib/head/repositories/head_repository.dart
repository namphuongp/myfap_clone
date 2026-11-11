import '../../core/api/api_client.dart';

typedef Json = Map<String, dynamic>;

class HeadRepository {
  HeadRepository(this.api);
  final ApiClient api;
  List<Json> rows(dynamic data) =>
      (data as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
  Future<Json> options() async => Map<String, dynamic>.from(
    await api.request('GET', '/head/options') as Map,
  );
  Future<Json> lecturers({
    String search = '',
    String status = 'ALL',
    int page = 1,
  }) async => Map<String, dynamic>.from(
    await api.request(
      'GET',
      '/head/lecturers?${Uri(queryParameters: {'search': search, 'status': status, 'page': '$page'}).query}',
    ) as Map,
  );
  Future<Json> lecturer(String id) async => Map<String, dynamic>.from(
    await api.request('GET', '/head/lecturers/$id') as Map,
  );
  Future<void> saveLecturer(Json? row, Json fields) async {
    await api.request(
      row == null ? 'POST' : 'PATCH',
      row == null ? '/head/lecturers' : '/head/lecturers/${row['id']}',
      {...fields, if (row != null) 'version': row['version']},
    );
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
