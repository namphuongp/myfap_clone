import 'package:flutter/material.dart';

import '../models/schedule_session.dart';
import '../utils/schedule_date.dart';

class ScheduleSessionCard extends StatelessWidget {
  const ScheduleSessionCard({
    super.key,
    required this.session,
    this.accentColor,
    this.onTap,
  });

  final ScheduleSession session;
  final Color? accentColor;
  final VoidCallback? onTap;

  static Color pickAccentColor(String course, [int index = 0]) {
    final lower = course.toLowerCase();
    if (lower.contains('flutter')) {
      return const Color(0xFF8B5CF6); // Purple like screenshot
    }
    if (lower.contains('dữ liệu') ||
        lower.contains('data') ||
        lower.contains('db')) {
      return const Color(0xFF0EA5E9); // Sky blue like screenshot
    }
    const palette = [
      Color(0xFF8B5CF6),
      Color(0xFF0EA5E9),
      Color(0xFFF59E0B),
      Color(0xFF10B981),
      Color(0xFFEC4899),
    ];
    return palette[index % palette.length];
  }

  void _showDetailSheet(BuildContext context) {
    final (attLabel, attColor, attBg, attIcon) = switch (session) {
      _ when session.status == 'CANCELLED' => (
        'Buổi học đã bị hủy',
        const Color(0xFFDC2626),
        const Color(0xFFFEE2E2),
        Icons.cancel_outlined,
      ),
      _
          when session.attendanceSaved &&
              session.myAttendance?.status == 'PRESENT' =>
        (
          'Có mặt',
          const Color(0xFF16A34A),
          const Color(0xFFE8F7EE),
          Icons.check_circle_rounded,
        ),
      _
          when session.attendanceSaved &&
              session.myAttendance?.status == 'ABSENT' =>
        (
          'Vắng mặt',
          const Color(0xFFDC2626),
          const Color(0xFFFEE2E2),
          Icons.cancel_rounded,
        ),
      _
          when session.attendanceSaved &&
              session.myAttendance?.status == 'LATE' =>
        (
          'Đi muộn',
          const Color(0xFFD97706),
          const Color(0xFFFEF3C7),
          Icons.warning_amber_rounded,
        ),
      _
          when session.attendanceSaved &&
              session.myAttendance?.status == 'EXCUSED' =>
        (
          'Vắng có phép',
          const Color(0xFF7047EB),
          const Color(0xFFEDE8FE),
          Icons.event_available_rounded,
        ),
      _ when session.attendanceSaved => (
        'Đã điểm danh',
        const Color(0xFF16A34A),
        const Color(0xFFE8F7EE),
        Icons.check_circle_outline_rounded,
      ),
      _ => (
        'Chưa điểm danh',
        const Color(0xFF6B6680),
        const Color(0xFFF3F2F7),
        Icons.hourglass_top_rounded,
      ),
    };

    final day = session.day;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B64F6), Color(0xFF6B40E8)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.course,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1A3C),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          session.sectionCode,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF757288),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Khung hiển thị tình trạng điểm danh
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: attBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: attColor.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tình trạng điểm danh của bạn',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B6680),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(attIcon, color: attColor, size: 24),
                        const SizedBox(width: 10),
                        Text(
                          attLabel,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: attColor,
                          ),
                        ),
                      ],
                    ),
                    if (session.myAttendance?.note?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Ghi chú: ${session.myAttendance!.note}',
                        style: TextStyle(fontSize: 13, color: attColor),
                      ),
                    ],
                    if (!session.attendanceSaved &&
                        session.status != 'CANCELLED') ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Giảng viên sẽ điểm danh trong hoặc sau giờ học.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF757288),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Chi tiết thời gian, phòng học
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEDE9F7)),
                ),
                child: Column(
                  children: [
                    _infoRow(
                      Icons.calendar_today_outlined,
                      'Ngày học',
                      '${fullWeekdays[day.weekday - 1]}, ${day.day}/${day.month}/${day.year}',
                    ),
                    const Divider(height: 20, color: Color(0xFFF3F2F7)),
                    _infoRow(
                      Icons.access_time_rounded,
                      'Thời gian',
                      'Ca ${session.slotId ?? 1} (${formatVietnamTime(session.startAt)} – ${formatVietnamTime(session.endAt)})',
                    ),
                    const Divider(height: 20, color: Color(0xFFF3F2F7)),
                    _infoRow(
                      Icons.meeting_room_outlined,
                      'Phòng học',
                      'Phòng ${session.roomName}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7047EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Đóng'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF7047EB)),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF757288)),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E1A3C),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor, statusBg, statusIcon) = switch (session) {
      _ when session.status == 'CANCELLED' => (
        'Đã hủy',
        const Color(0xFFDC2626),
        const Color(0xFFFEE2E2),
        Icons.cancel_outlined,
      ),
      _
          when session.attendanceSaved &&
              session.myAttendance?.status == 'PRESENT' =>
        (
          'Có mặt',
          const Color(0xFF16A34A),
          const Color(0xFFE8F7EE),
          Icons.check_circle_rounded,
        ),
      _
          when session.attendanceSaved &&
              session.myAttendance?.status == 'ABSENT' =>
        (
          'Vắng mặt',
          const Color(0xFFDC2626),
          const Color(0xFFFEE2E2),
          Icons.cancel_rounded,
        ),
      _
          when session.attendanceSaved &&
              session.myAttendance?.status == 'LATE' =>
        (
          'Đi muộn',
          const Color(0xFFD97706),
          const Color(0xFFFEF3C7),
          Icons.warning_amber_rounded,
        ),
      _
          when session.attendanceSaved &&
              session.myAttendance?.status == 'EXCUSED' =>
        (
          'Có phép',
          const Color(0xFF7047EB),
          const Color(0xFFEDE8FE),
          Icons.event_available_rounded,
        ),
      _ when session.attendanceSaved => (
        'Đã điểm danh',
        const Color(0xFF16A34A),
        const Color(0xFFE8F7EE),
        Icons.check_circle_outline_rounded,
      ),
      _ when session.status == 'COMPLETED' => (
        'Đã hoàn thành',
        const Color(0xFF7047EB),
        const Color(0xFFEDE8FE),
        Icons.task_alt_rounded,
      ),
      _ => (
        'Đã lên lịch',
        const Color(0xFF16A34A),
        const Color(0xFFE8F7EE),
        Icons.check_circle_outline_rounded,
      ),
    };

    final barColor = accentColor ?? pickAccentColor(session.course);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDE9F7), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap ?? () => _showDetailSheet(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Time badge + Status / Attendance badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1EEFD),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 15,
                            color: Color(0xFF5B34DB),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${formatVietnamTime(session.startAt)} – ${formatVietnamTime(session.endAt)}',
                            style: const TextStyle(
                              color: Color(0xFF5027D4),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 15, color: statusColor),
                          const SizedBox(width: 5),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Row 2: Accent bar + Course title + Section code
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.course,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E1A3C),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            session.sectionCode,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF757288),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Row 3: Room name + Slot
                Row(
                  children: [
                    const Icon(
                      Icons.meeting_room_outlined,
                      size: 18,
                      color: Color(0xFF5D5A72),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Phòng ${session.roomName}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF383450),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (session.slotId != null)
                      Text(
                        'Ca ${session.slotId}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF5D5A72),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
