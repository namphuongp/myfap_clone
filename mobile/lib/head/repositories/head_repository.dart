import '../../core/api/api_client.dart';

typedef Json = Map<String, dynamic>;

/// Tập trung các lời gọi API phục vụ quản lý giảng viên và báo cáo của HEAD.
class HeadRepository {
  HeadRepository(this.api);
  final ApiClient api;
  /// Chuyển danh sách JSON từ API thành các bản ghi có kiểu thống nhất.
  List<Json> rows(dynamic data) =>
      (data as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
  /// Lấy học kỳ, môn học và giảng viên để hiển thị các bộ lọc.
  Future<Json> options() async => Map<String, dynamic>.from(
    await api.request('GET', '/head/options') as Map,
  );
  /// Lấy danh sách giảng viên theo từ khóa, trạng thái và trang hiện tại.
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
  /// Lấy hồ sơ và thống kê giảng dạy của một giảng viên theo ID.
  Future<Json> lecturer(String id) async => Map<String, dynamic>.from(
    await api.request('GET', '/head/lecturers/$id') as Map,
  );
  /// Tạo mới bằng POST; cập nhật bằng PATCH kèm version để kiểm tra xung đột.
  Future<void> saveLecturer(Json? row, Json fields) async {
    await api.request(
      row == null ? 'POST' : 'PATCH',
      row == null ? '/head/lecturers' : '/head/lecturers/${row['id']}',
      {...fields, if (row != null) 'version': row['version']},
    );
  }

  /// Gọi API báo cáo và mã hóa các bộ lọc thành query parameters.
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
