// lib/core/csv_parser.dart
// Flexible CSV parser with alias-based column mapping.
// Handles CDR, SDR and TDR files with varying column name conventions.

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';

class ParseResult {
  final List<Map<String, dynamic>> rows;
  final int inserted;
  final int skipped;
  final List<String> errors;
  final List<String> detectedColumns;

  const ParseResult({
    required this.rows,
    required this.inserted,
    required this.skipped,
    required this.errors,
    required this.detectedColumns,
  });
}

class CsvParser {
  // ── Column aliases ──────────────────────────────────────────────────────────

  static const _callerAliases    = ['caller_number','caller','calling_number','from','a_number','msisdn_a'];
  static const _receiverAliases  = ['receiver_number','receiver','called_number','to','b_number','msisdn_b','called'];
  static const _callTimeAliases  = ['call_time','timestamp','date_time','date','call_date','start_time','event_time'];
  static const _durationAliases  = ['duration_seconds','duration','call_duration','duration_sec','dur'];
  static const _callTypeAliases  = ['call_type','type','direction'];
  static const _imeiAliases      = ['imei_number','imei','device_id','handset_imei'];
  static const _cellIdAliases    = ['cell_id','tower_id','cell','site_id','bts_id','serving_cell'];
  static const _latAliases       = ['latitude','lat','gps_lat','tower_lat','y'];
  static const _lonAliases       = ['longitude','lon','lng','gps_lon','gps_lng','tower_lon','x'];

  // SDR
  static const _phoneAliases     = ['phone_number','msisdn','phone','mobile','subscriber_number','number'];
  static const _nameAliases      = ['subscriber_name','name','customer_name','full_name','subscriber'];
  static const _addressAliases   = ['address','location','customer_address'];
  static const _activationAliases= ['activation_date','activated_on','sim_date','start_date'];

  // TDR
  static const _towerCellAliases = ['cell_id','tower_id','site_id','bts_id','cell'];
  static const _azimuthAliases   = ['azimuth','bearing','direction_deg','az'];

  // ── Main parse entry ────────────────────────────────────────────────────────

  static ParseResult parseCdr(String csvContent) {
    return _parse(csvContent, _mapCdrRow);
  }

  static ParseResult parseSdr(String csvContent) {
    return _parse(csvContent, _mapSdrRow);
  }

  static ParseResult parseTdr(String csvContent) {
    return _parse(csvContent, _mapTdrRow);
  }

  // ── Internal ────────────────────────────────────────────────────────────────

  static ParseResult _parse(
    String csvContent,
    Map<String, dynamic>? Function(Map<String, String> row, int rowNum, List<String> errors) mapper,
  ) {
    final rows  = <Map<String, dynamic>>[];
    final errors= <String>[];
    var skipped = 0;

    List<List<dynamic>> table;
    try {
      table = const CsvToListConverter(eol: '\n').convert(csvContent);
      if (table.isEmpty) {
        return ParseResult(rows: [], inserted: 0, skipped: 0, errors: ['Empty file'], detectedColumns: []);
      }
    } catch (e) {
      return ParseResult(rows: [], inserted: 0, skipped: 0, errors: ['CSV parse error: $e'], detectedColumns: []);
    }

    // First row = headers
    final headers = table.first.map((h) => h.toString().trim().toLowerCase()).toList();
    final detectedColumns = table.first.map((h) => h.toString().trim()).toList();

    for (var i = 1; i < table.length; i++) {
      final raw = table[i];
      if (raw.every((cell) => cell.toString().trim().isEmpty)) continue;

      final rowMap = <String, String>{};
      for (var j = 0; j < headers.length && j < raw.length; j++) {
        rowMap[headers[j]] = raw[j].toString().trim();
      }

      final mapped = mapper(rowMap, i, errors);
      if (mapped != null) {
        rows.add(mapped);
      } else {
        skipped++;
      }
    }

    return ParseResult(
      rows: rows,
      inserted: rows.length,
      skipped: skipped,
      errors: errors,
      detectedColumns: detectedColumns,
    );
  }

  // ── CDR row mapper ──────────────────────────────────────────────────────────

