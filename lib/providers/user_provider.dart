import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';

class UserProvider extends ChangeNotifier {
  final DatabaseService _db;
  UserProfile? _user;
  bool _isLoading = true;
  String? _error;

  UserProvider(this._db);

  UserProfile? get user => _user;
  bool get isLoading => _isLoading;
  bool get isOnboarded => _user != null;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    try {
      _user = await _db.getUser();
    } catch (e) {
      _user = null;
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _db.saveUser(profile);
    _user = profile;
    notifyListeners();
  }

  Future<void> incrementScanCount() async {
    if (_user == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastScan = _user!.lastScanDate;

    int newCount = _user!.dailyScanCount;
    if (lastScan == null) {
      // First scan ever — start at 1
      newCount = 1;
    } else {
      final lastScanDay = DateTime(lastScan.year, lastScan.month, lastScan.day);
      if (lastScanDay.isAtSameMomentAs(today)) {
        // Same day — increment
        newCount = _user!.dailyScanCount + 1;
      } else {
        // New day — reset and start at 1
        newCount = 1;
      }
    }

    _user = _user!.copyWith(
      dailyScanCount: newCount,
      lastScanDate: now,
    );
    await _db.saveUser(_user!);
    notifyListeners();
  }

  Future<void> resetDailyScanCount() async {
    if (_user == null) return;
    _user = _user!.copyWith(dailyScanCount: 0, lastScanDate: null);
    await _db.saveUser(_user!);
    notifyListeners();
  }

  Future<void> setPro(bool value) async {
    if (_user == null) return;
    _user = _user!.copyWith(isPro: value);
    await _db.saveUser(_user!);
    notifyListeners();
  }
}
