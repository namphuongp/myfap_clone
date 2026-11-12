import 'package:flutter/material.dart';

import '../models/lecturer_data.dart';
import 'lecturer_ui.dart';

class AttendanceStatusPill extends StatelessWidget {
  final TeachingSession session;
  const AttendanceStatusPill({super.key, required this.session});
  @override
  Widget build(BuildContext context) {
    final (label, color) = session.attendanceSaved
        ? ('Đã điểm danh', lecturerGreen)
        : session.start.isAfter(DateTime.now())
        ? ('Not yet', lecturerMuted)
        : ('Chưa điểm danh', lecturerOrange);
    return StatusPill(label, color: color);
  }
}
