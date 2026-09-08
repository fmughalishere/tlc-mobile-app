import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../patient/profile_tab.dart';
import 'doctor_appointments_tab.dart';
import 'doctor_availability_tab.dart';
import 'doctor_overview_tab.dart';
import 'doctor_patients_tab.dart';

/// The doctor's app.
///
/// The five tabs are the website's four nav items plus Settings, in the same
/// order and doing the same jobs — Overview, Appointments, Availability,
/// Patients, Profile. Keeping the order identical is not neatness: a doctor
/// who uses the desktop at the clinic and the phone between patients should
/// not have to learn two different maps of the same tool.
///
/// Profile is the patient one, unchanged. It already knows to show the
/// doctor-only fields — specialisation, bio, "show me as online" — because it
/// reads the role off the profile rather than off which shell it is inside.
class DoctorShell extends StatefulWidget {
  const DoctorShell({super.key});

  @override
  State<DoctorShell> createState() => _DoctorShellState();
}

class _DoctorShellState extends State<DoctorShell> {
  int _index = 0;

  void _go(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DoctorOverviewTab(onGoToTab: _go),
          const DoctorAppointmentsTab(),
          const DoctorAvailabilityTab(),
          const DoctorPatientsTab(),
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
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard_rounded),
              label: l10n.t('doc.nav.overview'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.event_note_outlined),
              selectedIcon: const Icon(Icons.event_note_rounded),
              label: l10n.t('doc.nav.appointments'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.schedule_outlined),
              selectedIcon: const Icon(Icons.schedule_rounded),
              label: l10n.t('doc.nav.availability'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.groups_2_outlined),
              selectedIcon: const Icon(Icons.groups_2_rounded),
              label: l10n.t('doc.nav.patients'),
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
