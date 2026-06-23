// lib/data/models/sdr_model.dart
import 'package:intl/intl.dart';

class SdrModel {
  final int id;
  final String phoneNumber;
  final String? subscriberName;
  final String? address;
  final DateTime? activationDate;

  const SdrModel({
    this.id = 0,
    required this.phoneNumber,
    this.subscriberName,
    this.address,
    this.activationDate,
  });

  factory SdrModel.fromDbRow(Map<String, dynamic> row) => SdrModel(
    id: (row['id'] as num?)?.toInt() ?? 0,
    phoneNumber: row['phone_number']?.toString() ?? '',
    subscriberName: row['subscriber_name']?.toString(),
    address: row['address']?.toString(),
    activationDate: row['activation_date'] != null
        ? DateTime.tryParse(row['activation_date'].toString())
        : null,
  );

  String get displayName => subscriberName ?? phoneNumber;

  String? get formattedActivationDate => activationDate != null
      ? DateFormat('dd MMM yyyy').format(activationDate!)
      : null;
}
