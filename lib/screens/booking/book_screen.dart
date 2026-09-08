import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatting.dart';
import '../../core/palette.dart';
import '../../core/session.dart';
import '../../data/app_data.dart';
import '../../data/repository.dart';
import '../../i18n/strings.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

/// Booking, in four steps.
///
/// ── Two things the server decides, not this screen ──
///
/// **The time.** The patient picks a *slot*, and the server reads the date,
/// the time and the doctor off that slot document inside a transaction. The
/// app never sends a date. That is what stops two people booking the same
/// 3pm: the second one's transaction sees `status != "available"` and fails
/// with a message saying so, which is a far better outcome than two patients
/// arriving for the same appointment.
///
/// **The money.** This flow books with `bookingType: "call-back"` — the unpaid
/// path, where the clinic phones to confirm and takes payment. That is a
/// deliberate choice for the first version: taking a card payment needs the
/// gateway's own hosted flow, and a booking that reaches the clinic and gets a
/// phone call is a real booking, not a placeholder. The price is still shown
/// at every step so nobody is surprised by it later.
class BookScreen extends StatefulWidget {
  const BookScreen({super.key, this.preselected});

  final Service? preselected;

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  final _repo = Repository();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  final _preferredWhen = TextEditingController();

  int _step = 0;
  Service? _service;
  String _mode = 'online';
  Slot? _slot;

  /// True once the patient has chosen to ask the clinic to arrange a time
  /// rather than pick from the (empty) list.
  bool _requesting = false;

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.preselected;
    if (_service != null) _step = 1;

    // Prefilled from the account, and still editable: the person booking is
    // sometimes not the person who made the account — a daughter booking for
    // her mother needs to put her mother's name on it.
    final session = context.read<Session>();
    _name.text = session.name;
    final profilePhone = session.profile?['phone'];
    if (profilePhone is String) _phone.text = Fmt.phone(profilePhone);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    _preferredWhen.dispose();
    _repo.close();
    super.dispose();
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _error = null;
      if (_step == 3 && _requesting) {
        _requesting = false;
        _step = 2;
        return;
      }
      _step -= 1;
      // Stepping back past the slot list invalidates the chosen slot — a slot
      // picked for "online" must not survive a switch to "at the clinic".
      if (_step < 3) _slot = null;
    });
  }

  Future<void> _submit() async {
    final service = _service;
    if (service == null) return;

    // Read once, up front. Everything below this point is across an `await`,
    // and reaching for the dictionary through `context` after one is how a
    // widget ends up using a BuildContext that has been disposed.
    final l10n = context.read<LocaleController>();
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.t('auth.needName'));
      return;
    }

    // The clinic rings this number to confirm every unpaid booking, so a
    // booking without a usable one is a booking nobody can complete.
    final phone = Fmt.toE164(_phone.text);
    if (phone == null) {
      setState(() => _error = l10n.t('auth.needPhone'));
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (_requesting) {
        await _repo.requestAppointment(
          service: service.name,
          patientName: name,
          patientPhone: phone,
          preferredWhen: _preferredWhen.text.trim(),
          notes: _notes.text.trim(),
        );
      } else {
        final slot = _slot;
        if (slot == null) return;
        await _repo.book(
          service: service.name,
          slotId: slot.id,
          patientName: name,
          patientPhone: phone,
          mode: slot.isOnline ? 'video' : 'in-person',
          amount: service.payableNow,
          notes: _notes.text.trim(),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      showToast(
        context,
        _requesting ? l10n.t('book.requested') : l10n.t('book.booked'),
      );
    } on ApiException catch (e) {
      // A 409 means somebody else took the slot between the list loading and
      // this tap. Sending the patient back to a refreshed list is the only
      // useful response — retrying the same slot cannot succeed.
      setState(() {
        _error = e.message;
        if (e.statusCode == 409) {
          _slot = null;
          _step = 2;
        }
      });
    } catch (e) {
      setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    const titles = [
      'book.step1',
      'book.step2',
      'book.step3',
      'book.step4',
    ];

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _back,
          ),
          title: Text(l10n.t('book.title')),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(38),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.t(titles[_step]),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Palette.indigoDeep,
                      ),
                    ),
                  ),
                  Text(
                    '${_step + 1} / 4',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontSize: 12, color: Palette.inkSoft),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            LinearProgressIndicator(
              value: (_step + 1) / 4,
              minHeight: 3,
              backgroundColor: Palette.mist,
            ),
            Expanded(child: _buildStep(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return _ServiceStep(
          onPick: (service) => setState(() {
            _service = service;
            _step = 1;
          }),
        );
      case 1:
        return _ModeStep(
          service: _service!,
          selected: _mode,
          onPick: (mode) => setState(() {
            _mode = mode;
            _step = 2;
          }),
        );
      case 2:
        return _SlotStep(
          repo: _repo,
          service: _service!,
          mode: _mode,
          onPick: (slot) => setState(() {
            _slot = slot;
            _requesting = false;
            _step = 3;
          }),
          onRequestInstead: () => setState(() {
            _requesting = true;
            _slot = null;
            _step = 3;
          }),
        );
      default:
        return _ConfirmStep(
          service: _service!,
          slot: _slot,
          requesting: _requesting,
          name: _name,
          phone: _phone,
          notes: _notes,
          preferredWhen: _preferredWhen,
          submitting: _submitting,
          error: _error,
          onSubmit: _submit,
        );
    }
  }
}

