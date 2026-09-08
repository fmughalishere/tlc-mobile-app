import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/formatting.dart';
import '../../core/palette.dart';
import '../../core/session.dart';
import '../../data/app_data.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../appointments/appointment_detail_screen.dart';
import '../booking/book_screen.dart';
import '../doctors/doctors_screen.dart';
import '../services/service_detail_screen.dart';

/// The first screen a signed-in patient sees.
///
/// It answers three questions, in the order a patient actually has them:
/// *when am I next seen*, *what can I book*, and *how do I reach a human*.
/// Everything else is a tab away.
///
/// It reads from [AppData], which started fetching before this screen existed,
/// so on a normal launch it draws with content rather than with a spinner.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.onGoToTab});

  final void Function(int index) onGoToTab;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    final data = context.watch<AppData>();
    final name = Fmt.firstName(session.name);

    final upcoming = data.upcoming;
    final next = upcoming.isEmpty ? null : upcoming.first;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo-icon.png',
              height: 28,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.t('app.name'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: l10n.toggle,
            child: Text(l10n.isUrdu ? 'English' : 'اردو'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            data.refreshAppointments(),
            data.refreshServices(),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          children: [
            Text(
              name.isEmpty
                  ? l10n.t('home.greeting')
                  : '${l10n.t('home.greeting')}, $name',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.t('home.subtitle'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),

            _BookCard(
              title: l10n.t('home.book'),
              subtitle: l10n.t('home.bookSub'),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const BookScreen()),
                );
                await data.refreshAppointments();
              },
            ),

            const SizedBox(height: 26),
            SectionHeader(
              title: l10n.t('home.upcoming'),
              actionLabel: upcoming.length > 1 ? l10n.t('common.seeAll') : null,
              onAction: upcoming.length > 1 ? () => onGoToTab(2) : null,
            ),

            if (!data.appointmentsLoaded && data.appointmentsLoading)
              const _SkeletonCard()
            else if (next == null)
              _SoftCard(
                child: EmptyState(
                  icon: Icons.event_available_outlined,
                  title: l10n.t('home.noUpcoming'),
                  message: l10n.t('home.noUpcomingSub'),
                ),
              )
            else
              AppointmentCard(
                appointment: next,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AppointmentDetailScreen(appointment: next),
                    ),
                  );
                  await data.refreshAppointments();
                },
              ),

            const SizedBox(height: 26),
            SectionHeader(
              title: l10n.t('home.ourServices'),
              actionLabel: l10n.t('common.seeAll'),
              onAction: () => onGoToTab(1),
            ),
            if (!data.servicesLoaded && data.servicesLoading)
              const _SkeletonRow()
            else if (data.services.isEmpty)
              _SoftCard(
                child: EmptyState(
                  icon: Icons.medical_services_outlined,
                  title: l10n.t('services.empty'),
                ),
              )
            else
              SizedBox(
                height: 134,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: data.services.length > 8 ? 8 : data.services.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => _ServiceChipCard(
                    service: data.services[i],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ServiceDetailScreen(service: data.services[i]),
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 26),
            SectionHeader(title: l10n.t('home.needHelp')),
            _WideTile(
              icon: Icons.groups_2_outlined,
              title: l10n.t('home.ourDoctors'),
              subtitle: l10n.t('home.ourDoctorsSub'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const DoctorsScreen()),
              ),
            ),
            _WideTile(
              icon: Icons.call_rounded,
              title: l10n.t('common.callClinic'),
              subtitle: AppConfig.clinicPhoneDisplay,
              onTap: () => dialClinic(context),
            ),
            _WideTile(
              icon: Icons.chat_bubble_outline_rounded,
              title: l10n.t('common.whatsapp'),
              subtitle: l10n.t('home.callSub'),
              onTap: () => openWhatsApp(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one loud thing on the screen. A clinic app has exactly one action that
/// matters more than the rest, and hiding it among equals helps nobody.
class _BookCard extends StatelessWidget {
  const _BookCard({required this.title, required this.subtitle, required this.onTap});

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Palette.indigoDeep,
      borderRadius: BorderRadius.circular(Palette.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Palette.radiusLg),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Palette.paper,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Palette.paper.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Palette.crimson,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded, color: Palette.paper),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Palette.paperDim,
          borderRadius: BorderRadius.circular(Palette.radiusCard),
        ),
        child: child,
      );
}

/// A card-shaped grey box while the first load is in flight.
///
/// Shown only on the very first load, and never on a refresh — replacing
/// content the patient is already reading with grey boxes is worse than
/// letting it sit there for a second while the new copy arrives.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) => Container(
        height: 108,
        decoration: BoxDecoration(
          color: Palette.paperDim,
          borderRadius: BorderRadius.circular(Palette.radiusCard),
        ),
      );
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 134,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => Container(
            width: 190,
            decoration: BoxDecoration(
              color: Palette.paperDim,
              borderRadius: BorderRadius.circular(Palette.radiusCard),
            ),
          ),
        ),
      );
}

class _ServiceChipCard extends StatelessWidget {
  const _ServiceChipCard({required this.service, required this.onTap});

  final Service service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final urdu = context.isUrdu;
    return SizedBox(
      width: 190,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: Palette.crimson,
                  ),
                ),
                const SizedBox(height: 7),
                Expanded(
                  child: Text(
                    service.displayName(urdu),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Palette.ink,
                      height: 1.35,
                    ),
                  ),
                ),
                if (service.price != null)
                  Text(
                    Fmt.money(service.price),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Palette.indigoDeep,
                      fontWeight: FontWeight.w600,
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

/// A full-width row. Replaces the old pair of half-width tiles, which put two
/// different kinds of thing side by side and clipped their labels in Urdu.
class _WideTile extends StatelessWidget {
  const _WideTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F2EC),
                    borderRadius: BorderRadius.circular(Palette.radiusSm),
                  ),
                  child: Icon(icon, color: Palette.indigoDeep, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: Palette.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: Palette.inkSoft),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Palette.inkSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared by Home, the Appointments tab and the doctor's list, so one booking
/// looks the same wherever it is shown.
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({super.key, required this.appointment, this.onTap});

  final Appointment appointment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final a = appointment;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Palette.paper,
        borderRadius: BorderRadius.circular(Palette.radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Palette.radiusCard),
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
                    Expanded(
                      child: Text(
                        a.service,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Palette.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    StatusPill(status: a.status, label: l10n.status(a.status)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 14, color: Palette.inkSoft),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        a.hasSchedule
                            ? '${Fmt.date(a.date)} · ${Fmt.time(a.time)}'
                            : l10n.t('appt.notScheduled'),
                        style: const TextStyle(fontSize: 13, color: Palette.inkSoft),
                      ),
                    ),
                  ],
                ),
                if (a.doctorName != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded,
                          size: 14, color: Palette.inkSoft),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          a.doctorName!,
                          style: const TextStyle(fontSize: 13, color: Palette.inkSoft),
                        ),
                      ),
                    ],
                  ),
                ],
                if (a.needsDoctor) ...[
                  const SizedBox(height: 10),
                  Text(
                    l10n.t('appt.needsDoctor'),
                    style: const TextStyle(fontSize: 12, color: Palette.warning),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
