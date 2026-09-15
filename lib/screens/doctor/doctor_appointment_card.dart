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
            // Two lines, not three columns.
            //
            // The old layout put the time, the details and the status pill in
            // one Row. On a phone that leaves the middle column whatever the
            // pill does not want — and a long status took so much that the
            // service name wrapped a character at a time down a strip four
            // letters wide.
            //
            // Now the pill shares the *title* line, where it is beside a short
            // patient name and has a natural stopping point, and the service
            // and mode get the full width of the card underneath.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 66,
                      child: Text(
                        a.hasSchedule ? Fmt.time(a.time) : '—',
                        // A clock time is Latin numerals in both languages,
                        // and must not be mirrored when the app is in Urdu.
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Palette.indigoDeep,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        a.patientName.isEmpty ? a.service : a.patientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Palette.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusPill(
                      status: a.status,
                      label: l10n.statusFor(a.status, staff: true),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Padding(
                  // Lined up under the patient name, so the eye follows one
                  // edge down the list instead of two.
                  padding: const EdgeInsetsDirectional.only(start: 66),
                  child: Text(
                    '${a.service} · ${_modeLabel(a.mode)}',
                    style: const TextStyle(fontSize: 12, height: 1.4, color: Palette.inkSoft),
                  ),
                ),
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
