import 'package:firebase_core/firebase_core.dart';

/// Web + default Firebase options (same project as `mego-c43a7`).
class FirebaseConfig {
  FirebaseConfig._();

  /// Default Storage bucket (matches download URLs like .../b/mego-c43a7.firebasestorage.app/...).
  static const String storageBucketGs = 'gs://mego-c43a7.firebasestorage.app';

  static const FirebaseOptions options = FirebaseOptions(
    apiKey: 'AIzaSyDZYU1HQ5Xav76qKwbt4o-ydMFmmJsD084',
    authDomain: 'mego-c43a7.firebaseapp.com',
    projectId: 'mego-c43a7',
    storageBucket: 'mego-c43a7.firebasestorage.app',
    messagingSenderId: '1057585249956',
    appId: '1:1057585249956:web:2093b3238eaff7e1c0f031',
    measurementId: 'G-YK9P98TNQ7',
  );
}