  static Map<String, dynamic>? _mapCdrRow(
    Map<String, String> row,
    int rowNum,
    List<String> errors,
  ) {
    final caller   = _find(row, _callerAliases);
    final receiver = _find(row, _receiverAliases);
    final callTime = _find(row, _callTimeAliases);

    if (caller == null || caller.isEmpty) {
      errors.add('Row $rowNum: missing caller number');
      return null;
    }
    if (receiver == null || receiver.isEmpty) {
      errors.add('Row $rowNum: missing receiver number');
      return null;
    }
    if (callTime == null || callTime.isEmpty) {
      errors.add('Row $rowNum: missing call_time');
      return null;
    }

    final parsedTime = _parseDateTime(callTime);
    if (parsedTime == null) {
      errors.add('Row $rowNum: unrecognized date format "$callTime"');
      return null;
    }

    final durationStr = _find(row, _durationAliases) ?? '0';
    final duration = int.tryParse(durationStr.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;

    final latStr = _find(row, _latAliases);
    final lonStr = _find(row, _lonAliases);
    final lat    = latStr != null ? double.tryParse(latStr) : null;
    final lon    = lonStr != null ? double.tryParse(lonStr) : null;

    return {
      'caller_number'  : caller,
      'receiver_number': receiver,
      'call_time'      : parsedTime.toIso8601String(),
      'duration_seconds': duration,
      'call_type'      : _find(row, _callTypeAliases) ?? 'unknown',
      'imei_number'    : _find(row, _imeiAliases),
      'cell_id'        : _find(row, _cellIdAliases),
      'latitude'       : (lat != null && lon != null) ? lat : null,
      'longitude'      : (lat != null && lon != null) ? lon : null,
    };
  }

  // ── SDR row mapper ──────────────────────────────────────────────────────────

  static Map<String, dynamic>? _mapSdrRow(
    Map<String, String> row,
    int rowNum,
    List<String> errors,
  ) {
    final phone = _find(row, _phoneAliases);
    if (phone == null || phone.isEmpty) {
      errors.add('Row $rowNum: missing phone_number');
      return null;
    }
    return {
      'phone_number'    : phone,
      'subscriber_name' : _find(row, _nameAliases),
      'address'         : _find(row, _addressAliases),
      'activation_date' : _find(row, _activationAliases),
    };
  }

  // ── TDR row mapper ──────────────────────────────────────────────────────────

  static Map<String, dynamic>? _mapTdrRow(
    Map<String, String> row,
    int rowNum,
    List<String> errors,
  ) {
    final cellId = _find(row, _towerCellAliases);
    final latStr = _find(row, _latAliases);
    final lonStr = _find(row, _lonAliases);

    if (cellId == null || cellId.isEmpty) {
      errors.add('Row $rowNum: missing cell_id');
      return null;
    }
    final lat = latStr != null ? double.tryParse(latStr) : null;
    final lon = lonStr != null ? double.tryParse(lonStr) : null;
    if (lat == null || lon == null) {
      errors.add('Row $rowNum: missing or invalid latitude/longitude');
      return null;
    }

    final azStr = _find(row, _azimuthAliases);
    return {
      'cell_id'  : cellId,
      'latitude' : lat,
      'longitude': lon,
      'azimuth'  : azStr != null ? double.tryParse(azStr) : null,
    };
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Find the first matching key in row using alias list.
  static String? _find(Map<String, String> row, List<String> aliases) {
    for (final alias in aliases) {
      final val = row[alias];
      if (val != null && val.isNotEmpty) return val;
    }
    return null;
  }

  /// Parse date strings in multiple formats.
  static DateTime? _parseDateTime(String s) {
    // Try ISO8601 first
    try { return DateTime.parse(s); } catch (_) {}

    // Common formats: dd/MM/yyyy HH:mm:ss  |  MM-dd-yyyy HH:mm  |  yyyy-MM-dd HH:mm:ss
    final patterns = [
      RegExp(r'^(\d{2})/(\d{2})/(\d{4})\s+(\d{2}):(\d{2}):(\d{2})$'),
      RegExp(r'^(\d{2})/(\d{2})/(\d{4})\s+(\d{2}):(\d{2})$'),
      RegExp(r'^(\d{2})-(\d{2})-(\d{4})\s+(\d{2}):(\d{2}):(\d{2})$'),
      RegExp(r'^(\d{4})/(\d{2})/(\d{2})\s+(\d{2}):(\d{2}):(\d{2})$'),
    ];
    for (final pat in patterns) {
      final m = pat.firstMatch(s);
      if (m == null) continue;
      try {
        // Reformat as ISO and parse
        final reformat = '${m.group(3)}-${m.group(2)}-${m.group(1)}T${m.group(4)}:${m.group(5)}:${m.group(6) ?? '00'}';
        return DateTime.parse(reformat);
      } catch (_) {}
    }
    debugPrint('[CSV] Could not parse date: $s');
    return null;
  }
}
