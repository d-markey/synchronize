class CacheEntry<T> {
  CacheEntry(this.key, this.data);

  final T data;
  int key;
  int _counter = 0;
  int _lastUsed = 0;

  int get counter => _counter;
  int get lastUsed => _lastUsed;

  int get ageInSeconds =>
      (DateTime.now().millisecondsSinceEpoch - _lastUsed) ~/ 1000;

  void update() {
    _counter++;
    _lastUsed = DateTime.now().millisecondsSinceEpoch;
  }
}
