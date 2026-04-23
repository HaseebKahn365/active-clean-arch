import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DashboardViewMode { list, tree }

class DashboardUiState {
  final DashboardViewMode viewMode;
  final Set<String> expandedNodeIds;
  final String? selectedNodeId;
  final String? reparentingNodeId;

  DashboardUiState({
    this.viewMode = DashboardViewMode.list,
    this.expandedNodeIds = const {},
    this.selectedNodeId,
    this.reparentingNodeId,
  });

  DashboardUiState copyWith({
    DashboardViewMode? viewMode,
    Set<String>? expandedNodeIds,
    String? selectedNodeId,
    String? reparentingNodeId,
  }) {
    return DashboardUiState(
      viewMode: viewMode ?? this.viewMode,
      expandedNodeIds: expandedNodeIds ?? this.expandedNodeIds,
      selectedNodeId: selectedNodeId ?? this.selectedNodeId,
      reparentingNodeId: reparentingNodeId, // Allow nulling
    );
  }

  DashboardUiState resetReparenting() {
    return DashboardUiState(
      viewMode: viewMode,
      expandedNodeIds: expandedNodeIds,
      selectedNodeId: selectedNodeId,
    );
  }
}

class DashboardUiNotifier extends Notifier<DashboardUiState> {
  @override
  DashboardUiState build() {
    return DashboardUiState();
  }

  void setViewMode(DashboardViewMode mode) {
    state = state.copyWith(viewMode: mode);
  }

  void toggleNodeExpansion(String id) {
    final next = Set<String>.from(state.expandedNodeIds);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = state.copyWith(expandedNodeIds: next);
  }

  void selectNode(String? id) {
    state = state.copyWith(selectedNodeId: id);
  }

  void startReparenting(String id) {
    state = state.copyWith(reparentingNodeId: id);
  }

  void stopReparenting() {
    state = state.resetReparenting();
  }

  void setExpandedNodes(Set<String> ids) {
    state = state.copyWith(expandedNodeIds: ids);
  }
}

final dashboardUiProvider = NotifierProvider<DashboardUiNotifier, DashboardUiState>(DashboardUiNotifier.new);
