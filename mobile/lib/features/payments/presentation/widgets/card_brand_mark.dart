import 'package:flutter/material.dart';

/// Brand mark drawn inline, so no network image is fetched for a logo.
class CardBrandMark extends StatelessWidget {
  const CardBrandMark({super.key, required this.brand});

  final String brand;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: brand == 'mastercard'
          ? const _MastercardMark()
          : const Text(
              'VISA',
              style: TextStyle(
                color: Color(0xFF1A1F71),
                fontSize: 11,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
    );
  }
}

class _MastercardMark extends StatelessWidget {
  const _MastercardMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: const <Widget>[
          Positioned(left: 0, child: _Circle(color: Color(0xFFEB001B))),
          Positioned(right: 0, child: _Circle(color: Color(0xFFF79E1B))),
        ],
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        // Slight transparency gives the overlap the mark is known for.
        color: color.withValues(alpha: 0.85),
        shape: BoxShape.circle,
      ),
    );
  }
}
