import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatting.dart';
import '../../core/palette.dart';
import '../../data/chat_repository.dart';
import '../../data/repository.dart';
import '../../i18n/chat_strings.dart';
import '../../i18n/strings.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../booking/pay_appointment_sheet.dart';
import '../chat/chat_screen.dart';
import 'rate_visit_screen.dart';

/// One appointment, everything about it, and the two things a patient can do
/// to it: join the call, or cancel.
///
/// The appointment is passed in rather than re-fetched. It came from a list
/// that loaded moments ago, and the alternative — a spinner on a screen the
/// patient just tapped into — is worse than showing what we already have.
/// After a cancel the screen pops and the list behind it reloads, so nothing
/// stale survives an action.
class AppointmentDetailScreen extends StatefulWidget {
  const AppointmentDetailScreen({super.key, required this.appointment});

  final Appointment appointment;

  @override
  State<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  final _repo = Repository();
  late Appointment _appointment = widget.appointment;
  bool _busy = false;

  @override
  void dispose() {
    _repo.close();
    super.dispose();
  }

  Future<void> _cancel() async {
    final l10n = context.read<LocaleController>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('appt.cancelConfirm')),
        content: Text(l10n.t('appt.cancelConfirmSub')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('appt.keepIt')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Palette.crimsonDeep),
            child: Text(l10n.t('appt.cancel')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await _repo.cancelAppointment(_appointment.id);
      if (!mounted) return;
      showToast(context, l10n.t('appt.cancelled'));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Pays for a follow-up the doctor already booked.
  ///
  /// The appointment is holding a slot and waiting on the money, and until now
  /// the app had no way to send it — a patient could see "waiting for your
  /// payment" and do nothing about it without opening the website. The sheet
  /// offers whichever gateways the server says are switched on, which is the
  /// same list the booking screen uses.
  ///
  /// Nothing here decides whether the payment succeeded. The server does that
  /// when the gateway's callback reaches it; this only reads the answer.
  /// Joins the video session.
  ///
  /// ── Why this is not just opening `roomUrl` ──
  ///
  /// It was, and it could never have worked. The clinic's Daily rooms are
  /// private: the room URL on its own is a door with no key, and Daily says
  /// so in the bluntest way it has — "You are not allowed to join this
  /// meeting. Contact the meeting host for help." Which reads, to a patient,
  /// as the clinic having shut them out of their own appointment.
  ///
  /// The key is a join token, and only the server can mint one. It hands one
  /// back from `/api/appointments/:id/session`, named for whoever asked and
  /// marked host or guest — which is also what stops a patient turning up in
  /// somebody else's consultation with a URL they were forwarded.
  ///
  /// The website has always done this. The app had the call written and never
  /// used it.
  Future<void> _joinCall() async {
    final l10n = context.read<LocaleController>();
    setState(() => _busy = true);

    try {
      final result = await _repo.startSession(_appointment.id);
      if (!mounted) return;

      // The server may have created the room on this very call, so the fresh
      // appointment is kept rather than the copy this screen was opened with.
      setState(() => _appointment = result.appointment);

      final url = result.appointment.roomUrl;
      if (url == null || url.isEmpty) {
        showToast(context, l10n.t('appt.joinNotReady'), error: true);
        return;
      }

      final token = result.joinToken;
      await openUrl(
        context,
        token == null || token.isEmpty ? url : '$url?t=$token',
      );
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Opens the encrypted chat with the doctor. The chat screen starts the
  /// session itself, as the website's "Open chat" button does.
  Future<void> _openChat() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(appointment: _appointment),
      ),
    );
  }

