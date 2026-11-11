import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfap/core/api/api_client.dart';
import 'package:myfap/lecturer/widgets/lecturer_ui.dart';

import 'head_test.dart' as base;

class LecturerApi extends base.HeadApi {
  final writes = <Map<String, dynamic>>[];
  bool failList = false, conflict = false;
  Map<String, dynamic> row = {
    'id': 'teacher1',
    'version': 4,
    'user_code': 'GV001',
    'name': 'Nguyễn An',
    'email': 'an@test.local',
    'phone': '0901234567',
    'address': 'Hồ Chí Minh',
    'active': true,
    'teaching': {
      'total_sessions': 8,
      'upcoming_sessions': 2,
      'completed_sessions': 6,
    },
  };
  @override
  Future<dynamic> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    if (path.startsWith('/head/lecturers')) {
      if (method == 'GET') {
        reads.add(path);
        if (failList) throw ApiException('Không tải được giảng viên');
        if (path.startsWith('/head/lecturers?')) {
          return {
            'total': 1,
            'has_more': false,
            'items': [Map<String, dynamic>.from(row)],
          };
        }
        return Map<String, dynamic>.from(row);
      }
      writes.add({'method': method, 'path': path, 'body': body});
      if (conflict) throw ApiException('Dữ liệu đã thay đổi', statusCode: 409);
      row = {...row, ...body!, 'version': 5};
      return Map<String, dynamic>.from(row);
    }
    return super.request(method, path, body);
  }
}

Finder input(String name) => find.widgetWithText(TextFormField, name);
Future<void> list(WidgetTester tester, LecturerApi api) async {
  await base.openHead(tester, api);
  await tester.tap(find.text('Quản lý giảng viên').last);
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, String label) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Tìm kiếm và lọc giảng viên theo trạng thái', (tester) async {
    final api = LecturerApi();
    addTearDown(api.dispose);
    await list(tester, api);
    expect(find.text('Nguyễn An • GV001'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'GV001');
    await tester.tap(find.byTooltip('Tìm giảng viên'));
    await tester.pumpAndSettle();
    expect(api.reads.last, contains('search=GV001'));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ngừng hoạt động').last);
    await tester.pumpAndSettle();
    expect(api.reads.last, contains('status=INACTIVE'));
  });
  testWidgets(
    'Tạo giảng viên kiểm tra form và gửi đúng dữ liệu, không tự gán role/bộ môn',
    (tester) async {
      final api = LecturerApi();
      addTearDown(api.dispose);
      await list(tester, api);
      await tester.tap(find.text('Thêm giảng viên'));
      await tester.pumpAndSettle();
      await tapVisible(tester, 'Lưu giảng viên');
      expect(api.writes, isEmpty);
      for (final entry in {
        'Mã giảng viên': 'GV002',
        'Họ và tên': 'Nguyễn Bình',
        'Email đăng nhập': 'BINH@test.local',
        'Số điện thoại': '0902222222',
        'Địa chỉ': 'Hà Nội',
        'Mật khẩu ban đầu': 'Lecturer@12345678',
        'Nhập lại mật khẩu': 'Lecturer@12345678',
      }.entries) {
        await tester.ensureVisible(input(entry.key));
        await tester.pumpAndSettle();
        await tester.enterText(input(entry.key), entry.value);
      }
      await tapVisible(tester, 'Lưu giảng viên');
      expect(api.writes, isEmpty);
      await tester.tap(find.text('Xác nhận lưu'));
      await tester.pumpAndSettle();
      expect(api.writes.single['method'], 'POST');
      final body = api.writes.single['body'] as Map;
      expect(body['email'], 'binh@test.local');
      expect(body['user_code'], 'GV002');
      expect(body.containsKey('role'), isFalse);
      expect(body.containsKey('department_id'), isFalse);
    },
  );
  testWidgets(
    'Xem chi tiết, sửa thông tin gửi đúng version và cập nhật danh sách',
    (tester) async {
      final api = LecturerApi();
      addTearDown(api.dispose);
      await list(tester, api);
      await tester.tap(find.text('Nguyễn An • GV001'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tổng buổi dạy: 8'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      await tapVisible(tester, 'Sửa thông tin giảng viên');
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.enterText(input('Họ và tên'), 'Nguyễn An mới');
      expect(
        tester.widget<TextFormField>(input('Mã giảng viên')).enabled,
        isFalse,
      );
      await tapVisible(tester, 'Lưu giảng viên');
      await tester.tap(find.text('Xác nhận lưu'));
      await tester.pumpAndSettle();
      expect(api.writes.single['body']['version'], 4);
      expect(api.writes.single['body'].containsKey('user_code'), isFalse);
      expect(find.text('Nguyễn An mới'), findsOneWidget);
    },
  );
  testWidgets('Conflict không tự gửi lại hoặc ghi đè', (tester) async {
    final api = LecturerApi()..conflict = true;
    addTearDown(api.dispose);
    await list(tester, api);
    await tester.tap(find.text('Nguyễn An • GV001'));
    await tester.pumpAndSettle();
    await tapVisible(tester, 'Sửa thông tin giảng viên');
    await tapVisible(tester, 'Lưu giảng viên');
    await tester.tap(find.text('Xác nhận lưu'));
    await tester.pumpAndSettle();
    expect(api.writes.length, 1);
    expect(find.text('Dữ liệu đã thay đổi'), findsOneWidget);
    expect(find.text('Đóng và tải lại dữ liệu'), findsOneWidget);
  });
  testWidgets(
    'Lỗi mạng có thử lại, HEAD dùng cùng màu giảng viên và không tràn ở 320px',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = LecturerApi()..failList = true;
      addTearDown(api.dispose);
      await list(tester, api);
      expect(find.text('Không tải được giảng viên'), findsOneWidget);
      api.failList = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      final context = tester.element(find.text('Nguyễn An • GV001'));
      expect(Theme.of(context).colorScheme.primary, lecturerNavy);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Thêm giảng viên'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
