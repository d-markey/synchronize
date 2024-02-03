import 'dart:async';

import 'package:synchronize/synchronize.dart';
import 'package:using/using.dart';

import 'cache_entry.dart';
import 'eviction_strategy.dart';
import 'utils.dart';

class Cache<T> {
  Cache(this.maxCapacity, this.loader, this.evictionStrategy,
      {required bool useLockers})
      : _lockers = useLockers ? {} : null;

  final int maxCapacity;
  final EvictionStrategy<T> evictionStrategy;
  final Future<T> Function(int) loader;

  final _cacheMap = <int, CacheEntry<T>>{};
  // lockers enable locking of individual cache entries
  final Map<int, Object>? _lockers;
  final _loadCounts = <int, int>{};

  Iterable<MapEntry<int, int>> getLoadCounts() => _loadCounts.entries;

  static int _nbCalls = 0;

  Future<T> get(int key) {
    final call = ++_nbCalls;

    // lock on _cacheMap when lockers are not available
    final locker = _lockers?.putIfAbsent(key, () => Object()) ?? _cacheMap;

    return ReaderWriterLock.read(locker).useAsync<T>((reader) async {
      Print.gray('[R/$call] checking $key (read lock)...');
      var entry = _cacheMap[key];
      if (entry == null) {
        Print.gray('[R/$call] $key not in cache, upgrading');
        entry = await reader.upgrade().useAsync<CacheEntry<T>>((writer) async {
          Print.gray('[U/$call]    checking $key (write lock)...');
          var entry = _cacheMap[key];
          if (entry == null) {
            // maybe loading the data involves calling a pay-per-call API
            // reader/writer lock will avoid costs due to loading the same
            // data multiple times
            Print.gray('[U/$call]    $key not in cache, load...');
            final data = await loader(key);
            _loadCounts[key] = (_loadCounts[key] ?? 0) + 1;
            entry = CacheEntry(key, data);
            if (_cacheMap.length >= maxCapacity) {
              evictionStrategy.evict(_cacheMap, _cacheMap.length - maxCapacity);
              // synchronize lockers if necessary
              _lockers?.removeWhere(
                  (k, v) => k != key && !_cacheMap.containsKey(k));
            }
            _cacheMap[key] = entry;
            Print.blue('[U/$call]    $key loaded...');
          } else {
            Print.green('[U/$call]    $key reload avoided! :)');
          }
          return entry;
        });
      }
      Print.gray('[R/$call] $key in cache');
      entry.update();
      return entry.data;
    });
  }
}
