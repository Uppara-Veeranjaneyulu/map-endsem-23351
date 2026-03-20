import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// `FirebaseOptions` for Android platform
class DefaultFirebaseOptions {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCbi2AYMXU_xsWuKHmM2niAWRU_FjmKV_M',
    appId: '1:979712552429:android:45df91d9bfe6197312cbe4',
    messagingSenderId: '979712552429',
    projectId: 'map-34c89',
    databaseURL: 'https://map-34c89.firebaseio.com',
    storageBucket: 'map-34c89.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCbi2AYMXU_xsWuKHmM2niAWRU_FjmKV_M',
    appId: '1:979712552429:web:YOUR_WEB_APP_ID',
    messagingSenderId: '979712552429',
    projectId: 'map-34c89',
    authDomain: 'map-34c89.firebaseapp.com',
    databaseURL: 'https://map-34c89.firebaseio.com',
    storageBucket: 'map-34c89.firebasestorage.app',
  );

  static const FirebaseOptions currentPlatform = web;
}
