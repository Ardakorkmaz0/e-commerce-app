import 'package:ecommerce_mobile/features/addresses/data/address_repository.dart';
import 'package:ecommerce_mobile/features/addresses/data/models/delivery_address_model.dart';
import 'package:ecommerce_mobile/features/addresses/presentation/providers/address_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Add and edit share one screen: [address] null means "create", otherwise
/// the fields start filled and saving patches that record.
class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key, this.address});

  final DeliveryAddress? address;

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _recipientController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _districtController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _countryCodeController = TextEditingController(text: 'TR');

  bool _makeDefault = false;
  bool _saving = false;
  String? _errorMessage;

  bool get _isEdit => widget.address != null;

  @override
  void initState() {
    super.initState();
    final address = widget.address;
    if (address == null) return;

    _labelController.text = address.label;
    _recipientController.text = address.recipientName;
    _phoneController.text = address.phoneNumber;
    _addressLine1Controller.text = address.addressLine1;
    _addressLine2Controller.text = address.addressLine2;
    _districtController.text = address.district;
    _cityController.text = address.city;
    _postalCodeController.text = address.postalCode;
    _countryCodeController.text = address.countryCode;
    _makeDefault = address.isDefault;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _recipientController.dispose();
    _phoneController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _countryCodeController.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }
    return null;
  }

  String? _countryCodeValidator(String? value) {
    final code = value?.trim() ?? '';
    if (!RegExp(r'^[A-Za-z]{2}$').hasMatch(code)) {
      return 'Enter a two-letter country code.';
    }
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final input = DeliveryAddressInput(
      label: _labelController.text.trim(),
      recipientName: _recipientController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      addressLine1: _addressLine1Controller.text.trim(),
      addressLine2: _addressLine2Controller.text.trim(),
      district: _districtController.text.trim(),
      city: _cityController.text.trim(),
      postalCode: _postalCodeController.text.trim(),
      countryCode: _countryCodeController.text.trim().toUpperCase(),
      isDefault: _makeDefault,
    );

    try {
      final notifier = ref.read(deliveryAddressesProvider.notifier);
      if (_isEdit) {
        await notifier.updateAddress(widget.address!.id, input);
      } else {
        await notifier.createAddress(input);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit ? 'Delivery address updated.' : 'Delivery address added.',
          ),
        ),
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = describeAddressError(error));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Edit delivery address' : 'Add delivery address',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: _saving
              ? null
              : () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.goNamed('addresses');
                  }
                },
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            if (_errorMessage != null) ...<Widget>[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Color(0xFFB91C1C)),
                ),
              ),
              const SizedBox(height: 16),
            ],
            _AddressField(
              controller: _labelController,
              label: 'Address label',
              hint: 'Home or Work',
              maxLength: 50,
              validator: _required,
              textCapitalization: TextCapitalization.words,
            ),
            _AddressField(
              controller: _recipientController,
              label: 'Recipient name',
              maxLength: 120,
              validator: _required,
              textCapitalization: TextCapitalization.words,
              autofillHints: const <String>[AutofillHints.name],
            ),
            _AddressField(
              controller: _phoneController,
              label: 'Phone number',
              maxLength: 32,
              validator: _required,
              keyboardType: TextInputType.phone,
              autofillHints: const <String>[AutofillHints.telephoneNumber],
            ),
            _AddressField(
              controller: _addressLine1Controller,
              label: 'Address line 1',
              maxLength: 200,
              validator: _required,
              textCapitalization: TextCapitalization.sentences,
              autofillHints: const <String>[AutofillHints.streetAddressLine1],
            ),
            _AddressField(
              controller: _addressLine2Controller,
              label: 'Address line 2 (optional)',
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              autofillHints: const <String>[AutofillHints.streetAddressLine2],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _AddressField(
                    controller: _districtController,
                    label: 'District',
                    maxLength: 100,
                    validator: _required,
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AddressField(
                    controller: _cityController,
                    label: 'City',
                    maxLength: 100,
                    validator: _required,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const <String>[AutofillHints.addressCity],
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: _AddressField(
                    controller: _postalCodeController,
                    label: 'Postal code (optional)',
                    maxLength: 20,
                    keyboardType: TextInputType.text,
                    autofillHints: const <String>[AutofillHints.postalCode],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AddressField(
                    controller: _countryCodeController,
                    label: 'Country',
                    maxLength: 2,
                    validator: _countryCodeValidator,
                    textCapitalization: TextCapitalization.characters,
                    autofillHints: const <String>[AutofillHints.countryCode],
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Make this my default address'),
              subtitle: const Text(
                'The first saved address is selected automatically.',
              ),
              value: _makeDefault,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _makeDefault = value),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_location_alt_outlined),
              label: Text(
                _saving
                    ? 'Saving...'
                    : (_isEdit ? 'Save changes' : 'Save address'),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressField extends StatelessWidget {
  const _AddressField({
    required this.controller,
    required this.label,
    required this.maxLength,
    this.hint,
    this.validator,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLength;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, hintText: hint),
        maxLength: maxLength,
        validator: validator,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        textInputAction: TextInputAction.next,
        autofillHints: autofillHints,
      ),
    );
  }
}
