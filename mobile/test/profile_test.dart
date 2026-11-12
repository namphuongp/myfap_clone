import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfap/core/api/api_client.dart';
import 'package:myfap/core/navigation/role_home_router.dart';
import 'package:myfap/core/profile/repositories/profile_repository.dart';
import 'package:myfap/core/profile/screens/profile_screen.dart';

class FakeProfileApi extends ApiClient {
  Map<String, dynamic> profile;
  bool failLoad = false, cleared = false;
  final List<String> paths = [];
  final List<String> methods = [];
  bool expired = false;
  FakeProfileApi(String role)
    : profile = {
        'id': '507f1f77bcf86cd799439011',
        'version': 1,
        'user_code': 'DEMO-$role',
        'name': 'Nguyễn Nam Phương',
        'email': 'demo@myfap.local',
        'role': role,
        'phone': '0901234567',
        'address': 'Thành phố Hồ Chí Minh',
        'date_of_birth': '2000-01-01',
        'department': {'name': 'Kỹ thuật phần mềm'},
        'major': role == 'STUDENT' ? {'name': 'Kỹ thuật phần mềm'} : null,
      };
  @override
  Future<dynamic> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    paths.add(path);
    methods.add(method);
    if (path == '/head/options') {
      return {
        'courses': <dynamic>[],
        'lecturers': <dynamic>[],
        'semesters': <dynamic>[],
        'majors': <dynamic>[],
      };
    }
    if (path.startsWith('/reports/attendance')) return {'items': <dynamic>[]};
    if (path.startsWith('/reports/requests')) {
      return {'leave_requests': <dynamic>[], 'change_requests': <dynamic>[]};
    }
    if (path == '/department/summary') {
      return {'sections': 2, 'sessions': 8, 'recorded_sessions': 3};
    }
    if (method == 'GET') {
      if (expired) throw ApiException('Phiên đã hết hạn', statusCode: 401);
      if (failLoad) throw ApiException('Không tải được hồ sơ');
      return Map<String, dynamic>.from(profile);
    }
    throw StateError('Màn hồ sơ chỉ được gọi GET');
  }

  @override
  Future<void> clearLocalSession() async {
    cleared = true;
  }
}

void main() {
  for (final role in ['STUDENT', 'LECTURER', 'HEAD', 'STAFF']) {
    testWidgets('Điều hướng từ trang chủ $role tới profile dùng chung', (
      tester,
    ) async {
      final api = FakeProfileApi(role);
      addTearDown(api.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: RoleHomeRouter(user: api.profile, api: api, onLoggedOut: () {}),
        ),
      );
      if (role == 'HEAD') {
        await tester.tap(find.text('Báo cáo bộ môn'));
        await tester.pumpAndSettle();
        expect(api.paths, contains('/department/summary'));
        expect(api.paths.any((path) => path.startsWith('/schedule')), isFalse);
        expect(find.textContaining('Số lớp: 2'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Hồ sơ cá nhân'));
      await tester.pumpAndSettle();
      expect(find.text('Hồ sơ cá nhân'), findsOneWidget);
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(api.paths, contains('/profile'));
      await tester.pageBack();
      await tester.pumpAndSettle();

      if (role == 'STUDENT' || role == 'LECTURER') {
        expect(find.byTooltip('Hồ sơ cá nhân'), findsOneWidget);
      } else {
        expect(find.text('Hồ sơ của tôi'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  setUpAll(() async {
    final fontRoot = Platform.environment['PROFILE_FONT_ROOT'];
    if (fontRoot != null) {
      final loader = FontLoader('Roboto');
      loader.addFont(
        Future.value(
          ByteData.sublistView(
            await File('$fontRoot/Roboto-Regular.ttf').readAsBytes(),
          ),
        ),
      );
      await loader.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(
        Future.value(
          ByteData.sublistView(
            await File('$fontRoot/MaterialIcons-Regular.otf').readAsBytes(),
          ),
        ),
      );
      await icons.load();
    }
  });
  Future<void> pumpProfile(
    WidgetTester tester,
    FakeProfileApi api, {
    VoidCallback? onSignedOut,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      api.dispose();
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('preview'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            fontFamily: 'Roboto',
            colorSchemeSeed: Colors.deepOrange,
            useMaterial3: true,
          ),
          home: ProfileScreen(
            repository: ProfileRepository(api),
            onSignedOut: onSignedOut ?? () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> preview(WidgetTester tester, String name) async {
    final directory = Platform.environment['PROFILE_PREVIEW_DIR'];
    if (directory == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File('$directory/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final role in ['STUDENT', 'LECTURER', 'HEAD', 'STAFF']) {
    testWidgets('Profile $role có avatar chữ và đúng thông tin đọc', (
      tester,
    ) async {
      final api = FakeProfileApi(role);
      await pumpProfile(tester, api);
      expect(find.text(roleLabels[role]!), findsOneWidget);
      expect(find.text('N'), findsOneWidget);
      expect(find.text('demo@myfap.local'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Lưu thay đổi'), findsNothing);
      expect(find.text('Đổi mật khẩu'), findsNothing);
      expect(find.text('Thông tin liên hệ'), findsNothing);
      expect(find.text('Bộ môn'), findsNothing);
      expect(find.text('0901234567'), findsNothing);
      expect(find.text('Ngày sinh'), findsNothing);
      expect(find.text('Địa chỉ liên hệ'), findsNothing);
      expect(find.text('Mã tài khoản'), findsOneWidget);
      await tester.tap(find.byTooltip('Tải lại hồ sơ'));
      await tester.pumpAndSettle();
      expect(api.methods.every((method) => method == 'GET'), isTrue);
      expect(
        tester.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundImage,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await preview(tester, 'profile-$role');
    });
  }
  testWidgets('Hồ sơ lỗi có thử lại', (tester) async {
    final api = FakeProfileApi('HEAD')..failLoad = true;
    api.profile['phone'] = null;
    await pumpProfile(tester, api);
    expect(find.text('Thử lại'), findsOneWidget);
    api.failLoad = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('DEMO-HEAD'), findsOneWidget);
    expect(api.methods.every((method) => method == 'GET'), isTrue);
  });
  testWidgets('Hồ sơ hết phiên xóa phiên và quay lại đăng nhập', (
    tester,
  ) async {
    final api = FakeProfileApi('STAFF')..expired = true;
    var signedOut = false;
    await pumpProfile(tester, api, onSignedOut: () => signedOut = true);
    expect(api.cleared, isTrue);
    expect(signedOut, isTrue);
    expect(api.methods.every((method) => method == 'GET'), isTrue);
  });
}
