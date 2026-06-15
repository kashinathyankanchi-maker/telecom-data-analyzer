// lib/screens/search/search_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Feature B: Global Search Screen
// Mobile: filters hidden inside a Drawer
// Desktop: filters visible in a persistent side panel
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../data/models/cdr_model.dart';
import '../../data/models/sdr_model.dart';
import '../../data/repositories/search_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_card.dart';

// ── State ─────────────────────────────────────────────────────────────────────
enum _SearchType { phone, imei }
enum _SearchStatus { idle, loading, done, error }

class _SearchState {
  final _SearchStatus status;
  final _SearchType searchType;
  final String query;
  final SearchResult? phoneResult;
  final ImeiResult? imeiResult;
  final String? error;

  const _SearchState({
    this.status = _SearchStatus.idle,
    this.searchType = _SearchType.phone,
    this.query = '',
    this.phoneResult,
    this.imeiResult,
    this.error,
  });

  _SearchState copyWith({
    _SearchStatus? status,
    _SearchType? searchType,
    String? query,
    SearchResult? phoneResult,
    ImeiResult? imeiResult,
    String? error,
  }) => _SearchState(
    status: status ?? this.status,
    searchType: searchType ?? this.searchType,
    query: query ?? this.query,
    phoneResult: phoneResult ?? this.phoneResult,
    imeiResult: imeiResult ?? this.imeiResult,
    error: error ?? this.error,
  );
}

class _SearchNotifier extends StateNotifier<_SearchState> {
  _SearchNotifier() : super(const _SearchState());
  final _repo = SearchRepository();

  void setType(_SearchType type) => state = state.copyWith(searchType: type);

  Future<void> search(String query) async {
    if (query.trim().isEmpty) return;
    state = state.copyWith(status: _SearchStatus.loading, query: query.trim());
    try {
      if (state.searchType == _SearchType.phone) {
        final result = await _repo.searchByPhone(query.trim());
        state = state.copyWith(status: _SearchStatus.done, phoneResult: result);
      } else {
        final result = await _repo.searchByImei(query.trim());
        state = state.copyWith(status: _SearchStatus.done, imeiResult: result);
      }
    } catch (e) {
      state = state.copyWith(status: _SearchStatus.error, error: e.toString());
    }
  }

  void clear() => state = const _SearchState();
}

final _searchProvider = StateNotifierProvider.autoDispose<_SearchNotifier, _SearchState>(
  (_) => _SearchNotifier(),
);

// ── Screen ────────────────────────────────────────────────────────────────────
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
    final state = ref.watch(_searchProvider);
    final isMobile = Responsive.isMobile(context);

    final filterPanel = _FilterPanel(
      selectedType: state.searchType,
      onTypeChanged: (t) => ref.read(_searchProvider.notifier).setType(t),
      controller: _controller,
      onSearch: _submit,
      onClear: () { _controller.clear(); ref.read(_searchProvider.notifier).clear(); },
    );

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Global Search'),
        actions: [
          // On mobile, open drawer for filters
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Search Filters',
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
          // Desktop: persistent filter panel
          if (!isMobile)
            Container(
              width: 300,
              height: double.infinity,
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: AppColors.bgBorder)),
                color: AppColors.bgSurface,
              ),
              padding: const EdgeInsets.all(20),
              child: filterPanel,
            ),

          // Results area
          Expanded(
            child: _buildResults(context, state),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context, _SearchState state) {
    final padding = Responsive.pagePadding(context);
    switch (state.status) {
      case _SearchStatus.idle:
        return EmptyState(
          icon: Icons.search,
          title: 'Search Telecom Records',
          subtitle: 'Enter a phone number or IMEI to get started',
        );
      case _SearchStatus.loading:
        return const Center(child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppColors.accent),
        ));
      case _SearchStatus.error:
        return EmptyState(
          icon: Icons.error_outline,
          title: 'Search Failed',
          subtitle: state.error,
          action: ElevatedButton(onPressed: _submit, child: const Text('Retry')),
        );
      case _SearchStatus.done:
        if (state.searchType == _SearchType.phone && state.phoneResult != null) {
          return _PhoneResultView(result: state.phoneResult!, padding: padding);
        }
        if (state.searchType == _SearchType.imei && state.imeiResult != null) {
          return _ImeiResultView(result: state.imeiResult!, padding: padding);
        }
        return const EmptyState(icon: Icons.inbox_outlined, title: 'No results');
    }
  }
}

