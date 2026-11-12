import 'package:flutter/material.dart';

import '../models/lecturer_data.dart';
import '../utils/lecturer_dates.dart';
import 'lecturer_ui.dart';
import 'attendance_status_pill.dart';

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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusPill(
                  'Slot ${session.slot}',
                  color: const Color(0xFF9B5300),
                ),
                StatusPill(slotLabels[session.slot] ?? 'Chưa có slot'),
                AttendanceStatusPill(session: session),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              session.courseCode.isEmpty
                  ? session.course
                  : '${session.courseCode} · ${session.course}',
              style: const TextStyle(
                fontSize: 17,
                color: lecturerNavy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Lớp ${session.section}',
              style: const TextStyle(color: lecturerMuted),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: lecturerBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.meeting_room_outlined,
                    color: lecturerMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Phòng ${session.room}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: lecturerNavy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onAttendance,
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: Text(
                    !session.canRecordToday
                        ? 'Xem danh sách'
                        : session.attendanceSaved
                        ? 'Sửa điểm danh'
                        : 'Điểm danh',
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
