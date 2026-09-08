import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../core/palette.dart';
import '../../data/repository.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
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
    final l10n = context.l10n;

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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final a = _appointment;

    // A video room only exists once the session has been started at the other
    // end. Showing the button before that gives the patient a link to nothing.
    final canJoin = a.roomUrl != null &&
        a.roomUrl!.isNotEmpty &&
        a.sessionStatus == 'live';

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

          if (canJoin)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => openUrl(context, a.roomUrl!),
                icon: const Icon(Icons.videocam_rounded, size: 20),
                label: Text(l10n.t('appt.joinCall')),
              ),
            ),

          if (a.canBeRated) ...[
            if (canJoin) const SizedBox(height: 12),
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
