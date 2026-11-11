import 'package:flutter/material.dart';

const statusLabels = {
  'PENDING': 'Chờ duyệt',
  'APPROVED': 'Đã duyệt',
  'REJECTED': 'Từ chối',
  'INVALIDATED': 'Mất hiệu lực',
  'CANCELLED': 'Đã hủy',
  'SCHEDULED': 'Đã xếp lịch',
  'COMPLETED': 'Đã kết thúc',
  'PRESENT': 'Có mặt',
  'ABSENT': 'Vắng mặt',
  'LATE': 'Đi muộn',
  'EXCUSED': 'Vắng có phép',
  'NOT_RECORDED': 'Chưa ghi nhận',
};

class LoadMessage extends StatelessWidget {
  const LoadMessage({super.key, required this.message, this.retry});
  final String message;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        if (retry != null)
          TextButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
      ],
    ),
  );
}

void showMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
