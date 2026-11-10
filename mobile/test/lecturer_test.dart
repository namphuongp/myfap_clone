import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfap/core/api/api_client.dart';
import 'package:myfap/lecturer/models/lecturer_data.dart';
import 'package:myfap/lecturer/repositories/lecturer_repository.dart';
import 'package:myfap/lecturer/screens/lecturer_home_screen.dart';
import 'package:myfap/lecturer/screens/lecturer_schedule_screen.dart';
import 'package:myfap/lecturer/screens/lecturer_attendance_screen.dart';
import 'package:myfap/lecturer/screens/lecturer_requests_screen.dart';
import 'package:myfap/lecturer/screens/lecturer_change_screen.dart';
import 'package:myfap/lecturer/utils/lecturer_dates.dart';
import 'package:myfap/lecturer/widgets/lecturer_ui.dart';

class LecturerApiFixture extends ApiClient {
  final List<(String, String, Json?)> calls = [];
  bool fail = false, conflict = false, reviewed = false;
  List<Json> recorded = [];
  List<String>? initialStatuses;
  final user = <String, dynamic>{
    'id': 'lecturer-id',
    'name': 'Nguyễn Hoàng Minh',
    'role': 'LECTURER',
    'email': 'lecturer@myfap.local',
    'user_code': 'GV001',
    'version': 2,
    'department': {'name': 'Kỹ thuật phần mềm'},
  };
  List<Json> get terms => [
    {
      'id': 'term-1',
      'code': 'FALL-2026',
      'start_at': DateTime.utc(vnDay().year, 1, 1).toIso8601String(),
      'end_at': DateTime.utc(vnDay().year + 1, 1, 1).toIso8601String(),
    },
  ];
  TeachingSession session({bool past = false}) {
    final day = vnDay().add(Duration(days: past ? -1 : 1));
    return TeachingSession({
      'id': past ? 'session-past' : 'session-next',
      'semester_id': 'term-1',
      'section_code': 'SE1937',
      'course': 'Lập trình ứng dụng di động',
      'course_code': 'PRM393',
      'room_id': 'room-a',
      'room_name': 'BE-301',
      'status': past ? 'COMPLETED' : 'SCHEDULED',
      'slot_id': 1,
      'session_date': dateKey(day),
      'start_at': vnMidnight(day)
          .add(const Duration(hours: 7, minutes: 30))
          .toIso8601String(),
      'end_at': vnMidnight(day)
          .add(const Duration(hours: 9, minutes: 50))
          .toIso8601String(),
    });
  }

  Json get leave => {
    'id': 'leave-1',
    'version': 4,
    'status': reviewed ? 'APPROVED' : 'PENDING',
    'requester': {'name': 'Trần Ngọc Anh', 'user_code': 'HE190001'},
    'lesson': {
      'section_code': 'SE1937',
      'course': 'Lập trình ứng dụng di động',
    },
    'session_date': dateKey(vnDay().add(const Duration(days: 1))),
    'slot_id': 1,
    'reason': 'Em có lịch khám bệnh tại bệnh viện.',
    'review_note': reviewed ? 'Đồng ý cho nghỉ' : null,
  };
  @override
  Future<dynamic> request(String method, String path, [Json? body]) async {
    calls.add((method, path, body));
    if (fail) throw ApiException('Không kết nối được máy chủ');
    final route = Uri.parse(path);
    if (path == '/profile') return user;
    if (route.path == '/semesters') return terms;
    if (route.path == '/rooms') {
      return [
        {'id': 'room-a', 'name': 'BE-301', 'capacity': 30},
        {'id': 'room-b', 'name': 'BE-302', 'capacity': 40},
      ];
    }
    if (route.path == '/schedule') {
      return [session().data, session(past: true).data];
    }
    if (method == 'GET' && path.endsWith('/attendance')) {
      return {
        'version': recorded.isEmpty ? 7 : 8,
        'saved': recorded.isNotEmpty,
        'session_status': 'COMPLETED',
        'rows': [
          for (final (i, name) in ['Trần Ngọc Anh', 'Lê Bảo Nam'].indexed)
            {
              'student_id': 'student-$i',
              'name': name,
              'user_code': 'HE19000$i',
              'status': recorded.isEmpty
                  ? (initialStatuses?[i] ?? 'NOT_RECORDED')
                  : recorded[i]['status'],
              'note': i == 0 ? 'Nghỉ có phép' : null,
            },
        ],
      };
    }
    if (method == 'PUT') {
      if (conflict) {
        throw ApiException('Dữ liệu đã thay đổi, hãy tải lại', statusCode: 409);
      }
      recorded = jsonList(body!['rows']);
      return {'version': 8};
    }
    if (route.path == '/leave-requests') {
      return {
        'page': 1,
        'items': reviewed && route.queryParameters['status'] == 'PENDING'
            ? []
            : [leave],
      };
    }
    if (path.endsWith('/decision')) {
      reviewed = true;
      return {...leave, 'version': 5};
    }
    if (route.path == '/change-requests') {
      return method == 'POST'
          ? {'id': 'change-new'}
          : {
              'page': 1,
              'items': [
                {
                  'id': 'change-1',
                  'version': 1,
                  'status': 'PENDING',
                  'lesson': {
                    'section_code': 'SE1937',
                    'course': 'Lập trình ứng dụng di động',
                  },
                  'original_date': dateKey(
                    vnDay().add(const Duration(days: 1)),
                  ),
                  'proposed_date': dateKey(
                    vnDay().add(const Duration(days: 2)),
                  ),
                  'original_slot_id': 1,
                  'proposed_slot_id': 2,
                  'original_room_name': 'BE-301',
                  'proposed_room_name': 'BE-302',
                  'reason': 'Phòng học cần bảo trì',
                },
              ],
            };
    }
    throw StateError('Fixture chưa hỗ trợ $method $path');
  }
}

