import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfap/core/api/api_client.dart';
import 'package:myfap/head/screens/head_home_screen.dart';

class HeadApi extends ApiClient {
  final writes = <Map<String, dynamic>>[];
  final reads = <String>[];
  bool conflict = false, locked = false, failLoad = false;
  Map<String, dynamic> course = {
    'id': 'course1',
    'code': 'PRM393',
    'name': 'Flutter',
    'version': 3,
  };
  Map<String, dynamic> get section => {
    'id': 'section1',
    'version': 7,
    'code': 'SE01',
    'course': 'Flutter',
    'semester_code': 'FALL-2026',
    'course_id': 'course1',
    'semester_id': 'semester1',
    'lecturer_id': 'lecturer1',
    'lecturer': 'Giảng viên A',
    'lecturer_code': 'GV001',
    'session_count': locked ? 2 : 0,
  };
  Map<String, dynamic> get lesson => {
    'id': 'session1',
    'section_code': 'SE01',
    'course': 'Flutter',
    'room_id': 'room1',
    'room_name': 'A101',
    'session_date': '2026-11-12',
    'slot_id': 1,
    'start_at': DateTime.now()
        .toUtc()
        .add(const Duration(days: 1))
        .toIso8601String(),
    'status': 'SCHEDULED',
    'attendance_saved': false,
  };
  @override
  Future<dynamic> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    if (method != 'GET') {
      writes.add({'method': method, 'path': path, 'body': body});
      if (conflict) throw ApiException('Dữ liệu đã thay đổi', statusCode: 409);
      return {'id': 'saved', 'version': 8};
    }
    reads.add(path);
    if (failLoad) throw ApiException('Không kết nối được máy chủ');
    if (path == '/head/options') {
      return {
        'courses': [course],
        'semesters': [
          {'id': 'semester1', 'code': 'FALL-2026'},
        ],
        'lecturers': [
          {'id': 'lecturer1', 'name': 'Giảng viên A', 'user_code': 'GV001'},
          {'id': 'lecturer2', 'name': 'Giảng viên B', 'user_code': 'GV002'},
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
    if (path.startsWith('/reports/attendance')) {
      return {
        'items': [
          {
            'section_code': 'SE01',
            'course': 'Flutter',
            'lecturer': 'Giảng viên A',
            'active_enrollments': 20,
            'sessions': 8,
            'recorded_sessions': 3,
            'presence_rate': null,
          },
        ],
      };
    }
    if (path.startsWith('/reports/requests')) {
      return {
        'leave_requests': [
          {'status': 'APPROVED', 'count': 2},
        ],
        'change_requests': [
          {'status': 'PENDING', 'count': 1},
        ],
        'major_transfers': <dynamic>[],
      };
    }
    if (path.startsWith('/head/courses?')) {
      return {
        'items': [course],
        'total': 1,
        'has_more': false,
      };
    }
    if (path.startsWith('/head/sections?')) {
      return {
        'items': [section],
        'total': 1,
        'has_more': false,
      };
    }
    if (path.startsWith('/schedule?')) return [lesson];
    if (path == '/rooms') {
      return [
        {'id': 'room1', 'name': 'A101', 'capacity': 30},
        {'id': 'room2', 'name': 'A102', 'capacity': 40},
        {'id': 'small', 'name': 'SMALL', 'capacity': 10},
      ];
    }
    if (path.startsWith('/change-requests?')) {
      return {
        'items': [
          {
            ...lesson,
            'id': 'req1',
            'status': 'PENDING',
            'reason': 'Cần phòng rộng',
            'original_date': lesson['session_date'],
            'original_slot_id': 1,
            'proposed_date': lesson['session_date'],
            'proposed_slot_id': 1,
            'proposed_room_name': 'A102',
            'created_at': '2026-11-10',
          },
        ],
        'total': 1,
        'has_more': false,
      };
    }
    throw StateError('Unexpected $method $path');
  }
}

Future<void> openHead(WidgetTester tester, HeadApi api) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HeadHomeScreen(
        user: {'name': 'Trưởng bộ môn Duy'},
        api: api,
        onLoggedOut: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder field(String label) => find.widgetWithText(TextFormField, label);
void main() {
  testWidgets(
    'HEAD có đúng bốn màn hình, báo cáo tổng hợp và không có màn chuyên cần',
    (tester) async {
      final api = HeadApi();
      addTearDown(api.dispose);
      await openHead(tester, api);
      expect(find.textContaining('Số lớp: 2'), findsOneWidget);
      expect(find.text('Theo dõi chuyên cần'), findsNothing);
      expect(
        api.reads.any(
          (p) => p.contains('/attendance') && !p.startsWith('/reports/'),
        ),
        isFalse,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('FALL-2026').last);
      await tester.pumpAndSettle();
      expect(api.reads, contains('/department/summary?semester_id=semester1'));
    },
  );
  testWidgets('Tạo môn không gửi department hoặc quyền do client quyết định', (
    tester,
  ) async {
    final api = HeadApi();
    addTearDown(api.dispose);
    await openHead(tester, api);
    await tester.tap(find.text('Môn học').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm môn học'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu môn học'));
    await tester.pumpAndSettle();
    expect(api.writes, isEmpty);
    await tester.enterText(field('Mã môn'), 'SDN302');
    await tester.enterText(field('Tên môn'), 'Node.js');
    await tester.tap(find.text('Lưu môn học'));
    await tester.pumpAndSettle();
    expect(api.writes.single, {
      'method': 'POST',
      'path': '/head/courses',
      'body': {'code': 'SDN302', 'name': 'Node.js'},
    });
  });
  testWidgets('Sửa môn gửi version và bắt tải lại khi conflict', (
    tester,
  ) async {
    final api = HeadApi()..conflict = true;
    addTearDown(api.dispose);
    await openHead(tester, api);
    await tester.tap(find.text('Môn học').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sửa môn học'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Tên môn'), 'Flutter nâng cao');
    await tester.tap(find.text('Lưu môn học'));
    await tester.pumpAndSettle();
    expect(api.writes.single['body'], {
      'code': 'PRM393',
      'name': 'Flutter nâng cao',
      'version': 3,
    });
    expect(find.text('Dữ liệu đã thay đổi'), findsOneWidget);
    expect(find.text('Đóng và tải lại'), findsOneWidget);
    await tester.tap(find.text('Đóng và tải lại'));
    await tester.pumpAndSettle();
    expect(api.writes.length, 1);
  });
  testWidgets('Phân công giảng viên gửi đúng lớp và version', (tester) async {
    final api = HeadApi();
    addTearDown(api.dispose);
    await openHead(tester, api);
    await tester.tap(find.text('Phân công').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Phân công giảng viên'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phân công giảng viên'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giảng viên B • GV002').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận phân công'));
    await tester.pumpAndSettle();
    expect(api.writes.single, {
      'method': 'PATCH',
      'path': '/head/sections/section1/lecturer',
      'body': {'version': 7, 'lecturer_id': 'lecturer2'},
    });
  });
  testWidgets('Lớp có buổi học không được đổi phân công', (tester) async {
    final api = HeadApi()..locked = true;
    addTearDown(api.dispose);
    await openHead(tester, api);
    await tester.tap(find.text('Phân công').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Phân công giảng viên'),
          )
          .onPressed,
      isNull,
    );
  });
  testWidgets('HEAD chuyển phòng có ngày ca chỉ đọc và xác nhận gửi STAFF', (
    tester,
  ) async {
    final api = HeadApi();
    addTearDown(api.dispose);
    await openHead(tester, api);
    await tester.tap(find.text('Chuyển phòng').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Xin chuyển phòng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xin chuyển phòng'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.textContaining('Lịch giữ nguyên:'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('SMALL • 10 chỗ'), findsNothing);
    await tester.tap(find.text('A102 • 40 chỗ').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Phòng cũ bảo trì');
    await tester.tap(find.text('Gửi đơn'));
    await tester.pumpAndSettle();
    expect(api.writes, isEmpty);
    await tester.tap(find.text('Xác nhận gửi'));
    await tester.pumpAndSettle();
    expect(api.writes.single['body'], {
      'session_id': 'session1',
      'proposed_room_id': 'room2',
      'proposed_date': api.lesson['session_date'],
      'proposed_slot_id': 1,
      'reason': 'Phòng cũ bảo trì',
    });
    await tester.tap(find.text('Đơn đã gửi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cần phòng rộng'), findsOneWidget);
  });
  testWidgets('HEAD có tải lại khi lỗi mạng và bố cục điện thoại không tràn', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = HeadApi()..failLoad = true;
    addTearDown(api.dispose);
    await openHead(tester, api);
    expect(find.text('Không kết nối được máy chủ'), findsOneWidget);
    api.failLoad = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    for (final tab in ['Môn học', 'Phân công', 'Chuyển phòng']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
