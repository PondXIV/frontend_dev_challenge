import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../model/deal_model.dart';
import '../../service/flash_sale_countdown_service.dart';

class FlashSaleCountdownText extends StatefulWidget {
  final DealModel deal;
  final TextStyle? style;
  final TextStyle? expiredStyle;

  const FlashSaleCountdownText({
    super.key,
    required this.deal,
    this.style,
    this.expiredStyle,
  });

  @override
  State<FlashSaleCountdownText> createState() => _FlashSaleCountdownTextState();
}

class _FlashSaleCountdownTextState extends State<FlashSaleCountdownText> {
  late final FlashSaleCountdownService _countdownService;

  @override
  void initState() {
    super.initState();
    _countdownService = Get.find<FlashSaleCountdownService>();
    _countdownService.register(widget.deal);
  }

  @override
  void didUpdateWidget(covariant FlashSaleCountdownText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deal.id != widget.deal.id ||
        oldWidget.deal.flashSaleEndsAt != widget.deal.flashSaleEndsAt) {
      _countdownService.unregister(oldWidget.deal);
      _countdownService.register(widget.deal);
    }
  }

  @override
  void dispose() {
    _countdownService.unregister(widget.deal);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final remaining =
          widget.deal.flashSaleEndsAt!.difference(_countdownService.now.value);
      if (remaining <= Duration.zero) {
        return Text('Expired', style: widget.expiredStyle ?? widget.style);
      }

      final seconds = remaining.inSeconds;
      final hours = seconds ~/ Duration.secondsPerHour;
      final minutes = (seconds ~/ Duration.secondsPerMinute) % 60;
      final remainder = seconds % Duration.secondsPerMinute;
      final text = hours > 0
          ? '${hours.toString().padLeft(2, '0')}:'
              '${minutes.toString().padLeft(2, '0')}:'
              '${remainder.toString().padLeft(2, '0')}'
          : '${(seconds ~/ Duration.secondsPerMinute).toString().padLeft(2, '0')}:'
              '${remainder.toString().padLeft(2, '0')}';
      return Text(text, style: widget.style);
    });
  }
}
