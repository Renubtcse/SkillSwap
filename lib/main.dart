

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'providers/skill_provider.dart';
import 'firebase_options.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'auth_screen.dart';
import 'services/firestore_service.dart';
import 'services/auth_service.dart';


import 'package:cloud_firestore/cloud_firestore.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    ChangeNotifierProvider(
      create: (context) => SkillProvider(),
      child: const SkillSwapApp(),
    ),
  );
}



class SkillSwapApp extends StatelessWidget {
  const SkillSwapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SkillSwap',
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final FirestoreService _firestoreService = FirestoreService();

  String? _profileCompletedUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data;

        if (user == null) {
          _profileCompletedUid = null;
          return const AuthScreen();
        }

        if (_profileCompletedUid == user.uid) {
          return const MainNavigation();
        }

        return FutureBuilder<Map<String, dynamic>?>(
          future: _firestoreService.getUserProfile(user.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (profileSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Unable to load your profile.'),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (profileSnapshot.data == null) {
              return ProfileCompletionScreen(
                onSaved: () {
                  setState(() {
                    _profileCompletedUid = user.uid;
                  });
                },
              );
            }

            return const MainNavigation();
          },
        );
      },
    );
  }
}

class ProfileCompletionScreen extends StatefulWidget {
  final VoidCallback onSaved;

  const ProfileCompletionScreen({
    super.key,
    required this.onSaved,
  });

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState
    extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final collegeController = TextEditingController();

  final FirestoreService _firestoreService = FirestoreService();

  bool isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    collegeController.dispose();
    super.dispose();
  }

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    setState(() => isLoading = true);

    try {
      await _firestoreService.ensureUserProfile(
        uid: user.uid,
        name: nameController.text.trim(),
        email: user.email ?? '',
        college: collegeController.text.trim(),
      );

      if (!mounted) return;

      widget.onSaved();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save profile: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 430),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 55,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Complete Your Profile',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please add your details to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Please enter your name'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue:
                        FirebaseAuth.instance.currentUser?.email ?? '',
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: collegeController,
                    decoration: const InputDecoration(
                      labelText: 'College Name',
                      prefixIcon: Icon(Icons.school_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Please enter your college'
                            : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isLoading ? null : saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : const Text(
                            'Save Profile',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// MAIN NAVIGATION


class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int selectedIndex = 0;

  final List<Widget> screens = const [
    HomeScreen(),
    ExploreScreen(),
    RequestsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SkillProvider>();

    final popularSkills = provider.skills.reversed.take(4).toList();

    final mySkills = provider.skills
        .where((skill) => skill['studentName'] == provider.studentName)
        .length;

    final sentRequests = provider.sentRequests.length;
    final completedSessions = provider.sessionHistory.length;

    // Only genuinely new notifications show the red dot.
    final hasNewNotifications = provider.hasNewNotifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SkillSwap',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () {
              // Clear the new notification indicator.
              provider.clearNewNotificationIndicator();

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined, size: 27),
                if (hasNewNotifications)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Notifications',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, ${provider.studentName}! 👋',
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Learn something new. Teach something useful.',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 24),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Time Credits',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${provider.credits} Credits',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Teach skills and earn more credits!',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'My Activity',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                statCard(
                  'Skills Published',
                  mySkills.toString(),
                  Icons.school_outlined,
                  Colors.deepPurple,
                ),
                statCard(
                  'Requests Sent',
                  sentRequests.toString(),
                  Icons.send_outlined,
                  Colors.blue,
                ),
                statCard(
                  'Sessions Completed',
                  completedSessions.toString(),
                  Icons.check_circle_outline,
                  Colors.green,
                ),
                statCard(
                  'Available Credits',
                  provider.credits.toString(),
                  Icons.stars_outlined,
                  Colors.orange,
                ),
              ],
            ),

            const SizedBox(height: 25),

            const Text(
              'What would you like to do?',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(
                  child: actionCard(
                    context,
                    Icons.search,
                    'Explore Skills',
                    Colors.blue,
                    const ExploreScreen(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: actionCard(
                    context,
                    Icons.school,
                    'Teach Skills',
                    Colors.orange,
                    const TeachScreen(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),

            const Text(
              'Popular Skills',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (popularSkills.isEmpty) ...[
              skillTile('Flutter Development', Icons.phone_android),
              skillTile('Python Programming', Icons.code),
              skillTile('UI/UX Design', Icons.design_services),
              skillTile('Public Speaking', Icons.mic),
            ] else ...[
              ...popularSkills.map((skill) {
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SkillDetailsScreen(
                          skill: Map<String, dynamic>.from(skill),
                        ),
                      ),
                    );
                  },
                  child: Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.school,
                        color: Colors.deepPurple,
                      ),
                      title: Text(
                        skill['skillName'].toString(),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text('By ${skill['studentName']}'),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 23),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget actionCard(
    BuildContext context,
    IconData icon,
    String title,
    Color color,
    Widget destination,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destination),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget skillTile(String title, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.deepPurple),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}

// NOTIFICATIONS SCREEN

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  String formatNotificationDate(dynamic createdAt) {
    if (createdAt == null) return '';

    try {
      final date = createdAt.toDate().toLocal();

      final day = date.day.toString().padLeft(2, '0');
      final month = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][date.month - 1];

      final year = date.year;

      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';

      return '$day $month $year • $hour:$minute $period';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SkillProvider>();
    final notifications = provider.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 65,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No notifications yet.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];

                final type = notification['type']?.toString() ?? '';
                final isCompleted = type == 'session_completed';
                final isRead = notification['read'] == true;

                final notificationTime = formatNotificationDate(
                  notification['createdAt'],
                );

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(
                      backgroundColor:
                          (isCompleted ? Colors.deepPurple : Colors.blue)
                              .withValues(alpha: 0.12),
                      child: Icon(
                        isCompleted ? Icons.task_alt : Icons.notifications,
                        color: isCompleted ? Colors.deepPurple : Colors.blue,
                      ),
                    ),
                    title: Text(
                      notification['title']?.toString() ?? 'Notification',
                      style: TextStyle(
                        fontWeight:
                            isRead ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification['message']?.toString() ?? '',
                          ),
                          if (notificationTime.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  notificationTime,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    trailing: isRead
                        ? null
                        : const Icon(
                            Icons.circle,
                            color: Colors.deepPurple,
                            size: 10,
                          ),
                  ),
                );
              },
            ),
    );
  }
}



