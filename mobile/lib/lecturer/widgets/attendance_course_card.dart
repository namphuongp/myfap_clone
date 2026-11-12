import 'package:flutter/material.dart';

import '../models/teaching_course.dart';
import 'lecturer_ui.dart';

class AttendanceCourseCard extends StatelessWidget {
  final TeachingCourse course;
  final VoidCallback onTap;
  const AttendanceCourseCard({
    super.key,
    required this.course,
    required this.onTap,
  });
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
                  child: Text(
                    course.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: lecturerNavyDark,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 20, color: lecturerMuted),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${course.classes.length} lớp phụ trách · ${course.sessions} buổi học',
              style: const TextStyle(color: lecturerMuted),
            ),
            const SizedBox(height: 12),
            StatusPill(
              'Đã điểm danh ${course.recorded}/${course.sessions} buổi',
              color: lecturerGreen,
            ),
          ],
        ),
      ),
    ),
  );
}
