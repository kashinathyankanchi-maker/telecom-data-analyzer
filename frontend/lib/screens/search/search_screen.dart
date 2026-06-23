// lib/screens/search/search_screen.dart
// Search CDR/SDR data and display analytics charts.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../data/models/cdr_model.dart';
import '../../data/models/sdr_model.dart';
import '../../providers/data_store.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_card.dart';

// ── State ──────────────────────────────────────────────────────────────────────
enum _SearchType { phone, imei }
enum _SearchStatus { idle, loading, done, empty, error }

class _SearchState {
  final _SearchType type;
  final _SearchStatus status;
  final String query;
  final String? error;
  // Phone results
  final SdrModel? subscriber;
  final List<CdrModel> callLog;
  final CdrSummary? summary;
  // IMEI results
  final List<CdrModel> imeiLog;
  // Filters
  final DateTime? fromDate;
  final DateTime? toDate;
  final int minDuration;
  final int maxDuration;

  const _SearchState({
    this.type = _SearchType.phone,
    this.status = _SearchStatus.idle,
    this.query = '',
    this.error,
    this.subscriber,
    this.callLog = const [],
    this.summary,
    this.imeiLog = const [],
    this.fromDate,
    this.toDate,
    this.minDuration = 0,
    this.maxDuration = 9999,
  });

  _SearchState copyWith({
    _SearchType? type,
    _SearchStatus? status,
    String? query,
    String? error,
    SdrModel? subscriber,
    List<CdrModel>? callLog,
    CdrSummary? summary,
    List<CdrModel>? imeiLog,
    DateTime? fromDate,
    DateTime? toDate,
    int? minDuration,
    int? maxDuration,
  }) => _SearchState(
    type: type ?? this.type,
    status: status ?? this.status,
    query: query ?? this.query,
    error: error ?? this.error,
    subscriber: subscriber ?? this.subscriber,
    callLog: callLog ?? this.callLog,
    summary: summary ?? this.summary,
    imeiLog: imeiLog ?? this.imeiLog,
    fromDate: fromDate ?? this.fromDate,
    toDate: toDate ?? this.toDate,
    minDuration: minDuration ?? this.minDuration,
    maxDuration: maxDuration ?? this.maxDuration,
  );

  List<CdrModel> get filteredLog {
    final base = type == _SearchType.phone ? callLog : imeiLog;
    return base.where((c) {
      if (fromDate != null && c.callTime.isBefore(fromDate!)) return false;
      if (toDate != null && c.callTime.isAfter(toDate!.add(const Duration(days: 1)))) return false;
      if (c.durationSeconds < minDuration) return false;
      if (c.durationSeconds > maxDuration) return false;
      return true;
    }).toList();
  }
}

class _SearchNotifier extends StateNotifier<_SearchState> {
  final Ref _ref;
  _SearchNotifier(this._ref) : super(const _SearchState());

  void setType(_SearchType t) => state = state.copyWith(type: t);

  Future<void> search(String q) async {
    if (q.trim().isEmpty) return;
    state = state.copyWith(status: _SearchStatus.loading, query: q.trim());
    try {
      if (state.type == _SearchType.phone) {
        final result = await _ref.read(phoneSearchProvider(q.trim()).future);
        if (result.isEmpty) {
          state = state.copyWith(status: _SearchStatus.empty);
          return;
        }
        final summary = CdrSummary.fromCallLog(q.trim(), result.callLog);
        state = state.copyWith(
          status: _SearchStatus.done,
          subscriber: result.subscriber,
          callLog: result.callLog,
          summary: summary,
        );
      } else {
        final log = await _ref.read(imeiSearchProvider(q.trim()).future);
        if (log.isEmpty) {
          state = state.copyWith(status: _SearchStatus.empty);
          return;
        }
        state = state.copyWith(status: _SearchStatus.done, imeiLog: log);
      }
    } catch (e) {
      state = state.copyWith(status: _SearchStatus.error, error: e.toString());
    }
  }

  void clear() => state = const _SearchState();

  void setDateRange(DateTime? from, DateTime? to) =>
      state = state.copyWith(fromDate: from, toDate: to);

  void setDurationRange(int min, int max) =>
      state = state.copyWith(minDuration: min, maxDuration: max);
}

final _searchProvider = StateNotifierProvider.autoDispose<_SearchNotifier, _SearchState>(
  (ref) => _SearchNotifier(ref),
);

