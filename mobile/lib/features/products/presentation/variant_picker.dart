import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:ecommerce_mobile/features/products/data/models/product_model.dart';
import 'package:flutter/material.dart';

/// A selection matches a variant when the two sets of value ids are equal.
///
/// The API sorts `option_value_ids`, so sorting the selection is enough to
/// compare them position by position.
ProductVariant? findVariant(
  List<ProductVariant> variants,
  Map<String, int> selection,
) {
  final chosen = selection.values.toList()..sort();

  for (final variant in variants) {
    if (variant.optionValueIds.length != chosen.length) continue;

    var matches = true;
    for (var index = 0; index < chosen.length; index++) {
      if (variant.optionValueIds[index] != chosen[index]) {
        matches = false;
        break;
      }
    }
    if (matches) return variant;
  }

  return null;
}

/// The combination the page should open on: the first one that can actually
/// be bought, so the shopper sees a real price instead of an empty picker.
Map<String, int> initialSelection(Product product) {
  final first = product.variants.firstWhere(
    (variant) => variant.inStock,
    orElse: () => product.variants.first,
  );

  final selection = <String, int>{};
  for (final group in product.optionGroups) {
    for (final value in group.values) {
      if (first.optionValueIds.contains(value.id)) {
        selection[group.slug] = value.id;
        break;
      }
    }
  }
  return selection;
}

/// Parses "#F8FAFC" into a [Color]; returns null for anything else so the
/// caller can fall back to a plain chip.
Color? parseSwatch(String hex) {
  final value = hex.replaceFirst('#', '');
  if (value.length != 6) return null;
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? null : Color(0xFF000000 | parsed);
}

/// The option rows — colour dots for swatch groups, text chips otherwise.
class VariantOptions extends StatelessWidget {
  const VariantOptions({
    super.key,
    required this.product,
    required this.selection,
    required this.onChanged,
  });

  final Product product;
  final Map<String, int> selection;
  final void Function(String groupSlug, int valueId) onChanged;

  /// Whether picking this value still leads to a variant that is in stock.
  ///
  /// Everything else stays fixed, which is how a shop greys out "US 12"
  /// once you have chosen a colour it is not made in.
  bool _isAvailable(String groupSlug, int valueId) {
    final candidate = Map<String, int>.from(selection)..[groupSlug] = valueId;
    final match = findVariant(product.variants, candidate);
    return match != null && match.inStock;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final group in product.optionGroups) ...<Widget>[
          Text(
            group.name.toUpperCase(),
            style: TextStyle(
              color: context.mutedText,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final value in group.values)
                _OptionButton(
                  value: value,
                  isColour: group.isColour,
                  selected: selection[group.slug] == value.id,
                  available: _isAvailable(group.slug, value.id),
                  // Unavailable combinations stay tappable so the shopper can
                  // pivot to them and see what else changes.
                  onTap: () => onChanged(group.slug, value.id),
                ),
            ],
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.value,
    required this.isColour,
    required this.selected,
    required this.available,
    required this.onTap,
  });

  final OptionValue value;
  final bool isColour;
  final bool selected;
  final bool available;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;

    if (isColour) {
      final swatch = parseSwatch(value.swatchColor) ?? context.borderColor;

      return Tooltip(
        message: available ? value.name : '${value.name} — unavailable',
        child: Opacity(
          opacity: available ? 1 : 0.4,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: swatch,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? accent : context.borderColor,
                  width: selected ? 3 : 1,
                ),
              ),
              // A tick reads on any swatch colour, unlike a coloured outline.
              child: selected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ),
        ),
      );
    }

    return Opacity(
      opacity: available ? 1 : 0.4,
      child: Material(
        color: selected ? accent : context.fieldFill,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? accent : context.borderColor),
            ),
            child: Text(
              value.name,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: FontWeight.w600,
                decoration: available ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
