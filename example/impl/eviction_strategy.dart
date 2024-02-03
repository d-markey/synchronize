import 'cache_entry.dart';
import 'utils.dart';

class EvictionStrategy<T> {
  EvictionStrategy({this.maxAgeInSeconds = -1});

  final int maxAgeInSeconds;

  void evict(Map<int, CacheEntry<T>> cache, int count) {
    final list = cache.values.toList();
    if (count <= 0) {
      // nothing to do
    } else if (count >= list.length) {
      // full eviction
      cache.clear();
    } else {
      Print.yellow('EVICTION REQUESTED');
      // evict entries older than maxAgeInMs
      if (maxAgeInSeconds > 0) {
        list.sort((a, b) => a.counter.compareTo(b.counter));
        for (var item in list) {
          if (item.ageInSeconds > maxAgeInSeconds) {
            Print.yellow(
                'Evicted ${item.key} (age = ${item.ageInSeconds} / counter: ${item.counter} / lastUsed: ${DateTime.fromMillisecondsSinceEpoch(item.lastUsed)})');
            cache.remove(item.key);
            count--;
          }
        }
      }
      if (count > 0) {
        // now evict oldest and less used entries
        list.sort(_compare);
        for (var v in list) {
          Print.yellow(
              ' * ${v.key}: counter: ${v.counter} / lastUsed: ${DateTime.fromMillisecondsSinceEpoch(v.lastUsed)}');
        }
        final victims = list.take(count).map((_) => _.key).toSet();
        cache.removeWhere((key, value) => victims.contains(key));
        Print.yellow('Evicted ${victims.join(' ')}');
      }
    }
  }

  static int _compare<T>(CacheEntry<T> a, CacheEntry<T> b) {
    // lowest counters first
    var compare = a.counter.compareTo(b.counter);
    if (compare != 0) return compare;
    // otherwise oldest first
    compare = a.lastUsed.compareTo(b.lastUsed);
    return compare;
  }
}
