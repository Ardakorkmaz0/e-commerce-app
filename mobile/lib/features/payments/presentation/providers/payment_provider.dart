import 'package:ecommerce_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:ecommerce_mobile/features/payments/data/models/payment_method_model.dart';
import 'package:ecommerce_mobile/features/payments/data/payment_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(
    apiClient: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

class PaymentMethodsNotifier extends AsyncNotifier<List<PaymentMethod>> {
  @override
  Future<List<PaymentMethod>> build() async {
    // Watching the user keeps one account's cards from lingering after
    // sign-out or after another account signs in.
    final user = ref.watch(authProvider).valueOrNull;
    if (user == null) {
      return const <PaymentMethod>[];
    }
    return ref.read(paymentRepositoryProvider).fetchPaymentMethods();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(paymentRepositoryProvider).fetchPaymentMethods(),
    );
  }

  Future<PaymentMethod> addPaymentMethod(PaymentMethodInput input) async {
    final repository = ref.read(paymentRepositoryProvider);
    final created = await repository.addPaymentMethod(input);
    state = AsyncData(await repository.fetchPaymentMethods());
    return created;
  }

  Future<void> setDefaultPaymentMethod(int methodId) async {
    final repository = ref.read(paymentRepositoryProvider);
    await repository.setDefaultPaymentMethod(methodId);
    state = AsyncData(await repository.fetchPaymentMethods());
  }

  Future<void> deletePaymentMethod(int methodId) async {
    final repository = ref.read(paymentRepositoryProvider);
    await repository.deletePaymentMethod(methodId);
    state = AsyncData(await repository.fetchPaymentMethods());
  }
}

final paymentMethodsProvider =
    AsyncNotifierProvider<PaymentMethodsNotifier, List<PaymentMethod>>(
      PaymentMethodsNotifier.new,
    );
