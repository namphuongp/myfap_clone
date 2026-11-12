import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfap/core/api/api_client.dart';
import 'package:myfap/core/widgets/role_layout.dart';
import 'package:myfap/head/screens/head_home_screen.dart';
import 'package:myfap/lecturer/screens/lecturer_home_screen.dart';
import 'package:myfap/staff/screens/staff_home_screen.dart';

void main() {
  for (final width in [320.0, 1200.0]) {
    for (final role in ['LECTURER', 'HEAD', 'STAFF']) {
      testWidgets('$role layout ở ${width}px với chữ lớn', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = ApiClient();
        addTearDown(api.dispose);
        final user = {'name': 'Nguyễn Văn Kiểm Thử', 'role': role};
        final screen = switch (role) {
          'LECTURER' => LecturerHomeScreen(
            user: user,
            api: api,
            onLoggedOut: () {},
          ),
          'HEAD' => HeadHomeScreen(user: user, api: api, onLoggedOut: () {}),
          _ => StaffHomeScreen(user: user, api: api, onLoggedOut: () {}),
        };
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: screen,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(RoleHomeHeader), findsOneWidget);
        expect(find.byTooltip('Hồ sơ cá nhân'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView).first, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
