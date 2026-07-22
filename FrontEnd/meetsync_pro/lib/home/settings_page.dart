//settings_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:meetsync_pro/home/home_page.dart';

import '../auth/google_sign_in_helper.dart';
import '../auth/login_page.dart';
import '../settings_content/phone_verification_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  File? _profileImage;
  bool _isLoading = false;
  bool _darkMode = false;
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _whatsappNotifications = false;
  
  // Phone number related variables
  String? _phoneNumber;
  bool _phoneVerified = false;
  bool _hasPhoneNumber = false;

  @override
  void initState() {
    super.initState();
    _loadPhoneNumberData();
  }

  // Load phone number data from Firestore
  Future<void> _loadPhoneNumberData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        
        if (doc.exists && mounted) {
          final data = doc.data()!;
          setState(() {
            _phoneNumber = data['phoneNumber'] as String?;
            _phoneVerified = data['phoneVerified'] ?? false;
            _hasPhoneNumber = _phoneNumber != null && _phoneNumber!.isNotEmpty;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading phone number data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final displayName = user?.displayName ?? 'User';
    final email = user?.email ?? 'No email';
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
            centerTitle: true,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const HomePage()),
                  (Route<dynamic> route) => false,
                );
              },
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Section
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: _profileImage != null
                                ? FileImage(_profileImage!)
                                : (user?.photoURL != null
                                    ? NetworkImage(user!.photoURL!)
                                    : null),
                            child: _profileImage == null && user?.photoURL == null
                                ? const Icon(Icons.person, size: 50)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDarkMode ? Colors.grey[800]! : Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                                onPressed: _changeProfileImage,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Account Settings
                _buildSectionHeader('Account Settings'),
                _buildSettingsTile(
                  icon: Icons.person_outline,
                  title: 'Edit Profile',
                  onTap: () => _navigateToEditProfile(),
                ),
                _buildSettingsTile(
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  onTap: _changePassword,
                ),
                _buildSettingsTile(
                  icon: Icons.email_outlined,
                  title: 'Email Address',
                  subtitle: email,
                  onTap: () => _navigateToEditEmail(),
                ),
                // Updated phone number tile with dynamic status
                _buildPhoneNumberTile(),
                const SizedBox(height: 24),

                // Notification Settings
                _buildSectionHeader('Notifications'),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_outlined),
                  title: const Text('Push Notifications'),
                  value: _pushNotifications,
                  onChanged: (value) => setState(() => _pushNotifications = value),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.email_outlined),
                  title: const Text('Email Notifications'),
                  value: _emailNotifications,
                  onChanged: (value) => setState(() => _emailNotifications = value),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.message_outlined),
                  title: const Text('WhatsApp Notifications'),
                  value: _whatsappNotifications,
                  onChanged: (value) => setState(() => _whatsappNotifications = value),
                ),
                const SizedBox(height: 24),

                // App Preferences
                _buildSectionHeader('App Preferences'),
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Dark Mode'),
                  value: _darkMode,
                  onChanged: (value) => setState(() => _darkMode = value),
                ),
                _buildSettingsTile(
                  icon: Icons.language_outlined,
                  title: 'Language',
                  subtitle: 'English',
                  onTap: () => _changeLanguage(),
                ),
                const SizedBox(height: 24),

                // Subscription & Support
                _buildSectionHeader('Subscription & Support'),
                _buildSettingsTile(
                  icon: Icons.credit_card_outlined,
                  title: 'Subscription Plan',
                  subtitle: 'choose a subscription plan.',
                  onTap: () => _navigateToSubscription(),
                ),
                _buildSettingsTile(
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  onTap: () => _navigateToHelp(),
                ),
                _buildSettingsTile(
                  icon: Icons.info_outline,
                  title: 'About MeetSync Pro',
                  onTap: () => _navigateToAbout(),
                ),
                const SizedBox(height: 32),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _confirmLogout(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.red.shade300),
                    ),
                    child: Text(
                      'Log Out',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Delete Account
                TextButton(
                  onPressed: _confirmDeleteAccount,
                  child: const Text(
                    'Delete Account',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isLoading)
          const Scaffold(
            backgroundColor: Colors.black54,
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  // New method to build phone number tile with dynamic status
  Widget _buildPhoneNumberTile() {
    String displayText;
    Color statusColor;
    IconData statusIcon;

    if (!_hasPhoneNumber) {
      displayText = 'Not set';
      statusColor = Colors.orange;
      statusIcon = Icons.add_circle_outline;
    } else if (_phoneVerified) {
      displayText = _phoneNumber!;
      statusColor = Colors.green;
      statusIcon = Icons.verified;
    } else {
      displayText = '$_phoneNumber (Not verified)';
      statusColor = Colors.orange;
      statusIcon = Icons.warning_outlined;
    }

    return ListTile(
      leading: const Icon(Icons.phone_outlined),
      title: const Text('Phone Number'),
      subtitle: Row(
        children: [
          Icon(
            statusIcon,
            size: 16,
            color: statusColor,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              displayText,
              style: TextStyle(color: statusColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: _addPhoneNumber,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Future<void> _changeProfileImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
        // Upload to Firebase Storage
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('${_auth.currentUser!.uid}.jpg');
        await ref.putFile(_profileImage!);
        final url = await ref.getDownloadURL();
        await _auth.currentUser!.updatePhotoURL(url);
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .update({'photoUrl': url});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _changePassword() async {
    try {
      setState(() => _isLoading = true);
      await _auth.sendPasswordResetEmail(email: _auth.currentUser!.email!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addPhoneNumber() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const PhoneVerificationPage()),
    );
    
    if (result == true) {
      // Reload phone number data after returning from phone verification
      await _loadPhoneNumberData();
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_phoneVerified 
            ? 'Phone number verified successfully' 
            : 'Phone number saved successfully'),
          backgroundColor: _phoneVerified ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        // Perform logout operations
        await GoogleSignInHelper.signOutFromGoogle();
        await FirebaseAuth.instance.signOut();

        // Dismiss loading and navigate
        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog
        
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
          (Route<dynamic> route) => false,
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('This will permanently delete your account and all data. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        setState(() => _isLoading = true);
        await _firestore.collection('users').doc(_auth.currentUser!.uid).delete();
        await _auth.currentUser!.delete();
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // Navigation methods
  void _navigateToEditProfile() {
    Navigator.pushNamed(context, '/edit-profile');
  }

  void _navigateToEditEmail() {
    Navigator.pushNamed(context, '/edit-email');
  }

  void _navigateToSubscription() {
    Navigator.pushNamed(context, '/subscription');
  }

  void _navigateToHelp() {
    Navigator.pushNamed(context, '/help');
  }

  void _navigateToAbout() {
    Navigator.pushNamed(context, '/about');
  }

  void _changeLanguage() {
    // Implement language change
  }
}