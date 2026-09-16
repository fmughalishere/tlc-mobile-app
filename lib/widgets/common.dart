import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/palette.dart';
import '../i18n/strings.dart';

/// Shorthands used on every screen.
///
/// `context.t('nav.home')` instead of
/// `context.watch<LocaleController>().t('nav.home')` is not only shorter — it
/// keeps the `watch` in one place, so no screen accidentally uses `read` and
/// then fails to rebuild when the language changes.
extension L10nContext on BuildContext {
  LocaleController get l10n => watch<LocaleController>();
  String t(String key) => watch<LocaleController>().t(key);
  bool get isUrdu => watch<LocaleController>().isUrdu;
}

/// One place that turns a Future into a screen.
///
/// Every list in this app has the same four states — loading, failed,
/// empty, and loaded — and before this existed each screen spelled all four
/// out again. The one that matters is *failed*: an app that shows an endless
/// spinner when the server is down is worse than one that says so, because the
/// patient keeps waiting instead of picking up the phone.
class AsyncView<T> extends StatefulWidget {
  const AsyncView({
    super.key,
    required this.load,
    required this.builder,
    this.emptyWhen,
    this.emptyTitle,
    this.emptyMessage,
    this.padding = const EdgeInsets.all(20),
    this.pullToRefresh = true,
  });

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;

  /// Returns true when the loaded data is "nothing to show".
  final bool Function(T data)? emptyWhen;
  final String? emptyTitle;
  final String? emptyMessage;
  final EdgeInsets padding;

  /// Off when the builder returns something that is not itself one scroll
  /// view — a TabBarView, say, whose tabs bring their own refresh gesture.
  /// Two nested RefreshIndicators show two spinners for one pull.
  final bool pullToRefresh;

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  Future<void> _reload() async {
    setState(() => _future = widget.load());
    // Swallowed on purpose: the failure is already going to be rendered by
    // the FutureBuilder below. Letting it escape here would also surface it
    // as an unhandled error from the pull-to-refresh gesture.
    try {
      await _future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        if (snapshot.hasError) {
          return ErrorView(error: snapshot.error!, onRetry: _reload);
        }
        final data = snapshot.data as T;
        final isEmpty = widget.emptyWhen?.call(data) ?? false;
        if (isEmpty) {
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: widget.padding,
              children: [
                const SizedBox(height: 60),
                EmptyState(
                  title: widget.emptyTitle ?? context.t('common.nothingHere'),
                  message: widget.emptyMessage,
                ),
              ],
            ),
          );
        }
        final child = widget.builder(context, data, _reload);
        if (!widget.pullToRefresh) return child;
        return RefreshIndicator(onRefresh: _reload, child: child);
      },
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
}

/// What the patient sees when a call fails.
///
/// The clinic's phone number is on this screen deliberately. A person who
/// opened the app to move an appointment and cannot reach the server still
/// has something they can do, and it is the same thing they would have done
/// before the app existed.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isAuth = error is ApiException && (error as ApiException).isAuth;
    final message = errorText(error);

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 60, 28, 28),
      children: [
        Icon(
          isAuth ? Icons.lock_outline_rounded : Icons.cloud_off_rounded,
          size: 40,
          color: Palette.inkSoft,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.t('common.somethingWrong'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        if (onRetry != null)
          Center(
            child: OutlinedButton(
              onPressed: () => onRetry!(),
              child: Text(l10n.t('common.retry')),
            ),
          ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.message, this.icon});

  final String title;
  final String? message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon ?? Icons.inbox_outlined, size: 38, color: Palette.line),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

/// A small status chip. The colour carries meaning, so it is derived from the
/// status rather than passed in — the same status is the same colour on every
/// screen, which is what makes a list scannable.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status, required this.label});

  final String status;
  final String label;

  static const _colors = <String, List<Color>>{
    // background, foreground
    'pending': [Palette.mist, Palette.inkSoft],
    'awaiting-payment': [Color(0xFFFDF3E2), Palette.warning],
    'confirmed': [Color(0xFFE7F2EC), Palette.indigoDeep],
    'completed': [Palette.successSoft, Palette.success],
    'cancelled': [Palette.dangerSoft, Palette.crimsonDeep],
  };

  @override
  Widget build(BuildContext context) {
    final pair = _colors[status] ?? const [Palette.mist, Palette.inkSoft];
    return ConstrainedBox(
      // A pill is a label, not a paragraph.
      //
      // Unconstrained in a Row it takes whatever its text asks for, and a long
      // status — "Waiting for your payment" — left the appointment beside it a
      // sliver to wrap into, one or two characters per line. The card looked
      // broken, and on a narrow phone every status long enough to matter did
      // it. Capped here rather than at each call site, because every call site
      // has the same problem and only one of them had been noticed.
      constraints: const BoxConstraints(maxWidth: 132),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: pair[0],
          borderRadius: BorderRadius.circular(Palette.radiusPill),
        ),
        child: Text(
          label,
          // Two lines rather than an ellipsis: "Waiting for your…" tells a
          // doctor scanning a list nothing, and these labels are short enough
          // that two lines always finishes them.
          maxLines: 2,
          style: TextStyle(
            fontSize: 11,
            height: 1.25,
            fontWeight: FontWeight.w600,
            color: pair[1],
          ),
        ),
      ),
    );
  }
}

