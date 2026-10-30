import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../models/models.dart';

const severityLabels = {
  'LOW': 'Low',
  'MEDIUM': 'Medium',
  'HIGH': 'High',
  'CRITICAL': 'Critical',
};
const severityColors = {
  'LOW': TL.kelp500,
  'MEDIUM': TL.buoy500,
  'HIGH': TL.coral500,
  'CRITICAL': TL.coral700,
};

/// (label, foreground, background) — status colours from semantic.css; APPROVED/ESCALATED
/// are renamed as in ReportStatusBadge.jsx.
(String, Color, Color) reportStatusStyle(String status) => switch (status) {
  'PENDING' => ('Pending', TL.buoy600, TL.buoy100),
  'VERIFYING' => ('Verifying', TL.sea600, TL.sea100),
  'VERIFIED' => ('Verified', TL.kelp600, TL.kelp100),
  'ESCALATED' => ('With government officer', TL.kelp600, TL.kelp100),
  'APPROVED' => ('Project', TL.kelp600, TL.kelp100),
  'CLEANED' => ('Cleaned', TL.kelp600, TL.kelp100),
  'REJECTED' => ('Rejected', TL.gray600, TL.gray100),
  _ => (status, TL.gray600, TL.gray100),
};

class ReportCard extends StatelessWidget {
  const ReportCard({super.key, required this.report, required this.onTap});
  final Report report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (label, fg, bg) = reportStatusStyle(report.status);
    final cover = AppConfig.mediaUrl(report.coverUrl);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(TL.radiusLg),
        boxShadow: TL.cardShadow,
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: cover == null
                  ? Container(
                      color: TL.sea100,
                      child: const Icon(
                        Icons.waves,
                        color: TL.sea600,
                        size: 40,
                      ),
                    )
                  : Image.network(
                      cover,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: TL.sea100,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: TL.sea600,
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        report.reference,
                        style: const TextStyle(
                          fontFamily: TL.fontMono,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: TL.textMuted,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: fg,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(report.title, style: text.titleMedium),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: TL.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(report.locationLine, style: text.bodySmall),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: severityColors[report.severity],
                      ),
                      const SizedBox(width: 6),
                      // Shrinks with an ellipsis on narrow phones instead of overflowing.
                      Expanded(
                        child: Text(
                          '${severityLabels[report.severity] ?? report.severity} severity',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(color: TL.textBody),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${report.trustPercentage}% trust',
                        style: const TextStyle(
                          fontFamily: TL.fontMono,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: TL.textStrong,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
