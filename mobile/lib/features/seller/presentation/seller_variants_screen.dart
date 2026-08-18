import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:ecommerce_mobile/features/products/data/models/product_model.dart';
import 'package:ecommerce_mobile/features/products/presentation/providers/product_provider.dart';
import 'package:ecommerce_mobile/features/products/presentation/variant_picker.dart';
import 'package:ecommerce_mobile/features/seller/data/models/seller_variant_model.dart';
import 'package:ecommerce_mobile/features/seller/data/seller_variant_repository.dart';
import 'package:ecommerce_mobile/features/seller/presentation/providers/seller_variant_provider.dart';
import 'package:ecommerce_mobile/shared/widgets/gradient_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Web equivalent: `/seller/<slug>/variants`
class SellerVariantsScreen extends ConsumerWidget {
  const SellerVariantsScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(sellerProductProvider(slug));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed('sellerProducts');
            }
          },
        ),
        title: const Text(
          'Variants',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: product.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Could not load this product.')),
        data: (Product item) => _VariantsBody(slug: slug, product: item),
      ),
    );
  }
}

class _VariantsBody extends ConsumerWidget {
  const _VariantsBody({required this.slug, required this.product});

  final String slug;
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variants = ref.watch(sellerVariantsProvider(slug));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(sellerVariantsProvider(slug)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          Text(
            product.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'A product with variants is bought as one of them, so the '
            "variant's price, stock and picture take over. Leave a price or "
            "description empty to keep using the product's.",
            style: TextStyle(color: context.mutedText, height: 1.5),
          ),
          const SizedBox(height: 20),

          _GeneratorPanel(slug: slug, product: product),
          const SizedBox(height: 20),

          variants.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, _) => Text(
              describeVariantError(error),
              style: const TextStyle(color: Color(0xFFB91C1C)),
            ),
            data: (List<SellerVariant> items) {
              if (items.isEmpty) {
                return Text(
                  'This product has no variants yet. It is sold on its own '
                  'at ${product.formattedPrice} with ${product.stock} in stock.',
                  style: TextStyle(color: context.mutedText),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${items.length} variant${items.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  for (final variant in items)
                    _VariantRow(
                      slug: slug,
                      variant: variant,
                      productPrice: product.price,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// "Tick what it comes in, get every combination."
///
/// Typing a shoe's 5 sizes x 3 colours by hand is 15 rows, so the seller
/// picks values and the server builds the grid. Running it again after
/// adding one more colour only creates the rows that are missing.
class _GeneratorPanel extends ConsumerStatefulWidget {
  const _GeneratorPanel({required this.slug, required this.product});

  final String slug;
  final Product product;

  @override
  ConsumerState<_GeneratorPanel> createState() => _GeneratorPanelState();
}

class _GeneratorPanelState extends ConsumerState<_GeneratorPanel> {
  final Set<int> _selected = <int>{};
  bool _busy = false;

  /// Rows the current ticks would produce: the counts per attribute
  /// multiplied together, ignoring attributes with nothing ticked.
  int _combinations(List<SellerAttribute> attributes) {
    var total = 1;
    var used = false;
    for (final attribute in attributes) {
      final count = attribute.values
          .where((value) => _selected.contains(value.id))
          .length;
      if (count > 0) {
        total *= count;
        used = true;
      }
    }
    return used ? total : 0;
  }

  /// Asks for a name (and a group name when [attribute] is null), then
  /// sends it. The list rebuilds from the server so the new chip carries
  /// the id the generator needs.
  Future<void> _addOption({SellerAttribute? attribute}) async {
    final result = await showDialog<_NewOption>(
      context: context,
      builder: (_) => _NewOptionDialog(attribute: attribute),
    );
    if (result == null) return;

    try {
      final created = await ref
          .read(sellerVariantRepositoryProvider)
          .addOption(
            widget.slug,
            attributeId: attribute?.id,
            attributeName: result.groupName,
            name: result.name,
            swatchColor: result.swatchColor,
          );

      ref.invalidate(sellerAttributesProvider);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            created
                ? 'Added "${result.name}".'
                : '"${result.name}" already existed.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeVariantError(error))));
    }
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    try {
      final created = await ref
          .read(sellerVariantRepositoryProvider)
          .generate(widget.slug, _selected.toList());

      ref.invalidate(sellerVariantsProvider(widget.slug));
      if (!mounted) return;

      setState(_selected.clear);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            created == 0
                ? 'Every combination already exists.'
                : 'Added $created variant${created == 1 ? '' : 's'}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeVariantError(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final attributes = ref.watch(sellerAttributesProvider);

    return attributes.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => Text(
        'Could not load the options.',
        style: TextStyle(color: context.mutedText),
      ),
      data: (List<SellerAttribute> all) {
        // Only the options that apply to this product's category.
        final relevant = all
            .where(
              (attribute) =>
                  attribute.categoryIds.contains(widget.product.categoryId),
            )
            .toList();

        if (relevant.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.controlBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'This category has no options yet. An administrator can add '
              'them under Attributes.',
              style: TextStyle(color: context.mutedText),
            ),
          );
        }

        final willCreate = _combinations(relevant);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.controlBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Build combinations',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              for (final attribute in relevant) ...<Widget>[
                Text(
                  attribute.name.toUpperCase(),
                  style: TextStyle(
                    color: context.mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final value in attribute.values)
                      FilterChip(
                        label: Text(value.name),
                        avatar: parseSwatch(value.swatchColor) == null
                            ? null
                            : CircleAvatar(
                                backgroundColor: parseSwatch(value.swatchColor),
                              ),
                        selected: _selected.contains(value.id),
                        onSelected: (on) => setState(() {
                          if (on) {
                            _selected.add(value.id);
                          } else {
                            _selected.remove(value.id);
                          }
                        }),
                      ),
                    // Lets the seller type an option nobody has entered
                    // yet, e.g. one more size.
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: Text('Add ${attribute.name.toLowerCase()}'),
                      onPressed: () => _addOption(attribute: attribute),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('New option group'),
                  onPressed: () => _addOption(),
                ),
              ),
              const SizedBox(height: 14),

              GradientButton(
                label: _busy
                    ? 'Building...'
                    : willCreate == 0
                    ? 'Tick some options'
                    : 'Build $willCreate combination'
                          '${willCreate == 1 ? '' : 's'}',
                onPressed: _busy || willCreate == 0 ? null : _generate,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VariantRow extends ConsumerWidget {
  const _VariantRow({
    required this.slug,
    required this.variant,
    required this.productPrice,
  });

  final String slug;
  final SellerVariant variant;
  final String productPrice;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete variant?'),
        content: Text('"${variant.optionLabel}" will no longer be for sale.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(sellerVariantRepositoryProvider)
          .remove(slug, variant.id);
      ref.invalidate(sellerVariantsProvider(slug));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeVariantError(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = variant.price == null
        ? '${_money(productPrice)} (product price)'
        : _money(variant.price!);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 52,
            height: 52,
            color: AppColors.primary.withAlpha(20),
            child: variant.imageDisplay.isEmpty
                ? Icon(
                    Icons.image_outlined,
                    color: AppColors.primary.withAlpha(100),
                  )
                : Image.network(
                    variant.imageDisplay,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.image_not_supported_outlined,
                      color: AppColors.primary.withAlpha(100),
                    ),
                  ),
          ),
        ),
        title: Text(
          variant.optionLabel,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: <Widget>[
            Flexible(
              child: Text(
                price,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.mutedText, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Stock ${variant.stock}',
              style: TextStyle(color: context.mutedText, fontSize: 12),
            ),
            if (!variant.isActive) ...<Widget>[
              const SizedBox(width: 8),
              const Text(
                'Hidden',
                style: TextStyle(
                  color: Color(0xFFB91C1C),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _confirmDelete(context, ref),
        ),
        // A phone has no room for the whole form inline, so the row opens
        // it instead of trying to squeeze five fields into a card.
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => VariantEditSheet(
            slug: slug,
            variant: variant,
            productPrice: productPrice,
          ),
        ),
      ),
    );
  }
}

String _money(String amount) {
  final value = double.tryParse(amount);
  return value == null ? amount : '\$${value.toStringAsFixed(2)}';
}

/// Price, stock, picture, description and visibility for one variant.
class VariantEditSheet extends ConsumerStatefulWidget {
  const VariantEditSheet({
    super.key,
    required this.slug,
    required this.variant,
    required this.productPrice,
  });

  final String slug;
  final SellerVariant variant;
  final String productPrice;

  @override
  ConsumerState<VariantEditSheet> createState() => _VariantEditSheetState();
}

class _VariantEditSheetState extends ConsumerState<VariantEditSheet> {
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _imageUrl;
  late final TextEditingController _description;
  late bool _isActive;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _price = TextEditingController(text: widget.variant.price ?? '');
    _stock = TextEditingController(text: '${widget.variant.stock}');
    _imageUrl = TextEditingController(text: widget.variant.imageUrl);
    _description = TextEditingController(text: widget.variant.description);
    _isActive = widget.variant.isActive;
  }

  @override
  void dispose() {
    _price.dispose();
    _stock.dispose();
    _imageUrl.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final stock = int.tryParse(_stock.text.trim());
    if (stock == null || stock < 0) {
      setState(() => _error = 'Stock must be zero or more.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref
          .read(sellerVariantRepositoryProvider)
          .update(
            widget.slug,
            widget.variant.id,
            // Empty means "same as the product", which travels as null.
            price: _price.text.trim().isEmpty ? null : _price.text.trim(),
            stock: stock,
            description: _description.text.trim(),
            imageUrl: _imageUrl.text.trim(),
            isActive: _isActive,
          );

      ref.invalidate(sellerVariantsProvider(widget.slug));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = describeVariantError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lifts the sheet above the keyboard rather than hiding the fields.
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.variant.optionLabel,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Price',
                hintText: widget.productPrice,
                helperText: 'Empty = product price',
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _stock,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Stock'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _imageUrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Image URL',
                hintText: 'https://...',
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                helperText: 'Empty = product description',
              ),
            ),
            const SizedBox(height: 8),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Visible to shoppers'),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),

            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFB91C1C)),
              ),
            ],

            const SizedBox(height: 16),
            GradientButton(
              label: _saving ? 'Saving...' : 'Save',
              onPressed: _saving ? null : _save,
            ),
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the "+" dialog hands back.
class _NewOption {
  const _NewOption({
    required this.groupName,
    required this.name,
    required this.swatchColor,
  });

  /// Empty when the option joins an existing group.
  final String groupName;

  final String name;

  /// Empty unless the seller picked a colour, in which case the value
  /// renders as a dot on both the seller's and the shopper's picker.
  final String swatchColor;
}

class _NewOptionDialog extends StatefulWidget {
  const _NewOptionDialog({this.attribute});

  /// Null means the seller is starting a whole new group.
  final SellerAttribute? attribute;

  @override
  State<_NewOptionDialog> createState() => _NewOptionDialogState();
}

class _NewOptionDialogState extends State<_NewOptionDialog> {
  final _group = TextEditingController();
  final _name = TextEditingController();

  /// A short palette beats a colour wheel here: these are the swatches the
  /// storefront already uses, and one tap is enough.
  static const _palette = <String>[
    '#111827',
    '#F8FAFC',
    '#DC2626',
    '#2563EB',
    '#16A34A',
    '#F59E0B',
    '#7C3AED',
    '#EC4899',
  ];

  bool _useColour = false;
  String _colour = _palette.first;

  @override
  void initState() {
    super.initState();
    // A group already drawn as swatches almost certainly wants another.
    _useColour =
        widget.attribute?.values.any((value) => value.swatchColor.isNotEmpty) ??
        false;
  }

  @override
  void dispose() {
    _group.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attribute = widget.attribute;

    return AlertDialog(
      title: Text(
        attribute == null ? 'New option group' : 'Add ${attribute.name}',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (attribute == null) ...<Widget>[
              TextField(
                controller: _group,
                autofocus: true,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Group name',
                  hintText: 'e.g. Bundle',
                ),
                // Both fields gate the Add button, so both have to rebuild.
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
            ],

            TextField(
              controller: _name,
              autofocus: attribute != null,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: attribute == null ? 'First option' : 'Option',
                hintText: attribute == null ? 'e.g. With game' : 'e.g. 45',
              ),
              onChanged: (_) => setState(() {}),
            ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show as a colour'),
              value: _useColour,
              onChanged: (value) => setState(() => _useColour = value),
            ),

            if (_useColour)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final hex in _palette)
                    GestureDetector(
                      onTap: () => setState(() => _colour = hex),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: parseSwatch(hex),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _colour == hex
                                ? context.accent
                                : context.borderColor,
                            width: _colour == hex ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed:
              _name.text.trim().isEmpty ||
                  (attribute == null && _group.text.trim().isEmpty)
              ? null
              : () => Navigator.of(context).pop(
                  _NewOption(
                    groupName: _group.text.trim(),
                    name: _name.text.trim(),
                    swatchColor: _useColour ? _colour : '',
                  ),
                ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
