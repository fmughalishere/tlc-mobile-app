import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatting.dart';
import '../../core/palette.dart';
import '../../core/session.dart';
import '../../data/app_data.dart';
import '../../data/repository.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import 'doctor_appointment_card.dart';

/// The doctor's overview: four numbers and today's list.
///
/// The numbers come from `/api/appointments/stats`, which counts them
/// server-side with Firestore's `count()`. That matters more than it sounds: a
/// doctor with two thousand past appointments should not download two thousand
/// documents on a mobile connection to be shown the number 2000.
///
/// Today's schedule comes from the appointments the app already holds, so this
/// screen has something to draw the moment it opens.
class DoctorOverviewTab extends StatefulWidget {
  const DoctorOverviewTab({super.key, required this.onGoToTab});

  final void Function(int index) onGoToTab;

  @override
  State<DoctorOverviewTab> createState() => _DoctorOverviewTabState();
}

class _DoctorOverviewTabState extends State<DoctorOverviewTab> {
  final _repo = Repository();
  DoctorStats? _stats;
  bool _statsFailed = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void dispose() {
    _repo.close();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _repo.doctorStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _statsFailed = false;
      });
    } catch (_) {
      // The tiles keep their last value and the schedule below is the part
      // that actually matters, so this is a quiet failure with a visible mark
      // rather than an error page over the whole screen.
      if (mounted) setState(() => _statsFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    final data = context.watch<AppData>();

    final today = Fmt.todayIso();
    final todays = data.appointments
        .where((a) => a.date == today && a.status != 'cancelled')
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    final presenceVisible = session.profile?['presenceVisible'] != false;
    final name = Fmt.firstName(session.name);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo-icon.png',
              height: 26,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.t('doc.overview.title'),
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
          await Future.wait([data.refreshAppointments(), _loadStats()]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          children: [
            Text(
              name.isEmpty
                  ? l10n.t('doc.overview.hello')
                  : '${l10n.t('doc.overview.hello')}, Dr. $name',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.t('doc.overview.subtitle'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            // Presence is automatic — derived from a heartbeat while the app
            // is open — so there is no switch here, only a report of what
            // patients currently see. The switch that does exist lives in
            // Profile and only ever *suppresses* it.
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Palette.line),
                borderRadius: BorderRadius.circular(Palette.radiusPill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: presenceVisible ? Palette.success : Palette.line,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      presenceVisible
                          ? l10n.t('doc.presence.on')
                          : l10n.t('doc.presence.hidden'),
                      style: const TextStyle(fontSize: 12.5, color: Palette.inkSoft),
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onGoToTab(4),
                    child: Text(l10n.t('doc.presence.change')),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              // Wide and short, so a long Urdu label wraps to two lines
              // without the number and the label colliding.
              childAspectRatio: 1.65,
              children: [
                _StatTile(
                  value: _stats?.todays ?? todays.length,
                  label: l10n.t('doc.stat.today'),
                  unknown: _statsFailed && _stats == null,
                ),
                _StatTile(
                  value: _stats?.upcoming,
                  label: l10n.t('doc.stat.upcoming'),
                  unknown: _stats == null,
                ),
                _StatTile(
                  value: _stats?.uniquePatients,
                  label: l10n.t('doc.stat.patients'),
                  unknown: _stats == null,
                ),
                _StatTile(
                  value: _stats?.completed,
                  label: l10n.t('doc.stat.completed'),
                  unknown: _stats == null,
                ),
              ],
            ),

            if (_stats?.indexHint != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF3E2),
                  borderRadius: BorderRadius.circular(Palette.radiusSm),
                ),
                child: Text(
                  _stats!.indexHint!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Palette.warning,
                    height: 1.5,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 26),
            SectionHeader(
              title: l10n.t('doc.overview.today'),
              actionLabel: l10n.t('common.seeAll'),
              onAction: () => widget.onGoToTab(1),
            ),
            Text(
              Fmt.dateLong(today),
              style: const TextStyle(fontSize: 12.5, color: Palette.inkSoft),
            ),
            const SizedBox(height: 12),

            if (!data.appointmentsLoaded && data.appointmentsLoading)
              const LoadingView()
            else if (todays.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Palette.paperDim,
                  borderRadius: BorderRadius.circular(Palette.radiusCard),
                ),
                child: EmptyState(
                  icon: Icons.event_available_outlined,
                  title: l10n.t('doc.overview.nothingToday'),
                ),
              )
            else
              for (final a in todays)
                DoctorAppointmentRow(
                  appointment: a,
                  onTap: () => widget.onGoToTab(1),
                ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, this.unknown = false});

  final int? value;
  final String label;
  final bool unknown;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Palette.line),
        borderRadius: BorderRadius.circular(Palette.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            // An em dash while the count is unknown, rather than a zero. Zero
            // is an answer; "we could not count" is not, and showing one as
            // the other is how a doctor concludes they have no patients.
            (unknown || value == null) ? '—' : '$value',
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              color: Palette.indigoDeep,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: Palette.inkSoft, height: 1.3),
          ),
        ],
      ),
    );
  }
}
