import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:ecommerce_mobile/features/payments/data/models/payment_method_model.dart';
import 'package:ecommerce_mobile/features/payments/data/payment_repository.dart';
import 'package:ecommerce_mobile/features/payments/presentation/providers/payment_provider.dart';
import 'package:ecommerce_mobile/features/payments/presentation/widgets/card_brand_mark.dart';
import 'package:ecommerce_mobile/shared/widgets/gradient_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Web equivalent: the add-card form on /profile/payment-methods.
///
/// The number lives in a controller for as long as the form is on screen and
/// is disposed with it. It is posted once and never written to storage.
class AddCardScreen extends ConsumerStatefulWidget {
  const AddCardScreen({super.key});

  @override
  ConsumerState<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends ConsumerState<AddCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _holderController = TextEditingController();
  final _codeController = TextEditingController();

  int? _expMonth;
  int? _expYear;
  bool _makeDefault = false;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Repaints the brand mark as the number is typed.
    _numberController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _numberController.dispose();
    _holderController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String get _digits => _numberController.text.replaceAll(RegExp(r'\D'), '');

  /// Mirrors the server's detection so the mark can appear while typing.
  String? get _brand {
    if (RegExp(r'^4').hasMatch(_digits)) return 'visa';
    if (RegExp(r'^5[1-5]').hasMatch(_digits)) return 'mastercard';
    if (RegExp(r'^2(2[2-9]|[3-6]|7[01]|720)').hasMatch(_digits)) {
      return 'mastercard';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_expMonth == null || _expYear == null) {
      setState(() => _errorMessage = 'Choose the expiry month and year.');
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(paymentMethodsProvider.notifier)
          .addPaymentMethod(
            PaymentMethodInput(
              cardNumber: _digits,
              securityCode: _codeController.text.trim(),
              holderName: _holderController.text.trim(),
              expMonth: _expMonth!,
              expYear: _expYear!,
              isDefault: _makeDefault,
            ),
          );

      // Clear the sensitive fields before leaving, so nothing sits in memory
      // longer than it must.
      _numberController.clear();
      _codeController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Card saved. Only the last four digits are stored.'),
        ),
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = describePaymentError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add card',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () =>
              context.canPop() ? context.pop() : context.goNamed('main'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
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

            TextFormField(
              controller: _numberController,
              keyboardType: TextInputType.number,
              autofillHints: const <String>[AutofillHints.creditCardNumber],
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(19),
                _CardNumberFormatter(),
              ],
              decoration: InputDecoration(
                labelText: 'Card number',
                hintText: '1234 5678 9012 3456',
                helperText: 'Visa and Mastercard are supported.',
                border: const OutlineInputBorder(),
                suffixIcon: _brand == null
                    ? null
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        child: CardBrandMark(brand: _brand!),
                      ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 62,
                  minHeight: 40,
                ),
              ),
              validator: (value) {
                if (_digits.length < 12) return 'Enter the full card number.';
                if (_brand == null) {
                  return 'Only Visa and Mastercard are supported.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _holderController,
              textCapitalization: TextCapitalization.words,
              autofillHints: const <String>[AutofillHints.creditCardName],
              decoration: const InputDecoration(
                labelText: 'Name on card',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value ?? '').trim().length < 2
                  ? 'Enter the name printed on the card.'
                  : null,
            ),
            const SizedBox(height: 16),

            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _expMonth,
                    decoration: const InputDecoration(
                      labelText: 'Month',
                      border: OutlineInputBorder(),
                    ),
                    items: List<int>.generate(12, (index) => index + 1)
                        .map(
                          (month) => DropdownMenuItem<int>(
                            value: month,
                            child: Text(month.toString().padLeft(2, '0')),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _expMonth = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _expYear,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(),
                    ),
                    items: List<int>.generate(15, (index) => currentYear + index)
                        .map(
                          (year) => DropdownMenuItem<int>(
                            value: year,
                            child: Text('$year'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _expYear = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'CVC',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (value ?? '').length != 3
                        ? 'Enter the 3 digit code.'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use this card by default'),
              value: _makeDefault,
              activeThumbColor: AppColors.primary,
              onChanged: (value) => setState(() => _makeDefault = value),
            ),
            const SizedBox(height: 16),

            GradientButton(
              label: _saving ? 'Saving...' : 'Save card',
              onPressed: _saving ? null : _submit,
            ),
            const SizedBox(height: 16),

            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.lock_outline, size: 15, color: AppColors.mutedText),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'The number is sent once to be verified and is never '
                    'stored on this device or in the database.',
                    style: TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Inserts a space every four digits while typing.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && index % 4 == 0) buffer.write(' ');
      buffer.write(digits[index]);
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
