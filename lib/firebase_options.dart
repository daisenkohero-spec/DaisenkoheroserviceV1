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
    apiKey: 'AIzaSyC05cIeLYivRFVtkl9OvclUDTXW4qUJjfg',
    appId: '1:519440484589:android:403384608f2306f5a724e4',
    messagingSenderId: '519440484589',
    projectId: 'daisenkoheroservicev1',
    storageBucket: 'daisenkoheroservicev1.firebasestorage.app',
  );
  // Register a Web app in Firebase Console to get a dedicated web appId.

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCP9L2LwA3773Q81Gp2wmXc-qEHBHJkGqI',
    appId: '1:519440484589:web:f8de880f85f383a1a724e4',
    messagingSenderId: '519440484589',
    projectId: 'daisenkoheroservicev1',
    authDomain: 'daisenkoheroservicev1.firebaseapp.com',
    storageBucket: 'daisenkoheroservicev1.firebasestorage.app',
    measurementId: 'G-EKQNS3XSEM',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyByRT4Fu88pNa4msfhnLrX9QH2QRzimXB0',
    appId: '1:519440484589:ios:9f375fc56d9af962a724e4',
    messagingSenderId: '519440484589',
    projectId: 'daisenkoheroservicev1',
    storageBucket: 'daisenkoheroservicev1.firebasestorage.app',
    iosBundleId: 'com.example.projectTechniqian',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyByRT4Fu88pNa4msfhnLrX9QH2QRzimXB0',
    appId: '1:519440484589:ios:9f375fc56d9af962a724e4',
    messagingSenderId: '519440484589',
    projectId: 'daisenkoheroservicev1',
    storageBucket: 'daisenkoheroservicev1.firebasestorage.app',
    iosBundleId: 'com.example.projectTechniqian',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCP9L2LwA3773Q81Gp2wmXc-qEHBHJkGqI',
    appId: '1:519440484589:web:fee64a2288313e76a724e4',
    messagingSenderId: '519440484589',
    projectId: 'daisenkoheroservicev1',
    authDomain: 'daisenkoheroservicev1.firebaseapp.com',
    storageBucket: 'daisenkoheroservicev1.firebasestorage.app',
    measurementId: 'G-D679QV9SXB',
  );
}
