import 'package:flutter/material.dart';

import '../../head/screens/head_home_screen.dart';
import '../../lecturer/screens/lecturer_home_screen.dart';
import '../../staff/screens/staff_home_screen.dart';
import '../../student/screens/student_home_screen.dart';
import '../api/api_client.dart';

class RoleHomeRouter extends StatelessWidget {
  const RoleHomeRouter({
    super.key,
    required this.user,
    required this.api,
    required this.onLoggedOut,
  });

  final Map<String, dynamic> user;
  final ApiClient api;
  final VoidCallback onLoggedOut;

  @override
  // DN5: Backend trả role STUDENT thì mở trang chủ sinh viên.
  Widget build(BuildContext context) => switch (user['role']) {
    'STUDENT' => StudentHomeScreen(
      user: user,
      api: api,
      onLoggedOut: onLoggedOut,
    ),
    'LECTURER' => LecturerHomeScreen(
      user: user,
      api: api,
      onLoggedOut: onLoggedOut,
    ),
    'HEAD' => HeadHomeScreen(user: user, api: api, onLoggedOut: onLoggedOut),
    'STAFF' => StaffHomeScreen(user: user, api: api, onLoggedOut: onLoggedOut),
    _ => const Scaffold(body: Center(child: Text('Vai trò không được hỗ trợ'))),
  };
}
