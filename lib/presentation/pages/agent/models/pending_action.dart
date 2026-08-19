/// A destructive operation the agent has proposed but not performed.
///
/// The agent never deletes directly; it returns one of these so the user can
/// confirm in the chat first. Deleting an activity cascades to all of its
/// records and cannot be undone.
class PendingAction {
  const PendingAction({
    required this.kind,
    required this.description,
    required this.targetId,
    this.targetName,
    this.recordCount,
  });

  final PendingActionKind kind;

  /// Human-readable summary shown on the confirmation card.
  final String description;

  final int targetId;
  final String? targetName;

  /// For activity deletion: how many records would be removed with it.
  final int? recordCount;
}

enum PendingActionKind { deleteActivity, deleteRecord }
