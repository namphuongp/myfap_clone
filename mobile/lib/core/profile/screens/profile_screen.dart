import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../repositories/profile_repository.dart';

const roleLabels = {
  'STUDENT': 'Sinh viên',
  'LECTURER': 'Giảng viên',
  'HEAD': 'Trưởng bộ môn',
  'STAFF': 'Cán bộ',
};
String initialsForName(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  return parts
      .skip(parts.length > 1 ? parts.length - 2 : 0)
      .map((part) => String.fromCharCode(part.runes.first))
      .join()
      .toUpperCase();
}

class ProfileScreen extends StatefulWidget {
  final ProfileRepository repository;
  final VoidCallback onSignedOut;
  const ProfileScreen({
    super.key,
    required this.repository,
    required this.onSignedOut,
  });
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  String? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await widget.repository.getProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        await widget.repository.clearSession();
        if (mounted) widget.onSignedOut();
      } else if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _dateLabel(String? value) {
    if (value == null) return 'Chưa cập nhật';
    final parts = value.split('-');
    return parts.length == 3 ? '${parts[2]}/${parts[1]}/${parts[0]}' : value;
  }

  Widget _info(String label, String? value, IconData icon) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(label),
    subtitle: SelectableText(
      value == null || value.trim().isEmpty ? 'Chưa cập nhật' : value,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final profile = _profile;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại hồ sơ',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            )
          : profile == null
          ? const Center(child: Text('Chưa có thông tin hồ sơ'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        color: colors.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 34,
                                backgroundColor: colors.primary,
                                foregroundColor: colors.onPrimary,
                                child: Text(
                                  initialsForName(profile.name),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                profile.name,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: colors.onPrimaryContainer,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Chip(
                                label: Text(
                                  roleLabels[profile.role] ?? profile.role,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Column(
                            children: [
                              _info(
                                'Mã tài khoản',
                                profile.userCode,
                                Icons.badge_outlined,
                              ),
                              _info('Email', profile.email, Icons.mail_outline),
                              _info(
                                'Bộ môn',
                                profile.departmentName,
                                Icons.school_outlined,
                              ),
                              if (profile.role == 'STUDENT')
                                _info(
                                  'Ngành học',
                                  profile.majorName,
                                  Icons.menu_book_outlined,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Thông tin liên hệ',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Column(
                            children: [
                              _info(
                                'Số điện thoại',
                                profile.phone,
                                Icons.phone_outlined,
                              ),
                              _info(
                                'Ngày sinh',
                                _dateLabel(profile.dateOfBirth),
                                Icons.cake_outlined,
                              ),
                              _info(
                                'Địa chỉ liên hệ',
                                profile.address,
                                Icons.location_on_outlined,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Thông tin hồ sơ do nhà trường quản lý.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
