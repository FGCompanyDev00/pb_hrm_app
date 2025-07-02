import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pb_hrsystem/core/services/performance_cache_service.dart';
import 'package:pb_hrsystem/core/services/performance_data_service.dart';
import 'package:pb_hrsystem/models/event.dart';

/// Normalizes the date by removing the time component
DateTime normalizeDate(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

/// High-performance calendar controller that manages data and state efficiently
class CalendarController extends ChangeNotifier {
  // Private state variables
  List<Events> _eventsForAll = [];
  List<Events> _eventsForDay = [];
  DateTime? _selectedDay;
  bool _isLoading = false;
  bool _isBackgroundLoading = false;
  String _selectedCategory = 'All';
  String _searchQuery = '';

  // Cache management
  final Map<DateTime, List<Events>> _eventCache = {};
  final Map<DateTime, Map<String, int>> _eventCountsCache = {};
  Timer? _cacheCleanupTimer;

  // Getters for UI
  List<Events> get eventsForAll => List.unmodifiable(_eventsForAll);
  List<Events> get eventsForDay => List.unmodifiable(_eventsForDay);
  DateTime? get selectedDay => _selectedDay;
  bool get isLoading => _isLoading;
  bool get isBackgroundLoading => _isBackgroundLoading;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  CalendarController() {
    _initializeController();
  }

  /// Initialize controller with performance optimizations
  void _initializeController() {
    _selectedDay = DateTime.now().toLocal();
    _setupCacheCleanup();
    _loadInitialData();
  }

  /// Setup automatic cache cleanup to prevent memory leaks
  void _setupCacheCleanup() {
    _cacheCleanupTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _cleanupExpiredCache(),
    );
  }

  /// Load initial data with smart caching strategy
  Future<void> _loadInitialData() async {
    try {
      // Try to load from cache first
      final hasCache = await _loadFromCache();

      if (hasCache) {
        // Show cached data immediately
        _setBackgroundLoading(true);
        _filterAndSearchEvents();

        // Fetch fresh data in background
        await _fetchFreshDataSilently();
      } else {
        // No cache available, show loading and fetch
        _setLoading(true);
        await fetchAllCalendarData();
      }
    } catch (e) {
      debugPrint('Error loading initial calendar data: $e');
      _setLoading(false);
    }
  }

  /// Load calendar events from cache
  Future<bool> _loadFromCache() async {
    try {
      final cachedEvents =
          await PerformanceCacheService.getCachedCalendarEvents();
      if (cachedEvents != null && cachedEvents.isNotEmpty) {
        _eventsForAll = cachedEvents.map((e) => Events.fromJson(e)).toList();
        _rebuildEventCache();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error loading calendar cache: $e');
      return false;
    }
  }

  /// Fetch fresh data silently without disrupting UI
  Future<void> _fetchFreshDataSilently() async {
    try {
      final freshEvents = await PerformanceDataService.fetchCalendarEvents(
        forceRefresh: true,
      );

      // Update only if we have new data
      if (freshEvents.isNotEmpty) {
        _eventsForAll = freshEvents.map((e) => Events.fromJson(e)).toList();
        _rebuildEventCache();
        _filterAndSearchEvents();

        // Cache the fresh data
        await PerformanceCacheService.cacheCalendarEvents(
          freshEvents,
        );
      }
    } catch (e) {
      debugPrint('Error fetching fresh calendar data: $e');
    } finally {
      _setBackgroundLoading(false);
    }
  }

  /// Fetch all calendar data from APIs
  Future<void> fetchAllCalendarData({bool showLoading = true}) async {
    if (showLoading) _setLoading(true);

    try {
      final freshEvents = await PerformanceDataService.fetchCalendarEvents();

      _eventsForAll = freshEvents.map((e) => Events.fromJson(e)).toList();
      _rebuildEventCache();
      _filterAndSearchEvents();
    } catch (e) {
      debugPrint('Error fetching calendar data: $e');
      // On error, try to load from cache as fallback
      await _loadFromCache();
    } finally {
      _setLoading(false);
    }
  }

  /// Rebuild event cache for fast lookups
  void _rebuildEventCache() {
    _eventCache.clear();
    _eventCountsCache.clear();

    for (final event in _eventsForAll) {
      final normalizedStart = normalizeDate(event.startDateTime);
      final normalizedEnd = normalizeDate(event.endDateTime);

      // Add event to each day in its range
      for (var day = normalizedStart;
          !day.isAfter(normalizedEnd);
          day = day.add(const Duration(days: 1))) {
        if (!_eventCache.containsKey(day)) {
          _eventCache[day] = [];
        }

        // Avoid duplicates
        if (!_eventCache[day]!.any((e) => e.uid == event.uid)) {
          _eventCache[day]!.add(event);
        }
      }
    }
  }

  /// Get events for a specific day (optimized with caching)
  List<Events> getEventsForDay(DateTime day) {
    final normalizedDay = normalizeDate(day);
    return _eventCache[normalizedDay] ?? [];
  }

  /// Get event counts by category for a specific day
  Map<String, int> getEventCountsByCategory(DateTime day) {
    final normalizedDay = normalizeDate(day);

    if (_eventCountsCache.containsKey(normalizedDay)) {
      return _eventCountsCache[normalizedDay]!;
    }

    final events = getEventsForDay(day);
    final counts = <String, int>{};

    for (final event in events) {
      counts[event.category] = (counts[event.category] ?? 0) + 1;
    }

    _eventCountsCache[normalizedDay] = counts;
    return counts;
  }

  /// Update selected day and filter events
  void updateSelectedDay(DateTime newDay) {
    if (_selectedDay != newDay) {
      _selectedDay = newDay;
      _filterAndSearchEvents();
      notifyListeners();
    }
  }

  /// Update category filter
  void updateCategoryFilter(String category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      _filterAndSearchEvents();
      notifyListeners();
    }
  }

  /// Update search query
  void updateSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      _filterAndSearchEvents();
      notifyListeners();
    }
  }

  /// Filter and search events efficiently
  void _filterAndSearchEvents() {
    if (_selectedDay == null) return;

    List<Events> dayEvents = getEventsForDay(_selectedDay!);

    // Apply category filter
    if (_selectedCategory != 'All') {
      dayEvents = dayEvents
          .where((event) => event.category == _selectedCategory)
          .toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      dayEvents = dayEvents.where((event) {
        final title = event.title.toLowerCase();
        final description = event.description.toLowerCase();
        return title.contains(query) || description.contains(query);
      }).toList();
    }

    _eventsForDay = dayEvents;
  }

  /// Refresh calendar data with pull-to-refresh
  Future<void> refreshCalendarData() async {
    await fetchAllCalendarData(showLoading: false);
  }

  /// Clean up expired cache entries to prevent memory leaks
  void _cleanupExpiredCache() {
    final now = DateTime.now();
    const maxAge = Duration(days: 7);

    // Remove old event cache entries
    _eventCache.removeWhere((date, events) => now.difference(date) > maxAge);

    // Remove old count cache entries
    _eventCountsCache
        .removeWhere((date, counts) => now.difference(date) > maxAge);

    // Clean up service-level caches
    PerformanceCacheService.clearExpiredMemoryCache();
  }

  /// Force complete refresh of all data
  Future<void> forceCompleteRefresh() async {
    try {
      _setLoading(true);

      // Clear all caches
      _eventCache.clear();
      _eventCountsCache.clear();
      _eventsForAll.clear();
      _eventsForDay.clear();

      await PerformanceCacheService.clearAllCaches();

      // Fetch everything fresh
      await fetchAllCalendarData(showLoading: false);
    } catch (e) {
      debugPrint('Error during force refresh: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Add a new event to the calendar
  void addEvent(Events event) {
    _eventsForAll.add(event);
    _rebuildEventCache();
    _filterAndSearchEvents();
    notifyListeners();

    // Update cache asynchronously
    _updateCacheAsync();
  }

  /// Update cache in background
  void _updateCacheAsync() {
    Future(() async {
      try {
        final eventsJson = _eventsForAll.map((e) => e.toJson()).toList();
        await PerformanceCacheService.cacheCalendarEvents(eventsJson);
      } catch (e) {
        debugPrint('Error updating calendar cache: $e');
      }
    });
  }

  /// Set loading state
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// Set background loading state
  void _setBackgroundLoading(bool loading) {
    if (_isBackgroundLoading != loading) {
      _isBackgroundLoading = loading;
      notifyListeners();
    }
  }

  /// Get statistics for debugging
  Map<String, dynamic> getStatistics() {
    return {
      'total_events': _eventsForAll.length,
      'events_for_selected_day': _eventsForDay.length,
      'cached_days': _eventCache.length,
      'cache_counts_days': _eventCountsCache.length,
      'selected_day': _selectedDay?.toIso8601String(),
      'selected_category': _selectedCategory,
      'search_query': _searchQuery,
      'is_loading': _isLoading,
      'is_background_loading': _isBackgroundLoading,
    };
  }

  @override
  void dispose() {
    _cacheCleanupTimer?.cancel();
    _eventCache.clear();
    _eventCountsCache.clear();
    super.dispose();
  }
}
