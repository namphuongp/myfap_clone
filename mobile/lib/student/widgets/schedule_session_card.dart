import 'package:flutter/material.dart';

import '../models/schedule_session.dart';
import '../utils/schedule_date.dart';

class ScheduleSessionCard extends StatelessWidget {
  const ScheduleSessionCard({super.key, required this.session});

  final ScheduleSession session;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (statusLabel, statusColor) = switch (session.status) {
      'CANCELLED' => ('Đã hủy', colors.error),
      'COMPLETED' => ('Đã hoàn thành', colors.primary),
      _ => ('Đã lên lịch', colors.tertiary),
    };

    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, size: 18, color: colors.primary),
                const SizedBox(width: 6),
                Text(
                  '${formatVietnamTime(session.startAt)} – ${formatVietnamTime(session.endAt)}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              session.course,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              session.sectionCode,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.meeting_room_outlined,
                  size: 17,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(child: Text('Phòng ${session.roomName}')),
                if (session.slotId != null) Text('Ca ${session.slotId}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
