import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../models/food_item.dart';
import '../models/meal_log.dart';
import '../models/scan_event.dart';
import 'auth_service.dart';

class DatabaseService {
  static final _firestore = FirebaseFirestore.instance;

  // ---- Helpers ----
  static DocumentReference _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  static CollectionReference _mealLogs(String uid) =>
      _userDoc(uid).collection('meal_logs');

  static CollectionReference _scanEvents(String uid) =>
      _userDoc(uid).collection('scan_events');

  // ---- User ----
  Future<void> saveUser(UserProfile user) async {
    final uid = await AuthService.getOrCreateUserId();
    await _userDoc(uid).set(user.toMap(), SetOptions(merge: true));
  }

  Future<UserProfile?> getUser() async {
    final uid = AuthService.currentUserId;
    final snap = await _userDoc(uid).get();
    if (!snap.exists) return null;
    return UserProfile.fromMap(snap.data() as Map<String, dynamic>);
  }

  // ---- Meals ----
  Future<void> saveMealLog(MealLog meal) async {
    final uid = await AuthService.getOrCreateUserId();
    final data = meal.toMap();
    // Embed items directly in the meal document
    data['items'] = meal.items.map((i) => i.toMap()).toList();
    await _mealLogs(uid).doc(meal.id).set(data);
  }

  Future<List<MealLog>> getMealsForDate(String _, DateTime date) async {
    final uid = AuthService.currentUserId;
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final snap = await _mealLogs(uid)
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('dateTime', isLessThan: Timestamp.fromDate(end))
        .get();

    return snap.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((i) => FoodItem.fromMap(i as Map<String, dynamic>))
          .toList();
      return MealLog.fromMap(data, items);
    }).toList();
  }

  Future<void> deleteMealLog(String id) async {
    final uid = AuthService.currentUserId;
    await _mealLogs(uid).doc(id).delete();
  }

  Future<void> deleteItemFromMeal(String mealId, String itemId) async {
    final uid = AuthService.currentUserId;
    final doc = _mealLogs(uid).doc(mealId);
    final snap = await doc.get();
    if (!snap.exists) return;

    final data = snap.data() as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? [])
        .where((i) => (i as Map<String, dynamic>)['id'] != itemId)
        .toList();

    if (items.isEmpty) {
      await doc.delete();
    } else {
      await doc.update({'items': items});
    }
  }

  // ---- Scan Events ----
  Future<void> saveScanEvent(ScanEvent event) async {
    final uid = AuthService.currentUserId;
    await _scanEvents(uid).doc(event.id).set(event.toMap());
  }

  Future<List<ScanEvent>> getScanEvents(String _, {int limit = 50}) async {
    final uid = AuthService.currentUserId;
    final snap = await _scanEvents(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => ScanEvent.fromMap(d.data() as Map<String, dynamic>))
        .toList();
  }
}
