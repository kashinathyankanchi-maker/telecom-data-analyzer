// lib/providers/data_store.dart
// Global Riverpod providers that expose the SQLite data to all screens.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database.dart';
import '../data/models/cdr_model.dart';
import '../data/models/sdr_model.dart';
import '../data/models/tdr_model.dart';

// ── DB counts refresher ──────────────────────────────────────────────────────

final dbCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  return AppDatabase.instance.getTableCounts();
});

// ── CDR search result ────────────────────────────────────────────────────────

class PhoneSearchResult {
  final SdrModel? subscriber;
  final List<CdrModel> callLog;

  const PhoneSearchResult({this.subscriber, required this.callLog});

  bool get isEmpty => callLog.isEmpty;
}

final phoneSearchProvider = FutureProvider.family<PhoneSearchResult, String>((ref, phone) async {
  final cdrRows = await AppDatabase.instance.queryCdrByPhone(phone);
  final sdrRow  = await AppDatabase.instance.querySdrByPhone(phone);

  final callLog = cdrRows.map(CdrModel.fromDbRow).toList();
  final subscriber = sdrRow != null ? SdrModel.fromDbRow(sdrRow) : null;

  return PhoneSearchResult(subscriber: subscriber, callLog: callLog);
});

final imeiSearchProvider = FutureProvider.family<List<CdrModel>, String>((ref, imei) async {
  final rows = await AppDatabase.instance.queryCdrByImei(imei);
  return rows.map(CdrModel.fromDbRow).toList();
});

// ── GPS data for map ─────────────────────────────────────────────────────────

final gpsCallsProvider = FutureProvider<List<CdrModel>>((ref) async {
  final rows = await AppDatabase.instance.queryAllCdrWithGps();
  return rows.map(CdrModel.fromDbRow).toList();
});

final allTowersProvider = FutureProvider<List<TdrModel>>((ref) async {
  final rows = await AppDatabase.instance.queryAllTdr();
  return rows.map(TdrModel.fromDbRow).toList();
});

// ── Graph data ────────────────────────────────────────────────────────────────

class GraphEdgeData {
  final String source;
  final String target;
  final int callCount;
  const GraphEdgeData({required this.source, required this.target, required this.callCount});
}

final graphDataProvider = FutureProvider.family<Map<String, List<GraphEdgeData>>, List<String>>((ref, suspects) async {
  final result = <String, List<GraphEdgeData>>{};
  for (final suspect in suspects) {
    final rows = await AppDatabase.instance.queryCdrByPhone(suspect);
    final edges = <GraphEdgeData>[];
    final contactCounts = <String, int>{};

    for (final row in rows) {
      final caller   = row['caller_number'] as String;
      final receiver = row['receiver_number'] as String;
      final contact  = (caller == suspect) ? receiver : caller;
      contactCounts[contact] = (contactCounts[contact] ?? 0) + 1;
    }

    for (final entry in contactCounts.entries) {
      edges.add(GraphEdgeData(source: suspect, target: entry.key, callCount: entry.value));
    }
    result[suspect] = edges;
  }
  return result;
});
