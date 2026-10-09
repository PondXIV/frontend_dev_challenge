# Solutions

## 1. Tickets/features investigated

### Bug tickets RES-101–RES-107

- **RES-101 — Stale search results:** Queries run asynchronously and can finish out of order; a slower earlier query must not replace the latest one. `SearchDealsController` tags requests with an incrementing ID and only applies results/errors/loading state from the current request. Clearing the query also invalidates in-flight work. Covered by `search_deals_controller_test.dart`.
- **RES-102 — Countdown after leaving orders:** `PickupCountdown` owns a periodic timer that calls `setState`; failing to cancel it when the widget is disposed causes the reported lifecycle crash. Its `dispose` cancels the timer. Covered by `pickup_countdown_test.dart`.
- **RES-103 — Accumulating deal requests:** Each deal-details controller listens for cart changes and re-fetches that deal's availability. If the GetX worker remains subscribed after the route closes, old controllers continue issuing requests. `DealDetailsController.onClose` disposes its `ever` worker.
- **RES-104 — Duplicate feed items:** A page request started before refresh can finish afterward and append stale data to the refreshed feed. `HomeController` increments a feed generation on refresh and ignores responses from older generations; it also prevents simultaneous pagination requests. Covered by `home_controller_test.dart`.
- **RES-105 — Feed performance and image memory:** Scroll offset is observed only by the app bar and scroll-to-top button, not by the feed `Obx`, so scrolling does not rebuild the whole feed. `ListView.builder` builds feed rows lazily. `TheNetworkImage` sets decoded cache dimensions from the rendered size and device pixel ratio, rather than retaining full-resolution source images. This is code-level verification; no Android DevTools before/after profile or memory measurements were captured in this environment.
- **RES-106 — Wrong pickup time and filter:** UTC instants were formatted and compared as device-local time, producing wrong Bangkok labels and dates. `PickupWindowModel` now normalizes instants to Bangkok time (UTC+7) for labels and market-date/open checks. `pickup_window_model_test.dart` covers the 06:00–09:30 label and market-date comparisons.
- **RES-107 — Deep-link crash:** `DealDetailsController` assumed every route supplied a `DealModel` in `Get.arguments`; external links supply an ID in the URL instead, so the cast crashed. The binding now passes the optional ID/source into the controller, which fetches the deal through `DealRepo.fetchById` when there is no model argument. The screen shows loading while fetching and provides a retry for request failures; a successful ID lookup renders the normal deal details and add-to-bag action. `deal_details_controller_test.dart` verifies the ID-based path and analytics source.

### F-1 — Live flash-sale countdowns

A single app-wide `FlashSaleCountdownService` provides the current time and detects expirations. `FlashSaleCountdownText` subscribes to that clock, so each per-second update rebuilds only its countdown text; cards listen separately for the one-time expired state. The live timer is shown in the flash rail, home/search deal cards, and deal details. Expired deals are visibly disabled and cannot be added; the service removes expired flash-sale lines from the bag and shows a snackbar. Focused widget tests cover both countdown formats, ticking, expiration, and cart removal.

### F-2 — Impression tracking

`DealImpressionTracker` uses `VisibilityDetector` on each lazily built card and passes visibility changes to `AnalyticsService`. The service starts a one-second timer at 50% visibility, cancels it if visibility drops below 50%, and records each deal ID at most once per app session. Events include `deal_id`, the required `home_feed`/`flash_rail`/`search` source, and list position; they appear immediately on Analytics debug. Unsent events are posted through `FakeApiService.sendAnalyticsBatch` at 10 events or 15 seconds after the first queued event. Failed sends are logged and retained for a later retry. Countdown-independent impression timers are only active while a card qualifies as visible. `analytics_impression_test.dart` checks continuous visibility, session deduplication, event properties, and both batch thresholds.

## F-3 — Stock reservations

Adding a deal increments the bag immediately, then reserves one unit asynchronously. A failed reservation removes only its own optimistic unit and shows a friendly stock-availability message. Each confirmed unit keeps its reservation ID and expiry; the bag shows the shortest remaining hold, and decrement/remove releases the corresponding hold. Checkout is disabled while reservations are pending and sends every confirmed reservation ID to the backend.

**Expiry policy:** if a hold expires while the user is browsing, that unit is removed from the bag immediately and the user is told to add it again. If checkout returns `410` (the backend does not identify which hold expired), the whole bag is cleared, remaining holds are released, and the user is asked to rebuild the bag. This avoids retrying with stale or partially ambiguous reservation IDs and prevents the UI from implying that unreserved stock is still held. `cart_reservation_test.dart` covers optimistic success/failure, release behavior, expiry, checkout payloads, and the `410` response.

## 2. AI usage log

- Used repository search and targeted source/test reads to trace the ticket behaviors; edited the RES-106 model, RES-107 route/controller/screen, F-1 countdown/cart flows, F-2 visibility/batching analytics, F-3 reservation/cart flows, regression tests, and this write-up.
- Example 1: My initial notes treated RES-101–105 as unverified likely causes. Reading the actual controllers and regression tests showed the safeguards already present; I corrected the write-up to describe the implementation instead of presenting guesses as findings.
- Example 2: I initially described the time conversion helper as `marketTime`; checking the implementation showed its actual name is `_toMarketTime`. I corrected the description to match the code.

## 3. Design questions

### Q1: In this codebase, what is the difference between a `GetxController` lifecycle and a widget state `Lifecycle`? Name one bug from Part A that exists because of confusion between the two.

A `GetxController` lifecycle is the controller's own lifecycle under GetX dependency management — it is created, attached to a route, listens to reactive state, and is disposed when the route or binding is torn down. A widget state lifecycle is Flutter's widget tree lifecycle (`initState`, `didUpdateWidget`, `dispose`) and is tied to the UI element rendering in the widget tree.

A bug from Part A caused by confusing the two is RES-102: the countdown timer belongs to the widget `State`, so it must be cancelled in that state's `dispose`; disposing a route/controller does not itself cancel a timer owned by a widget state.

### Q2: When does wrapping a large subtree in a single `Obx` hurt you? How do you decide how tightly to scope reactivity?

A single `Obx` around a large subtree hurts performance when the subtree rebuilds too often, even when only a small portion of the UI actually changes. This causes unnecessary widget rebuilds, dropped frames, and wasted work during scrolling.

I scope reactivity by separating data that changes often from data that changes infrequently. Small, leaf-level reactive widgets are usually preferred for frequently updating text or counters. Broader `Obx` blocks are acceptable only when the subtree is small and the cost of rebuild is low; otherwise I split state into smaller reactive boundaries.

### Q3: How would you write an automated test that would have caught RES-106 before release? What (if anything) would you change in the code to make such a test possible?

I would add a unit test around `PickupWindowModel` that asserts the label and date checks for a UTC instant that crosses midnight or spans time zones. Example: a window from `2026-10-07T23:00:00.000Z` to `2026-10-08T02:30:00.000Z` should render as `06:00 – 09:30` in Bangkok time and `isToday` should be computed against the market date, not the device-local date.

The model tests cover the Bangkok label and compare full market dates across a UTC date boundary. To make `isToday` fully deterministic under any test clock, I would inject a clock or expose a method that accepts `now`; the current getter reads `DateTime.now()`.

## 4. Time spent, roughly, and what I would do next with one more day

Time spent: roughly 150 minutes total on investigation, RES-106/107, F-1/F-2/F-3 implementation, targeted tests, and this write-up.

With one more day, I would capture the requested before/after Android DevTools frame and memory profiles for RES-105, then test the reservation expiry/checkout experience end to end against the running app.
