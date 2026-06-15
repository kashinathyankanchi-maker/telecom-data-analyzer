// lib/data/repositories/ingest_repository.dart
import 'package:dio/dio.dart';
import '../../../lib/core/constants.dart';
import 'api_client.dart';

class IngestResult {
  final String recordType;
  final int inserted;
  final int skipped;
  final List<String> errors;

  const IngestResult({
    required this.recordType,
    required this.inserted,
    required this.skipped,
    required this.errors,
  });

  factory IngestResult.fromJson(Map<String, dynamic> json) => IngestResult(
    recordType: json['record_type'] as String,
    inserted: (json['inserted'] as num).toInt(),
    skipped: (json['skipped'] as num).toInt(),
    errors: (json['errors'] as List<dynamic>).cast<String>(),
  );
}

class IngestRepository {
  final _client = ApiClient.instance.dio;

  Future<IngestResult> uploadCsv({
    required String filePath,
    required String fileName,
    required List<int> fileBytes,
    required String recordType, // 'cdr' | 'sdr' | 'tdr'
    void Function(int sent, int total)? onProgress,
  }) async {
    return ApiClient.call(() async {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
          contentType: DioMediaType('text', 'csv'),
        ),
      });

      final response = await _client.post(
        '${ApiConstants.upload}/$recordType',
        data: formData,
        onSendProgress: onProgress,
      );

      return IngestResult.fromJson(response.data as Map<String, dynamic>);
    });
  }
}
