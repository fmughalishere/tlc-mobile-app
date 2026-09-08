import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/formatting.dart';
import '../../core/palette.dart';
import '../../core/session_window.dart';
import '../../data/app_data.dart';
import '../../data/repository.dart';
import '../../i18n/strings.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../doctor/doctor_appointment_card.dart' show modeIcon;

/// Every booking in the clinic, and everything the desk can do to one.
///
/// Four things live here that the doctor's version does not have, because
/// they are the clinic's job rather than the clinician's:
///
///   · **Assign a doctor** — a booking made when nobody had an open slot
///     arrives with `needsDoctor` set and no doctor on it. Until someone here
///     picks one, the patient has a request rather than an appointment.
///   · **Reschedule** — moving a booking to a different open time. The server
///     does it in a transaction, so two people rescheduling at once cannot
///     double-book the destination.
///   · **Refund** — real money, through the payment provider, not reversible
///     from this screen. It asks twice.
///   · **Start a session early** — admin has always been able to; it is the
///     override for a patient who turns up ten minutes before their time.
class AdminAppointmentsTab extends StatefulWidget {
  const AdminAppointmentsTab({super.key});

  @override
  State<AdminAppointmentsTab> createState() => _AdminAppointmentsTabState();
}

class _AdminAppointmentsTabState extends State<AdminAppointmentsTab> {
  static const _filters = [
    'needsDoctor',
    'all',
    'pending',
    'confirmed',
    'awaiting-payment',
    'completed',
    'cancelled',
  ];

  final _repo = Repository();
  final _search = TextEditingController();

