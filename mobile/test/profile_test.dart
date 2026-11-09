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
  bool failLoad = false, conflict = false, cleared = false;
  int patches = 0, passwordChanges = 0;
  final List<int> versions = [];
  final List<String> paths = [];
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
    if (path == '/department/summary') {
      return {'sections': 2, 'sessions': 8, 'recorded_sessions': 3};
    }
    if (method == 'GET') {
      if (failLoad) throw ApiException('Không tải được hồ sơ');
      return Map<String, dynamic>.from(profile);
    }
    if (path == '/profile/password') {
      passwordChanges++;
      return {'message': 'OK'};
    }
    patches++;
    if (conflict) {
      throw ApiException('Dữ liệu đã thay đổi, hãy tải lại', statusCode: 409);
    }
    versions.add(body!['version'] as int);
    profile = {...profile, ...body, 'version': (body['version'] as int) + 1};
    return Map<String, dynamic>.from(profile);
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
        await tester.tap(find.text('Xem báo cáo bộ môn'));
        await tester.pumpAndSettle();
        expect(api.paths, contains('/department/summary'));
        expect(api.paths.any((path) => path.startsWith('/schedule')), isFalse);
        expect(find.textContaining('Số lớp: 2'), findsOneWidget);
      }
      await tester.tap(find.byTooltip('Hồ sơ cá nhân'));
      await tester.pumpAndSettle();
      expect(find.text('Hồ sơ cá nhân'), findsOneWidget);
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(api.paths, contains('/profile'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Hồ sơ của tôi'), findsOneWidget);
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
      expect(find.text('NP'), findsOneWidget);
      expect(find.text('demo@myfap.local'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(
        tester.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundImage,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await preview(tester, 'profile-$role');
    });
  }
  testWidgets(
    'Lưu thông tin liên hệ dùng version mới, không sửa trường định danh',
    (tester) async {
      final api = FakeProfileApi('STUDENT');
      await pumpProfile(tester, api);
      await tester.enterText(
        find.byKey(const Key('profile-phone')),
        '0912345678',
      );
      await tester.ensureVisible(find.text('Lưu thay đổi'));
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();
      expect(api.profile['phone'], '0912345678');
      expect(api.versions, [1]);
      expect(api.profile['role'], 'STUDENT');
      expect(find.text('Đã cập nhật hồ sơ'), findsOneWidget);
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();
      expect(api.versions, [1, 2]);
      await preview(tester, 'profile-saved-contact');
    },
  );
  testWidgets('Số điện thoại sai không gọi API lưu', (tester) async {
    final api = FakeProfileApi('LECTURER');
    await pumpProfile(tester, api);
    await tester.enterText(find.byKey(const Key('profile-phone')), 'abc');
    await tester.ensureVisible(find.text('Lưu thay đổi'));
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect(api.patches, 0);
    expect(find.text('Số điện thoại không hợp lệ'), findsOneWidget);
  });
  testWidgets('Lỗi tải có thử lại và conflict không tự ghi đè', (tester) async {
    final api = FakeProfileApi('HEAD')..failLoad = true;
    await pumpProfile(tester, api);
    expect(find.text('Thử lại'), findsOneWidget);
    api.failLoad = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    api.conflict = true;
    await tester.ensureVisible(find.text('Lưu thay đổi'));
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect(find.text('Dữ liệu đã thay đổi, hãy tải lại'), findsOneWidget);
    expect(api.profile['version'], 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Đổi mật khẩu kiểm tra nhập lại và yêu cầu đăng nhập lại', (
    tester,
  ) async {
    final api = FakeProfileApi('STAFF');
    var signedOut = false;
    await pumpProfile(tester, api, onSignedOut: () => signedOut = true);
    await tester.ensureVisible(find.text('Đổi mật khẩu'));
    await tester.tap(find.text('Đổi mật khẩu'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.at(0), 'Demo@12345678');
    await tester.enterText(fields.at(1), 'Changed@12345678');
    await tester.enterText(fields.at(2), 'NotMatching@12345678');
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(api.passwordChanges, 0);
    expect(find.text('Mật khẩu nhập lại không khớp'), findsOneWidget);
    await tester.enterText(fields.at(2), 'Changed@12345678');
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(api.passwordChanges, 1);
    expect(api.cleared, isTrue);
    expect(signedOut, isTrue);
  });
}
