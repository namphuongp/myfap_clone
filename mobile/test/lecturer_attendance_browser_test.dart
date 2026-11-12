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
import 'package:myfap/lecturer/screens/lecturer_attendance_classes_screen.dart';
import 'package:myfap/lecturer/screens/lecturer_attendance_courses_screen.dart';
import 'package:myfap/lecturer/screens/lecturer_attendance_sessions_screen.dart';
import 'package:myfap/lecturer/screens/lecturer_attendance_screen.dart';
import 'package:myfap/lecturer/utils/lecturer_dates.dart';
import 'package:myfap/lecturer/widgets/lecturer_ui.dart';

class AttendanceBrowserApi extends ApiClient {
  final calls = <(String, String)>[];
  bool fail = false, moved = false, outsideTerm = false;
  Json lesson(
    String id,
    String section,
    int offset, {
    bool saved = false,
    String status = 'SCHEDULED',
    String semester = 'current',
  }) {
    final start = vnMidnight(vnDay().add(Duration(days: offset)));
    return {
      'id': id,
      'section_id': section,
      'section_code': section == 'section-a' ? 'SE20A' : 'SE20B',
      'semester_id': semester,
      'course': 'Lập trình ứng dụng di động',
      'course_code': 'PRM393',
      'course_id': 'course-prm393',
      'room_id': 'room-1',
      'room_name': 'BE-301',
      'slot_id': 1,
      'start_at': start.toIso8601String(),
      'end_at': start
          .add(const Duration(hours: 2, minutes: 20))
          .toIso8601String(),
      'status': status,
      'attendance_saved': saved,
    };
  }

  @override
  Future<dynamic> request(String method, String path, [Json? body]) async {
    calls.add((method, path));
    if (fail) throw ApiException('Không kết nối được máy chủ');
    final route = Uri.parse(path);
    if (route.path == '/semesters') {
      return [
        {
          'id': 'current',
          'code': 'FALL-2026',
          'start_at': vnMidnight(vnDay().subtract(const Duration(days: 30)))
              .toIso8601String(),
          'end_at': vnMidnight(
            vnDay().add(Duration(days: outsideTerm ? -1 : 30)),
          ).toIso8601String(),
        },
      ];
    }
    if (route.path == '/schedule') {
      return [
        lesson('a-past', 'section-a', -1, saved: true, status: 'COMPLETED'),
        lesson('a-today', 'section-a', 0),
        {
          ...lesson('a-future', 'section-a', moved ? 2 : 1),
          if (moved) 'slot_id': 3,
          if (moved) 'room_name': 'BE-302',
        },
        lesson('b-future', 'section-b', 1),
        lesson('cancelled', 'section-a', 3, status: 'CANCELLED'),
        lesson('other-term', 'section-a', 4, semester: 'old'),
      ];
    }
    throw StateError('Unexpected API call: $method $path');
  }
}

void main() {
  setUpAll(() async {
    final fonts = Platform.environment['PROFILE_FONT_ROOT'];
    if (fonts == null) return;
    for (final (family, filename) in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final loader = FontLoader(family)
        ..addFont(
          Future.value(
            ByteData.sublistView(await File('$fonts/$filename').readAsBytes()),
          ),
        );
      await loader.load();
    }
  });
  AttendanceBrowserApi fixture() {
    final api = AttendanceBrowserApi();
    addTearDown(api.dispose);
    return api;
  }

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('browser-preview'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: lecturerTheme(ThemeData(fontFamily: 'Roboto')),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
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
        find.byKey(const Key('browser-preview')),
      );
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(dir).create(recursive: true);
      await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'Attendance entry opens separate classes then sessions without opening a student roster',
    (tester) async {
      final api = fixture();
      await pump(
        tester,
        LecturerHomeScreen(
          user: {'name': 'Giảng viên demo', 'role': 'LECTURER'},
          api: api,
          onLoggedOut: () {},
        ),
      );
      await tester.tap(find.text('Điểm danh'));
      await tester.pumpAndSettle();
      expect(find.byType(LecturerAttendanceCoursesScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey('attendance-course-course-prm393')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('attendance-class-section-a')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('attendance-course-course-prm393')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LecturerAttendanceClassesScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey('attendance-class-section-a')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('attendance-class-section-b')),
        findsOneWidget,
      );
      expect(find.text('Đã điểm danh 1/3 buổi'), findsOneWidget);
      expect(find.text('Đã điểm danh 0/1 buổi'), findsOneWidget);
      expect(
        api.calls.where((c) => Uri.parse(c.$2).path == '/schedule').length,
        2,
      );
      await capture(tester, 'attendance-classes');
      await tester.tap(
        find.byKey(const ValueKey('attendance-class-section-a')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LecturerAttendanceSessionsScreen), findsOneWidget);
      expect(find.text('DANH SÁCH BUỔI HỌC (3)'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('attendance-session-a-past')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('attendance-session-cancelled')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('attendance-session-other-term')),
        findsNothing,
      );
      expect(find.byType(LecturerAttendanceScreen), findsNothing);
      expect(api.calls.any((c) => c.$2.contains('/attendance')), isFalse);
      await capture(tester, 'attendance-class-sessions');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Refreshing sessions reflects a moved slot and room without duplicate sessions',
    (tester) async {
      final api = fixture(), repo = LecturerRepository(api);
      final data = await repo.attendanceOverview();
      await pump(
        tester,
        LecturerAttendanceSessionsScreen(
          repository: repo,
          term: data.term!,
          section: data.classes.first,
        ),
      );
      api.moved = true;
      await tester.tap(find.byTooltip('Tải lại các buổi học'));
      await tester.pumpAndSettle();
      final target = find.byKey(const ValueKey('attendance-session-a-future'));
      await tester.scrollUntilVisible(
        target,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(target, findsOneWidget);
      expect(
        find.descendant(of: target, matching: find.text('Phòng BE-302')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: target,
          matching: find.text('Slot 3 · 12:50 – 15:10'),
        ),
        findsOneWidget,
      );
      expect(api.calls.every((c) => c.$1 == 'GET'), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Class list can retry errors and does not fetch sessions outside a semester',
    (tester) async {
      final api = fixture()..fail = true;
      await pump(
        tester,
        LecturerAttendanceClassesScreen(
          repository: LecturerRepository(api),
          courseId: 'course-prm393',
          courseName: 'PRM393 · Lập trình ứng dụng di động',
        ),
      );
      expect(find.text('Không kết nối được máy chủ'), findsOneWidget);
      api.fail = false;
      await tester.tap(find.text('Tải lại'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('attendance-class-section-a')),
        findsOneWidget,
      );
      api.outsideTerm = true;
      api.calls.clear();
      await tester.tap(find.byTooltip('Tải lại các lớp'));
      await tester.pumpAndSettle();
      expect(find.text('Hiện đang ngoài học kỳ'), findsOneWidget);
      expect(
        api.calls.any((c) => Uri.parse(c.$2).path == '/schedule'),
        isFalse,
      );
    },
  );
  testWidgets('Class cards and session list fit 320px with larger text', (
    tester,
  ) async {
    final api = fixture(), repo = LecturerRepository(api);
    await pump(
      tester,
      LecturerAttendanceClassesScreen(
        repository: repo,
        courseId: 'course-prm393',
        courseName: 'PRM393 · Lập trình ứng dụng di động',
      ),
      size: const Size(320, 740),
      scale: 1.3,
    );
    await capture(tester, 'attendance-classes-320');
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('attendance-class-section-a')));
    await tester.pumpAndSettle();
    await capture(tester, 'attendance-sessions-320');
    expect(tester.takeException(), isNull);
  });
}
