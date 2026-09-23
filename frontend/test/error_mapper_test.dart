import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/error_mapper.dart';

void main() {
  group('ErrorMapper.map', () {
    test('maps TimeoutException', () {
      expect(
        ErrorMapper.map(TimeoutException('slow')),
        'Request timed out. Please try again.',
      );
    });

    test('maps SocketException', () {
      expect(
        ErrorMapper.map(const SocketException('down')),
        'No internet connection. Check your network and try again.',
      );
    });

    test('maps HttpException', () {
      expect(
        ErrorMapper.map(const HttpException('bad')),
        'Could not connect to the server.',
      );
    });

    test('maps FormatException', () {
      expect(
        ErrorMapper.map(const FormatException('bad json')),
        'Received an invalid response from the server.',
      );
    });

    test('maps 401 to session expired', () {
      expect(
        ErrorMapper.map(Exception('Server error 401')),
        'Your session has expired. Please log in again.',
      );
    });

    test('maps 403 to permission denied', () {
      expect(
        ErrorMapper.map(Exception('Server error 403')),
        "You don't have permission for that action.",
      );
    });

    test('maps 404 to not found', () {
      expect(
        ErrorMapper.map(Exception('Server error 404')),
        'The requested resource was not found.',
      );
    });

    test('maps 429 to rate limited', () {
      expect(
        ErrorMapper.map(Exception('Server error 429')),
        'Too many requests. Please wait a moment and try again.',
      );
    });

    test('maps 5xx to server error', () {
      expect(
        ErrorMapper.map(Exception('Server error 500')),
        'Something went wrong on our end. Please try again later.',
      );
      expect(
        ErrorMapper.map(Exception('Server error 503')),
        'Something went wrong on our end. Please try again later.',
      );
    });

    test('strips Exception: prefix for short messages', () {
      expect(
        ErrorMapper.map(Exception('Email already registered')),
        'Email already registered',
      );
    });

    test('replaces very long messages with generic fallback', () {
      final long = 'x' * 200;
      expect(
        ErrorMapper.map(Exception(long)),
        'Something went wrong. Please try again.',
      );
    });

    test('null maps to generic message', () {
      expect(ErrorMapper.map(null), 'An unexpected error occurred.');
    });
  });
}