/// A section title with an optional action on the far side. "Far side" and
/// not "right": in Urdu the layout is mirrored, and a Row inside a
/// Directionality already does the right thing.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// A card that is a button. Used for every "pick one of these" list in the
/// booking flow, so choosing a service and choosing a time feel like the same
/// kind of act.
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.selected = false,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? const Color(0xFFE7F2EC) : Palette.paper,
        borderRadius: BorderRadius.circular(Palette.radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Palette.radiusCard),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? Palette.indigo : Palette.line,
                width: selected ? 1.6 : 1,
              ),
              borderRadius: BorderRadius.circular(Palette.radiusCard),
            ),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 14)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Palette.ink,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: const TextStyle(fontSize: 13, color: Palette.inkSoft),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 10), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A label/value row, used on every detail screen.
class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, required this.value, this.emphasis = false});

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: Palette.inkSoft),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Palette.ink,
                fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A bulleted line. The dot is drawn rather than typed so it stays put in
/// Urdu, where a "•" typed into the string lands on the wrong side.
class Bullet extends StatelessWidget {
  const Bullet(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7),
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: Palette.indigo,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Five stars, read-only.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.value, this.size = 16});

  final num value;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = value >= i + 1;
        final half = !filled && value > i;
        return Icon(
          half ? Icons.star_half_rounded : Icons.star_rounded,
          size: size,
          color: (filled || half) ? const Color(0xFFE8A317) : Palette.line,
        );
      }),
    );
  }
}

/// The circle with someone's initials, used wherever there is no photo.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.initials, this.photoURL, this.size = 44});

  final String initials;
  final String? photoURL;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (photoURL != null && photoURL!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoURL!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          // A broken photo URL must not take the screen down with it.
          errorBuilder: (_, __, ___) => _initialsCircle(),
        ),
      );
    }
    return _initialsCircle();
  }

  Widget _initialsCircle() => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFFE7F2EC),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          textDirection: TextDirection.ltr,
          style: TextStyle(
            color: Palette.indigoDeep,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.36,
          ),
        ),
      );
}

/// Opens the dialler with the clinic's number already in it.
///
/// The dialler, not a call: placing one would need the CALL_PHONE permission
/// and would dial without the patient confirming. Handing them a filled-in
/// dialler is both politer and one permission fewer to justify.
Future<void> dialClinic(BuildContext context) async {
  await _launch(context, Uri(scheme: 'tel', path: AppConfig.clinicPhoneE164));
}

/// WhatsApp, which in Pakistan is often the way people actually reach a
/// business. wa.me handles the "is it installed" question itself.
Future<void> openWhatsApp(BuildContext context) async {
  final number = AppConfig.clinicPhoneE164.replaceAll('+', '');
  await _launch(context, Uri.parse('https://wa.me/$number'));
}

Future<void> openUrl(BuildContext context, String url) async {
  await _launch(context, Uri.parse(url));
}

Future<void> _launch(BuildContext context, Uri uri) async {
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showToast(context, LocaleController.tr('net.cannotOpen'), error: true);
    }
  } catch (e) {
    if (context.mounted) showToast(context, errorText(e), error: true);
  }
}

