import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration for the Daisenko Hero Service app.
/// Generated from `android/app/google-services.json`.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAu5ZnM0JpsF-HoaQHFHriHZkTp_Gv1lHY',
    appId: '1:408424583515:android:d8cf3e093270ff7e390a7e',
    messagingSenderId: '408424583515',
    projectId: 'air-cleaning-test',
    storageBucket: 'air-cleaning-test.firebasestorage.app',
  );

  // Register a Web app in Firebase Console to get a dedicated web appId.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAu5ZnM0JpsF-HoaQHFHriHZkTp_Gv1lHY',
    appId: '1:408424583515:web:daisenko-hero-service',
    messagingSenderId: '408424583515',
    projectId: 'air-cleaning-test',
    authDomain: 'air-cleaning-test.firebaseapp.com',
    storageBucket: 'air-cleaning-test.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAu5ZnM0JpsF-HoaQHFHriHZkTp_Gv1lHY',
    appId: '1:408424583515:ios:daisenko-hero-service',
    messagingSenderId: '408424583515',
    projectId: 'air-cleaning-test',
    storageBucket: 'air-cleaning-test.firebasestorage.app',
    iosBundleId: 'com.example.projectTechniqian',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAu5ZnM0JpsF-HoaQHFHriHZkTp_Gv1lHY',
    appId: '1:408424583515:ios:daisenko-hero-service',
    messagingSenderId: '408424583515',
    projectId: 'air-cleaning-test',
    storageBucket: 'air-cleaning-test.firebasestorage.app',
    iosBundleId: 'com.example.projectTechniqian',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAu5ZnM0JpsF-HoaQHFHriHZkTp_Gv1lHY',
    appId: '1:408424583515:web:daisenko-hero-service',
    messagingSenderId: '408424583515',
    projectId: 'air-cleaning-test',
    authDomain: 'air-cleaning-test.firebaseapp.com',
    storageBucket: 'air-cleaning-test.firebasestorage.app',
  );
}
