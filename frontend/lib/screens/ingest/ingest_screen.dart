// lib/screens/ingest/ingest_screen.dart
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/csv_parser.dart';
import '../../core/database.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../providers/data_store.dart';
import '../../widgets/section_header.dart';

// ── State ──────────────────────────────────────────────────────────────────────
enum _Status { idle, picking, parsing, success, error }

class _IngestState {
  final _Status status;
  final String selectedType;
  final String? fileName;
  final ParseResult? result;
  final String? errorMessage;

  const _IngestState({
    this.status = _Status.idle,
    this.selectedType = 'cdr',
    this.fileName,
    this.result,
    this.errorMessage,
  });

  _IngestState copyWith({
    _Status? status,
    String? selectedType,
    String? fileName,
    ParseResult? result,
    String? errorMessage,
  }) => _IngestState(
    status: status ?? this.status,
    selectedType: selectedType ?? this.selectedType,
    fileName: fileName ?? this.fileName,
    result: result ?? this.result,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}

class _IngestNotifier extends StateNotifier<_IngestState> {
  final Ref _ref;
  _IngestNotifier(this._ref) : super(const _IngestState());

  void selectType(String t) => state = state.copyWith(selectedType: t);

  Future<void> pickAndIngest() async {
    state = state.copyWith(status: _Status.picking);

    FilePickerResult? picked;
    try {
      picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
        dialogTitle: 'Select CSV File',
      );
    } catch (e) {
      // Fallback without extension filter
      picked = await FilePicker.pickFiles(withData: true, dialogTitle: 'Select CSV File');
    }
    if (picked == null || picked.files.isEmpty) {
      state = state.copyWith(status: _Status.idle);
      return;
    }

    final file = picked.files.single;
    state = state.copyWith(status: _Status.parsing, fileName: file.name);

    try {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        state = state.copyWith(status: _Status.error, errorMessage: 'File is empty or could not be read.');
        return;
      }

      final csvText = utf8.decode(bytes, allowMalformed: true);

      ParseResult parsed;
      int dbInserted;

      if (state.selectedType == 'cdr') {
        parsed = CsvParser.parseCdr(csvText);
        dbInserted = await AppDatabase.instance.insertCdrBatch(parsed.rows);
      } else if (state.selectedType == 'sdr') {
        parsed = CsvParser.parseSdr(csvText);
        dbInserted = await AppDatabase.instance.insertSdrBatch(parsed.rows);
      } else {
        parsed = CsvParser.parseTdr(csvText);
        dbInserted = await AppDatabase.instance.insertTdrBatch(parsed.rows);
      }

      // Refresh counts in the home shell
      _ref.invalidate(dbCountsProvider);

      state = state.copyWith(
        status: _Status.success,
        result: ParseResult(
          rows: parsed.rows,
          inserted: dbInserted,
          skipped: parsed.skipped,
          errors: parsed.errors,
          detectedColumns: parsed.detectedColumns,
        ),
      );
    } catch (e) {
      state = state.copyWith(
        status: _Status.error,
        errorMessage: e.toString(),
      );
    }
  }

  void reset() => state = const _IngestState();
}

final _ingestProvider = StateNotifierProvider.autoDispose<_IngestNotifier, _IngestState>(
  (ref) => _IngestNotifier(ref),
);

// ── Screen ─────────────────────────────────────────────────────────────────────
class IngestScreen extends ConsumerWidget {
  const IngestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state    = ref.watch(_ingestProvider);
    final notifier = ref.read(_ingestProvider.notifier);
    final padding  = Responsive.pagePadding(context);
    final counts   = ref.watch(dbCountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Ingestion'),
        actions: [
          if (state.status == _Status.success || state.status == _Status.error)
            TextButton.icon(
              onPressed: notifier.reset,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Import Another'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: padding,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.maxContentWidth(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // DB Stats banner
                counts.when(
                  data: (c) => _DbStatsBanner(counts: c),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 24),
                const SectionHeader(
                  title: 'Import Telecom Records',
                  subtitle: 'Select a CSV file to import CDR, SDR, or TDR data. Data is stored locally on your computer.',
                ),
                const SizedBox(height: 28),

                // Step 1: Record type
                _RecordTypeSelector(
                  selected: state.selectedType,
                  onChanged: notifier.selectType,
                ),
                const SizedBox(height: 28),

                // Step 2: Format guide
                _CsvFormatGuide(recordType: state.selectedType),
                const SizedBox(height: 28),

                // Step 3: Import button / drop zone
                if (state.status != _Status.success)
                  _ImportButton(
                    status: state.status,
                    fileName: state.fileName,
                    onPressed: state.status == _Status.idle ? notifier.pickAndIngest : null,
                  ),

                // Results
                if (state.status == _Status.success && state.result != null) ...[
                  const SizedBox(height: 24),
                  _ResultCard(result: state.result!, fileName: state.fileName ?? ''),
                ],

                // Error
                if (state.status == _Status.error) ...[
                  const SizedBox(height: 24),
                  _ErrorCard(message: state.errorMessage ?? 'Unknown error'),
                ],

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── DB Stats Banner ────────────────────────────────────────────────────────────
class _DbStatsBanner extends StatelessWidget {
  const _DbStatsBanner({required this.counts});
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bgBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(label: 'CDR Records', value: '${counts['cdr'] ?? 0}', icon: Icons.call, color: AppColors.accent),
          _StatChip(label: 'SDR Records', value: '${counts['sdr'] ?? 0}', icon: Icons.person_outline, color: AppColors.secondary),
          _StatChip(label: 'TDR Towers', value: '${counts['tdr'] ?? 0}', icon: Icons.cell_tower, color: AppColors.info),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.icon, required this.color});
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 6),
      Text(value, style: AppTextStyles.headlineMedium.copyWith(color: color)),
      Text(label, style: AppTextStyles.bodySmall),
    ],
  );
}

