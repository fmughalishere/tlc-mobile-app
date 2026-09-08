import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatting.dart';
import '../../core/palette.dart';
import '../../data/app_data.dart';
import '../../data/repository.dart';
import '../../i18n/strings.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

/// Booking the next visit, at the end of this one.
///
/// ── Why the new appointment is not "confirmed" ──
///
/// The doctor picks the time and the server holds the slot, but the patient
/// has not paid yet — so it lands as **awaiting-payment**, with a deadline
/// after which the hold lapses and the slot is freed.
///
/// That is a different state from "pending", which means the clinic will
/// phone. Here the next move belongs to the patient. Showing both under one
/// label would tell the wrong person to act, which is why the website
/// separated them and why this screen says so plainly before the doctor
/// commits to a time.
class FollowUpScreen extends StatefulWidget {
  const FollowUpScreen({super.key, required this.appointment});

  final Appointment appointment;

  @override
  State<FollowUpScreen> createState() => _FollowUpScreenState();
}

class _FollowUpScreenState extends State<FollowUpScreen> {
  final _repo = Repository();
  final _note = TextEditingController();

  Slot? _selected;
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    _repo.close();
    super.dispose();
  }

  /// Only this doctor's own open times.
  ///
  /// Filtered by `doctorId` rather than by service: a follow-up is with the
  /// same doctor by definition, and restricting it to the original service
  /// would hide the slots a doctor deliberately left open to anything.
  Future<List<Slot>> _loadSlots() {
    return _repo.availableSlots(doctorId: widget.appointment.doctorId);
  }

  Future<void> _book() async {
    final slot = _selected;
    if (slot == null) return;
    final l10n = context.read<LocaleController>();
    final data = context.read<AppData>();

    setState(() => _saving = true);
    try {
      await _repo.scheduleFollowUp(
        widget.appointment.id,
        slotId: slot.id,
        note: _note.text,
      );
      await data.refreshAppointments();
      if (!mounted) return;
      showToast(context, l10n.t('doc.fu.booked'));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final a = widget.appointment;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('doc.followUp'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Palette.paperDim,
                borderRadius: BorderRadius.circular(Palette.radiusCard),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.patientName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Palette.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${l10n.t('doc.fu.after')} ${a.service} · ${Fmt.date(a.date)}',
                    style: const TextStyle(fontSize: 12.5, color: Palette.inkSoft),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: AsyncView<List<Slot>>(
              load: _loadSlots,
              builder: (context, slots, reload) {
                if (slots.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 50, 24, 24),
                    children: [
                      EmptyState(
                        icon: Icons.event_busy_outlined,
                        title: l10n.t('doc.fu.noSlots'),
                        message: l10n.t('doc.fu.noSlotsSub'),
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
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  children: [
                    Text(
                      l10n.t('doc.fu.pickTime'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 14),
                    for (final day in days) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10, top: 6),
                        child: Text(
                          Fmt.dateLong(day),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Palette.ink,
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: 9,
                        runSpacing: 9,
                        children: [
                          for (final slot in byDay[day]!)
                            _TimeChip(
                              slot: slot,
                              selected: _selected?.id == slot.id,
                              onTap: () => setState(() => _selected = slot),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 6),
                    TextField(
                      controller: _note,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText:
                            '${l10n.t('doc.fu.note')} (${l10n.t('common.optional')})',
                        hintText: l10n.t('doc.fu.noteHint'),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDF3E2),
                      borderRadius: BorderRadius.circular(Palette.radiusSm),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 17, color: Palette.warning),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            l10n.t('doc.fu.paymentNote'),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Palette.warning,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (_selected == null || _saving) ? null : _book,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Palette.paper),
                              ),
                            )
                          : Text(
                              _selected == null
                                  ? l10n.t('doc.fu.pickFirst')
                                  : '${l10n.t('doc.fu.book')} · '
                                      '${Fmt.date(_selected!.date)} ${Fmt.time(_selected!.time)}',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.slot, required this.selected, required this.onTap});

  final Slot slot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Palette.indigoDeep : Palette.paper,
      borderRadius: BorderRadius.circular(Palette.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Palette.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? Palette.indigoDeep : Palette.line,
            ),
            borderRadius: BorderRadius.circular(Palette.radiusSm),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Fmt.time(slot.time),
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? Palette.paper : Palette.indigoDeep,
                ),
              ),
              Text(
                slot.isOnline ? 'online' : 'in clinic',
                style: TextStyle(
                  fontSize: 10.5,
                  color: selected ? Palette.paper : Palette.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
