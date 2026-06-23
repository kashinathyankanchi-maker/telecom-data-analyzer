// lib/data/repositories/mock_interceptor.dart
//
// Demo Mode – intercepts all API calls and returns realistic mock data.
// Every response shape EXACTLY matches what the repository fromJson methods expect.
//
import 'package:dio/dio.dart';

class MockInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.path;

    // ── 1. Auth: Login ───────────────────────────────────────────────────────
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
            'created_at': DateTime.now().toIso8601String(),
          }
        },
      ));
    }

    // ── 2. Auth: Get Me ──────────────────────────────────────────────────────
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
          'created_at': DateTime.now().toIso8601String(),
        },
      ));
    }

    // ── 3. Ingest: Upload ────────────────────────────────────────────────────
    if (path.contains('/upload') || path.contains('/ingest')) {
      return handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'record_type': 'cdr',
          'inserted': 250,
          'skipped': 5,
          'errors': ['Row 12: missing caller_number', 'Row 47: invalid date format'],
        },
      ));
    }

    // ── 4. Search: Phone / IMEI ──────────────────────────────────────────────
    // SearchResult.fromJson expects: { subscriber?, summary{}, call_log[] }
    if (path.contains('/search')) {
      final queryType = options.queryParameters['type'] ?? 'phone';

      if (queryType == 'imei') {
        // ImeiResult.fromJson expects: { imei, associated_numbers[], call_log[] }
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'imei': options.queryParameters['q'] ?? '351000000000001',
            'associated_numbers': ['9876543210', '9123456789', '9000000001'],
            'call_log': _sampleCallLog(),
          },
        ));
      }

      // Phone search
      return handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'subscriber': {
            'id': 1,
            'phone_number': options.queryParameters['q'] ?? '9876543210',
            'subscriber_name': 'Demo Subscriber',
            'address': '42 Main Street, Bengaluru, Karnataka',
            'activation_date': '2021-03-15',
          },
          'summary': {
            'phone_number': options.queryParameters['q'] ?? '9876543210',
            'total_calls': 47,
            'total_duration_seconds': 18720,
            'first_seen': DateTime.now().subtract(const Duration(days: 180)).toIso8601String(),
            'last_seen': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
            'unique_contacts': 12,
            'unique_towers': 8,
          },
          'call_log': _sampleCallLog(),
        },
      ));
    }

    // ── 5. Graph: Link Analysis ──────────────────────────────────────────────
    // GraphData.fromJson expects: { nodes[{id,label,is_suspect,subscriber?}], edges[{source,target,call_count,total_duration}] }
    if (path.contains('/graph') || path.contains('/link')) {
      final suspects = (options.data?['suspects'] as List<dynamic>? ?? ['9876543210'])
          .map((e) => e.toString())
          .toList();

      final nodes = <Map<String, dynamic>>[];
      final edges = <Map<String, dynamic>>[];

      // Add suspect nodes
      for (final s in suspects) {
        nodes.add({
          'id': s,
          'label': s,
          'is_suspect': true,
          'subscriber': null,
        });
      }

      // Add contact nodes
      final contacts = ['8001112222', '7009998888', '9123000000', '9999111100'];
      for (final c in contacts) {
        nodes.add({
          'id': c,
          'label': c,
          'is_suspect': false,
          'subscriber': {
            'subscriber_name': 'Contact ${c.substring(c.length - 4)}',
            'address': 'Bengaluru, Karnataka',
            'activation_date': '2020-01-01',
          },
        });
      }

      // Add edges from first suspect to each contact
      if (suspects.isNotEmpty) {
        for (var i = 0; i < contacts.length; i++) {
          edges.add({
            'source': suspects[0],
            'target': contacts[i],
            'call_count': (i + 1) * 3,
            'total_duration': (i + 1) * 540,
          });
        }
        // Edge between suspects if more than 1
        if (suspects.length > 1) {
          edges.add({
            'source': suspects[0],
            'target': suspects[1],
            'call_count': 12,
            'total_duration': 3600,
          });
        }
      }

      return handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {'nodes': nodes, 'edges': edges},
      ));
    }

    // ── 6. Towers / Geo Map ──────────────────────────────────────────────────
    if (path.contains('/towers') || path.contains('/map')) {
      return handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: [
          {'id': 1, 'cell_id': 'CELL-BLR-01', 'lat': 12.9716, 'lon': 77.5946, 'radius': 500, 'hit_count': 25},
          {'id': 2, 'cell_id': 'CELL-BLR-02', 'lat': 12.9750, 'lon': 77.5900, 'radius': 750, 'hit_count': 10},
          {'id': 3, 'cell_id': 'CELL-BLR-03', 'lat': 12.9680, 'lon': 77.5980, 'radius': 400, 'hit_count': 18},
          {'id': 4, 'cell_id': 'CELL-BLR-04', 'lat': 12.9800, 'lon': 77.6010, 'radius': 600, 'hit_count': 7},
        ],
      ));
    }

    // ── Fallback: safe empty 200 ─────────────────────────────────────────────
    return handler.resolve(Response(
      requestOptions: options,
      statusCode: 200,
      data: {},
    ));
  }

  /// Returns a realistic list of CDR records matching CdrModel.fromJson
  static List<Map<String, dynamic>> _sampleCallLog() {
    final now = DateTime.now();
    return List.generate(15, (i) {
      final isOut = i.isEven;
      return {
        'id': i + 1,
        'caller_number': isOut ? '9876543210' : '800111${2000 + i}',
        'receiver_number': isOut ? '800111${2000 + i}' : '9876543210',
        'call_time': now.subtract(Duration(days: i, hours: i % 12)).toIso8601String(),
        'duration_seconds': 30 + (i * 47),
        'call_type': isOut ? 'outgoing' : 'incoming',
        'imei_number': '35100000000${i.toString().padLeft(4, '0')}',
        'cell_id': 'CELL-BLR-0${(i % 4) + 1}',
      };
    });
  }
}
