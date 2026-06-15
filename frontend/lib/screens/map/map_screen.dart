// lib/screens/map/map_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Feature D: Geo-Mapping Screen
// Rules:
//   - Full-bleed map (no AppBar overlap)
//   - Map controls in FABs
//   - Tower marker tap → showModalBottomSheet (NOT navigate)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme.dart';
import '../../data/models/tdr_model.dart';
import '../../data/repositories/geo_repository.dart';
import '../../widgets/empty_state.dart';

// ── State ─────────────────────────────────────────────────────────────────────
class _MapState {
  final bool isLoading;
  final GeoMapData? data;
  final String? error;
  final String? phone;
  final bool showTimeline;

  const _MapState({
    this.isLoading = false,
    this.data,
    this.error,
    this.phone,
    this.showTimeline = false,
  });

  _MapState copyWith({
    bool? isLoading,
    GeoMapData? data,
    String? error,
    String? phone,
    bool? showTimeline,
  }) => _MapState(
    isLoading: isLoading ?? this.isLoading,
    data: data ?? this.data,
    error: error ?? this.error,
    phone: phone ?? this.phone,
    showTimeline: showTimeline ?? this.showTimeline,
  );
}

class _MapNotifier extends StateNotifier<_MapState> {
  _MapNotifier() : super(const _MapState());
  final _repo = GeoRepository();

  void toggleTimeline() => state = state.copyWith(showTimeline: !state.showTimeline);

  Future<void> loadMap(String phone) async {
    if (phone.trim().isEmpty) return;
    state = state.copyWith(isLoading: true, error: null, phone: phone.trim());
    try {
      final data = await _repo.fetchTowerMap(phone.trim());
      state = state.copyWith(isLoading: false, data: data);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final _mapProvider = StateNotifierProvider.autoDispose<_MapNotifier, _MapState>(
  (_) => _MapNotifier(),
);

// ── Screen ────────────────────────────────────────────────────────────────────
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _search() {
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty) ref.read(_mapProvider.notifier).loadMap(phone);
  }

  LatLng _computeCenter(List<TdrModel> towers) {
    if (towers.isEmpty) return const LatLng(20.5937, 78.9629); // India center
    final avgLat = towers.map((t) => t.latitude).reduce((a, b) => a + b) / towers.length;
    final avgLon = towers.map((t) => t.longitude).reduce((a, b) => a + b) / towers.length;
    return LatLng(avgLat, avgLon);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_mapProvider);
    final towers = state.data?.towers ?? [];
    final timeline = state.data?.timeline ?? [];
    final center = _computeCenter(towers);

    return Scaffold(
      // NO appBar — full-bleed map
      body: Stack(
        children: [
          // ── Full-bleed Map ─────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: towers.isEmpty ? 5.0 : 12.0,
            ),
            children: [
              // Base tile layer (OpenStreetMap — no API key needed)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.telecom.analyzer',
              ),

              // Chronological path polyline
              if (towers.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: towers.map((t) => t.latLng).toList(),
                      color: AppColors.accent.withOpacity(0.7),
                      strokeWidth: 2.5,
                      isDotted: false,
                    ),
                  ],
                ),

              // Tower markers
              MarkerLayer(
                markers: towers.asMap().entries.map((entry) {
                  final i = entry.key;
                  final tower = entry.value;
                  return Marker(
                    point: tower.latLng,
                    width: 52,
                    height: 52,
                    child: GestureDetector(
                      onTap: () => _showTowerSheet(context, tower, i + 1),
                      child: _TowerMarker(
                        index: i + 1,
                        callCount: tower.callCount,
                        isFirst: i == 0,
                        isLast: i == towers.length - 1,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // ── Loading indicator ──────────────────────────────────────────────
          if (state.isLoading)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.accent),
              )),
            ),

          // ── Empty/error state (when no data) ───────────────────────────────
          if (!state.isLoading && state.data == null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.bgBorder),
                  ),
                  child: Text(
                    state.error ?? 'Enter a phone number to map tower connections',
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

          // ── Top search bar (overlaid on map) ───────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.bgSurface.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.bgBorder),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone, color: AppColors.accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      onSubmitted: (_) => _search(),
                      decoration: const InputDecoration(
                        hintText: 'Phone number…',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, color: AppColors.accent),
                    onPressed: _search,
                  ),
                ],
              ),
            ),
          ),

          // ── Stats chip ─────────────────────────────────────────────────────
          if (towers.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.bgBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cell_tower, size: 16, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Text('${towers.length} towers', style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent)),
                    const SizedBox(width: 12),
                    const Icon(Icons.call, size: 16, color: AppColors.secondary),
                    const SizedBox(width: 6),
                    Text('${timeline.length} calls', style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondary)),
                  ],
                ),
              ),
            ),

          // ── Timeline panel (DraggableScrollableSheet) ──────────────────────
          if (state.showTimeline && timeline.isNotEmpty)
            DraggableScrollableSheet(
              initialChildSize: 0.35,
              minChildSize: 0.15,
              maxChildSize: 0.7,
              builder: (ctx, scrollController) => Container(
                decoration: const BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(top: BorderSide(color: AppColors.bgBorder)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.bgBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.timeline, size: 18, color: AppColors.accent),
                          const SizedBox(width: 8),
                          Text('Call Timeline', style: AppTextStyles.titleLarge),
                          const Spacer(),
                          Text('${timeline.length} events', style: AppTextStyles.bodySmall),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: timeline.length,
                        itemBuilder: (_, i) => _TimelineRow(event: timeline[i]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),

      // ── FAB Controls ──────────────────────────────────────────────────────
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zoom in
          FloatingActionButton.small(
            heroTag: 'zoom_in',
            onPressed: () => _mapController.move(
              _mapController.camera.center,
              _mapController.camera.zoom + 1,
            ),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          // Zoom out
          FloatingActionButton.small(
            heroTag: 'zoom_out',
            onPressed: () => _mapController.move(
              _mapController.camera.center,
              _mapController.camera.zoom - 1,
            ),
            child: const Icon(Icons.remove),
          ),
          const SizedBox(height: 8),
          // Center / fit all markers
          FloatingActionButton.small(
            heroTag: 'center',
            onPressed: () {
              if (towers.isNotEmpty) _mapController.move(center, 12.0);
            },
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 8),
          // Toggle timeline panel
          FloatingActionButton(
            heroTag: 'timeline',
            onPressed: ref.read(_mapProvider.notifier).toggleTimeline,
            backgroundColor: state.showTimeline ? AppColors.accent : AppColors.bgElevated,
            foregroundColor: state.showTimeline ? AppColors.bgBase : AppColors.accent,
            child: const Icon(Icons.timeline),
          ),
        ],
      ),
    );
  }

  void _showTowerSheet(BuildContext context, TdrModel tower, int index) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _TowerDetailSheet(tower: tower, index: index),
    );
  }
}

