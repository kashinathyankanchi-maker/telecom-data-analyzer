// lib/data/repositories/geo_repository.dart
import '../../core/constants.dart';
import '../models/tdr_model.dart';
import 'api_client.dart';

class GeoRepository {
  final _client = ApiClient.instance.dio;

  Future<GeoMapData> fetchTowerMap(
    String phone, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return ApiClient.call(() async {
      final params = <String, dynamic>{'phone': phone};
      if (startDate != null) params['start_date'] = startDate.toUtc().toIso8601String();
      if (endDate != null)   params['end_date']   = endDate.toUtc().toIso8601String();

      final response = await _client.get(ApiConstants.towers, queryParameters: params);
      return GeoMapData.fromJson(response.data as Map<String, dynamic>);
    });
  }
}
