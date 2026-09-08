import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatting.dart';
import '../../core/palette.dart';
import '../../data/app_data.dart';
import '../../data/repository.dart';
import '../../i18n/strings.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

/// The e-prescription for one completed visit.
///
/// The patient sees this the moment it is saved, on their own appointment
/// screen — there is no separate "send" step, and that is deliberate: a
/// two-step save is a prescription that sits written but undelivered because
/// someone was interrupted.
///
/// Only the treating doctor can write it. That is enforced by the server, not
/// here; this screen is the interface to a permission that already exists.
class PrescriptionScreen extends StatefulWidget {
  const PrescriptionScreen({super.key, required this.appointment});

  final Appointment appointment;

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  final _repo = Repository();
  late final TextEditingController _text =
      TextEditingController(text: widget.appointment.prescription ?? '');
  late List<String> _images = [...widget.appointment.prescriptionImages];
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    _repo.close();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.read<LocaleController>();
    final data = context.read<AppData>();
    final text = _text.text.trim();
    if (text.isEmpty && _images.isEmpty) {
      showToast(context, l10n.t('doc.rx.needSomething'), error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await _repo.savePrescription(
        widget.appointment.id,
        prescription: text,
        images: _images,
      );
      await data.refreshAppointments();
      if (!mounted) return;
      showToast(context, l10n.t('doc.rx.saved'));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Photographs are added by URL rather than by camera, for now.
  ///
  /// The website uploads to Cloudinary through `/api/upload`, which signs the
  /// request server-side. Wiring the phone's camera into that same signed
  /// upload is a real piece of work and worth doing properly; a half-finished
  /// version that uploads somewhere else would put patient documents in a
  /// second place nobody is auditing. Until then a doctor who has already put
  /// a photo on the website can paste its link here, and the text field below
  /// carries the prescription itself.
  Future<void> _addImage() async {
    final l10n = context.read<LocaleController>();
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('doc.rx.addImage')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(hintText: 'https://…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(l10n.t('common.save')),
          ),
        ],
      ),
    );
    controller.dispose();

    if (url == null || url.isEmpty) return;
    if (!url.startsWith('http')) {
      if (mounted) showToast(context, l10n.t('doc.rx.badUrl'), error: true);
      return;
    }
    // Six is the server's cap, and it rejects the rest silently — so the app
    // stops at six too rather than letting the doctor add a seventh that never
    // arrives.
    if (_images.length >= 6) {
      if (mounted) showToast(context, l10n.t('doc.rx.maxImages'), error: true);
      return;
    }
    setState(() => _images = [..._images, url]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final a = widget.appointment;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('appt.prescription'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Container(
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
                  '${a.service} · ${Fmt.date(a.date)} ${Fmt.time(a.time)}',
                  style: const TextStyle(fontSize: 12.5, color: Palette.inkSoft),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),
          TextField(
            controller: _text,
            maxLines: 12,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.t('doc.rx.text'),
              hintText: l10n.t('doc.rx.hint'),
              alignLabelWithHint: true,
            ),
          ),

          const SizedBox(height: 20),
          SectionHeader(
            title: l10n.t('doc.rx.images'),
            actionLabel: _images.length < 6 ? l10n.t('doc.rx.add') : null,
            onAction: _images.length < 6 ? _addImage : null,
          ),
          if (_images.isEmpty)
            Text(
              l10n.t('doc.rx.noImages'),
              style: const TextStyle(fontSize: 12.5, color: Palette.inkSoft, height: 1.6),
            )
          else
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Palette.radiusSm),
                      child: Image.network(
                        _images[i],
                        width: 104,
                        height: 104,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 104,
                          height: 104,
                          color: Palette.mist,
                          child: const Icon(Icons.broken_image_outlined,
                              color: Palette.inkSoft),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: InkWell(
                        onTap: () => setState(
                          () => _images = [..._images]..removeAt(i),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Palette.ink,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 13, color: Palette.paper),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Palette.paper),
                      ),
                    )
                  : Text(l10n.t('doc.rx.save')),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.t('doc.rx.visibleNote'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5, color: Palette.inkSoft, height: 1.5),
          ),
        ],
      ),
    );
  }
}
