import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfap/main.dart';

void main() {
  testWidgets('Chặn đăng nhập khi thiếu email và mật khẩu', (tester) async {
    await tester.pumpWidget(const MyFapApp());
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pump();
    expect(find.text('Nhập email hợp lệ'), findsOneWidget);
    expect(find.text('Nhập mật khẩu'), findsOneWidget);
  });
}
