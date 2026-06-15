// lib/screens/graph/graph_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Feature C: Link Analysis Graph Screen
// Rules:
//   - InteractiveViewer for pinch-to-zoom
//   - Nodes ≥ 48×48 px
//   - Tap node → showModalBottomSheet (NOT navigate)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphview/GraphView.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../data/repositories/graph_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';

// ── State ─────────────────────────────────────────────────────────────────────
class _GraphState {
  final bool isLoading;
  final GraphData? data;
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
    bool? isLoading,
    GraphData? data,
    String? error,
    List<String>? suspects,
    int? depth,
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
  final _repo = GraphRepository();

  void setDepth(int d) => state = state.copyWith(depth: d);

  Future<void> fetchGraph(List<String> suspects) async {
    if (suspects.isEmpty) return;
    state = state.copyWith(isLoading: true, error: null, suspects: suspects);
    try {
      final data = await _repo.fetchGraph(suspects, depth: state.depth);
      state = state.copyWith(isLoading: false, data: data);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final _graphProvider = StateNotifierProvider.autoDispose<_GraphNotifier, _GraphState>(
  (_) => _GraphNotifier(),
);

// ── Screen ────────────────────────────────────────────────────────────────────
class GraphScreen extends ConsumerStatefulWidget {
  const GraphScreen({super.key});

  @override
  ConsumerState<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends ConsumerState<GraphScreen> {
  final _suspectController = TextEditingController();
  final _suspectsList = <String>[];

  @override
  void dispose() {
    _suspectController.dispose();
    super.dispose();
  }

  void _addSuspect() {
    final val = _suspectController.text.trim();
    if (val.isNotEmpty && !_suspectsList.contains(val)) {
      setState(() => _suspectsList.add(val));
      _suspectController.clear();
    }
  }

  void _removeSuspect(String s) => setState(() => _suspectsList.remove(s));

  void _buildGraph() {
    if (_suspectsList.isEmpty) return;
    ref.read(_graphProvider.notifier).fetchGraph(List.from(_suspectsList));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_graphProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Link Analysis'),
        actions: [
          // Depth toggle
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<int>(
              selected: {state.depth},
              onSelectionChanged: (s) => ref.read(_graphProvider.notifier).setDepth(s.first),
              segments: const [
                ButtonSegment(value: 1, label: Text('1 Hop')),
                ButtonSegment(value: 2, label: Text('2 Hops')),
              ],
              style: ButtonStyle(
                textStyle: WidgetStatePropertyAll(AppTextStyles.bodySmall),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Suspect input bar
          _SuspectInputBar(
            controller: _suspectController,
            suspects: _suspectsList,
            onAdd: _addSuspect,
            onRemove: _removeSuspect,
            onBuild: _buildGraph,
          ),
          const Divider(height: 1),

          // Graph area
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppColors.accent),
                  ))
                : state.error != null
                    ? EmptyState(
                        icon: Icons.error_outline,
                        title: 'Graph Error',
                        subtitle: state.error,
                        action: ElevatedButton(onPressed: _buildGraph, child: const Text('Retry')),
                      )
                    : state.data == null
                        ? const EmptyState(
                            icon: Icons.hub_outlined,
                            title: 'Build a Contact Graph',
                            subtitle: 'Enter one or more suspect numbers above and tap "Build Graph"',
                          )
                        : _GraphView(data: state.data!),
          ),
        ],
      ),
    );
  }
}

// ── Suspect Input Bar ─────────────────────────────────────────────────────────
class _SuspectInputBar extends StatelessWidget {
  const _SuspectInputBar({
    required this.controller,
    required this.suspects,
    required this.onAdd,
    required this.onRemove,
    required this.onBuild,
  });

  final TextEditingController controller;
  final List<String> suspects;
  final VoidCallback onAdd;
  final void Function(String) onRemove;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgSurface,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onSubmitted: (_) => onAdd(),
                  decoration: const InputDecoration(
                    hintText: 'Add suspect number…',
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
                label: const Text('Build'),
              ),
            ],
          ),
          if (suspects.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
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
}

