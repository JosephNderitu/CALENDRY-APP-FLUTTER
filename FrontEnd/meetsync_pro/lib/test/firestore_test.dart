import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreTestPage extends StatelessWidget {
  const FirestoreTestPage({Key? key}) : super(key: key);

  Future<void> _testFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Write test
        await FirebaseFirestore.instance.collection('test').doc(user.uid).set({
          'test': 'success',
          'timestamp': FieldValue.serverTimestamp()
        });
        
        // Read test
        final doc = await FirebaseFirestore.instance.collection('test').doc(user.uid).get();
        print('Firestore test successful: ${doc.data()}');
      }
    } catch (e) {
      print('Firestore test failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firestore Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Press to test Firestore connection'),
            ElevatedButton(
              onPressed: _testFirestore,
              child: const Text('Run Test'),
            ),
          ],
        ),
      ),
    );
  }
}