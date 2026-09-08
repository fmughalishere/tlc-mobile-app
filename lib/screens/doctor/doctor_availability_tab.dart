import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatting.dart';
import '../../core/palette.dart';
import '../../data/app_data.dart';
import '../../data/repository.dart';
import '../../i18n/strings.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

/// A doctor's own calendar: the times they can see patients, and the days they
/// cannot.
///
/// Before the website had this page a doctor had to ask an admin to open a
/// time — which made the clinic a bottleneck for the one thing only the doctor
/// actually knows. This is the same two jobs on the phone, and it matters more
/// here: opening tomorrow morning is exactly the kind of thing someone does
/// from the car park, not from a desk.
///
/// The server is what scopes it. `doctorId` comes from the token, so this
/// screen never sends one and cannot open a time in somebody else's diary.
class DoctorAvailabilityTab extends StatefulWidget {
  const DoctorAvailabilityTab({super.key});

  @override
  State<DoctorAvailabilityTab> createState() => _DoctorAvailabilityTabState();
}

class _DoctorAvailabilityTabState extends State<DoctorAvailabilityTab> {
  final _repo = Repository();

  List<Slot> _slots = const [];
  List<Leave> _leaves = const [];
  bool _loading = true;
  Object? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _repo.close();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _error = null);
    try {
      // Both at once. They are two independent requests, and running them in
      // a row makes the doctor wait for the sum of two round trips to see a
      // screen that could have been drawn after the slower one.
      final results = await Future.wait<Object>([
        _repo.mySlots(),
        _repo.leaves(),
      ]);
      final slots = results[0] as List<Slot>;
      final leaves = results[1] as List<Leave>;
      if (!mounted) return;
      setState(() {
        _slots = slots;
        _leaves = leaves;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  // ── Opening times ─────────────────────────────────────────────────────────

  Future<void> _openTimes() async {
    // Read before the first await: `context.l10n` watches, and watching
    // outside build is an assertion failure in Provider.
    final l10n = context.read<LocaleController>();
    final services = context.read<AppData>().services;
    final draft = await showModalBottomSheet<_SlotDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Palette.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Palette.radiusLg)),
      ),
      builder: (_) => _AddTimesSheet(services: services),
    );
    if (draft == null) return;

    try {
      await _repo.openSlots(
        date: draft.date,
        times: draft.times,
        service: draft.service,
        mode: draft.mode,
        durationMinutes: draft.durationMinutes,
      );
      if (!mounted) return;
      showToast(context, '${draft.times.length} ${l10n.t('doc.av.opened')}');
      await _load();
    } on ApiException catch (e) {
      // The server refuses a time inside a leave, and a duplicate of one that
      // already exists. Both messages are written for a person to read, so
      // they are shown as they are rather than replaced with something generic.
      if (mounted) showToast(context, e.message, error: true);
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    }
  }

  Future<void> _removeSlot(Slot slot) async {
    final l10n = context.read<LocaleController>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('doc.av.removeTime')),
        content: Text(
          '${Fmt.dateLong(slot.date)} · ${Fmt.time(slot.time)}\n\n'
          '${l10n.t('doc.av.removeTimeSub')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Palette.crimsonDeep),
            child: Text(l10n.t('doc.av.remove')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busyId = slot.id);
    try {
      await _repo.removeSlot(slot.id);
      if (mounted) setState(() => _slots = _slots.where((s) => s.id != slot.id).toList());
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  // ── Leave ─────────────────────────────────────────────────────────────────

  Future<void> _addLeave() async {
    final l10n = context.read<LocaleController>();
    final draft = await showModalBottomSheet<_LeaveDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Palette.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Palette.radiusLg)),
      ),
      builder: (_) => const _AddLeaveSheet(),
    );
    if (draft == null) return;

    try {
      final result = await _repo.addLeave(
        from: draft.from,
        to: draft.to,
        reason: draft.reason,
      );
      if (!mounted) return;

      // Booked slots are left standing on purpose — those are real patients
      // with a real appointment, and they need telling rather than deleting.
      // Said plainly, so the doctor knows the leave alone did not settle it.
      if (result.bookedSlots > 0) {
        showToast(
          context,
          '${l10n.t('doc.av.leaveSavedBut')} ${result.bookedSlots}',
          error: true,
        );
      } else if (result.removedSlots > 0) {
        showToast(
          context,
          '${l10n.t('doc.av.leaveSaved')} — ${result.removedSlots} '
          '${l10n.t('doc.av.timesRemoved')}',
        );
      } else {
        showToast(context, l10n.t('doc.av.leaveSaved'));
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    }
  }

  Future<void> _removeLeave(Leave leave) async {
    final l10n = context.read<LocaleController>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('doc.av.removeLeave')),
        content: Text(l10n.t('doc.av.removeLeaveSub')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Palette.crimsonDeep),
            child: Text(l10n.t('doc.av.remove')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busyId = leave.id);
    try {
      await _repo.removeLeave(leave.id);
      if (mounted) setState(() => _leaves = _leaves.where((l) => l.id != leave.id).toList());
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  // ── Screen ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Past days are dropped: a calendar of times that have already gone is
    // noise, and the doctor cannot act on any of it.
    final today = Fmt.todayIso();
    final upcoming = _slots.where((s) => s.date.compareTo(today) >= 0).toList();

    final days = <String>[];
    final byDay = <String, List<Slot>>{};
    for (final s in upcoming) {
      if (!byDay.containsKey(s.date)) {
        byDay[s.date] = [];
        days.add(s.date);
      }
      byDay[s.date]!.add(s);
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.t('doc.av.title')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openTimes,
        backgroundColor: Palette.crimson,
        foregroundColor: Palette.paper,
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.t('doc.av.addTimes')),
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
                    children: [
                      Text(
                        l10n.t('doc.av.subtitle'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),

                      // ── Days away ──
                      const SizedBox(height: 24),
                      SectionHeader(
                        title: l10n.t('doc.av.daysAway'),
                        actionLabel: l10n.t('doc.av.markAway'),
                        onAction: _addLeave,
                      ),
                      Text(
                        l10n.t('doc.av.daysAwaySub'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Palette.inkSoft,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_leaves.isEmpty)
                        Text(
                          l10n.t('doc.av.noLeave'),
                          style: const TextStyle(fontSize: 12.5, color: Palette.inkSoft),
                        )
                      else
                        for (final leave in _leaves)
                          _LeaveRow(
                            leave: leave,
                            busy: _busyId == leave.id,
                            onRemove: () => _removeLeave(leave),
                          ),

                      // ── Open times ──
                      const SizedBox(height: 28),
                      SectionHeader(title: l10n.t('doc.av.myTimes')),
                      if (days.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Palette.paperDim,
                            borderRadius: BorderRadius.circular(Palette.radiusCard),
                          ),
                          child: EmptyState(
                            icon: Icons.schedule_outlined,
                            title: l10n.t('doc.av.noTimes'),
                            message: l10n.t('doc.av.noTimesSub'),
                          ),
                        )
                      else
                        for (final day in days) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 16, bottom: 10),
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
                            _SlotRow(
                              slot: slot,
                              busy: _busyId == slot.id,
                              onRemove: () => _removeSlot(slot),
                            ),
                        ],
                    ],
                  ),
                ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.slot, required this.busy, required this.onRemove});

  final Slot slot;
  final bool busy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final booked = slot.status == 'booked';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
        decoration: BoxDecoration(
          border: Border.all(color: Palette.line),
          borderRadius: BorderRadius.circular(Palette.radiusSm),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Fmt.time(slot.time),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Palette.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${slot.durationMinutes.round()} min · '
                    '${slot.isOnline ? l10n.t('book.online') : l10n.t('book.inClinic')}'
                    '${slot.service != null ? ' · ${slot.service}' : ''}',
                    style: const TextStyle(fontSize: 11.5, color: Palette.inkSoft),
                  ),
                ],
              ),
            ),
            // A booked time is not removable here, and should not look as
            // though it might be — behind it is a patient who has to be
            // rescheduled, not a row to be tidied away.
            if (booked)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: StatusPill(status: 'confirmed', label: l10n.t('doc.av.booked')),
              )
            else
              IconButton(
                icon: busy
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline_rounded, size: 19),
                color: Palette.inkSoft,
                onPressed: busy ? null : onRemove,
              ),
          ],
        ),
      ),
    );
  }
}

