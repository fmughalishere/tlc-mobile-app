import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/palette.dart';
import '../../data/repository.dart';
import '../../i18n/strings.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

/// Adding or editing one service.
///
/// ── The two columns ──
///
/// Every translatable field appears twice: English, then Urdu. They are shown
/// as a pair rather than on two separate screens because that is the only way
/// the person writing the Urdu can see what they are translating — and because
/// the Urdu column is what a patient reading Urdu actually sees.
///
/// An empty Urdu field is saved as *absent*, not as an empty string. Both read
/// the same through the app's fallback, but storing "" for every untranslated
/// field puts a meaningless key on every document and turns "which of these
/// still needs Urdu?" into a question the data can no longer answer.
///
/// Lists — points and treatments — are one item per line, in both languages.
class ServiceEditorScreen extends StatefulWidget {
  const ServiceEditorScreen({super.key, this.service});

  /// Null when creating.
  final Service? service;

  @override
  State<ServiceEditorScreen> createState() => _ServiceEditorScreenState();
}

class _ServiceEditorScreenState extends State<ServiceEditorScreen> {
  final _repo = Repository();

  late final _name = TextEditingController(text: widget.service?.name ?? '');
  late final _nameUr = TextEditingController(text: widget.service?.nameUr ?? '');
  late final _category = TextEditingController(text: widget.service?.category ?? '');
  late final _short = TextEditingController(text: widget.service?.short ?? '');
  late final _shortUr = TextEditingController(text: widget.service?.shortUr ?? '');
  late final _intro = TextEditingController(text: widget.service?.intro ?? '');
  late final _introUr = TextEditingController(text: widget.service?.introUr ?? '');
  late final _points =
      TextEditingController(text: widget.service?.points.join('\n') ?? '');
  late final _pointsUr =
      TextEditingController(text: widget.service?.pointsUr.join('\n') ?? '');
  late final _treatments =
      TextEditingController(text: widget.service?.treatments.join('\n') ?? '');
  late final _treatmentsUr =
      TextEditingController(text: widget.service?.treatmentsUr.join('\n') ?? '');
  late final _price =
      TextEditingController(text: widget.service?.price?.round().toString() ?? '');
  late final _advance = TextEditingController(
      text: widget.service?.advancePayment?.round().toString() ?? '');
  late final _duration = TextEditingController(
      text: widget.service?.durationMinutes?.round().toString() ?? '');
  late final _image = TextEditingController(text: widget.service?.image ?? '');

  bool _saving = false;
  String? _error;

  bool get _isNew => widget.service == null;

  @override
  void dispose() {
    for (final c in [
      _name, _nameUr, _category, _short, _shortUr, _intro, _introUr,
      _points, _pointsUr, _treatments, _treatmentsUr,
      _price, _advance, _duration, _image,
    ]) {
      c.dispose();
    }
    _repo.close();
    super.dispose();
  }

  /// Absent, not empty. See the note at the top of the file.
  String? _optional(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  /// A number, or absent. Empty must not become 0 — for `advancePayment` those
  /// mean opposite things: absent is "charge the full price online", zero is
  /// "charge nothing at all".
  num? _optionalNumber(TextEditingController c) {
    final v = c.text.trim();
    if (v.isEmpty) return null;
    final n = num.tryParse(v);
    return (n != null && n >= 0) ? n : null;
  }

  List<String> _lines(TextEditingController c) => c.text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  Future<void> _save() async {
    final l10n = context.read<LocaleController>();
    if (_name.text.trim().isEmpty || _category.text.trim().isEmpty) {
      setState(() => _error = l10n.t('adm.svc.needNameCategory'));
      return;
    }

    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'category': _category.text.trim(),
      'short': _short.text.trim(),
      'intro': _intro.text.trim(),
      'points': _lines(_points),
      'treatments': _lines(_treatments),
      'nameUr': _optional(_nameUr),
      'shortUr': _optional(_shortUr),
      'introUr': _optional(_introUr),
      'pointsUr': _lines(_pointsUr),
      'treatmentsUr': _lines(_treatmentsUr),
      'price': _optionalNumber(_price),
      'advancePayment': _optionalNumber(_advance),
      'durationMinutes': _optionalNumber(_duration),
      'image': _optional(_image),
    };

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isNew) {
        await _repo.createService(body);
      } else {
        await _repo.updateService(widget.service!.id, body);
      }
      if (!mounted) return;
      showToast(context, l10n.t('adm.svc.saved'));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.t('adm.cat.newService') : l10n.t('adm.svc.edit')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          _Field(
            controller: _category,
            label: l10n.t('adm.svc.category'),
            hint: 'Mental Health',
            helper: l10n.t('adm.svc.categoryHelp'),
          ),

