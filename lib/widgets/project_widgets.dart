import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'common.dart';

(String, Color, Color) projectStatusStyle(String s) => switch (s) {
  'PLANNED' => ('Planned', TL.buoy600, TL.buoy100),
  'ACTIVE' => ('Active', TL.sea600, TL.sea100),
  'COMPLETED' => ('Completed', TL.kelp600, TL.kelp100),
  _ => (s, TL.gray600, TL.gray100),
};

class ProjectStatusPill extends StatelessWidget {
  const ProjectStatusPill(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = projectStatusStyle(status);
    return StatusPill(label, fg: fg, bg: bg);
  }
}
