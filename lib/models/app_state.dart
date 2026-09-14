import 'package:elmasa/models/workspace.dart';

class AppState {
  final List<Workspace> workspaces;
  final String? activeWorkspaceId;

  AppState({
    required this.workspaces,
    this.activeWorkspaceId,
  });

  Map<String, dynamic> toJson() => {
    'workspaces': workspaces.map((w) => w.toJson()).toList(),
    'activeWorkspaceId': activeWorkspaceId,
  };

  factory AppState.fromJson(Map<String, dynamic> json) => AppState(
    workspaces: (json['workspaces'] as List?)?.map((w) => Workspace.fromJson(w)).toList() ?? [],
    activeWorkspaceId: json['activeWorkspaceId'],
  );
}
