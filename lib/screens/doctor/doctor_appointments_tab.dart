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
import 'doctor_appointment_card.dart';
import 'follow_up_screen.dart';
import 'prescription_screen.dart';

/// The doctor's working screen: every appointment, and everything they can do
/// to one.
///
/// ── About the clock ──
///
/// Whether a session can be joined depends on the time *right now*, so this
/// screen keeps its own ticking `_now` and rebuilds every thirty seconds. It
/// is the only screen in the app that does, and it needs to: without it a
/// doctor who opened the tab at 2:58 would still be looking at a disabled
/// "Join" button at 3:05, and would reasonably conclude the app was broken.
class DoctorAppointmentsTab extends StatefulWidget {
  const DoctorAppointmentsTab({super.key});

  @override
  State<DoctorAppointmentsTab> createState() => _DoctorAppointmentsTabState();
}

class _DoctorAppointmentsTabState extends State<DoctorAppointmentsTab> {
  static const _filters = ['all', 'confirmed', 'pending', 'completed', 'cancelled'];

  final _repo = Repository();
  final _search = TextEditingController();

  String _filter = 'all';
  String _query = '';
  DateTime _now = DateTime.now();
  Timer? _clock;

  /// The appointment currently being acted on, so its own buttons can show a
  /// spinner without disabling the rest of the list.
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _search.dispose();
    _repo.close();
    super.dispose();
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
    // `read`, not `watch`. `context.l10n` watches, and watching outside a
    // build method is an assertion failure in Provider — which would turn
    // every one of these buttons into a crash the moment it succeeded.
    final l10n = context.read<LocaleController>();
    final data = context.read<AppData>();
    await _run(a.id, () async {
      await _repo.setAppointmentStatus(a.id, status);
      await data.refreshAppointments();
      if (mounted) showToast(context, l10n.t('doc.updated'));
    });
  }

  /// Opens the room and hands the doctor a host link.
  ///
  /// The call itself runs in the phone's browser rather than inside a WebView.
  /// That is a deliberate choice: a video call needs the camera and the
  /// microphone, and Chrome already has permission for both and a permission
  /// prompt people recognise. An in-app WebView would need its own permission
  /// plumbing on both platforms to arrive at the same place, and would fail
  /// silently — a black rectangle — when it did not.
  ///
  /// The `t=` token is what makes this the *host* link: it is what lets the
  /// doctor admit the patient and end the call for everyone.
  Future<void> _startSession(Appointment a) async {
    final data = context.read<AppData>();
    await _run(a.id, () async {
      final result = await _repo.startSession(a.id);
      await data.refreshAppointments();
      if (!mounted) return;

      final url = result.appointment.roomUrl;
      if (url != null && url.isNotEmpty) {
        final token = result.joinToken;
        await openUrl(
          context,
          token == null || token.isEmpty ? url : '$url?t=$token',
        );
      } else if (a.mode == 'chat') {
        // Secure chat is end-to-end encrypted in the browser with a key the
        // server hands only to this appointment's participants. Reproducing
        // that in the app is real work and half of it would be worse than
        // none, so for now the doctor is sent to the same thread on the site.
        await openUrl(context, '${AppConfig.apiBaseUrl}/doctor/appointments');
      }
    });
  }

  Future<void> _endSession(Appointment a) async {
    final l10n = context.read<LocaleController>();
    final data = context.read<AppData>();
    final confirmed = await _confirm(
      title: l10n.t('doc.endSession'),
      message: l10n.t('doc.endSessionSub'),
      destructive: true,
    );
    if (confirmed != true) return;

    await _run(a.id, () async {
      await _repo.endSession(a.id);
      await data.refreshAppointments();
      if (mounted) showToast(context, l10n.t('doc.sessionEnded'));
    });
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    bool destructive = false,
  }) {
    final l10n = context.read<LocaleController>();
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: destructive
                ? TextButton.styleFrom(foregroundColor: Palette.crimsonDeep)
                : null,
            child: Text(l10n.t('common.confirm')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final data = context.watch<AppData>();

    var visible = data.appointments;
    if (_filter != 'all') {
      visible = visible.where((a) => a.status == _filter).toList();
    }
    if (_query.isNotEmpty) {
      visible = visible.where((a) {
        return [a.patientName, a.patientPhone ?? '', a.service, a.date]
            .join(' ')
            .toLowerCase()
            .contains(_query);
      }).toList();
    }
    visible = [...visible]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.t('doc.appointments.title')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: l10n.t('doc.appointments.search'),
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
                final selected = _filter == f;
                return ChoiceChip(
                  label: Text(
                    f == 'all' ? l10n.t('doc.filter.all') : l10n.status(f),
                  ),
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
                            itemBuilder: (context, i) => _DoctorCard(
                              appointment: visible[i],
                              now: _now,
                              busy: _busyId == visible[i].id,
                              onSetStatus: (s) => _setStatus(visible[i], s),
                              onStart: () => _startSession(visible[i]),
                              onEnd: () => _endSession(visible[i]),
                              onPrescribe: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        PrescriptionScreen(appointment: visible[i]),
                                  ),
                                );
                                await data.refreshAppointments();
                              },
                              onFollowUp: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => FollowUpScreen(appointment: visible[i]),
                                  ),
                                );
                                await data.refreshAppointments();
                              },
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Buttons inside a card: tighter than the app-wide default, which is sized
/// for a screen's primary action rather than for two of them inside a list row.
final ButtonStyle _cardButton = OutlinedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
  minimumSize: const Size(0, 40),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

