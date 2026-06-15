// lib/screens/ingest/ingest_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Feature A: CSV Data Ingestion Screen
// ─────────────────────────────────────────────────────────────────────────────
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../data/repositories/ingest_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';

// ── State ─────────────────────────────────────────────────────────────────────
enum _UploadStatus { idle, picking, uploading, success, error }

class _IngestState {
  final _UploadStatus status;
  final String selectedType;    // 'cdr' | 'sdr' | 'tdr'
  final String? fileName;
  final List<int>? fileBytes;
  final IngestResult? result;
  final String? errorMessage;
  final double progress;

  const _IngestState({
    this.status = _UploadStatus.idle,
    this.selectedType = 'cdr',
    this.fileName,
    this.fileBytes,
    this.result,
    this.errorMessage,
    this.progress = 0,
  });

  _IngestState copyWith({
    _UploadStatus? status,
    String? selectedType,
    String? fileName,
    List<int>? fileBytes,
    IngestResult? result,
    String? errorMessage,
    double? progress,
  }) => _IngestState(
    status: status ?? this.status,
    selectedType: selectedType ?? this.selectedType,
    fileName: fileName ?? this.fileName,
    fileBytes: fileBytes ?? this.fileBytes,
    result: result ?? this.result,
    errorMessage: errorMessage ?? this.errorMessage,
    progress: progress ?? this.progress,
  );
}

class _IngestNotifier extends StateNotifier<_IngestState> {
  _IngestNotifier() : super(const _IngestState());
  final _repo = IngestRepository();

  void selectType(String type) => state = state.copyWith(selectedType: type);

  Future<void> pickFile() async {
    state = state.copyWith(status: _UploadStatus.picking);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      state = state.copyWith(status: _UploadStatus.idle);
      return;
    }
    final file = result.files.single;
    state = state.copyWith(
      status: _UploadStatus.idle,
      fileName: file.name,
      fileBytes: file.bytes?.toList(),
    );
  }

  Future<void> upload() async {
    if (state.fileBytes == null) return;
    state = state.copyWith(status: _UploadStatus.uploading, progress: 0);
    try {
      final result = await _repo.uploadCsv(
        filePath: '',
        fileName: state.fileName!,
        fileBytes: state.fileBytes!,
        recordType: state.selectedType,
        onProgress: (sent, total) {
          if (total > 0) state = state.copyWith(progress: sent / total);
        },
      );
      state = state.copyWith(status: _UploadStatus.success, result: result);
    } catch (e) {
      state = state.copyWith(status: _UploadStatus.error, errorMessage: e.toString());
    }
  }

  void reset() => state = const _IngestState();
}

final _ingestProvider = StateNotifierProvider.autoDispose<_IngestNotifier, _IngestState>(
  (_) => _IngestNotifier(),
);

