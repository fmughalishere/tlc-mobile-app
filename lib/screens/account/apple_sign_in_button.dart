import 'package:flutter/material.dart';

/// "Sign in with Apple", the same size and shape as the Google button beside
/// it.
///
/// Apple's Human Interface Guidelines ask for this button to be at least as
/// prominent as any other sign-in option, and for it to be black or white
/// with Apple's own logo — so it is drawn black, with the logo, and it sits
/// above "Continue with Google" rather than below it. It inherits the theme's
/// outlined-button padding and pill shape, which is what keeps the two the
/// same height.
class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({
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
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.black.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white70,
          side: const BorderSide(color: Colors.black),
        ),
        icon: busy
            ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.apple, size: 21),
        label: Text(label),
      ),
    );
  }
}
