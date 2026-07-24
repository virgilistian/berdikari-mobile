/// Per-row sync state for locally-stored, server-mirrored data.
enum SyncRowStatus {
  synced,
  pendingCreate,
  pendingUpdate,
  pendingDelete,
  failed;

  bool get isPending => this == pendingCreate || this == pendingUpdate;

  static SyncRowStatus fromName(String? name) => SyncRowStatus.values
      .firstWhere((s) => s.name == name, orElse: () => SyncRowStatus.synced);
}

/// One write waiting to reach the server — mirrors [PendingOrder]'s role
/// for POS, generalized for any local-first repository (Catalog, Finance, ...).
class OutboxJob {
  OutboxJob({
    required this.localId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.createdAt,
    this.status = 'pending',
    this.lastError,
  });

  final int localId;

  /// e.g. `product`, `category`, `finance_entry`.
  final String entityType;

  /// The local row id this job targets (matches [AppDatabase]'s row key).
  final String entityId;

  /// `create` | `update` | `delete`.
  final String operation;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  /// `pending` (will auto-retry) or `failed` (needs a manual retry/discard —
  /// the server rejected it, retrying unchanged would fail again).
  String status;
  String? lastError;
}
