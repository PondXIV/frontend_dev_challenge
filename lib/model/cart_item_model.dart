import 'deal_model.dart';
import 'reservation_model.dart';
import 'package:get/get.dart';

class CartItemModel {
  final DealModel deal;
  int quantity;
  final List<ReservationModel> reservations;
  final Set<int> pendingReservationIds;
  final RxInt pendingReservations = 0.obs;

  CartItemModel({
    required this.deal,
    this.quantity = 1,
    List<ReservationModel>? reservations,
    Set<int>? pendingReservationIds,
  })  : reservations = reservations ?? [],
        pendingReservationIds = pendingReservationIds ?? {};

  num get lineTotal => deal.price * quantity;

  bool get isReserving => pendingReservations.value > 0;

  Duration? get reservationTimeLeft {
    if (reservations.isEmpty) return null;
    return reservations
        .map((reservation) =>
            reservation.expiresAt.difference(DateTime.now().toUtc()))
        .reduce((a, b) => a < b ? a : b);
  }
}
