import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../patient/profile_tab.dart';
import 'admin_appointments_tab.dart';
import 'admin_catalogue_tab.dart';
import 'admin_doctors_tab.dart';
import 'admin_overview_tab.dart';

/// The admin's app.
///
/// The website has eight items down its sidebar. Eight does not fit across a
/// phone, so they are grouped into five by what a person is actually trying to
/// do rather than by which collection the data lives in:
///
///   Overview · Bookings · Doctors · Catalogue · Profile
///
/// **Catalogue** holds services, discount codes and the blog behind one
/// segmented control. They are three different collections and one job —
/// "change what the website says and charges" — and someone doing that job
/// moves between them constantly.
///
/// **Slots** and **Translations** are deliberately not here. Opening the whole
/// clinic's calendar is something the doctors now do for themselves, and
/// translating a medical catalogue is a long, careful, two-column reading task
/// that a phone makes worse rather than better. Both stay on the website, and
/// Profile links to it.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  void _go(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          AdminOverviewTab(onGoToTab: _go),
          const AdminAppointmentsTab(),
          const AdminDoctorsTab(),
          const AdminCatalogueTab(),
          const ProfileTab(),
        ],
      ),
      bottomNavigationBar: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _go,
          height: 66,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.insights_outlined),
              selectedIcon: const Icon(Icons.insights_rounded),
              label: l10n.t('doc.nav.overview'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.event_note_outlined),
              selectedIcon: const Icon(Icons.event_note_rounded),
              label: l10n.t('doc.nav.appointments'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.medical_information_outlined),
              selectedIcon: const Icon(Icons.medical_information_rounded),
              label: l10n.t('adm.nav.doctors'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.inventory_2_outlined),
              selectedIcon: const Icon(Icons.inventory_2_rounded),
              label: l10n.t('adm.nav.catalogue'),
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
