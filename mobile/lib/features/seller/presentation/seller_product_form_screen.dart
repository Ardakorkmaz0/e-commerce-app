import 'package:dio/dio.dart';
import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:ecommerce_mobile/features/products/data/models/product_model.dart';
import 'package:ecommerce_mobile/features/products/presentation/providers/product_provider.dart';
import 'package:ecommerce_mobile/shared/widgets/gradient_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Web equivalent: `/seller/new` and `/seller/<slug>/edit`.
///
/// [slug] null means "create", otherwise the existing listing is loaded and
/// patched.
class SellerProductFormScreen extends ConsumerStatefulWidget {
  const SellerProductFormScreen({super.key, this.slug});

  final String? slug;

  @override
  ConsumerState<SellerProductFormScreen> createState() =>
      _SellerProductFormScreenState();
}

class _SellerProductFormScreenState
    extends ConsumerState<SellerProductFormScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _imageUrlController = TextEditingController();

  int? _categoryId;
  bool _isActive = true;
  bool _loading = false;
  bool _prefilled = false;
  String? _errorMessage;

  bool get _isEdit => widget.slug != null;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _prefill(Product product) {
    if (_prefilled) return;
    _prefilled = true;

    _nameController.text = product.name;
    _descriptionController.text = product.description;
    _priceController.text = product.price;
    _stockController.text = product.stock.toString();
    _imageUrlController.text = product.imageUrl;
    _isActive = product.isActive;
    // The seller endpoint sends the category id directly, so there is
    // nothing to look up.
    _categoryId = product.categoryId;
  }

  /// Turns a DRF validation body into one readable line.
  String _describeError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final messages = data.values
            .expand((value) => value is List ? value : <dynamic>[value])
            .map((value) => value.toString())
            .join(' ');
        if (messages.isNotEmpty) return messages;
      }
      if (error.response?.statusCode == 403) {
        return 'You need a seller account to do this.';
      }
    }
    return 'Could not save the product.';
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final price = _priceController.text.trim();

    if (name.isEmpty || price.isEmpty || _categoryId == null) {
      setState(() => _errorMessage = 'Name, price and category are required.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final payload = <String, dynamic>{
      'name': name,
      'description': _descriptionController.text.trim(),
      'price': price,
      'stock': int.tryParse(_stockController.text.trim()) ?? 0,
      'category': _categoryId,
      'image_url': _imageUrlController.text.trim(),
      'is_active': _isActive,
    };

    try {
      final repository = ref.read(productRepositoryProvider);
      if (_isEdit) {
        await repository.updateProduct(widget.slug!, payload);
      } else {
        await repository.createProduct(payload);
      }

      ref.invalidate(sellerProductsProvider);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = _describeError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    // The seller's own endpoint, not the public one: it also returns
    // listings the seller has hidden from the store.
    final existing = _isEdit
        ? ref.watch(sellerProductProvider(widget.slug!))
        : const AsyncValue<Product?>.data(null);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.canPop() ? context.pop() : context.goNamed('main'),
        ),
        title: Text(
          _isEdit ? 'Edit Product' : 'Add Product',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Could not load categories.')),
        data: (List<Category> categoryList) {
          return existing.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) =>
                const Center(child: Text('Could not load this product.')),
            data: (Product? product) {
              if (product != null) _prefill(product);

              return ListView(
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  if (_errorMessage != null) ...<Widget>[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Color(0xFFDC2626)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  _Field(label: 'Product name', controller: _nameController),
                  const SizedBox(height: 12),

                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _Field(
                          label: 'Price',
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Field(
                          label: 'Stock',
                          controller: _stockController,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<int>(
                    initialValue: _categoryId,
                    decoration: _decoration('Category'),
                    items: categoryList
                        .map(
                          (category) => DropdownMenuItem<int>(
                            value: category.id,
                            child: Text(category.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _categoryId = value),
                  ),
                  const SizedBox(height: 12),

                  _Field(
                    label: 'Description',
                    controller: _descriptionController,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),

                  _Field(
                    label: 'Image link',
                    controller: _imageUrlController,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 8),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Visible in the store'),
                    value: _isActive,
                    activeThumbColor: AppColors.primary,
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                  const SizedBox(height: 20),

                  GradientButton(
                    label: _loading
                        ? 'Saving...'
                        : (_isEdit ? 'Save changes' : 'Create product'),
                    onPressed: _loading ? null : _submit,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

InputDecoration _decoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: _decoration(label),
    );
  }
}
