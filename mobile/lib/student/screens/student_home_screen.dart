import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/profile/repositories/profile_repository.dart';
import '../../core/profile/screens/profile_screen.dart';
import 'announcements_screen.dart';
import 'enrollment_screen.dart';
import 'requests_screen.dart';
import 'student_schedule_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({
    super.key,
    required this.user,
    required this.api,
    required this.onLoggedOut,
  });

  final Map<String, dynamic> user;
  final ApiClient api;
  final VoidCallback onLoggedOut;

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  static const _titles = [
    'Lịch học',
    'Đăng ký môn',
    'Đơn từ',
    'Thông báo học vụ',
  ];

  int _selectedIndex = 0;
  bool _loggingOut = false;

  void _signedOutFromProfile() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    widget.onLoggedOut();
  }

  Future<void> _openProfile() => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => ProfileScreen(
        repository: ProfileRepository(widget.api),
        onSignedOut: _signedOutFromProfile,
      ),
    ),
  );

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await widget.api.logout();
      if (mounted) widget.onLoggedOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_titles[_selectedIndex]),
      actions: [
        IconButton(
          tooltip: 'Hồ sơ cá nhân',
          onPressed: _loggingOut ? null : _openProfile,
          icon: const Icon(Icons.account_circle_outlined),
        ),
        IconButton(
          tooltip: 'Đăng xuất',
          onPressed: _loggingOut ? null : _logout,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: IndexedStack(
      index: _selectedIndex,
      children: [
        StudentScheduleScreen(api: widget.api),
        const EnrollmentScreen(),
        const RequestsScreen(),
        const AnnouncementsScreen(),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Lịch'),
        NavigationDestination(icon: Icon(Icons.school), label: 'Đăng ký'),
        NavigationDestination(icon: Icon(Icons.description), label: 'Đơn từ'),
        NavigationDestination(
          icon: Icon(Icons.notifications),
          label: 'Thông báo',
        ),
      ],
    ),
  );
}
