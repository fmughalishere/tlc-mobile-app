import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/formatting.dart';
import '../../core/palette.dart';
import '../../data/app_data.dart';
import '../../data/repository.dart';
import '../../i18n/strings.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import 'service_editor_screen.dart';

/// Everything the website says and charges: services, discount codes, posts.
///
/// Three collections behind one segmented control, because they are one job.
/// Someone who has just put the price up on a treatment is often the same
/// person, in the same five minutes, issuing the code that discounts it and
/// writing the post that announces it — and on a phone, three separate tabs
/// for that means three trips through the bottom bar.
class AdminCatalogueTab extends StatefulWidget {
  const AdminCatalogueTab({super.key});

  @override
  State<AdminCatalogueTab> createState() => _AdminCatalogueTabState();
}

class _AdminCatalogueTabState extends State<AdminCatalogueTab> {
  final _repo = Repository();
  int _section = 0;

  List<Coupon> _coupons = const [];
  List<BlogPost> _posts = const [];
  bool _couponsLoaded = false;
  bool _postsLoaded = false;

  /// In-flight guards. The list builders below call `_ensureLoaded` when they
  /// find nothing loaded yet, and a screen rebuilds more than once while a
  /// request is out — without these, one glance at Codes could fire four
  /// identical requests.
  bool _couponsLoading = false;
  bool _postsLoading = false;
  String? _busyId;

  @override
  void dispose() {
    _repo.close();
    super.dispose();
  }

  /// Loaded on first look rather than at startup. An admin who only ever opens
  /// Services should not be paying for the blog on every launch.
  Future<void> _ensureLoaded(int section) async {
    if (section == 1 && !_couponsLoaded) await _loadCoupons();
    if (section == 2 && !_postsLoaded) await _loadPosts();
  }

  Future<void> _loadCoupons() async {
    if (_couponsLoading) return;
    _couponsLoading = true;
    try {
      final list = await _repo.coupons();
      if (mounted) setState(() {
        _coupons = list;
        _couponsLoaded = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _couponsLoaded = true);
        showToast(context, errorText(e), error: true);
      }
    } finally {
      _couponsLoading = false;
    }
  }

