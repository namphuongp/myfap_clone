import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfap/core/api/api_client.dart';
import 'package:myfap/student/screens/student_home_screen.dart';
import 'package:myfap/student/utils/schedule_date.dart';

class FakeScheduleApi extends ApiClient {
  FakeScheduleApi();

  final List<String> paths = [];

  @override
  Future<dynamic> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    paths.add(path);
    if (path.startsWith('/schedule')) {
      final today = vietnamToday();
      final todayStr =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      return [
        {
          'course': 'Flutter Mobile',
          'section_code': 'SE20A.PR4938',
          'room_name': 'EE-301',
          'start_at': '${todayStr}T00:30:00Z', // 07:30 VN
          'end_at': '${todayStr}T02:30:00Z', // 09:30 VN
          'status': 'SCHEDULED',
          'slot_id': 1,
        },
        {
          'course': 'Cơ sở dữ liệu',
          'section_code': 'SE20A.DB1202',
          'room_name': 'EE-301',
          'start_at': '${todayStr}T05:00:00Z', // 12:00 VN
          'end_at': '${todayStr}T05:20:00Z', // 12:20 VN
          'status': 'SCHEDULED',
          'slot_id': 2,
        },
      ];
    }
    return [];
  }

  @override
  Future<void> logout() async {}
}

void main() {
  testWidgets('Hiển thị giao diện lịch học sinh viên chuẩn mẫu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final api = FakeScheduleApi();
    await tester.pumpWidget(
      MaterialApp(
        home: StudentHomeScreen(
          user: const {
            'id': '123',
            'role': 'STUDENT',
            'full_name': 'Sinh viên FPT',
          },
          api: api,
          onLoggedOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Kiểm tra Header
    expect(find.text('Lịch học'), findsWidgets);
    expect(find.text('Quản lý thời khóa biểu của bạn'), findsOneWidget);
    expect(find.byTooltip('Hồ sơ cá nhân'), findsOneWidget);
    expect(find.byTooltip('Đăng xuất'), findsOneWidget);

    // 2. Kiểm tra Segmented control: "Tuần học" và "Lịch học"
    expect(find.text('Tuần học'), findsOneWidget);
    expect(find.text('Lịch học'), findsWidgets);

    // 3. Kiểm tra điều hướng tuần: nút tuần trước, tuần sau
    expect(find.byTooltip('Tuần trước'), findsOneWidget);
    expect(find.byTooltip('Tuần sau'), findsOneWidget);

    // 4. Kiểm tra các thứ trong tuần
    expect(find.text('T2'), findsOneWidget);
    expect(find.text('T3'), findsOneWidget);
    expect(find.text('T4'), findsOneWidget);
    expect(find.text('T5'), findsOneWidget);
    expect(find.text('T6'), findsOneWidget);
    expect(find.text('T7'), findsOneWidget);
    expect(find.text('CN'), findsOneWidget);

    // 5. Kiểm tra Bottom navigation
    expect(find.text('Lịch'), findsOneWidget);
    expect(find.text('Đăng ký'), findsOneWidget);
    expect(find.text('Đơn từ'), findsOneWidget);
    expect(find.text('Thông báo'), findsOneWidget);

    // 6. Kiểm tra thông tin các môn học và chi tiết buổi học hiển thị ngay hôm nay
    expect(find.text('Flutter Mobile'), findsOneWidget);
    expect(find.text('SE20A.PR4938'), findsOneWidget);
    expect(find.text('Cơ sở dữ liệu'), findsOneWidget);
    expect(find.text('SE20A.DB1202'), findsOneWidget);
    expect(find.text('Phòng EE-301'), findsNWidgets(2));
    expect(find.text('Ca 1'), findsOneWidget);
    expect(find.text('Ca 2'), findsOneWidget);
    expect(find.text('Đã lên lịch'), findsNWidgets(2));
    expect(find.text('2 buổi'), findsOneWidget);
  });
}