// ── Filter Panel ──────────────────────────────────────────────────────────────
class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.selectedType,
    required this.onTypeChanged,
    required this.controller,
    required this.onSearch,
    required this.onClear,
  });

  final _SearchType selectedType;
  final void Function(_SearchType) onTypeChanged;
  final TextEditingController controller;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SectionHeader(title: 'Search Filters'),
        const SizedBox(height: 24),

        Text('Search Type', style: AppTextStyles.labelLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _TypeChip(label: 'Phone Number', isSelected: selectedType == _SearchType.phone, onTap: () => onTypeChanged(_SearchType.phone))),
            const SizedBox(width: 8),
            Expanded(child: _TypeChip(label: 'IMEI', isSelected: selectedType == _SearchType.imei, onTap: () => onTypeChanged(_SearchType.imei))),
          ],
        ),
        const SizedBox(height: 20),

        Text(selectedType == _SearchType.phone ? 'Phone Number' : 'IMEI Number', style: AppTextStyles.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onSubmitted: (_) => onSearch(),
          keyboardType: selectedType == _SearchType.imei ? TextInputType.number : TextInputType.phone,
          decoration: InputDecoration(
            hintText: selectedType == _SearchType.phone ? '+91XXXXXXXXXX' : '15-digit IMEI',
            prefixIcon: Icon(
              selectedType == _SearchType.phone ? Icons.phone : Icons.smartphone,
              color: AppColors.textMuted, size: 20,
            ),
            suffixIcon: IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: onClear),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onSearch,
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Search'),
          ),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.isSelected, required this.onTap});
  final String label;
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
      child: Center(child: Text(label, style: AppTextStyles.bodySmall.copyWith(
        color: isSelected ? AppColors.accent : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
      ))),
    ),
  );
}

// ── Phone Result View ─────────────────────────────────────────────────────────
class _PhoneResultView extends StatelessWidget {
  const _PhoneResultView({required this.result, required this.padding});
  final SearchResult result;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final s = result.summary;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: padding,
          sliver: SliverList(delegate: SliverChildListDelegate([
            // Subscriber Card
            if (result.subscriber != null) ...[
              _SubscriberCard(subscriber: result.subscriber!),
              const SizedBox(height: 20),
            ],

            // Stats grid
            const SectionHeader(title: 'Call Summary'),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: Responsive.isMobile(context) ? 2 : 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                StatCard(label: 'Total Calls', value: '${s.totalCalls}', icon: Icons.call),
                StatCard(label: 'Total Duration', value: s.formattedTotalDuration, icon: Icons.timer_outlined),
                StatCard(label: 'Unique Contacts', value: '${s.uniqueContacts}', icon: Icons.people_outline, accentColor: AppColors.secondary),
                StatCard(label: 'Towers Used', value: '${s.uniqueTowers}', icon: Icons.cell_tower, accentColor: AppColors.info),
                if (s.firstSeen != null)
                  StatCard(label: 'First Seen', value: DateFormat('dd MMM yy').format(s.firstSeen!), icon: Icons.calendar_today_outlined, accentColor: AppColors.warning),
                if (s.lastSeen != null)
                  StatCard(label: 'Last Seen', value: DateFormat('dd MMM yy').format(s.lastSeen!), icon: Icons.update, accentColor: AppColors.success),
              ],
            ),
            const SizedBox(height: 24),

            // Call log
            SectionHeader(
              title: 'Call Log',
              subtitle: '${result.callLog.length} records',
            ),
            const SizedBox(height: 12),
          ])),
        ),
        SliverPadding(
          padding: padding.copyWith(top: 0),
          sliver: SliverList.builder(
            itemCount: result.callLog.length,
            itemBuilder: (ctx, i) => _CdrRow(cdr: result.callLog[i]),
          ),
        ),
        if (result.callLog.isEmpty)
          SliverFillRemaining(
            child: EmptyState(icon: Icons.call_missed, title: 'No call records found'),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

class _SubscriberCard extends StatelessWidget {
  const _SubscriberCard({required this.subscriber});
  final SdrModel subscriber;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1C2537), Color(0xFF111827)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.bgBorder),
    ),
    child: Row(
      children: [
        Container(
          width: 56, height: 56,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.accent, AppColors.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
            ],
          ),
        ),
      ],
    ),
  );
}

class _CdrRow extends StatelessWidget {
  const _CdrRow({required this.cdr});
  final CdrModel cdr;

  @override
  Widget build(BuildContext context) {
    final isOutgoing = cdr.callType == 'outgoing';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: (isOutgoing ? AppColors.accent : AppColors.secondary).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOutgoing ? Icons.call_made : Icons.call_received,
              size: 18,
              color: isOutgoing ? AppColors.accent : AppColors.secondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isOutgoing ? cdr.receiverNumber : cdr.callerNumber, style: AppTextStyles.labelLarge),
                Text(cdr.formattedTime, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(cdr.formattedDuration, style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent)),
              if (cdr.cellId != null)
                Text(cdr.cellId!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── IMEI Result View ──────────────────────────────────────────────────────────
class _ImeiResultView extends StatelessWidget {
  const _ImeiResultView({required this.result, required this.padding});
  final ImeiResult result;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: padding,
          sliver: SliverList(delegate: SliverChildListDelegate([
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.smartphone, color: AppColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Text('IMEI: ${result.imei}', style: AppTextStyles.labelLarge.copyWith(color: AppColors.warning)),
                  ]),
                  const SizedBox(height: 12),
                  Text('Associated Numbers (${result.associatedNumbers.length})', style: AppTextStyles.bodySmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: result.associatedNumbers.map((n) => Chip(
                      label: Text(n, style: AppTextStyles.bodySmall),
                      avatar: const Icon(Icons.phone, size: 14, color: AppColors.accent),
                    )).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SectionHeader(title: 'Call Log', subtitle: '${result.callLog.length} records'),
            const SizedBox(height: 12),
          ])),
        ),
        SliverPadding(
          padding: padding.copyWith(top: 0),
          sliver: SliverList.builder(
            itemCount: result.callLog.length,
            itemBuilder: (_, i) => _CdrRow(cdr: result.callLog[i]),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}
