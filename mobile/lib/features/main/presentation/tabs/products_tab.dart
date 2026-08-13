import 'package:flutter/material.dart';

// Web karşılığı: /products sayfası
class ProductsTab extends StatelessWidget {
  const ProductsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      // TODO: Backend hazır olunca ürün listesi buraya gelecek
      body: const Center(
        child: Text('Products will appear here.'),
      ),
    );
  }
}
