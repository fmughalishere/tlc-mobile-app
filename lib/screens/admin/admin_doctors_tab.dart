import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/palette.dart';
import '../../data/repository.dart';
import '../../i18n/strings.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

/// The clinic's doctors: approving them, suspending them, adding them.
///
/// Pending requests come first and cannot be scrolled past. A doctor who
/// signed up on the website is invisible to patients and locked out of their
/// own dashboard until somebody here says yes — so a request sitting unseen at
/// the bottom of a list is a person waiting on the clinic without knowing it.
class AdminDoctorsTab extends StatefulWidget {
  const AdminDoctorsTab({super.key});

  @override
  State<AdminDoctorsTab> createState() => _AdminDoctorsTabState();
}

class _AdminDoctorsTabState extends State<AdminDoctorsTab> {
  final _repo = Repository();
  List<Doctor> _doctors = const [];

  /// The approval state is not on the `Doctor` model — a patient never sees
  /// it, so it is not part of the shape the app shares. Admin needs it, so it
  /// is read out of the raw response and kept beside the list.
  Map<String, String> _approval = const {};

  bool _loading = true;
  Object? _error;
  String? _busyUid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _repo.close();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await _repo.allDoctorsRaw();
      if (!mounted) return;
      setState(() {
        _doctors = rows.map(Doctor.fromJson).toList();
        _approval = {
          for (final r in rows)
            '${r['uid']}': '${r['approvalStatus'] ?? 'approved'}',
        };
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _run(String uid, Future<void> Function() action) async {
    setState(() => _busyUid = uid);
    try {
      await action();
      await _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  Future<void> _decide(Doctor d, String status) async {
    final l10n = context.read<LocaleController>();
    if (status == 'rejected') {
      final ok = await _confirm(
        l10n.t('adm.doc.rejectTitle'),
        l10n.t('adm.doc.rejectSub'),
        destructive: true,
      );
      if (ok != true) return;
    }
    await _run(d.uid, () async {
      await _repo.setDoctorApproval(d.uid, status);
      if (mounted) {
        showToast(
          context,
          status == 'approved' ? l10n.t('adm.doc.approved') : l10n.t('adm.doc.rejected'),
        );
      }
    });
  }

  Future<void> _toggleActive(Doctor d) async {
    final l10n = context.read<LocaleController>();
    if (d.active) {
      final ok = await _confirm(
        l10n.t('adm.doc.suspendTitle'),
        l10n.t('adm.doc.suspendSub'),
        destructive: true,
      );
      if (ok != true) return;
    }
    await _run(d.uid, () => _repo.setDoctorActive(d.uid, !d.active));
  }

  Future<bool?> _confirm(String title, String message, {bool destructive = false}) {
    final l10n = context.read<LocaleController>();
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: destructive
                ? TextButton.styleFrom(foregroundColor: Palette.crimsonDeep)
                : null,
            child: Text(l10n.t('common.confirm')),
          ),
        ],
      ),
    );
  }

