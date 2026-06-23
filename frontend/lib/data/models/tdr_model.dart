// lib/data/models/tdr_model.dart
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

class TdrModel {
  final int id;
  final String cellId;
  final double latitude;
  final double longitude;
  final double? azimuth;
  final int callCount;
  final String? firstContact;

  const TdrModel({
    this.id = 0,
    required this.cellId,
    required this.latitude,
    required this.longitude,
    this.azimuth,
    this.callCount = 0,
    this.firstContact,
  });

  factory TdrModel.fromDbRow(Map<String, dynamic> row) => TdrModel(
    id: (row['id'] as num?)?.toInt() ?? 0,
    cellId: row['cell_id']?.toString() ?? '',
    latitude: (row['latitude'] as num).toDouble(),
    longitude: (row['longitude'] as num).toDouble(),
    azimuth: (row['azimuth'] as num?)?.toDouble(),
    callCount: (row['call_count'] as num?)?.toInt() ?? 0,
    firstContact: row['first_contact']?.toString(),
  );

  LatLng get latLng => LatLng(latitude, longitude);

  String? get formattedFirstContact => firstContact != null
      ? DateFormat('dd MMM HH:mm').format(DateTime.parse(firstContact!).toLocal())
      : null;
}

/// GPS point from a CDR row (for map display).
class GpsCdrPoint {
  final double latitude;
  final double longitude;
  final String callerNumber;
  final String receiverNumber;
  final DateTime callTime;
  final int durationSeconds;
  final String? cellId;

  const GpsCdrPoint({
    required this.latitude,
    required this.longitude,
    required this.callerNumber,
    required this.receiverNumber,
    required this.callTime,
    required this.durationSeconds,
    this.cellId,
  });

  LatLng get latLng => LatLng(latitude, longitude);
  String get formattedTime => DateFormat('dd MMM HH:mm').format(callTime);
}
