import '../../core/api/api_client.dart';

typedef Json = Map<String, dynamic>;

class LecturerRepository {
  LecturerRepository(this.api);
  final ApiClient api;
  List<Json> rows(dynamic data) =>
      (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  Future<List<Json>> schedule(DateTime day) async {
    final from = DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).subtract(const Duration(hours: 7));
    final query = Uri(
      queryParameters: {
        'from': from.toIso8601String(),
        'to': from.add(const Duration(days: 7)).toIso8601String(),
      },
    ).query;
    return rows(await api.request('GET', '/schedule?$query'));
  }

  Future<Json> requests(
    String kind,
    String status,
    int page,
  ) async => Map<String, dynamic>.from(
    await api.request(
      'GET',
      '/$kind-requests?${Uri(queryParameters: {if (status.isNotEmpty) 'status': status, 'page': '$page'}).query}',
    ) as Map,
  );
  Future<void> review(Json row, String decision, String note) async {
    await api.request('PATCH', '/leave-requests/${row['id']}/decision', {
      'version': row['version'],
      'decision': decision,
      'note': note,
    });
  }

  Future<List<Json>> rooms() async => rows(await api.request('GET', '/rooms'));
  Future<List<Json>> slots() async =>
      rows(await api.request('GET', '/time-slots'));
  Future<void> change(Json body) async {
    await api.request('POST', '/change-requests', body);
  }

  Future<Json> attendance(String id) async => Map<String, dynamic>.from(
    await api.request('GET', '/sessions/$id/attendance') as Map,
  );
  Future<void> saveAttendance(String id, int version, List<Json> rows) async {
    await api.request('PUT', '/sessions/$id/attendance', {
      'version': version,
      'rows': rows,
    });
  }
}
