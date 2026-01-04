import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../state/save_load_service.dart';
import '../state/game_state.dart';

/// Service to save/load GlobalGameState to Firestore under `users/{uid}/saveSlots/slot_0`.
class CloudSaveService {
  static final _firestore = FirebaseFirestore.instance;

  /// Save the provided [state] to the cloud for the current user.
  /// Throws if there is no signed-in user.
  static Future<void> saveToCloud(GlobalGameState state) async {
    if (Platform.isMacOS) {
      print('CloudSaveService: skipping cloud save on macOS (disabled)');
      return;
    }
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('CloudSaveService.saveToCloud: no authenticated user; attempting sign-in');
      // Try anonymous sign-in a few times with short delays to cope with
      // desktop initialization timing where Firebase may finish shortly.
      for (var attempt = 1; attempt <= 3 && FirebaseAuth.instance.currentUser == null; attempt++) {
        try {
          final cred = await FirebaseAuth.instance.signInAnonymously().timeout(const Duration(seconds: 5));
          user = cred.user;
          if (user != null) break;
        } catch (e) {
          print('CloudSaveService: anonymous sign-in attempt $attempt failed: $e');
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }

    if (user == null) {
      print('CloudSaveService.saveToCloud: still no authenticated user after retries; aborting cloud save');
      return; // non-fatal: keep local save only
    }

    final docRef = _firestore.collection('users').doc(user.uid)
      .collection('saveSlots').doc('slot_0');

    final serialized = SaveLoadService.serializeGameState(state);
    print('CloudSaveService.saveToCloud: saving for user ${user.uid}');

    await docRef.set({
      'data': serialized,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    print('CloudSaveService.saveToCloud: save completed for user ${user.uid}');
  }

  /// Load the cloud save for the current user. Returns null if no document found.
  static Future<GlobalGameState?> loadFromCloud() async {
    if (Platform.isMacOS) {
      print('CloudSaveService: skipping cloud load on macOS (disabled)');
      return null;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final docRef = _firestore.collection('users').doc(user.uid)
      .collection('saveSlots').doc('slot_0');

    final snapshot = await docRef.get();
    if (!snapshot.exists) return null;

    final data = snapshot.data();
    if (data == null) return null;

    final jsonString = data['data'] as String?;
    if (jsonString == null || jsonString.isEmpty) return null;

    final state = SaveLoadService.deserializeGameState(jsonString);
    return state;
  }

  /// Resolve conflict between local and cloud states.
  /// Returns the chosen state (local or cloud). Throws if manual resolution required.
  static GlobalGameState resolveConflict(GlobalGameState local, GlobalGameState cloud) {
    // Prefer the state with higher dayCount
    if (cloud.dayCount > local.dayCount) return cloud;
    if (local.dayCount > cloud.dayCount) return local;

    // If dayCount equal, prefer higher currentDayRevenue
    if (cloud.currentDayRevenue > local.currentDayRevenue) return cloud;
    if (local.currentDayRevenue > cloud.currentDayRevenue) return local;

    // If still tied, consider equal and return local by default
    // Caller can throw if they want explicit UI conflict resolution
    return local;
  }
}
