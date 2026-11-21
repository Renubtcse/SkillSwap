
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SkillProvider extends ChangeNotifier {
  // PROFILE
  String _studentName = 'Student Name';
  String _email = 'student@example.com';
  String _college = 'IGDTUW, Delhi';

  String get studentName => _studentName;
  String get email => _email;
  String get college => _college;

  // CREDITS
  static const int startingCredits = 10;
  int _credits = startingCredits;

  int get credits => _credits;

  // DATA
  final List<Map<String, dynamic>> _skills = [];

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
  final List<Map<String, dynamic>> _notifications = [];

  List<Map<String, dynamic>> get skills => _skills;
  List<Map<String, dynamic>> get incomingRequests => _incomingRequests;
  List<Map<String, dynamic>> get sentRequests => _sentRequests;
  List<Map<String, dynamic>> get sessionHistory => _sessionHistory;
  List<Map<String, dynamic>> get notifications => _notifications;

  // NEW NOTIFICATION INDICATOR
  bool _hasNewNotifications = false;
  bool _hasEstablishedNotificationsBaseline = false;

  bool get hasNewNotifications => _hasNewNotifications;

  void clearNewNotificationIndicator() {
    if (!_hasNewNotifications) return;

    _hasNewNotifications = false;
    notifyListeners();
  }

  late final Future<void> _loadFuture;

  // FIREBASE SUBSCRIPTIONS
  StreamSubscription<User?>? _authSubscription;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _skillsSubscription;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _profileSubscription;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _receivedCreditsSubscription;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _spentCreditsSubscription;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _requesterSessionsSubscription;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _receiverSessionsSubscription;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _notificationsSubscription;

  final Map<String, Map<String, dynamic>> _receivedTransactions = {};
  final Map<String, Map<String, dynamic>> _spentTransactions = {};

  final Map<String, Map<String, dynamic>> _requesterSessions = {};
  final Map<String, Map<String, dynamic>> _receiverSessions = {};

  SkillProvider() {
    _loadFuture = _loadData();

    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen(
      _handleAuthChange,
    );
  }

  // AUTHENTICATION AND FIREBASE LISTENERS

  Future<void> _cancelUserSubscriptions() async {
    await _skillsSubscription?.cancel();
    await _profileSubscription?.cancel();
    await _receivedCreditsSubscription?.cancel();
    await _spentCreditsSubscription?.cancel();
    await _requesterSessionsSubscription?.cancel();
    await _receiverSessionsSubscription?.cancel();
    await _notificationsSubscription?.cancel();
  }

  Future<void> _handleAuthChange(User? user) async {
    await _cancelUserSubscriptions();

    _receivedTransactions.clear();
    _spentTransactions.clear();
    _requesterSessions.clear();
    _receiverSessions.clear();

    _notifications.clear();
    _sessionHistory.clear();

    _hasNewNotifications = false;
    _hasEstablishedNotificationsBaseline = false;

    if (user == null) {
      _skills.clear();
      _credits = startingCredits;
      notifyListeners();
      return;
    }

    await _loadFuture;

    final firestore = FirebaseFirestore.instance;

    // PROFILE LISTENER
    _profileSubscription = firestore
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

          await _saveData();
          notifyListeners();
        }
      },
      onError: (error) {
        debugPrint('Profile sync error: $error');
      },
    );

    // SKILLS LISTENER
    _skillsSubscription = firestore
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

    // RECEIVED CREDITS
    _receivedCreditsSubscription = firestore
        .collection('creditTransactions')
        .where('toUid', isEqualTo: user.uid)
        .snapshots()
        .listen(
      (snapshot) {
        _receivedTransactions
          ..clear()
          ..addEntries(
            snapshot.docs.map(
              (document) => MapEntry(
                document.id,
                document.data(),
              ),
            ),
          );

        _recalculateCredits();
      },
      onError: (error) {
        debugPrint('Received credits sync error: $error');
      },
    );

    // SPENT CREDITS
    _spentCreditsSubscription = firestore
        .collection('creditTransactions')
        .where('fromUid', isEqualTo: user.uid)
        .snapshots()
        .listen(
      (snapshot) {
        _spentTransactions
          ..clear()
          ..addEntries(
            snapshot.docs.map(
              (document) => MapEntry(
                document.id,
                document.data(),
              ),
            ),
          );

        _recalculateCredits();
      },
      onError: (error) {
        debugPrint('Spent credits sync error: $error');
      },
    );

    // SESSION HISTORY: SESSIONS WHERE USER IS LEARNER
    _requesterSessionsSubscription = firestore
        .collection('sessions')
        .where('requesterUid', isEqualTo: user.uid)
        .snapshots()
        .listen(
      (snapshot) {
        _requesterSessions
          ..clear()
          ..addEntries(
            snapshot.docs.map(
              (document) => MapEntry(
                document.id,
                {
                  ...document.data(),
                  'id': document.id,
                },
              ),
            ),
          );

        _refreshSessionHistory();
      },
      onError: (error) {
        debugPrint('Learner session history error: $error');
      },
    );

    // SESSION HISTORY: SESSIONS WHERE USER IS TEACHER
    _receiverSessionsSubscription = firestore
        .collection('sessions')
        .where('receiverUid', isEqualTo: user.uid)
        .snapshots()
        .listen(
      (snapshot) {
        _receiverSessions
          ..clear()
          ..addEntries(
            snapshot.docs.map(
              (document) => MapEntry(
                document.id,
                {
                  ...document.data(),
                  'id': document.id,
                },
              ),
            ),
          );

        _refreshSessionHistory();
      },
      onError: (error) {
        debugPrint('Teacher session history error: $error');
      },
    );

    // NOTIFICATIONS REAL-TIME LISTENER
    _notificationsSubscription = firestore
        .collection('notifications')
        .where('recipientUid', isEqualTo: user.uid)
        .snapshots(includeMetadataChanges: true)
        .listen(
      (snapshot) {
        if (!_hasEstablishedNotificationsBaseline) {
          if (!snapshot.metadata.isFromCache) {
            _hasEstablishedNotificationsBaseline = true;
          }
        } else {
          final hasAddedNotification = snapshot.docChanges.any(
            (change) =>
                change.type == DocumentChangeType.added &&
                !change.doc.metadata.hasPendingWrites,
          );

          if (hasAddedNotification) {
            _hasNewNotifications = true;
          }
        }

        _notifications
          ..clear()
          ..addAll(
            snapshot.docs.map((document) {
              return {
                ...document.data(),
                'id': document.id,
              };
            }),
          );

        _notifications.sort((a, b) {
          final aDate = _dateValue(a['createdAt']);
          final bDate = _dateValue(b['createdAt']);
          return bDate.compareTo(aDate);
        });

        notifyListeners();
      },
      onError: (error) {
        debugPrint('Notifications sync error: $error');
      },
    );
  }

  // DATE HELPER

  DateTime _dateValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime(2000);
    }

    return DateTime(2000);
  }

  // BUILD SESSION HISTORY FROM FIRESTORE

  void _refreshSessionHistory() {
    final Map<String, Map<String, dynamic>> allSessions = {
      ..._requesterSessions,
      ..._receiverSessions,
    };

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final List<Map<String, dynamic>> firebaseHistory = [];

    for (final entry in allSessions.entries) {
      final sessionId = entry.key;
      final session = entry.value;

      if (session['status'] != 'Completed') {
        continue;
      }

      final isTeaching = session['receiverUid'] == user.uid;

      final otherStudent = isTeaching
          ? session['requesterName']
          : session['receiverName'];

      final transaction = _receivedTransactions[sessionId] ??
          _spentTransactions[sessionId];

      final amount =
          (transaction?['amount'] as num?)?.toInt() ?? 0;

      // Scheduled session date
      final scheduledDate = session['sessionDate'] ??
          session['createdAt'];

      // Actual completion timestamp
      final completedAt = session['completedAt'];

      // Duration
      final duration =
          (session['durationMinutes'] as num?)?.toInt() ?? 0;

      // Completion timestamp converted to ISO string
      String? completedAtString;

      if (completedAt is Timestamp) {
        completedAtString =
            completedAt.toDate().toIso8601String();
      } else if (completedAt is DateTime) {
        completedAtString = completedAt.toIso8601String();
      } else if (completedAt is String) {
        completedAtString = completedAt;
      }

      firebaseHistory.add({
        'sessionId': sessionId,
        'studentName': otherStudent?.toString() ?? 'Student',
        'skillName': session['skillName']?.toString() ?? 'Skill',
        'type': isTeaching ? 'Teaching' : 'Learning',
        'credits': amount,

        // Date on which the session was scheduled
        'date': _dateValue(scheduledDate).toIso8601String(),

        // Scheduled starting time
        'startTime': session['startTime']?.toString() ?? '',

        // Session duration in minutes
        'durationMinutes': duration,

        // Actual date and time when both students completed it
        'completedAt': completedAtString,
      });
    }

    // Latest completed sessions first
    firebaseHistory.sort((a, b) {
      final aDate = _dateValue(
        a['completedAt'] ?? a['date'],
      );

      final bDate = _dateValue(
        b['completedAt'] ?? b['date'],
      );

      return bDate.compareTo(aDate);
    });

    // Keep older local demo history entries
    final localHistory = _sessionHistory
        .where((item) => item['sessionId'] == null)
        .toList();

    _sessionHistory
      ..clear()
      ..addAll(firebaseHistory)
      ..addAll(localHistory);

    notifyListeners();
  }

  // CREDIT BALANCE

  void _recalculateCredits() {
    int received = 0;
    int spent = 0;

    for (final transaction in _receivedTransactions.values) {
      received +=
          (transaction['amount'] as num?)?.toInt() ?? 0;
    }

    for (final transaction in _spentTransactions.values) {
      spent +=
          (transaction['amount'] as num?)?.toInt() ?? 0;
    }

    _credits = startingCredits + received - spent;

    _refreshSessionHistory();
    notifyListeners();
  }

  // SESSION COMPLETION, CREDIT TRANSFER AND NOTIFICATIONS

  Future<String> completeSession(String sessionId) async {
    await _loadFuture;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Please login first.');
    }

    final firestore = FirebaseFirestore.instance;
    final sessionRef = firestore.collection('sessions').doc(sessionId);

    try {
      return await firestore.runTransaction<String>(
        (transaction) async {
          final sessionSnapshot = await transaction.get(sessionRef);

          if (!sessionSnapshot.exists) {
            throw Exception('Session not found.');
          }

          final session = sessionSnapshot.data()!;

          final requesterUid =
              session['requesterUid']?.toString();
          final receiverUid =
              session['receiverUid']?.toString();
          final requestId =
              session['requestId']?.toString();

          if (requesterUid == null ||
              receiverUid == null ||
              requestId == null) {
            throw Exception('Invalid session information.');
          }

          if (user.uid != requesterUid &&
              user.uid != receiverUid) {
            throw Exception(
              'You are not a participant in this session.',
            );
          }

          if (session['status'] != 'Confirmed') {
            throw Exception(
              'Only confirmed sessions can be completed.',
            );
          }

          final requesterCompleted =
              session['requesterCompleted'] == true;
          final receiverCompleted =
              session['receiverCompleted'] == true;

          final isRequester = user.uid == requesterUid;

          if (isRequester && requesterCompleted) {
            throw Exception(
              'You have already confirmed completion.',
            );
          }

          if (!isRequester && receiverCompleted) {
            throw Exception(
              'You have already confirmed completion.',
            );
          }

          final requestRef =
              firestore.collection('requests').doc(requestId);

          final ledgerRef =
              firestore.collection('creditTransactions').doc(sessionId);

          final requestSnapshot =
              await transaction.get(requestRef);

          final ledgerSnapshot =
              await transaction.get(ledgerRef);

          if (!requestSnapshot.exists) {
            throw Exception('Original request not found.');
          }

          if (ledgerSnapshot.exists) {
            throw Exception(
              'Credits have already been transferred.',
            );
          }

          final request = requestSnapshot.data()!;

          if (request['status'] != 'Accepted') {
            throw Exception('Original request is not accepted.');
          }

          final rate =
              (request['credits'] as num?)?.toInt() ?? 0;

          final duration =
              (session['durationMinutes'] as num?)?.toInt() ?? 0;

          if (rate <= 0 || duration <= 0) {
            throw Exception('Invalid credit rate or duration.');
          }

          final amount = (rate * duration / 60).ceil();

          final otherStudentCompleted = isRequester
              ? receiverCompleted
              : requesterCompleted;

          final updateData = <String, dynamic>{};

          if (isRequester) {
            updateData['requesterCompleted'] = true;
          } else {
            updateData['receiverCompleted'] = true;
          }

          if (otherStudentCompleted) {
            updateData['status'] = 'Completed';

            // Save the actual completion timestamp
            updateData['completedAt'] =
                FieldValue.serverTimestamp();

            if (isRequester && _credits < amount) {
              throw Exception(
                'Insufficient credits for this session.',
              );
            }
          }

          transaction.update(sessionRef, updateData);

          if (otherStudentCompleted) {
            transaction.set(ledgerRef, {
              'sessionId': sessionId,
              'requestId': requestId,
              'fromUid': requesterUid,
              'toUid': receiverUid,
              'amount': amount,
              'skillName': session['skillName'] ?? '',
              'createdAt': FieldValue.serverTimestamp(),
            });

            // LEARNER NOTIFICATION
            final learnerNotificationRef = firestore
                .collection('notifications')
                .doc('${sessionId}_learner');

            transaction.set(learnerNotificationRef, {
              'recipientUid': requesterUid,
              'title': 'Session Completed',
              'message':
                  'Your session for ${session['skillName'] ?? 'the skill'} has been completed. $amount credits have been transferred.',
              'type': 'session_completed',
              'sessionId': sessionId,
              'read': false,
              'createdAt': FieldValue.serverTimestamp(),
            });

            // TEACHER NOTIFICATION
            final teacherNotificationRef = firestore
                .collection('notifications')
                .doc('${sessionId}_teacher');

            transaction.set(teacherNotificationRef, {
              'recipientUid': receiverUid,
              'title': 'Session Completed',
              'message':
                  'Your session for ${session['skillName'] ?? 'the skill'} has been completed. You received $amount credits.',
              'type': 'session_completed',
              'sessionId': sessionId,
              'read': false,
              'createdAt': FieldValue.serverTimestamp(),
            });

            return 'completed';
          }

          return 'waiting';
        },
      );
    } catch (error) {
      debugPrint('COMPLETE SESSION ERROR: $error');
      rethrow;
    }
  }

  // LOCAL DATA

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    _studentName =
        prefs.getString('studentName') ?? _studentName;
    _email = prefs.getString('email') ?? _email;
    _college = prefs.getString('college') ?? _college;

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

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('studentName', _studentName);
    await prefs.setString('email', _email);
    await prefs.setString('college', _college);

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

  // PROFILE

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

  // SKILLS

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

    final actualName =
        _studentName.trim().isNotEmpty &&
                _studentName != 'Student Name'
            ? _studentName.trim()
            : studentName.trim();

    if (actualName.isEmpty ||
        actualName == 'Student Name') {
      throw Exception('Please complete your profile first.');
    }

    final skillData = <String, dynamic>{
      'studentName': actualName,
      'skillName': skillName.trim(),
      'category': category,
      'level': level,
      'credits': credits,
      'description': description.trim(),
      'initial': actualName[0].toUpperCase(),
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      final document = await FirebaseFirestore.instance
          .collection('skills')
          .add(skillData);

      final savedDocument = await document.get();

      if (!savedDocument.exists) {
        throw Exception(
          'Skill was not found after publishing.',
        );
      }
    } catch (error, stackTrace) {
      debugPrint('PUBLISH SKILL ERROR: $error');
      debugPrint('PUBLISH SKILL STACKTRACE: $stackTrace');
      rethrow;
    }
  }

  Future<bool> deleteSkill(
    Map<String, dynamic> skill,
  ) async {
    await _loadFuture;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return false;

    final skillId = skill['id'];

    if (skillId == null ||
        skill['createdBy'] != user.uid) {
      return false;
    }

    await FirebaseFirestore.instance
        .collection('skills')
        .doc(skillId.toString())
        .delete();

    return true;
  }

  // LEARNING REQUESTS

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
      throw Exception(
        'Invalid skill or student information.',
      );
    }

    if (receiverUid == user.uid) {
      throw Exception(
        'You cannot request your own skill.',
      );
    }

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
      throw Exception(
        'You have already requested this skill.',
      );
    }

    await FirebaseFirestore.instance
        .collection('requests')
        .add({
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

  // LEGACY DEMO METHODS

  Future<void> updateIncomingRequest(
    int index,
    String status,
  ) async {
    await _loadFuture;

    if (index < 0 ||
        index >= _incomingRequests.length) {
      return;
    }

    _incomingRequests[index]['status'] = status;

    await _saveData();
    notifyListeners();
  }

  Future<bool> earnCredits(int amount) async {
    await _loadFuture;

    if (amount <= 0) return false;

    _credits += amount;
    notifyListeners();
    return true;
  }

  Future<bool> spendCredits(int amount) async {
    await _loadFuture;

    if (amount <= 0 || amount > _credits) {
      return false;
    }

    _credits -= amount;
    notifyListeners();
    return true;
  }

  Future<bool> completeIncomingSession(
    int index,
  ) async {
    await _loadFuture;

    if (index < 0 ||
        index >= _incomingRequests.length) {
      return false;
    }

    final request = _incomingRequests[index];

    if (request['status'] != 'Accepted') {
      return false;
    }

    final creditsText = request['credits'].toString();

    final amount = int.tryParse(
          creditsText.replaceAll(
            RegExp(r'[^0-9]'),
            '',
          ),
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
      'startTime': '',
      'durationMinutes': 0,
      'completedAt': DateTime.now().toIso8601String(),
    });

    await _saveData();
    notifyListeners();

    return true;
  }

  Future<bool> completeSentSession(
    int index,
  ) async {
    await _loadFuture;

    if (index < 0 ||
        index >= _sentRequests.length) {
      return false;
    }

    final request = _sentRequests[index];

    if (request['status'] != 'Accepted') {
      return false;
    }

    final creditsText = request['credits'].toString();

    final amount = int.tryParse(
          creditsText.replaceAll(
            RegExp(r'[^0-9]'),
            '',
          ),
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
      'startTime': '',
      'durationMinutes': 0,
      'completedAt': DateTime.now().toIso8601String(),
    });

    await _saveData();
    notifyListeners();

    return true;
  }

  Future<void> updateSentRequestStatus(
    int index,
    String status,
  ) async {
    await _loadFuture;

    if (index < 0 ||
        index >= _sentRequests.length) {
      return;
    }

    if (status != 'Accepted' &&
        status != 'Rejected') {
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
    _cancelUserSubscriptions();
    super.dispose();
  }
}
