import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/local/sync/sync_manager.dart';
import '../../../data/repositories/offline_queue_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';

/// Small, non-blocking sync status chip — mounted once in [AppShell] so
/// every authenticated screen shows the same aggregate state. Merges
/// [SyncManager] (Catalog/Finance outbox) with the existing
/// [OfflineQueueRepository] (POS checkout queue) into one indicator.
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sync = context.watch<SyncManager>();
    final offlineQueue = context.watch<OfflineQueueRepository>();
    final theme = Theme.of(context);

    final pendingCount = sync.pendingCount + offlineQueue.queuedCount;
    final failedCount = sync.failedCount + offlineQueue.failedOrders.length;
    final isOffline = sync.isOffline || offlineQueue.isOffline;
    final syncing = sync.syncing || offlineQueue.draining;

    // Fully synced and online is the normal state during daily operations —
    // stay invisible then (zero footprint, never competes for layout space
    // with a screen's own content) and only take up room when there's
    // something worth surfacing.
    if (failedCount == 0 && !syncing && !isOffline && pendingCount == 0) {
      return const SizedBox.shrink();
    }

    final String label;
    final Color color;
    final IconData icon;

    if (failedCount > 0) {
      label = l10n.syncStatusFailed;
      color = theme.colorScheme.error;
      icon = Icons.error_outline;
    } else if (syncing) {
      label = l10n.syncStatusSyncing;
      color = theme.colorScheme.primary;
      icon = Icons.sync;
    } else if (isOffline) {
      label = pendingCount > 0
          ? l10n.syncStatusPending(pendingCount)
          : l10n.syncStatusOffline;
      color = theme.colorScheme.warning;
      icon = Icons.cloud_off_outlined;
    } else {
      label = l10n.syncStatusPending(pendingCount);
      color = theme.colorScheme.warning;
      icon = Icons.cloud_upload_outlined;
    }

    return Semantics(
      label: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: theme.textTheme.bodySmall!.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small "Menunggu sinkronisasi" dot + label for a not-yet-synced row —
/// Catalog product tiles, Finance entry tiles.
class SyncPendingBadge extends StatelessWidget {
  const SyncPendingBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: theme.colorScheme.warning,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          l10n.syncPendingBadge,
          style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.warning),
        ),
      ],
    );
  }
}
