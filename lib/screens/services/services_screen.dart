import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatting.dart';
import '../../core/palette.dart';
import '../../data/app_data.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import 'service_detail_screen.dart';

/// The clinic's catalogue, grouped by category.
///
/// `/api/services` needs no token, which is what lets this list be requested
/// the moment the app starts — before Firebase has finished booting and before
/// anyone has signed in. By the time this screen is opened the answer is
/// usually already here.
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key, this.embedded = false, this.onPick});

  /// True when shown as a tab inside the patient shell — it then has no back
  /// button and does not pop when a service is chosen.
  final bool embedded;

  /// Set by the booking flow: choosing a service returns it rather than
  /// opening the detail page.
  final void Function(Service service)? onPick;

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final urdu = context.isUrdu;
    final data = context.watch<AppData>();

    // Searching matches both languages at once, deliberately: a patient
    // reading Urdu may still type a treatment's English name, because that is
    // what they were told at the desk.
    final services = _query.isEmpty
        ? data.services
        : data.services.where((s) {
            final haystack = [
              s.name,
              s.nameUr ?? '',
              s.short,
              s.shortUr ?? '',
              s.category,
            ].join(' ').toLowerCase();
            return haystack.contains(_query);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: Text(l10n.t('services.title')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              controller: _search,
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: l10n.t('services.search'),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: !data.servicesLoaded && data.servicesLoading
                ? const LoadingView()
                : RefreshIndicator(
                    onRefresh: data.refreshServices,
                    child: _buildList(context, services, urdu),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Service> services, bool urdu) {
    final l10n = context.l10n;

    if (services.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 50),
          EmptyState(
            icon: _query.isEmpty ? Icons.medical_services_outlined : Icons.search_off_rounded,
            title: _query.isEmpty ? l10n.t('services.empty') : l10n.t('services.noMatch'),
            message: _query.isEmpty ? null : l10n.t('services.noMatchSub'),
          ),
        ],
      );
    }

    // Grouped by category, in the order the categories first appear — which is
    // the clinic's own `order` field, so the app shows the catalogue the way
    // the clinic arranged it.
    final categories = <String>[];
    final grouped = <String, List<Service>>{};
    for (final s in services) {
      final key = s.category.isEmpty ? '—' : s.category;
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
        categories.add(key);
      }
      grouped[key]!.add(s);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      itemCount: categories.length,
      itemBuilder: (context, i) {
        final category = categories[i];
        final items = grouped[category]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 4 : 22, bottom: 10),
              child: Text(
                category,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Palette.crimson,
                ),
              ),
            ),
            for (final service in items)
              ChoiceCard(
                title: service.displayName(urdu),
                subtitle: service.displayShort(urdu),
                trailing: service.price == null
                    ? const Icon(Icons.chevron_right_rounded, color: Palette.inkSoft)
                    : Text(
                        Fmt.money(service.price),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Palette.indigoDeep,
                        ),
                      ),
                onTap: () {
                  if (widget.onPick != null) {
                    widget.onPick!(service);
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ServiceDetailScreen(service: service),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