/// One appointment, with everything the doctor can do to it.
class _DoctorCard extends StatelessWidget {
  const _DoctorCard({
    required this.appointment,
    required this.now,
    required this.busy,
    required this.onSetStatus,
    required this.onStart,
    required this.onEnd,
    required this.onPrescribe,
    required this.onFollowUp,
  });

  final Appointment appointment;
  final DateTime now;
  final bool busy;
  final void Function(String status) onSetStatus;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final VoidCallback onPrescribe;
  final VoidCallback onFollowUp;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final a = appointment;

    final isOnline = a.mode == 'video' || a.mode == 'audio' || a.mode == 'chat';
    final joinable = SessionWindow.canJoin(a, now);
    final startEarly = SessionWindow.canStartEarly(a, now);

    // No status control while the patient still has to pay. Its options are
    // confirmed/completed/cancelled, so an awaiting-payment row would render a
    // control matching none of them — one that silently confirms an unpaid
    // visit the moment anybody touches it.
    final canChangeStatus =
        a.status != 'cancelled' && a.status != 'awaiting-payment';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
                Text(
                  a.mode,
                  style: const TextStyle(fontSize: 12.5, color: Palette.inkSoft),
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

            if (a.notes != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Palette.paperDim,
                  borderRadius: BorderRadius.circular(Palette.radiusSm),
                ),
                child: Text(
                  a.notes!,
                  style: const TextStyle(fontSize: 12.5, color: Palette.ink, height: 1.5),
                ),
              ),
            ],

            // ── The session ──
            if (a.status == 'confirmed' && isOnline) ...[
              const SizedBox(height: 14),
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          onPressed: busy || (!joinable && !startEarly) ? null : onStart,
                          style: FilledButton.styleFrom(
                            backgroundColor: Palette.indigoDeep,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                          ),
                          child: Text(
                            busy
                                ? l10n.t('doc.connecting')
                                : startEarly
                                    ? l10n.t('doc.startEarly')
                                    : a.mode == 'chat'
                                        ? l10n.t('doc.openChat')
                                        : l10n.t('doc.joinAsHost'),
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                        if (a.sessionStatus == 'live')
                          OutlinedButton(
                            onPressed: busy ? null : onEnd,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Palette.crimsonDeep,
                              side: const BorderSide(color: Palette.crimson),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                            ),
                            child: Text(
                              l10n.t('doc.endSession'),
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // ── After the visit ──
            if (a.isCompleted) ...[
              if (a.rating != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    StarRow(value: a.rating!, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${a.rating!.toStringAsFixed(1)} / 5',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Palette.ink,
                      ),
                    ),
                  ],
                ),
                if (a.ratingComment != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    '“${a.ratingComment}”',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Palette.inkSoft,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 14),
              // A Wrap, not a Row of Expandeds.
              //
              // Two equal halves of a phone screen is not enough room for
              // "Add prescription" beside an icon, and Expanded gave each
              // button exactly half whether the words fitted or not — so the
              // label broke mid-word across two lines ("Add presc / ription").
              // Here each button takes the width its own text needs: if both
              // fit on one line they sit side by side, and if they do not —
              // a longer word, Urdu, a larger system font, a narrower phone —
              // the second drops onto its own line, still whole.
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: onPrescribe,
                    style: _cardButton,
                    icon: const Icon(Icons.medication_outlined, size: 17),
                    label: Text(
                      a.prescription == null
                          ? l10n.t('doc.addPrescription')
                          : l10n.t('doc.editPrescription'),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onFollowUp,
                    style: _cardButton,
                    icon: const Icon(Icons.event_repeat_outlined, size: 17),
                    label: Text(
                      l10n.t('doc.followUp'),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ],

            if (a.isCancelled && a.cancelReason != null) ...[
              const SizedBox(height: 10),
              Text(
                a.cancelReason!,
                style: const TextStyle(fontSize: 12, color: Palette.crimsonDeep),
              ),
            ],

            // ── Status ──
            if (canChangeStatus) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    l10n.t('doc.markAs'),
                    style: const TextStyle(fontSize: 12, color: Palette.inkSoft),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 6,
                      children: [
                        for (final s in const ['confirmed', 'completed', 'cancelled'])
                          if (s != a.status)
                            TextButton(
                              onPressed: busy ? null : () => onSetStatus(s),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                minimumSize: const Size(0, 34),
                                foregroundColor: s == 'cancelled'
                                    ? Palette.crimsonDeep
                                    : Palette.indigo,
                              ),
                              child: Text(
                                l10n.status(s),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                      ],
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
