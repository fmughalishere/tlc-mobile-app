import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../core/palette.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

/// A compact row for the overview: time, patient, service, status.
///
/// Separate from the full card on the Appointments tab because they answer
/// different questions. This one answers "what is my day", so the time leads
/// and nothing is actionable. The full card answers "what do I do about this
/// one", and is mostly buttons.
class DoctorAppointmentRow extends StatelessWidget {
  const DoctorAppointmentRow({super.key, required this.appointment, this.onTap});

  final Appointment appointment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final a = appointment;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Palette.paper,
        borderRadius: BorderRadius.circular(Palette.radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Palette.radiusCard),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              border: Border.all(color: Palette.line),
              borderRadius: BorderRadius.circular(Palette.radiusCard),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 66,
                  child: Text(
                    a.hasSchedule ? Fmt.time(a.time) : '—',
                    // A clock time is Latin numerals in both languages, and
                    // must not be mirrored when the app is in Urdu.
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Palette.indigoDeep,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.patientName.isEmpty ? a.service : a.patientName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Palette.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${a.service} · ${_modeLabel(a.mode)}',
                        style: const TextStyle(fontSize: 12, color: Palette.inkSoft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusPill(status: a.status, label: l10n.status(a.status)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _modeLabel(String mode) {
  switch (mode) {
    case 'video':
      return 'Video';
    case 'audio':
      return 'Audio';
    case 'chat':
      return 'Chat';
    case 'in-person':
      return 'In person';
    default:
      return mode;
  }
}

IconData modeIcon(String mode) {
  switch (mode) {
    case 'video':
      return Icons.videocam_outlined;
    case 'audio':
      return Icons.call_outlined;
    case 'chat':
      return Icons.chat_bubble_outline_rounded;
    default:
      return Icons.local_hospital_outlined;
  }
}
