import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/formatting.dart';
import '../../core/palette.dart';
import '../../core/session.dart';
import '../../data/app_data.dart';
import '../../data/repository.dart';
import '../../i18n/strings.dart';
import '../../widgets/common.dart';

/// "Send us a message" — the website's contact form (`POST /api/contact`).
///
/// For a question before booking, not for booking: fees, timings, whether a
/// treatment is right for someone. The route needs an email address to reply
/// to and a message of at least a sentence; the name is optional; and it has
/// no phone field, so a phone number given here is added to the end of the
/// message (see [Repository.sendContactMessage]). No sign-in is needed, but
/// a signed-in patient finds their name, email and phone already filled in.
///
/// On success the form is replaced by a confirmation rather than cleared, as
/// on the website: a cleared form looks exactly like one that failed quietly.
class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _repo = Repository();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _message = TextEditingController();

  bool _sending = false;
  bool _sent = false;
  String? _error;

  /// The route's own sentences, in English, mapped to this app's keys so an
  /// Urdu reader is not answered in English at the moment something fails.
  static const _serverKeys = <String, String>{
    'Please enter an email address we can reply to.': 'auth.invalidEmail',
    'Please tell us a little more — at least a sentence.': 'contact.needMore',
    'We already have that message — we will reply shortly.': 'contact.tooSoon',
    'We could not save your message. Please call the clinic.': 'contact.notSaved',
  };

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  @override
  void initState() {
    super.initState();
    final session = context.read<Session>();
    final profile = context.read<AppData>().profile;
    _name.text = session.signedIn ? session.name : '';
    _email.text = session.user?.email ?? profile?.email ?? '';
    final phone = profile?.phone ?? session.profile?['phone'];
    if (phone is String && phone.isNotEmpty) _phone.text = Fmt.phone(phone);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _message.dispose();
    _repo.close();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final l10n = context.read<LocaleController>();
    final email = _email.text.trim();
    final message = _message.text.trim();

    if (email.isEmpty) {
      setState(() => _error = l10n.t('auth.needEmail'));
      return;
    }
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = l10n.t('auth.invalidEmail'));
      return;
    }
    if (message.length < 10) {
      setState(() => _error = l10n.t('contact.needMore'));
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await _repo.sendContactMessage(
        email: email,
        message: message,
        name: _name.text,
        phone: _phone.text,
      );
      if (!mounted) return;
      setState(() => _sent = true);
    } on ApiException catch (e) {
      final key = _serverKeys[e.message.trim()];
      if (mounted) {
        setState(() => _error = key != null ? l10n.t(key) : errorText(e));
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('contact.title'))),
      body: _sent ? _buildSent(context) : _buildForm(context),
    );
  }

  Widget _buildSent(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
      children: [
        EmptyState(
          icon: Icons.mark_email_read_outlined,
          title: l10n.t('contact.form.sentTitle'),
          message: l10n.t('contact.form.sentBody').replaceAll('{email}', _email.text.trim()),
        ),
        const SizedBox(height: 18),
        Text(
          l10n.t('contact.form.sentUrgent'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Palette.inkSoft, height: 1.5),
        ),
        const SizedBox(height: 10),
        Center(
          child: OutlinedButton.icon(
            onPressed: () => dialClinic(context),
            icon: const Icon(Icons.call_rounded, size: 18),
            label: Text(
              AppConfig.clinicPhoneDisplay,
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _sent = false;
              _message.clear();
            }),
            child: Text(l10n.t('contact.form.sendAnother')),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        Text(
          l10n.t('contact.form.lede'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: '${l10n.t('contact.form.name')} (${l10n.t('common.optional')})',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textDirection: TextDirection.ltr,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: l10n.t('auth.email'),
            hintText: 'you@example.com',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: '${l10n.t('contact.label.phone')} (${l10n.t('common.optional')})',
            hintText: '0310 040 4444',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _message,
          maxLines: 6,
          minLines: 4,
          maxLength: 3900,
          decoration: InputDecoration(
            labelText: l10n.t('contact.form.message'),
            hintText: l10n.t('contact.form.messagePlaceholder'),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 4),

        // The website's own caution, said before they type rather than after.
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Palette.warningSoft,
            borderRadius: BorderRadius.circular(Palette.radiusSm),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, size: 18, color: Palette.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.t('contact.form.privacy'),
                  style: const TextStyle(fontSize: 12.5, color: Palette.warning, height: 1.5),
                ),
              ),
            ],
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
              style: const TextStyle(color: Palette.crimsonDeep, fontSize: 13, height: 1.5),
            ),
          ),
        ],

        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _sending ? null : _send,
            child: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Palette.paper),
                    ),
                  )
                : Text(l10n.t('contact.form.submit')),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.t('contact.form.goesTo').replaceAll('{email}', AppConfig.supportEmail),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Palette.inkSoft),
        ),
      ],
    );
  }
}
