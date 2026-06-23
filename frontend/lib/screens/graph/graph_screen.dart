// lib/screens/graph/graph_screen.dart
// Link Analysis: builds contact graphs from locally stored CDR data.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphview/GraphView.dart';
import '../../core/theme.dart';
import '../../core/database.dart';
import '../../widgets/empty_state.dart';

// ── Local graph builder ────────────────────────────────────────────────────────
class _GraphNodeData {
  final String id;
  final bool isSuspect;
  final int callCount;

  const _GraphNodeData({required this.id, required this.isSuspect, required this.callCount});
}

class _GraphData {
  final List<_GraphNodeData> nodes;
  final List<({String source, String target, int count})> edges;

  const _GraphData({required this.nodes, required this.edges});
}

// ── State ──────────────────────────────────────────────────────────────────────
class _GraphState {
  final bool isLoading;
  final _GraphData? data;
  final String? error;
  final List<String> suspects;
  final int depth;

  const _GraphState({
    this.isLoading = false,
    this.data,
    this.error,
    this.suspects = const [],
    this.depth = 1,
  });

  _GraphState copyWith({
    bool? isLoading, _GraphData? data, String? error,
    List<String>? suspects, int? depth,
  }) => _GraphState(
    isLoading: isLoading ?? this.isLoading,
    data: data ?? this.data,
    error: error ?? this.error,
    suspects: suspects ?? this.suspects,
    depth: depth ?? this.depth,
  );
}

class _GraphNotifier extends StateNotifier<_GraphState> {
  _GraphNotifier() : super(const _GraphState());

  void setDepth(int d) => state = state.copyWith(depth: d);

  Future<void> buildGraph(List<String> suspects) async {
    if (suspects.isEmpty) return;
    state = state.copyWith(isLoading: true, error: null, suspects: suspects);
    try {
      final nodeMap = <String, _GraphNodeData>{};
      final edgeMap = <String, Map<String, int>>{};

      // Add suspect nodes
      for (final s in suspects) {
        nodeMap[s] = _GraphNodeData(id: s, isSuspect: true, callCount: 0);
      }

      // Query CDR for each suspect
      for (final suspect in suspects) {
        final rows = await AppDatabase.instance.queryCdrByPhone(suspect);
        for (final row in rows) {
          final caller   = row['caller_number'] as String;
          final receiver = row['receiver_number'] as String;
          final contact  = (caller == suspect) ? receiver : caller;

          // Add contact node if not a suspect
          if (!nodeMap.containsKey(contact)) {
            nodeMap[contact] = _GraphNodeData(id: contact, isSuspect: false, callCount: 0);
          }

          // Count edge
          edgeMap[suspect] ??= {};
          edgeMap[suspect]![contact] = (edgeMap[suspect]![contact] ?? 0) + 1;
        }

        // Depth 2: also query each contact's connections
        if (state.depth == 2) {
          final contacts = edgeMap[suspect]?.keys.toList() ?? [];
          for (final contact in contacts) {
            if (suspects.contains(contact)) continue;
            final contactRows = await AppDatabase.instance.queryCdrByPhone(contact);
            for (final row in contactRows) {
              final c2 = (row['caller_number'] as String) == contact
                  ? row['receiver_number'] as String
                  : row['caller_number'] as String;
              if (!nodeMap.containsKey(c2)) {
                nodeMap[c2] = _GraphNodeData(id: c2, isSuspect: false, callCount: 0);
              }
              edgeMap[contact] ??= {};
              edgeMap[contact]![c2] = (edgeMap[contact]![c2] ?? 0) + 1;
            }
          }
        }
      }

      final edges = <({String source, String target, int count})>[];
      for (final src in edgeMap.entries) {
        for (final tgt in src.value.entries) {
          edges.add((source: src.key, target: tgt.key, count: tgt.value));
        }
      }

      state = state.copyWith(
        isLoading: false,
        data: _GraphData(nodes: nodeMap.values.toList(), edges: edges),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final _graphProvider = StateNotifierProvider.autoDispose<_GraphNotifier, _GraphState>(
  (_) => _GraphNotifier(),
);

// ── Screen ─────────────────────────────────────────────────────────────────────
class GraphScreen extends ConsumerStatefulWidget {
  const GraphScreen({super.key});

  @override
  ConsumerState<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends ConsumerState<GraphScreen> {
  final _ctrl = TextEditingController();
  final _suspects = <String>[];

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _add() {
    final v = _ctrl.text.trim();
    if (v.isNotEmpty && !_suspects.contains(v)) {
      setState(() => _suspects.add(v));
      _ctrl.clear();
    }
  }

  void _remove(String s) => setState(() => _suspects.remove(s));

  void _build() {
    if (_suspects.isEmpty) return;
    ref.read(_graphProvider.notifier).buildGraph(List.from(_suspects));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_graphProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Link Analysis'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<int>(
              selected: {state.depth},
              onSelectionChanged: (s) => ref.read(_graphProvider.notifier).setDepth(s.first),
              segments: const [
                ButtonSegment(value: 1, label: Text('1 Hop')),
                ButtonSegment(value: 2, label: Text('2 Hops')),
              ],
            ),
          ),
        ],
      ),
      body: Column(children: [
        _SuspectBar(
          controller: _ctrl,
          suspects: _suspects,
          onAdd: _add, onRemove: _remove, onBuild: _build,
        ),
        const Divider(height: 1),
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.accent)))
              : state.error != null
                  ? EmptyState(
                      icon: Icons.error_outline, title: 'Graph Error', subtitle: state.error,
                      action: ElevatedButton(onPressed: _build, child: const Text('Retry')),
                    )
                  : state.data == null
                      ? const EmptyState(
                          icon: Icons.hub_outlined,
                          title: 'Build a Contact Graph',
                          subtitle: 'Enter one or more phone numbers and tap "Build"\nData is loaded from imported CDR files',
                        )
                      : _GraphView(data: state.data!),
        ),
      ]),
    );
  }
}

