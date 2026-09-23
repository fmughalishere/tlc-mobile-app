import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../core/palette.dart';
import '../data/app_data.dart';
import 'common.dart';

/// The date filter that sits above every appointments list.
///
/// One widget for the patient, the doctor and the clinic, because all three
/// are asking the same question — what is on the books between these two days.
/// The range itself lives in [AppData], not here: all three screens read the
/// same fetched list, so a range owned by one screen would be invisible to the
/// next, and the list under it would already have been fetched without it.
///
/// Picking a date refetches from the server. It does not filter the list the
/// phone already holds — that list is one window of the most recent bookings,
/// so filtering it locally would hide appointments that were never downloaded
/// and present the gap as an empty week.
///
/// ── Why the native picker ──
///
/// `showDatePicker` is already translated, already handles the Urdu locale,
/// already knows about leap years, and is the dialog the person has used in
/// every other app on the phone. A calendar drawn by hand here would be a
/// worse version of it in every one of those respects.
class DateRangeBar extends StatelessWidget {
  const DateRangeBar({super.key, this.count});

  /// How many rows the range matched, shown under the fields. A filtered list
  /// should say what it is showing — otherwise a short list reads as a quiet
  /// week rather than as a narrow filter.
  final int? count;

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _shift(int days) => _iso(DateTime.now().add(Duration(days: days)));

  Future<void> _pick(BuildContext context, {required bool isFrom}) async {
    final data = context.read<AppData>();
    final current = isFrom ? data.apptFrom : data.apptTo;
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(current.isEmpty ? _iso(now) : current) ?? now,
      // Five years back covers a clinic's whole record so far; two forward
      // covers anything that can actually be booked.
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;

    final value = _iso(picked);
    if (isFrom) {
      // Keeping a start date that is after the end date returns nothing and
      // looks like a bug, so the end moves with it rather than being silently
      // wrong.
      final end = data.apptTo;
      await data.setAppointmentRange(
        value,
        end.isNotEmpty && end.compareTo(value) < 0 ? value : end,
      );
    } else {
      final start = data.apptFrom;
      await data.setAppointmentRange(
        start.isNotEmpty && start.compareTo(value) > 0 ? value : start,
        value,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final data = context.watch<AppData>();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: l10n.t('range.from'),
                  value: data.apptFrom.isEmpty ? null : Fmt.date(data.apptFrom),
                  onTap: () => _pick(context, isFrom: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Field(
                  label: l10n.t('range.to'),
                  value: data.apptTo.isEmpty ? null : Fmt.date(data.apptTo),
                  onTap: () => _pick(context, isFrom: false),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // The presets are what the clinic actually asks for at the counter.
          // Each one just writes both fields, so it can be adjusted by hand
          // afterwards — there is no hidden mode to get stuck in.
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _Chip(
                  label: l10n.t('range.today'),
                  from: _shift(0),
                  to: _shift(0),
                ),
                _Chip(
                  label: l10n.t('range.week'),
                  from: _shift(-6),
                  to: _shift(0),
                ),
                _Chip(
                  label: l10n.t('range.month'),
                  from: _shift(-29),
                  to: _shift(0),
                ),
                _Chip(
                  label: l10n.t('range.upcoming'),
                  from: _shift(0),
                  to: _shift(30),
                ),
                if (data.apptRanged)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 4),
                    child: TextButton(
                      onPressed: () => data.setAppointmentRange('', ''),
                      child: Text(l10n.t('range.clear')),
                    ),
                  ),
              ],
            ),
          ),

          if (data.apptRanged && count != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                count == 0
                    ? l10n.t('range.empty')
                    : '$count · ${l10n.t('range.matched')}',
                style: theme.textTheme.bodySmall?.copyWith(color: Palette.inkSoft),
              ),
            ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, required this.onTap});

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          value ?? '—',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: value == null ? Palette.inkSoft : null,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.from, required this.to});

  final String label;
  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final selected = data.apptFrom == from && data.apptTo == to;

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        // Tapping the chip that is already on clears the range, which is the
        // behaviour people expect from a toggle and saves a trip to "Clear".
        onSelected: (_) => data.setAppointmentRange(
          selected ? '' : from,
          selected ? '' : to,
        ),
      ),
    );
  }
}
