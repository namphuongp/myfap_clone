import 'package:flutter/material.dart';

import '../repositories/lecturer_repository.dart';
import '../widgets/lecturer_widgets.dart';

class LecturerScheduleScreen extends StatelessWidget {
  const LecturerScheduleScreen({super.key, required this.repository});
  final LecturerRepository repository;
  @override
  Widget build(BuildContext context) => SessionBrowser(repository: repository);
}