class _SuspectBar extends StatelessWidget {
  const _SuspectBar({
    required this.controller, required this.suspects,
    required this.onAdd, required this.onRemove, required this.onBuild,
  });
  final TextEditingController controller;
  final List<String> suspects;
  final VoidCallback onAdd, onBuild;
  final void Function(String) onRemove;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.bgSurface,
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onAdd(),
              decoration: const InputDecoration(
                hintText: 'Add phone number to analyse…',
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            style: IconButton.styleFrom(backgroundColor: AppColors.accentGlow, foregroundColor: AppColors.accent),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: suspects.isNotEmpty ? onBuild : null,
            icon: const Icon(Icons.hub, size: 16),
            label: const Text('Build Graph'),
          ),
        ]),
        if (suspects.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 4,
            children: suspects.map((s) => Chip(
              label: Text(s, style: AppTextStyles.bodySmall),
              avatar: const Icon(Icons.gpp_bad, size: 14, color: AppColors.nodeSuspect),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () => onRemove(s),
              backgroundColor: AppColors.nodeSuspect.withOpacity(0.08),
              side: const BorderSide(color: AppColors.nodeSuspect, width: 0.5),
            )).toList(),
          ),
        ],
      ],
    ),
  );
}

// ── Graph View ─────────────────────────────────────────────────────────────────
class _GraphView extends StatefulWidget {
  const _GraphView({required this.data});
  final _GraphData data;

  @override
  State<_GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends State<_GraphView> {
  late final Graph _graph;
  late final Algorithm _algorithm;
  final Map<String, Node> _nodeMap = {};

  @override
  void initState() {
    super.initState();
    _buildGraph();
  }

  void _buildGraph() {
    _graph = Graph()..isTree = false;
    _nodeMap.clear();
    for (final n in widget.data.nodes) {
      final node = Node.Id(n.id);
      _nodeMap[n.id] = node;
      _graph.addNode(node);
    }
    for (final e in widget.data.edges) {
      final src = _nodeMap[e.source];
      final tgt = _nodeMap[e.target];
      if (src != null && tgt != null) {
        _graph.addEdge(src, tgt, paint: Paint()..color = AppColors.bgBorder..strokeWidth = 1.5);
      }
    }
    _algorithm = FruchtermanReingoldAlgorithm(
      FruchtermanReingoldConfiguration(
        iterations: 1000, repulsionRate: 0.5, attractionRate: 0.01,
        repulsionPercentage: 0.4, attractionPercentage: 0.15,
        clusterPadding: 15, epsilon: 0.0001, lerpFactor: 0.05, movementThreshold: 0.6,
      ),
    );
  }

  _GraphNodeData? _nodeDataFor(String id) {
    try { return widget.data.nodes.firstWhere((n) => n.id == id); } catch (_) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(100),
      minScale: 0.3, maxScale: 3.0,
      child: GraphView(
        graph: _graph,
        algorithm: _algorithm,
        paint: Paint()..color = AppColors.bgBorder..strokeWidth = 1.5..style = PaintingStyle.stroke,
        builder: (node) {
          final id   = node.key?.value as String? ?? '';
          final data = _nodeDataFor(id);
          final isSuspect = data?.isSuspect ?? false;
          final color = isSuspect ? AppColors.nodeSuspect : AppColors.nodeContact;
          return GestureDetector(
            onTap: () => _showDetails(id, data),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: isSuspect ? 2.5 : 1.5),
                  boxShadow: isSuspect
                      ? [BoxShadow(color: color.withOpacity(0.35), blurRadius: 12, spreadRadius: 2)]
                      : null,
                ),
                child: Icon(
                  isSuspect ? Icons.gpp_bad : Icons.person,
                  color: color, size: 24,
                ),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 80),
                child: Text(
                  id, style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
                  textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  void _showDetails(String id, _GraphNodeData? data) {
    final edges = widget.data.edges.where((e) => e.source == id || e.target == id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(
                data?.isSuspect == true ? Icons.gpp_bad : Icons.person,
                color: data?.isSuspect == true ? AppColors.nodeSuspect : AppColors.nodeContact,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(id, style: AppTextStyles.titleLarge)),
              if (data?.isSuspect == true)
                Chip(
                  label: const Text('SUSPECT'),
                  backgroundColor: AppColors.nodeSuspect.withOpacity(0.12),
                  side: const BorderSide(color: AppColors.nodeSuspect),
                  labelStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.nodeSuspect, fontWeight: FontWeight.w700),
                ),
            ]),
            const Divider(height: 24),
            Text('Connections', style: AppTextStyles.labelLarge),
            const SizedBox(height: 8),
            ...edges.map((e) {
              final other = e.source == id ? e.target : e.source;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  const Icon(Icons.compare_arrows, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(child: Text(other, style: AppTextStyles.bodyMedium)),
                  Text('${e.count} calls', style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent)),
                ]),
              );
            }),
          ]),
        ),
      ),
    );
  }
}
