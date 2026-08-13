import 'package:flutter/material.dart';

// Web equivalent: /cart page (cart modal in navbar + cart page)
class CartTab extends StatelessWidget {
  const CartTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      // TODO: replace with real cart items once the backend is ready
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Your cart is empty.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
