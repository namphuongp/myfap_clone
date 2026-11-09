import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfap/core/api/api_client.dart';
import 'package:myfap/student/screens/enrollment_screen.dart';

class FakeEnrollmentApi extends ApiClient {
  FakeEnrollmentApi({this.registered = false, this.remaining = 30});

  bool registered;
  final int remaining;
  bool withdrawn = false;
  int? withdrawnVersion;

  static const section = {
    'id': '507f1f77bcf86cd799439011',
    'code': 'SE20A-DBI202',
    'course_id': '507f1f77bcf86cd799439012',
    'course': 'Cơ sở dữ liệu',
    'course_code': 'DBI202',
    'semester_id': '507f1f77bcf86cd799439013',
    'semester_code': 'FALL-2026',
    'remaining': 29,
  };

  @override
  Future<dynamic> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    if (method == 'GET' && path == '/sections/available') {
      return [
        {...section, 'remaining': remaining},
      ];
    }
    if (method == 'GET' && path == '/me/enrollments') {
      return registered || withdrawn
          ? [
              {
                'section_id': section['id'],
                'course_id': section['course_id'],
                'semester_id': section['semester_id'],
                'status': registered ? 'ACTIVE' : 'WITHDRAWN',
                'version': 3,
              },
            ]
          : [];
    }
    if (method == 'GET' && path == '/sections') {
      return registered ? [section] : [];
    }
    if (method == 'GET' && path == '/courses') {
      return [
        {'id': section['course_id'], 'name': 'Cơ sở dữ liệu'},
      ];
    }
    if (method == 'GET' && path == '/semesters') {
      return [
        {'id': section['semester_id'], 'name': 'Kỳ Fall 2026'},
      ];
    }
    if (method == 'GET' && path == '/sections/${section['id']}/sessions') {
      return [
        {
          'start_at': '2030-01-15T00:30:00.000Z',
          'end_at': '2030-01-15T02:50:00.000Z',
          'status': 'SCHEDULED',
        },
      ];
    }
    if (method == 'POST' && path == '/sections/${section['id']}/enrollments') {
      registered = true;
      return {};
    }
    if (method == 'POST' && path.endsWith('/withdraw')) {
      withdrawnVersion = body?['version'] as int?;
      registered = false;
      withdrawn = true;
      return {};
    }
    throw StateError('Unexpected request: $method $path');
  }
}

void main() {
  testWidgets('Xem lịch lớp rồi đăng ký môn', (tester) async {
    final api = FakeEnrollmentApi();
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EnrollmentScreen(
            api: api,
            studentId: '507f1f77bcf86cd799439014',
            onEnrollmentChanged: () => changes++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tìm lớp'));
    await tester.pumpAndSettle();
    expect(find.text('Còn 30 chỗ trống'), findsOneWidget);
    await tester.tap(find.text('Cơ sở dữ liệu'));
    await tester.pumpAndSettle();
    expect(find.text('Lịch học sắp tới'), findsOneWidget);
    await tester.tap(find.text('Đăng ký lớp'));
    await tester.pumpAndSettle();
    expect(api.registered, isTrue);
    expect(changes, 1);
    expect(find.text('Lớp của tôi'), findsOneWidget);
  });

  testWidgets('Lớp hết chỗ không thể đăng ký', (tester) async {
    final api = FakeEnrollmentApi(remaining: 0);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EnrollmentScreen(
            api: api,
            studentId: '507f1f77bcf86cd799439014',
            onEnrollmentChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tìm lớp'));
    await tester.pumpAndSettle();
    expect(find.text('Còn 0 chỗ trống'), findsOneWidget);
    await tester.tap(find.text('Cơ sở dữ liệu'));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Lớp đã đầy'),
    );
    expect(button.onPressed, isNull);
    expect(api.registered, isFalse);
  });

  testWidgets('Rút lớp gửi đúng version hiện tại', (tester) async {
    final api = FakeEnrollmentApi(registered: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EnrollmentScreen(
            api: api,
            studentId: '507f1f77bcf86cd799439014',
            onEnrollmentChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rút lớp'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Rút lớp'));
    await tester.pumpAndSettle();
    expect(api.withdrawnVersion, 3);
    expect(find.text('Lớp đã rút'), findsOneWidget);
  });
}
