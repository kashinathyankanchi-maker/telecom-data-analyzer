// lib/data/repositories/graph_repository.dart
// This file is kept for model definitions only.
// All graph queries now go through lib/screens/graph/graph_screen.dart
// which reads directly from the local SQLite database.

class GraphNode {
  final String id;
  final String label;
  final bool isSuspect;
  final Map<String, dynamic>? subscriber;

  const GraphNode({
    required this.id,
    required this.label,
    required this.isSuspect,
    this.subscriber,
  });
}

class GraphEdge {
  final String source;
  final String target;
  final int callCount;
  final int totalDuration;

  const GraphEdge({
    required this.source,
    required this.target,
    required this.callCount,
    required this.totalDuration,
  });
}