  Future<void> _payNow() async {
    final l10n = context.read<LocaleController>();
    final result = await payForAppointment(context, _appointment);
    if (!mounted || result == null) return;

    if (result.paid) {
      showToast(context, l10n.t('book.paid'));
      // Popped rather than patched in place: the appointment's status,
      // payment state and paid-at all changed on the server at once, and the
      // list behind this screen reloads them together.
      Navigator.of(context).pop();
      return;
    }

    if (result.openedInBrowser) {
      // Paying in Chrome. The result page lands there, so the app is told
      // where to look rather than told an outcome it cannot know.
      showToast(context, l10n.t('pay.inBrowser'));
      return;
    }

    if (result.cancelled) {
      showToast(context, l10n.t('book.payCancelled'), error: true);
      return;
    }

    // Undecided — the server could not tell whether the money arrived. The
    // slot is still held and a second attempt could charge twice, so the
    // message says call the clinic rather than try again.
    showToast(
      context,
      result.message?.trim().isNotEmpty == true
          ? result.message!
          : l10n.t(result.attention ? 'book.payAttention' : 'book.payFailed'),
      error: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final a = _appointment;

    // Money still owed on a time that is being held. `paymentStatus` is
    // checked as well as the status, because a callback can mark an
    // appointment paid a moment before this screen's copy catches up, and
    // offering to pay again is the one mistake worth guarding twice against.
    final canPay = a.awaitingPayment && a.paymentStatus != 'paid';

    // A video room only exists once the session has been started at the other
    // end. Showing the button before that gives the patient a link to nothing.
    final canJoin = a.roomUrl != null &&
        a.roomUrl!.isNotEmpty &&
        a.sessionStatus == 'live';

    // Chat follows the website: only on a chat consultation with a doctor,
    // and only inside the session window. Outside it the button stays, greyed,
    // with the reason underneath, so the patient knows when it will open.
    final showChat = ChatAccess.isChatAppointment(a);
    final chatClosedReason = showChat ? ChatAccess.closedReason(a, asHost: false) : null;

    final canCancel = a.status == 'pending' ||
        a.status == 'confirmed' ||
        a.status == 'awaiting-payment';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('appt.details'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  a.service,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(width: 12),
              StatusPill(status: a.status, label: l10n.status(a.status)),
            ],
          ),

          if (a.needsDoctor) ...[
            const SizedBox(height: 14),
            _Note(
              icon: Icons.pending_outlined,
              text: l10n.t('appt.needsDoctor'),
              tone: Palette.warning,
              background: const Color(0xFFFDF3E2),
            ),
          ],

          if (a.isCancelled && a.cancelReason != null) ...[
            const SizedBox(height: 14),
            _Note(
              icon: Icons.cancel_outlined,
              text: a.cancelReason!,
              tone: Palette.crimsonDeep,
              background: Palette.dangerSoft,
            ),
          ],

          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Palette.paperDim,
              borderRadius: BorderRadius.circular(Palette.radiusCard),
            ),
            child: Column(
              children: [
                DetailRow(
                  label: l10n.t('book.when'),
                  value: a.hasSchedule
                      ? '${Fmt.dateLong(a.date)} · ${Fmt.time(a.time)}'
                      : l10n.t('appt.notScheduled'),
                  emphasis: true,
                ),
                if (a.doctorName != null)
                  DetailRow(label: l10n.t('book.doctor'), value: a.doctorName!),
                DetailRow(
                  label: l10n.t('book.howSeen'),
                  value: a.consultMode == 'in-clinic'
                      ? l10n.t('book.inClinic')
                      : l10n.t('book.online'),
                ),
                if (a.amount > 0)
                  DetailRow(label: l10n.t('appt.amount'), value: Fmt.money(a.amount)),
                DetailRow(
                  label: l10n.t('appt.amount'),
                  value: a.paymentStatus == 'paid'
                      ? l10n.t('appt.paid')
                      : l10n.t('appt.unpaid'),
                ),
                DetailRow(
                  label: l10n.t('appt.bookedOn'),
                  value: Fmt.stamp(a.createdAt),
                ),
              ],
            ),
          ),

          if (a.preferredWhen != null) ...[
            const SizedBox(height: 22),
            SectionHeader(title: l10n.t('book.preferredWhen')),
            Text(a.preferredWhen!, style: Theme.of(context).textTheme.bodyMedium),
          ],

          if (a.notes != null) ...[
            const SizedBox(height: 22),
            SectionHeader(title: l10n.t('book.notes')),
            Text(a.notes!, style: Theme.of(context).textTheme.bodyMedium),
          ],

          if (a.isCompleted) ...[
            const SizedBox(height: 22),
            SectionHeader(title: l10n.t('appt.prescription')),
            if (a.prescription == null || a.prescription!.isEmpty)
              Text(
                l10n.t('appt.noPrescription'),
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Palette.line),
                  borderRadius: BorderRadius.circular(Palette.radiusCard),
                ),
                child: Text(
                  a.prescription!,
                  style: const TextStyle(fontSize: 14, height: 1.7, color: Palette.ink),
                ),
              ),
            if (a.prescriptionImages.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: a.prescriptionImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(Palette.radiusSm),
                    child: Image.network(
                      a.prescriptionImages[i],
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 110,
                        height: 110,
                        color: Palette.mist,
                        child: const Icon(Icons.broken_image_outlined,
                            color: Palette.inkSoft),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],

          if (a.rating != null) ...[
            const SizedBox(height: 22),
            SectionHeader(title: l10n.t('appt.yourRating')),
            Row(
              children: [
                StarRow(value: a.rating!, size: 20),
                const SizedBox(width: 10),
                Text(
                  a.rating!.toStringAsFixed(1),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Palette.ink),
                ),
              ],
            ),
            if (a.ratingComment != null) ...[
              const SizedBox(height: 8),
              Text(a.ratingComment!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],

          const SizedBox(height: 30),

          if (canPay) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _payNow,
                icon: const Icon(Icons.lock_outline_rounded, size: 19),
                label: Text(l10n.t('pay.confirmAndPay')),
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (canJoin)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _joinCall,
                icon: const Icon(Icons.videocam_rounded, size: 20),
                label: Text(l10n.t('appt.joinCall')),
              ),
            ),

          if (showChat) ...[
            if (canJoin) const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy || chatClosedReason != null ? null : _openChat,
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 19),
                label: Text(ChatStrings.t('chat.messageDoctor')),
              ),
            ),
            if (chatClosedReason != null) ...[
              const SizedBox(height: 6),
              Text(
                chatClosedReason,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Palette.inkSoft),
              ),
            ],
          ],

          if (a.canBeRated) ...[
            if (canJoin || showChat) const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final updated = await Navigator.of(context).push<Appointment>(
                    MaterialPageRoute<Appointment>(
                      builder: (_) => RateVisitScreen(appointment: a),
                    ),
                  );
                  if (updated != null && mounted) {
                    setState(() => _appointment = updated);
                  }
                },
                icon: const Icon(Icons.star_rounded, size: 20),
                label: Text(l10n.t('appt.rate')),
              ),
            ),
          ],

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => dialClinic(context),
              icon: const Icon(Icons.call_outlined, size: 19),
              label: Text(l10n.t('common.callClinic')),
            ),
          ),

          if (canCancel) ...[
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: _busy ? null : _cancel,
                style: TextButton.styleFrom(foregroundColor: Palette.crimsonDeep),
                child: Text(l10n.t('appt.cancel')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({
    required this.icon,
    required this.text,
    required this.tone,
    required this.background,
  });

  final IconData icon;
  final String text;
  final Color tone;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Palette.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tone),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, color: tone, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
