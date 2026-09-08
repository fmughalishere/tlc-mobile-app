import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/formatting.dart';
import '../../core/palette.dart';
import '../../core/session.dart';
import '../../data/repository.dart';
import '../../i18n/strings.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../appointments/appointment_detail_screen.dart';

/// What a doctor or an admin sees when they sign in on the phone.
///
/// A doctor gets a real, useful screen: the appointments assigned to them,
/// which is the one thing worth having on a phone between patients. The full
/// doctor tools — prescriptions, calendar, chat — are the next stage.
///
/// An admin is sent to the website, deliberately. The admin panel is a
/// desk-and-keyboard job: approving doctors, editing the catalogue, reading
/// payment records. Squeezing it onto a phone would produce something nobody
/// would use for those tasks, and pretending otherwise wastes the effort.
class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  final _repo = Repository();

  @override
  void dispose() {
    _repo.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    final isAdmin = session.role == Role.admin;

    return Scaffold(
      appBar: AppBar(
        title: Text(session.name.isEmpty ? l10n.t('staff.title') : session.name),
        actions: [
          TextButton(
            onPressed: l10n.toggle,
            child: Text(l10n.isUrdu ? 'English' : 'اردو'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            // Confirmed, not immediate: this icon sits next to the language
            // toggle in the app bar, and a doctor between patients should not
            // be able to sign themselves out with one mis-tap.
            onPressed: () => _confirmSignOut(context, session),
          ),
        ],
      ),
      body: isAdmin
          ? _AdminNotice(l10nText: l10n.t('staff.adminSub'), open: l10n.t('staff.openWebsite'))
          : AsyncView<List<Appointment>>(
              load: () => _repo.appointments(limit: 100),
              emptyWhen: (list) => list.isEmpty,
              emptyTitle: l10n.t('appt.empty'),
              builder: (context, all, reload) {
                final today = Fmt.todayIso();
                final upcoming = all.where((a) => a.isUpcoming).toList()
                  ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
                final todays = upcoming.where((a) => a.date == today).toList();
                final later = upcoming.where((a) => a.date != today).toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    Text(
                      l10n.t('staff.doctorSub'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    SectionHeader(title: Fmt.dateLong(today)),
                    if (todays.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Palette.paperDim,
                          borderRadius: BorderRadius.circular(Palette.radiusCard),
                        ),
                        child: EmptyState(
                          icon: Icons.event_available_outlined,
                          title: l10n.t('common.nothingHere'),
                        ),
                      )
                    else
                      for (final a in todays)
                        _StaffRow(
                          appointment: a,
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => AppointmentDetailScreen(appointment: a),
                              ),
                            );
                            await reload();
                          },
                        ),
                    if (later.isNotEmpty) ...[
                      const SizedBox(height: 26),
                      SectionHeader(title: l10n.t('appt.upcoming')),
                      for (final a in later)
                        _StaffRow(
                          appointment: a,
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => AppointmentDetailScreen(appointment: a),
                              ),
                            );
                            await reload();
                          },
                        ),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

Future<void> _confirmSignOut(BuildContext context, Session session) async {
  final l10n = context.read<LocaleController>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.t('auth.signOut')),
      content: Text(l10n.t('profile.signOutConfirm')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.t('common.cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: Palette.crimsonDeep),
          child: Text(l10n.t('auth.signOut')),
        ),
      ],
    ),
  );
  if (confirmed == true) await session.signOut();
}

class _AdminNotice extends StatelessWidget {
  const _AdminNotice({required this.l10nText, required this.open});

  final String l10nText;
  final String open;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 70, 28, 28),
      children: [
        const Icon(Icons.admin_panel_settings_outlined, size: 44, color: Palette.inkSoft),
        const SizedBox(height: 18),
        Text(
          l10nText,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 26),
        FilledButton(
          onPressed: () => openUrl(context, '${AppConfig.apiBaseUrl}/admin/dashboard'),
          child: Text(open),
        ),
      ],
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({required this.appointment, required this.onTap});

  final Appointment appointment;
  final VoidCallback onTap;

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
              children: [
                SizedBox(
                  width: 68,
                  child: Text(
                    a.hasSchedule ? Fmt.time(a.time) : '—',
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
                        a.service,
                        style: const TextStyle(fontSize: 12, color: Palette.inkSoft),
                      ),
                    ],
                  ),
                ),
                StatusPill(status: a.status, label: l10n.status(a.status)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
