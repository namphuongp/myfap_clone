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

String firstInitialForName(String name) {
  final value = name.trim();
  return value.isEmpty
      ? '?'
      : String.fromCharCode(value.runes.first).toUpperCase();
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

  Widget _infoItem({
    required String label,
    required String? value,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    bool isLast = false,
  }) {
    final displayValue = (value == null || value.trim().isEmpty)
        ? 'Chưa cập nhật'
        : value;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8C8CA1),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    SelectableText(
                      displayValue,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF1E1E2D),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFF1F1F6),
            indent: 72,
            endIndent: 16,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF7047EB);
    final profile = _profile;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          'Hồ sơ cá nhân',
          style: TextStyle(
            color: Color(0xFF1E1E2D),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại hồ sơ',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFECEB),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFE11D48),
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF1E1E2D),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _load,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : profile == null
          ? const Center(
              child: Text(
                'Chưa có thông tin hồ sơ',
                style: TextStyle(color: Color(0xFF8C8CA1)),
              ),
            )
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Thẻ Avatar & Họ tên
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 24,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.06),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 42,
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  child: Text(
                                    firstInitialForName(profile.name),
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              profile.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF1E1E2D),
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3EEFF),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFDDD2FE),
                                ),
                              ),
                              child: Text(
                                roleLabels[profile.role] ?? profile.role,
                                style: const TextStyle(
                                  color: primaryColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 2. Thẻ Thông tin tài khoản
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _infoItem(
                              label: 'Mã tài khoản',
                              value: profile.userCode,
                              icon: Icons.badge_outlined,
                              iconColor: const Color(0xFF7047EB),
                              iconBg: const Color(0xFFF3EEFF),
                            ),
                            _infoItem(
                              label: 'Email',
                              value: profile.email,
                              icon: Icons.mail_outline_rounded,
                              iconColor: const Color(0xFF0284C7),
                              iconBg: const Color(0xFFE0F2FE),
                              isLast: profile.role != 'STUDENT',
                            ),
                            if (profile.role == 'STUDENT')
                              _infoItem(
                                label: 'Ngành học',
                                value: profile.majorName,
                                icon: Icons.school_outlined,
                                iconColor: const Color(0xFF059669),
                                iconBg: const Color(0xFFD1FAE5),
                                isLast: true,
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 3. Thông báo chú thích
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F2F9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: Color(0xFF8C8CA1),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Thông tin hồ sơ do nhà trường quản lý.',
                                style: TextStyle(
                                  color: const Color(0xFF8C8CA1)
                                      .withValues(alpha: 0.9),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