  Future<void> _loadPosts() async {
    if (_postsLoading) return;
    _postsLoading = true;
    try {
      final list = await _repo.blogs(includeDrafts: true);
      if (mounted) setState(() {
        _posts = list;
        _postsLoaded = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _postsLoaded = true);
        showToast(context, errorText(e), error: true);
      }
    } finally {
      _postsLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.t('adm.cat.title')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 0, label: Text(l10n.t('adm.cat.services'))),
                  ButtonSegment(value: 1, label: Text(l10n.t('adm.cat.coupons'))),
                  ButtonSegment(value: 2, label: Text(l10n.t('adm.cat.blog'))),
                ],
                selected: {_section},
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12.5)),
                ),
                onSelectionChanged: (set) {
                  final next = set.first;
                  setState(() => _section = next);
                  _ensureLoaded(next);
                },
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => switch (_section) {
          0 => _newService(),
          1 => _newCoupon(),
          _ => _newPost(),
        },
        backgroundColor: Palette.crimson,
        foregroundColor: Palette.paper,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          switch (_section) {
            0 => l10n.t('adm.cat.newService'),
            1 => l10n.t('adm.cat.newCoupon'),
            _ => l10n.t('adm.cat.newPost'),
          },
        ),
      ),
      body: switch (_section) {
        0 => _servicesList(context),
        1 => _couponsList(context),
        _ => _postsList(context),
      },
    );
  }

  // ── Services ──────────────────────────────────────────────────────────────

  Future<void> _newService() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ServiceEditorScreen()),
    );
    if (saved == true && mounted) await context.read<AppData>().refreshServices();
  }

  Future<void> _editService(Service service) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ServiceEditorScreen(service: service),
      ),
    );
    if (saved == true && mounted) await context.read<AppData>().refreshServices();
  }

  Future<void> _deleteService(Service service) async {
    final l10n = context.read<LocaleController>();
    final data = context.read<AppData>();
    final ok = await _confirm(
      l10n.t('adm.cat.deleteService'),
      '${service.name}\n\n${l10n.t('adm.cat.deleteServiceSub')}',
    );
    if (ok != true) return;

    setState(() => _busyId = service.id);
    try {
      await _repo.deleteService(service.id);
      await data.refreshServices();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Widget _servicesList(BuildContext context) {
    final l10n = context.l10n;
    final urdu = context.isUrdu;
    final data = context.watch<AppData>();

    if (!data.servicesLoaded && data.servicesLoading) return const LoadingView();

    return RefreshIndicator(
      onRefresh: data.refreshServices,
      child: data.services.isEmpty
          ? ListView(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
              children: [
                EmptyState(
                  icon: Icons.medical_services_outlined,
                  title: l10n.t('services.empty'),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
              itemCount: data.services.length,
              itemBuilder: (context, i) {
                final s = data.services[i];
                // How much Urdu the clinic has written for this one. Without
                // it the only way to find the gaps is to switch the whole app
                // to Urdu and go looking, which is how a catalogue stays half
                // translated for a year.
                final translated = [
                  s.nameUr != null,
                  s.shortUr != null,
                  s.introUr != null,
                  s.pointsUr.isNotEmpty,
                  s.treatmentsUr.isNotEmpty,
                ].where((x) => x).length;

                return _Row(
                  busy: _busyId == s.id,
                  title: s.displayName(urdu),
                  subtitle: [
                    s.category,
                    if (s.price != null) Fmt.money(s.price),
                    if (s.durationMinutes != null)
                      '${s.durationMinutes!.round()} min',
                  ].join(' · '),
                  badge: translated == 5
                      ? null
                      : '${l10n.t('adm.cat.urdu')} $translated/5',
                  onTap: () => _editService(s),
                  onDelete: () => _deleteService(s),
                );
              },
            ),
    );
  }

  // ── Coupons ───────────────────────────────────────────────────────────────

  Future<void> _newCoupon() async {
    final made = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Palette.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Palette.radiusLg)),
      ),
      builder: (_) => _NewCouponSheet(repo: _repo),
    );
    if (made == true) await _loadCoupons();
  }

  Future<void> _toggleCoupon(Coupon c) async {
    setState(() => _busyId = c.code);
    try {
      await _repo.setCouponActive(c.code, !c.active);
      await _loadCoupons();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _deleteCoupon(Coupon c) async {
    final l10n = context.read<LocaleController>();
    final ok = await _confirm(
      l10n.t('adm.cat.deleteCoupon'),
      '${c.code}\n\n${l10n.t('adm.cat.deleteCouponSub')}',
    );
    if (ok != true) return;

    setState(() => _busyId = c.code);
    try {
      await _repo.deleteCoupon(c.code);
      await _loadCoupons();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Widget _couponsList(BuildContext context) {
    final l10n = context.l10n;
    if (!_couponsLoaded) {
      _ensureLoaded(1);
      return const LoadingView();
    }

    return RefreshIndicator(
      onRefresh: _loadCoupons,
      child: _coupons.isEmpty
          ? ListView(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
              children: [
                EmptyState(
                  icon: Icons.local_offer_outlined,
                  title: l10n.t('adm.cat.noCoupons'),
                  message: l10n.t('adm.cat.noCouponsSub'),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
              itemCount: _coupons.length,
              itemBuilder: (context, i) {
                final c = _coupons[i];
                // Three different reasons a code will not work, and "inactive"
                // alone cannot tell them apart — so each one is named.
                final reason = !c.active
                    ? l10n.t('adm.cat.switchedOff')
                    : c.expired
                        ? l10n.t('adm.cat.expiredTag')
                        : c.exhausted
                            ? l10n.t('adm.cat.usedUp')
                            : null;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      border: Border.all(color: Palette.line),
                      borderRadius: BorderRadius.circular(Palette.radiusCard),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                c.code,
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                  color: Palette.ink,
                                ),
                              ),
                            ),
                            StatusPill(
                              status: c.usable ? 'confirmed' : 'pending',
                              label: reason ?? l10n.t('adm.cat.liveTag'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          [
                            c.isPercent
                                ? '${c.discountValue.round()}% ${l10n.t('adm.cat.off')}'
                                : '${Fmt.money(c.discountValue)} ${l10n.t('adm.cat.off')}',
                            '${c.usedCount}/${c.maxUses} ${l10n.t('adm.cat.used')}',
                            if (c.expiresAt != null)
                              '${l10n.t('adm.cat.until')} ${Fmt.date(c.expiresAt)}',
                          ].join(' · '),
                          style: const TextStyle(fontSize: 12.5, color: Palette.inkSoft),
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed:
                                  _busyId == c.code ? null : () => _toggleCoupon(c),
                              child: Text(
                                c.active
                                    ? l10n.t('adm.cat.switchOff')
                                    : l10n.t('adm.cat.switchOn'),
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  _busyId == c.code ? null : () => _deleteCoupon(c),
                              style: TextButton.styleFrom(
                                foregroundColor: Palette.crimsonDeep,
                              ),
                              child: Text(
                                l10n.t('adm.cat.delete'),
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  // ── Blog ──────────────────────────────────────────────────────────────────

  Future<void> _newPost() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Palette.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Palette.radiusLg)),
      ),
      builder: (_) => _NewPostSheet(repo: _repo),
    );
    if (saved == true) await _loadPosts();
  }

  Future<void> _togglePublished(BlogPost post) async {
    setState(() => _busyId = post.id);
    try {
      await _repo.updateBlog(post.id, {'published': !post.published});
      await _loadPosts();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _deletePost(BlogPost post) async {
    final l10n = context.read<LocaleController>();
    final ok = await _confirm(
      l10n.t('adm.cat.deletePost'),
      '${post.title}\n\n${l10n.t('adm.cat.deletePostSub')}',
    );
    if (ok != true) return;

    setState(() => _busyId = post.id);
    try {
      await _repo.deleteBlog(post.id);
      await _loadPosts();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Widget _postsList(BuildContext context) {
    final l10n = context.l10n;
    if (!_postsLoaded) {
      _ensureLoaded(2);
      return const LoadingView();
    }

    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
        children: [
          // Long-form writing and the two-column Urdu translation screen stay
          // on the website. A phone is the wrong tool for an hour of careful
          // reading against a second column, and pretending otherwise would
          // produce something nobody would use for it.
          Container(
            padding: const EdgeInsets.all(13),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Palette.paperDim,
              borderRadius: BorderRadius.circular(Palette.radiusSm),
            ),
            child: Row(
              children: [
                const Icon(Icons.desktop_windows_outlined,
                    size: 17, color: Palette.inkSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.t('adm.cat.longFormNote'),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Palette.inkSoft,
                      height: 1.55,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      openUrl(context, '${AppConfig.apiBaseUrl}/admin/blogs'),
                  child: Text(
                    l10n.t('adm.cat.open'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          if (_posts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: EmptyState(
                icon: Icons.article_outlined,
                title: l10n.t('adm.cat.noPosts'),
              ),
            )
          else
            for (final post in _posts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    border: Border.all(color: Palette.line),
                    borderRadius: BorderRadius.circular(Palette.radiusCard),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              post.title,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: Palette.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          StatusPill(
                            status: post.published ? 'confirmed' : 'pending',
                            label: post.published
                                ? l10n.t('adm.cat.published')
                                : l10n.t('adm.cat.draft'),
                          ),
                        ],
                      ),
                      if (post.excerpt.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          post.excerpt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Palette.inkSoft,
                            height: 1.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _busyId == post.id
                                ? null
                                : () => _togglePublished(post),
                            child: Text(
                              post.published
                                  ? l10n.t('adm.cat.unpublish')
                                  : l10n.t('adm.cat.publish'),
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                          TextButton(
                            onPressed:
                                _busyId == post.id ? null : () => _deletePost(post),
                            style: TextButton.styleFrom(
                              foregroundColor: Palette.crimsonDeep,
                            ),
                            child: Text(
                              l10n.t('adm.cat.delete'),
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<bool?> _confirm(String title, String message) {
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
            style: TextButton.styleFrom(foregroundColor: Palette.crimsonDeep),
            child: Text(l10n.t('adm.cat.delete')),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onDelete,
    required this.busy,
    this.badge,
  });

  final String title;
  final String subtitle;
  final String? badge;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Palette.paper,
        borderRadius: BorderRadius.circular(Palette.radiusCard),
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(Palette.radiusCard),
          child: Container(
            padding: const EdgeInsets.fromLTRB(15, 13, 6, 13),
            decoration: BoxDecoration(
              border: Border.all(color: Palette.line),
              borderRadius: BorderRadius.circular(Palette.radiusCard),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: Palette.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12, color: Palette.inkSoft),
                      ),
                      if (badge != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDF3E2),
                            borderRadius: BorderRadius.circular(Palette.radiusPill),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Palette.warning,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: busy
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded, size: 19),
                  color: Palette.inkSoft,
                  onPressed: busy ? null : onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sheets ──────────────────────────────────────────────────────────────────

class _NewCouponSheet extends StatefulWidget {
  const _NewCouponSheet({required this.repo});
  final Repository repo;

  @override
  State<_NewCouponSheet> createState() => _NewCouponSheetState();
}

class _NewCouponSheetState extends State<_NewCouponSheet> {
  final _code = TextEditingController();
  final _value = TextEditingController();
  final _maxUses = TextEditingController(text: '1');

  bool _percent = true;
  DateTime? _expires;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _value.dispose();
    _maxUses.dispose();
    super.dispose();
  }

  String? _iso(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    final l10n = context.read<LocaleController>();
    final code = _code.text.trim().toUpperCase();
    final value = num.tryParse(_value.text.trim());

    if (code.isEmpty) {
      setState(() => _error = l10n.t('adm.cat.needCode'));
      return;
    }
    if (value == null || value <= 0) {
      setState(() => _error = l10n.t('adm.cat.needValue'));
      return;
    }
    if (_percent && value > 100) {
      setState(() => _error = l10n.t('adm.cat.percentTooBig'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repo.createCoupon(
        code: code,
        discountType: _percent ? 'percent' : 'flat',
        discountValue: value,
        maxUses: int.tryParse(_maxUses.text.trim()) ?? 1,
        expiresAt: _iso(_expires),
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
                l10n.t('adm.cat.newCoupon'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: l10n.t('adm.cat.code'),
                  hintText: 'EID25',
                  helperText: l10n.t('adm.cat.codeHelp'),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(value: true, label: Text(l10n.t('adm.cat.percent'))),
                        ButtonSegment(value: false, label: Text(l10n.t('adm.cat.flat'))),
                      ],
                      selected: {_percent},
                      showSelectedIcon: false,
                      style: const ButtonStyle(visualDensity: VisualDensity.compact),
                      onSelectionChanged: (s) => setState(() => _percent = s.first),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _value,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: _percent
                      ? l10n.t('adm.cat.percentOff')
                      : l10n.t('adm.cat.rupeesOff'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _maxUses,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(labelText: l10n.t('adm.cat.maxUses')),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _expires ?? DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (picked != null) setState(() => _expires = picked);
                },
                borderRadius: BorderRadius.circular(Palette.radiusSm),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    border: Border.all(color: Palette.line),
                    borderRadius: BorderRadius.circular(Palette.radiusSm),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_outlined, size: 19, color: Palette.inkSoft),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _expires == null
                              ? l10n.t('adm.cat.noExpiry')
                              : Fmt.dateLong(_iso(_expires)),
                          style: const TextStyle(fontSize: 13.5, color: Palette.ink),
                        ),
                      ),
                      if (_expires != null)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 17),
                          onPressed: () => setState(() => _expires = null),
                        ),
                    ],
                  ),
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
                  child: Text(l10n.t('adm.cat.createCoupon')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewPostSheet extends StatefulWidget {
  const _NewPostSheet({required this.repo});
  final Repository repo;

  @override
  State<_NewPostSheet> createState() => _NewPostSheetState();
}

class _NewPostSheetState extends State<_NewPostSheet> {
  final _title = TextEditingController();
  final _excerpt = TextEditingController();
  final _content = TextEditingController();
  bool _publish = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _excerpt.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.read<LocaleController>();
    if (_title.text.trim().isEmpty || _content.text.trim().isEmpty) {
      setState(() => _error = l10n.t('adm.cat.needTitleContent'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repo.createBlog({
        'title': _title.text.trim(),
        'excerpt': _excerpt.text.trim(),
        'content': _content.text.trim(),
        'published': _publish,
      });
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
                l10n.t('adm.cat.newPost'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l10n.t('adm.cat.postTitle')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _excerpt,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.t('adm.cat.postExcerpt'),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _content,
                maxLines: 10,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.t('adm.cat.postContent'),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _publish,
                onChanged: (v) => setState(() => _publish = v),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.t('adm.cat.publishNow'),
                  style: const TextStyle(fontSize: 13.5),
                ),
                subtitle: Text(
                  l10n.t('adm.cat.publishNowSub'),
                  style: const TextStyle(fontSize: 11.5),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: Text(l10n.t('common.save')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
