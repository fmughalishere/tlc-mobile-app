import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/formatting.dart';
import '../../core/palette.dart';
import '../../core/session.dart';
import '../../data/app_data.dart';
import '../../i18n/strings.dart';
import '../../widgets/common.dart';
import '../diagnostics_screen.dart';

/// The account, its settings, and the way out.
///
/// Every field the website's own Settings page can change is here, and each
/// one writes through the same endpoint the website uses — `PATCH /api/profile`
/// — so a change made on the phone is the same change, stored in the same
/// place, as one made at the clinic's desk.
///
/// The language switch writes to two places on purpose: to SharedPreferences,
/// so this phone remembers it offline, and to the profile, so the website
/// greets them in the same language. Only the first is awaited — tapping
/// "اردو" should turn the app Urdu instantly, not after a round trip.
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _saving = false;

  // ── Editing ───────────────────────────────────────────────────────────────

  /// One dialog for every single-line field, because they only differ in their
  /// label, their keyboard and how they are validated. Five near-identical
  /// dialogs is five places for one of them to be subtly different.
  Future<void> _editField({
    required String title,
    required String field,
    required String? current,
    TextInputType keyboard = TextInputType.text,
    bool multiline = false,
    String? hint,
    String? Function(String value)? validate,

    /// Transforms what was typed into what the server should store — the
    /// phone number becomes E.164 here, exactly as the website does it.
    String Function(String value)? transform,
  }) async {
    final l10n = context.read<LocaleController>();
    final controller = TextEditingController(text: current ?? '');
    String? error;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: keyboard,
            maxLines: multiline ? 5 : 1,
            textCapitalization:
                multiline ? TextCapitalization.sentences : TextCapitalization.words,
            // Emails and phone numbers are Latin text even for an Urdu
            // reader; letting them mirror puts the cursor and the "@" at the
            // wrong end of the field.
            textDirection: keyboard == TextInputType.text ? null : TextDirection.ltr,
            decoration: InputDecoration(
              hintText: hint,
              errorText: error,
              alignLabelWithHint: multiline,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.t('common.cancel')),
            ),
            TextButton(
              onPressed: () {
                final typed = controller.text.trim();
                final problem = validate?.call(typed);
                if (problem != null) {
                  setDialogState(() => error = problem);
                  return;
                }
                Navigator.of(dialogContext).pop(transform?.call(typed) ?? typed);
              },
              child: Text(l10n.t('common.save')),
            ),
          ],
        ),
      ),
    );
    controller.dispose();

    if (result == null) return;

    // Typing the same thing again and pressing Save is not a change. Sending
    // it anyway costs a round trip and gets back 400 "Nothing to update",
    // which would look to the person like their save had failed.
    if (result.trim() == (current ?? '').trim()) return;

    // `saveProfile` stores what came back, so there is no follow-up read: the
    // screen redraws from the server's own copy of what it just accepted.
    await _save({field: result});
  }

  Future<void> _save(Map<String, dynamic> changes) async {
    final l10n = context.read<LocaleController>();
    final data = context.read<AppData>();
    setState(() => _saving = true);
    try {
      await data.saveProfile(changes);
      if (mounted) showToast(context, l10n.t('profile.saved'));
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _setLanguage(bool urdu) {
    // Local first: the switch has to feel instant.
    context.read<LocaleController>().set(urdu);

    // Then mirrored onto the profile, so the website greets them in the same
    // language. Deliberately not awaited and its failure deliberately ignored
    // — the language has already changed on this phone, and a dropped
    // connection should not undo that or interrupt with an error about a
    // preference that has, from the patient's point of view, been applied.
    context
        .read<AppData>()
        .saveProfile({'locale': urdu ? 'ur' : 'en'})
        .catchError((Object _) {});
  }

  Future<void> _signOut() async {
    final l10n = context.read<LocaleController>();
    final session = context.read<Session>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('auth.signOut')),
        content: Text(l10n.t('profile.signOutConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Palette.crimsonDeep),
            child: Text(l10n.t('auth.signOut')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await session.signOut();
      // Nothing to navigate: Session has already cleared its state and told
      // the gate, which swaps this whole screen for the sign-in one.
    } catch (e) {
      // The local state is cleared regardless, so the person IS signed out of
      // this app — but if Firebase could not be reached, say so rather than
      // letting them believe the credential was cleared everywhere.
      if (mounted) showToast(context, '${l10n.t('profile.signOutPartial')} ($e)', error: true);
    }
  }

  // ── Screen ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    final data = context.watch<AppData>();
    final profile = data.profile;

    // The profile document is the better source, but the session always has
    // *something* — so a failed read shows a slightly thinner screen rather
    // than an error page in front of the sign-out button.
    final name = profile?.name ?? session.name;
    final isDoctor = profile?.isDoctor ?? (session.role == Role.doctor);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.t('profile.title')),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: data.refreshProfile,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            // The whole header is the button, not just the pencil. A 20-pixel
            // icon is a hard target on a phone, and "tap your name to change
            // it" is what people try first anyway.
            Material(
              color: Palette.paperDim,
              borderRadius: BorderRadius.circular(Palette.radiusCard),
              child: InkWell(
                borderRadius: BorderRadius.circular(Palette.radiusCard),
                onTap: () => _editField(
                  title: l10n.t('profile.editName'),
                  field: 'name',
                  current: name,
                  validate: (v) => v.isEmpty ? l10n.t('auth.needName') : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Avatar(
                        initials: _initials(name),
                        photoURL: profile?.photoURL,
                        size: 56,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? l10n.t('profile.addName') : name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              l10n.t('profile.tapToEdit'),
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Palette.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_outlined, size: 20, color: Palette.indigo),
                    ],
                  ),
                ),
              ),
            ),

            // ── Account ──
            const SizedBox(height: 26),
            SectionHeader(title: l10n.t('profile.account')),
            _Row(
              icon: Icons.person_outline_rounded,
              label: l10n.t('auth.name'),
              value: name,
              onTap: () => _editField(
                title: l10n.t('profile.editName'),
                field: 'name',
                current: name,
                validate: (v) => v.isEmpty ? l10n.t('auth.needName') : null,
              ),
            ),
            _Row(
              icon: Icons.call_outlined,
              label: l10n.t('auth.phone'),
              value: Fmt.phone(profile?.phone),
              placeholder: l10n.t('profile.notSet'),
              onTap: () => _editField(
                title: l10n.t('auth.phone'),
                field: 'phone',
                current: Fmt.phone(profile?.phone),
                keyboard: TextInputType.phone,
                hint: '0310 040 4444',
                validate: (v) =>
                    v.isEmpty || Fmt.toE164(v) != null ? null : l10n.t('auth.needPhone'),
                // Stored in E.164, the way every other part of the system
                // keys on it — so the clinic's SMS and the app agree about
                // which number this is.
                transform: (v) => v.isEmpty ? '' : (Fmt.toE164(v) ?? v),
              ),
            ),
            _Row(
              icon: Icons.mail_outline_rounded,
              label: l10n.t('auth.email'),
              value: profile?.email ?? '',
              placeholder: l10n.t('profile.notSet'),
              onTap: () => _editField(
                title: l10n.t('auth.email'),
                field: 'email',
                current: profile?.email,
                keyboard: TextInputType.emailAddress,
                validate: (v) => v.isEmpty || v.contains('@')
                    ? null
                    : l10n.t('profile.emailLooksWrong'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(
                l10n.t('profile.contactNote'),
                style: const TextStyle(fontSize: 11.5, color: Palette.inkSoft, height: 1.5),
              ),
            ),

            // ── Doctor-only ──
            if (isDoctor) ...[
              const SizedBox(height: 26),
              SectionHeader(title: l10n.t('profile.doctorDetails')),
              _Row(
                icon: Icons.medical_information_outlined,
                label: l10n.t('profile.specialization'),
                value: profile?.specialization ?? '',
                placeholder: l10n.t('profile.notSet'),
                onTap: () => _editField(
                  title: l10n.t('profile.specialization'),
                  field: 'specialization',
                  current: profile?.specialization,
                ),
              ),
              _Row(
                icon: Icons.notes_rounded,
                label: l10n.t('profile.bio'),
                value: profile?.bio ?? '',
                placeholder: l10n.t('profile.notSet'),
                onTap: () => _editField(
                  title: l10n.t('profile.bio'),
                  field: 'bio',
                  current: profile?.bio,
                  multiline: true,
                ),
              ),
              _Switch(
                icon: Icons.visibility_outlined,
                label: l10n.t('profile.showOnline'),
                subtitle: l10n.t('profile.showOnlineSub'),
                value: profile?.presenceVisible ?? true,
                onChanged: (v) => _save({'presenceVisible': v}),
              ),
            ],

            // ── Preferences ──
            const SizedBox(height: 26),
            SectionHeader(title: l10n.t('profile.preferences')),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: _LangButton(
                      label: 'English',
                      selected: !l10n.isUrdu,
                      onTap: () => _setLanguage(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _LangButton(
                      label: 'اردو',
                      selected: l10n.isUrdu,
                      onTap: () => _setLanguage(true),
                    ),
                  ),
                ],
              ),
            ),
            _Switch(
              icon: Icons.notifications_active_outlined,
              label: l10n.t('profile.notificationSound'),
              subtitle: l10n.t('profile.notificationSoundSub'),
              value: profile?.notificationSound ?? true,
              onChanged: (v) => _save({'notificationSound': v}),
            ),
            _Switch(
              icon: Icons.chat_outlined,
              label: l10n.t('profile.messageSound'),
              subtitle: l10n.t('profile.messageSoundSub'),
              value: profile?.messageSound ?? true,
              onChanged: (v) => _save({'messageSound': v}),
            ),

            // ── The clinic ──
            const SizedBox(height: 26),
            SectionHeader(title: l10n.t('profile.contact')),
            _Row(
              icon: Icons.call_outlined,
              label: l10n.t('common.callClinic'),
              value: AppConfig.clinicPhoneDisplay,
              onTap: () => dialClinic(context),
            ),
            _Row(
              icon: Icons.chat_bubble_outline_rounded,
              label: l10n.t('common.whatsapp'),
              value: AppConfig.clinicPhoneDisplay,
              onTap: () => openWhatsApp(context),
            ),
            _Row(
              icon: Icons.mail_outline_rounded,
              label: l10n.t('profile.emailUs'),
              value: AppConfig.supportEmail,
              onTap: () => openUrl(context, 'mailto:${AppConfig.supportEmail}'),
            ),
            _Row(
              icon: Icons.public_rounded,
              label: l10n.t('staff.openWebsite'),
              value: AppConfig.apiBaseUrl.replaceAll('https://', ''),
              onTap: () => openUrl(context, AppConfig.apiBaseUrl),
            ),

            // Debug builds only. It is a developer's tool — useful while the
            // app is being built and tested, and clutter on a patient's phone
            // once it ships. `kDebugMode` is a compile-time constant, so in a
            // release build this whole branch is removed rather than merely
            // skipped.
            if (kDebugMode) ...[
              const SizedBox(height: 26),
              SectionHeader(title: l10n.t('profile.developer')),
              _Row(
                icon: Icons.wifi_tethering_rounded,
                label: l10n.t('profile.diagnostics'),
                value: '',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const DiagnosticsScreen()),
                ),
              ),
            ],

            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _signOut,
                style: OutlinedButton.styleFrom(foregroundColor: Palette.crimsonDeep),
                icon: const Icon(Icons.logout_rounded, size: 19),
                label: Text(l10n.t('auth.signOut')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    String first(String s) => s.substring(0, 1).toUpperCase();
    if (parts.length == 1) return first(parts.first);
    return '${first(parts.first)}${first(parts.last)}';
  }
}

/// A tappable settings row: icon, label, current value, chevron.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.placeholder,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final empty = value.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Palette.paper,
        borderRadius: BorderRadius.circular(Palette.radiusSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Palette.radiusSm),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: Palette.line),
              borderRadius: BorderRadius.circular(Palette.radiusSm),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Palette.indigo),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Palette.ink,
                        ),
                      ),
                      if (!empty || placeholder != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          empty ? placeholder! : value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: empty ? Palette.line : Palette.inkSoft,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 20, color: Palette.inkSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(
          border: Border.all(color: Palette.line),
          borderRadius: BorderRadius.circular(Palette.radiusSm),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Palette.indigo),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Palette.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Palette.inkSoft),
                  ),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _LangButton extends StatelessWidget {
  const _LangButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE7F2EC) : Palette.paper,
      borderRadius: BorderRadius.circular(Palette.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Palette.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? Palette.indigo : Palette.line,
              width: selected ? 1.6 : 1,
            ),
            borderRadius: BorderRadius.circular(Palette.radiusSm),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected) ...[
                const Icon(Icons.check_rounded, size: 16, color: Palette.indigoDeep),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? Palette.indigoDeep : Palette.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
