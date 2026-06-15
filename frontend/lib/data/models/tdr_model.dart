// lib/data/models/tdr_model.dart
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

class TdrModel {
  final String cellId;
  final double latitude;
  final double longitude;
  final int? azimuth;
  // Below fields only present in geo-map responses
  final String? firstContact;
  final String? lastContact;
  final int callCount;

  const TdrModel({
    required this.cellId,
    required this.latitude,
    required this.longitude,
    this.azimuth,
    this.firstContact,
    this.lastContact,
    this.callCount = 0,
  });

  factory TdrModel.fromJson(Map<String, dynamic> json) => TdrModel(
    cellId: json['cell_id'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    azimuth: (json['azimuth'] as num?)?.toInt(),
    firstContact: json['first_contact'] as String?,
    lastContact: json['last_contact'] as String?,
    callCount: (json['call_count'] as num?)?.toInt() ?? 0,
  );

  LatLng get latLng => LatLng(latitude, longitude);

  String? get formattedFirstContact => firstContact != null
      ? DateFormat('dd MMM HH:mm').format(DateTime.parse(firstContact!).toLocal())
      : null;
}

/// A single CDR event in the geo-map timeline.
class TowerTimelineEvent {
  final DateTime callTime;
  final String cellId;
  final String callerNumber;
  final String receiverNumber;
  final int? durationSeconds;

  const TowerTimelineEvent({
    required this.callTime,
    required this.cellId,
    required this.callerNumber,
    required this.receiverNumber,
    this.durationSeconds,
  });

  factory TowerTimelineEvent.fromJson(Map<String, dynamic> json) =>
      TowerTimelineEvent(
        callTime: DateTime.parse(json['call_time'] as String).toLocal(),
        cellId: json['cell_id'] as String,
        callerNumber: json['caller_number'] as String,
        receiverNumber: json['receiver_number'] as String,
        durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      );

  String get formattedTime => DateFormat('dd MMM HH:mm:ss').format(callTime);
}

class GeoMapData {
  final String phoneNumber;
  final List<TdrModel> towers;
  final List<TowerTimelineEvent> timeline;

  const GeoMapData({
    required this.phoneNumber,
    required this.towers,
    required this.timeline,
  });

  factory GeoMapData.fromJson(Map<String, dynamic> json) => GeoMapData(
    phoneNumber: json['phone_number'] as String,
    towers: (json['towers'] as List<dynamic>)
        .map((e) => TdrModel.fromJson(e as Map<String, dynamic>))
        .toList(),
    timeline: (json['timeline'] as List<dynamic>)
        .map((e) => TowerTimelineEvent.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
