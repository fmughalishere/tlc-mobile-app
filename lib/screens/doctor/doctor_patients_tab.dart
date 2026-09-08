import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatting.dart';
import '../../core/palette.dart';
import '../../data/app_data.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import 'doctor_patient_detail_screen.dart';

/// The doctor's patients.
///
/// There is no patients collection to read. "A patient of Dr X" is defined by
/// having an appointment with Dr X, so this list is rolled up from the
/// appointments the app already holds — which also means it needs no request
/// of its own and appears instantly.
///
/// Ordered by who was seen most recently, because that is what someone is
/// looking for when they open this on a phone: the person who was just here.
class DoctorPatientsTab extends StatefulWidget {
  const DoctorPatientsTab({super.key});

  @override
  State<DoctorPatientsTab> createState() => _DoctorPatientsTabState();
}

class _DoctorPatientsTabState extends State<DoctorPatientsTab> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final data = context.watch<AppData>();

    var patients = PatientSummary.from(data.appointments, Fmt.todayIso());
    if (_query.isNotEmpty) {
      patients = patients
          .where((p) =>
              '${p.patientName} ${p.patientPhone ?? ''}'.toLowerCase().contains(_query))
          .toList();
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.t('doc.patients.title')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: l10n.t('doc.patients.search'),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: !data.appointmentsLoaded && data.appointmentsLoading
                ? const LoadingView()
                : RefreshIndicator(
                    onRefresh: data.refreshAppointments,
                    child: patients.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                            children: [
                              EmptyState(
                                icon: _query.isEmpty
                                    ? Icons.groups_2_outlined
                                    : Icons.search_off_rounded,
                                title: _query.isEmpty
                                    ? l10n.t('doc.patients.empty')
                                    : l10n.t('common.nothingHere'),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                            itemCount: patients.length,
                            itemBuilder: (context, i) => _PatientRow(
                              patient: patients[i],
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => DoctorPatientDetailScreen(
                                    patientId: patients[i].patientId,
                                    fallbackName: patients[i].patientName,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PatientRow extends StatelessWidget {
  const _PatientRow({required this.patient, required this.onTap});

  final PatientSummary patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = patient;

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
            child: Column(
              children: [
                Row(
                  children: [
                    Avatar(initials: p.initials, size: 42),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.patientName.isEmpty ? '—' : p.patientName,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: Palette.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${p.totalSessions} ${l10n.t('doc.patients.sessions')}'
                            ' · ${l10n.t('doc.patients.lastSeen')} ${Fmt.date(p.lastSeen)}',
                            style: const TextStyle(fontSize: 11.5, color: Palette.inkSoft),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Palette.inkSoft),
                  ],
                ),
                if (p.nextUpcoming != null) ...[
                  const SizedBox(height: 11),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F2EC),
                      borderRadius: BorderRadius.circular(Palette.radiusSm),
                    ),
                    child: Text(
                      '${l10n.t('doc.patients.next')}: '
                      '${Fmt.date(p.nextUpcoming!.date)} · ${Fmt.time(p.nextUpcoming!.time)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Palette.indigoDeep,
                      ),
                    ),
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