// ── Screen ─────────────────────────────────────────────────────────────────────
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final q = _controller.text.trim();
    if (q.isNotEmpty) {
      ref.read(_searchProvider.notifier).search(q);
      if (Responsive.isMobile(context)) _scaffoldKey.currentState?.closeDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state   = ref.watch(_searchProvider);
    final isMobile= Responsive.isMobile(context);

    final filterPanel = _FilterPanel(
      state: state,
      controller: _controller,
      onTypeChanged: (t) => ref.read(_searchProvider.notifier).setType(t),
      onSearch: _submit,
      onClear: () { _controller.clear(); ref.read(_searchProvider.notifier).clear(); },
      onDateRange: (f, t) => ref.read(_searchProvider.notifier).setDateRange(f, t),
    );

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Search & Analytics'),
        actions: [
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Filters',
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: isMobile
          ? Drawer(
              backgroundColor: AppColors.bgSurface,
              child: SafeArea(child: Padding(
                padding: const EdgeInsets.all(20),
                child: filterPanel,
              )),
            )
          : null,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMobile)
            Container(
              width: 300,
              height: double.infinity,
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: AppColors.bgBorder)),
                color: AppColors.bgSurface,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: filterPanel,
              ),
            ),
          Expanded(child: _buildResults(context, state)),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context, _SearchState state) {
    switch (state.status) {
      case _SearchStatus.idle:
        return const EmptyState(
          icon: Icons.search,
          title: 'Search Telecom Records',
          subtitle: 'Enter a phone number or IMEI to analyse the data',
        );
      case _SearchStatus.loading:
        return const Center(child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppColors.accent),
        ));
      case _SearchStatus.empty:
        return EmptyState(
          icon: Icons.inbox_outlined,
          title: 'No Records Found',
          subtitle: 'No data for "${state.query}" in the database.\nImport CDR/SDR files first.',
        );
      case _SearchStatus.error:
        return EmptyState(
          icon: Icons.error_outline,
          title: 'Search Error',
          subtitle: state.error,
          action: ElevatedButton(onPressed: _submit, child: const Text('Retry')),
        );
      case _SearchStatus.done:
        if (state.type == _SearchType.imei) {
          return _ImeiView(log: state.filteredLog, imei: state.query);
        }
        return _PhoneAnalyticsView(state: state);
    }
  }
}

// ── Filter Panel ───────────────────────────────────────────────────────────────
class _FilterPanel extends StatefulWidget {
  const _FilterPanel({
    required this.state,
    required this.controller,
    required this.onTypeChanged,
    required this.onSearch,
    required this.onClear,
    required this.onDateRange,
  });
  final _SearchState state;
  final TextEditingController controller;
  final void Function(_SearchType) onTypeChanged;
  final VoidCallback onSearch, onClear;
  final void Function(DateTime?, DateTime?) onDateRange;

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SectionHeader(title: 'Search'),
        const SizedBox(height: 20),
        Text('Search Type', style: AppTextStyles.labelLarge),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _TypeChip(
            label: 'Phone Number', icon: Icons.phone,
            isSelected: state.type == _SearchType.phone,
            onTap: () => widget.onTypeChanged(_SearchType.phone),
          )),
          const SizedBox(width: 8),
          Expanded(child: _TypeChip(
            label: 'IMEI', icon: Icons.smartphone,
            isSelected: state.type == _SearchType.imei,
            onTap: () => widget.onTypeChanged(_SearchType.imei),
          )),
        ]),
        const SizedBox(height: 16),
        Text(state.type == _SearchType.phone ? 'Phone Number' : 'IMEI Number',
          style: AppTextStyles.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: widget.controller,
          onSubmitted: (_) => widget.onSearch(),
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: state.type == _SearchType.phone ? 'e.g. 9876543210' : '15-digit IMEI',
            prefixIcon: Icon(
              state.type == _SearchType.phone ? Icons.phone : Icons.smartphone,
              color: AppColors.textMuted, size: 20,
            ),
            suffixIcon: IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: widget.onClear),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: widget.onSearch,
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Search & Analyse'),
          ),
        ),

        if (state.status == _SearchStatus.done) ...[
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 16),
          Text('Date Filter', style: AppTextStyles.labelLarge),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _DateButton(
              label: state.fromDate != null ? DateFormat('dd MMM yy').format(state.fromDate!) : 'From',
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: state.fromDate ?? DateTime.now().subtract(const Duration(days: 30)),
                  firstDate: DateTime(2000), lastDate: DateTime.now(),
                );
                if (d != null) widget.onDateRange(d, state.toDate);
              },
            )),
            const SizedBox(width: 8),
            Expanded(child: _DateButton(
              label: state.toDate != null ? DateFormat('dd MMM yy').format(state.toDate!) : 'To',
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: state.toDate ?? DateTime.now(),
                  firstDate: DateTime(2000), lastDate: DateTime.now(),
                );
                if (d != null) widget.onDateRange(state.fromDate, d);
              },
            )),
          ]),
          if (state.fromDate != null || state.toDate != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => widget.onDateRange(null, null),
              child: const Text('Clear Date Filter'),
            ),
          ],
        ],
      ],
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 12),
      side: const BorderSide(color: AppColors.bgBorder),
    ),
    child: Text(label, style: AppTextStyles.bodySmall),
  );
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.icon, required this.isSelected, required this.onTap});
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.accentGlow : AppColors.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isSelected ? AppColors.accent : AppColors.bgBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? AppColors.accent : AppColors.textMuted),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.bodySmall.copyWith(
            color: isSelected ? AppColors.accent : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ), textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