// ── Step 1: the service ─────────────────────────────────────────────────────

class _ServiceStep extends StatelessWidget {
  const _ServiceStep({required this.onPick});

  final void Function(Service) onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final urdu = context.isUrdu;
    // Already loaded — the catalogue was fetched at launch, so the first step
    // of booking has no wait in it at all.
    final data = context.watch<AppData>();

    if (!data.servicesLoaded && data.servicesLoading) return const LoadingView();

    if (data.services.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
        children: [
          EmptyState(
            icon: Icons.medical_services_outlined,
            title: l10n.t('services.empty'),
          ),
          const SizedBox(height: 20),
          Center(
            child: OutlinedButton(
              onPressed: data.refreshServices,
              child: Text(l10n.t('common.retry')),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        for (final service in data.services)
          ChoiceCard(
            title: service.displayName(urdu),
            subtitle: service.price == null
                ? service.displayShort(urdu)
                : Fmt.money(service.price),
            trailing: const Icon(Icons.chevron_right_rounded, color: Palette.inkSoft),
            onTap: () => onPick(service),
          ),
      ],
    );
  }
}

// ── Step 2: online or in the clinic ─────────────────────────────────────────

class _ModeStep extends StatelessWidget {
  const _ModeStep({
    required this.service,
    required this.selected,
    required this.onPick,
  });

  final Service service;
  final String selected;
  final void Function(String) onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final urdu = context.isUrdu;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          service.displayName(urdu),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 20),
        ChoiceCard(
          title: l10n.t('book.online'),
          subtitle: l10n.t('book.onlineSub'),
          selected: selected == 'online',
          leading: const Icon(Icons.videocam_outlined, color: Palette.indigo),
          onTap: () => onPick('online'),
        ),
        ChoiceCard(
          title: l10n.t('book.inClinic'),
          subtitle: l10n.t('book.inClinicSub'),
          selected: selected == 'in-clinic',
          leading: const Icon(Icons.local_hospital_outlined, color: Palette.indigo),
          onTap: () => onPick('in-clinic'),
        ),
      ],
    );
  }
}

// ── Step 3: the time ────────────────────────────────────────────────────────

class _SlotStep extends StatelessWidget {
  const _SlotStep({
    required this.repo,
    required this.service,
    required this.mode,
    required this.onPick,
    required this.onRequestInstead,
  });

