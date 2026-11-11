import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfap/core/api/api_client.dart';
import 'package:myfap/head/screens/head_home_screen.dart';

class HeadApi extends ApiClient {
  final reads = <String>[];
  bool failLoad = false;
  @override
  Future<dynamic> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    if (method != 'GET') throw StateError('HEAD reports are read only');
    reads.add(path);
    if (failLoad) throw ApiException('Không kết nối được máy chủ');
    if (path == '/head/options') {
      return {
        'courses': [
          {'id': 'course1', 'name': 'Flutter'},
        ],
        'lecturers': [
          {'id': 'teacher1', 'name': 'Giảng viên A'},
        ],
        'semesters': [
          {'id': 'term1', 'code': 'FALL-2026'},
        ],
      };
    }
    if (path.startsWith('/department/summary')) {
      return {
        'sections': 2,
        'sessions': 8,
        'recorded_sessions': 3,
        'completed_sessions': 2,
        'cancelled_sessions': 0,
      };
    }
    if (path.startsWith('/reports/attendance')) return {'items': <dynamic>[]};
    if (path.startsWith('/reports/requests')) {
      return {'leave_requests': <dynamic>[], 'change_requests': <dynamic>[]};
    }
    throw StateError('Unexpected $path');
  }
}

Future<void> openHead(WidgetTester tester, HeadApi api) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HeadHomeScreen(
        user: {'name': 'Trưởng bộ môn'},
        api: api,
        onLoggedOut: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'HEAD có báo cáo và giảng viên, không khôi phục ba chức năng đã xóa',
    (tester) async {
      final api = HeadApi();
      addTearDown(api.dispose);
      await openHead(tester, api);
      await tester.tap(find.text('Báo cáo bộ môn'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Số lớp: 2'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Quản lý môn học'), findsNothing);
      expect(find.text('Phân công giảng dạy'), findsNothing);
      expect(find.text('Đơn chuyển phòng'), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('FALL-2026').last);
      await tester.pumpAndSettle();
      expect(api.reads, contains('/department/summary?semester_id=term1'));
    },
  );
  testWidgets(
    'Báo cáo còn tải lại khi lỗi mạng và không tràn trên điện thoại',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = HeadApi()..failLoad = true;
      addTearDown(api.dispose);
      await openHead(tester, api);
      await tester.tap(find.text('Báo cáo bộ môn'));
      await tester.pumpAndSettle();
      expect(find.text('Không kết nối được máy chủ'), findsOneWidget);
      api.failLoad = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Số lớp: 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
