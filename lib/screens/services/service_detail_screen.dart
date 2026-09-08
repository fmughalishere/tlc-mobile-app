import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../core/palette.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../booking/book_screen.dart';

/// One service, in full.
///
/// Every piece of text here goes through `displayX(urdu)`, which reads the
/// clinic's own Urdu column and falls back to English when it is empty. That
/// fallback is the whole point: the catalogue is translated a service at a
/// time, and an Urdu reader should see English treatment names during those
/// weeks rather than blank space where a treatment ought to be.
class ServiceDetailScreen extends StatelessWidget {
  const ServiceDetailScreen({super.key, required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final urdu = context.isUrdu;

    final points = service.displayPoints(urdu);
    final treatments = service.displayTreatments(urdu);
    final intro = service.displayIntro(urdu);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('services.title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          if (service.image != null && service.image!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(Palette.radiusCard),
              child: Image.network(
                service.image!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                // A Cloudinary URL that has been deleted must not take the
                // whole page down — the words below are the point of it.
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : const SizedBox(height: 180),
              ),
            ),
          if (service.image != null && service.image!.isNotEmpty)
            const SizedBox(height: 18),

          Text(
            service.category,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Palette.crimson,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            service.displayName(urdu),
            style: Theme.of(context).textTheme.headlineMedium,
          ),

          if (service.displayShort(urdu).isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              service.displayShort(urdu),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],

          const SizedBox(height: 20),
          _FactsRow(service: service),

          if (intro.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text(intro, style: Theme.of(context).textTheme.bodyMedium),
          ],

          if (points.isNotEmpty) ...[
            const SizedBox(height: 26),
            SectionHeader(title: l10n.t('services.whatsIncluded')),
            for (final point in points) Bullet(point),
          ],

          if (treatments.isNotEmpty) ...[
            const SizedBox(height: 22),
            SectionHeader(title: l10n.t('services.treatments')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final treatment in treatments)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Palette.mist,
                      borderRadius: BorderRadius.circular(Palette.radiusPill),
                    ),
                    child: Text(
                      treatment,
                      style: const TextStyle(fontSize: 12.5, color: Palette.ink),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BookScreen(preselected: service),
                ),
              ),
              child: Text(l10n.t('services.bookThis')),
            ),
          ),
        ),
      ),
    );
  }
}

/// Price, advance and duration — the three things a patient checks before
/// deciding. Each is skipped when the clinic has not filled it in, rather than
/// shown as "—", because an empty row invites the question "is it free?".
class _FactsRow extends StatelessWidget {
  const _FactsRow({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final facts = <List<String>>[
      if (service.price != null) [l10n.t('services.price'), Fmt.money(service.price)],
      if (service.advancePayment != null)
        [l10n.t('services.advance'), Fmt.money(service.advancePayment)],
      if (service.durationMinutes != null)
        [
          l10n.t('services.duration'),
          '${service.durationMinutes!.round()} ${l10n.t('services.minutes')}',
        ],
    ];

    if (facts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Palette.paperDim,
        borderRadius: BorderRadius.circular(Palette.radiusCard),
      ),
      child: Wrap(
        spacing: 28,
        runSpacing: 14,
        children: [
          for (final fact in facts)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fact[0],
                  style: const TextStyle(fontSize: 11, color: Palette.inkSoft),
                ),
                const SizedBox(height: 3),
                Text(
                  fact[1],
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Palette.indigoDeep,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