  final Repository repo;
  final Service service;
  final String mode;
  final void Function(Slot) onPick;
  final VoidCallback onRequestInstead;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AsyncView<List<Slot>>(
      load: () => repo.availableSlots(service: service.name, mode: mode),
      builder: (context, slots, reload) {
        if (slots.isEmpty) {
          // Not a dead end. The clinic's own booking flow has this same
          // escape hatch, because "no times" usually means "no doctor
          // covering this has opened their calendar yet", not "never".
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
            children: [
              EmptyState(
                icon: Icons.event_busy_outlined,
                title: l10n.t('book.noSlots'),
                message: l10n.t('book.noSlotsSub'),
              ),
              const SizedBox(height: 26),
              FilledButton(
                onPressed: onRequestInstead,
                child: Text(l10n.t('book.requestInstead')),
              ),
            ],
          );
        }

        // Grouped by day. A flat list of thirty times with the date repeated
        // on each one is unreadable; a patient scans for the day first.
        final days = <String>[];
        final byDay = <String, List<Slot>>{};
        for (final slot in slots) {
          if (!byDay.containsKey(slot.date)) {
            byDay[slot.date] = [];
            days.add(slot.date);
          }
          byDay[slot.date]!.add(slot);
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          itemCount: days.length + 1,
          itemBuilder: (context, i) {
            if (i == days.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Center(
                  child: TextButton(
                    onPressed: onRequestInstead,
                    child: Text(l10n.t('book.requestInstead')),
                  ),
                ),
              );
            }

            final day = days[i];
            final daySlots = byDay[day]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 22, bottom: 12),
                  child: Text(
                    Fmt.dateLong(day),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Palette.ink,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final slot in daySlots)
                      _SlotChip(slot: slot, onTap: () => onPick(slot)),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({required this.slot, required this.onTap});

  final Slot slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Palette.paper,
      borderRadius: BorderRadius.circular(Palette.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Palette.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            border: Border.all(color: Palette.line),
            borderRadius: BorderRadius.circular(Palette.radiusSm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Fmt.time(slot.time),
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Palette.indigoDeep,
                ),
              ),
              if (slot.doctorName.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  slot.doctorName,
                  style: const TextStyle(fontSize: 11, color: Palette.inkSoft),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step 4: confirm ─────────────────────────────────────────────────────────

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    required this.service,
    required this.slot,
    required this.requesting,
    required this.name,
    required this.phone,
    required this.notes,
    required this.preferredWhen,
    required this.submitting,
    required this.error,
    required this.onSubmit,
  });

  final Service service;
  final Slot? slot;
  final bool requesting;
  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController notes;
  final TextEditingController preferredWhen;
  final bool submitting;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final urdu = context.isUrdu;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Palette.paperDim,
            borderRadius: BorderRadius.circular(Palette.radiusCard),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('book.summary'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Palette.crimson,
                ),
              ),
              const SizedBox(height: 10),
              DetailRow(
                label: l10n.t('book.service'),
                value: service.displayName(urdu),
                emphasis: true,
              ),
              if (slot != null) ...[
                DetailRow(
                  label: l10n.t('book.when'),
                  value: '${Fmt.dateLong(slot!.date)} · ${Fmt.time(slot!.time)}',
                ),
                if (slot!.doctorName.isNotEmpty)
                  DetailRow(label: l10n.t('book.doctor'), value: slot!.doctorName),
                DetailRow(
                  label: l10n.t('book.howSeen'),
                  value: slot!.isOnline ? l10n.t('book.online') : l10n.t('book.inClinic'),
                ),
              ] else
                DetailRow(
                  label: l10n.t('book.when'),
                  value: l10n.t('appt.notScheduled'),
                ),
              if (service.price != null)
                DetailRow(
                  label: l10n.t('services.price'),
                  value: Fmt.money(service.price),
                ),
            ],
          ),
        ),

        const SizedBox(height: 22),
        TextField(
          controller: name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: l10n.t('book.yourName')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: l10n.t('book.yourPhone'),
            hintText: '0310 040 4444',
          ),
        ),

        if (requesting) ...[
          const SizedBox(height: 12),
          TextField(
            controller: preferredWhen,
            decoration: InputDecoration(
              labelText: l10n.t('book.preferredWhen'),
              hintText: l10n.t('book.preferredWhenHint'),
            ),
          ),
        ],

        const SizedBox(height: 12),
        TextField(
          controller: notes,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: '${l10n.t('book.notes')} (${l10n.t('common.optional')})',
            alignLabelWithHint: true,
          ),
        ),

        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFDF3E2),
            borderRadius: BorderRadius.circular(Palette.radiusSm),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: Palette.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.t('book.payLater'),
                  style: const TextStyle(fontSize: 12.5, color: Palette.warning, height: 1.5),
                ),
              ),
            ],
          ),
        ),

        if (error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Palette.dangerSoft,
              borderRadius: BorderRadius.circular(Palette.radiusSm),
            ),
            child: Text(
              error!,
              style: const TextStyle(color: Palette.crimsonDeep, fontSize: 13, height: 1.5),
            ),
          ),
        ],

        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: submitting ? null : onSubmit,
            child: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Palette.paper),
                    ),
                  )
                : Text(l10n.t('book.submit')),
          ),
        ),
      ],
    );
  }
}
