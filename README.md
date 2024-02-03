# Synchronize

This package provides various synchronization implementations:

 * Lock for exclusive access
   This lock can be used to execute critical sections of code.
   The provided implementation supports reentrancy.

 * ReaderWriterLock for single writer/multiple reader synchronization
   The provided implementation does not supports reentrancy, but locks
   can be upgraded and/or downgraded.

 * Semaphore for single writer/multiple reader synchronization
   The provided implementation does not supports reentrancy, but locks
   can be upgraded and/or downgraded.

Implementations are based on package `using` and support automatic
releasing via `use()` / `useAsync()` / `execute()` / `executeAsync()`.

## Example

```
void main() {

  final cache = <String, Data>{};

  Future<Data?> fromCache(String key) =>
    ReaderWriterLock.read(cache).useAsync((reader) async {

      // multiple readers may retrieve some data from the cache
      if (cache.containsKey(key)) {
         return cache[key]!;
      }

      // when the data is not in cache, the lock is upgraded
      return reader.upgrade().useAsync((writer) async {
        // we now have exclusive access to load or compute data and update
        // the cache

        // ... load data, update cache ...
        return data;
      })
    });

}
```
