import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/identification.dart';
import '../../../domain/entities/prediction.dart';
import '../notifiers/history_provider.dart';

// ─── Helpers ────────────────────────────────────────────────────────────────

Prediction? _bestPrediction(Identification id) =>
    id.selectedPrediction ??
    (id.predictions.isNotEmpty ? id.predictions.first : null);

int _confidencePercent(Identification id) {
  final p = _bestPrediction(id);
  if (p == null) return 0;
  final c = p.confidence;
  return (c > 1.0 ? c : c * 100).round();
}

String _statusLabel(int confidence) {
  if (confidence >= 90) return 'Confirmée';
  if (confidence >= 75) return 'Validée';
  return 'En attente';
}

String _locationLabel(Identification id) {
  if (id.location?.address != null && id.location!.address!.isNotEmpty) {
    return id.location!.address!;
  }
  if (id.location != null) {
    final lat = id.location!.latitude.toStringAsFixed(4);
    final lon = id.location!.longitude.toStringAsFixed(4);
    return '$lat, $lon';
  }
  return 'Position inconnue';
}

const _accentColors = [
  AppTheme.secondaryColor,
  AppTheme.accentColor,
  AppTheme.logoBackground,
  AppTheme.primaryColor,
];

// ─── Screen ─────────────────────────────────────────────────────────────────

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  int _selectedFilter = 0;

  static const _filterLabels = [
    'Toutes',
    'Récentes',
    'Haute confiance',
    'GPS activé',
  ];

  List<Identification> _applyFilter(List<Identification> items) {
    switch (_selectedFilter) {
      case 1:
        final cutoff = DateTime.now().subtract(const Duration(days: 7));
        return items.where((i) => i.timestamp.isAfter(cutoff)).toList();
      case 2:
        return items.where((i) => _confidencePercent(i) >= 80).toList();
      case 3:
        return items.where((i) => i.location != null).toList();
      default:
        return items;
    }
  }

  List<_GroupedIdentifications> _groupByDay(List<Identification> items) {
    final sorted = List<Identification>.from(items)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final Map<DateTime, List<Identification>> buckets = {};
    for (final item in sorted) {
      final key = DateTime(
        item.timestamp.year,
        item.timestamp.month,
        item.timestamp.day,
      );
      buckets.putIfAbsent(key, () => []).add(item);
    }
    final entries = buckets.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return entries
        .map((e) => _GroupedIdentifications(date: e.key, items: e.value))
        .toList();
  }

  String _formatSectionDate(DateTime date) {
    const days = [
      'lundi',
      'mardi',
      'mercredi',
      'jeudi',
      'vendredi',
      'samedi',
      'dimanche',
    ];
    const months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    final day = days[(date.weekday - 1).clamp(0, 6)];
    final month = months[date.month - 1];
    return '$day ${date.day} $month';
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(historyNotifierProvider);

    if (historyState.isLoading && historyState.identifications.isEmpty) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.secondaryColor),
        ),
      );
    }

    final filtered = _applyFilter(historyState.identifications);
    final totalObservations = filtered.length;
    final averageConfidence =
        filtered.isEmpty
            ? 0
            : (filtered.fold<int>(0, (s, i) => s + _confidencePercent(i)) /
                    filtered.length)
                .round();
    final distinctLocations =
        filtered
            .where((i) => i.location != null)
            .map((i) {
              final addr = i.location!.address;
              return (addr != null && addr.isNotEmpty)
                  ? addr
                  : '${i.location!.latitude},${i.location!.longitude}';
            })
            .toSet()
            .length;

    final grouped = _groupByDay(filtered);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          const _HistoryBackground(),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                    child: _HistoryHeader(
                      totalObservations: totalObservations,
                      averageConfidence: averageConfidence,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SummaryRow(
                      totalObservations: totalObservations,
                      averageConfidence: averageConfidence,
                      distinctLocations: distinctLocations,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                    child: _FilterChips(
                      chips: _filterLabels,
                      selectedIndex: _selectedFilter,
                      onSelected:
                          (index) =>
                              setState(() => _selectedFilter = index),
                    ),
                  ),
                ),
                if (historyState.error != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: _ErrorBanner(message: historyState.error!),
                    ),
                  ),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    child: _EmptyState(
                      isFiltered: _selectedFilter != 0,
                    ),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final entry = grouped[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: _DaySection(
                            date: entry.date,
                            identifications: entry.items,
                            dateLabel: _formatSectionDate(entry.date),
                          ),
                        );
                      }, childCount: grouped.length),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (Navigator.canPop(context))
            Positioned(
              top: MediaQuery.of(context).padding.top + 6,
              left: 12,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Header ─────────────────────────────────────────────────────────────────

class _HistoryHeader extends StatelessWidget {
  final int totalObservations;
  final int averageConfidence;

  const _HistoryHeader({
    required this.totalObservations,
    required this.averageConfidence,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.98),
            const Color(0xFF3B6D69),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -18,
            right: -12,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -36,
            left: -24,
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppTheme.logoBackground,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.history_toggle_off,
                        color: AppTheme.logoIcon,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Historique',
                            style: Theme.of(
                              context,
                            ).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Retrouve ici toutes tes identifications de plumes.',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.88),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _PillStat(
                      icon: Icons.photo_library_outlined,
                      label: 'Détections',
                      value: '$totalObservations',
                    ),
                    const SizedBox(width: 12),
                    _PillStat(
                      icon: Icons.bolt_outlined,
                      label: 'Confiance moyenne',
                      value: '$averageConfidence%',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PillStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PillStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Summary Row ─────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final int totalObservations;
  final int averageConfidence;
  final int distinctLocations;

  const _SummaryRow({
    required this.totalObservations,
    required this.averageConfidence,
    required this.distinctLocations,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _SummaryItem(
        icon: Icons.insights,
        label: 'Observations',
        value: '$totalObservations',
        color: AppTheme.secondaryColor,
      ),
      _SummaryItem(
        icon: Icons.verified,
        label: 'Fiabilité',
        value: '$averageConfidence%',
        color: AppTheme.accentColor,
      ),
      _SummaryItem(
        icon: Icons.place_outlined,
        label: 'Zones',
        value: '$distinctLocations',
        color: AppTheme.logoBackground,
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(child: items[i]),
          if (i != items.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── Filter Chips ────────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  final List<String> chips;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _FilterChips({
    required this.chips,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final isSelected = selectedIndex == index;
          return ChoiceChip(
            label: Text(chips[index]),
            selected: isSelected,
            onSelected: (_) => onSelected(index),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            selectedColor: AppTheme.secondaryColor,
            backgroundColor: AppTheme.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(
                color:
                    isSelected
                        ? AppTheme.secondaryColor
                        : AppTheme.dividerColor,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Day Section ─────────────────────────────────────────────────────────────

class _DaySection extends StatelessWidget {
  final DateTime date;
  final List<Identification> identifications;
  final String dateLabel;

  const _DaySection({
    required this.date,
    required this.identifications,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppTheme.secondaryColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                dateLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...identifications.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _IdentificationCard(
              identification: entry.value,
              colorIndex: entry.key,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Identification Card ──────────────────────────────────────────────────────

class _IdentificationCard extends StatelessWidget {
  final Identification identification;
  final int colorIndex;

  const _IdentificationCard({
    required this.identification,
    required this.colorIndex,
  });

  @override
  Widget build(BuildContext context) {
    final prediction = _bestPrediction(identification);
    final speciesName = prediction?.speciesName ?? 'Espèce inconnue';
    final scientificName = prediction?.scientificName ?? '';
    final confidence = _confidencePercent(identification);
    final status = _statusLabel(confidence);
    final location = _locationLabel(identification);
    final accentColor = _accentColors[colorIndex % _accentColors.length];
    final note =
        identification.predictions.length > 1
            ? '${identification.predictions.length} espèces analysées · score final ${((prediction?.finalScore ?? 0) * 100).round()}%'
            : 'Identification par analyse d\'image';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CardThumbnail(
                localImagePath: identification.localImagePath,
                accentColor: accentColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  speciesName,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium?.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  scientificName,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _StatusBadge(label: status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        note,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _MetaItem(
                              icon: Icons.schedule,
                              label:
                                  '${identification.timestamp.hour.toString().padLeft(2, '0')}:${identification.timestamp.minute.toString().padLeft(2, '0')}',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetaItem(
                              icon: Icons.place,
                              label: location,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _ConfidenceBar(value: confidence),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardThumbnail extends StatelessWidget {
  final String? localImagePath;
  final Color accentColor;

  const _CardThumbnail({
    required this.localImagePath,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage =
        localImagePath != null && File(localImagePath!).existsSync();

    return Container(
      width: 88,
      color: accentColor.withValues(alpha: 0.14),
      child:
          hasImage
              ? Image.file(
                File(localImagePath!),
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => _FallbackIcon(accentColor: accentColor),
              )
              : _FallbackIcon(accentColor: accentColor),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  final Color accentColor;

  const _FallbackIcon({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: accentColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.flutter_dash, color: Colors.white, size: 26),
      ),
    );
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;

  const _StatusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final isPending = label == 'En attente';
    final color = isPending ? AppTheme.accentColor : AppTheme.secondaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Meta Item ───────────────────────────────────────────────────────────────

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.secondaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Confidence Bar ───────────────────────────────────────────────────────────

class _ConfidenceBar extends StatelessWidget {
  final int value;

  const _ConfidenceBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Confiance',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$value%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 8,
              backgroundColor: AppTheme.dividerColor,
              valueColor: AlwaysStoppedAnimation<Color>(
                value >= 90 ? AppTheme.secondaryColor : AppTheme.accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error Banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isFiltered;

  const _EmptyState({required this.isFiltered});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_toggle_off,
                color: AppTheme.secondaryColor,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isFiltered ? 'Aucun résultat' : 'Aucune identification',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? 'Essaie un autre filtre.'
                  : 'Identifie ta première plume depuis l\'accueil.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Background ──────────────────────────────────────────────────────────────

class _HistoryBackground extends StatelessWidget {
  const _HistoryBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -40,
            child: _SoftOrb(
              color: AppTheme.secondaryColor.withValues(alpha: 0.18),
              size: 180,
            ),
          ),
          Positioned(
            top: 140,
            left: -50,
            child: _SoftOrb(
              color: AppTheme.accentColor.withValues(alpha: 0.12),
              size: 140,
            ),
          ),
          Positioned(
            bottom: 80,
            right: -30,
            child: _SoftOrb(
              color: Colors.white.withValues(alpha: 0.05),
              size: 120,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _SoftOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ─── Data Models ─────────────────────────────────────────────────────────────

class _GroupedIdentifications {
  final DateTime date;
  final List<Identification> items;

  const _GroupedIdentifications({required this.date, required this.items});
}
