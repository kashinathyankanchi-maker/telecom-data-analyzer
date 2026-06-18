// lib/data/repositories/mock_interceptor.dart
import 'package:dio/dio.dart';

/// A Dio interceptor that intercepts all API calls and returns mock data.
/// This allows the app to function in a "Demo Mode" without a backend server.
class MockInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.path;

    // 1. Auth: Login
    if (path.contains('/auth/login')) {
      return handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'access_token': 'mock_jwt_token_123',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': 1,
            'username': 'admin',
            'email': 'admin@telecom.local',
            'role': 'admin',
            'is_active': true,
            'created_at': DateTime.now().toIso8601String()
          }
        },
      ));
    }

    // 2. Auth: Get Me
    if (path.contains('/auth/me')) {
      return handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'id': 1,
          'username': 'admin',
          'email': 'admin@telecom.local',
          'role': 'admin',
          'is_active': true,
          'created_at': DateTime.now().toIso8601String()
        },
      ));
    }

    // 3. Ingest: Upload
    if (path.contains('/upload')) {
      return handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'record_type': 'demo_data',
          'inserted': 100,
          'skipped': 0,
          'errors': []
        },
      ));
    }

    // 4. Search
    if (path.contains('/search')) {
      return handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: [
          {
            'id': 1,
            'type': 'cdr',
            'caller_number': '1234567890',
            'called_number': '0987654321',
            'timestamp': DateTime.now().toIso8601String(),
            'duration': 120,
            'location_lat': 12.9716,
            'location_lon': 77.5946
          },
          {
            'id': 2,
            'type': 'sdr',
            'imsi': '404000000000000',
            'imei': '351000000000000',
            'timestamp': DateTime.now().toIso8601String(),
            'location_lat': 12.9720,
            'location_lon': 77.5950
          }
        ],
      ));
    }

    // 5. Graph
    if (path.contains('/graph')) {
      return handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'nodes': [
            {'id': '1234567890', 'label': '1234567890\n(2 calls)'},
            {'id': '0987654321', 'label': '0987654321\n(2 calls)'},
            {'id': '1111111111', 'label': '1111111111\n(1 call)'},
          ],
          'edges': [
            {'source': '1234567890', 'target': '0987654321', 'weight': 2},
            {'source': '1234567890', 'target': '1111111111', 'weight': 1},
          ]
        },
      ));
    }

    // 6. Towers (Geo Map)
    if (path.contains('/towers')) {
      return handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: [
          {
            'id': 1,
            'cell_id': 'CELL-A',
            'lat': 12.9716,
            'lon': 77.5946,
            'radius': 500,
            'hit_count': 15
          },
          {
            'id': 2,
            'cell_id': 'CELL-B',
            'lat': 12.9750,
            'lon': 77.5900,
            'radius': 750,
            'hit_count': 5
          }
        ],
      ));
    }

    // Fallback: Just return empty 200 to prevent crashing
    return handler.resolve(Response(
      requestOptions: options,
      statusCode: 200,
      data: {},
    ));
  }
}
