import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/palette.dart';
import '../../widgets/common.dart';
import '../contact/contact_screen.dart';

/// The website's reading: conditions, treatments, telemedicine, what to
/// expect, questions, the clinic, and the blog.
///
/// ── Why these open the website rather than living in the app ──
///
/// That content is written in the website's source (src/data/content/*.ts,
/// the FAQ in src/data/site.ts) and in Firestore for the blog, not served by
/// an API. Copying it into the app would give the clinic two versions to keep
/// true, and a medical page that is right on the web and a month stale on a
/// patient's phone is worse than no page. So each row opens the live page.
///
/// The website picks its language from what the visitor chose there, not from
/// anything in the link, so an Urdu reader chooses اردو on the site once —
/// which the note at the top says.
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  static const _pages = <_InfoPage>[
    _InfoPage('/conditions', Icons.psychology_outlined, 'info.conditions', 'info.conditionsSub'),
    _InfoPage('/treatments', Icons.healing_outlined, 'info.treatments', 'info.treatmentsSub'),
    _InfoPage('/telemedicine', Icons.videocam_outlined, 'info.telemedicine', 'info.telemedicineSub'),
    _InfoPage('/what-to-expect', Icons.checklist_rounded, 'info.whatToExpect', 'info.whatToExpectSub'),
    _InfoPage('/faq', Icons.help_outline_rounded, 'info.faq', 'info.faqSub'),
    _InfoPage('/about', Icons.local_hospital_outlined, 'info.about', 'info.aboutSub'),
    _InfoPage('/blog', Icons.article_outlined, 'info.blog', 'info.blogSub'),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('info.title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        children: [
          Text(
            l10n.t('info.lede'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (l10n.isUrdu) ...[
            const SizedBox(height: 8),
            Text(
              l10n.t('info.urduNote'),
              style: const TextStyle(fontSize: 12.5, color: Palette.inkSoft, height: 1.5),
            ),
          ],
          const SizedBox(height: 18),
          for (final page in _pages)
            _InfoTile(
              icon: page.icon,
              title: l10n.t(page.titleKey),
              subtitle: l10n.t(page.subtitleKey),
              external: true,
              onTap: () => openUrl(context, '${AppConfig.apiBaseUrl}${page.path}'),
            ),
          const SizedBox(height: 16),
          SectionHeader(title: l10n.t('info.stillQuestions')),
          _InfoTile(
            icon: Icons.mail_outline_rounded,
            title: l10n.t('contact.title'),
            subtitle: l10n.t('contact.homeSub'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ContactScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPage {
  const _InfoPage(this.path, this.icon, this.titleKey, this.subtitleKey);

  final String path;
  final IconData icon;
  final String titleKey;
  final String subtitleKey;
}

/// The home tab's wide tile, so this screen reads as part of the same app.
/// A row that leaves the app says so with an "open outside" mark in place of
/// the chevron.
class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.external = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool external;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Palette.paper,
        borderRadius: BorderRadius.circular(Palette.radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Palette.radiusCard),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              border: Border.all(color: Palette.line),
              borderRadius: BorderRadius.circular(Palette.radiusCard),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F2EC),
                    borderRadius: BorderRadius.circular(Palette.radiusSm),
                  ),
                  child: Icon(icon, color: Palette.indigoDeep, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: Palette.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: Palette.inkSoft),
                      ),
                    ],
                  ),
                ),
                Icon(
                  external ? Icons.open_in_new_rounded : Icons.chevron_right_rounded,
                  size: external ? 18 : 24,
                  color: Palette.inkSoft,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
