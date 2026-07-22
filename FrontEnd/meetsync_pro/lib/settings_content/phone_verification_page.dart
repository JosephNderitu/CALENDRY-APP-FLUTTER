// phone_verification_page.dart
// This file handles phone number verification using Firebase Auth and Firestore.
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class PhoneVerificationPage extends StatefulWidget {
  const PhoneVerificationPage({Key? key}) : super(key: key);

  @override
  _PhoneVerificationPageState createState() => _PhoneVerificationPageState();
}

class _PhoneVerificationPageState extends State<PhoneVerificationPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  String? _verificationId;
  int? _resendToken;
  bool _isLoading = false;
  bool _codeSent = false;
  String? _errorMessage;
  bool _canResend = false;
  int _resendTimeout = 30;
  Timer? _resendTimer;
  
  // New properties for country selection and optional verification
  String _selectedCountryCode = '+1';
  String _selectedCountryName = 'United States';
  bool _wantsVerification = false;
  
  // Properties for existing phone number
  bool _hasExistingNumber = false;
  String? _existingPhoneNumber;
  bool _isExistingNumberVerified = false;
  bool _isEditing = false;

  // Common country codes
  final List<Map<String, String>> _countries = [
    {'code': '+1', 'name': 'United States', 'flag': '🇺🇸'},
    {'code': '+1', 'name': 'Canada', 'flag': '🇨🇦'},
    {'code': '+44', 'name': 'United Kingdom', 'flag': '🇬🇧'},
    {'code': '+33', 'name': 'France', 'flag': '🇫🇷'},
    {'code': '+49', 'name': 'Germany', 'flag': '🇩🇪'},
    {'code': '+39', 'name': 'Italy', 'flag': '🇮🇹'},
    {'code': '+34', 'name': 'Spain', 'flag': '🇪🇸'},
    {'code': '+81', 'name': 'Japan', 'flag': '🇯🇵'},
    {'code': '+82', 'name': 'South Korea', 'flag': '🇰🇷'},
    {'code': '+86', 'name': 'China', 'flag': '🇨🇳'},
    {'code': '+91', 'name': 'India', 'flag': '🇮🇳'},
    {'code': '+55', 'name': 'Brazil', 'flag': '🇧🇷'},
    {'code': '+52', 'name': 'Mexico', 'flag': '🇲🇽'},
    {'code': '+61', 'name': 'Australia', 'flag': '🇦🇺'},
    {'code': '+7', 'name': 'Russia', 'flag': '🇷🇺'},
    {'code': '+254', 'name': 'Kenya', 'flag': '🇰🇪'},
    {'code': '+234', 'name': 'Nigeria', 'flag': '🇳🇬'},
    {'code': '+27', 'name': 'South Africa', 'flag': '🇿🇦'},
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingPhoneNumber();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  // Load existing phone number from Firestore
  Future<void> _loadExistingPhoneNumber() async {
    try {
      final user = _auth.currentUser!;
      final doc = await _firestore.collection('users').doc(user.uid).get();
      
      if (doc.exists && doc.data()!.containsKey('phoneNumber')) {
        final data = doc.data()!;
        final phoneNumber = data['phoneNumber'] as String?;
        
        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          setState(() {
            _hasExistingNumber = true;
            _existingPhoneNumber = phoneNumber;
            _isExistingNumberVerified = data['phoneVerified'] ?? false;
            
            // Parse country code and phone number
            final countryCode = data['countryCode'] as String?;
            final countryName = data['countryName'] as String?;
            
            if (countryCode != null) {
              _selectedCountryCode = countryCode;
            }
            if (countryName != null) {
              _selectedCountryName = countryName;
            }
            
            // Extract local number (remove country code) for display in text field
            String localNumber = phoneNumber;
            if (localNumber.startsWith(countryCode ?? '')) {
              localNumber = localNumber.substring(countryCode!.length);
            }
            _phoneController.text = localNumber;
          });
        }
      }
    } catch (e) {
      // Handle error silently or show a message
      debugPrint('Error loading existing phone number: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_codeSent ? 'Verify Code' : (_hasExistingNumber && !_isEditing ? 'Phone Number' : 'Add Phone Number')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              if (!_codeSent && _hasExistingNumber && !_isEditing) ...[
                // Display existing phone number
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Current Phone Number',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            if (_isExistingNumberVerified)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.verified, color: Colors.green, size: 16),
                                    SizedBox(width: 4),
                                    Text('Verified', style: TextStyle(color: Colors.green, fontSize: 12)),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.warning, color: Colors.orange, size: 16),
                                    SizedBox(width: 4),
                                    Text('Not Verified', style: TextStyle(color: Colors.orange, fontSize: 12)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _countries.firstWhere(
                                  (country) => country['code'] == _selectedCountryCode && country['name'] == _selectedCountryName,
                                  orElse: () => {'flag': '🌍'},
                                )['flag'] ?? '🌍',
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _existingPhoneNumber!,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    _selectedCountryName,
                                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => setState(() => _isEditing = true),
                                icon: const Icon(Icons.edit),
                                label: const Text('Edit Number'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (!_isExistingNumberVerified)
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _wantsVerification = true;
                                      _isEditing = true;
                                    });
                                  },
                                  icon: const Icon(Icons.verified_user),
                                  label: const Text('Verify'),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (!_codeSent) ...[
                const Text(
                  'Enter your phone number',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _hasExistingNumber 
                    ? 'Update your phone number and verification status'
                    : 'You can choose to verify it now or skip verification',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                
                // Country Code Selector
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ListTile(
                    leading: Text(
                      _countries.firstWhere((country) => 
                        country['code'] == _selectedCountryCode && 
                        country['name'] == _selectedCountryName)['flag'] ?? '🌍',
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text('$_selectedCountryName $_selectedCountryCode'),
                    trailing: const Icon(Icons.arrow_drop_down),
                    onTap: _showCountryPicker,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Phone Number Input
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: _getPhoneHint(),
                    helperText: 'Enter without country code. Leading zero will be removed automatically.',
                    border: const OutlineInputBorder(),
                    errorText: _errorMessage,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    // Remove leading zero and non-digits for validation
                    String cleanValue = value.trim().replaceAll(RegExp(r'[^\d]'), '');
                    if (cleanValue.startsWith('0')) {
                      cleanValue = cleanValue.substring(1);
                    }
                    if (cleanValue.length < 6 || cleanValue.length > 15) {
                      return 'Please enter a valid phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // Verification Option Toggle
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Verification Options',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        RadioListTile<bool>(
                          title: const Text('Save without verification'),
                          subtitle: const Text('Add phone number to profile without verification'),
                          value: false,
                          groupValue: _wantsVerification,
                          onChanged: (value) => setState(() => _wantsVerification = value!),
                          contentPadding: EdgeInsets.zero,
                        ),
                        RadioListTile<bool>(
                          title: const Text('Verify phone number'),
                          subtitle: const Text('Send SMS verification code'),
                          value: true,
                          groupValue: _wantsVerification,
                          onChanged: (value) => setState(() => _wantsVerification = value!),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Action Buttons
                Column(
                  children: [
                    if (_hasExistingNumber && _isEditing) ...[
                      OutlinedButton(
                        onPressed: _isLoading ? null : () {
                          setState(() {
                            _isEditing = false;
                            _wantsVerification = false;
                            // Reset to original values
                            _loadExistingPhoneNumber();
                          });
                        },
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : (_wantsVerification ? _verifyPhoneNumber : _savePhoneNumberDirectly),
                        child: Text(_hasExistingNumber 
                          ? (_wantsVerification ? 'Send Verification Code' : 'Update Phone Number')
                          : (_wantsVerification ? 'Send Verification Code' : 'Save Phone Number')),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const Text(
                  'Enter the 6-digit code sent to your phone',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Verification Code',
                    border: const OutlineInputBorder(),
                    errorText: _errorMessage,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the verification code';
                    }
                    if (value.length != 6) {
                      return 'Code must be 6 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyCode,
                    child: const Text('Verify Code'),
                  ),
                ),
                const SizedBox(height: 16),
                if (!_canResend)
                  Text(
                    'Resend code in $_resendTimeout seconds',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).disabledColor),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _resendCode,
                      child: const Text('Resend Code'),
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => setState(() {
                      _codeSent = false;
                      _errorMessage = null;
                      _resendTimer?.cancel();
                    }),
                    child: const Text('Change Phone Number'),
                  ),
                ),
                const SizedBox(height: 8),
                // Option to skip verification
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _savePhoneNumberDirectly,
                    child: const Text('Skip Verification & Save Number'),
                  ),
                ),
              ],
              if (_isLoading) 
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              const SizedBox(height: 20), // Extra space at bottom
            ],
          ),
        ),
      ),
    ),
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 400,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: const Text(
                  'Select Country',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _countries.length,
                  itemBuilder: (context, index) {
                    final country = _countries[index];
                    return ListTile(
                      leading: Text(
                        country['flag']!,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(country['name']!),
                      trailing: Text(
                        country['code']!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedCountryCode = country['code']!;
                          _selectedCountryName = country['name']!;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper method to get appropriate phone number hint based on selected country
  String _getPhoneHint() {
    switch (_selectedCountryCode) {
      case '+254': // Kenya
        return '0712345678 or 712345678';
      case '+234': // Nigeria
        return '08012345678 or 8012345678';
      case '+27': // South Africa
        return '0821234567 or 821234567';
      case '+1': // US/Canada
        return '2345678901';
      case '+44': // UK
        return '7700123456';
      default:
        return 'Enter your phone number';
    }
  }

  // Helper method to format phone number correctly
  String _formatPhoneNumber(String phoneNumber) {
    String cleanNumber = phoneNumber.trim();
    
    // Remove any leading zero if present
    if (cleanNumber.startsWith('0')) {
      cleanNumber = cleanNumber.substring(1);
    }
    
    // Remove any spaces, dashes, or other formatting
    cleanNumber = cleanNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    return '$_selectedCountryCode$cleanNumber';
  }

  // New method to save phone number directly without verification
  Future<void> _savePhoneNumberDirectly() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _auth.currentUser!;
      final fullPhoneNumber = _formatPhoneNumber(_phoneController.text);
      
      // Save to Firestore with verification status
      await _firestore.collection('users').doc(user.uid).update({
        'phoneNumber': fullPhoneNumber,
        'countryCode': _selectedCountryCode,
        'countryName': _selectedCountryName,
        'phoneVerified': false,
        'phoneAddedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      
      final String successMessage = _hasExistingNumber 
        ? 'Phone number updated successfully'
        : 'Phone number saved successfully';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save phone number. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _startResendTimer() {
    setState(() {
      _canResend = false;
      _resendTimeout = 30;
    });
    
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimeout <= 0) {
        timer.cancel();
        setState(() => _canResend = true);
      } else {
        setState(() => _resendTimeout--);
      }
    });
  }

  Future<void> _verifyPhoneNumber() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final phoneNumber = _formatPhoneNumber(_phoneController.text);
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Silent verification succeeded
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _errorMessage = _getErrorMessage(e.code);
            _isLoading = false;
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          // Silent verification failed, fallback to SMS with reCAPTCHA
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _codeSent = true;
            _isLoading = false;
          });
          _startResendTimer();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final phoneNumber = _formatPhoneNumber(_phoneController.text);
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _errorMessage = _getErrorMessage(e.code);
            _isLoading = false;
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _isLoading = false;
          });
          _startResendTimer();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to resend code. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_verificationId == null) {
      setState(() {
        _errorMessage = 'Verification session expired. Please start again.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _codeController.text.trim(),
      );
      await _signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e.code);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Invalid verification code';
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final user = _auth.currentUser!;
      await user.linkWithCredential(credential);
      
      // Update phone number in Firestore with verification status
      await _firestore.collection('users').doc(user.uid).update({
        'phoneNumber': user.phoneNumber,
        'countryCode': _selectedCountryCode,
        'countryName': _selectedCountryName,
        'phoneVerified': true,
        'phoneVerifiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      
      final String successMessage = _hasExistingNumber 
        ? 'Phone number updated and verified successfully'
        : 'Phone number verified and saved successfully';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e.code);
        _isLoading = false;
      });
    }
  }

  String _getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'invalid-phone-number':
        return 'Invalid phone number format';
      case 'too-many-requests':
        return 'Too many requests. Please try again later';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later';
      case 'credential-already-in-use':
        return 'This phone number is already linked to another account';
      case 'missing-client-identifier':
        return 'Silent verification failed. Please try SMS verification';
      case 'missing-application-context':
        return 'Silent verification not available. Please try SMS verification';
      case 'invalid-verification-code':
        return 'Invalid verification code. Please try again';
      case 'session-expired':
        return 'Session expired. Please request a new code';
      default:
        return 'Verification failed. Please try again';
    }
  }
}