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

          SellerGalleryPanel(slug: slug, cover: product.imageUrl),
          const SizedBox(height: 24),

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

/// Mirrors MAX_GALLERY_PHOTOS in the API, which enforces it.
const int maxGalleryPhotos = 6;

/// The extra photos, in the order a shopper will flip through them.
///
/// Sits above the variant grid on the same screen: a photo is usually
/// added right after the variant it belongs to, so making the seller
/// navigate elsewhere for it would be a step backwards.
class SellerGalleryPanel extends ConsumerWidget {
  const SellerGalleryPanel({
    super.key,
    required this.slug,
    required this.cover,
  });

  final String slug;

  /// The product's own picture, which always leads the strip.
  final String cover;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final variants =
        ref.read(sellerVariantsProvider(slug)).valueOrNull ??
        const <SellerVariant>[];

    final result = await showDialog<_NewPhoto>(
      context: context,
      builder: (_) => _NewPhotoDialog(variants: variants),
    );
    if (result == null) return;

    try {
      await ref
          .read(sellerVariantRepositoryProvider)
          .addImage(
            slug,
            imageUrl: result.url,
            alt: result.alt,
            variantId: result.variantId,
          );
      ref.invalidate(sellerImagesProvider(slug));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeVariantError(error))));
    }
  }

  void _edit(
    BuildContext context, {
    required SellerImage image,
    required int index,
    required int total,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Consumer(
        builder: (_, sheetRef, _) => PhotoEditSheet(
          slug: slug,
          image: image,
          index: index,
          total: total,
          variants:
              sheetRef.watch(sellerVariantsProvider(slug)).valueOrNull ??
              const <SellerVariant>[],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = ref.watch(sellerImagesProvider(slug));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Photos', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          'The thumbnail strip beside the product picture. Pin one to a '
          'variant and it only shows while that variant is chosen.',
          style: TextStyle(color: context.mutedText, fontSize: 12),
        ),
        const SizedBox(height: 10),

        images.when(
          loading: () => const SizedBox(
            height: 92,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text(
            describeVariantError(error),
            style: const TextStyle(color: Color(0xFFB91C1C)),
          ),
          data: (List<SellerImage> items) {
            final full = items.length >= maxGalleryPhotos;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    // The cover, then the gallery, then the add tile.
                    itemCount: items.length + (full ? 1 : 2),
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _PhotoTile(
                          url: cover,
                          caption: 'Cover',
                          // Comes from the product form, not this list.
                          dimmed: true,
                        );
                      }
                      if (index <= items.length) {
                        final image = items[index - 1];
                        return _PhotoTile(
                          url: image.url,
                          caption: image.variantId == null ? 'All' : 'Variant',
                          onTap: () => _edit(
                            context,
                            image: image,
                            index: index - 1,
                            total: items.length,
                          ),
                        );
                      }
                      return _AddPhotoTile(onTap: () => _add(context, ref));
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  full
                      ? 'That is all $maxGalleryPhotos extra photos. Tap one '
                            'to replace or delete it.'
                      : '${items.length} of $maxGalleryPhotos extra photos. '
                            'Tap one to edit it.',
                  style: TextStyle(color: context.mutedText, fontSize: 11),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.url,
    required this.caption,
    this.dimmed = false,
    this.onTap,
  });

  final String url;
  final String caption;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dimmed ? 0.6 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Stack(
              children: <Widget>[
                Container(
                  width: 68,
                  height: 68,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: url.isEmpty
                      ? Icon(Icons.image_outlined, color: context.mutedText)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            url,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.image_not_supported_outlined,
                              color: context.mutedText,
                            ),
                          ),
                        ),
                ),
                // A quiet corner badge, so the thumbnail stays the thing
                // being looked at. The whole tile is the tap target.
                if (onTap != null)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: context.accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.edit_outlined,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              caption,
              style: TextStyle(color: context.mutedText, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: context.accent.withAlpha(28),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.add_rounded, size: 30, color: context.accent),
          ),
          const SizedBox(height: 2),
          Text(
            'Add',
            style: TextStyle(
              color: context.accent,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewPhoto {
  const _NewPhoto({
    required this.url,
    required this.alt,
    required this.variantId,
  });

  final String url;
  final String alt;
  final int? variantId;
}

class _NewPhotoDialog extends StatefulWidget {
  const _NewPhotoDialog({required this.variants});

  final List<SellerVariant> variants;

  @override
  State<_NewPhotoDialog> createState() => _NewPhotoDialogState();
}

class _NewPhotoDialogState extends State<_NewPhotoDialog> {
  final _url = TextEditingController();
  final _alt = TextEditingController();
  int? _variantId;

  @override
  void dispose() {
    _url.dispose();
    _alt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a photo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _url,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Image URL',
                hintText: 'https://...',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _alt,
              maxLength: 140,
              decoration: const InputDecoration(
                labelText: 'Alt text',
                hintText: 'What the photo shows',
              ),
            ),
            if (widget.variants.isNotEmpty)
              DropdownButtonFormField<int?>(
                initialValue: _variantId,
                decoration: const InputDecoration(labelText: 'Show for'),
                items: <DropdownMenuItem<int?>>[
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Every variant'),
                  ),
                  for (final variant in widget.variants)
                    DropdownMenuItem<int?>(
                      value: variant.id,
                      child: Text(variant.optionLabel),
                    ),
                ],
                onChanged: (value) => setState(() => _variantId = value),
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
          onPressed: _url.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(
                  _NewPhoto(
                    url: _url.text.trim(),
                    alt: _alt.text.trim(),
                    variantId: _variantId,
                  ),
                ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// Everything about one photo, edited where it sits: which picture, what
/// it shows, which variant it belongs to, and where it sits in the strip.
class PhotoEditSheet extends ConsumerStatefulWidget {
  const PhotoEditSheet({
    super.key,
    required this.slug,
    required this.image,
    required this.index,
    required this.total,
    required this.variants,
  });

  final String slug;
  final SellerImage image;
  final int index;
  final int total;
  final List<SellerVariant> variants;

  @override
  ConsumerState<PhotoEditSheet> createState() => _PhotoEditSheetState();
}

class _PhotoEditSheetState extends ConsumerState<PhotoEditSheet> {
  late final TextEditingController _url;
  late final TextEditingController _alt;
  late int? _variantId;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.image.url);
    _alt = TextEditingController(text: widget.image.alt);
    // A variant that was deleted leaves an id nothing matches, which would
    // make the dropdown throw; fall back to "every variant".
    _variantId = widget.variants.any((v) => v.id == widget.image.variantId)
        ? widget.image.variantId
        : null;
  }

  @override
  void dispose() {
    _url.dispose();
    _alt.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {bool close = true}) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await action();
      ref.invalidate(sellerImagesProvider(widget.slug));
      if (!mounted) return;
      if (close) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = describeVariantError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.read(sellerVariantRepositoryProvider);

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
              'Photo ${widget.index + 1} of ${widget.total}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Image URL',
                hintText: 'https://...',
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _alt,
              maxLength: 140,
              decoration: const InputDecoration(
                labelText: 'Alt text',
                hintText: 'What the photo shows',
              ),
            ),

            if (widget.variants.isNotEmpty)
              DropdownButtonFormField<int?>(
                initialValue: _variantId,
                decoration: const InputDecoration(labelText: 'Show for'),
                items: <DropdownMenuItem<int?>>[
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Every variant'),
                  ),
                  for (final variant in widget.variants)
                    DropdownMenuItem<int?>(
                      value: variant.id,
                      child: Text(variant.optionLabel),
                    ),
                ],
                onChanged: (value) => setState(() => _variantId = value),
              ),

            const SizedBox(height: 16),
            Text(
              'POSITION IN THE STRIP',
              style: TextStyle(
                color: context.mutedText,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                OutlinedButton.icon(
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Earlier'),
                  onPressed: _busy || widget.index == 0
                      ? null
                      : () => _run(
                          () => repository.moveImage(
                            widget.slug,
                            widget.image.id,
                            widget.index - 1,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Later'),
                  onPressed: _busy || widget.index >= widget.total - 1
                      ? null
                      : () => _run(
                          () => repository.moveImage(
                            widget.slug,
                            widget.image.id,
                            widget.index + 1,
                          ),
                        ),
                ),
              ],
            ),

            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
            ],

            const SizedBox(height: 20),
            GradientButton(
              label: _busy ? 'Saving...' : 'Save',
              onPressed: _busy || _url.text.trim().isEmpty
                  ? null
                  : () => _run(
                      () => repository.updateImage(
                        widget.slug,
                        widget.image.id,
                        imageUrl: _url.text.trim(),
                        alt: _alt.text.trim(),
                        variantId: _variantId,
                      ),
                    ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text(
                'Delete photo',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => repository.removeImage(widget.slug, widget.image.id),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
