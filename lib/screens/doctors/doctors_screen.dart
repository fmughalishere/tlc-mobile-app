import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../data/repository.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

/// The doctors a patient can be booked with.
///
/// The filtering is the server's job, not this screen's: `/api/doctors`
/// already drops the suspended and unapproved ones for a patient and strips
/// their contact details before sending anything. So this file shows what it
/// is given and does not try to decide who should be visible — a rule enforced
/// in two places is a rule that will disagree with itself.
///
/// `online` is likewise computed server-side from the doctor's heartbeat. A
/// doctor whose session ended without a clean goodbye stops reading as
/// available on its own, which is why there is no "available" switch anywhere.
class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key});

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  final _repo = Repository();

  @override
  void dispose() {
    _repo.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('doctors.title'))),
      body: AsyncView<List<Doctor>>(
        load: _repo.doctors,
        emptyWhen: (list) => list.isEmpty,
        emptyTitle: l10n.t('doctors.empty'),
        builder: (context, doctors, reload) {
          // Online first — that is the only ordering a patient cares about
          // when they are deciding whether to try a consultation now.
          final sorted = [...doctors]..sort((a, b) {
              if (a.online != b.online) return a.online ? -1 : 1;
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            itemCount: sorted.length,
            itemBuilder: (context, i) {
              final doctor = sorted[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Palette.line),
                    borderRadius: BorderRadius.circular(Palette.radiusCard),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Avatar(
                            initials: doctor.initials,
                            photoURL: doctor.photoURL,
                            size: 48,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doctor.displayName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Palette.ink,
                                  ),
                                ),
                                if (doctor.specialization != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    doctor.specialization!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Palette.inkSoft,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: doctor.online
                                            ? Palette.success
                                            : Palette.line,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      doctor.online
                                          ? l10n.t('doctors.online')
                                          : l10n.t('doctors.offline'),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: doctor.online
                                            ? Palette.success
                                            : Palette.inkSoft,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (doctor.bio != null && doctor.bio!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          doctor.bio!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
