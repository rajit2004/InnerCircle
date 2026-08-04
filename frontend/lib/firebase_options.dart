// ============================================================================
// PLACEHOLDER FILE -- DO NOT SHIP THESE VALUES
// ============================================================================
//
// FEATURE (push notifications, 2026-07-05): every value below is a fake
// placeholder. This file cannot be generated correctly without your actual
// Firebase project, which only you can create (it needs your Google account
// and the Firebase console). See PUSH_NOTIFICATIONS_SETUP.md for the full
// walkthrough, but the short version:
//
//   1. dart pub global activate flutterfire_cli
//   2. flutterfire configure
//
// That command logs into your Firebase account, lets you pick/create a
// project, and OVERWRITES this exact file with your real apiKey, appId,
// projectId, and messagingSenderId. Do that -- don't hand-edit the values
// below, they won't work no matter what you type in.
//
// Kept here (rather than leaving the file missing) purely so the rest of
// the app's imports resolve and the project stays compilable while you do
// the Firebase console setup -- main.dart's Firebase.initializeApp() call
// will fail at runtime with these placeholder values until you run
// flutterfire configure.
// ============================================================================

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web -- '
            'this app targets Android. Run `flutterfire configure` if you '
            'need web support too.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are only configured for Android in this '
              'project. Run `flutterfire configure` to add iOS/other platforms.',
        );
    }
  }

  // PLACEHOLDER -- replace by running `flutterfire configure`, do not
  // hand-edit these strings.

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBzevBtrmk01HJTyIh_0NdJtLkmUfaeSpY',
    appId: '1:608403460456:android:4f05afc053ba7c900406dd',
    messagingSenderId: '608403460456',
    projectId: 'ranesh-innercircle',
    storageBucket: 'ranesh-innercircle.firebasestorage.app',
  );
}
