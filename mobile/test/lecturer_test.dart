import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfap/core/api/api_client.dart';
import 'package:myfap/lecturer/screens/lecturer_home_screen.dart';

class LecturerApi extends ApiClient {
  final writes = <Map<String, dynamic>>[];
  bool conflict = false;
  String requestStatus = 'PENDING';
  final bool future;
  LecturerApi({this.future = false});
  Map<String, dynamic> get lesson {
    final d = DateTime.now().toUtc().add(Duration(days: future ? 1 : -1));
    return {
      'id': 'lesson',
      'section_code': 'SE01',
      'course': 'Flutter',
      'session_date': d
          .add(const Duration(hours: 7))
          .toIso8601String()
          .split('T')
          .first,
      'slot_id': 1,
      'room_id': 'room1',
      'room_name': 'A101',
      'start_at': d.toIso8601String(),
      'status': 'SCHEDULED',
      'attendance_saved': false,
    };
  }

  @override
  Future<dynamic> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    if (method != 'GET') {
      writes.add({'method': method, 'path': path, 'body': body});
      if (conflict) throw ApiException('Dữ liệu đã thay đổi', statusCode: 409);
      if (path.contains('/decision')) {
        requestStatus = body!['decision'] as String;
      }
      return {'version': 5};
    }
    if (path.startsWith('/schedule?')) return [lesson];
    if (path.startsWith('/leave-requests?') ||
        path.startsWith('/change-requests?')) {
      return {
        'total': 1,
        'has_more': false,
        'items': [
          {
            ...lesson,
            'id': 'request1',
            'version': 4,
            'requester_name': 'Nguyễn An',
            'requester_code': 'SV001',
            'reason': 'Khám bệnh',
            'status': requestStatus,
            'created_at': '2026-11-10',
            'original_date': lesson['session_date'],
            'original_slot_id': 1,
            'proposed_date': lesson['session_date'],
            'proposed_slot_id': 2,
            'proposed_room_name': 'A102',
          },
        ],
      };
    }
    if (path == '/rooms') {
      return [
        {'id': 'room1', 'name': 'A101', 'capacity': 30},
        {'id': 'room2', 'name': 'A102', 'capacity': 40},
      ];
    }
    if (path == '/time-slots') {
      return [
        {'id': 1, 'start_minute': 450, 'end_minute': 590},
        {'id': 2, 'start_minute': 600, 'end_minute': 740},
      ];
    }
    if (path.endsWith('/attendance')) {
      return {
        'version': 4,
        'saved': false,
        'session_status': 'SCHEDULED',
        'start_at': lesson['start_at'],
        'rows': [
          {
            'student_id': 'student1',
            'name': 'Nguyễn An',
            'user_code': 'SV001',
            'status': 'NOT_RECORDED',
            'note': 'Nghỉ có phép',
          },
        ],
      };
    }
    throw StateError('Unexpected $method $path');
  }
}

Future<void> open(WidgetTester tester, LecturerApi api) async {
  await tester.pumpWidget(
    MaterialApp(
      home: LecturerHomeScreen(
        user: {'name': 'Giảng viên A'},
        api: api,
        onLoggedOut: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Thoát điểm danh chưa lưu cần xác nhận và không gửi API', (
    tester,
  ) async {
    final api = LecturerApi();
    addTearDown(api.dispose);
    await open(tester, api);
    await tester.tap(find.text('Điểm danh').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mở danh sách điểm danh'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Có mặt').last);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Rời màn hình?'), findsOneWidget);
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(find.text('Mở danh sách điểm danh'), findsOneWidget);
    expect(api.writes, isEmpty);
  });
  testWidgets('Form đổi lịch không tràn trên điện thoại', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = LecturerApi(future: true);
    addTearDown(api.dispose);
    await open(tester, api);
    await tester.tap(find.text('Đổi lịch/phòng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yêu cầu thay đổi'));
    await tester.pumpAndSettle();
    expect(find.text('Yêu cầu đổi lịch / phòng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Bốn màn hình không tràn ở kích thước điện thoại', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = LecturerApi();
    addTearDown(api.dispose);
    await open(tester, api);
    for (final label in ['Đơn nghỉ', 'Đổi lịch/phòng', 'Điểm danh']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('Mở danh sách điểm danh'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Bốn màn hình và duyệt đơn gửi đúng version', (tester) async {
    final api = LecturerApi();
    addTearDown(api.dispose);
    await open(tester, api);
    expect(find.text('SE01 • Flutter'), findsOneWidget);
    await tester.tap(find.text('Đơn nghỉ'));
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn An • SV001'), findsOneWidget);
    await tester.tap(find.text('Duyệt nghỉ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(api.writes, isEmpty);
    await tester.enterText(find.byType(TextFormField), 'Đồng ý nghỉ');
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(api.writes.single['body'], {
      'version': 4,
      'decision': 'APPROVED',
      'note': 'Đồng ý nghỉ',
    });
  });
  testWidgets('Từ chối đơn không tự ghi đè khi xung đột', (tester) async {
    final api = LecturerApi()..conflict = true;
    addTearDown(api.dispose);
    await open(tester, api);
    await tester.tap(find.text('Đơn nghỉ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Từ chối').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'Cần bổ sung minh chứng',
    );
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(api.writes.single['body']['decision'], 'REJECTED');
    expect(find.text('Dữ liệu đã thay đổi'), findsOneWidget);
  });
  testWidgets('Đổi phòng giữ nguyên ngày và ca, gửi cho cán bộ duyệt', (
    tester,
  ) async {
    final api = LecturerApi(future: true);
    addTearDown(api.dispose);
    await open(tester, api);
    await tester.tap(find.text('Đổi lịch/phòng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yêu cầu thay đổi'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A102 • 40 chỗ').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).last,
      'Cần phòng rộng hơn',
    );
    await tester.ensureVisible(find.text('Gửi cán bộ duyệt'));
    await tester.tap(find.text('Gửi cán bộ duyệt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi yêu cầu'));
    await tester.pumpAndSettle();
    expect(api.writes.single['body'], {
      'session_id': 'lesson',
      'reason': 'Cần phòng rộng hơn',
      'proposed_date': api.lesson['session_date'],
      'proposed_slot_id': 1,
      'proposed_room_id': 'room2',
    });
  });
  testWidgets('Nghỉ có phép vẫn chưa ghi nhận, chọn điểm danh trước khi lưu', (
    tester,
  ) async {
    final api = LecturerApi();
    addTearDown(api.dispose);
    await open(tester, api);
    await tester.tap(find.text('Điểm danh').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mở danh sách điểm danh'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa ghi nhận'), findsOneWidget);
    expect(find.text('Nghỉ có phép (đơn nghỉ đã duyệt)'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vắng có phép').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu điểm danh (1 sinh viên)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(api.writes.single['body'], {
      'version': 4,
      'rows': [
        {'student_id': 'student1', 'status': 'EXCUSED'},
      ],
    });
  });
  testWidgets('Chưa bắt đầu buổi học không được điểm danh', (tester) async {
    final api = LecturerApi(future: true);
    addTearDown(api.dispose);
    await open(tester, api);
    await tester.tap(find.text('Điểm danh').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mở danh sách điểm danh'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .onChanged,
      isNull,
    );
    expect(api.writes, isEmpty);
  });
}