// ── Phone Analytics View ───────────────────────────────────────────────────────
class _PhoneAnalyticsView extends StatelessWidget {
  const _PhoneAnalyticsView({required this.state});
  final _SearchState state;

  @override
  Widget build(BuildContext context) {
    final filtered = state.filteredLog;
    final recomputedSummary = CdrSummary.fromCallLog(state.query, filtered);
    final padding  = Responsive.pagePadding(context);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: padding,
          sliver: SliverList(delegate: SliverChildListDelegate([
            const SizedBox(height: 8),

            // Subscriber card
            if (state.subscriber != null) ...[
              _SubscriberCard(subscriber: state.subscriber!),
              const SizedBox(height: 20),
            ],

            // Summary stats
            const SectionHeader(title: 'Call Summary'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12, runSpacing: 12,
              children: [
                StatCard(label: 'Total Calls', value: '${recomputedSummary.totalCalls}', icon: Icons.call),
                StatCard(label: 'Total Duration', value: recomputedSummary.formattedTotalDuration, icon: Icons.timer_outlined),
                StatCard(label: 'Unique Contacts', value: '${recomputedSummary.uniqueContacts}', icon: Icons.people_outline, accentColor: AppColors.secondary),
                StatCard(label: 'Towers Used', value: '${recomputedSummary.uniqueTowers}', icon: Icons.cell_tower, accentColor: AppColors.info),
                StatCard(label: 'Incoming', value: '${recomputedSummary.incoming}', icon: Icons.call_received, accentColor: AppColors.success),
                StatCard(label: 'Outgoing', value: '${recomputedSummary.outgoing}', icon: Icons.call_made, accentColor: AppColors.warning),
              ],
            ),
            const SizedBox(height: 28),

            // Charts row
            LayoutBuilder(builder: (ctx, constraints) {
              final isWide = constraints.maxWidth > 700;
              final charts = [
                _CallsPerDayChart(perDay: recomputedSummary.callsPerDay),
                _InOutPieChart(incoming: recomputedSummary.incoming, outgoing: recomputedSummary.outgoing),
                _HourlyHeatChart(perHour: recomputedSummary.callsPerHour),
                _TopContactsChart(topContacts: recomputedSummary.topContacts),
              ];
              if (isWide) {
                return Column(children: [
                  Row(children: [
                    Expanded(child: charts[0]),
                    const SizedBox(width: 16),
                    Expanded(child: charts[1]),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: charts[2]),
                    const SizedBox(width: 16),
                    Expanded(child: charts[3]),
                  ]),
                ]);
              }
              return Column(children: charts.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 16), child: c,
              )).toList());
            }),
            const SizedBox(height: 24),

            // Call log
            SectionHeader(
              title: 'Call Log',
              subtitle: '${filtered.length} records${filtered.length != state.callLog.length ? ' (filtered)' : ''}',
            ),
            const SizedBox(height: 8),
          ])),
        ),
        SliverPadding(
          padding: padding.copyWith(top: 0),
          sliver: SliverList.builder(
            itemCount: filtered.length,
            itemBuilder: (ctx, i) => _CdrRow(cdr: filtered[i], searchPhone: state.query),
          ),
        ),
        if (filtered.isEmpty)
          const SliverFillRemaining(
            child: EmptyState(icon: Icons.call_missed, title: 'No records match the current filters'),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

// ── Charts ─────────────────────────────────────────────────────────────────────
class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child, this.height = 200});
  final String title;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.bgBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.labelLarge),
        const SizedBox(height: 12),
        SizedBox(height: height, child: child),
      ],
    ),
  );
}

