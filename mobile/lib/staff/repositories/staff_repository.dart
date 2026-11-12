import '../../core/api/api_client.dart';

typedef StaffJson = Map<String, dynamic>;

StaffJson _object(dynamic value) => Map<String, dynamic>.from(value as Map);

class StaffPage {
  const StaffPage({
    required this.page,
    required this.items,
    required this.pageSize,
  });
  final int page;
  final List<StaffJson> items;
  final int pageSize;
  bool get hasNext => items.length == pageSize;

  factory StaffPage.fromJson(StaffJson json, {required int pageSize}) =>
      StaffPage(
        page: (json['page'] as num?)?.toInt() ?? 1,
        items: (json['items'] as List? ?? const [])
            .map((row) => _object(row))
            .toList(),
        pageSize: pageSize,
      );
}

class StaffRepository {
  const StaffRepository(this.api);
  final ApiClient api;

  Future<StaffPage> changeRequests({String? status, int page = 1}) async {
    final query = Uri(queryParameters: {'page': '$page', 'status': ?status})
        .query;
    return StaffPage.fromJson(
      _object(await api.request('GET', '/change-requests?$query')),
      pageSize: 50,
    );
  }

  Future<void> reviewChange(
    StaffJson request, {
    required String decision,
    required String note,
  }) async {
    await api.request('PATCH', '/change-requests/${request['id']}/decision', {
      'version': request['version'],
      'decision': decision,
      'note': note,
    });
  }

  Future<StaffPage> majorTransfers({String? status, int page = 1}) async {
    final query = Uri(queryParameters: {'page': '$page', 'status': ?status}).query;
    return StaffPage.fromJson(
      _object(await api.request('GET', '/major-transfer-requests?$query')),
      pageSize: 50,
    );
  }

  Future<void> reviewMajorTransfer(
    StaffJson request, {
    required String decision,
    required String note,
  }) async {
    await api.request(
      'PATCH',
      '/major-transfer-requests/${request['id']}/decision',
      {'version': request['version'], 'decision': decision, 'note': note},
    );
  }

  Future<StaffPage> notices({String? status, int page = 1}) async {
    final query = Uri(queryParameters: {'page': '$page', 'status': ?status})
        .query;
    return StaffPage.fromJson(
      _object(await api.request('GET', '/notices?$query')),
      pageSize: 20,
    );
  }

  Future<StaffJson> createNotice({
    required String title,
    required String content,
    DateTime? expiresAt,
  }) async => _object(
    await api.request('POST', '/notices', {
      'title': title,
      'content': content,
      'audience': 'ALL_STUDENTS',
      'department_ids': <String>[],
      'major_ids': <String>[],
      'expires_at': expiresAt?.toUtc().toIso8601String(),
    }),
  );

  Future<void> publishNotice(StaffJson notice) async {
    await api.request('POST', '/notices/${notice['id']}/publish', {
      'version': notice['version'],
    });
  }
}
