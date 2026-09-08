import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../core/palette.dart';
import '../../data/repository.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

/// One patient's whole history with this doctor.
///
/// Fetched with `?patientId=`, which the server narrows *inside* the doctor's
/// own scope — the doctorId filter is applied first and cannot be escaped by
/// the query string, so this can never reach another doctor's records. The
/// alternative, which the website used to do, was to download every
/// appointment the doctor had ever had and filter down to one person in the
/// browser: correct, and wasteful in exactly the place a phone can least
/// afford it.
class DoctorPatientDetailScreen extends StatefulWidget {
  const DoctorPatientDetailScreen({
    super.key,
    required this.patientId,
    this.fallbackName = '',
  });

  final String patientId;

  /// Shown in the title bar while the history is loading, so the screen is not
  /// blank and nameless for the second it takes.
  final String fallbackName;

  @override
  State<DoctorPatientDetailScreen> createState() => _DoctorPatientDetailScreenState();
}

class _DoctorPatientDetailScreenState extends State<DoctorPatientDetailScreen> {
  final _repo = Repository();

  @override
  void dispose() {
    _repo.close();
    super.dispose();
  }

  Future<List<Appointment>> _load() async {
    final list = await _repo.doctorAppointments(patientId: widget.patientId, limit: 200);
    // Newest first — the visit being asked about is nearly always the last one.
    list.sort((a, b) => (b.date + b.time).compareTo(a.date + a.time));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.fallbackName.isEmpty ? l10n.t('doc.patients.one') : widget.fallbackName,
        ),
      ),
      body: AsyncView<List<Appointment>>(
        load: _load,
        emptyWhen: (list) => list.isEmpty,
        emptyTitle: l10n.t('doc.patients.noRecord'),
        emptyMessage: l10n.t('doc.patients.noRecordSub'),
        builder: (context, history, reload) {
          final patient = history.first;
          final completed = history.where((a) => a.isCompleted).length;
          final today = Fmt.todayIso();
          Appointment? next;
          for (final a in history.reversed) {
            if (a.date.compareTo(today) >= 0 && a.status == 'confirmed') {
              next = a;
              break;
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
            children: [
              Row(
                children: [
                  Avatar(initials: _initials(patient.patientName), size: 52),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.patientName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (patient.patientPhone != null) ...[
                          const SizedBox(height: 3),
                          InkWell(
                            onTap: () => openUrl(context, 'tel:${patient.patientPhone}'),
                            child: Row(
                              children: [
                                const Icon(Icons.call_outlined,
                                    size: 14, color: Palette.indigo),
                                const SizedBox(width: 6),
                                Text(
                                  Fmt.phone(patient.patientPhone),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Palette.indigo,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              if (next != null) ...[
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F2EC),
                    borderRadius: BorderRadius.circular(Palette.radiusCard),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.t('doc.patients.next'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: Palette.indigoDeep,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${next.service} · ${Fmt.dateLong(next.date)} · ${Fmt.time(next.time)}',
                        style: const TextStyle(fontSize: 13.5, color: Palette.ink),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      value: '${history.length}',
                      label: l10n.t('doc.patients.totalWithYou'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Stat(
                      value: '$completed',
                      label: l10n.t('appt.status.completed'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 26),
              SectionHeader(title: l10n.t('doc.patients.history')),
              for (final a in history) _HistoryRow(appointment: a),
            ],
          );
        },
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    String first(String s) => s.substring(0, 1).toUpperCase();
    if (parts.length == 1) return first(parts.first);
    return '${first(parts.first)}${first(parts.last)}';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          border: Border.all(color: Palette.line),
          borderRadius: BorderRadius.circular(Palette.radiusCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Palette.indigoDeep,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: Palette.inkSoft),
            ),
          ],
        ),
      );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final a = appointment;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(15),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.service,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Palette.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        a.hasSchedule
                            ? '${Fmt.date(a.date)} · ${Fmt.time(a.time)} · ${a.mode}'
                            : l10n.t('appt.notScheduled'),
                        style: const TextStyle(fontSize: 12, color: Palette.inkSoft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                StatusPill(status: a.status, label: l10n.status(a.status)),
              ],
            ),
            if (a.notes != null) ...[
              const SizedBox(height: 9),
              Text(
                '“${a.notes}”',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Palette.inkSoft,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
            ],
            if (a.prescription != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Palette.paperDim,
                  borderRadius: BorderRadius.circular(Palette.radiusSm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('appt.prescription'),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: Palette.crimson,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      a.prescription!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Palette.ink,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (a.rating != null) ...[
              const SizedBox(height: 9),
              Row(
                children: [
                  StarRow(value: a.rating!, size: 14),
                  const SizedBox(width: 7),
                  Text(
                    a.rating!.toStringAsFixed(1),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontSize: 11.5, color: Palette.inkSoft),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