/// Anything thrown, as a sentence a patient can read.
///
/// `ApiException` already carries the server's own wording — those messages are
/// written for a person ("You can only rate a completed appointment") — so it
/// passes straight through. Everything else is a fault in the app or the
/// platform, and its raw text ("Bad state: No element", a stack of
/// `_AssertionError`) tells the person nothing they can act on. They get a
/// plain sentence; the real text goes to the log, where it is useful.
String errorText(Object error) {
  if (error is ApiException) {
    final message = error.message.trim();
    // The API routes answer some failures with an i18n key rather than prose,
    // precisely so the app can say it in the reader's own language. A key that
    // this build does not know falls back to the generic sentence — a key is
    // never shown to a patient.
    if (RegExp(r'^[a-z]+\.[A-Za-z]+$').hasMatch(message)) {
      final text = LocaleController.tr(message);
      return text == message ? LocaleController.tr('net.generic') : text;
    }
    return message;
  }
  debugPrint('[error] $error');
  return LocaleController.tr('net.generic');
}

/// Patient or doctor.
///
/// Public, and in this file rather than in one screen, because both the
/// sign-in and the create-account screens ask it and they have to look and
/// behave identically — a switch that sits half a pixel differently on the
/// next screen reads as a different control.
enum AccountRole { patient, doctor }

/// The patient / doctor switch: two halves of one pill.
///
/// Two halves rather than a dropdown, because there are exactly two answers
/// and the choice changes what the rest of the screen asks for. Which one is
/// selected should be readable at a glance, not one line of text inside a
/// closed menu.
class RoleSwitch extends StatelessWidget {
  const RoleSwitch({
    super.key,
    required this.role,
    required this.onChanged,
    this.enabled = true,
  });

  final AccountRole role;
  final bool enabled;
  final void Function(AccountRole) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    Widget half(AccountRole value, String label, IconData icon) {
      final selected = role == value;
      return Expanded(
        child: Material(
          color: selected ? Palette.indigo : Colors.transparent,
          borderRadius: BorderRadius.circular(Palette.radiusPill),
          child: InkWell(
            onTap: enabled ? () => onChanged(value) : null,
            borderRadius: BorderRadius.circular(Palette.radiusPill),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 17,
                    color: selected ? Palette.paper : Palette.inkSoft,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: selected ? Palette.paper : Palette.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border.all(color: Palette.line),
        borderRadius: BorderRadius.circular(Palette.radiusPill),
      ),
      child: Row(
        children: [
          half(AccountRole.patient, l10n.t('auth.imPatient'),
              Icons.person_outline_rounded),
          half(AccountRole.doctor, l10n.t('auth.imDoctor'),
              Icons.medical_services_outlined),
        ],
      ),
    );
  }
}

/// Google's own mark, drawn rather than shipped as a PNG.
///
/// Google's brand guidelines are specific about this button: their four
/// colours, unaltered, at a legible size. Drawing it means it stays sharp on
/// every screen density and adds nothing to the download.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  /// The G as four stroked arcs and one bar.
  ///
  /// A stroked arc rather than a filled wedge: the ring's thickness is then a
  /// single number instead of two radii and a boolean operation, and there is
  /// no path arithmetic that could go wrong at an unusual size.
  static const _degree = 0.017453292519943295; // one degree, in radians

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = s * 0.36;
    final stroke = s * 0.26;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    final box = Rect.fromCircle(center: centre, radius: radius);

    void arc(Color color, double startTurns, double sweepTurns) {
      paint.color = color;
      canvas.drawArc(box, startTurns, sweepTurns, false, paint);
    }

    // Angles run clockwise from three o'clock, as everywhere else in Flutter.
    arc(const Color(0xFFEA4335), -125 * _degree, 70 * _degree); // red, top left
    arc(const Color(0xFFFBBC05), 125 * _degree, 110 * _degree); // yellow, left
    arc(const Color(0xFF34A853), 40 * _degree, 85 * _degree); // green, bottom
    arc(const Color(0xFF4285F4), -55 * _degree, 95 * _degree); // blue, right

    // The bar into the centre, which is what turns a ring into a G.
    canvas.drawRect(
      Rect.fromLTRB(
        centre.dx,
        centre.dy - stroke * 0.38,
        centre.dx + radius + stroke / 2,
        centre.dy + stroke * 0.38,
      ),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The "Continue with Google" button, identical on both auth screens.
class GoogleButton extends StatelessWidget {
  const GoogleButton({
    super.key,
    required this.onPressed,
    required this.busy,
    required this.label,
  });

  final VoidCallback? onPressed;
  final bool busy;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: busy ? null : onPressed,
        icon: busy
            ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const GoogleMark(size: 18),
        label: Text(label),
      ),
    );
  }
}

/// The "or" rule between the form and the other ways in.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(color: Palette.inkSoft, fontSize: 12),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

/// A toast that says what actually happened.
void showToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Palette.crimsonDeep : Palette.ink,
      ),
    );
}
