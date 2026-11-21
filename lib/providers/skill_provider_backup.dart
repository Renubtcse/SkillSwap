
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SkillProvider extends ChangeNotifier {
  // Profile details
  String _studentName = 'Student Name';
  String _email = 'student@example.com';
  String _college = 'IGDTUW, Delhi';

  String get studentName => _studentName;
  String get email => _email;
  String get college => _college;

  // Time credits
  int _credits = 5;
  int get credits => _credits;

  // Firebase skills
  final List<Map<String, dynamic>> _skills = [];

  // Legacy demo incoming requests
  final List<Map<String, dynamic>> _incomingRequests = [
    {
      'name': 'Rahul Mehta',
      'skill': 'Python Programming',
      'message': 'I want to learn Python basics.',
      'credits': '2 Credits/hour',
      'status': 'Pending',
    },
    {
      'name': 'Ananya Gupta',
      'skill': 'Flutter Development',
      'message': 'I want to learn mobile app development.',
      'credits': '2 Credits/hour',
      'status': 'Pending',
    },
    {
      'name': 'Karan Malhotra',
      'skill': 'UI/UX Design',
      'message': 'I am interested in learning UI design.',
      'credits': '1 Credit/hour',
      'status': 'Pending',
    },
  ];

  final List<Map<String, dynamic>> _sentRequests = [];
  final List<Map<String, dynamic>> _sessionHistory = [];

  List<Map<String, dynamic>> get skills => _skills;

  List<Map<String, dynamic>> get incomingRequests =>
      _incomingRequests;

  List<Map<String, dynamic>> get sentRequests => _sentRequests;

  List<Map<String, dynamic>> get sessionHistory => _sessionHistory;

  late final Future<void> _loadFuture;

  StreamSubscription<User?>? _authSubscription;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _skillsSubscription;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _profileSubscription;

  SkillProvider() {
    _loadFuture = _loadData();

    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen(
      _handleAuthChange,
    );
  }

  // Handle login and logout
  Future<void> _handleAuthChange(User? user) async {
    await _skillsSubscription?.cancel();
    await _profileSubscription?.cancel();

    if (user == null) {
      _skills.clear();
      notifyListeners();
      return;
    }

    await _loadFuture;

    // Listen to logged-in student's Firebase profile
    _profileSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen(
      (document) async {
        if (document.exists) {
          final data = document.data()!;

          _studentName = data['name'] ?? _studentName;
          _email = data['email'] ?? user.email ?? _email;
          _college = data['college'] ?? _college;

          if (data['credits'] is num) {
            _credits = (data['credits'] as num).toInt();
          }

          await _saveData();
          notifyListeners();
        }
      },
      onError: (error) {
        debugPrint('Profile sync error: $error');
      },
    );

    // Listen to published skills in real time
    _skillsSubscription = FirebaseFirestore.instance
        .collection('skills')
        .snapshots()
        .listen(
      (snapshot) {
        _skills
          ..clear()
          ..addAll(
            snapshot.docs.map((document) {
              return {
                ...document.data(),
                'id': document.id,
              };
            }),
          );

        notifyListeners();
      },
      onError: (error) {
        debugPrint('Skills sync error: $error');
      },
    );
  }

  // Load locally saved data
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    _studentName =
        prefs.getString('studentName') ?? _studentName;

    _email = prefs.getString('email') ?? _email;

    _college = prefs.getString('college') ?? _college;

    _credits = prefs.getInt('credits') ?? 5;

    final savedRequests = prefs.getString('sentRequests');
    final savedIncoming = prefs.getString('incomingRequests');
    final savedHistory = prefs.getString('sessionHistory');

    if (savedRequests != null) {
      final decoded = jsonDecode(savedRequests) as List;

      _sentRequests
        ..clear()
        ..addAll(
          decoded.map(
            (item) => Map<String, dynamic>.from(item),
          ),
        );
    }

    if (savedIncoming != null) {
      final decoded = jsonDecode(savedIncoming) as List;

      _incomingRequests
        ..clear()
        ..addAll(
          decoded.map(
            (item) => Map<String, dynamic>.from(item),
          ),
        );
    }

    if (savedHistory != null) {
      final decoded = jsonDecode(savedHistory) as List;

      _sessionHistory
        ..clear()
        ..addAll(
          decoded.map(
            (item) => Map<String, dynamic>.from(item),
          ),
        );
    }

    notifyListeners();
  }

  // Save locally stored data
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('studentName', _studentName);
    await prefs.setString('email', _email);
    await prefs.setString('college', _college);

    await prefs.setInt('credits', _credits);

    await prefs.setString(
      'sentRequests',
      jsonEncode(_sentRequests),
    );

    await prefs.setString(
      'incomingRequests',
      jsonEncode(_incomingRequests),
    );

    await prefs.setString(
      'sessionHistory',
      jsonEncode(_sessionHistory),
    );
  }

  // Update profile locally and in Firebase
  Future<void> updateProfile({
    required String name,
    required String email,
    required String college,
  }) async {
    await _loadFuture;

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'name': name,
        'email': email,
        'college': college,
      });
    }

    _studentName = name;
    _email = email;
    _college = college;

    await _saveData();
    notifyListeners();
  }

  // Add a skill to Firebase
  Future<void> addSkill({
    required String studentName,
    required String skillName,
    required String category,
    required String level,
    required int credits,
    required String description,
  }) async {
    await _loadFuture;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Please login to publish a skill.');
    }

    final actualName = _studentName.trim().isNotEmpty &&
            _studentName != 'Student Name'
        ? _studentName.trim()
        : studentName.trim();

    if (actualName.isEmpty || actualName == 'Student Name') {
      throw Exception('Please complete your profile first.');
    }

    await FirebaseFirestore.instance.collection('skills').add({
      'studentName': actualName,
      'skillName': skillName,
      'category': category,
      'level': level,
      'credits': credits,
      'description': description,
      'initial': actualName[0].toUpperCase(),
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete a skill published by the current user
  Future<bool> deleteSkill(
    Map<String, dynamic> skill,
  ) async {
    await _loadFuture;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return false;

    final skillId = skill['id'];

    if (skillId == null || skill['createdBy'] != user.uid) {
      return false;
    }

    await FirebaseFirestore.instance
        .collection('skills')
        .doc(skillId.toString())
        .delete();

    return true;
  }

  // Send a real learning request to Firebase
  Future<void> sendRequest(
    Map<String, dynamic> skill,
  ) async {
    await _loadFuture;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Please login first.');
    }

    final receiverUid = skill['createdBy']?.toString();
    final skillId = skill['id']?.toString();

    if (receiverUid == null ||
        receiverUid.isEmpty ||
        skillId == null ||
        skillId.isEmpty) {
      throw Exception('Invalid skill or student information.');
    }

    if (receiverUid == user.uid) {
      throw Exception('You cannot request your own skill.');
    }

    // Check for an existing pending request
    final existingRequests = await FirebaseFirestore.instance
        .collection('requests')
        .where('requesterUid', isEqualTo: user.uid)
        .where('skillId', isEqualTo: skillId)
        .get();

    final alreadyPending = existingRequests.docs.any(
      (document) =>
          document.data()['status'] == 'Pending',
    );

    if (alreadyPending) {
      throw Exception('You have already requested this skill.');
    }

    // Create request in Firestore
    await FirebaseFirestore.instance.collection('requests').add({
      'requesterUid': user.uid,
      'requesterName': _studentName,
      'receiverUid': receiverUid,
      'receiverName': skill['studentName'] ?? 'Student',
      'skillId': skillId,
      'skillName': skill['skillName'] ?? '',
      'category': skill['category'] ?? 'Other',
      'credits': skill['credits'] ?? 0,
      'message': 'I want to learn ${skill['skillName']}.',
      'status': 'Pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Keep local cache for existing parts of the app
    _sentRequests.add({
      'studentName': skill['studentName'] ?? 'Student',
      'skillName': skill['skillName'] ?? '',
      'status': 'Pending',
      'credits': skill['credits'] ?? 0,
      'category': skill['category'] ?? 'Other',
    });

    await _saveData();
    notifyListeners();
  }

  // Legacy demo incoming request method
  Future<void> updateIncomingRequest(
    int index,
    String status,
  ) async {
    await _loadFuture;

    if (index < 0 || index >= _incomingRequests.length) {
      return;
    }

    _incomingRequests[index]['status'] = status;

    await _saveData();
    notifyListeners();
  }

  // Earn credits locally
  Future<bool> earnCredits(int amount) async {
    await _loadFuture;

    if (amount <= 0) return false;

    _credits += amount;

    await _saveData();
    notifyListeners();

    return true;
  }

  // Spend credits locally
  Future<bool> spendCredits(int amount) async {
    await _loadFuture;

    if (amount <= 0 || amount > _credits) {
      return false;
    }

    _credits -= amount;

    await _saveData();
    notifyListeners();

    return true;
  }

  // Legacy demo teaching session
  Future<bool> completeIncomingSession(int index) async {
    await _loadFuture;

    if (index < 0 || index >= _incomingRequests.length) {
      return false;
    }

    final request = _incomingRequests[index];

    if (request['status'] != 'Accepted') {
      return false;
    }

    final creditsText = request['credits'].toString();

    final amount = int.tryParse(
          creditsText.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;

    if (amount <= 0) return false;

    _credits += amount;
    request['status'] = 'Completed';

    _sessionHistory.insert(0, {
      'studentName': request['name'],
      'skillName': request['skill'],
      'type': 'Teaching',
      'credits': amount,
      'date': DateTime.now().toIso8601String(),
    });

    await _saveData();
    notifyListeners();

    return true;
  }

  // Legacy demo learning session
  Future<bool> completeSentSession(int index) async {
    await _loadFuture;

    if (index < 0 || index >= _sentRequests.length) {
      return false;
    }

    final request = _sentRequests[index];

    if (request['status'] != 'Accepted') {
      return false;
    }

    final creditsText = request['credits'].toString();

    final amount = int.tryParse(
          creditsText.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;

    if (amount <= 0 || amount > _credits) {
      return false;
    }

    _credits -= amount;
    request['status'] = 'Completed';

    _sessionHistory.insert(0, {
      'studentName': request['studentName'],
      'skillName': request['skillName'],
      'type': 'Learning',
      'credits': amount,
      'date': DateTime.now().toIso8601String(),
    });

    await _saveData();
    notifyListeners();

    return true;
  }

  // Legacy local sent request status method
  Future<void> updateSentRequestStatus(
    int index,
    String status,
  ) async {
    await _loadFuture;

    if (index < 0 || index >= _sentRequests.length) {
      return;
    }

    if (status != 'Accepted' && status != 'Rejected') {
      return;
    }

    if (_sentRequests[index]['status'] != 'Pending') {
      return;
    }

    _sentRequests[index]['status'] = status;

    await _saveData();
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _skillsSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }
}
