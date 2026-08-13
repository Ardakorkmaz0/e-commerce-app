import 'package:flutter/material.dart';
import 'package:ecommerce_mobile/core/theme/app_theme.dart';

// Flutter equivalent of the web's .signin-submit-button.
// Handles gradient, shadow, and disabled state to match web behavior.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed; // pass null to disable the button

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null;

    return DecoratedBox(
      decoration: BoxDecoration(
        // Remove gradient when disabled, apply grey instead
        gradient: disabled ? null : AppGradients.action,
        color: disabled ? Colors.grey.shade300 : null,
        borderRadius: BorderRadius.circular(8),
        // Web: box-shadow 0 10px 24px rgba(79,70,229,0.28)
        boxShadow: disabled
            ? null
            : [
                BoxShadow(
                  color: AppColors.primary.withAlpha(71), // 0.28 * 255 ≈ 71
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
