// lib/data/models/sdr_model.dart
import 'package:intl/intl.dart';

class SdrModel {
  final String phoneNumber;
  final String? subscriberName;
  final String? address;
  final DateTime? activationDate;

  const SdrModel({
    required this.phoneNumber,
    this.subscriberName,
    this.address,
    this.activationDate,
  });

  factory SdrModel.fromJson(Map<String, dynamic> json) => SdrModel(
    phoneNumber: json['phone_number']?.toString() ?? '',
    subscriberName: json['subscriber_name']?.toString(),
    address: json['address']?.toString(),
    activationDate: json['activation_date'] != null
        ? DateTime.tryParse(json['activation_date'].toString())
        : null,
  );

  String get displayName => subscriberName ?? phoneNumber;

  String? get formattedActivationDate => activationDate != null
      ? DateFormat('dd MMM yyyy').format(activationDate!)
      : null;
}
