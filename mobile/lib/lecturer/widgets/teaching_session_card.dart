import 'package:flutter/material.dart';

import '../models/lecturer_data.dart';
import '../utils/lecturer_dates.dart';
import 'lecturer_ui.dart';

class TeachingSessionCard extends StatelessWidget {
  final TeachingSession session;
  final VoidCallback onAttendance, onChange;
  const TeachingSessionCard({
    super.key,
    required this.session,
    required this.onAttendance,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final isCancelled = session.status == 'CANCELLED';
    final isCompleted = session.status == 'COMPLETED';
    final accentColor = isCancelled
        ? const Color(0xFFEF4444)
        : isCompleted
            ? const Color(0xFF10B981)
            : const Color(0xFF7047EB);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECE7F7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EEFF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: Color(0xFF7047EB),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            slotLabels[session.slot] ?? 'Chưa có slot',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF493A7D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isCancelled)
                  const StatusPill('Đã hủy', color: Color(0xFFE11D48))
                else if (isCompleted)
                  const StatusPill('Đã kết thúc', color: Color(0xFF059669))
                else
                  const StatusPill('Đã lên lịch', color: Color(0xFF059669)),
              ],
            ),
            const SizedBox(height: 14),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.courseCode.isEmpty
                              ? session.course
                              : '${session.courseCode} · ${session.course}',
                          style: const TextStyle(
                            fontSize: 16.5,
                            color: Color(0xFF1E1A3C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Lớp ${session.section}',
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: lecturerMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.meeting_room_outlined,
                  color: lecturerMuted,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Phòng ${session.room}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B4764),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F1FB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Slot ${session.slot}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5D5776),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onAttendance,
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: Text(
                    session.canRecordToday ? 'Điểm danh' : 'Xem danh sách',
                  ),
                ),
                if (session.canChange)
                  OutlinedButton.icon(
                    onPressed: onChange,
                    icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                    label: const Text('Đổi lịch / phòng'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
