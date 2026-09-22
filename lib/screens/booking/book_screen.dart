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
import 'payment_screen.dart';

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
/// **The money.** Two paths, and the patient chooses on the last step.
///
/// *Pay now* asks the clinic's server to start a payment, then opens the
/// gateway's own hosted page in a WebView. The appointment is not created
/// here at all — the server creates it when the gateway's callback arrives
/// carrying a signature it can verify. So this screen cannot produce a paid
/// appointment by getting something wrong, and a patient who closes the app
/// mid-payment still ends up with the right outcome: the server either
/// finalises the booking or releases the slot.
///
/// *Pay when the clinic calls* is the original unpaid path, and it stays.
/// Many of this clinic's patients have no card, and an app that quietly made
/// online payment the only way in would lock them out of the service rather
/// than modernise it. It is also the fallback when no gateway is switched on:
/// `/api/payments/methods` answering with an empty list is not an error, it
/// just means today the clinic takes payment by phone.
///
/// The price is shown at every step either way, so nobody is surprised by it.
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
  final _coupon = TextEditingController();

  int _step = 0;
  Service? _service;
  String _mode = 'online';
  Slot? _slot;

  /// True once the patient has chosen to ask the clinic to arrange a time
  /// rather than pick from the (empty) list.
  bool _requesting = false;

  bool _submitting = false;
  String? _error;

  /// The ways to pay the clinic can take today, straight from the server.
  /// Empty is a normal state, not a broken one — see the note above.
  List<PaymentMethod> _methods = const [];
  String? _gateway;

  /// True when the patient wants to pay now. Set to true the moment a usable
  /// method arrives, because a patient who can pay usually wants the time
  /// confirmed there and then rather than waiting for a phone call — and the
  /// other option is one tap away, clearly labelled, on the same screen.
  bool _payNow = false;

  /// "new" or "follow-up" — the website's first question. It decides which
  /// services are listed (follow-ups are their own priced services) and
  /// whether a coupon can be used, since the clinic's coupons are for first
  /// visits only.
  String _patientType = 'new';

  /// How an online consultation happens: "video", "audio" or "chat". The same
  /// three the website offers; a chat booking opens the in-app chat.
  String _channel = 'video';

  /// The coupon the patient applied, if any. Its discount is shown as an
  /// estimate — the server prices the booking and its figure is charged.
  CouponCheck? _appliedCoupon;
  bool _checkingCoupon = false;
  String? _couponError;

  @override
  void initState() {
    super.initState();
    _service = widget.preselected;
    if (_service != null) {
      _step = 1;
      _patientType = _isFollowUpService(_service!) ? 'follow-up' : 'new';
    }

    // Prefilled from the account, and still editable: the person booking is
    // sometimes not the person who made the account — a daughter booking for
    // her mother needs to put her mother's name on it.
    final session = context.read<Session>();
    _name.text = session.name;
    final profilePhone = session.profile?['phone'];
    if (profilePhone is String) _phone.text = Fmt.phone(profilePhone);

    _loadMethods();
  }

  /// Asked for once, as the screen opens, so the answer is already here by the
  /// time the patient reaches the last step. Deliberately not awaited and
  /// deliberately silent on failure: this list decides whether an extra option
  /// is offered, and a clinic that cannot be asked simply offers the phone
  /// call — which is exactly what it did before any of this existed.
  /// True once the patient has answered the pay-now question themselves.
  /// See [_loadMethods].
  bool _payNowTouched = false;

  Future<void> _loadMethods() async {
    try {
      final methods = await _repo.paymentMethods();
      if (!mounted || methods.isEmpty) return;
      setState(() {
        _methods = methods;
        _gateway ??= methods.first.id;
        // Only a default, never an override. This request is not awaited, so
        // it can land after the patient has already reached step 4 and chosen
        // "pay when the clinic calls" — and it used to flip that answer back
        // to "pay now", which then opened a gateway for somebody who had asked
        // not to be sent to one.
        if (!_payNowTouched) _payNow = true;
      });
    } catch (_) {
      // Nothing to say and nothing to retry. See above.
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    _preferredWhen.dispose();
    _coupon.dispose();
    _repo.close();
    super.dispose();
  }

  /// Coupons are for new patients, on a service with something to pay.
  bool get _couponAllowed =>
      _patientType == 'new' && (_service?.payableNow ?? 0) > 0;

  CouponCheck? get _activeCoupon => _couponAllowed ? _appliedCoupon : null;

  /// What the app expects the patient to pay now, after any coupon. Shown on
  /// screen and sent along, but only as an estimate — see [_payFor].
  num get _payable {
    final base = _service?.payableNow ?? 0;
    final coupon = _activeCoupon;
    return coupon == null ? base : base - coupon.discountOn(base);
  }

  String? get _sessionType {
    final service = _service;
    if (_patientType != 'follow-up' || service == null) return null;
    return _guessSessionType(service);
  }

  void _clearCoupon() {
    _appliedCoupon = null;
    _couponError = null;
    _coupon.clear();
  }

  Future<void> _applyCoupon() async {
    final code = _coupon.text.trim();
    if (code.isEmpty || _checkingCoupon) return;

    final l10n = context.read<LocaleController>();
    final email = context.read<Session>().user?.email ??
        context.read<AppData>().profile?.email;

    setState(() {
      _checkingCoupon = true;
      _couponError = null;
      _appliedCoupon = null;
    });

    try {
      final check = await _repo.checkCoupon(code, patientEmail: email);
      if (!mounted) return;
      setState(() {
        if (check.valid) {
          _appliedCoupon = check;
        } else {
          _couponError = l10n.t(check.reason ?? 'book.couponInvalid');
        }
      });
      if (check.valid) showToast(context, l10n.t('book.couponApplied'));
    } catch (e) {
      if (mounted) setState(() => _couponError = errorText(e));
    } finally {
      if (mounted) setState(() => _checkingCoupon = false);
    }
  }

  void _removeCoupon() => setState(_clearCoupon);

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

  /// True when this tap should open a gateway rather than book unpaid.
  ///
  /// All four conditions, because each one on its own has been the cause of a
  /// payment screen opening for nothing: a request with no slot to pay for, a
  /// free service, a clinic with no gateway switched on, and the patient
  /// having chosen the phone call.
  bool get _paying =>
      _payNow &&
      !_requesting &&
      _gateway != null &&
      _methods.isNotEmpty &&
      (_service?.payableNow ?? 0) > 0 &&
      // A coupon that takes the whole amount leaves nothing for a gateway to
      // charge — the server refuses that — so it is booked unpaid instead.
      _payable > 0;

  /// Hands the patient to the gateway and deals with whichever of the three
  /// things happened.
  ///
  /// Note what is *not* here: no appointment is created, no payment status is
  /// written, and nothing the WebView said is believed. The server made the
  /// decision when the gateway's signed callback reached it. All this does is
  /// read the outcome and then refresh from the server anyway — which is also
  /// what covers the case of a patient who paid and killed the app before the
  /// result page loaded.
  Future<void> _payFor(Service service, Slot slot, String name, String phone) async {
    final l10n = context.read<LocaleController>();
    final data = context.read<AppData>();
    final method = _methods.firstWhere(
      (m) => m.id == _gateway,
      orElse: () => _methods.first,
    );

    final expected = _payable;
    final handover = await _repo.startNewBookingPayment(
      gateway: method.id,
      service: service.name,
      slot: slot,
      patientName: name,
      amount: expected,
      mode: slot.isOnline ? _channel : 'in-person',
      patientPhone: phone,
      notes: _notes.text.trim(),
      patientType: _patientType,
      sessionType: _sessionType,
      couponCode: _activeCoupon?.code,
    );

    if (!mounted) return;

    // The server's figure wins. It re-prices every booking from the service
    // and coupon documents, and a coupon it would not honour is dropped rather
    // than refused. `/api/payments/start` does not return the amount as such,
    // but the wallet forms carry it, so where it can be read it is the figure
    // shown — and if it differs from what this screen said, the patient is
    // told before they pay, not after. (A card handover is a bare URL; the
    // gateway's own page shows the amount there.)
    final charged = _serverAmount(handover) ?? expected;
    if (charged.round() != expected.round()) {
      showToast(
        context,
        l10n.t('book.priceChanged').replaceAll('{amount}', Fmt.money(charged)),
      );
    }

    final result = await Navigator.of(context).push<PaymentResult>(
      MaterialPageRoute<PaymentResult>(
        builder: (_) => PaymentScreen(
          handover: handover,
          methodLabel: method.label,
          amountPkr: charged,
        ),
      ),
    );

    // Always, and before anything is decided on screen. Whether they paid,
    // cancelled or the page fell over, the truth is now on the server.
    await data.refreshAppointments();
    if (!mounted) return;

    if (result?.paid == true) {
      Navigator.of(context).pop();
      showToast(context, l10n.t('book.paid'));
      return;
    }

    if (result != null && result.openedInBrowser) {
      // Gone to the phone's own browser. Neither paid nor failed from here —
      // the redirect lands in Chrome, not in the app. The slot stays held and
      // nothing is cleared, so coming back to a confirmed appointment and
      // coming back to finish paying both work.
      setState(() => _error = l10n.t('pay.inBrowser'));
      return;
    }

    if (result == null || result.cancelled) {
      // Backed out. They are still on the confirm step with everything they
      // typed intact, which is the whole reason this does not pop.
      showToast(context, l10n.t('book.payCancelled'), error: true);
      return;
    }

    // Undecided: the server could not tell whether the money arrived. Do not
    // clear the slot and do not invite another attempt — the slot is still
    // held, and a second payment for a charge that may already have gone
    // through is the one mistake that costs a patient real money. They are
    // kept where they are, told what happened, and pointed at the phone.
    if (result.attention) {
      setState(() {
        _error = result.message?.trim().isNotEmpty == true
            ? result.message
            : l10n.t('book.payAttention');
      });
      return;
    }

    // Refused. The slot has been released by the callback, so sending them
    // back to a fresh list is the only honest next step — the time they picked
    // may already be gone.
    setState(() {
      _error = result.message?.trim().isNotEmpty == true
          ? result.message
          : l10n.t('book.payFailed');
      _slot = null;
      _step = 2;
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
        await _repo.requestDoctorAssignment(
          service: service.name,
          patientName: name,
          patientPhone: phone,
          preferredWhen: _preferredWhen.text.trim(),
          notes: _notes.text.trim(),
          mode: _mode == 'in-clinic' ? 'in-person' : _channel,
          amount: _payable,
          patientType: _patientType,
          sessionType: _sessionType,
          couponCode: _activeCoupon?.code,
        );
      } else {
        final slot = _slot;
        if (slot == null) return;

        if (_paying) {
          // Everything from here is the server's and the gateway's. This
          // returns when the patient comes back, whatever they did.
          await _payFor(service, slot, name, phone);
          return;
        }

        await _repo.bookCallBack(
          service: service.name,
          slotId: slot.id,
          patientName: name,
          patientPhone: phone,
          mode: slot.isOnline ? _channel : 'in-person',
          amount: _payable,
          notes: _notes.text.trim(),
          patientType: _patientType,
          sessionType: _sessionType,
          couponCode: _activeCoupon?.code,
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
          patientType: _patientType,
          onPatientType: (type) => setState(() {
            _patientType = type;
            _clearCoupon();
          }),
          onPick: (service) => setState(() {
            if (_service?.id != service.id) _clearCoupon();
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
          methods: _methods,
          payNow: _payNow,
          gateway: _gateway,
          onPayNowChanged: (value) => setState(() {
            _payNow = value;
            _payNowTouched = true;
            _error = null;
          }),
          onGatewayChanged: (id) => setState(() => _gateway = id),
          payable: _payable,
          couponAllowed: _couponAllowed,
          coupon: _coupon,
          appliedCoupon: _activeCoupon,
          checkingCoupon: _checkingCoupon,
          couponError: _couponError,
          onApplyCoupon: _applyCoupon,
          onRemoveCoupon: _removeCoupon,
          showChannel: _slot?.isOnline ?? (_mode == 'online'),
          channel: _channel,
          onChannelChanged: (value) => setState(() => _channel = value),
        );
    }
  }
}

/// Follow-up bookings are ordinary services the clinic files under a
/// "Follow-up" category — the website's rule, word for word
/// (`isFollowUpService` in src/app/patient/book/page.tsx).
bool _isFollowUpService(Service s) {
  final pattern = RegExp('follow|session', caseSensitive: false);
  return pattern.hasMatch(s.category) || pattern.hasMatch(s.name);
}

/// The session length the website records for a follow-up, read off the
/// service's name the same way it does.
String _guessSessionType(Service s) {
  if (s.name.contains('60')) return 'session-60';
  if (s.name.contains('30')) return 'session-30';
  return 'regular-followup';
}

/// The amount the server wrote into a wallet handover, in rupees, or null
/// when this handover does not carry one. JazzCash sends paisa in
/// `pp_Amount`; EasyPaisa sends rupees in `amount`.
num? _serverAmount(PaymentHandover handover) {
  if (handover.kind != 'form') return null;
  final jazz = num.tryParse(handover.fields['pp_Amount'] ?? '');
  if (jazz != null) return jazz / 100;
  final easy = num.tryParse(handover.fields['amount'] ?? '');
  if (easy != null) return easy;
  return null;
}

// ── Step 1: the service ─────────────────────────────────────────────────────

class _ServiceStep extends StatelessWidget {
  const _ServiceStep({
    required this.patientType,
    required this.onPatientType,
    required this.onPick,
  });

  final String patientType;
  final void Function(String) onPatientType;
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

    // The new / follow-up question is only asked when the clinic actually has
    // follow-up services. Without any, every booking is a new one — which is
    // also what the website's filter comes to — and a choice that leads to an
    // empty list is not a choice.
    final hasFollowUps = data.services.any(_isFollowUpService);
    final type = hasFollowUps ? patientType : 'new';
    final visible = hasFollowUps
        ? data.services
            .where((s) => _isFollowUpService(s) == (type == 'follow-up'))
            .toList()
        : data.services;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        if (hasFollowUps) ...[
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment<String>(
                  value: 'new',
                  label: Text(l10n.t('book.newPatient')),
                ),
                ButtonSegment<String>(
                  value: 'follow-up',
                  label: Text(l10n.t('book.followUp')),
                ),
              ],
              selected: {type},
              onSelectionChanged: (picked) {
                if (picked.isNotEmpty) onPatientType(picked.first);
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t(type == 'new' ? 'book.newPatientHint' : 'book.followUpHint'),
            style: const TextStyle(fontSize: 12.5, color: Palette.inkSoft, height: 1.5),
          ),
          const SizedBox(height: 16),
        ],
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: EmptyState(
              icon: Icons.medical_services_outlined,
              title: l10n.t('book.noServicesType'),
            ),
          ),
        for (final service in visible)
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
    required this.methods,
    required this.payNow,
    required this.gateway,
    required this.onPayNowChanged,
    required this.onGatewayChanged,
    required this.payable,
    required this.couponAllowed,
    required this.coupon,
    required this.appliedCoupon,
    required this.checkingCoupon,
    required this.couponError,
    required this.onApplyCoupon,
    required this.onRemoveCoupon,
    required this.showChannel,
    required this.channel,
    required this.onChannelChanged,
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
  final List<PaymentMethod> methods;
  final bool payNow;
  final String? gateway;
  final void Function(bool) onPayNowChanged;
  final void Function(String) onGatewayChanged;

  /// What the app expects to be paid now, after any coupon.
  final num payable;
  final bool couponAllowed;
  final TextEditingController coupon;
  final CouponCheck? appliedCoupon;
  final bool checkingCoupon;
  final String? couponError;
  final VoidCallback onApplyCoupon;
  final VoidCallback onRemoveCoupon;

  /// Video, audio or chat — asked only when the consultation is online.
  final bool showChannel;
  final String channel;
  final void Function(String) onChannelChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final urdu = context.isUrdu;
    final discount = appliedCoupon?.discountOn(service.payableNow) ?? 0;

    // A paid booking needs all three: a time to attach the money to, a price,
    // and somewhere for the money to go.
    final canPay = slot != null && payable > 0 && methods.isNotEmpty;
    final paying = canPay && payNow;

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
              if (appliedCoupon != null && discount > 0) ...[
                DetailRow(
                  label: '${l10n.t('book.discount')} · ${appliedCoupon!.code}',
                  value: '− ${Fmt.money(discount)}',
                ),
                DetailRow(
                  label: l10n.t('book.payable'),
                  value: Fmt.money(payable),
                  emphasis: true,
                ),
              ],
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

        if (showChannel) ...[
          const SizedBox(height: 16),
          Text(
            l10n.t('book.howToMeet'),
            style: const TextStyle(fontSize: 12.5, color: Palette.inkSoft),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in const ['video', 'audio', 'chat'])
                ChoiceChip(
                  label: Text(l10n.t('mode.$option')),
                  selected: channel == option,
                  onSelected: (_) => onChannelChanged(option),
                ),
            ],
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

        if (couponAllowed) ...[
          const SizedBox(height: 16),
          _CouponBox(
            controller: coupon,
            applied: appliedCoupon,
            discount: discount,
            payable: payable,
            checking: checkingCoupon,
            error: couponError,
            onApply: onApplyCoupon,
            onRemove: onRemoveCoupon,
          ),
        ],

        const SizedBox(height: 22),
        if (canPay) ...[
          SectionHeader(title: l10n.t('book.howPay')),
          _PayChoice(
            selected: payNow,
            title: l10n.t('book.payNow'),
            subtitle: l10n.t('book.payNowSub'),
            icon: Icons.lock_outline_rounded,
            trailing: Fmt.money(payable),
            onTap: () => onPayNowChanged(true),
          ),
          if (payNow) ...[
            const SizedBox(height: 2),
            for (final method in methods)
              Padding(
                padding: const EdgeInsets.only(left: 14, bottom: 8),
                child: _MethodRow(
                  method: method,
                  selected: method.id == gateway,
                  onTap: () => onGatewayChanged(method.id),
                ),
              ),
          ],
          const SizedBox(height: 8),
          _PayChoice(
            selected: !payNow,
            title: l10n.t('book.payAtClinic'),
            subtitle: l10n.t('book.payAtClinicSub'),
            icon: Icons.call_outlined,
            onTap: () => onPayNowChanged(false),
          ),
        ] else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Palette.warningSoft,
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
                : Text(
                    paying
                        ? '${l10n.t('book.payNow')} · ${Fmt.money(payable)}'
                        : l10n.t('book.submit'),
                  ),
          ),
        ),
      ],
    );
  }
}