class _CallsPerDayChart extends StatelessWidget {
  const _CallsPerDayChart({required this.perDay});
  final Map<String, int> perDay;

  @override
  Widget build(BuildContext context) {
    if (perDay.isEmpty) return _ChartCard(title: 'Calls Per Day', child: const EmptyState(icon: Icons.bar_chart, title: 'No data'));

    final sorted = perDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final maxY   = (sorted.map((e) => e.value).reduce((a, b) => a > b ? a : b)).toDouble();

    return _ChartCard(
      title: 'Calls Per Day',
      child: BarChart(BarChartData(
        maxY: maxY + 2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 28,
            getTitlesWidget: (val, meta) {
              final idx = val.toInt();
              if (idx < 0 || idx >= sorted.length) return const SizedBox.shrink();
              final date = sorted[idx].key;
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(date.substring(5), // MM-DD
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 9),
                  textAlign: TextAlign.center,
                ),
              );
            },
          )),
        ),
        barGroups: sorted.asMap().entries.map((entry) => BarChartGroupData(
          x: entry.key,
          barRods: [BarChartRodData(
            toY: entry.value.value.toDouble(),
            color: AppColors.accent,
            width: (200 / sorted.length).clamp(4.0, 20.0),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          )],
        )).toList(),
      )),
    );
  }
}

class _InOutPieChart extends StatelessWidget {
  const _InOutPieChart({required this.incoming, required this.outgoing});
  final int incoming, outgoing;

  @override
  Widget build(BuildContext context) {
    final total = incoming + outgoing;
    if (total == 0) return _ChartCard(title: 'Incoming vs Outgoing', child: const EmptyState(icon: Icons.pie_chart, title: 'No data'));

    return _ChartCard(
      title: 'Incoming vs Outgoing',
      child: Row(children: [
        Expanded(
          child: PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 30,
            sections: [
              PieChartSectionData(
                value: incoming.toDouble(),
                color: AppColors.success,
                title: '$incoming',
                titleStyle: AppTextStyles.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                radius: 60,
              ),
              PieChartSectionData(
                value: outgoing.toDouble(),
                color: AppColors.accent,
                title: '$outgoing',
                titleStyle: AppTextStyles.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                radius: 60,
              ),
            ],
          )),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Legend(color: AppColors.success, label: 'Incoming', value: incoming),
            const SizedBox(height: 8),
            _Legend(color: AppColors.accent, label: 'Outgoing', value: outgoing),
          ],
        ),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, required this.value});
  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 6),
    Text('$label: $value', style: AppTextStyles.bodySmall),
  ]);
}

class _HourlyHeatChart extends StatelessWidget {
  const _HourlyHeatChart({required this.perHour});
  final Map<int, int> perHour;

  @override
  Widget build(BuildContext context) {
    if (perHour.isEmpty) return _ChartCard(title: 'Calls by Hour of Day', child: const EmptyState(icon: Icons.access_time, title: 'No data'));

    final maxY = (perHour.values.isEmpty ? 1 : perHour.values.reduce((a, b) => a > b ? a : b)).toDouble();

    return _ChartCard(
      title: 'Calls by Hour of Day',
      child: BarChart(BarChartData(
        maxY: maxY + 1,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 24,
            getTitlesWidget: (val, meta) {
              final h = val.toInt();
              if (h % 6 != 0) return const SizedBox.shrink();
              return Text('${h}h', style: AppTextStyles.bodySmall.copyWith(fontSize: 9));
            },
          )),
        ),
        barGroups: List.generate(24, (h) => BarChartGroupData(
          x: h,
          barRods: [BarChartRodData(
            toY: (perHour[h] ?? 0).toDouble(),
            color: _hourColor(h),
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          )],
        )),
      )),
    );
  }

  Color _hourColor(int hour) {
    if (hour >= 22 || hour < 6)  return AppColors.secondary;   // Night
    if (hour >= 6  && hour < 12) return AppColors.success;     // Morning
    if (hour >= 12 && hour < 17) return AppColors.accent;      // Afternoon
    return AppColors.warning;                                   // Evening
  }
}

