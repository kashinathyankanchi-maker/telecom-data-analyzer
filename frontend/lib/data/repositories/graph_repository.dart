// lib/data/repositories/graph_repository.dart
import 'package:telecom_analyzer/core/constants.dart';
import 'api_client.dart';

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

  factory GraphNode.fromJson(Map<String, dynamic> json) => GraphNode(
    id: json['id']?.toString() ?? '',
    label: json['label']?.toString() ?? json['id']?.toString() ?? '',
    isSuspect: json['is_suspect'] as bool? ?? false,
    subscriber: json['subscriber'] as Map<String, dynamic>?,
  );
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

  factory GraphEdge.fromJson(Map<String, dynamic> json) => GraphEdge(
    source: json['source']?.toString() ?? '',
    target: json['target']?.toString() ?? '',
    callCount: (json['call_count'] as num?)?.toInt() ?? 0,
    totalDuration: (json['total_duration'] as num?)?.toInt() ?? 0,
  );
}

class GraphData {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  const GraphData({required this.nodes, required this.edges});

  factory GraphData.fromJson(Map<String, dynamic> json) => GraphData(
    nodes: (json['nodes'] as List<dynamic>)
        .map((e) => GraphNode.fromJson(e as Map<String, dynamic>))
        .toList(),
    edges: (json['edges'] as List<dynamic>)
        .map((e) => GraphEdge.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class GraphRepository {
  final _client = ApiClient.instance.dio;

  Future<GraphData> fetchGraph(List<String> suspects, {int depth = 1}) {
    return ApiClient.call(() async {
      final response = await _client.post(
        ApiConstants.graph,
        data: {'suspects': suspects, 'depth': depth},
      );
      return GraphData.fromJson(response.data as Map<String, dynamic>);
    });
  }
}