// ── Record Type Selector ───────────────────────────────────────────────────────
class _RecordTypeSelector extends StatelessWidget {
  const _RecordTypeSelector({required this.selected, required this.onChanged});
  final String selected;
  final void Function(String) onChanged;

  static const _types = [
    ('cdr', 'CDR', Icons.call_outlined, 'Call Detail Records', 'caller, receiver, call_time, duration, imei, cell_id'),
    ('sdr', 'SDR', Icons.person_outline, 'Subscriber Data Records', 'phone_number, subscriber_name, address, activation_date'),
    ('tdr', 'TDR', Icons.cell_tower, 'Tower Detail Records', 'cell_id, latitude, longitude, azimuth'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Record Type', style: AppTextStyles.labelLarge),
        const SizedBox(height: 12),
        ...(_types.map((t) {
          final isSelected = t.$1 == selected;
          return GestureDetector(
            onTap: () => onChanged(t.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accentGlow : AppColors.bgSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppColors.accent : AppColors.bgBorder,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(t.$3, size: 22, color: isSelected ? AppColors.accent : AppColors.textMuted),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.$2, style: AppTextStyles.labelLarge.copyWith(
                          color: isSelected ? AppColors.accent : AppColors.textPrimary,
                        )),
                        const SizedBox(height: 2),
                        Text(t.$4, style: AppTextStyles.bodySmall),
                        const SizedBox(height: 2),
                        Text('Columns: ${t.$5}', style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted, fontSize: 10,
                        )),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: AppColors.accent, size: 20),
                ],
              ),
            ),
          );
        })),
      ],
    );
  }
}

// ── CSV Format Guide ───────────────────────────────────────────────────────────
class _CsvFormatGuide extends StatelessWidget {
  const _CsvFormatGuide({required this.recordType});
  final String recordType;

  static const _examples = {
    'cdr': '''caller_number,receiver_number,call_time,duration_seconds,call_type,imei_number,cell_id,latitude,longitude
9876543210,8001234567,2024-03-15 10:23:45,120,outgoing,351000000000001,CELL-01,12.9716,77.5946
8001234567,9876543210,2024-03-15 11:05:12,60,incoming,,CELL-02,,''',
    'sdr': '''phone_number,subscriber_name,address,activation_date
9876543210,John Kumar,"42 MG Road, Bengaluru",2020-01-15
8001234567,Jane Sharma,"18 Anna Salai, Chennai",2019-06-01''',
    'tdr': '''cell_id,latitude,longitude,azimuth
CELL-BLR-01,12.9716,77.5946,120
CELL-BLR-02,12.9750,77.5900,240''',
  };

  @override
  Widget build(BuildContext context) {
    final example = _examples[recordType] ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.info_outline, size: 16, color: AppColors.info),
            const SizedBox(width: 8),
            Text('Expected CSV Format', style: AppTextStyles.labelLarge),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.bgBorder),
          ),
          child: Text(example, style: AppTextStyles.monoSmall.copyWith(color: AppColors.accent, fontSize: 11)),
        ),
        const SizedBox(height: 8),
        Text(
          'Column names are flexible — many aliases are supported. '
          'For CDR: latitude/longitude columns are optional (enables map view if present).',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

// ── Import Button ──────────────────────────────────────────────────────────────
class _ImportButton extends StatelessWidget {
  const _ImportButton({required this.status, required this.fileName, required this.onPressed});
  final _Status status;
  final String? fileName;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isLoading = status == _Status.picking || status == _Status.parsing;
    return SizedBox(
      width: double.infinity,
      height: 120,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.accent, Color(0xFF0099EE)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: isLoading
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 28, height: 28,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        status == _Status.picking ? 'Selecting file…' : 'Parsing CSV…',
                        style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.upload_file_outlined, color: Colors.white, size: 36),
                      const SizedBox(height: 8),
                      Text('Click to Select CSV File', style: AppTextStyles.labelLarge.copyWith(color: Colors.white)),
                      Text('Files are parsed and stored locally', style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Result Card ────────────────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.fileName});
  final ParseResult result;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text('Import Complete: $fileName',
              style: AppTextStyles.titleLarge.copyWith(color: AppColors.success),
              overflow: TextOverflow.ellipsis,
            )),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _Stat('Inserted', '${result.inserted}', AppColors.success)),
            const SizedBox(width: 12),
            Expanded(child: _Stat('Skipped', '${result.skipped}', AppColors.warning)),
            const SizedBox(width: 12),
            Expanded(child: _Stat('Errors', '${result.errors.length}', AppColors.error)),
          ]),
          if (result.detectedColumns.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Detected Columns', style: AppTextStyles.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: result.detectedColumns.map((col) => Chip(
                label: Text(col, style: AppTextStyles.bodySmall),
                backgroundColor: AppColors.bgElevated,
                side: const BorderSide(color: AppColors.bgBorder),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
              )).toList(),
            ),
          ],
          if (result.errors.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Errors (first ${result.errors.take(5).length})', style: AppTextStyles.labelLarge),
            const SizedBox(height: 6),
            ...result.errors.take(5).map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $e', style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning)),
            )),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(children: [
      Text(value, style: AppTextStyles.headlineMedium.copyWith(color: color)),
      Text(label, style: AppTextStyles.bodySmall),
    ]),
  );
}

// ── Error Card ─────────────────────────────────────────────────────────────────
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.error.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.error.withOpacity(0.3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, color: AppColors.error),
        const SizedBox(width: 12),
        Expanded(child: Text(message, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error))),
      ],
    ),
  );
}