// ── Tower Marker ──────────────────────────────────────────────────────────────
class _TowerMarker extends StatelessWidget {
  const _TowerMarker({
    required this.index,
    required this.callCount,
    required this.isFirst,
    required this.isLast,
  });

  final int index;
  final int callCount;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = isFirst ? AppColors.success : (isLast ? AppColors.error : AppColors.accent);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
            boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)],
          ),
          child: Center(
            child: Text(
              '$index',
              style: AppTextStyles.labelLarge.copyWith(color: color, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tower Detail Bottom Sheet ─────────────────────────────────────────────────
class _TowerDetailSheet extends StatelessWidget {
  const _TowerDetailSheet({required this.tower, required this.index});
  final TdrModel tower;
  final int index;

  @override
  Widget build(BuildContext context) {
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentGlow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.cell_tower, color: AppColors.accent, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tower #$index', style: AppTextStyles.bodySmall),
                      Text(tower.cellId, style: AppTextStyles.titleLarge),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            _TowerDetailRow(icon: Icons.location_on_outlined, label: 'Coordinates',
              value: '${tower.latitude.toStringAsFixed(6)}, ${tower.longitude.toStringAsFixed(6)}'),
            if (tower.azimuth != null)
              _TowerDetailRow(icon: Icons.explore_outlined, label: 'Azimuth', value: '${tower.azimuth}°'),
            _TowerDetailRow(icon: Icons.call, label: 'Call Count', value: '${tower.callCount}'),
            if (tower.formattedFirstContact != null)
              _TowerDetailRow(icon: Icons.access_time, label: 'First Contact', value: tower.formattedFirstContact!),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _TowerDetailRow extends StatelessWidget {
  const _TowerDetailRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.bodySmall),
            Text(value, style: AppTextStyles.labelLarge),
          ],
        )),
      ],
    ),
  );
}

// ── Timeline Row ──────────────────────────────────────────────────────────────
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event});
  final TowerTimelineEvent event;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.bgBorder)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.accentGlow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.cell_tower, size: 14, color: AppColors.accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${event.callerNumber} → ${event.receiverNumber}',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${event.formattedTime}  ·  Tower: ${event.cellId}',
                style: AppTextStyles.bodySmall),
            ],
          ),
        ),
        if (event.durationSeconds != null)
          Text(
            '${event.durationSeconds}s',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent),
          ),
      ],
    ),
  );
}
