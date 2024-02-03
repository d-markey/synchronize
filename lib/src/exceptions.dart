class SemaphoreFullException implements Exception {
  SemaphoreFullException([this.message = 'Semaphore is full']);

  final String message;
}
