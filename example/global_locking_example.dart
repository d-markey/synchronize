import 'dart:async';
import 'dart:math';

import 'impl/cache.dart';
import 'impl/data.dart';
import 'impl/eviction_strategy.dart';
import 'impl/utils.dart';

void main() async {
  final rnd = Random();
  var ids = List.generate(100, (i) {
    if (rnd.nextInt(10) < 4) {
      // full span = 10 .. 99
      return 10 + rnd.nextInt(90);
    } else {
      // most used span = 50 .. 59
      return 50 + rnd.nextInt(10);
    }
  });

  // allow for 10 (most used) + 5 (spare)
  final cache = Cache(15, loadData, EvictionStrategy(maxAgeInSeconds: 5),
      useLockers: false);
  final futures = <Future>[];

  for (var id in ids) {
    final fid = futures.length + 1;
    futures.add(Future(() async {
      Print.cyan('[$fid] Get data #$id from cache...');
      await randomDelay(factor: 20);
      final data = await cache.get(id);
      Print.cyan('[$fid] Data #${data.id} retrieved');
    }));
  }

  print('Waiting for ${futures.length} tasks to complete...');

  await Future.wait(futures);

  print('LOAD COUNTS:');
  for (var entries in cache.getLoadCounts()) {
    print('  * ${entries.key} loaded ${times(entries.value)}');
  }
}
