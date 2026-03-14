// File generated manually for project: mesh-net-6f9a0
// Platform: Android

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web not supported');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Platform not supported');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDRIyW4AIbQSToojaH4UtXyLI0_inpRu1c',
    appId: '1:35996124346:android:d5342c06b2edaca44aee83',
    messagingSenderId: '35996124346',
    projectId: 'mesh-net-6f9a0',
    databaseURL: 'https://mesh-net-6f9a0-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'mesh-net-6f9a0.firebasestorage.app',
  );
}
