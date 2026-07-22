import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class GoogleSignInHelper {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', 'https://www.googleapis.com/auth/calendar'],
    clientId: kIsWeb ? '869886843088-0au7oht3r89179srr8s8e082if9oepto.apps.googleusercontent.com' : null,
  );
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web-specific initialization
        await _ensureWebInitialized();
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = 
          await _auth.signInWithCredential(credential);

      return userCredential.user;
    } catch (e) {
      print('Google sign in error: $e');
      return null;
    }
    
  }

  static Future<void> _ensureWebInitialized() async {
    // No explicit initialization needed for newer versions
    // The clientId provided in constructor is sufficient
  }

  static Future<void> signOutFromGoogle() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}