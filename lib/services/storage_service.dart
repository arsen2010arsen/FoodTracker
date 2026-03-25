import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/meal.dart';
import '../models/user_profile.dart';

class StorageService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  StorageService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Користувач не авторизований.');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _mealsCollection => _firestore
      .collection('users')
      .doc(_uid)
      .collection('meals');

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _firestore.collection('users').doc(_uid);

  DocumentReference<Map<String, dynamic>> get _profileDoc =>
      _userDoc.collection('profile').doc('main');

  Future<void> _ensureUserDocument() async {
    await _userDoc.set(
      {
        'uid': _uid,
        'updated_at': DateTime.now().toIso8601String(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> saveMeal(Meal meal) async {
    await _ensureUserDocument();
    await _mealsCollection.add(meal.toJson());
  }

  Future<List<Meal>> getMealsForDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final query = await _mealsCollection
        .where('logged_at', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('logged_at', isLessThan: end.toIso8601String())
        .get();

    final meals = query.docs.map((d) => Meal.fromJson(d.data())).toList()
      ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    return meals;
  }

  Future<void> saveUserProfile(Map<String, dynamic> profileJson) async {
    await _ensureUserDocument();
    await _profileDoc.set(profileJson);
  }

  Future<UserProfile?> getUserProfile() async {
    final snapshot = await _profileDoc.get();
    final data = snapshot.data();
    if (data == null) return null;
    return UserProfile.fromJson(data);
  }

  Future<void> clearUserProfile() async {
    await _profileDoc.delete();
  }

  Future<void> clearAllMeals() async {
    final snapshot = await _mealsCollection.get();
    if (snapshot.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
