import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:ecommerce_mobile/features/products/data/models/product_model.dart';
import 'package:flutter/material.dart';

/// The photos to show, in order, for the variant currently chosen.
///
/// The variant's own picture leads, then the product cover, then the
/// gallery with anything pinned to a different variant left out. Kept
/// beside the widget so the web and the app build the same strip.
List<String> buildPhotoStrip(Product product, ProductVariant? variant) {
  final strip = <String>[];

  if (variant != null && variant.imageUrl.isNotEmpty) {
    strip.add(variant.imageUrl);
  }
  if (product.imageUrl.isNotEmpty) {
    strip.add(product.imageUrl);
  }

  for (final photo in product.photos) {
    if (photo.variantId != null && photo.variantId != variant?.id) continue;
    if (photo.url.isNotEmpty) strip.add(photo.url);
  }

  // The same file can arrive as both the cover and a gallery row.
  return strip.toSet().toList();
}

/// A swipeable photo panel with a thumbnail rail underneath.
///
/// A phone has the width for the picture or for a side rail, not both, so
/// the rail lies below and the photos themselves are swipeable — which is
/// what a thumb reaches for first anyway.
class ProductGallery extends StatefulWidget {
  const ProductGallery({super.key, required this.photos, required this.alt});

  final List<String> photos;
  final String alt;

  @override
  State<ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<ProductGallery> {
  late PageController _pages;
  int _active = 0;

  @override
  void initState() {
    super.initState();
    _pages = PageController();
  }

  @override
  void didUpdateWidget(ProductGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new variant means a new strip, so go back to its first photo.
    if (oldWidget.photos != widget.photos && _active != 0) {
      setState(() => _active = 0);
      if (_pages.hasClients) _pages.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tint = AppColors.primary.withAlpha(20);

    if (widget.photos.isEmpty) {
      return Container(
        height: 280,
        width: double.infinity,
        color: tint,
        child: Icon(
          Icons.image_outlined,
          size: 96,
          color: AppColors.primary.withAlpha(100),
        ),
      );
    }

    return Column(
      children: <Widget>[
        SizedBox(
          height: 280,
          child: Container(
            color: tint,
            child: PageView.builder(
              controller: _pages,
              itemCount: widget.photos.length,
              onPageChanged: (index) => setState(() => _active = index),
              itemBuilder: (context, index) => Image.network(
                widget.photos[index],
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Icon(
                  Icons.image_not_supported_outlined,
                  size: 96,
                  color: AppColors.primary.withAlpha(100),
                ),
              ),
            ),
          ),
        ),

        if (widget.photos.length > 1)
          Container(
            // Same tint as the photo panel, so the two read as one surface.
            color: tint,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              height: 62,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final selected = index == _active;

                  return GestureDetector(
                    onTap: () {
                      setState(() => _active = index);
                      _pages.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      );
                    },
                    child: Container(
                      width: 62,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? context.accent
                              : context.borderColor,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Image.network(
                        widget.photos[index],
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.image_not_supported_outlined,
                          size: 20,
                          color: context.mutedText,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
