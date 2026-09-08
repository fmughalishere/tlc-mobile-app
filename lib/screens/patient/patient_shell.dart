import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/palette.dart';
import '../../data/app_data.dart';
import '../../widgets/common.dart';
import '../services/services_screen.dart';
import 'appointments_tab.dart';
import 'home_tab.dart';
import 'notifications_tab.dart';
import 'profile_tab.dart';

/// The patient's app: five tabs and nothing else at the top level.
///
/// The tabs are kept alive with an IndexedStack rather than rebuilt on every
/// switch. That is not a performance flourish — a list that reloads every time
/// someone glances at Home and comes back is a list that flickers, loses its
/// scroll position, and spends the patient's mobile data doing it.
class PatientShell extends StatefulWidget {
  const PatientShell({super.key});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _index = 0;

  /// Lets Home send the patient to another tab — "you have no appointments,
  /// book one" should land on the right tab, not open a parallel stack.
  void _go(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final unread = context.watch<AppData>().unreadCount;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeTab(onGoToTab: _go),
          const ServicesScreen(embedded: true),
          const AppointmentsTab(),
          const NotificationsTab(),
          const ProfileTab(),
        ],
      ),

      // ── Why the bar is wrapped ──
      //
      // Five labels have to fit across the narrowest phone the clinic's
      // patients actually use, in two languages, at whatever font size the
      // person has set in Android's accessibility settings. Left alone, a
      // phone at 1.3× text scale wraps "Appointments" onto a second line and
      // the whole bar grows into the screen; at 1.5× the labels clip.
      //
      // So the text scale is clamped for this one widget only — the rest of
      // the app still honours the setting in full, which is where it actually
      // matters for reading — and the labels themselves are kept to one short
      // word each.
      bottomNavigationBar: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _go,
          height: 66,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: l10n.t('nav.home'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.medical_services_outlined),
              selectedIcon: const Icon(Icons.medical_services_rounded),
              label: l10n.t('nav.services'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.event_note_outlined),
              selectedIcon: const Icon(Icons.event_note_rounded),
              label: l10n.t('nav.appointments'),
            ),
            NavigationDestination(
              // The badge is the only reason to open this tab, so it belongs
              // on the icon rather than inside the screen.
              icon: _Badged(
                count: unread,
                child: const Icon(Icons.notifications_none_rounded),
              ),
              selectedIcon: _Badged(
                count: unread,
                child: const Icon(Icons.notifications_rounded),
              ),
              label: l10n.t('nav.alerts'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: l10n.t('nav.profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badged extends StatelessWidget {
  const _Badged({required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    return Badge(
      // Past nine the exact number stops mattering and the badge starts to
      // push the icon around, so it stops counting.
      label: Text(count > 9 ? '9+' : '$count'),
      backgroundColor: Palette.crimson,
      textColor: Palette.paper,
      child: child,
    );
  }
}
