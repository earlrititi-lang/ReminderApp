import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

bool isFirebaseConfiguredForCurrentPlatform() {
  try {
    DefaultFirebaseOptions.currentPlatform;
    return true;
  } catch (_) {
    return false;
  }
}

bool isFirebaseAvailable() {
  return isFirebaseConfiguredForCurrentPlatform() && Firebase.apps.isNotEmpty;
}
