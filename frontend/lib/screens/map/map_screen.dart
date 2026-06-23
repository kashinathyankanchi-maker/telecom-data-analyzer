// lib/screens/map/map_screen.dart
// Geo Map — shows GPS-tagged CDR records and TDR tower data from local database.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme.dart';
import '../../data/models/cdr_model.dart';
import '../../data/models/tdr_model.dart';
import '../../providers/data_store.dart';

// ── Screen ─────────────────────────────────────────────────────────────────────
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController  = MapController();
  final _filterCtrl     = TextEditingController();
  String _phoneFilter   = '';
  bool   _showCdrPoints = true;
  bool   _showTowers    = true;

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  List<CdrModel> _filteredCdr(List<CdrModel> all) {
    if (_phoneFilter.isEmpty) return all;
    return all.where((c) =>
      c.callerNumber.contains(_phoneFilter) || c.receiverNumber.contains(_phoneFilter)
    ).toList();
  }

  LatLng _computeCenter(List<CdrModel> cdrPoints, List<TdrModel> towers) {
    final points = <LatLng>[
      ...cdrPoints.where((c) => c.hasGps).map((c) => c.latLng!),
      ...towers.map((t) => t.latLng),
    ];
    if (points.isEmpty) return const LatLng(20.5937, 78.9629); // India
    final avgLat = points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final avgLon = points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
    return LatLng(avgLat, avgLon);
  }

  @override
  Widget build(BuildContext context) {
    final gpsCallsAsync = ref.watch(gpsCallsProvider);
    final towersAsync   = ref.watch(allTowersProvider);

    return gpsCallsAsync.when(
      error: (e, _) => Center(child: Text('Error: $e')),
      loading: () => const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.accent))),
      data: (allCdr) => towersAsync.when(
        error: (e, _) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.accent))),
        data: (towers) {
          final cdrPoints = _filteredCdr(allCdr);
          final center    = _computeCenter(cdrPoints, towers);
          final hasData   = cdrPoints.isNotEmpty || towers.isNotEmpty;
          final zoom      = hasData ? 12.0 : 5.0;

          return Scaffold(
            body: Stack(children: [
              // Full-bleed map
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(initialCenter: center, initialZoom: zoom),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.telecom.analyzer',
                  ),

                  // Polyline connecting CDR GPS points in time order
                  if (_showCdrPoints && cdrPoints.length > 1)
                    PolylineLayer(polylines: [
                      Polyline(
                        points: cdrPoints.where((c) => c.hasGps).map((c) => c.latLng!).toList(),
                        color: AppColors.accent.withOpacity(0.5),
                        strokeWidth: 2,
                      ),
                    ]),

                  // TDR tower markers
                  if (_showTowers)
                    MarkerLayer(
                      markers: towers.map((t) => Marker(
                        point: t.latLng,
                        width: 48, height: 48,
                        child: GestureDetector(
                          onTap: () => _showTowerSheet(t),
                          child: _TowerMarker(cellId: t.cellId),
                        ),
                      )).toList(),
                    ),

                  // CDR GPS event markers
                  if (_showCdrPoints)
                    MarkerLayer(
                      markers: cdrPoints.where((c) => c.hasGps).toList().asMap().entries.map((entry) {
                        final i = entry.key;
                        final c = entry.value;
                        return Marker(
                          point: c.latLng!,
                          width: 36, height: 36,
                          child: GestureDetector(
                            onTap: () => _showCdrSheet(c, i + 1),
                            child: _CdrMarker(index: i + 1, isOutgoing: c.isOutgoing),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),

              // Empty state
              if (!hasData)
                Center(
                  child: Container(
                    margin: const EdgeInsets.all(32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.bgBorder),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.map_outlined, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text('No GPS Data', style: AppTextStyles.titleLarge),
                      const SizedBox(height: 8),
                      Text(
                        'Import CDR files with latitude/longitude columns\nor TDR files with tower coordinates to see them here.',
                        style: AppTextStyles.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ]),
                  ),
                ),

              // Top controls bar
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 16, right: 16,
                child: Column(children: [
                  // Search filter
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.bgBorder),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(children: [
                      const Icon(Icons.phone, color: AppColors.accent, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _filterCtrl,
                          onChanged: (v) => setState(() => _phoneFilter = v.trim()),
                          onSubmitted: (v) => setState(() => _phoneFilter = v.trim()),
                          decoration: const InputDecoration(
                            hintText: 'Filter by phone number (optional)…',
                            border: InputBorder.none, enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none, filled: false,
                            isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      if (_phoneFilter.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: AppColors.textMuted),
                          onPressed: () { _filterCtrl.clear(); setState(() => _phoneFilter = ''); },
                        ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  // Layer toggles
                  Row(children: [
                    _LayerChip(
                      label: 'CDR Points (${cdrPoints.length})',
                      active: _showCdrPoints,
                      icon: Icons.call,
                      color: AppColors.accent,
                      onTap: () => setState(() => _showCdrPoints = !_showCdrPoints),
                    ),
                    const SizedBox(width: 8),
                    _LayerChip(
                      label: 'Towers (${towers.length})',
                      active: _showTowers,
                      icon: Icons.cell_tower,
                      color: AppColors.secondary,
                      onTap: () => setState(() => _showTowers = !_showTowers),
                    ),
                  ]),
                ]),
              ),
            ]),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            floatingActionButton: Column(mainAxisSize: MainAxisSize.min, children: [
              FloatingActionButton.small(
                heroTag: 'zoom_in',
                onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1),
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'zoom_out',
                onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1),
                child: const Icon(Icons.remove),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'center',
                onPressed: () { if (hasData) _mapController.move(center, 12.0); },
                child: const Icon(Icons.my_location),
              ),
            ]),
          );
        },
      ),
    );
  }

  void _showTowerSheet(TdrModel tower) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.accentGlow, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.cell_tower, color: AppColors.accent, size: 24),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Cell Tower', style: AppTextStyles.bodySmall),
                Text(tower.cellId, style: AppTextStyles.titleLarge),
              ]),
            ]),
            const Divider(height: 24),
            _DetailRow(Icons.location_on_outlined, 'Coordinates',
              '${tower.latitude.toStringAsFixed(6)}, ${tower.longitude.toStringAsFixed(6)}'),
            if (tower.azimuth != null)
              _DetailRow(Icons.explore_outlined, 'Azimuth', '${tower.azimuth}°'),
          ]),
        ),
      ),
    );
  }

  void _showCdrSheet(CdrModel cdr, int index) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(cdr.isOutgoing ? Icons.call_made : Icons.call_received,
                color: cdr.isOutgoing ? AppColors.accent : AppColors.success, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Call Event #$index', style: AppTextStyles.bodySmall),
                Text(cdr.isOutgoing ? cdr.receiverNumber : cdr.callerNumber, style: AppTextStyles.titleLarge),
              ])),
            ]),
            const Divider(height: 24),
            _DetailRow(Icons.access_time, 'Time', cdr.formattedTime),
            _DetailRow(Icons.timer_outlined, 'Duration', cdr.formattedDuration),
            _DetailRow(Icons.location_on_outlined, 'GPS',
              '${cdr.latitude?.toStringAsFixed(6)}, ${cdr.longitude?.toStringAsFixed(6)}'),
            if (cdr.cellId != null)
              _DetailRow(Icons.cell_tower, 'Cell ID', cdr.cellId!),
          ]),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Icon(icon, size: 18, color: AppColors.textMuted),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTextStyles.bodySmall),
        Text(value, style: AppTextStyles.labelLarge),
      ]),
    ]),
  );
}

// ── Markers ────────────────────────────────────────────────────────────────────
class _TowerMarker extends StatelessWidget {
  const _TowerMarker({required this.cellId});
  final String cellId;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.secondary, width: 2),
        boxShadow: [BoxShadow(color: AppColors.secondary.withOpacity(0.4), blurRadius: 8)],
      ),
      child: const Icon(Icons.cell_tower, color: AppColors.secondary, size: 18),
    ),
  ]);
}

class _CdrMarker extends StatelessWidget {
  const _CdrMarker({required this.index, required this.isOutgoing});
  final int index;
  final bool isOutgoing;

  @override
  Widget build(BuildContext context) {
    final color = isOutgoing ? AppColors.accent : AppColors.success;
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: color.withOpacity(0.85),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)],
      ),
      child: Center(
        child: Text('$index', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _LayerChip extends StatelessWidget {
  const _LayerChip({required this.label, required this.active, required this.icon, required this.color, required this.onTap});
  final String label;
  final bool active;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.15) : AppColors.bgSurface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? color : AppColors.bgBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: active ? color : AppColors.textMuted),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: active ? color : AppColors.textMuted)),
      ]),
    ),
  );
}
