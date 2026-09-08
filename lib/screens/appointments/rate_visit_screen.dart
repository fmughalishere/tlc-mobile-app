import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../data/repository.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

/// The five-question satisfaction survey.
///
/// The keys — care, listening, courtesy, efficiency, recommend — are the
/// website's, from `src/lib/rating.ts`, and they must never change: they are
/// what every answer is stored under, so renaming one orphans every rating
/// already given.
///
/// The submit button stays disabled until all five are answered, because the
/// server rejects a partial set rather than filling the gaps in. That is the
/// right behaviour and worth mirroring here: a missing answer averaged as 3
/// would be the survey inventing an opinion the patient never gave, and it
/// would move a real doctor's score.
class RateVisitScreen extends StatefulWidget {
  const RateVisitScreen({super.key, required this.appointment});

  final Appointment appointment;

  @override
  State<RateVisitScreen> createState() => _RateVisitScreenState();
}

class _RateVisitScreenState extends State<RateVisitScreen> {
  static const questions = <List<String>>[
    ['care', 'How would you rate the quality of medical care you received?'],
    [
      'listening',
      'How well did our doctor and medical staff listen to and address your concerns?',
    ],
    ['courtesy', 'How would you rate the courtesy and professionalism of our staff?'],
    [
      'efficiency',
      'How satisfied were you with the waiting time and overall efficiency of your visit?',
    ],
    ['recommend', 'How likely are you to recommend our practice to your family or friends?'],
  ];

  static const questionsUr = <String, String>{
    'care': 'آپ کو ملنے والی طبی دیکھ بھال کے معیار کو آپ کیا درجہ دیں گی؟',
    'listening': 'ہمارے ڈاکٹر اور عملے نے آپ کی بات کتنی توجہ سے سنی اور مسئلہ حل کیا؟',
    'courtesy': 'ہمارے عملے کے اخلاق اور پیشہ ورانہ رویّے کو آپ کیا درجہ دیں گی؟',
    'efficiency': 'انتظار کے وقت اور مجموعی نظم و ضبط سے آپ کتنی مطمئن رہیں؟',
    'recommend': 'آپ ہمارے کلینک کو اپنے گھر والوں یا دوستوں کو کتنا تجویز کریں گی؟',
  };

  static const scaleEn = <int, String>{
    1: 'Very Poor',
    2: 'Poor',
    3: 'Average',
    4: 'Good',
    5: 'Excellent',
  };

  static const scaleUr = <int, String>{
    1: 'بہت ناقص',
    2: 'ناقص',
    3: 'اوسط',
    4: 'اچھا',
    5: 'بہترین',
  };

  final _answers = <String, int>{};
  final _comment = TextEditingController();
  final _repo = Repository();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    _repo.close();
    super.dispose();
  }

  bool get _complete => _answers.length == questions.length;

  Future<void> _submit() async {
    if (!_complete) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.rateAppointment(
        widget.appointment.id,
        answers: _answers,
        comment: _comment.text,
      );
      if (!mounted) return;
      // The screen below is handed back an appointment carrying the new score
      // so it can render it immediately, without a second round trip whose
      // only job would be to tell it what it already knows.
      final total = _answers.values.fold<int>(0, (sum, v) => sum + v);
      final mean = (total / _answers.length * 100).round() / 100;
      Navigator.of(context).pop(
        Appointment.fromJson({
          'id': widget.appointment.id,
          'patientId': widget.appointment.patientId,
          'patientName': widget.appointment.patientName,
          'service': widget.appointment.service,
          'status': widget.appointment.status,
          'mode': widget.appointment.mode,
          'date': widget.appointment.date,
          'time': widget.appointment.time,
          'amount': widget.appointment.amount,
          'paymentStatus': widget.appointment.paymentStatus,
          'bookingType': widget.appointment.bookingType,
          'createdAt': widget.appointment.createdAt,
          'doctorId': widget.appointment.doctorId,
          'doctorName': widget.appointment.doctorName,
          'consultMode': widget.appointment.consultMode,
          'notes': widget.appointment.notes,
          'prescription': widget.appointment.prescription,
          'prescriptionImages': widget.appointment.prescriptionImages,
          'rating': mean,
          'ratingComment': _comment.text.trim(),
        }),
      );
    } catch (e) {
      setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final urdu = context.isUrdu;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('appt.rate'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text(
            widget.appointment.service,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 22),

          for (final question in questions) ...[
            Text(
              urdu ? (questionsUr[question[0]] ?? question[1]) : question[1],
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 10),
            _ScaleRow(
              value: _answers[question[0]],
              onPick: (score) => setState(() => _answers[question[0]] = score),
            ),
            const SizedBox(height: 6),
            if (_answers[question[0]] != null)
              Text(
                urdu
                    ? (scaleUr[_answers[question[0]]!] ?? '')
                    : (scaleEn[_answers[question[0]]!] ?? ''),
                style: const TextStyle(
                  fontSize: 12,
                  color: Palette.indigoDeep,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 22),
          ],

          TextField(
            controller: _comment,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: '${l10n.t('book.notes')} (${l10n.t('common.optional')})',
              alignLabelWithHint: true,
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 14),
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

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_complete && !_busy) ? _submit : null,
              child: _busy
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
          if (!_complete) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                '${_answers.length} / ${questions.length}',
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 12, color: Palette.inkSoft),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Five stars, tappable.
///
/// Stars rather than numbered buttons because the scale runs one to five in
/// one direction only, and a row of stars says that without a legend.
class _ScaleRow extends StatelessWidget {
  const _ScaleRow({required this.value, required this.onPick});

  final int? value;
  final void Function(int) onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      // Always left-to-right: one star is the worst score and five is the
      // best, and mirroring that in Urdu would put "excellent" where the eye
      // expects "very poor".
      textDirection: TextDirection.ltr,
      children: List.generate(5, (i) {
        final score = i + 1;
        final on = value != null && value! >= score;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: InkResponse(
            onTap: () => onPick(score),
            radius: 26,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                on ? Icons.star_rounded : Icons.star_border_rounded,
                size: 34,
                color: on ? const Color(0xFFE8A317) : Palette.line,
              ),
            ),
          ),
        );
      }),
    );
  }
}
