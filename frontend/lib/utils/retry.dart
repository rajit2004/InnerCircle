// Retry utility with exponential backoff for frontend operations.

import 'dart:async';
import 'dart:math';

/// Configuration for retry behavior.
class RetryConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final double jitterFactor;
  final List<int> retryableStatusCodes;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 10),
    this.backoffMultiplier = 2.0,
    this.jitterFactor = 0.1,
    this.retryableStatusCodes = const [408, 429, 500, 502, 503, 504],
  });

  /// Creates a config optimized for API retries (e.g., Groq calls).
  static const RetryConfig apiDefault = RetryConfig(
    maxAttempts: 3,
    initialDelay: Duration(milliseconds: 1000),
    maxDelay: Duration(seconds: 30),
    backoffMultiplier: 2.0,
    jitterFactor: 0.15,
    retryableStatusCodes: [408, 429, 500, 502, 503, 504],
  );

  /// Creates a config for user-initiated retries (faster, fewer attempts).
  static const RetryConfig userRetry = RetryConfig(
    maxAttempts: 2,
    initialDelay: Duration(milliseconds: 500),
    maxDelay: Duration(seconds: 5),
    backoffMultiplier: 2.0,
    jitterFactor: 0.1,
  );
}

/// Exception thrown when all retry attempts are exhausted.
class RetryExhaustedException implements Exception {
  final int attempts;
  final Object lastError;

  RetryExhaustedException(this.attempts, this.lastError);

  @override
  String toString() =>
      'RetryExhaustedException after $attempts attempts: $lastError';
}

/// Executes [operation] with exponential backoff retry logic.
///
/// Returns the result of the successful operation.
/// Throws [RetryExhaustedException] if all attempts fail.
Future<T> retryWithBackoff<T>(
  Future<T> Function() operation, {
  RetryConfig config = RetryConfig.apiDefault,
  bool Function(Object error)? isRetryable,
  void Function(int attempt, Duration delay, Object error)? onRetry,
}) async {
  var attempt = 0;
  var delay = config.initialDelay;
  Object? lastError;

  while (attempt < config.maxAttempts) {
    try {
      return await operation();
    } catch (e) {
      lastError = e;
      attempt++;

      if (attempt >= config.maxAttempts) {
        break;
      }

      // Check if error is retryable
      bool shouldRetry =
          isRetryable?.call(e) ?? _isRetryableByDefault(e, config);
      if (!shouldRetry) {
        rethrow;
      }

      // Apply jitter to prevent thundering herd
      final jitter =
          delay.inMilliseconds *
          config.jitterFactor *
          (Random().nextDouble() * 2 - 1);
      final actualDelay = Duration(
        milliseconds: (delay.inMilliseconds + jitter)
            .clamp(0, config.maxDelay.inMilliseconds)
            .round(),
      );

      if (onRetry != null) {
        onRetry(attempt, actualDelay, e);
      }

      await Future.delayed(actualDelay);
      delay = Duration(
        milliseconds: (delay.inMilliseconds * config.backoffMultiplier)
            .clamp(0, config.maxDelay.inMilliseconds)
            .round(),
      );
    }
  }

  throw RetryExhaustedException(config.maxAttempts, lastError!);
}

/// Default retryability check based on status codes and error types.
bool _isRetryableByDefault(Object error, RetryConfig config) {
  // Check for HTTP status codes in error message
  final errorStr = error.toString().toLowerCase();
  for (final code in config.retryableStatusCodes) {
    if (errorStr.contains(code.toString()) ||
        errorStr.contains('status $code') ||
        errorStr.contains('status=$code')) {
      return true;
    }
  }

  // Check for common retryable error patterns
  if (errorStr.contains('timeout') ||
      errorStr.contains('connection') ||
      errorStr.contains('socket') ||
      errorStr.contains('network') ||
      errorStr.contains('dns') ||
      errorStr.contains('rate limit') ||
      errorStr.contains('too many requests')) {
    return true;
  }

  return false;
}
