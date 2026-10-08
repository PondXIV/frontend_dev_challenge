import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../util/log_service.dart';

class HomeController extends GetxController {
  final DealRepo dealRepo;

  HomeController({required this.dealRepo});

  final deals = <DealModel>[].obs;
  final flashDeals = <DealModel>[].obs;
  final isLoading = true.obs;
  final todayOnly = false.obs;
  final scrollOffset = 0.0.obs;

  final scrollController = ScrollController();
  final refreshController = RefreshController();

  int _page = 1;
  int _totalPages = 1;
  int _feedGeneration = 0;
  bool _isFetchingMore = false;

  bool get hasMore => _page < _totalPages;

  List<DealModel> get visibleDeals => todayOnly.value
      ? deals.where((d) => d.pickupWindow.isToday).toList()
      : deals.toList();

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    _initialLoad();
  }

  void _onScroll() {
    scrollOffset.value = scrollController.offset;
  }

  Future<void> _initialLoad() async {
    isLoading.value = true;
    try {
      await Future.wait([refreshDeals(), _loadFlashDeals()]);
    } catch (e) {
      LogService.error('initial load failed', e);
    }
    isLoading.value = false;
  }

  Future<void> _loadFlashDeals() async {
    flashDeals.assignAll(await dealRepo.fetchFlashDeals());
  }

  Future<void> refreshDeals() async {
    final generation = ++_feedGeneration;
    _page = 1;
    if (_isFetchingMore) {
      refreshController.loadComplete();
    }
    _isFetchingMore = false;
    try {
      final res = await dealRepo.fetchDeals(page: 1);
      if (generation != _feedGeneration) return;
      _totalPages = res.totalPages;
      deals.assignAll(res.items);
      refreshController.refreshCompleted();
    } catch (e) {
      if (generation != _feedGeneration) return;
      LogService.error('refresh deals failed', e);
      refreshController.refreshFailed();
    }
  }

  Future<void> loadMore() async {
    if (_isFetchingMore) return;
    if (!hasMore) {
      refreshController.loadNoData();
      return;
    }
    final generation = _feedGeneration;
    final requestedPage = _page + 1;
    _isFetchingMore = true;
    try {
      final res = await dealRepo.fetchDeals(page: requestedPage);
      if (generation != _feedGeneration) return;
      _page = requestedPage;
      _totalPages = res.totalPages;
      deals.addAll(res.items);
    } catch (e) {
      if (generation != _feedGeneration) return;
      LogService.error('loadMore failed', e);
    } finally {
      if (generation == _feedGeneration) {
        _isFetchingMore = false;
        refreshController.loadComplete();
      }
    }
  }

  void scrollToTop() {
    scrollController.animateTo(0,
        duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
  }

  @override
  void onClose() {
    scrollController.dispose();
    refreshController.dispose();
    super.onClose();
  }
}
