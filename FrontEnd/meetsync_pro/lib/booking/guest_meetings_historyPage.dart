import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class MyBookingsPage extends StatefulWidget {
  @override
  _MyBookingsPageState createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<MyBookingsPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _verificationCodeController = TextEditingController();

  static const ownerEmail = 'gikurujoseph53@gmail.com';
  
  bool _isLoading = false;
  bool _isCodeSent = false;
  bool _isVerified = false;
  String? _errorMessage;
  String? _generatedCode;
  String? _verifiedEmail;
  List<QueryDocumentSnapshot> _meetings = [];
  Timer? _resendTimer;
  int _resendCountdown = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _verificationCodeController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  String _generateVerificationCode(String email) {
    // Check if the email matches the owner's email
    if (email.toLowerCase() == ownerEmail.toLowerCase()) {
      return '000000'; // Default code for owner
    }
    
    // Generate random code for all other emails
    final random = Random();
    return List.generate(6, (index) => random.nextInt(10).toString()).join();
  }

  Future<void> _sendVerificationCode() async {
    final email = _emailController.text.trim().toLowerCase();
    
    if (email.isEmpty || !_isValidEmail(email)) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check for bookings first
      final meetingsQuery = await FirebaseFirestore.instance
          .collection('meetings')
          .where('guestEmail', isEqualTo: email)
          .limit(1)
          .get();

      if (meetingsQuery.docs.isEmpty) {
        setState(() => _errorMessage = 'No bookings found for this email address');
        return;
      }

      // Generate new code
      _generatedCode = _generateVerificationCode(email);
      
      // Create or update verification document
      await FirebaseFirestore.instance
          .collection('email_verifications')
          .doc(email.replaceAll('.', '_'))
          .set({
            'email': email,
            'code': _generatedCode,
            'createdAt': FieldValue.serverTimestamp(),
            'expiresAt': DateTime.now().add(Duration(minutes: 30)).toIso8601String(),
          }, SetOptions(merge: true)); // This allows updating existing docs

      _showVerificationCodeDialog(isOwner: email == ownerEmail);

      setState(() {
        _isCodeSent = true;
        _resendCountdown = 60;
      });
      
      _startResendTimer();

    } catch (e) {
      setState(() => _errorMessage = 'Failed to send verification code. Please try again.');
      debugPrint('Verification error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showVerificationCodeDialog({bool isOwner = false}) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with adaptive icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOwner ? Icons.admin_panel_settings : Icons.mark_email_read,
                  size: 36,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                isOwner ? 'Developer Access' : 'Email Verification',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                isOwner 
                    ? 'Use your developer verification code'
                    : 'Verification code sent to your email',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: theme.textTheme.bodyLarge?.color?.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 20),

              // Information box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: isOwner ? Colors.blue : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isOwner ? 'Developer Notes' : 'Troubleshooting',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isOwner
                          ? '• Bypasses standard email verification\n'
                              '• For development purposes only\n'
                              '• Keep your code secure'
                          : '• Check spam/junk folder\n'
                              '• Allow 5 minutes for delivery\n'
                              '• Verify email address is correct',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) {
          timer.cancel();
        }
      });
    });
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  Future<void> _verifyCode() async {
    final code = _verificationCodeController.text.trim();
    
    if (code.isEmpty || code.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit verification code');
      return;
    }

    if (code != _generatedCode) {
      setState(() => _errorMessage = 'Invalid verification code. Please try again.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch all meetings for the verified email
      await _loadMeetings(_emailController.text.trim().toLowerCase());
      
      setState(() {
        _isVerified = true;
        _verifiedEmail = _emailController.text.trim().toLowerCase();
      });

      // Clean up verification document
      await FirebaseFirestore.instance
          .collection('email_verifications')
          .doc(_verifiedEmail!.replaceAll('.', '_'))
          .delete();

    } catch (e) {
      setState(() => _errorMessage = 'Failed to load meetings: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMeetings(String email) async {
    try {
      final meetingsQuery = await FirebaseFirestore.instance
          .collection('meetings')
          .where('guestEmail', isEqualTo: email)
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _meetings = meetingsQuery.docs;
      });
    } catch (e) {
      // Extract the index creation link from the error (if available)
      final errorMessage = e.toString();
      final indexLink = errorMessage.contains('https://') 
          ? errorMessage.substring(errorMessage.indexOf('https://'))
          : 'No link provided in error';

      // Log to console (clickable in VS Code)
      debugPrint('🔥 Firestore Error: $errorMessage');
      debugPrint('👉 CREATE MISSING INDEX HERE: $indexLink');

      // Show error to user
      setState(() {
        _errorMessage = 'Failed to load meetings. Check console for index creation link.';
      });
    }
  }

  Future<void> _refreshMeetings() async {
    if (_verifiedEmail != null) {
      setState(() => _isLoading = true);
      try {
        await _loadMeetings(_verifiedEmail!);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh meetings: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetVerification() {
    setState(() {
      _isCodeSent = false;
      _isVerified = false;
      _errorMessage = null;
      _generatedCode = null;
      _verifiedEmail = null;
      _meetings = [];
      _resendCountdown = 0;
      _emailController.clear();
      _verificationCodeController.clear();
    });
    _resendTimer?.cancel();
  }

  String _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return '#10B981'; // Green
      case 'pending':
        return '#F59E0B'; // Orange
      case 'rejected':
        return '#EF4444'; // Red
      case 'rescheduled':
        return '#8B5CF6'; // Purple
      default:
        return '#6B7280'; // Gray
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'rejected':
        return Icons.cancel;
      case 'rescheduled':
        return Icons.update;
      default:
        return Icons.help_outline;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('EEE, MMM d, y').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatTimeSlot(String timeSlot) {
    try {
      final parts = timeSlot.split('-');
      if (parts.length == 2) {
        final startTime = parts[0];
        final endTime = parts[1];
        
        final startHour = int.parse(startTime.split(':')[0]);
        final endHour = int.parse(endTime.split(':')[0]);
        
        String formatHour(int hour) {
          if (hour == 0) return '12:00 AM';
          if (hour < 12) return '$hour:00 AM';
          if (hour == 12) return '12:00 PM';
          return '${hour - 12}:00 PM';
        }
        
        return '${formatHour(startHour)} - ${formatHour(endHour)}';
      }
      return timeSlot;
    } catch (e) {
      return timeSlot;
    }
  }

  Widget _buildVerificationForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.verified_user,
                    color: Colors.blue[700],
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Email Verification Required',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        'Enter your email to view your bookings',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            
            if (!_isCodeSent) ...[
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'Enter the email used for booking',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                textCapitalization: TextCapitalization.none,
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendVerificationCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Send Verification Code',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ] else ...[
              Text(
                'Verification code sent to:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 4),
              Text(
                _emailController.text.trim(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _verificationCodeController,
                decoration: InputDecoration(
                  labelText: 'Verification Code',
                  hintText: 'Enter 6-digit code',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.security),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text('Verify Code'),
                    ),
                  ),
                  SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _resendCountdown > 0 ? null : _sendVerificationCode,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    ),
                    child: Text(_resendCountdown > 0 
                        ? 'Resend (${_resendCountdown}s)' 
                        : 'Resend'),
                  ),
                ],
              ),
              SizedBox(height: 12),
              TextButton(
                onPressed: _resetVerification,
                child: Text('Use different email'),
              ),
            ],
            
            if (_errorMessage != null) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingsList() {
    if (_meetings.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            children: [
              Icon(
                Icons.event_busy,
                size: 64,
                color: Colors.grey[400],
              ),
              SizedBox(height: 16),
              Text(
                'No Bookings Found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'You don\'t have any meeting bookings yet.',
                style: TextStyle(
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Stats Header
        Container(
          margin: EdgeInsets.only(bottom: 16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[600]!, Colors.blue[400]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Bookings',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${_meetings.length}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_today,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
        
        // Meetings List
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: _meetings.length,
          itemBuilder: (context, index) {
            final meeting = _meetings[index];
            final data = meeting.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'unknown';
            final statusColor = Color(int.parse(_getStatusColor(status).replaceAll('#', '0xFF')));
            
            return Card(
              elevation: 2,
              margin: EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showMeetingDetails(data),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: statusColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getStatusIcon(status),
                                  color: statusColor,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Spacer(),
                          Text(
                            _formatDate(data['date'] ?? ''),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.person, size: 18, color: Colors.grey[600]),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'with ${data['hostName'] ?? 'Unknown Host'}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 18, color: Colors.grey[600]),
                          SizedBox(width: 8),
                          Text(
                            _formatTimeSlot(data['timeSlot'] ?? ''),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      if (data['purpose'] != null && data['purpose'].toString().isNotEmpty) ...[
                        SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.description, size: 18, color: Colors.grey[600]),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                data['purpose'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showMeetingDetails(Map<String, dynamic> meetingData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.event, size: 28, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Meeting Details',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color(int.parse(_getStatusColor(meetingData['status']).replaceAll('#', '0xFF'))).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        (meetingData['status'] ?? 'unknown').toUpperCase(),
                        style: TextStyle(
                          color: Color(int.parse(_getStatusColor(meetingData['status']).replaceAll('#', '0xFF'))),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                _buildDetailRow('Date', _formatDate(meetingData['date'] ?? ''), Icons.calendar_today),
                _buildDetailRow('Time', _formatTimeSlot(meetingData['timeSlot'] ?? ''), Icons.access_time),
                _buildDetailRow('Host', meetingData['hostName'] ?? 'Unknown', Icons.person),
                _buildDetailRow('Host Email', meetingData['hostEmail'] ?? 'Unknown', Icons.email),
                if (meetingData['purpose'] != null && meetingData['purpose'].toString().isNotEmpty)
                  _buildDetailRow('Purpose', meetingData['purpose'], Icons.description),
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Bookings'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isVerified)
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _refreshMeetings,
              tooltip: 'Refresh',
            ),
          if (_isVerified)
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: _resetVerification,
              tooltip: 'Sign Out',
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue[50]!,
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isVerified) ...[
                _buildVerificationForm(),
              ] else ...[
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.green[100],
                      child: Icon(Icons.verified, color: Colors.green[700]),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Verified',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                          Text(
                            _verifiedEmail!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                if (_isLoading)
                  Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading your bookings...'),
                      ],
                    ),
                  )
                else
                  _buildMeetingsList(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}