class _TopContactsChart extends StatelessWidget {
  const _TopContactsChart({required this.topContacts});
  final Map<String, int> topContacts;

  @override
  Widget build(BuildContext context) {
    if (topContacts.isEmpty) return _ChartCard(title: 'Top Contacts', child: const EmptyState(icon: Icons.people, title: 'No data'));

    final entries = topContacts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxVal  = entries.first.value.toDouble();

    return _ChartCard(
      title: 'Top ${entries.length} Contacts',
      height: entries.length * 44.0 + 16,
      child: Column(
        children: entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            SizedBox(
              width: 100,
              child: Text(e.key, style: AppTextStyles.bodySmall, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: e.value / maxVal,
                  backgroundColor: AppColors.bgElevated,
                  valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                  minHeight: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('${e.value}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent)),
          ]),
        )).toList(),
      ),
    );
  }
}

// ── Subscriber Card ────────────────────────────────────────────────────────────
class _SubscriberCard extends StatelessWidget {
  const _SubscriberCard({required this.subscriber});
  final SdrModel subscriber;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1C2537), Color(0xFF111827)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.bgBorder),
    ),
    child: Row(children: [
      Container(
        width: 56, height: 56,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.accent, AppColors.secondary]),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            (subscriber.displayName.isNotEmpty ? subscriber.displayName[0] : '?').toUpperCase(),
            style: AppTextStyles.headlineMedium.copyWith(color: Colors.white),
          ),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(subscriber.displayName, style: AppTextStyles.titleLarge),
        const SizedBox(height: 4),
        Text(subscriber.phoneNumber, style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent)),
        if (subscriber.address != null) ...[
          const SizedBox(height: 4),
          Text(subscriber.address!, style: AppTextStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
        if (subscriber.formattedActivationDate != null) ...[
          const SizedBox(height: 4),
          Text('Activated: ${subscriber.formattedActivationDate}', style: AppTextStyles.bodySmall),
        ],
      ])),
    ]),
  );
}

// ── CDR Row ────────────────────────────────────────────────────────────────────
class _CdrRow extends StatelessWidget {
  const _CdrRow({required this.cdr, required this.searchPhone});
  final CdrModel cdr;
  final String searchPhone;

  @override
  Widget build(BuildContext context) {
    final isOut = cdr.callerNumber == searchPhone;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.bgBorder),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: (isOut ? AppColors.accent : AppColors.success).withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isOut ? Icons.call_made : Icons.call_received,
            size: 16, color: isOut ? AppColors.accent : AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isOut ? cdr.receiverNumber : cdr.callerNumber, style: AppTextStyles.labelLarge),
          Text(cdr.formattedTime, style: AppTextStyles.bodySmall),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(cdr.formattedDuration, style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent)),
          if (cdr.cellId != null)
            Text(cdr.cellId!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 10)),
        ]),
      ]),
    );
  }
}

// ── IMEI View ──────────────────────────────────────────────────────────────────
class _ImeiView extends StatelessWidget {
  const _ImeiView({required this.log, required this.imei});
  final List<CdrModel> log;
  final String imei;

  @override
  Widget build(BuildContext context) {
    final phones = log.map((c) => c.callerNumber).toSet()
      ..addAll(log.map((c) => c.receiverNumber));

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: Responsive.pagePadding(context),
          sliver: SliverList(delegate: SliverChildListDelegate([
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.smartphone, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Text('IMEI: $imei', style: AppTextStyles.labelLarge.copyWith(color: AppColors.warning)),
                ]),
                const SizedBox(height: 12),
                Text('Associated Phone Numbers (${phones.length})', style: AppTextStyles.bodySmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 6,
                  children: phones.map((n) => Chip(
                    label: Text(n, style: AppTextStyles.bodySmall),
                    avatar: const Icon(Icons.phone, size: 14, color: AppColors.accent),
                  )).toList(),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            SectionHeader(title: 'Call Log', subtitle: '${log.length} records'),
            const SizedBox(height: 8),
          ])),
        ),
        SliverPadding(
          padding: Responsive.pagePadding(context).copyWith(top: 0),
          sliver: SliverList.builder(
            itemCount: log.length,
            itemBuilder: (_, i) => _CdrRow(cdr: log[i], searchPhone: log[i].callerNumber),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}
