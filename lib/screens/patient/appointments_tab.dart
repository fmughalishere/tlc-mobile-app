import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_data.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../appointments/appointment_detail_screen.dart';
import '../booking/book_screen.dart';
import 'home_tab.dart' show AppointmentCard;

/// Everything the patient has booked, split into two lists.
///
/// Upcoming is soonest-first and past is newest-first, which sounds
/// inconsistent and is not: in both cases the appointment nearest to *now* is
/// at the top, because that is the one being looked for.
class AppointmentsTab extends StatelessWidget {
  const AppointmentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final data = context.watch<AppData>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(l10n.t('appt.title')),
          bottom: TabBar(
            tabs: [
              Tab(text: '${l10n.t('appt.upcoming')} (${data.upcoming.length})'),
              Tab(text: '${l10n.t('appt.past')} (${data.past.length})'),
            ],
          ),
        ),
        body: !data.appointmentsLoaded && data.appointmentsLoading
            ? const LoadingView()
            : TabBarView(
                children: [
                  _List(items: data.upcoming, upcoming: true),
                  _List(items: data.past, upcoming: false),
                ],
              ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.items, required this.upcoming});

  final List<Appointment> items;
  final bool upcoming;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final data = context.read<AppData>();

    if (items.isEmpty) {
      // Still a ListView so pull-to-refresh keeps working on an empty tab —
      // "nothing here" is exactly the state someone pulls to refresh.
      return RefreshIndicator(
        onRefresh: data.refreshAppointments,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
          children: [
            EmptyState(
              icon: upcoming ? Icons.event_available_outlined : Icons.history_rounded,
              title: l10n.t(upcoming ? 'appt.emptyUpcoming' : 'appt.emptyPast'),
              message: l10n.t(upcoming ? 'appt.emptySub' : 'appt.emptyPastSub'),
            ),
            if (upcoming) ...[
              const SizedBox(height: 24),
              Center(
                child: FilledButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const BookScreen()),
                    );
                    await data.refreshAppointments();
                  },
                  child: Text(l10n.t('home.book')),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: data.refreshAppointments,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        itemCount: items.length,
        itemBuilder: (context, i) => AppointmentCard(
          appointment: items[i],
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AppointmentDetailScreen(appointment: items[i]),
              ),
            );
            await data.refreshAppointments();
          },
        ),
      ),
    );
  }
}
