import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/apple_auth.dart';
import '../../core/palette.dart';
import '../../core/push.dart';
import '../../core/session.dart';
import '../../data/repository.dart';
import '../../i18n/strings.dart';
import '../../widgets/common.dart';

/// "Delete account", from the profile tab. Patients only — the server refuses
/// doctors and admins, and the profile tab does not offer it to them.
///
/// ── The order, and why ──
///
///   1. A dialog that says exactly what happens and needs a word typed.
///   2. Apple accounts: Apple is told to forget the app (one more sheet).
///   3. Push stops, while the token can still authorise the unregister —
///      the same first step `Session.signOut` takes.
///   4. `POST /api/account/delete`. The server deletes the Firebase user
///      last, after everything that needs it.
///   5. Only then a local sign-out. The login is already gone on the server;
///      signing out here is what puts the sign-in screen back.
///
/// If step 4 fails nothing has been signed out: push is started again and the
/// person is still in their account, able to try again or call the clinic.
/// Half-deleted and half-signed-out is the one state this must never leave.
Future<void> confirmAndDeleteAccount(BuildContext context) async {
  final l10n = context.read<LocaleController>();
  final session = context.read<Session>();
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => const _ConfirmDeleteDialog(),
  );
  if (confirmed != true || !context.mounted) return;

  // A cancelled Apple sheet means they changed their mind: stop quietly.
  final carryOn = await revokeAppleSignIn();
  if (!carryOn || !context.mounted) return;

  // Nothing on screen may be tapped while this runs — a second press, or
  // navigating away, halfway through closing an account helps nobody.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(width: 18),
            Expanded(child: Text(l10n.t('account.deleting'))),
          ],
        ),
      ),
    ),
  );

  final repo = Repository();
  try {
    await pushService.stop();
    await repo.deleteAccount();
  } catch (e) {
    navigator.pop();
    // Still signed in, so notifications should keep working.
    pushService.start().catchError((Object _) {});
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${l10n.t('account.deleteFailed')} ${errorText(e)}'),
          backgroundColor: Palette.crimsonDeep,
        ),
      );
    return;
  } finally {
    repo.close();
  }

  navigator.pop();

  // The messenger sits above the gate, so this survives the screen being
  // swapped for the sign-in one a frame later.
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(l10n.t('account.deleted')),
      backgroundColor: Palette.ink,
    ));

  try {
    await session.signOut();
  } catch (error) {
    // The server has already removed the login, and Session cleared its own
    // state before this could throw — the person is out either way.
    debugPrint('[account] local sign-out after delete: $error');
  }
}

/// Says what deletion does, and enables the button only once the word is
/// typed. Honest about what is kept as well as what goes.
class _ConfirmDeleteDialog extends StatefulWidget {
  const _ConfirmDeleteDialog();

  @override
  State<_ConfirmDeleteDialog> createState() => _ConfirmDeleteDialogState();
}

class _ConfirmDeleteDialogState extends State<_ConfirmDeleteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Either language's word is accepted, whichever the app is showing — a
  /// person who switched language mid-way should not be told they typed it
  /// wrong.
  bool get _matches {
    final typed = _controller.text.trim();
    return typed.toUpperCase() == 'DELETE' || typed == 'حذف';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final word = l10n.t('account.deleteWord');
    const body = TextStyle(fontSize: 13.5, height: 1.5, color: Palette.ink);

    return AlertDialog(
      title: Text(l10n.t('account.deleteTitle')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.t('account.deleteIntro'), style: body),
            const SizedBox(height: 10),
            Bullet(l10n.t('account.deleteUpcoming')),
            Bullet(l10n.t('account.deleteLogin')),
            Bullet(l10n.t('account.deleteNotifications')),
            Bullet(l10n.t('account.deleteRecords')),
            const SizedBox(height: 10),
            Text(
              l10n.t('account.deleteFinal'),
              style: body.copyWith(
                fontWeight: FontWeight.w700,
                color: Palette.crimsonDeep,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.t('account.deleteTypePrompt').replaceAll('{word}', word),
              style: body,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: word),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.t('common.cancel')),
        ),
        TextButton(
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          style: TextButton.styleFrom(foregroundColor: Palette.crimsonDeep),
          child: Text(l10n.t('account.deleteForever')),
        ),
      ],
    );
  }
}
