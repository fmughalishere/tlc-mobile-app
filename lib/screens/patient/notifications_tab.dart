import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatting.dart';
import '../../core/palette.dart';
import '../../data/app_data.dart';
import '../../widgets/common.dart';

/// Reminders, confirmations and the clinic's messages.
///
/// These are created server-side only — the app can read its own and mark them
/// read, and nothing more. That is why there is no "delete" here: a
/// notification the clinic sent is a record of what the patient was told, and
/// letting either side quietly remove it turns "we did remind you" into an
/// argument rather than a fact.
class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});

  static IconData _iconFor(String type) {
    switch (type) {
      case 'appointment-confirmed':
        return Icons.check_circle_outline_rounded;
      case 'appointment-cancelled':
        return Icons.cancel_outlined;
      case 'appointment-rescheduled':
        return Icons.update_rounded;
      case 'appointment-reminder':
      case 'appointment-starting-soon':
        return Icons.alarm_rounded;
      case 'appointment-awaiting-payment':
      case 'appointment-payment-expired':
        return Icons.payments_outlined;
      case 'doctor-assigned':
        return Icons.person_add_alt_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final data = context.watch<AppData>();
    final items = data.notifications;
    final unread = data.unreadCount;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.t('alerts.title')),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: data.markAllNotificationsRead,
              child: Text(l10n.t('alerts.markAllRead')),
            ),
        ],
      ),
      body: !data.notificationsLoaded && data.notificationsLoading
          ? const LoadingView()
          : RefreshIndicator(
              onRefresh: data.refreshNotifications,
              child: items.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(24, 70, 24, 24),
                      children: [
                        EmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: l10n.t('alerts.empty'),
                          message: l10n.t('alerts.emptySub'),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final n = items[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: n.read ? Palette.paper : const Color(0xFFF2F8F5),
                            borderRadius: BorderRadius.circular(Palette.radiusCard),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(Palette.radiusCard),
                              onTap: n.read
                                  ? null
                                  : () => data.markNotificationRead(n.id),
                              child: Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: n.read ? Palette.line : Palette.indigo,
                                    width: n.read ? 1 : 1.2,
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(Palette.radiusCard),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      _iconFor(n.type),
                                      size: 20,
                                      color: n.read ? Palette.inkSoft : Palette.indigo,
                                    ),
                                    const SizedBox(width: 13),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  n.title,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: n.read
                                                        ? FontWeight.w600
                                                        : FontWeight.w700,
                                                    color: Palette.ink,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                Fmt.ago(n.createdAt),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Palette.inkSoft,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            n.message,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
