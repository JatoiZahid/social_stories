import 'package:flutter/material.dart';

import '../api.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

String formatDateTime(DateTime d) =>
    '${formatDate(d)}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String statusLabel(String status) => switch (status) {
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      'withdrawn' => 'Taken back by the sender',
      _ => 'Waiting for review',
    };

IconData typeIcon(SubmissionType type) => switch (type) {
      SubmissionType.newStory => Icons.add_box_rounded,
      SubmissionType.editStory => Icons.edit_note_rounded,
      SubmissionType.editQuestions => Icons.quiz_rounded,
    };