// ── Graph View ────────────────────────────────────────────────────────────────
class _GraphView extends StatefulWidget {
  const _GraphView({required this.data});
  final GraphData data;

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
        _graph.addEdge(src, tgt, paint: Paint()
          ..color = AppColors.bgBorder
          ..strokeWidth = 1.5);
      }
    }

    _algorithm = FruchtermanReingoldAlgorithm(
      iterations: 1000,
      repulsionRate: 0.5,
      attractionRate: 0.01,
      maxDelta: 100,
    );
  }

  GraphNode? _nodeDataFor(String id) {
    try {
      return widget.data.nodes.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(100),
      minScale: 0.3,
      maxScale: 3.0,
      child: GraphView(
        graph: _graph,
        algorithm: _algorithm,
        paint: Paint()
          ..color = AppColors.bgBorder
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
        builder: (node) {
          final id = node.key?.value as String? ?? '';
          final data = _nodeDataFor(id);
          return _GraphNodeWidget(
            nodeId: id,
            data: data,
            onTap: () => _showNodeDetails(context, data),
          );
        },
      ),
    );
  }

  void _showNodeDetails(BuildContext context, GraphNode? data) {
    if (data == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NodeDetailSheet(node: data),
    );
  }
}

// ── Graph Node Widget (≥ 48×48 px) ───────────────────────────────────────────
class _GraphNodeWidget extends StatelessWidget {
  const _GraphNodeWidget({required this.nodeId, required this.data, required this.onTap});
  final String nodeId;
  final GraphNode? data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSuspect = data?.isSuspect ?? false;
    final hasSubscriber = data?.subscriber != null;
    final color = isSuspect
        ? AppColors.nodeSuspect
        : hasSubscriber ? AppColors.nodeContact : AppColors.nodeUnknown;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Node circle — minimum 48×48
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: isSuspect ? 2.5 : 1.5),
              boxShadow: isSuspect
                  ? [BoxShadow(color: color.withOpacity(0.35), blurRadius: 12, spreadRadius: 2)]
                  : null,
            ),
            child: Icon(
              isSuspect ? Icons.gpp_bad : (hasSubscriber ? Icons.person : Icons.help_outline),
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 80),
            child: Text(
              data?.label ?? nodeId,
              style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Node Detail Bottom Sheet ──────────────────────────────────────────────────
class _NodeDetailSheet extends StatelessWidget {
  const _NodeDetailSheet({required this.node});
  final GraphNode node;

  @override
  Widget build(BuildContext context) {
    final sub = node.subscriber;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: (node.isSuspect ? AppColors.nodeSuspect : AppColors.nodeContact).withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: node.isSuspect ? AppColors.nodeSuspect : AppColors.nodeContact),
                  ),
                  child: Icon(
                    node.isSuspect ? Icons.gpp_bad : Icons.person,
                    color: node.isSuspect ? AppColors.nodeSuspect : AppColors.nodeContact,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(node.label, style: AppTextStyles.titleLarge),
                      Text(node.id, style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent)),
                    ],
                  ),
                ),
                if (node.isSuspect)
                  Chip(
                    label: const Text('SUSPECT'),
                    backgroundColor: AppColors.nodeSuspect.withOpacity(0.12),
                    side: const BorderSide(color: AppColors.nodeSuspect),
                    labelStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.nodeSuspect, fontWeight: FontWeight.w700),
                  ),
              ],
            ),
            if (sub != null) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              _DetailRow(icon: Icons.person_outline, label: 'Subscriber Name', value: sub['subscriber_name'] ?? 'N/A'),
              _DetailRow(icon: Icons.home_outlined, label: 'Address', value: sub['address'] ?? 'N/A'),
              _DetailRow(icon: Icons.calendar_today_outlined, label: 'Activation Date', value: sub['activation_date'] ?? 'N/A'),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.bodySmall),
              Text(value, style: AppTextStyles.labelLarge),
            ],
          ),
        ),
      ],
    ),
  );
}
