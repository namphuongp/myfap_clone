import 'package:flutter/material.dart';

import '../widgets/lecturer_ui.dart';

class AttendanceChoiceRow extends StatelessWidget {
  final String studentId, status;
  final String? note;
  final bool enabled;
  final ValueChanged<String> onChanged;
  const AttendanceChoiceRow({
    super.key,
    required this.studentId,
    required this.status,
    required this.note,
    required this.enabled,
    required this.onChanged,
  });

  String get _noteText {
    final parts = <String>[];
    if (note != null && note!.trim().isNotEmpty) {
      parts.add(note == 'Nghỉ có phép' ? 'Đã duyệt đơn nghỉ' : note!);
    }
    // Giữ nguyên trạng thái cũ cho đến khi giảng viên chủ động chọn lại.
    if (status == 'LATE') parts.add('Trạng thái cũ: Đi muộn');
    if (status == 'EXCUSED') parts.add('Trạng thái cũ: Vắng có phép');
    return parts.isEmpty ? 'Không có ghi chú' : parts.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final radios = RadioGroup<String>(
      groupValue: status == 'ABSENT' || status == 'PRESENT' ? status : null,
      onChanged: (value) {
        if (enabled && value != null) onChanged(value);
      },
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final choice in const {
            'ABSENT': 'Absent',
            'PRESENT': 'Present',
          }.entries)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Radio<String>(
                  key: ValueKey('attendance-$studentId-${choice.key}'),
                  value: choice.key,
                  enabled: enabled,
                ),
                GestureDetector(
                  onTap: enabled ? () => onChanged(choice.key) : null,
                  child: Text(
                    choice.value,
                    style: TextStyle(
                      fontSize: 13,
                      color: enabled ? lecturerNavy : lecturerMuted,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
    final noteBox = Container(
      key: ValueKey('attendance-note-$studentId'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: lecturerBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDFE4EB)),
      ),
      child: Text(
        'Ghi chú: $_noteText',
        style: TextStyle(
          fontSize: 12,
          color: note == null ? lecturerMuted : lecturerGreen,
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 500
          ? Row(
              children: [
                radios,
                const SizedBox(width: 16),
                Expanded(child: noteBox),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [radios, const SizedBox(height: 6), noteBox],
            ),
    );
  }
}
