import 'package:get/get.dart';

import '../../repository/order_repo.dart';
import '../../service/api_exception.dart';
import '../../service/cart_service.dart';
import '../../util/log_service.dart';

class CartController extends GetxController {
  final CartService cartService;
  final OrderRepo orderRepo;

  CartController({required this.cartService, required this.orderRepo});

  final isCheckingOut = false.obs;

  Future<void> checkout() async {
    if (isCheckingOut.value) return;
    final checkoutItems = cartService.beginCheckout();
    if (checkoutItems == null) {
      if (cartService.items.isEmpty) return;
      Get.snackbar(
        'Items still being reserved',
        'Please wait until your item holds are confirmed before checking out.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    isCheckingOut.value = true;
    try {
      final order = await orderRepo.checkout(checkoutItems);
      cartService.clear(releaseReservations: false);
      Get.snackbar(
        'Order confirmed',
        'Order #${order.id} — pick up soon!',
        snackPosition: SnackPosition.BOTTOM,
      );
    } on ApiException catch (e) {
      LogService.error('checkout failed', e);
      if (e.statusCode == 410) {
        cartService.handleExpiredCheckout();
      } else {
        Get.snackbar(
          'Checkout failed',
          e.message,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      LogService.error('checkout failed', e);
      Get.snackbar(
        'Checkout failed',
        'We could not complete checkout. Your reserved items are still in your bag.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      cartService.endCheckout();
      isCheckingOut.value = false;
    }
  }
}
