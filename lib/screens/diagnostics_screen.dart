import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/palette.dart';
import '../core/session.dart';
import '../data/repository.dart';
import '../widgets/common.dart';

/// What the app thinks is true about itself, and whether the server agrees.
///
/// This is not a debug leftover — it is the screen that answers "the app isn't
/// working" without anyone having to guess. It separates the three things that
/// look identical from the outside: the phone has no connection, the server
/// refused this account, or the account has no role and so can see nothing.
///
/// Nothing secret is on it. A Firebase uid is not a credential, and the base
/// URL is the clinic's public website.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final _repo = Repository();
  final _results = <String, String>{};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _runAll();
  }

  @override
  void dispose() {
    _repo.close();
    super.dispose();
  }

  Future<void> _runAll() async {
    setState(() {
      _busy = true;
      _results.clear();
    });

    await _check('Services (public)', () async {
      final services = await _repo.services();
      return '${services.length} found';
    });

    await _check('Profile (needs sign-in)', () async {
      final profile = await _repo.profile();
      return profile == null ? 'no profile document' : '${profile.role} · ${profile.name}';
    });

    await _check('Appointments', () async {
      final list = await _repo.appointments(limit: 5);
      return '${list.length} found';
    });

    await _check('Doctors', () async {
      final list = await _repo.doctors();
      return '${list.length} found';
    });

    if (mounted) setState(() => _busy = false);
  }

  Future<void> _check(String label, Future<String> Function() run) async {
    try {
      final result = await run();
      if (mounted) setState(() => _results[label] = 'ok — $result');
    } on ApiException catch (e) {
      if (mounted) setState(() => _results[label] = 'HTTP ${e.statusCode}: ${e.message}');
    } catch (e) {
      if (mounted) setState(() => _results[label] = 'failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('profile.diagnostics'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          _Block(
            title: 'Account',
            rows: {
              'signed in': session.signedIn ? 'yes' : 'no',
              'uid': session.user?.uid ?? '—',
              'role': session.role.name,
              'suspended': session.blocked ? 'yes' : 'no',
            },
          ),
          const SizedBox(height: 14),
          _Block(
            title: 'Build',
            rows: {
              'server': AppConfig.apiBaseUrl,
              'clinic': AppConfig.clinicPhoneDisplay,
              'language': l10n.isUrdu ? 'ur' : 'en',
            },
          ),
          const SizedBox(height: 14),
          _Block(title: 'Endpoints', rows: _results),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _busy ? null : _runAll,
              child: Text(_busy ? l10n.t('common.loading') : l10n.t('common.retry')),
            ),
          ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.rows});

  final String title;
  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Palette.line),
        borderRadius: BorderRadius.circular(Palette.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, color: Palette.ink),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const Text('…', style: TextStyle(color: Palette.inkSoft, fontSize: 13)),
          for (final entry in rows.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontSize: 11.5, color: Palette.inkSoft),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      // These are ids, URLs and HTTP messages — Latin text,
                      // which must not be mirrored when the app is in Urdu.
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: entry.value.startsWith('ok') ? Palette.success : Palette.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