          const SizedBox(height: 20),
          SectionHeader(title: l10n.t('adm.svc.name')),
          _Pair(
            english: _name,
            urdu: _nameUr,
            l10n: l10n,
          ),

          const SizedBox(height: 20),
          SectionHeader(title: l10n.t('adm.svc.short')),
          _Pair(english: _short, urdu: _shortUr, l10n: l10n, lines: 2),

          const SizedBox(height: 20),
          SectionHeader(title: l10n.t('adm.svc.intro')),
          _Pair(english: _intro, urdu: _introUr, l10n: l10n, lines: 5),

          const SizedBox(height: 20),
          SectionHeader(title: l10n.t('services.whatsIncluded')),
          Text(
            l10n.t('adm.svc.onePerLine'),
            style: const TextStyle(fontSize: 11.5, color: Palette.inkSoft),
          ),
          const SizedBox(height: 10),
          _Pair(english: _points, urdu: _pointsUr, l10n: l10n, lines: 5),

          const SizedBox(height: 20),
          SectionHeader(title: l10n.t('services.treatments')),
          Text(
            l10n.t('adm.svc.onePerLine'),
            style: const TextStyle(fontSize: 11.5, color: Palette.inkSoft),
          ),
          const SizedBox(height: 10),
          _Pair(english: _treatments, urdu: _treatmentsUr, l10n: l10n, lines: 5),

          const SizedBox(height: 24),
          SectionHeader(title: l10n.t('adm.svc.moneyTime')),
          _Field(
            controller: _price,
            label: l10n.t('services.price'),
            keyboard: TextInputType.number,
            helper: l10n.t('adm.svc.priceHelp'),
          ),
          const SizedBox(height: 12),
          _Field(
            controller: _advance,
            label: l10n.t('services.advance'),
            keyboard: TextInputType.number,
            helper: l10n.t('adm.svc.advanceHelp'),
          ),
          const SizedBox(height: 12),
          _Field(
            controller: _duration,
            label: '${l10n.t('services.duration')} (${l10n.t('services.minutes')})',
            keyboard: TextInputType.number,
          ),
          const SizedBox(height: 12),
          _Field(
            controller: _image,
            label: l10n.t('adm.svc.image'),
            keyboard: TextInputType.url,
            helper: l10n.t('adm.svc.imageHelp'),
          ),

          if (_error != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Palette.dangerSoft,
                borderRadius: BorderRadius.circular(Palette.radiusSm),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Palette.crimsonDeep, fontSize: 13),
              ),
            ),
          ],

          const SizedBox(height: 26),
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
                  : Text(l10n.t('common.save')),
            ),
          ),
        ],
      ),
    );
  }
}

/// English above, Urdu below — the pair a translator works in.
class _Pair extends StatelessWidget {
  const _Pair({
    required this.english,
    required this.urdu,
    required this.l10n,
    this.lines = 1,
  });

  final TextEditingController english;
  final TextEditingController urdu;
  final LocaleController l10n;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: english,
          maxLines: lines,
          textCapitalization: TextCapitalization.sentences,
          // Latin, always — even when the app itself is in Urdu, this is the
          // English column and typing into it should behave as English.
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: 'English',
            alignLabelWithHint: lines > 1,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: urdu,
          maxLines: lines,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(
            labelText: 'اردو',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.helper,
    this.keyboard = TextInputType.text,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helper;
  final TextInputType keyboard;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      textDirection: keyboard == TextInputType.text ? null : TextDirection.ltr,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 3,
      ),
    );
  }
}
