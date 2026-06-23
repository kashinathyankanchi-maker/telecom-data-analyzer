// lib/data/models/cdr_model.dart
import 'package:intl/intl.dart';

class CdrModel {
  final int id;
  final String callerNumber;
  final String receiverNumber;
  final DateTime callTime;
  final int durationSeconds;
  final String callType;
  final String? imeiNumber;
  final String? cellId;

  const CdrModel({
    required this.id,
    required this.callerNumber,
    required this.receiverNumber,
    required this.callTime,
    required this.durationSeconds,
    required this.callType,
    this.imeiNumber,
    this.cellId,
  });

  factory CdrModel.fromJson(Map<String, dynamic> json) => CdrModel(
    id: (json['id'] as num?)?.toInt() ?? 0,
    callerNumber: json['caller_number']?.toString() ?? '',
    receiverNumber: json['receiver_number']?.toString() ?? '',
    callTime: json['call_time'] != null
        ? DateTime.tryParse(json['call_time'].toString())?.toLocal() ?? DateTime.now()
        : DateTime.now(),
    durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
    callType: json['call_type']?.toString() ?? 'unknown',
    imeiNumber: json['imei_number']?.toString(),
    cellId: json['cell_id']?.toString(),
  );

  String get formattedTime =>
      DateFormat('dd MMM yyyy, HH:mm').format(callTime);

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }
}

class CdrSummary {
  final String phoneNumber;
  final int totalCalls;
  final int totalDurationSeconds;
  final DateTime? firstSeen;
  final DateTime? lastSeen;
  final int uniqueContacts;
  final int uniqueTowers;

  const CdrSummary({
    required this.phoneNumber,
    required this.totalCalls,
    required this.totalDurationSeconds,
    this.firstSeen,
    this.lastSeen,
    required this.uniqueContacts,
    required this.uniqueTowers,
  });

  factory CdrSummary.fromJson(Map<String, dynamic> json) => CdrSummary(
    phoneNumber: json['phone_number'] as String,
    totalCalls: (json['total_calls'] as num?)?.toInt() ?? 0,
    totalDurationSeconds: (json['total_duration_seconds'] as num?)?.toInt() ?? 0,
    firstSeen: json['first_seen'] != null
        ? DateTime.parse(json['first_seen'] as String).toLocal()
        : null,
    lastSeen: json['last_seen'] != null
        ? DateTime.parse(json['last_seen'] as String).toLocal()
        : null,
    uniqueContacts: (json['unique_contacts'] as num?)?.toInt() ?? 0,
    uniqueTowers: (json['unique_towers'] as num?)?.toInt() ?? 0,
  );

  String get formattedTotalDuration {
    final h = totalDurationSeconds ~/ 3600;
    final m = (totalDurationSeconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}
