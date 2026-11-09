import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/schedule_home_screen.dart';

class LecturerHomeScreen extends StatelessWidget {
  const LecturerHomeScreen({
    super.key,
    required this.user,
    required this.api,
    required this.onLoggedOut,
  });

  final Map<String, dynamic> user;
  final ApiClient api;
  final VoidCallback onLoggedOut;

  @override
  Widget build(BuildContext context) =>
      ScheduleHomeScreen(user: user, api: api, onLoggedOut: onLoggedOut);
}
