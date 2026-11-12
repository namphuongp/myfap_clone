import '../../core/api/api_client.dart';
import '../models/student_notice.dart';

class StudentNoticeRepository {
  const StudentNoticeRepository(this.api);

  final ApiClient api;

  Future<List<StudentNotice>> list({int page = 1}) async {
    // TB2: Gọi GET /notices, chỉ yêu cầu thông báo đã phát hành.
    final payload = Map<String, dynamic>.from(
      await api.request('GET', '/notices?page=$page&status=PUBLISHED') as Map,
    );
    return (payload['items'] as List)
        .map(
          (row) =>
              StudentNotice.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<StudentNotice> detail(String id) async {
    final payload = Map<String, dynamic>.from(
      await api.request('GET', '/notices/$id') as Map,
    );
    return StudentNotice.fromJson(payload);
  }
}
