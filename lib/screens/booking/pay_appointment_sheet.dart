import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../core/palette.dart';
import '../../data/repository.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import 'payment_screen.dart';

/// Paying for an appointment that already exists.
///
/// ── Why this is separate from the booking flow ──
///
/// A follow-up the doctor scheduled at the end of a visit is not a booking
/// waiting to happen — the slot is already held, the price is already on the
/// appointment, and the only open question is the money. The booking screen's
/// four steps have nothing to ask about here, so this is one sheet: pick a
/// method, pay, done.
///
/// Which methods appear is the server's decision, not this file's. It lists
/// only the gateways whose credentials are actually set, so the day the clinic
/// is approved for a new wallet it appears here without anyone updating an app
/// on a patient's phone — and a gateway the clinic switches off disappears the
/// same way.
///
/// Returns the outcome, or null if the patient closed the sheet without
/// choosing anything.
Future<PaymentResult?> payForAppointment(
  BuildContext context,
  Appointment appointment,
) {
  return showModalBottomSheet<PaymentResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Palette.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _PayAppointmentSheet(appointment: appointment),
  );
}

class _PayAppointmentSheet extends StatefulWidget {
  const _PayAppointmentSheet({required this.appointment});

  final Appointment appointment;

  @override
  State<_PayAppointmentSheet> createState() => _PayAppointmentSheetState();
}

class _PayAppointmentSheetState extends State<_PayAppointmentSheet> {
  final _repo = Repository();

  List<PaymentMethod>? _methods;
  String? _starting;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final methods = await _repo.paymentMethods();
      if (!mounted) return;
      setState(() => _methods = methods);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _methods = const [];
        _error = errorText(e);
      });
    }
  }

  Future<void> _pay(PaymentMethod method) async {
    if (_starting != null) return;
    setState(() {
      _starting = method.id;
      _error = null;
    });

    try {
      final handover = await _repo.startAppointmentPayment(
        gateway: method.id,
        appointmentId: widget.appointment.id,
      );
      if (!mounted) return;

      final result = await Navigator.of(context).push<PaymentResult>(
        MaterialPageRoute<PaymentResult>(
          builder: (_) => PaymentScreen(
            handover: handover,
            methodLabel: method.label,
            amountPkr: widget.appointment.amount,
          ),
        ),
      );
      if (!mounted) return;

      // The sheet closes carrying whatever happened. The screen underneath
      // owns the message and the refresh, because it is the one that knows
      // what list needs reloading.
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = null;
        _error = errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final methods = _methods;
    final busy = _starting != null;

    return SafeArea(
      child: Padding(
        // The keyboard never opens here, but the gesture bar does, and a sheet
        // whose last button sits under it is a button nobody can press.
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Palette.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              l10n.t('pay.chooseMethod'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              widget.appointment.hasSchedule
                  ? '${widget.appointment.service} · '
                      '${Fmt.dateLong(widget.appointment.date)} · '
                      '${Fmt.time(widget.appointment.time)}'
                  : widget.appointment.service,
              style: const TextStyle(fontSize: 12.5, color: Palette.inkSoft),
            ),

            if (widget.appointment.amount > 0) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                decoration: BoxDecoration(
                  color: Palette.paperDim,
                  borderRadius: BorderRadius.circular(Palette.radiusSm),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.t('pay.dueNow'),
                      style: const TextStyle(fontSize: 12.5, color: Palette.inkSoft),
                    ),
                    Text(
                      Fmt.money(widget.appointment.amount),
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Palette.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Palette.dangerSoft,
                  borderRadius: BorderRadius.circular(Palette.radiusSm),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(fontSize: 13, color: Palette.crimsonDeep),
                ),
              ),
            ],

            const SizedBox(height: 16),

            if (methods == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 26),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
              )
            else if (methods.isEmpty)
              // Said plainly and pointed somewhere. A payment sheet with no
              // methods and no explanation reads as a broken app rather than
              // as a clinic that happens to take payment by phone.
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  l10n.t('pay.noMethods'),
                  style: const TextStyle(fontSize: 13.5, height: 1.6, color: Palette.inkSoft),
                ),
              )
            else
              ...methods.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SheetMethodRow(
                    method: m,
                    // The whole list disables together, not just the row that
                    // was tapped: a second method started during the moment
                    // before the payment page opens would be a second payment
                    // against the same appointment.
                    busy: busy,
                    starting: _starting == m.id,
                    onTap: () => _pay(m),
                  ),
                ),
              ),

            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.lock_outline_rounded, size: 13, color: Palette.inkSoft),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    l10n.t('pay.holdNote'),
                    style: const TextStyle(fontSize: 11.5, height: 1.5, color: Palette.inkSoft),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One method. Deliberately drawn from what the server sent — the label and
/// the blurb are the clinic's words, not this file's.
class _SheetMethodRow extends StatelessWidget {
  const _SheetMethodRow({
    required this.method,
    required this.busy,
    required this.starting,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool busy;
  final bool starting;
  final VoidCallback onTap;

  static const _icons = <String, IconData>{
    'safepay': Icons.credit_card_rounded,
    'jazzcash': Icons.account_balance_wallet_outlined,
    'easypaisa': Icons.account_balance_wallet_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: busy && !starting ? 0.5 : 1,
      child: Material(
        color: Palette.paper,
        borderRadius: BorderRadius.circular(Palette.radiusSm),
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(Palette.radiusSm),
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
            decoration: BoxDecoration(
              border: Border.all(color: Palette.line),
              borderRadius: BorderRadius.circular(Palette.radiusSm),
            ),
            child: Row(
              children: [
                Icon(
                  _icons[method.id] ?? Icons.payments_outlined,
                  size: 20,
                  color: Palette.indigoDeep,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method.label,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Palette.ink,
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
                if (starting)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.chevron_right_rounded, size: 20, color: Palette.inkSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