/// "Have a coupon?" — the website's coupon field, on the confirm step.
///
/// Once applied it turns into a line saying what was taken off and what is
/// left to pay, with a way to take it off again. The figure is the app's
/// estimate; the server prices the booking and a code it will not honour is
/// dropped there, with the normal price charged.
class _CouponBox extends StatelessWidget {
  const _CouponBox({
    required this.controller,
    required this.applied,
    required this.discount,
    required this.payable,
    required this.checking,
    required this.error,
    required this.onApply,
    required this.onRemove,
  });

  final TextEditingController controller;
  final CouponCheck? applied;
  final int discount;
  final num payable;
  final bool checking;
  final String? error;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final coupon = applied;

    if (coupon != null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE7F2EC),
          border: Border.all(color: Palette.indigo),
          borderRadius: BorderRadius.circular(Palette.radiusSm),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_offer_outlined, size: 18, color: Palette.indigoDeep),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.t('book.couponAppliedCode').replaceAll('{code}', coupon.code),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Palette.indigoDeep,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n
                        .t('book.couponSaving')
                        .replaceAll('{discount}', Fmt.money(discount))
                        .replaceAll('{total}', Fmt.money(payable)),
                    style: const TextStyle(fontSize: 12, color: Palette.inkSoft, height: 1.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.t('book.couponServerNote'),
                    style: const TextStyle(fontSize: 11.5, color: Palette.inkSoft, height: 1.5),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onRemove,
              child: Text(l10n.t('book.couponRemove')),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('book.coupon'),
          style: const TextStyle(fontSize: 12.5, color: Palette.inkSoft),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onApply(),
                decoration: InputDecoration(
                  hintText: l10n.t('book.couponPlaceholder'),
                  errorText: error,
                  errorMaxLines: 3,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: OutlinedButton(
                onPressed: checking ? null : onApply,
                child: checking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.t('book.apply')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One of the two ways to pay, as a card you tap.
///
/// A radio list rather than a switch, because these are not on/off: they are
/// two different arrangements with two different consequences, and each needs
/// its own sentence saying what happens next. A patient choosing how to part
/// with money should be able to read the choice, not infer it from a toggle's
/// position.
class _PayChoice extends StatelessWidget {
  const _PayChoice({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.trailing,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? const Color(0xFFE7F2EC) : Palette.paper,
        borderRadius: BorderRadius.circular(Palette.radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Palette.radiusCard),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? Palette.indigo : Palette.line,
                width: selected ? 1.6 : 1,
              ),
              borderRadius: BorderRadius.circular(Palette.radiusCard),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: selected ? Palette.indigoDeep : Palette.line,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 16, color: Palette.inkSoft),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Palette.ink,
                              ),
                            ),
                          ),
                          if (trailing != null)
                            Text(
                              trailing!,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Palette.indigoDeep,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Palette.inkSoft,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One gateway inside the "pay now" choice.
///
/// The label and the line under it are the server's words, not the app's —
/// "Debit or credit card · Visa, Mastercard and UnionPay, secured by Safepay"
/// comes from `/api/payments/methods`. That is on purpose: when the clinic is
/// approved for another gateway, it appears here correctly described without
/// anyone updating an app on a patient's phone.
class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  static const _icons = <String, IconData>{
    'safepay': Icons.credit_card_rounded,
    'jazzcash': Icons.account_balance_wallet_outlined,
    'easypaisa': Icons.account_balance_wallet_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Palette.paper,
      borderRadius: BorderRadius.circular(Palette.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Palette.radiusSm),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? Palette.indigo : Palette.line,
              width: selected ? 1.4 : 1,
            ),
            borderRadius: BorderRadius.circular(Palette.radiusSm),
          ),
          child: Row(
            children: [
              Icon(
                _icons[method.id] ?? Icons.payments_outlined,
                size: 19,
                color: selected ? Palette.indigoDeep : Palette.inkSoft,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: selected ? Palette.indigoDeep : Palette.ink,
                      ),
                    ),
                    if (method.blurb.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        method.blurb,
                        style: const TextStyle(fontSize: 11.5, color: Palette.inkSoft),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded, size: 18, color: Palette.indigoDeep),
            ],
          ),
        ),
      ),
    );
  }
}
