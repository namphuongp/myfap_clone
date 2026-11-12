import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfap/core/api/api_client.dart';
import 'package:myfap/staff/repositories/staff_repository.dart';
import 'package:myfap/staff/screens/staff_notices_screen.dart';
import 'package:myfap/staff/screens/staff_change_requests_screen.dart';

class FakeStaffApi extends ApiClient {
  final calls = <({String method, String path, Map<String, dynamic>? body})>[];
  Map<String, dynamic> notice = {
    'id': 'notice-1',
    'title': 'Lịch học kỳ tới',
    'content': 'Sinh viên kiểm tra lịch học.',
    'status': 'DRAFT',
    'version': 4,
  };
  final transfer = <String, dynamic>{
    'id': 'transfer-1',
    'version': 3,
    'status': 'PENDING',
    'reason': 'Xin chuyển ngành học',
    'student': {'name': 'Nguyễn An', 'user_code': 'SV001'},
    'from_major': {'code': 'SE', 'name': 'Kỹ thuật phần mềm'},
    'to_major': {'code': 'AI', 'name': 'Trí tuệ nhân tạo'},
    'effective_semester': {'code': 'SPRING-2027'},
    'applied_at': null,
  };
  @override
  Future<dynamic> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    calls.add((method: method, path: path, body: body));
    if (method == 'GET' && path.startsWith('/notices?')) {
      return {
        'page': 1,
        'items': [notice],
      };
    }
    if (method == 'GET' && path.startsWith('/change-requests?')) {
      return {'page': 1, 'items': <dynamic>[]};
    }
    if (method == 'GET' && path.startsWith('/major-transfer-requests?')) {
      return {
        'page': 1,
        'items': [transfer],
      };
    }
    if (method == 'POST' && path == '/notices') {
      notice = {...notice, ...body!, 'status': 'DRAFT'};
      return notice;
    }
    if (method == 'POST' && path == '/notices/notice-1/publish') {
      notice = {...notice, 'status': 'PUBLISHED', 'version': 5};
      return notice;
    }
    if (method == 'PATCH' &&
        path == '/major-transfer-requests/transfer-1/decision') {
      transfer['status'] = body!['decision'];
      return transfer;
    }
    throw StateError('Unexpected $method $path');
  }
}

Future<void> open(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Cán bộ tạo nháp thông báo với payload đúng phạm vi', (
    tester,
  ) async {
    final api = FakeStaffApi();
    await open(tester, StaffNoticesScreen(repository: StaffRepository(api)));
    await tester.tap(find.text('Soạn thông báo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Thông báo mới');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Nội dung thông báo học vụ mới',
    );
    await tester.ensureVisible(find.text('Lưu bản nháp'));
    await tester.tap(find.text('Lưu bản nháp'));
    await tester.pumpAndSettle();
    final call = api.calls.singleWhere(
      (c) => c.method == 'POST' && c.path == '/notices',
    );
    expect(call.body!['audience'], 'ALL_STUDENTS');
    expect(call.body!['title'], 'Thông báo mới');
    expect(find.text('Thông báo đã được lưu thành bản nháp.'), findsOneWidget);
  });
  testWidgets('Phát hành thông báo có xác nhận và gửi đúng version', (
    tester,
  ) async {
    final api = FakeStaffApi();
    await open(tester, StaffNoticesScreen(repository: StaffRepository(api)));
    await tester.tap(find.text('Phát hành'));
    await tester.pumpAndSettle();
    expect(api.calls.where((c) => c.method == 'POST'), isEmpty);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Phát hành'),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.calls.singleWhere((c) => c.method == 'POST').body, {
      'version': 4,
    });
    expect(find.text('Đã phát hành thông báo.'), findsOneWidget);
  });
  testWidgets(
    'Duyệt chuyển ngành cần phản hồi, gửi version và hiện kỳ hiệu lực',
    (tester) async {
      final api = FakeStaffApi();
      await open(
        tester,
        StaffChangeRequestsScreen(repository: StaffRepository(api)),
      );
      await tester.tap(find.text('Chuyển ngành'));
      await tester.pumpAndSettle();
      expect(find.text('Hiệu lực từ kỳ: SPRING-2027'), findsOneWidget);
      await tester.ensureVisible(find.text('Xem và xử lý đơn'));
      await tester.tap(find.text('Xem và xử lý đơn'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Duyệt'));
      await tester.pumpAndSettle();
      expect(api.calls.where((c) => c.method == 'PATCH'), isEmpty);
      await tester.enterText(
        find.byType(TextFormField),
        'Đã kiểm tra, áp dụng từ kỳ tới',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Duyệt'));
      await tester.pumpAndSettle();
      final call = api.calls.singleWhere((c) => c.method == 'PATCH');
      expect(call.path, '/major-transfer-requests/transfer-1/decision');
      expect(call.body!['version'], 3);
      expect(call.body!['decision'], 'APPROVED');
      expect(api.transfer['applied_at'], isNull);
    },
  );
}