// EXPLORE SCREEN







class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController searchController =
      TextEditingController();

  String selectedCategory = 'All';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SkillProvider>();

    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUid = currentUser?.uid;

    // Show all published skills, including your own
    final allSkills = provider.skills;

    final sentRequests = provider.sentRequests;
    final query = searchController.text.trim().toLowerCase();

    // Search and category filtering
    final filteredStudents = allSkills.where((student) {
      final skillName =
          (student['skillName'] ?? '').toString().toLowerCase();

      final studentName =
          (student['studentName'] ?? '').toString().toLowerCase();

      final category =
          (student['category'] ?? '').toString();

      final matchesCategory = selectedCategory == 'All' ||
          category == selectedCategory;

      final matchesSearch =
          skillName.contains(query) || studentName.contains(query);

      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Explore Skills',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Discover New Skills 🚀',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Learn from other students and grow together.',
              style: TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 20),

            // SEARCH BAR
            TextField(
              controller: searchController,
              onChanged: (value) {
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Search skills or students...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    searchController.clear();
                    setState(() {});
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),

            const SizedBox(height: 22),

            // CATEGORY FILTER
            const Text(
              'Categories',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  'All',
                  'Programming',
                  'Design',
                  'Communication',
                  'Other',
                ].map((category) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: selectedCategory == category,
                      onSelected: (selected) {
                        setState(() {
                          selectedCategory = category;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 22),

            // STUDENT LIST HEADING
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Students Who Can Teach',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${filteredStudents.length} found',
                  style: const TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // EMPTY STATE
            if (filteredStudents.isEmpty)
              Padding(
                padding: const EdgeInsets.all(30),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 50,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        allSkills.isEmpty
                            ? 'No skills have been published yet.'
                            : 'No matching skills found!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

            // FIREBASE SKILL CARDS
            ...filteredStudents.map((student) {
              final name =
                  (student['studentName'] ?? 'Student').toString();

              final skillName =
                  (student['skillName'] ?? 'Untitled Skill').toString();

              final category =
                  (student['category'] ?? 'Other').toString();

              final level =
                  (student['level'] ?? 'Beginner').toString();

              final credits =
                  (student['credits'] ?? 0).toString();

              final description =
                  (student['description'] ?? '').toString();

              final initial = student['initial']?.toString() ??
                  (name.isNotEmpty ? name[0].toUpperCase() : 'S');

              // Check whether this is the logged-in student's skill
              final isOwnSkill =
                  currentUid != null &&
                  student['createdBy'] == currentUid;

              final isRequested = sentRequests.any(
                (request) =>
                    request['studentName'] == name &&
                    request['skillName'] == skillName,
              );

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor:
                                Colors.deepPurple.shade100,
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  skillName,
                                  style: const TextStyle(
                                    color: Colors.deepPurple,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Icon(
                            Icons.school_outlined,
                            color: Colors.deepPurple,
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text(category)),
                          Chip(label: Text(level)),
                          if (isOwnSkill)
                            const Chip(
                              label: Text('Your Skill'),
                              backgroundColor: Color(0xFFEDE7F6),
                            ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 18,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text('$credits Credits/hour'),
                        ],
                      ),

                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          description,
                          style: const TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // VIEW DETAILS BUTTON
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SkillDetailsScreen(
                                  skill: student,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.info_outline),
                          label: const Text('View Details'),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // REQUEST BUTTON
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (isRequested || isOwnSkill)
                              ? null
                              : () async {
                                  try {
                                    await context
                                        .read<SkillProvider>()
                                        .sendRequest(student);

                                    if (!context.mounted) return;

                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Request sent to $name!',
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;

                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Could not send request: $e',
                                        ),
                                      ),
                                    );
                                  }
                                },
                          child: Text(
                            isOwnSkill
                                ? 'Your Skill'
                                : isRequested
                                    ? 'Request Sent ✓'
                                    : 'Request to Learn',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}



class SkillDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> skill;

  const SkillDetailsScreen({
    super.key,
    required this.skill,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SkillProvider>();

    final name = skill['studentName'].toString();
    final skillName = skill['skillName'].toString();

    final isRequested = provider.sentRequests.any((request) =>
        request['studentName'] == name &&
        request['skillName'] == skillName);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Skill Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 45,
                backgroundColor: Colors.deepPurple.shade100,
                child: const Icon(
                  Icons.school,
                  size: 45,
                  color: Colors.deepPurple,
                ),
              ),
            ),

            const SizedBox(height: 18),

            Center(
              child: Text(
                skillName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 8),

            Center(
              child: Text(
                'Taught by $name',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'About This Skill',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    detailRow(
                      Icons.category,
                      'Category',
                      skill['category'].toString(),
                    ),

                    const Divider(height: 25),

                    detailRow(
                      Icons.trending_up,
                      'Experience Level',
                      skill['level'].toString(),
                    ),

                    const Divider(height: 25),

                    detailRow(
                      Icons.access_time,
                      'Credits per Hour',
                      '${skill['credits']} Credits',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),

            const Text(
              'Description',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                skill['description']?.toString().isNotEmpty == true
                    ? skill['description'].toString()
                    : 'No description provided.',
                style: const TextStyle(fontSize: 15),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isRequested
                    ? null
                    : () {
                        context
                            .read<SkillProvider>()
                            .sendRequest(skill);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Request sent to $name!',
                            ),
                          ),
                        );

                        Navigator.pop(context);
                      },
                icon: const Icon(Icons.send),
                label: Text(
                  isRequested
                      ? 'Request Already Sent ✓'
                      : 'Request to Learn',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget detailRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, color: Colors.deepPurple),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}



// REQUESTS SCREEN



class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  int selectedTab = 0;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Color statusColor(String status) {
    if (status == 'Accepted' || status == 'Confirmed') {
      return Colors.green;
    }
    if (status == 'Rejected' || status == 'Cancelled') {
      return Colors.red;
    }
    if (status == 'Completed') return Colors.blue;
    return Colors.orange;
  }

  String formatDateTime(dynamic dateValue) {
    if (dateValue == null) return 'Date unavailable';

    try {
      final date = dateValue is Timestamp
          ? dateValue.toDate().toLocal()
          : DateTime.parse(dateValue.toString()).toLocal();

      final day = date.day.toString().padLeft(2, '0');
      final month = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][date.month - 1];

      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';

      return '$day $month ${date.year} • $hour:$minute $period';
    } catch (e) {
      return 'Date unavailable';
    }
  }

  Future<void> updateRequest(String requestId, String status) async {
    try {
      await _db.collection('requests').doc(requestId).update({
        'status': status,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request $status successfully!')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update request: $e')),
      );
    }
  }

  Future<void> respondToSession(
    String sessionId,
    String status,
  ) async {
    try {
      await _db.collection('sessions').doc(sessionId).update({
        'status': status,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'Confirmed'
                ? 'Session confirmed successfully!'
                : 'Session proposal rejected.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update session: $e')),
      );
    }
  }

  Future<void> scheduleSession(
    String requestId,
    Map<String, dynamic> request,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      if (request['requesterUid'] != user.uid &&
          request['receiverUid'] != user.uid) {
        throw Exception('You are not a participant in this request.');
      }

      final participantField =
          request['requesterUid'] == user.uid
              ? 'requesterUid'
              : 'receiverUid';

      final existing = await _db
          .collection('sessions')
          .where(participantField, isEqualTo: user.uid)
          .get();

      final alreadyExists = existing.docs.any(
        (doc) => doc.data()['requestId'] == requestId,
      );

      if (alreadyExists) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A session has already been proposed.'),
          ),
        );
        return;
      }

      final selectedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(
          const Duration(days: 1),
        ),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(
          const Duration(days: 90),
        ),
      );

      if (selectedDate == null || !mounted) return;

      final selectedTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 10, minute: 0),
      );

      if (selectedTime == null || !mounted) return;

      int duration = 60;

      final selectedDuration = await showDialog<int>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Session Duration'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [30, 60, 90, 120].map((minutes) {
                    return RadioListTile<int>(
                      title: Text('$minutes minutes'),
                      value: minutes,
                      groupValue: duration,
                      onChanged: (value) {
                        setDialogState(() {
                          duration = value!;
                        });
                      },
                    );
                  }).toList(),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext, duration);
                    },
                    child: const Text('Continue'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (selectedDuration == null || !mounted) return;

      final sessionDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );

      final formattedTime =
          '${selectedTime.hour.toString().padLeft(2, '0')}:'
          '${selectedTime.minute.toString().padLeft(2, '0')}';

      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Confirm Session Details'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Skill: ${request['skillName']}'),
                const SizedBox(height: 8),
                Text(
                  'Date: ${selectedDate.day}/'
                  '${selectedDate.month}/${selectedDate.year}',
                ),
                const SizedBox(height: 8),
                Text('Start Time: $formattedTime'),
                const SizedBox(height: 8),
                Text('Duration: $selectedDuration minutes'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Edit'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Schedule'),
              ),
            ],
          );
        },
      );

      if (confirm != true || !mounted) return;

      await _db.collection('sessions').add({
        'requestId': requestId,
        'skillName': request['skillName'] ?? '',
        'requesterUid': request['requesterUid'],
        'requesterName': request['requesterName'],
        'receiverUid': request['receiverUid'],
        'receiverName': request['receiverName'],
        'scheduledByUid': user.uid,
        'sessionDate': Timestamp.fromDate(sessionDateTime),
        'startTime': formattedTime,
        'durationMinutes': selectedDuration,
        'status': 'Proposed',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session proposed successfully!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to schedule session: $e'),
        ),
      );
    }
  }

  String formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Date unavailable';

    if (dateValue is Timestamp) {
      final date = dateValue.toDate().toLocal();
      return '${date.day}/${date.month}/${date.year}';
    }

    return 'Date unavailable';
  }

  Widget buildStatusBadge(String status) {
    return Chip(
      label: Text(status),
      backgroundColor: statusColor(status).withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: statusColor(status),
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget buildSessionSection(
    String requestId,
    Map<String, dynamic> request,
  ) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Text('Please login again.');
    }

    if (request['requesterUid'] != currentUser.uid &&
        request['receiverUid'] != currentUser.uid) {
      return const Text('You cannot access this session.');
    }

    final participantField =
        request['requesterUid'] == currentUser.uid
            ? 'requesterUid'
            : 'receiverUid';

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('sessions')
          .where(participantField, isEqualTo: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Unable to load session details: ${snapshot.error}',
            style: const TextStyle(color: Colors.red),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }

        final sessions = (snapshot.data?.docs ?? [])
            .where((doc) => doc.data()['requestId'] == requestId)
            .toList();

        if (sessions.isEmpty) {
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => scheduleSession(requestId, request),
              icon: const Icon(Icons.calendar_month),
              label: const Text('Schedule Session'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
          );
        }

        final sessionDocument = sessions.first;
        final session = sessionDocument.data();
        final status = session['status']?.toString() ?? 'Proposed';

        final isProposer =
            session['scheduledByUid'] == currentUser.uid;

        final isRequester =
            session['requesterUid'] == currentUser.uid;

        final requesterCompleted =
            session['requesterCompleted'] == true;

        final receiverCompleted =
            session['receiverCompleted'] == true;

        final myCompletionDone =
            isRequester ? requesterCompleted : receiverCompleted;

        final otherCompletionDone =
            isRequester ? receiverCompleted : requesterCompleted;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.event_available,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Session Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  buildStatusBadge(status),
                ],
              ),
              const SizedBox(height: 12),
              Text('Date: ${formatDate(session['sessionDate'])}'),
              const SizedBox(height: 6),
              Text('Start Time: ${session['startTime']}'),
              const SizedBox(height: 6),
              Text('Duration: ${session['durationMinutes']} minutes'),
              const SizedBox(height: 6),
              Text(
                'Proposed by: ${isProposer ? 'You' : 'Other student'}',
              ),
              if (session['createdAt'] != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Proposed on: ${formatDateTime(session['createdAt'])}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],

              if (status == 'Proposed' && isProposer)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Waiting for the other student to confirm.',
                    style: TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              if (status == 'Proposed' && !isProposer) ...[
                const SizedBox(height: 12),
                const Text(
                  'A session has been proposed. Please confirm or reject it.',
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => respondToSession(
                          sessionDocument.id,
                          'Confirmed',
                        ),
                        icon: const Icon(Icons.check),
                        label: const Text('Confirm'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => respondToSession(
                          sessionDocument.id,
                          'Rejected',
                        ),
                        icon: const Icon(Icons.close),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              if (status == 'Confirmed') ...[
                const SizedBox(height: 12),
                const Text(
                  'Your session is confirmed!',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(height: 24),
                const Text(
                  'Session Completion',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      requesterCompleted
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: requesterCompleted
                          ? Colors.green
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Learner confirmation'),
                    ),
                    Text(
                      requesterCompleted ? 'Done' : 'Pending',
                      style: TextStyle(
                        color: requesterCompleted
                            ? Colors.green
                            : Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      receiverCompleted
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: receiverCompleted
                          ? Colors.green
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Teacher confirmation'),
                    ),
                    Text(
                      receiverCompleted ? 'Done' : 'Pending',
                      style: TextStyle(
                        color: receiverCompleted
                            ? Colors.green
                            : Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (!myCompletionDone)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final result = await context
                              .read<SkillProvider>()
                              .completeSession(sessionDocument.id);

                          if (!context.mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result == 'completed'
                                    ? 'Session completed! Credits transferred successfully.'
                                    : 'Your confirmation saved. Waiting for the other student.',
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Unable to complete session: $e',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.task_alt),
                      label: const Text('Mark Session as Completed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  )
                else
                  Text(
                    otherCompletionDone
                        ? 'Both students have confirmed completion.'
                        : 'Your confirmation is saved. Waiting for the other student.',
                    style: const TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],

              if (status == 'Completed') ...[
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Session completed by both students!',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Credit transfer has been processed.',
                  style: TextStyle(color: Colors.deepPurple),
                ),
              ],

              if (status == 'Rejected')
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'This session proposal was rejected.',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please login to view requests.'),
        ),
      );
    }

    final incomingStream = _db
        .collection('requests')
        .where('receiverUid', isEqualTo: user.uid)
        .snapshots();

    final sentStream = _db
        .collection('requests')
        .where('requesterUid', isEqualTo: user.uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Requests',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _tabButton('Incoming', 0),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _tabButton('Sent', 1),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: selectedTab == 0
                    ? incomingStream
                    : sentStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading requests: ${snapshot.error}',
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        selectedTab == 0
                            ? 'No incoming requests yet.'
                            : 'You have not sent any requests yet.',
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final document = docs[index];
                      final request = document.data();

                      final status =
                          request['status']?.toString() ?? 'Pending';

                      final isIncoming = selectedTab == 0;

                      final personName = isIncoming
                          ? request['requesterName'] ?? 'Student'
                          : request['receiverName'] ?? 'Student';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 15),
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.deepPurple,
                                    child: Icon(
                                      isIncoming
                                          ? Icons.person
                                          : Icons.school,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      personName.toString(),
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  buildStatusBadge(status),
                                ],
                              ),
                              const SizedBox(height: 15),
                              Text(
                                'Skill: ${request['skillName'] ?? ''}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                request['message']?.toString() ?? '',
                              ),

                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Request Date: ${formatDateTime(request['createdAt'])}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.stars,
                                    color: Colors.deepPurple,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${request['credits'] ?? 0} Credits/hour',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                ],
                              ),

                              if (isIncoming && status == 'Pending') ...[
                                const SizedBox(height: 15),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => updateRequest(
                                          document.id,
                                          'Accepted',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Accept'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => updateRequest(
                                          document.id,
                                          'Rejected',
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: const Text('Reject'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              if (status == 'Accepted') ...[
                                const SizedBox(height: 15),
                                buildSessionSection(
                                  document.id,
                                  request,
                                ),
                              ],

                              if (status == 'Rejected') ...[
                                const SizedBox(height: 12),
                                const Text(
                                  'This request was rejected.',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String label, int tabIndex) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          selectedTab = tabIndex;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: selectedTab == tabIndex
            ? Colors.deepPurple
            : Colors.grey.shade200,
        foregroundColor: selectedTab == tabIndex
            ? Colors.white
            : Colors.black,
      ),
      child: Text(label),
    );
  }
}

// PROFILE SCREEN










class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void editProfile(BuildContext context, SkillProvider provider) {
    final nameController =
        TextEditingController(text: provider.studentName);
    final emailController =
        TextEditingController(text: provider.email);
    final collegeController =
        TextEditingController(text: provider.college);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration:
                      const InputDecoration(labelText: 'Full Name'),
                ),
                TextField(
                  controller: emailController,
                  decoration:
                      const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextField(
                  controller: collegeController,
                  decoration:
                      const InputDecoration(labelText: 'College Name'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty ||
                    emailController.text.trim().isEmpty ||
                    collegeController.text.trim().isEmpty) {
                  return;
                }

                try {
                  await provider.updateProfile(
                    name: nameController.text.trim(),
                    email: emailController.text.trim(),
                    college: collegeController.text.trim(),
                  );

                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile updated successfully!'),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Update failed: $e')),
                  );
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    ).then((_) {
      nameController.dispose();
      emailController.dispose();
      collegeController.dispose();
    });
  }

  // AVAILABILITY MANAGEMENT
  Future<void> editAvailability(
    BuildContext context,
    Map<String, dynamic> currentAvailability,
  ) async {
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    final selectedDays = List<String>.from(
      currentAvailability['days'] ?? [],
    );

    TimeOfDay startTime = _parseTime(
      currentAvailability['startTime'] ?? '09:00',
    );

    TimeOfDay endTime = _parseTime(
      currentAvailability['endTime'] ?? '17:00',
    );

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Set My Availability'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Available Days',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...days.map((day) {
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(day),
                        value: selectedDays.contains(day),
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              selectedDays.add(day);
                            } else {
                              selectedDays.remove(day);
                            }
                          });
                        },
                      );
                    }),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Available Time',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Start Time'),
                      subtitle: Text(startTime.format(context)),
                      trailing:
                          const Icon(Icons.access_time),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: startTime,
                        );
                        if (picked != null) {
                          setDialogState(() {
                            startTime = picked;
                          });
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('End Time'),
                      subtitle: Text(endTime.format(context)),
                      trailing:
                          const Icon(Icons.access_time),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: endTime,
                        );
                        if (picked != null) {
                          setDialogState(() {
                            endTime = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedDays.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Please select at least one day.'),
                        ),
                      );
                      return;
                    }

                    final startMinutes =
                        startTime.hour * 60 + startTime.minute;
                    final endMinutes =
                        endTime.hour * 60 + endTime.minute;

                    if (endMinutes <= startMinutes) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'End time must be after start time.',
                          ),
                        ),
                      );
                      return;
                    }

                    try {
                      final user =
                          FirebaseAuth.instance.currentUser;

                      if (user == null) {
                        throw Exception('Please login first.');
                      }

                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .update({
                        'availability': {
                          'days': selectedDays,
                          'startTime':
                              '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                          'endTime':
                              '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                        },
                      });

                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Availability saved successfully!',
                          ),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text('Unable to save: $e'),
                        ),
                      );
                    }
                  },
                  child: const Text('Save Availability'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  Widget buildAvailabilitySection(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final availability =
            Map<String, dynamic>.from(data?['availability'] ?? {});

        final days =
            List<String>.from(availability['days'] ?? []);

        final start = availability['startTime'] ?? 'Not set';
        final end = availability['endTime'] ?? 'Not set';

        return Card(
          margin: const EdgeInsets.only(bottom: 15),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month,
                      color: Colors.deepPurple,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'My Availability',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit Availability',
                      onPressed: () =>
                          editAvailability(context, availability),
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (snapshot.connectionState ==
                    ConnectionState.waiting)
                  const LinearProgressIndicator()
                else if (days.isEmpty)
                  const Text(
                    'You have not set your availability yet.',
                    style: TextStyle(color: Colors.grey),
                  )
                else ...[
                  const Text(
                    'Available Days',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: days.map((day) {
                      return Chip(
                        label: Text(day),
                        backgroundColor: Colors.deepPurple.shade50,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: Colors.deepPurple,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text('$start - $end'),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        editAvailability(context, availability),
                    icon: const Icon(Icons.edit_calendar),
                    label: Text(
                      days.isEmpty
                          ? 'Set Availability'
                          : 'Update Availability',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildSkillSection(
    String title,
    IconData icon,
    List<String> skills,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.deepPurple),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (skills.isEmpty)
              const Text(
                'No skills added yet.',
                style: TextStyle(color: Colors.grey),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: skills.map((skill) {
                  return Chip(
                    label: Text(skill),
                    backgroundColor: Colors.deepPurple.shade50,
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> deleteMySkill(
    BuildContext context,
    SkillProvider provider,
    Map<String, dynamic> skill,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Skill?'),
          content: Text(
            'Are you sure you want to delete ${skill['skillName']}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    final deleted = await provider.deleteSkill(skill);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? 'Skill deleted successfully!'
              : 'Unable to delete this skill.',
        ),
      ),
    );
  }

  Widget buildMySkillsSection(
    BuildContext context,
    SkillProvider provider,
    List<Map<String, dynamic>> mySkills,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.manage_accounts, color: Colors.deepPurple),
                SizedBox(width: 10),
                Text(
                  'My Published Skills',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (mySkills.isEmpty)
              const Text(
                'You have not published any skills yet.',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...mySkills.map((skill) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEDE7F6),
                    child: Icon(
                      Icons.lightbulb_outline,
                      color: Colors.deepPurple,
                    ),
                  ),
                  title: Text(
                    skill['skillName'].toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${skill['category']} • ${skill['level']} • ${skill['credits']} Credits/hour',
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                    onPressed: () =>
                        deleteMySkill(context, provider, skill),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SkillProvider>();

    final mySkills = provider.skills
        .where((skill) =>
            skill['studentName'] == provider.studentName)
        .toList();

    final teachingSkills = mySkills
        .map((skill) => skill['skillName'].toString())
        .toSet()
        .toList();

    final learningSkills = provider.sentRequests
        .map((request) => request['skillName'].toString())
        .toSet()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => editProfile(context, provider),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 10),
            const CircleAvatar(
              radius: 55,
              backgroundColor: Colors.deepPurple,
              child: Icon(
                Icons.person,
                size: 65,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              provider.studentName,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(provider.email),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.school,
                  size: 17,
                  color: Colors.deepPurple,
                ),
                const SizedBox(width: 5),
                Text(provider.college),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => editProfile(context, provider),
                icon: const Icon(Icons.edit),
                label: const Text('Edit Profile'),
              ),
            ),
            const SizedBox(height: 20),

            // TIME CREDITS
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  const Icon(Icons.stars, color: Colors.white, size: 35),
                  const SizedBox(height: 8),
                  const Text(
                    'Your Time Credits',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${provider.credits} Credits',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // AVAILABILITY
            buildAvailabilitySection(context),

            // MY PUBLISHED SKILLS
            buildMySkillsSection(context, provider, mySkills),

            buildSkillSection(
              'Skills I Can Teach',
              Icons.school,
              teachingSkills,
            ),
            buildSkillSection(
              'Skills I Want to Learn',
              Icons.menu_book,
              learningSkills,
            ),

            // SESSION HISTORY
            Card(
              margin: const EdgeInsets.only(bottom: 15),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.deepPurple,
                  child: Icon(Icons.history, color: Colors.white),
                ),
                title: const Text(
                  'Session History',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'View your completed learning sessions',
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 17,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const SessionHistoryScreen(),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 15),

            // LOGOUT
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await AuthService().logout();
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Logout failed: $e')),
                    );
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}




class SessionHistoryScreen extends StatelessWidget {
  const SessionHistoryScreen({super.key});

  String formatDate(String? date) {
    if (date == null || date.isEmpty) {
      return 'Date unavailable';
    }

    final parsedDate = DateTime.tryParse(date);

    if (parsedDate == null) {
      return 'Date unavailable';
    }

    final localDate = parsedDate.toLocal();

    return '${localDate.day.toString().padLeft(2, '0')}/'
        '${localDate.month.toString().padLeft(2, '0')}/'
        '${localDate.year}';
  }

  String formatDateTime(String? date) {
    if (date == null || date.isEmpty) {
      return 'Completion time unavailable';
    }

    final parsedDate = DateTime.tryParse(date);

    if (parsedDate == null) {
      return 'Completion time unavailable';
    }

    final localDate = parsedDate.toLocal();

    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final year = localDate.year;

    final hour = localDate.hour % 12 == 0 ? 12 : localDate.hour % 12;
    final minute = localDate.minute.toString().padLeft(2, '0');
    final period = localDate.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/$year at $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SkillProvider>();
    final history = provider.sessionHistory;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Session History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: history.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 65,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No completed sessions yet.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final session = history[index];

                final type = session['type']?.toString() ?? '';
                final isTeaching = type == 'Teaching';

                final credits =
                    int.tryParse(session['credits'].toString()) ?? 0;

                final studentName =
                    session['studentName']?.toString() ?? 'Student';

                final skillName =
                    session['skillName']?.toString() ?? 'Skill';

                final date = session['date']?.toString();

                final startTime =
                    session['startTime']?.toString() ?? '';

                final duration =
                    int.tryParse(
                      session['durationMinutes']?.toString() ?? '',
                    ) ?? 0;

                final completedAt =
                    session['completedAt']?.toString();

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: isTeaching
                                  ? Colors.green.shade50
                                  : Colors.blue.shade50,
                              child: Icon(
                                isTeaching
                                    ? Icons.school
                                    : Icons.menu_book,
                                color: isTeaching
                                    ? Colors.green
                                    : Colors.blue,
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    skillName,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    isTeaching
                                        ? 'Teaching Session'
                                        : 'Learning Session',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade600,
                            ),
                          ],
                        ),

                        const Divider(height: 25),

                        _historyDetail(
                          Icons.person_outline,
                          'With $studentName',
                        ),

                        const SizedBox(height: 12),

                        _historyDetail(
                          Icons.calendar_today,
                          'Session Date: ${formatDate(date)}',
                        ),

                        const SizedBox(height: 12),

                        _historyDetail(
                          Icons.access_time,
                          'Start Time: ${startTime.isEmpty ? 'Unavailable' : startTime}',
                        ),

                        const SizedBox(height: 12),

                        _historyDetail(
                          Icons.timer_outlined,
                          'Duration: ${duration > 0 ? '$duration minutes' : 'Unavailable'}',
                        ),

                        const SizedBox(height: 12),

                        _historyDetail(
                          Icons.event_available,
                          'Completed: ${formatDateTime(completedAt)}',
                        ),

                        const Divider(height: 25),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${isTeaching ? '+' : '-'}$credits Credits',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isTeaching
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _historyDetail(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.grey,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text),
        ),
      ],
    );
  }
}





// TEACH SKILLS SCREEN


class TeachScreen extends StatefulWidget {
  const TeachScreen({super.key});

  @override
  State<TeachScreen> createState() => _TeachScreenState();
}

class _TeachScreenState extends State<TeachScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController skillController =
      TextEditingController();

  final TextEditingController descriptionController =
      TextEditingController();

  String? selectedCategory;
  String? selectedLevel;
  int selectedCredits = 1;

  final List<String> categories = [
    'Programming',
    'Design',
    'Communication',
    'Other',
  ];

  final List<String> levels = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  @override
  void dispose() {
    skillController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> publishSkill() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = context.read<SkillProvider>();

    final skillName = skillController.text.trim();

    await provider.addSkill(
      studentName: provider.studentName,
      skillName: skillName,
      category: selectedCategory!,
      level: selectedLevel!,
      credits: selectedCredits,
      description: descriptionController.text.trim(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$skillName published successfully!',
        ),
        backgroundColor: Colors.green,
      ),
    );

    _formKey.currentState!.reset();

    skillController.clear();
    descriptionController.clear();

    setState(() {
      selectedCategory = null;
      selectedLevel = null;
      selectedCredits = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Teach a Skill',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Form(
          key: _formKey,

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const Text(
                'Share Your Knowledge! 🎓',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Teach other students and earn time credits.',
                style: TextStyle(fontSize: 14),
              ),

              const SizedBox(height: 25),

              // SKILL NAME

              const Text(
                'Skill Name',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              TextFormField(
                controller: skillController,
                decoration: InputDecoration(
                  hintText: 'e.g. Flutter Development',
                  prefixIcon: const Icon(Icons.lightbulb_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a skill name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // CATEGORY

              const Text(
                'Category',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: InputDecoration(
                  hintText: 'Select Category',
                  prefixIcon: const Icon(Icons.category_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a category';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // EXPERIENCE LEVEL

              const Text(
                'Experience Level',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                value: selectedLevel,
                decoration: InputDecoration(
                  hintText: 'Select Experience Level',
                  prefixIcon: const Icon(Icons.trending_up),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: levels.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Text(level),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedLevel = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select experience level';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // CREDITS

              const Text(
                'Credits Per Hour',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              DropdownButtonFormField<int>(
                value: selectedCredits,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.stars_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: [1, 2, 3, 4, 5].map((credit) {
                  return DropdownMenuItem(
                    value: credit,
                    child: Text('$credit Credits / Hour'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCredits = value!;
                  });
                },
              ),

              const SizedBox(height: 20),

              // DESCRIPTION

              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              TextFormField(
                controller: descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Describe what you can teach...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 30),

              // PUBLISH BUTTON

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: publishSkill,
                  icon: const Icon(Icons.publish),
                  label: const Text(
                    'Publish Skill',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

