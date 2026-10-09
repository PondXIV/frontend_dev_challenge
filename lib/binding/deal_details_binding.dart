import 'package:get/get.dart';

import '../feature/deal/deal_details_controller.dart';
import '../model/deal_model.dart';

class DealDetailsBinding extends Bindings {
  @override
  void dependencies() {
    final argument = Get.arguments;
    Get.lazyPut(() => DealDetailsController(
          dealRepo: Get.find(),
          cartService: Get.find(),
          analytics: Get.find(),
          initialDeal: argument is DealModel ? argument : null,
          dealId: int.tryParse(Get.parameters['id'] ?? ''),
          source: Get.parameters['source'] ?? 'unknown',
        ));
  }
}
