import 'dart:async';
import 'dart:io';

class ErrorMapper {
  ErrorMapper._();

  static String map(dynamic error) {
    if (error is TimeoutException) {
      return 'Request timed out. Please try again.';
    }
    if (error is SocketException) {
      return 'No internet connection. Check your network and try again.';
    }
    if (error is HttpException) {
      return 'Could not connect to the server.';
    }
    if (error is FormatException) {
      return 'Received an invalid response from the server.';
    }

    final message = error?.toString() ?? 'An unexpected error occurred.';

    if (message.contains('Server error 401')) {
      return 'Your session has expired. Please log in again.';
    }
    if (message.contains('Server error 403')) {
      return 'You don\'t have permission for that action.';
    }
    if (message.contains('Server error 404')) {
      return 'The requested resource was not found.';
    }
    if (message.contains('Server error 429')) {
      return 'Too many requests. Please wait a moment and try again.';
    }
    if (message.contains('Server error 5')) {
      return 'Something went wrong on our end. Please try again later.';
    }

    final clean = message.replaceFirst('Exception: ', '');
    if (clean.length > 120) {
      return 'Something went wrong. Please try again.';
    }
    return clean;
  }
}