  Future<void> _addDoctor() async {
    final l10n = context.read<LocaleController>();
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Palette.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Palette.radiusLg)),
      ),
      builder: (_) => _AddDoctorSheet(repo: _repo),
    );
    if (created == true) {
      if (mounted) showToast(context, l10n.t('adm.doc.created'));
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final pending =
        _doctors.where((d) => _approval[d.uid] == 'pending').toList();
    final rest = _doctors.where((d) => _approval[d.uid] != 'pending').toList()
      ..sort((a, b) {
        if (a.active != b.active) return a.active ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.t('adm.doc.title')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDoctor,
        backgroundColor: Palette.crimson,
        foregroundColor: Palette.paper,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(l10n.t('adm.doc.add')),
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 96),
                    children: [
                      if (pending.isNotEmpty) ...[
                        SectionHeader(
                          title: '${l10n.t('adm.doc.pending')} (${pending.length})',
                        ),
                        Text(
                          l10n.t('adm.doc.pendingSub'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Palette.inkSoft,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final d in pending)
                          _PendingCard(
                            doctor: d,
                            busy: _busyUid == d.uid,
                            onApprove: () => _decide(d, 'approved'),
                            onReject: () => _decide(d, 'rejected'),
                          ),
                        const SizedBox(height: 24),
                      ],
                      SectionHeader(title: l10n.t('adm.doc.all')),
                      if (rest.isEmpty)
                        Text(
                          l10n.t('doctors.empty'),
                          style: const TextStyle(fontSize: 12.5, color: Palette.inkSoft),
                        )
                      else
                        for (final d in rest)
                          _DoctorCard(
                            doctor: d,
                            rejected: _approval[d.uid] == 'rejected',
                            busy: _busyUid == d.uid,
                            onToggleActive: () => _toggleActive(d),
                          ),
                    ],
                  ),
                ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.doctor,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final Doctor doctor;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF3E2),
          borderRadius: BorderRadius.circular(Palette.radiusCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Avatar(initials: doctor.initials, size: 42),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctor.displayName,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Palette.ink,
                        ),
                      ),
                      if (doctor.specialization != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          doctor.specialization!,
                          style: const TextStyle(fontSize: 12, color: Palette.inkSoft),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (doctor.bio != null) ...[
              const SizedBox(height: 10),
              Text(
                doctor.bio!,
                style: const TextStyle(fontSize: 12.5, color: Palette.ink, height: 1.55),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton(
                  onPressed: busy ? null : onApprove,
                  style: FilledButton.styleFrom(
                    backgroundColor: Palette.indigoDeep,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  ),
                  child: Text(
                    l10n.t('adm.doc.approve'),
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
                OutlinedButton(
                  onPressed: busy ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Palette.crimsonDeep,
                    side: const BorderSide(color: Palette.crimson),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  ),
                  child: Text(
                    l10n.t('adm.doc.reject'),
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  const _DoctorCard({
    required this.doctor,
    required this.rejected,
    required this.busy,
    required this.onToggleActive,
  });

  final Doctor doctor;
  final bool rejected;
  final bool busy;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          border: Border.all(color: Palette.line),
          borderRadius: BorderRadius.circular(Palette.radiusCard),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Avatar(
                  initials: doctor.initials,
                  photoURL: doctor.photoURL,
                  size: 42,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctor.displayName,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: Palette.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (doctor.online) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Palette.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Flexible(
                            child: Text(
                              doctor.specialization ??
                                  (doctor.online
                                      ? l10n.t('doctors.online')
                                      : l10n.t('doctors.offline')),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Palette.inkSoft,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (rejected)
                  StatusPill(status: 'cancelled', label: l10n.t('adm.doc.rejectedTag'))
                else
                  StatusPill(
                    status: doctor.active ? 'confirmed' : 'pending',
                    label: doctor.active
                        ? l10n.t('adm.doc.activeTag')
                        : l10n.t('adm.doc.suspendedTag'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: busy ? null : onToggleActive,
                style: TextButton.styleFrom(
                  foregroundColor:
                      doctor.active ? Palette.crimsonDeep : Palette.indigo,
                ),
                child: Text(
                  doctor.active ? l10n.t('adm.doc.suspend') : l10n.t('adm.doc.reinstate'),
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Creating a doctor account.
///
/// The password is set by the admin and handed over — that is how the clinic
/// actually onboards someone, and it is what the website's own form does. It
/// is typed once and never shown again: the app does not keep it, and the
/// server hands it straight to Firebase Auth.
class _AddDoctorSheet extends StatefulWidget {
  const _AddDoctorSheet({required this.repo});

  final Repository repo;

  @override
  State<_AddDoctorSheet> createState() => _AddDoctorSheetState();
}

class _AddDoctorSheetState extends State<_AddDoctorSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _specialization = TextEditingController();
  final _bio = TextEditingController();

  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _specialization.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.read<LocaleController>();
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;

    if (name.isEmpty) {
      setState(() => _error = l10n.t('auth.needName'));
      return;
    }
    if (!email.contains('@')) {
      setState(() => _error = l10n.t('auth.needEmail'));
      return;
    }
    // Eight, not six: this is the server's rule for a doctor account, and
    // failing here with a clear message beats a 400 after the round trip.
    if (password.length < 8) {
      setState(() => _error = l10n.t('adm.doc.needPassword'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repo.createDoctor(
        name: name,
        email: email,
        password: password,
        specialization: _specialization.text.trim(),
        bio: _bio.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
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

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('adm.doc.add'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                l10n.t('adm.doc.addSub'),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Palette.inkSoft,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l10n.t('auth.name')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(labelText: l10n.t('auth.email')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: _obscure,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: l10n.t('adm.doc.tempPassword'),
                  helperText: l10n.t('adm.doc.tempPasswordHelp'),
                  helperMaxLines: 2,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _specialization,
                decoration: InputDecoration(
                  labelText:
                      '${l10n.t('profile.specialization')} (${l10n.t('common.optional')})',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bio,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: '${l10n.t('profile.bio')} (${l10n.t('common.optional')})',
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
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Palette.paper),
                          ),
                        )
                      : Text(l10n.t('adm.doc.create')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
