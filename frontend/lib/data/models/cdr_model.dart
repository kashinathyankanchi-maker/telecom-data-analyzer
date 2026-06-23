// lib/data/models/cdr_model.dart
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

class CdrModel {
  final int id;
  final String callerNumber;
  final String receiverNumber;
  final DateTime callTime;
  final int durationSeconds;
  final String callType;
  final String? imeiNumber;
  final String? cellId;
  final double? latitude;
  final double? longitude;

  const CdrModel({
    required this.id,
    required this.callerNumber,
    required this.receiverNumber,
    required this.callTime,
    required this.durationSeconds,
    required this.callType,
    this.imeiNumber,
    this.cellId,
    this.latitude,
    this.longitude,
  });

  bool get hasGps => latitude != null && longitude != null;
  LatLng? get latLng => hasGps ? LatLng(latitude!, longitude!) : null;

  factory CdrModel.fromDbRow(Map<String, dynamic> row) => CdrModel(
    id: (row['id'] as num?)?.toInt() ?? 0,
    callerNumber: row['caller_number']?.toString() ?? '',
    receiverNumber: row['receiver_number']?.toString() ?? '',
    callTime: row['call_time'] != null
        ? DateTime.tryParse(row['call_time'].toString())?.toLocal() ?? DateTime.now()
        : DateTime.now(),
    durationSeconds: (row['duration_seconds'] as num?)?.toInt() ?? 0,
    callType: row['call_type']?.toString() ?? 'unknown',
    imeiNumber: row['imei_number']?.toString(),
    cellId: row['cell_id']?.toString(),
    latitude: (row['latitude'] as num?)?.toDouble(),
    longitude: (row['longitude'] as num?)?.toDouble(),
  );

  String get formattedTime =>
      DateFormat('dd MMM yyyy, HH:mm').format(callTime);

  String get formattedDate =>
      DateFormat('dd MMM yyyy').format(callTime);

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  bool get isOutgoing => callType.toLowerCase() == 'outgoing' || callType.toLowerCase() == 'mo';
}

class CdrSummary {
  final String phoneNumber;
  final int totalCalls;
  final int totalDurationSeconds;
  final DateTime? firstSeen;
  final DateTime? lastSeen;
  final int uniqueContacts;
  final int uniqueTowers;
  final Map<String, int> callsPerDay;
  final Map<int, int> callsPerHour;
  final Map<String, int> topContacts;
  final int incoming;
  final int outgoing;

  const CdrSummary({
    required this.phoneNumber,
    required this.totalCalls,
    required this.totalDurationSeconds,
    this.firstSeen,
    this.lastSeen,
    required this.uniqueContacts,
    required this.uniqueTowers,
    required this.callsPerDay,
    required this.callsPerHour,
    required this.topContacts,
    required this.incoming,
    required this.outgoing,
  });

  factory CdrSummary.fromCallLog(String phone, List<CdrModel> log) {
    if (log.isEmpty) {
      return CdrSummary(
        phoneNumber: phone, totalCalls: 0, totalDurationSeconds: 0,
        uniqueContacts: 0, uniqueTowers: 0,
        callsPerDay: {}, callsPerHour: {}, topContacts: {},
        incoming: 0, outgoing: 0,
      );
    }

    final contacts  = <String>{};
    final towers    = <String>{};
    final perDay    = <String, int>{};
    final perHour   = <int, int>{};
    final contactMap= <String, int>{};
    var totalDur    = 0;
    var inc = 0, out = 0;

    for (final c in log) {
      totalDur += c.durationSeconds;
      final contact = (c.callerNumber == phone) ? c.receiverNumber : c.callerNumber;
      contacts.add(contact);
      contactMap[contact] = (contactMap[contact] ?? 0) + 1;
      if (c.cellId != null) towers.add(c.cellId!);

      final dayKey = DateFormat('yyyy-MM-dd').format(c.callTime);
      perDay[dayKey] = (perDay[dayKey] ?? 0) + 1;
      perHour[c.callTime.hour] = (perHour[c.callTime.hour] ?? 0) + 1;

      if (c.isOutgoing) { out++; } else { inc++; }
    }

    final sorted = log..sort((a, b) => a.callTime.compareTo(b.callTime));
    final topContacts = Map.fromEntries(
      contactMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))
        ..take(5),
    );

    return CdrSummary(
      phoneNumber: phone,
      totalCalls: log.length,
      totalDurationSeconds: totalDur,
      firstSeen: sorted.first.callTime,
      lastSeen: sorted.last.callTime,
      uniqueContacts: contacts.length,
      uniqueTowers: towers.length,
      callsPerDay: perDay,
      callsPerHour: perHour,
      topContacts: topContacts,
      incoming: inc,
      outgoing: out,
    );
  }

  String get formattedTotalDuration {
    final h = totalDurationSeconds ~/ 3600;
    final m = (totalDurationSeconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}
