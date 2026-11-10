import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/academic/academic_widgets.dart';
import '../../core/profile/repositories/profile_repository.dart';
import '../../core/profile/screens/profile_screen.dart';
import '../repositories/head_repository.dart';
import 'head_report_screen.dart';
import 'head_courses_screen.dart';
import 'head_assignments_screen.dart';
import 'head_room_screen.dart';

class HeadHomeScreen extends StatefulWidget {
  const HeadHomeScreen({
    super.key,
    required this.user,
    required this.api,
    required this.onLoggedOut,
  });
  final Map<String, dynamic> user;
  final ApiClient api;
  final VoidCallback onLoggedOut;
  @override
  State<HeadHomeScreen> createState() => _HeadHomeScreenState();
}

class _HeadHomeScreenState extends State<HeadHomeScreen> {
  late final _repo = HeadRepository(widget.api);
  int _index = 0;
  bool _busy = false;
  void _signedOut() {
    Navigator.of(context).popUntil((r) => r.isFirst);
    widget.onLoggedOut();
  }

  Future<void> _profile() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ProfileScreen(
        repository: ProfileRepository(widget.api),
        onSignedOut: _signedOut,
      ),
    ),
  );
  Future<void> _logout() async {
    setState(() => _busy = true);
    try {
      await widget.api.logout();
      if (mounted) _signedOut();
    } catch (e) {
      if (mounted) showMessage(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        const [
          'Báo cáo bộ môn',
          'Quản lý môn học',
          'Phân công giảng dạy',
          'Đơn chuyển phòng',
        ][_index],
      ),
      actions: [
        IconButton(
          tooltip: 'Hồ sơ cá nhân',
          onPressed: _busy ? null : _profile,
          icon: const Icon(Icons.account_circle_outlined),
        ),
        IconButton(
          tooltip: 'Đăng xuất',
          onPressed: _busy ? null : _logout,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: Column(
      children: [
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.business)),
          title: Text(widget.user['name']?.toString() ?? 'Trưởng bộ môn'),
          subtitle: const Text('Trưởng bộ môn'),
          trailing: TextButton(
            onPressed: _profile,
            child: const Text('Hồ sơ của tôi'),
          ),
        ),
        Expanded(
          child: switch (_index) {
            0 => HeadReportScreen(repository: _repo),
            1 => HeadCoursesScreen(repository: _repo),
            2 => HeadAssignmentsScreen(repository: _repo),
            _ => HeadRoomScreen(repository: _repo),
          },
        ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (v) => setState(() => _index = v),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Báo cáo'),
        NavigationDestination(icon: Icon(Icons.menu_book), label: 'Môn học'),
        NavigationDestination(icon: Icon(Icons.groups), label: 'Phân công'),
        NavigationDestination(
          icon: Icon(Icons.meeting_room),
          label: 'Chuyển phòng',
        ),
      ],
    ),
  );
}
