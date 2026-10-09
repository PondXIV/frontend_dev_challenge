import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app_config.dart';
import '../../model/cart_item_model.dart';
import '../shared_widget/the_network_image.dart';
import 'cart_controller.dart';

class CartScreen extends GetView<CartController> {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = controller.cartService;
    return Scaffold(
      appBar: AppBar(title: const Text('My bag')),
      body: Obx(() {
        if (cart.items.isEmpty) {
          return const Center(child: Text('Your bag is empty'));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: cart.items.length,
          itemBuilder: (context, index) {
            final item = cart.items[index];
            return Card(
              key: ValueKey(item.deal.id),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: Colors.white,
              elevation: 0.5,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    TheNetworkImage(
                      url: item.deal.imageUrl,
                      width: 64,
                      height: 64,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.deal.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600)),
                          Text(item.deal.storeName,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.grey.shade600)),
                          Text('฿${item.deal.price.toStringAsFixed(0)} each',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppConfig.primaryGreen,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          _ReservationStatus(
                            item: item,
                            now: cart.now,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: cart.isCheckoutLocked.value
                                  ? null
                                  : () => cart.decrement(item.deal.id),
                            ),
                            Text('${item.quantity}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: cart.isCheckoutLocked.value
                                  ? null
                                  : () => cart.add(item.deal),
                            ),
                          ],
                        ),
                        IconButton(
                          tooltip: 'Remove item',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: cart.isCheckoutLocked.value
                              ? null
                              : () => cart.remove(item.deal.id),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
      bottomNavigationBar: Obx(() {
        if (cart.items.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          color: Colors.white,
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Total', style: TextStyle(fontSize: 13)),
                  Text('฿${cart.total.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: FilledButton(
                  onPressed: controller.isCheckingOut.value ||
                          cart.isCheckoutLocked.value ||
                          cart.items.any((item) => item.isReserving)
                      ? null
                      : controller.checkout,
                  child: controller.isCheckingOut.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : cart.items.any((item) => item.isReserving)
                          ? const Text('Reserving stock…')
                          : const Text('Checkout'),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _ReservationStatus extends StatelessWidget {
  final CartItemModel item;
  final Rx<DateTime> now;

  const _ReservationStatus({required this.item, required this.now});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (item.isReserving) {
        return const Text(
          'Reserving stock…',
          style: TextStyle(fontSize: 11, color: Colors.orange),
        );
      }
      final remaining = item.reservations
          .map((reservation) => reservation.expiresAt.difference(now.value))
          .reduce((a, b) => a < b ? a : b);
      final seconds = remaining.inSeconds.clamp(0, 5 * 60);
      final minutes = seconds ~/ 60;
      final remainder = seconds % 60;
      return Text(
        'Reserved · expires in $minutes:${remainder.toString().padLeft(2, '0')}',
        style: const TextStyle(fontSize: 11, color: Colors.green),
      );
    });
  }
}