class _LeaveRow extends StatelessWidget {
  const _LeaveRow({required this.leave, required this.busy, required this.onRemove});

  final Leave leave;
  final bool busy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF3E2),
          borderRadius: BorderRadius.circular(Palette.radiusSm),
        ),
        child: Row(
          children: [
            const Icon(Icons.flight_takeoff_rounded, size: 18, color: Palette.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    leave.isSingleDay
                        ? Fmt.dateLong(leave.from)
                        : '${Fmt.date(leave.from)} → ${Fmt.date(leave.to)}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Palette.ink,
                    ),
                  ),
                  if (leave.reason != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      leave.reason!,
                      style: const TextStyle(fontSize: 11.5, color: Palette.inkSoft),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: busy
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.close_rounded, size: 18),
              color: Palette.inkSoft,
              onPressed: busy ? null : onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

// ── The two sheets ──────────────────────────────────────────────────────────

class _SlotDraft {
  const _SlotDraft({
    required this.date,
    required this.times,
    required this.mode,
    required this.durationMinutes,
    this.service,
  });

  final String date;
  final List<String> times;
  final String mode;
  final int durationMinutes;
  final String? service;
}

/// Opening times, a whole morning at once.
///
/// The times are generated from a start, an end and a gap rather than typed
/// one by one, because "I'm free 9 to 1 on Tuesday" is how a doctor actually
/// thinks about it — and typing eight separate times is eight chances to
/// mistype one.
class _AddTimesSheet extends StatefulWidget {
  const _AddTimesSheet({required this.services});

  final List<Service> services;

  @override
  State<_AddTimesSheet> createState() => _AddTimesSheetState();
}

class _AddTimesSheetState extends State<_AddTimesSheet> {
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 13, minute: 0);
  int _duration = 30;
  String _mode = 'online';
  String? _service;

  List<String> get _times {
    final out = <String>[];
    var minutes = _start.hour * 60 + _start.minute;
    final endMinutes = _end.hour * 60 + _end.minute;
    // `+ _duration <=` rather than `<`: a slot that would run past the end
    // time is not a slot the doctor said they were free for.
    while (minutes + _duration <= endMinutes && out.length < 24) {
      final h = (minutes ~/ 60).toString().padLeft(2, '0');
      final m = (minutes % 60).toString().padLeft(2, '0');
      out.add('$h:$m');
      minutes += _duration;
    }
    return out;
  }

  String get _dateIso =>
      '${_date.year.toString().padLeft(4, '0')}-'
      '${_date.month.toString().padLeft(2, '0')}-'
      '${_date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final urdu = context.isUrdu;
    final times = _times;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('doc.av.addTimes'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),

              _PickerRow(
                label: l10n.t('doc.av.day'),
                value: Fmt.dateLong(_dateIso),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 180)),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: _PickerRow(
                      label: l10n.t('doc.av.from'),
                      value: _start.format(context),
                      onTap: () async {
                        final picked =
                            await showTimePicker(context: context, initialTime: _start);
                        if (picked != null) setState(() => _start = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PickerRow(
                      label: l10n.t('doc.av.to'),
                      value: _end.format(context),
                      onTap: () async {
                        final picked =
                            await showTimePicker(context: context, initialTime: _end);
                        if (picked != null) setState(() => _end = picked);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),
              Text(
                l10n.t('doc.av.each'),
                style: const TextStyle(fontSize: 12, color: Palette.inkSoft),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final d in const [15, 20, 30, 45, 60])
                    ChoiceChip(
                      label: Text('$d min'),
                      selected: _duration == d,
                      onSelected: (_) => setState(() => _duration = d),
                    ),
                ],
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ModeButton(
                      label: l10n.t('book.online'),
                      icon: Icons.videocam_outlined,
                      selected: _mode == 'online',
                      onTap: () => setState(() => _mode = 'online'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ModeButton(
                      label: l10n.t('book.inClinic'),
                      icon: Icons.local_hospital_outlined,
                      selected: _mode == 'in-clinic',
                      onTap: () => setState(() => _mode = 'in-clinic'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                // `value:` rather than `initialValue:` — the newer spelling
                // only exists on recent Flutter, and a deprecation warning is
                // a far cheaper mistake than a build that will not compile.
                // ignore: deprecated_member_use
                value: _service,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.t('doc.av.service')),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l10n.t('doc.av.anyService')),
                  ),
                  for (final s in widget.services)
                    DropdownMenuItem<String?>(
                      value: s.name,
                      child: Text(s.displayName(urdu), overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _service = v),
              ),

              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Palette.paperDim,
                  borderRadius: BorderRadius.circular(Palette.radiusSm),
                ),
                child: Text(
                  times.isEmpty
                      ? l10n.t('doc.av.noneFit')
                      : '${times.length} ${l10n.t('doc.av.willOpen')}\n'
                          '${times.map(Fmt.time).join(' · ')}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Palette.inkSoft,
                    height: 1.6,
                  ),
                ),
              ),

              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: times.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(
                            _SlotDraft(
                              date: _dateIso,
                              times: times,
                              mode: _mode,
                              durationMinutes: _duration,
                              service: _service,
                            ),
                          ),
                  child: Text(l10n.t('doc.av.openThem')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaveDraft {
  const _LeaveDraft({required this.from, required this.to, this.reason});
  final String from;
  final String to;
  final String? reason;
}

class _AddLeaveSheet extends StatefulWidget {
  const _AddLeaveSheet();

  @override
  State<_AddLeaveSheet> createState() => _AddLeaveSheetState();
}

class _AddLeaveSheetState extends State<_AddLeaveSheet> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now(),
  );
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('doc.av.markAway'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.t('doc.av.daysAwaySub'),
              style: const TextStyle(fontSize: 12.5, color: Palette.inkSoft, height: 1.55),
            ),
            const SizedBox(height: 18),
            _PickerRow(
              label: l10n.t('doc.av.dates'),
              value: _iso(_range.start) == _iso(_range.end)
                  ? Fmt.dateLong(_iso(_range.start))
                  : '${Fmt.date(_iso(_range.start))} → ${Fmt.date(_iso(_range.end))}',
              onTap: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  initialDateRange: _range,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _range = picked);
              },
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _reason,
              decoration: InputDecoration(
                labelText: '${l10n.t('doc.av.reason')} (${l10n.t('common.optional')})',
                hintText: l10n.t('doc.av.reasonHint'),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  _LeaveDraft(
                    from: _iso(_range.start),
                    to: _iso(_range.end),
                    reason: _reason.text.trim(),
                  ),
                ),
                child: Text(l10n.t('doc.av.markAway')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Palette.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Palette.line),
            borderRadius: BorderRadius.circular(Palette.radiusSm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Palette.inkSoft),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Palette.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE7F2EC) : Palette.paper,
      borderRadius: BorderRadius.circular(Palette.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Palette.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? Palette.indigo : Palette.line,
              width: selected ? 1.6 : 1,
            ),
            borderRadius: BorderRadius.circular(Palette.radiusSm),
          ),
          child: Column(
            children: [
              Icon(icon, size: 19, color: selected ? Palette.indigoDeep : Palette.inkSoft),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Palette.indigoDeep : Palette.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