void main() {
  setUpAll(() async {
    final root = Platform.environment['PROFILE_FONT_ROOT'];
    if (root != null) {
      for (final (family, file) in [
        ('Roboto', 'Roboto-Regular.ttf'),
        ('MaterialIcons', 'MaterialIcons-Regular.otf'),
      ]) {
        final loader = FontLoader(family)
          ..addFont(
            Future.value(
              ByteData.sublistView(await File('$root/$file').readAsBytes()),
            ),
          );
        await loader.load();
      }
    }
  });
  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('lecturer-preview'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: lecturerTheme(ThemeData(fontFamily: 'Roboto')),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final dir = Platform.environment['LECTURER_PREVIEW_DIR'];
    if (dir == null) return;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('lecturer-preview')),
      );
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(dir).create(recursive: true);
      await File('$dir/$name.png').writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  LecturerApiFixture api() {
    final api = LecturerApiFixture();
    addTearDown(api.dispose);
    return api;
  }

  testWidgets('Trang chủ đúng phạm vi, mở lịch và hồ sơ theo mẫu', (
    tester,
  ) async {
    final mock = api();
    await pump(
      tester,
      LecturerHomeScreen(user: mock.user, api: mock, onLoggedOut: () {}),
    );
    expect(find.text('Duyệt đơn nghỉ'), findsOneWidget);
    expect(find.text('Điểm danh'), findsWidgets);
    expect(find.text('Mark Report'), findsNothing);
    expect(find.text('Thông báo'), findsNothing);
    expect(find.text('BUỔI DẠY GẦN ĐÂY'), findsNothing);
    expect(find.text('Tổng quan giảng dạy'), findsNothing);
    expect(mock.calls, isEmpty);
    await capture(tester, 'home');
    await tester.tap(find.text('Lịch dạy').first);
    await tester.pumpAndSettle();
    expect(find.text('FALL-2026'), findsOneWidget);
    expect(find.text('Học kỳ hiện tại'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    await capture(tester, 'schedule');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Hồ sơ cá nhân'));
    await tester.pumpAndSettle();
    expect(find.text('GV001'), findsOneWidget);
    expect(find.text('HM'), findsOneWidget);
    await capture(tester, 'profile');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Lịch chọn ngày, hiện slot và phòng; ngày trống có trạng thái rõ',
    (tester) async {
      final mock = api();
      await pump(
        tester,
        LecturerScheduleScreen(repository: LecturerRepository(mock)),
      );
      final next = vnDay().add(const Duration(days: 1));
      if (next.weekday == DateTime.monday) {
        await tester.tap(find.byTooltip('Tuần sau'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(ValueKey('teaching-day-${dateKey(next)}')));
      await tester.pumpAndSettle();
      expect(find.text('Phòng BE-301'), findsOneWidget);
      expect(find.text('07:30 – 09:50'), findsOneWidget);
      await capture(tester, 'schedule-day');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Điểm danh không mặc định Có mặt, gửi đủ lớp và version, giữ ghi chú',
    (tester) async {
      final mock = api();
      await pump(
        tester,
        LecturerAttendanceScreen(
          repository: LecturerRepository(mock),
          session: mock.session(past: true),
        ),
      );
      expect(find.text('Ghi chú: Đã duyệt đơn nghỉ'), findsOneWidget);
      await capture(tester, 'attendance');
      await tester.scrollUntilVisible(
        find.text('Lưu điểm danh'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu điểm danh'));
      await tester.pumpAndSettle();
      expect(mock.calls.where((c) => c.$1 == 'PUT'), isEmpty);
      for (var i = 0; i < 2; i++) {
        final radio = find.byKey(
          ValueKey('attendance-student-$i-${i == 0 ? 'ABSENT' : 'PRESENT'}'),
        );
        await tester.ensureVisible(radio);
        await tester.tap(radio);
        await tester.pumpAndSettle();
      }
      await tester.scrollUntilVisible(
        find.text('Lưu điểm danh'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu điểm danh'));
      await tester.pumpAndSettle();
      final put = mock.calls.singleWhere((c) => c.$1 == 'PUT');
      expect(put.$3!['version'], 7);
      expect(jsonList(put.$3!['rows']).map((r) => r['status']), [
        'ABSENT',
        'PRESENT',
      ]);
      expect(find.text('Đã ghi nhận điểm danh'), findsOneWidget);
      expect(find.text('Ghi chú: Đã duyệt đơn nghỉ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Buổi tương lai chỉ xem và không gửi điểm danh', (tester) async {
    final mock = api();
    await pump(
      tester,
      LecturerAttendanceScreen(
        repository: LecturerRepository(mock),
        session: mock.session(),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Lưu điểm danh'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Lưu điểm danh'),
          )
          .onPressed,
      isNull,
    );
    expect(mock.calls.where((c) => c.$1 == 'PUT'), isEmpty);
  });
  testWidgets(
    'Duyệt nghỉ kiểm tra phản hồi, gửi version và cập nhật danh sách',
    (tester) async {
      final mock = api();
      await pump(
        tester,
        LecturerRequestsScreen(repository: LecturerRepository(mock)),
      );
      expect(find.text('Trần Ngọc Anh'), findsOneWidget);
      await capture(tester, 'leave-requests');
      await tester.ensureVisible(find.text('Xem và duyệt đơn'));
      await tester.tap(find.text('Xem và duyệt đơn'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duyệt nghỉ'));
      await tester.pumpAndSettle();
      expect(find.text('Nhập ý kiến phản hồi'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('leave-review-note')),
        'Đồng ý cho nghỉ',
      );
      await tester.tap(find.text('Duyệt nghỉ'));
      await tester.pumpAndSettle();
      final review = mock.calls.singleWhere((c) => c.$2.endsWith('/decision'));
      expect(review.$3, {
        'version': 4,
        'decision': 'APPROVED',
        'note': 'Đồng ý cho nghỉ',
      });
      expect(find.text('Không có đơn phù hợp'), findsOneWidget);
    },
  );
  testWidgets('Đổi phòng gửi đúng buổi/ngày/slot, chặn đề xuất không đổi', (
    tester,
  ) async {
    final mock = api();
    await pump(
      tester,
      LecturerChangeScreen(
        repository: LecturerRepository(mock),
        initialSession: mock.session(),
      ),
    );
    await capture(tester, 'change-request');
    await tester.enterText(
      find.byKey(const Key('change-reason')),
      'Phòng học cần bảo trì',
    );
    await tester.scrollUntilVisible(
      find.text('Gửi yêu cầu'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Gửi yêu cầu'));
    await tester.pumpAndSettle();
    expect(
      find.text('Hãy thay đổi ngày, slot hoặc phòng so với lịch hiện tại.'),
      findsOneWidget,
    );
    final room = find.byKey(const ValueKey('room-session-next'));
    await tester.ensureVisible(room);
    await tester.tap(room);
    await tester.pumpAndSettle();
    await tester.tap(find.text('BE-302 · 40 chỗ').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Gửi yêu cầu'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Gửi yêu cầu'));
    await tester.pumpAndSettle();
    final post = mock.calls.singleWhere((c) => c.$1 == 'POST');
    expect(post.$3!['session_id'], 'session-next');
    expect(post.$3!['proposed_room_id'], 'room-b');
    expect(post.$3!['proposed_slot_id'], 1);
    expect(post.$3!['proposed_date'], dateKey(mock.session().day));
  });
  testWidgets(
    'Lỗi kết nối có tải lại và trạng thái đơn đổi lịch có phòng cũ/mới',
    (tester) async {
      final mock = api()..fail = true;
      await pump(
        tester,
        LecturerRequestsScreen(
          repository: LecturerRepository(mock),
          initialLeave: false,
        ),
      );
      expect(find.text('Không kết nối được máy chủ'), findsOneWidget);
      mock.fail = false;
      await tester.tap(find.text('Tải lại'));
      await tester.pumpAndSettle();
      expect(find.textContaining('BE-301 → BE-302'), findsOneWidget);
      await capture(tester, 'change-history');
    },
  );
  testWidgets(
    'Conflict điểm danh không tự ghi đè và hỏi trước khi bỏ thay đổi',
    (tester) async {
      final mock = api()..conflict = true;
      await pump(
        tester,
        LecturerAttendanceScreen(
          repository: LecturerRepository(mock),
          session: mock.session(past: true),
        ),
      );
      for (var i = 0; i < 2; i++) {
        final radio = find.byKey(ValueKey('attendance-student-$i-PRESENT'));
        await tester.ensureVisible(radio);
        await tester.tap(radio);
        await tester.pumpAndSettle();
      }
      await tester.scrollUntilVisible(
        find.text('Lưu điểm danh'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu điểm danh'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Dữ liệu đã thay đổi'), findsOneWidget);
      expect(mock.recorded, isEmpty);
      await tester.tap(find.byTooltip('Tải lại danh sách'));
      await tester.pumpAndSettle();
      expect(find.text('Bỏ thay đổi chưa lưu?'), findsOneWidget);
      await tester.tap(find.text('Tiếp tục sửa'));
      await tester.pumpAndSettle();
      expect(mock.calls.where((c) => c.$1 == 'PUT').length, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Trạng thái cũ được giữ khi không chọn lại radio', (
    tester,
  ) async {
    final mock = api()..initialStatuses = ['EXCUSED', 'LATE'];
    await pump(
      tester,
      LecturerAttendanceScreen(
        repository: LecturerRepository(mock),
        session: mock.session(past: true),
      ),
    );
    expect(find.textContaining('Trạng thái cũ: Vắng có phép'), findsOneWidget);
    expect(find.textContaining('Trạng thái cũ: Đi muộn'), findsOneWidget);
    expect(
      tester
          .widgetList<RadioGroup<String>>(find.byType(RadioGroup<String>))
          .every((group) => group.groupValue == null),
      isTrue,
    );
    await tester.scrollUntilVisible(
      find.text('Lưu điểm danh'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu điểm danh'));
    await tester.pumpAndSettle();
    expect(mock.recorded.map((r) => r['status']), ['EXCUSED', 'LATE']);
  });
  testWidgets('Radio và note không tràn ở 320px với chữ lớn', (tester) async {
    final mock = api();
    await pump(
      tester,
      LecturerAttendanceScreen(
        repository: LecturerRepository(mock),
        session: mock.session(past: true),
      ),
      size: const Size(320, 740),
      textScale: 1.3,
    );
    expect(
      find.byKey(const ValueKey('attendance-student-0-ABSENT')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('attendance-student-0-PRESENT')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('attendance-student-1-PRESENT')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('attendance-student-1-ABSENT')),
      findsOneWidget,
    );
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    await capture(tester, 'attendance-320');
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(320, 740), const Size(1100, 800)]) {
    testWidgets('Layout giảng viên ${size.width} với cỡ chữ lớn', (
      tester,
    ) async {
      final mock = api();
      await pump(
        tester,
        LecturerHomeScreen(user: mock.user, api: mock, onLoggedOut: () {}),
        size: size,
        textScale: 1.3,
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -250));
      await tester.pumpAndSettle();
      await capture(tester, 'home-${size.width.toInt()}');
      expect(tester.takeException(), isNull);
    });
  }
}
