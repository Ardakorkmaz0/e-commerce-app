import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:ecommerce_mobile/features/products/data/models/facet_model.dart';
import 'package:ecommerce_mobile/features/products/presentation/providers/product_provider.dart';
import 'package:ecommerce_mobile/shared/widgets/gradient_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mobile equivalent of the web's filter panel. A bottom sheet rather than a
/// sidebar, since a phone has no room for a permanent column.
///
/// Edits are held locally and only written to [productQueryProvider] on
/// "Apply", so the list behind the sheet does not refetch on every tap.
class FilterSheet extends ConsumerStatefulWidget {
  const FilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const FilterSheet(),
    );
  }

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  late ProductQuery _draft;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(productQueryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final facets = ref.watch(facetsProvider(_draft));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Row(
                children: <Widget>[
                  Text(
                    'Filters',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (_draft.hasFilters)
                    TextButton(
                      onPressed: () => setState(() => _draft = _draft.cleared()),
                      child: const Text('Clear all'),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: facets.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) =>
                    const Center(child: Text('Could not load filters.')),
                data: (Facets data) => ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  children: <Widget>[
                    _SortGroup(
                      selected: _draft.sort,
                      onChanged: (value) =>
                          setState(() => _draft = _draft.copyWith(sort: value)),
                    ),

                    if (data.priceRanges.isNotEmpty)
                      _PriceGroup(
                        ranges: data.priceRanges,
                        selected: _draft.priceRange,
                        onChanged: (value) => setState(
                          () => _draft = _draft.copyWith(priceRange: value),
                        ),
                      ),

                    _AvailabilityGroup(
                      counts: data.availability,
                      selected: _draft.availability,
                      onChanged: (value) => setState(
                        () => _draft = _draft.copyWith(availability: value),
                      ),
                    ),

                    for (final facet in data.attributes)
                      _AttributeGroup(
                        facet: facet,
                        query: _draft,
                        onToggle: (valueSlug) => setState(
                          () => _draft =
                              _draft.toggleAttribute(facet.slug, valueSlug),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: GradientButton(
                  label: 'Apply',
                  onPressed: () {
                    ref.read(productQueryProvider.notifier).state = _draft;
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.mutedText,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SortGroup extends StatelessWidget {
  const _SortGroup({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _GroupTitle('Sort'),
        Wrap(
          spacing: 8,
          children: sortOptions.entries.map((entry) {
            final isSelected = selected == entry.key;
            return ChoiceChip(
              label: Text(entry.value),
              selected: isSelected,
              onSelected: (_) => onChanged(entry.key),
              selectedColor: AppColors.primary.withAlpha(30),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : null,
                fontWeight: isSelected ? FontWeight.bold : null,
              ),
            );
          }).toList(),
        ),
        const Divider(height: 24),
      ],
    );
  }
}

class _PriceGroup extends StatelessWidget {
  const _PriceGroup({
    required this.ranges,
    required this.selected,
    required this.onChanged,
  });

  final List<PriceRange> ranges;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _GroupTitle('Price'),
        for (final range in ranges)
          // Radio behaviour: only one price band at a time, and tapping the
          // selected one clears it.
          _FilterRow(
            label: range.label,
            count: range.count,
            selected: selected == range.slug,
            isRadio: true,
            onTap: () => onChanged(selected == range.slug ? '' : range.slug),
          ),
        const Divider(height: 24),
      ],
    );
  }
}

class _AvailabilityGroup extends StatelessWidget {
  const _AvailabilityGroup({
    required this.counts,
    required this.selected,
    required this.onChanged,
  });

  final AvailabilityCounts counts;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <String, ({String label, int count})>{
      'in_stock': (label: 'In stock', count: counts.inStock),
      'low_stock': (label: 'Low stock', count: counts.lowStock),
      'out_of_stock': (label: 'Out of stock', count: counts.outOfStock),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _GroupTitle('Availability'),
        for (final entry in options.entries)
          _FilterRow(
            label: entry.value.label,
            count: entry.value.count,
            selected: selected == entry.key,
            isRadio: true,
            onTap: () => onChanged(selected == entry.key ? '' : entry.key),
          ),
        const Divider(height: 24),
      ],
    );
  }
}

class _AttributeGroup extends StatelessWidget {
  const _AttributeGroup({
    required this.facet,
    required this.query,
    required this.onToggle,
  });

  final Facet facet;
  final ProductQuery query;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _GroupTitle(facet.name),
        for (final value in facet.values)
          _FilterRow(
            label: value.name,
            count: value.count,
            selected: query.isAttributeSelected(facet.slug, value.slug),
            onTap: () => onToggle(value.slug),
          ),
        const Divider(height: 24),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.isRadio = false,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final bool isRadio;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            Icon(
              isRadio
                  ? (selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked)
                  : (selected
                        ? Icons.check_box
                        : Icons.check_box_outline_blank),
              size: 20,
              color: selected ? AppColors.primary : AppColors.border,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.primary : null,
                  fontWeight: selected ? FontWeight.w600 : null,
                ),
              ),
            ),
            Text(
              '$count',
              style: const TextStyle(
                color: AppColors.mutedText,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