  String _filter = 'all';
  String _query = '';
  DateTime _now = DateTime.now();
  Timer? _clock;
  String? _busyId;
  List<Doctor> _doctors = const [];

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _loadDoctors();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _search.dispose();
    _repo.close();
    super.dispose();
  }

  /// Loaded once and kept. It is a short list that changes rarely, and it is
  /// needed the moment somebody opens the "assign a doctor" sheet — fetching
  /// it then would put a spinner inside a modal.
  Future<void> _loadDoctors() async {
    try {
      final list = await _repo.allDoctors();
      if (mounted) setState(() => _doctors = list);
    } catch (_) {
      // Not fatal: every other action on this screen still works, and the
      // assign sheet says so for itself if the list is empty.
    }
  }

  Future<void> _run(String id, Future<void> Function() action) async {
    setState(() => _busyId = id);
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _setStatus(Appointment a, String status) async {
    final l10n = context.read<LocaleController>();
    final data = context.read<AppData>();
    await _run(a.id, () async {
      await _repo.setAppointmentStatus(a.id, status);
      await data.refreshAppointments();
      if (mounted) showToast(context, l10n.t('doc.updated'));
    });
  }

  Future<void> _assign(Appointment a) async {
    final l10n = context.read<LocaleController>();
    final data = context.read<AppData>();

    final chosen = await showModalBottomSheet<Doctor>(
      context: context,
      backgroundColor: Palette.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Palette.radiusLg)),
      ),
      builder: (_) => _PickDoctorSheet(doctors: _doctors),
    );
    if (chosen == null) return;

    await _run(a.id, () async {
      await _repo.assignDoctor(a.id, chosen);
      await data.refreshAppointments();
      if (mounted) showToast(context, '${l10n.t('adm.appt.assigned')} ${chosen.displayName}');
    });
  }

  Future<void> _reschedule(Appointment a) async {
    final l10n = context.read<LocaleController>();
    final data = context.read<AppData>();

    // Only this appointment's own doctor's open times. Moving a booking to a
    // different doctor is a different decision, and doing both in one step is
    // how a patient ends up seeing somebody they did not agree to.
    final slot = await showModalBottomSheet<Slot>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Palette.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Palette.radiusLg)),
      ),
      builder: (_) => _PickSlotSheet(repo: _repo, doctorId: a.doctorId),
    );
    if (slot == null) return;

    await _run(a.id, () async {
      await _repo.reschedule(a.id, slot.id);
      await data.refreshAppointments();
      if (mounted) showToast(context, l10n.t('adm.appt.rescheduled'));
    });
  }

  Future<void> _refund(Appointment a) async {
    final l10n = context.read<LocaleController>();
    final data = context.read<AppData>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('adm.appt.refundTitle')),
        content: Text(
          '${Fmt.money(a.amount)} · ${a.patientName}\n\n${l10n.t('adm.appt.refundSub')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Palette.crimsonDeep),
            child: Text(l10n.t('adm.appt.refund')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await _run(a.id, () async {
      await _repo.issueRefund(a.id);
      await data.refreshAppointments();
      if (mounted) showToast(context, l10n.t('adm.appt.refunded'));
    });
  }

  Future<void> _startSession(Appointment a) async {
    final data = context.read<AppData>();
    await _run(a.id, () async {
      final result = await _repo.startSession(a.id);
      await data.refreshAppointments();
      if (!mounted) return;
      final url = result.appointment.roomUrl;
      if (url != null && url.isNotEmpty) {
        final token = result.joinToken;
        await openUrl(context, token == null || token.isEmpty ? url : '$url?t=$token');
      } else if (a.mode == 'chat') {
        await openUrl(context, '${AppConfig.apiBaseUrl}/admin/appointments');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final data = context.watch<AppData>();

    var visible = data.appointments;
    if (_filter == 'needsDoctor') {
      visible = visible.where((a) => a.needsDoctor && a.isUpcoming).toList();
    } else if (_filter != 'all') {
      visible = visible.where((a) => a.status == _filter).toList();
    }
    if (_query.isNotEmpty) {
      visible = visible.where((a) {
        return [a.patientName, a.patientPhone ?? '', a.service, a.doctorName ?? '', a.date]
            .join(' ')
            .toLowerCase()
            .contains(_query);
      }).toList();
    }
    visible = [...visible]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final needsDoctorCount =
        data.appointments.where((a) => a.needsDoctor && a.isUpcoming).length;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.t('adm.appt.title')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: l10n.t('adm.appt.search'),
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
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final f = _filters[i];
                // The "needs a doctor" chip is skipped entirely when there are
                // none — a filter that can only ever show an empty list is
                // just a thing to tap and be disappointed by.
                if (f == 'needsDoctor' && needsDoctorCount == 0) {
                  return const SizedBox.shrink();
                }
                final selected = _filter == f;
                final label = f == 'all'
                    ? l10n.t('doc.filter.all')
                    : f == 'needsDoctor'
                        ? '${l10n.t('adm.appt.needsDoctor')} ($needsDoctorCount)'
                        : l10n.status(f);
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => setState(() => _filter = f),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Palette.paper : Palette.inkSoft,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: !data.appointmentsLoaded && data.appointmentsLoading
                ? const LoadingView()
                : RefreshIndicator(
                    onRefresh: data.refreshAppointments,
                    child: visible.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                            children: [
                              EmptyState(
                                icon: Icons.event_note_outlined,
                                title: l10n.t('doc.appointments.empty'),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                            itemCount: visible.length,
                            itemBuilder: (context, i) => _AdminCard(
                              appointment: visible[i],
                              now: _now,
                              busy: _busyId == visible[i].id,
                              onAssign: () => _assign(visible[i]),
                              onReschedule: () => _reschedule(visible[i]),
                              onRefund: () => _refund(visible[i]),
                              onStart: () => _startSession(visible[i]),
                              onSetStatus: (s) => _setStatus(visible[i], s),
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

final ButtonStyle _cardButton = OutlinedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
  minimumSize: const Size(0, 40),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

class _AdminCard extends StatelessWidget {
  const _AdminCard({
    required this.appointment,
    required this.now,
    required this.busy,
    required this.onAssign,
    required this.onReschedule,
    required this.onRefund,
    required this.onStart,
    required this.onSetStatus,
  });

  final Appointment appointment;
  final DateTime now;
  final bool busy;
  final VoidCallback onAssign;
  final VoidCallback onReschedule;
  final VoidCallback onRefund;
  final VoidCallback onStart;
  final void Function(String status) onSetStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final a = appointment;

    final isOnline = a.mode == 'video' || a.mode == 'audio' || a.mode == 'chat';
    final joinable = SessionWindow.canJoin(a, now);
    final startEarly = SessionWindow.canStartEarly(a, now);
    final canChangeStatus = a.status != 'cancelled' && a.status != 'awaiting-payment';
    // The server frees the old slot if there is one and claims the new one
    // either way, so a doctor-request with no slot can be rescheduled too —
    // which is exactly how one stops being a request and becomes a booking.
    final canReschedule = a.status != 'completed' && a.status != 'cancelled';
    final refundable = a.isCancelled && a.paymentStatus == 'paid';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: a.needsDoctor ? Palette.warning : Palette.line,
            width: a.needsDoctor ? 1.4 : 1,
          ),
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
                        a.patientName.isEmpty ? '—' : a.patientName,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: Palette.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        a.service,
                        style: const TextStyle(fontSize: 13, color: Palette.inkSoft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                StatusPill(status: a.status, label: l10n.status(a.status)),
              ],
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 14, color: Palette.inkSoft),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    a.hasSchedule
                        ? '${Fmt.date(a.date)} · ${Fmt.time(a.time)}'
                        : l10n.t('appt.notScheduled'),
                    style: const TextStyle(fontSize: 12.5, color: Palette.inkSoft),
                  ),
                ),
                Icon(modeIcon(a.mode), size: 14, color: Palette.inkSoft),
                const SizedBox(width: 6),
                Text(a.mode, style: const TextStyle(fontSize: 12.5, color: Palette.inkSoft)),
              ],
            ),

            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 14, color: Palette.inkSoft),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    a.doctorName ?? l10n.t('adm.appt.noDoctor'),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: a.doctorName == null ? Palette.warning : Palette.inkSoft,
                      fontWeight:
                          a.doctorName == null ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),

            if (a.patientPhone != null) ...[
              const SizedBox(height: 6),
              InkWell(
                onTap: () => openUrl(context, 'tel:${a.patientPhone}'),
                child: Row(
                  children: [
                    const Icon(Icons.call_outlined, size: 14, color: Palette.indigo),
                    const SizedBox(width: 7),
                    Text(
                      Fmt.phone(a.patientPhone),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Palette.indigo,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  a.paymentStatus == 'paid'
                      ? Icons.check_circle_outline_rounded
                      : a.paymentStatus == 'refunded'
                          ? Icons.undo_rounded
                          : Icons.pending_outlined,
                  size: 14,
                  color: a.paymentStatus == 'paid' ? Palette.success : Palette.inkSoft,
                ),
                const SizedBox(width: 7),
                Text(
                  a.amount > 0
                      ? '${Fmt.money(a.amount)} · ${a.paymentStatus}'
                      : a.paymentStatus,
                  style: const TextStyle(fontSize: 12.5, color: Palette.inkSoft),
                ),
              ],
            ),

            if (a.preferredWhen != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Palette.paperDim,
                  borderRadius: BorderRadius.circular(Palette.radiusSm),
                ),
                child: Text(
                  '${l10n.t('book.preferredWhen')} ${a.preferredWhen}',
                  style: const TextStyle(fontSize: 12.5, color: Palette.ink, height: 1.5),
                ),
              ),
            ],

            if (a.needsDoctor) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF3E2),
                  borderRadius: BorderRadius.circular(Palette.radiusSm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('adm.appt.needsDoctorSub'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Palette.warning,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: busy ? null : onAssign,
                      style: FilledButton.styleFrom(
                        backgroundColor: Palette.indigoDeep,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                      ),
                      child: Text(
                        l10n.t('adm.appt.assign'),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (a.status == 'confirmed' && isOnline) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F8F5),
                  borderRadius: BorderRadius.circular(Palette.radiusSm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      SessionWindow.label(a, now),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Palette.indigoDeep,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: busy || (!joinable && !startEarly) ? null : onStart,
                      style: FilledButton.styleFrom(
                        backgroundColor: Palette.indigoDeep,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      ),
                      child: Text(
                        startEarly ? l10n.t('doc.startEarly') : l10n.t('doc.joinAsHost'),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (refundable) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Palette.dangerSoft,
                  borderRadius: BorderRadius.circular(Palette.radiusSm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.t('adm.appt.awaitingRefund')} · ${Fmt.money(a.amount)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Palette.crimsonDeep,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: busy ? null : onRefund,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Palette.crimsonDeep,
                        side: const BorderSide(color: Palette.crimson),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      ),
                      child: Text(
                        l10n.t('adm.appt.refund'),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (canReschedule || canChangeStatus) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (canReschedule)
                    OutlinedButton.icon(
                      onPressed: busy ? null : onReschedule,
                      style: _cardButton,
                      icon: const Icon(Icons.event_repeat_outlined, size: 17),
                      label: Text(
                        l10n.t('adm.appt.reschedule'),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  if (canChangeStatus)
                    for (final s in const ['confirmed', 'completed', 'cancelled'])
                      if (s != a.status)
                        OutlinedButton(
                          onPressed: busy ? null : () => onSetStatus(s),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 11),
                            minimumSize: const Size(0, 40),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: s == 'cancelled'
                                ? Palette.crimsonDeep
                                : Palette.indigoDeep,
                          ),
                          child: Text(
                            l10n.status(s),
                            style: const TextStyle(fontSize: 12.5),
                          ),
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

/// Picking a doctor for a booking that arrived without one.
class _PickDoctorSheet extends StatelessWidget {
  const _PickDoctorSheet({required this.doctors});

  final List<Doctor> doctors;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final available = doctors.where((d) => d.active).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('adm.appt.assign'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            if (available.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  l10n.t('doctors.empty'),
                  style: const TextStyle(fontSize: 13, color: Palette.inkSoft),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final d in available)
                      ChoiceCard(
                        title: d.displayName,
                        subtitle: d.specialization,
                        leading: Avatar(initials: d.initials, size: 38),
                        onTap: () => Navigator.of(context).pop(d),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Picking a new time for a booking that is being moved.
class _PickSlotSheet extends StatelessWidget {
  const _PickSlotSheet({required this.repo, required this.doctorId});

  final Repository repo;
  final String? doctorId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                l10n.t('adm.appt.pickNewTime'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: AsyncView<List<Slot>>(
                load: () => repo.availableSlots(doctorId: doctorId),
                builder: (context, slots, reload) {
                  if (slots.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                      children: [
                        EmptyState(
                          icon: Icons.event_busy_outlined,
                          title: l10n.t('book.noSlots'),
                          message: l10n.t('adm.appt.noSlotsSub'),
                        ),
                      ],
                    );
                  }

                  final days = <String>[];
                  final byDay = <String, List<Slot>>{};
                  for (final s in slots) {
                    if (!byDay.containsKey(s.date)) {
                      byDay[s.date] = [];
                      days.add(s.date);
                    }
                    byDay[s.date]!.add(s);
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                    children: [
                      for (final day in days) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 10),
                          child: Text(
                            Fmt.dateLong(day),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Palette.ink,
                            ),
                          ),
                        ),
                        for (final slot in byDay[day]!)
                          ChoiceCard(
                            title: Fmt.time(slot.time),
                            subtitle:
                                '${slot.doctorName} · ${slot.isOnline ? l10n.t('book.online') : l10n.t('book.inClinic')}',
                            onTap: () => Navigator.of(context).pop(slot),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
