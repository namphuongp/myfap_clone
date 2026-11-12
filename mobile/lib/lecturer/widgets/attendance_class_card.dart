import 'package:flutter/material.dart';

import '../models/teaching_class.dart';
import '../utils/lecturer_dates.dart';
import 'lecturer_ui.dart';

class AttendanceClassCard extends StatelessWidget {
  final TeachingClass section;
  final VoidCallback? onTap;
  const AttendanceClassCard({super.key, required this.section, this.onTap});
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          section.courseCode,
                          section.course,
                        ].where((s) => s.isNotEmpty).join(' · '),
                        maxLines: onTap == null ? null : 3,
                        overflow: onTap == null
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: lecturerNavyDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Lớp ${section.code}',
                        style: const TextStyle(color: lecturerMuted),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.chevron_right,
                      color: lecturerMuted,
                      size: 20,
                    ),
                  ),
              ],
            ),
            if (section.sessions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '${dateLabel(section.sessions.first.day)} – ${dateLabel(section.sessions.last.day)}',
                style: const TextStyle(fontSize: 13, color: lecturerMuted),
              ),
            ],
            const SizedBox(height: 12),
            StatusPill(
              'Đã điểm danh ${section.recorded}/${section.sessions.length} buổi',
              color: lecturerGreen,
            ),
            if (onTap == null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusPill(
                    'Chưa điểm danh ${section.pending}',
                    color: lecturerOrange,
                  ),
                  StatusPill('Not yet ${section.future}', color: lecturerMuted),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
