import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../model/deal_model.dart';
import '../../service/analytics_service.dart';

class DealImpressionTracker extends StatefulWidget {
  final DealModel deal;
  final String source;
  final int position;
  final Widget child;

  const DealImpressionTracker({
    super.key,
    required this.deal,
    required this.source,
    required this.position,
    required this.child,
  });

  @override
  State<DealImpressionTracker> createState() => _DealImpressionTrackerState();
}

class _DealImpressionTrackerState extends State<DealImpressionTracker> {
  late final AnalyticsService _analytics;

  @override
  void initState() {
    super.initState();
    _analytics = Get.find<AnalyticsService>();
  }

  @override
  void didUpdateWidget(covariant DealImpressionTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deal.id != widget.deal.id ||
        oldWidget.source != widget.source ||
        oldWidget.position != widget.position) {
      _sendVisibility(
        deal: oldWidget.deal,
        source: oldWidget.source,
        position: oldWidget.position,
        fraction: 0,
      );
    }
  }

  @override
  void dispose() {
    _reportVisibility(0);
    super.dispose();
  }

  void _reportVisibility(double fraction) {
    _sendVisibility(
      deal: widget.deal,
      source: widget.source,
      position: widget.position,
      fraction: fraction,
    );
  }

  void _sendVisibility({
    required DealModel deal,
    required String source,
    required int position,
    required double fraction,
  }) {
    _analytics.onDealVisibilityChanged(
      deal: deal,
      source: source,
      position: position,
      visibleFraction: fraction,
    );
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ValueKey(
        'deal-impression:${widget.source}:${widget.deal.id}:${widget.position}',
      ),
      onVisibilityChanged: (info) => _reportVisibility(info.visibleFraction),
      child: widget.child,
    );
  }
}