// ── Screen ────────────────────────────────────────────────────────────────────
class IngestScreen extends ConsumerWidget {
  const IngestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_ingestProvider);
    final notifier = ref.read(_ingestProvider.notifier);
    final padding = Responsive.pagePadding(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Ingestion'),
        actions: [
          if (state.status == _UploadStatus.success || state.status == _UploadStatus.error)
            TextButton.icon(
              onPressed: notifier.reset,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('New Upload'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: padding,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: Responsive.maxContentWidth(context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const SectionHeader(
                      title: 'Import Telecom Records',
                      subtitle: 'Upload a CSV file to bulk-insert CDR, SDR, or TDR records',
                    ),
                    const SizedBox(height: 28),

                    // Step 1: Record type selector
                    _RecordTypeSelector(
                      selected: state.selectedType,
                      onChanged: notifier.selectType,
                    ),
                    const SizedBox(height: 24),

                    // Step 2: File drop zone
                    _FileDropZone(
                      fileName: state.fileName,
                      onPickFile: notifier.pickFile,
                    ),
                    const SizedBox(height: 28),

                    // Step 3: Upload button
                    if (state.fileName != null && state.status != _UploadStatus.success)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: state.status == _UploadStatus.uploading
                              ? null
                              : notifier.upload,
                          icon: const Icon(Icons.cloud_upload_outlined),
                          label: const Text('Upload & Ingest'),
                        ),
                      ),

                    // Upload progress
                    if (state.status == _UploadStatus.uploading) ...[
                      const SizedBox(height: 16),
                      _UploadProgress(progress: state.progress),
                    ],

                    // Results card
                    if (state.status == _UploadStatus.success && state.result != null) ...[
                      const SizedBox(height: 24),
                      _ResultCard(result: state.result!),
                    ],

                    // Error card
                    if (state.status == _UploadStatus.error) ...[
                      const SizedBox(height: 24),
                      _ErrorCard(message: state.errorMessage ?? 'Unknown error'),
                    ],

                    const SizedBox(height: 40),
                    _CsvFormatGuide(recordType: state.selectedType),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _RecordTypeSelector extends StatelessWidget {
  const _RecordTypeSelector({required this.selected, required this.onChanged});
  final String selected;
  final void Function(String) onChanged;

  static const _types = [
    ('cdr', 'CDR', Icons.call_outlined, 'Call Detail Records'),
    ('sdr', 'SDR', Icons.person_outline, 'Subscriber Details'),
    ('tdr', 'TDR', Icons.cell_tower, 'Tower Records'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Record Type', style: AppTextStyles.labelLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _types.map((t) {
            final isSelected = t.$1 == selected;
            return GestureDetector(
              onTap: () => onChanged(t.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(t.$3, size: 18, color: isSelected ? AppColors.accent : AppColors.textMuted),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.$2, style: AppTextStyles.labelLarge.copyWith(
                          color: isSelected ? AppColors.accent : AppColors.textPrimary,
                        )),
                        Text(t.$4, style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _FileDropZone extends StatelessWidget {
  const _FileDropZone({required this.fileName, required this.onPickFile});
  final String? fileName;
  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPickFile,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 160,
        decoration: BoxDecoration(
          color: fileName != null ? AppColors.accentGlow : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: fileName != null ? AppColors.accent : AppColors.bgBorder,
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: fileName != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.success, size: 36),
                    const SizedBox(height: 10),
                    Text(fileName!, style: AppTextStyles.titleLarge.copyWith(color: AppColors.success)),
                    const SizedBox(height: 4),
                    Text('Tap to change file', style: AppTextStyles.bodySmall),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.upload_file_outlined, color: AppColors.accent, size: 40),
                    const SizedBox(height: 10),
                    Text('Tap to select CSV file', style: AppTextStyles.titleLarge),
                    const SizedBox(height: 4),
                    Text('CSV files up to 50 MB', style: AppTextStyles.bodySmall),
                  ],
                ),
        ),
      ),
    );
  }
}

class _UploadProgress extends StatelessWidget {
  const _UploadProgress({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Uploading…', style: AppTextStyles.bodyMedium),
            Text('${(progress * 100).toInt()}%', style: AppTextStyles.labelLarge.copyWith(color: AppColors.accent)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.bgElevated,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final IngestResult result;

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
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 22),
              const SizedBox(width: 10),
              Text('Ingestion Complete', style: AppTextStyles.titleLarge.copyWith(color: AppColors.success)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _ResultStat(label: 'Inserted', value: '${result.inserted}', color: AppColors.success)),
              const SizedBox(width: 12),
              Expanded(child: _ResultStat(label: 'Skipped', value: '${result.skipped}', color: AppColors.warning)),
              const SizedBox(width: 12),
              Expanded(child: _ResultStat(label: 'Errors', value: '${result.errors.length}', color: AppColors.error)),
            ],
          ),
          if (result.errors.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Error Details', style: AppTextStyles.labelLarge),
            const SizedBox(height: 8),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.bgBase,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: result.errors.length,
                itemBuilder: (_, i) => Text(
                  '• ${result.errors[i]}',
                  style: AppTextStyles.monoSmall.copyWith(color: AppColors.warning),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      children: [
        Text(value, style: AppTextStyles.headlineMedium.copyWith(color: color)),
        Text(label, style: AppTextStyles.bodySmall),
      ],
    ),
  );
}

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
      children: [
        const Icon(Icons.error_outline, color: AppColors.error),
        const SizedBox(width: 12),
        Expanded(child: Text(message, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error))),
      ],
    ),
  );
}

class _CsvFormatGuide extends StatelessWidget {
  const _CsvFormatGuide({required this.recordType});
  final String recordType;

  static const _headers = {
    'cdr': 'caller_number, receiver_number, call_time, duration_seconds, call_type, imei_number, cell_id',
    'sdr': 'phone_number, subscriber_name, address, activation_date',
    'tdr': 'cell_id, latitude, longitude, azimuth',
  };

  @override
  Widget build(BuildContext context) {
    final header = _headers[recordType] ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Expected CSV Format',
          subtitle: 'Column names are flexible — common aliases are supported',
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.bgBorder),
          ),
          child: Text(header, style: AppTextStyles.monoSmall.copyWith(color: AppColors.accent)),
        ),
      ],
    );
  }
}
