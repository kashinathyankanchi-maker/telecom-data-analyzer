// lib/data/repositories/search_repository.dart
import 'package:telecom_analyzer/core/constants.dart';
import '../models/cdr_model.dart';
import '../models/sdr_model.dart';
import 'api_client.dart';

class SearchResult {
  final SdrModel? subscriber;
  final CdrSummary summary;
  final List<CdrModel> callLog;

  const SearchResult({
    this.subscriber,
    required this.summary,
    required this.callLog,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json, String phone) =>
      SearchResult(
        subscriber: json['subscriber'] != null
            ? SdrModel.fromJson(json['subscriber'] as Map<String, dynamic>)
            : null,
        summary: CdrSummary.fromJson(json['summary'] as Map<String, dynamic>),
        callLog: (json['call_log'] as List<dynamic>)
            .map((e) => CdrModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ImeiResult {
  final String imei;
  final List<String> associatedNumbers;
  final List<CdrModel> callLog;

  const ImeiResult({
    required this.imei,
    required this.associatedNumbers,
    required this.callLog,
  });

  factory ImeiResult.fromJson(Map<String, dynamic> json) => ImeiResult(
    imei: json['imei'] as String,
    associatedNumbers: (json['associated_numbers'] as List<dynamic>).cast<String>(),
    callLog: (json['call_log'] as List<dynamic>)
        .map((e) => CdrModel.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class SearchRepository {
  final _client = ApiClient.instance.dio;

  Future<SearchResult> searchByPhone(String phone, {int limit = 100, int offset = 0}) {
    return ApiClient.call(() async {
      final response = await _client.get(
        ApiConstants.search,
        queryParameters: {'q': phone, 'type': 'phone', 'limit': limit, 'offset': offset},
      );
      return SearchResult.fromJson(response.data as Map<String, dynamic>, phone);
    });
  }

  Future<ImeiResult> searchByImei(String imei, {int limit = 100, int offset = 0}) {
    return ApiClient.call(() async {
      final response = await _client.get(
        ApiConstants.search,
        queryParameters: {'q': imei, 'type': 'imei', 'limit': limit, 'offset': offset},
      );
      return ImeiResult.fromJson(response.data as Map<String, dynamic>);
    });
  }
}
