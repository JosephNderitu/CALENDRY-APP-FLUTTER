import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth/forgot_password_page.dart';
import 'booking/booking_lookup_page.dart';
import 'booking/guest_meetings_historyPage.dart';
import 'calendar/calendar_page.dart';
import 'home/CreateMeetingPage.dart';
import 'legal_pages/legal_pages.dart';
import 'payments/subscription_page.dart';
import 'settings_content/about_page.dart';
import 'settings_content/edit_profile_page.dart';
import 'firebase_options.dart';
import 'auth/login_page.dart';
import 'home/home_page.dart';
import 'home/settings_page.dart';
import 'settings_content/help_page.dart';
import 'settings_content/phone_verification_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Firebase only if not already initialized
    await Firebase.initializeApp(
      options: firebaseOptions,
    );

    // Configure Firestore settings
    try {
      await FirebaseFirestore.instance.enablePersistence(
        const PersistenceSettings(
          synchronizeTabs: true,
        ),
      );
    } catch (e) {
      // Ignore persistence errors - they're not critical
      debugPrint('Firestore persistence info: $e');
    }
    
  } catch (e) {
    // Only log the error, don't crash the app
    debugPrint('Firebase initialization info: $e');
  }
  
  // Always run the app, regardless of Firebase init status
  runApp(const MeetSyncApp());
}

class MeetSyncApp extends StatefulWidget {
  const MeetSyncApp({Key? key}) : super(key: key);

  @override
  State<MeetSyncApp> createState() => _MeetSyncAppState();
}

class _MeetSyncAppState extends State<MeetSyncApp> {
  late Future<bool> _initializationFuture;

  @override
  void initState() {
    super.initState();
    _initializationFuture = _ensureFirebaseInitialized();
  }

  Future<bool> _ensureFirebaseInitialized() async {
    try {
      // Check if Firebase is already initialized
      if (Firebase.apps.isNotEmpty) {
        return true;
      }
      
      // Try to initialize Firebase
      await Firebase.initializeApp(options: firebaseOptions);
      return true;
    } catch (e) {
      debugPrint('Firebase initialization check: $e');
      // Return true anyway - let the app try to work
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        // Show loading while checking Firebase status
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Initializing MeetSync Pro...'),
                  ],
                ),
              ),
            ),
          );
        }

        // Build the main app
        return MaterialApp(
          title: 'MeetSync Pro',
          theme: ThemeData(primarySwatch: Colors.blue),
          home: const AuthWrapper(),
          debugShowCheckedModeBanner: false,
          routes: {
            '/privacy-policy': (context) {
              final parentContext = ModalRoute.of(context)!.settings.arguments as BuildContext;
              return PrivacyPolicyPage(parentContext: parentContext);
            },
            '/terms-and-conditions': (context) {
              final parentContext = ModalRoute.of(context)!.settings.arguments as BuildContext;
              return TermsAndConditionsPage(parentContext: parentContext);
            },
            '/settings': (context) => const SettingsPage(),
            '/edit-profile': (context) => const EditProfilePage(),
            '/help': (context) => const HelpPage(),
            '/about': (context) => const AboutPage(),
            '/calendar': (context) => const CalendarPage(),
            '/phone-verification': (context) => const PhoneVerificationPage(),
            '/forgot-password': (context) => const ForgotPasswordPage(),
            '/subscription': (context) => const SubscriptionPage(),
            '/book-meeting': (context) => BookingLookupPage(),
            '/meetings_schedule': (context) => const MeetingSchedulePage(),
            '/my-bookings': (context) => MyBookingsPage(),
          },
          initialRoute: '/',
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Handle authentication errors gracefully
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, size: 64, color: Colors.orange),
                    const SizedBox(height: 16),
                    const Text(
                      'Connection Issue',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Please check your internet connection and try again.',
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        // Restart the AuthWrapper by rebuilding
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const AuthWrapper()),
                        );
                      },
                      child: const Text('Retry Connection'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          if (user == null) {
            return LoginPage();
          }
          return FutureBuilder(
            future: _initializeUserData(user),
            builder: (context, initSnapshot) {
              if (initSnapshot.hasError) {
                return Scaffold(
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_off, size: 64, color: Colors.orange),
                          const SizedBox(height: 16),
                          const Text(
                            'User Setup Issue',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'There was an issue setting up your profile. You can continue to use the app.',
                            style: TextStyle(fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (context) => HomePage()),
                              );
                            },
                            child: const Text('Continue to App'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              
              if (initSnapshot.connectionState == ConnectionState.waiting) {
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Setting up your profile...'),
                      ],
                    ),
                  ),
                );
              }
              return HomePage();
            },
          );
        }
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading authentication...'),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _initializeUserData(User user) async {
    try {
      final usersRef = FirebaseFirestore.instance.collection('users');
      final userDoc = await usersRef.doc(user.uid).get();

      if (!userDoc.exists) {
        final initialData = {
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName ?? 'New User',
          'bookingId': _generateBookingId(),
          'timeZone': 'UTC',
          'createdAt': FieldValue.serverTimestamp(),
          'role': 'host',
        };

        await usersRef.doc(user.uid).set(initialData);

        final dailySlots = await _generateDateSlots();

        await FirebaseFirestore.instance.collection('availability').doc(user.uid).set({
          'hostId': user.uid,
          'timeZone': 'UTC',
          'slots': dailySlots,
        });
      }
    } catch (e) {
      debugPrint('Error initializing user data: $e');
      throw e;
    }
  }

  String _generateBookingId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(8, (index) => chars[Random().nextInt(chars.length)]).join();
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
           '${date.month.toString().padLeft(2, '0')}-'
           '${date.day.toString().padLeft(2, '0')}';
  }

  Future<Map<String, List<String>>> _generateDateSlots() async {
    final now = DateTime.now().toUtc();
    final Map<String, List<String>> dateSlots = {};

    for (int i = 0; i < 14; i++) {
      final date = now.add(Duration(days: i));
      final weekday = date.weekday;

      if (weekday >= 1 && weekday <= 5) {
        dateSlots[_formatDate(date)] = ['09:00-12:00', '14:00-17:00'];
      } else {
        dateSlots[_formatDate(date)] = ['BLOCKED'];
      }
    }
    return dateSlots;
  }
}