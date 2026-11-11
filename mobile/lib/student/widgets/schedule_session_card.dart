import 'package:flutter/material.dart';

import '../models/schedule_session.dart';
import '../utils/schedule_date.dart';

class ScheduleSessionCard extends StatelessWidget {
  const ScheduleSessionCard({
    super.key,
    required this.session,
    this.accentColor,
  });

  final ScheduleSession session;
  final Color? accentColor;

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

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor, statusBg) = switch (session.status) {
      'CANCELLED' => (
        'Đã hủy',
        const Color(0xFFDC2626),
        const Color(0xFFFEE2E2),
      ),
      'COMPLETED' => (
        'Đã hoàn thành',
        const Color(0xFF7047EB),
        const Color(0xFFEDE8FE),
      ),
      _ => ('Đã lên lịch', const Color(0xFF16A34A), const Color(0xFFE8F7EE)),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Time badge + Status badge
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
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 15,
                      color: statusColor,
                    ),
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
    );
  }
}
