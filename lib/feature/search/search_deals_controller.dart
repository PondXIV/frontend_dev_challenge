import 'package:get/get.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../util/log_service.dart';

class SearchDealsController extends GetxController {
  final DealRepo dealRepo;

  SearchDealsController({required this.dealRepo});

  final results = <DealModel>[].obs;
  final isLoading = false.obs;
  final hasSearched = false.obs;
  final errorMessage = RxnString();
  int _requestId = 0;

  void onQueryChanged(String query) {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      _requestId++;
      results.clear();
      errorMessage.value = null;
      hasSearched.value = false;
      isLoading.value = false;
      return;
    }
    _search(normalizedQuery, ++_requestId);
  }

  Future<void> _search(String query, int requestId) async {
    isLoading.value = true;
    hasSearched.value = true;
    errorMessage.value = null;
    try {
      final found = await dealRepo.search(query);
      if (requestId != _requestId) return;
      results.assignAll(found);
    } catch (e) {
      LogService.error('search failed', e);
      if (requestId != _requestId) return;
      results.clear();
      errorMessage.value = 'Search failed. Please try again.';
    } finally {
      if (requestId == _requestId) {
        isLoading.value = false;
      }
    }
  }
}
