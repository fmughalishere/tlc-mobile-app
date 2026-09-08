import 'package:flutter/material.dart';
import '../../core/formatting.dart';
import '../../core/palette.dart';
import '../../data/repository.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

/// The clinic at a glance.
///
/// Two kinds of number, kept visually apart because they are read for
/// different reasons. The **counts** are the size of the clinic — how many
/// patients, how many services. The **analytics** are its last few weeks —
/// money taken, visits completed, how patients rated them.
///
/// Between the two sits the only figure on the screen that is a job rather
/// than a report: bookings still waiting for someone to pick up the phone.
/// It is given its own card, in amber, for that reason.
class AdminOverviewTab extends StatefulWidget {
  const AdminOverviewTab({super.key, required this.onGoToTab});

  final void Function(int index) onGoToTab;

  @override
  State<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<AdminOverviewTab> {
  final _repo = Repository();

  @override
  void dispose() {
    _repo.close();
    super.dispose();
  }

  /// The dictionary keys the rating survey uses, so the breakdown is labelled
  /// the same way the patient was asked. Falls back to the raw key, which is
  /// still readable, if the survey ever grows a question the app has not met.
  static const _questionLabels = <String, String>{
    'care': 'Quality of care',
    'listening': 'Listening to concerns',
    'courtesy': 'Courtesy of staff',
    'efficiency': 'Waiting time',
    'recommend': 'Would recommend',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo-icon.png',
              height: 26,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.t('adm.overview.title'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: l10n.toggle,
            child: Text(l10n.isUrdu ? 'English' : 'اردو'),
          ),
        ],
      ),
      body: AsyncView<AdminStats>(
        load: _repo.adminStats,
        builder: (context, stats, reload) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
          children: [
            if (stats.indexHint != null) ...[
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF3E2),
                  borderRadius: BorderRadius.circular(Palette.radiusSm),
                ),
                child: Text(
                  stats.indexHint!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Palette.warning,
                    height: 1.55,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── The one thing that is a to-do ──
            if (stats.callBacks > 0)
              _CallBackCard(
                count: stats.callBacks,
                onTap: () => widget.onGoToTab(1),
              ),
            if (stats.callBacks > 0) const SizedBox(height: 20),

            SectionHeader(title: l10n.t('adm.overview.clinic')),
            _TileGrid(
              tiles: [
                (value: '${stats.patients}', label: l10n.t('adm.stat.patients')),
                (value: '${stats.appointments}', label: l10n.t('adm.stat.appointments')),
                (value: '${stats.services}', label: l10n.t('adm.stat.services')),
                (value: '${stats.blogs}', label: l10n.t('adm.stat.blogs')),
              ],
            ),

            const SizedBox(height: 26),
            SectionHeader(
              title: stats.windowDays > 0
                  ? '${l10n.t('adm.overview.recent')} · ${stats.windowDays} ${l10n.t('adm.overview.days')}'
                  : l10n.t('adm.overview.recent'),
            ),
            _TileGrid(
              tiles: [
                (value: Fmt.money(stats.paidRevenue), label: l10n.t('adm.stat.revenue')),
                (value: Fmt.money(stats.refunded), label: l10n.t('adm.stat.refunded')),
                (value: '${stats.completed}', label: l10n.t('adm.stat.completed')),
                (
                  value: stats.avgRating == null
                      ? '—'
                      : stats.avgRating!.toStringAsFixed(1),
                  label: '${l10n.t('adm.stat.rating')} (${stats.ratingCount})',
                ),
              ],
            ),

            // ── Which part of a visit is being marked down ──
            if (stats.ratingQuestions.isNotEmpty) ...[
              const SizedBox(height: 26),
              SectionHeader(title: l10n.t('adm.overview.byQuestion')),
              Text(
                l10n.t('adm.overview.byQuestionSub'),
                style: const TextStyle(
                  fontSize: 12,
                  color: Palette.inkSoft,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 14),
              for (final q in stats.ratingQuestions)
                _QuestionBar(
                  label: _questionLabels[q.key] ?? q.key,
                  average: q.average,
                  count: q.count,
                ),
            ],

            // ── Per doctor ──
            if (stats.doctorRows.isNotEmpty) ...[
              const SizedBox(height: 26),
              SectionHeader(title: l10n.t('adm.overview.byDoctor')),
              for (final d in stats.doctorRows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(14),
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
                                d.name,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Palette.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${d.completed} ${l10n.t('adm.stat.completedLower')}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Palette.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (d.avgRating != null) ...[
                          StarRow(value: d.avgRating!, size: 14),
                          const SizedBox(width: 7),
                          Text(
                            d.avgRating!.toStringAsFixed(1),
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Palette.ink,
                            ),
                          ),
                        ] else
                          Text(
                            l10n.t('adm.overview.noRatings'),
                            style: const TextStyle(fontSize: 11.5, color: Palette.line),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

typedef _Tile = ({String value, String label});

class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.tiles});

  final List<_Tile> tiles;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      // Wide and short. "PKR 1,240,000" has to fit on one line beside a
      // two-line Urdu label without either being cut.
      childAspectRatio: 1.75,
      children: [
        for (final tile in tiles)
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              border: Border.all(color: Palette.line),
              borderRadius: BorderRadius.circular(Palette.radiusCard),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    tile.value,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Palette.indigoDeep,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  tile.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Palette.inkSoft,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CallBackCard extends StatelessWidget {
  const _CallBackCard({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Material(
      color: const Color(0xFFFDF3E2),
      borderRadius: BorderRadius.circular(Palette.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Palette.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.phone_in_talk_rounded, color: Palette.warning),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count ${l10n.t('adm.overview.callBacks')}',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Palette.warning,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.t('adm.overview.callBacksSub'),
                      style: const TextStyle(fontSize: 12, color: Palette.warning),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Palette.warning),
            ],
          ),
        ),
      ),
    );
  }
}

/// One survey question's average, drawn as a bar out of five.
///
/// A bar rather than a number, because five bars side by side answer the
/// question this section exists for — *which one is lowest* — at a glance,
/// and five decimals do not.
class _QuestionBar extends StatelessWidget {
  const _QuestionBar({required this.label, required this.average, required this.count});

  final String label;
  final double? average;
  final int count;

  @override
  Widget build(BuildContext context) {
    final value = average ?? 0;
    final fraction = (value / 5).clamp(0.0, 1.0);

    // Amber below 3.5, green above. The threshold is deliberately generous:
    // on a five-point scale a genuine 3 is "average", and colouring it red
    // teaches everyone to ignore the colour.
    final colour = average == null
        ? Palette.line
        : value >= 3.5
            ? Palette.success
            : Palette.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12.5, color: Palette.ink),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                average == null ? '—' : '${value.toStringAsFixed(1)} · $count',
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colour,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 7,
              backgroundColor: Palette.mist,
              valueColor: AlwaysStoppedAnimation<Color>(colour),
            ),
          ),
        ],
      ),
    );
  }
}
