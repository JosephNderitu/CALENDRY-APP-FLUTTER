import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../auth/login_page.dart';
import '../booking/meeting_requests_page.dart';
import '../booking/monthly_meetings_page.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _subscriptionStream;
  late Stream<QuerySnapshot> _meetingsStream;

  // --- Environment Configuration ---
  static const bool IS_LOCAL_TESTING = true; // TOGGLE THIS: Set to 'false' for production

  static const String PROD_BASE_URL = 'https://meetsync.pro';

  // IMPORTANT: Use your computer's local IP address or the emulator/simulator alias:
  // 10.0.2.2 for Android Emulator 
  // 127.0.0.1 or localhost for iOS Simulator / Web / Desktop
  // Replace '3000' with the port your local server is running on
  static const String LOCAL_BASE_URL = 'http://10.0.2.2:3000'; 

  // For example, if you are strictly testing on iOS or web:
  // const String LOCAL_BASE_URL = 'http://localhost:3000';

  @override
  void initState() {
    super.initState();
    _initializeStreams();
  }

  void _initializeStreams() {
    final user = _auth.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginPage()),
        );
      });
      return;
    }

    _userStream = _firestore.collection('users').doc(user.uid).snapshots();
    _subscriptionStream = _firestore.collection('subscriptions').doc(user.uid).snapshots();
    _meetingsStream = _firestore
        .collection('meetings')
        .where('hostId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'confirmed')
        .snapshots();
  }

  // Get complete DateTime from date and time slot
  DateTime? _getMeetingDateTime(String dateStr, String timeSlot) {
    try {
      final meetingDate = DateTime.parse(dateStr);
      final timeStr = timeSlot.split('-')[0].trim(); // Get start time
      
      // Parse the time (assuming format like "10:00 AM")
      final timeParts = timeStr.split(' ');
      final hourMin = timeParts[0].split(':');
      int hour = int.parse(hourMin[0]);
      final minute = int.parse(hourMin[1]);
      
      if (timeParts.length > 1 && timeParts[1].toUpperCase() == 'PM' && hour != 12) {
        hour += 12;
      } else if (timeParts.length > 1 && timeParts[1].toUpperCase() == 'AM' && hour == 12) {
        hour = 0;
      }
      
      return DateTime(
        meetingDate.year,
        meetingDate.month,
        meetingDate.day,
        hour,
        minute,
      );
    } catch (e) {
      return null;
    }
  }

  // Check if meeting is today
  bool _isMeetingToday(String dateStr) {
    try {
      final meetingDate = DateTime.parse(dateStr);
      final today = DateTime.now();
      return meetingDate.year == today.year &&
             meetingDate.month == today.month &&
             meetingDate.day == today.day;
    } catch (e) {
      return false;
    }
  }

  // Check if meeting is in the past
  bool _isMeetingPast(String dateStr, String timeSlot) {
    final meetingDateTime = _getMeetingDateTime(dateStr, timeSlot);
    if (meetingDateTime == null) return false;
    return meetingDateTime.isBefore(DateTime.now());
  }

  // Separate meetings into today's and past meetings
  Map<String, List<DocumentSnapshot>> _categorizeMeetings(List<DocumentSnapshot> meetings) {
    final todayMeetings = <DocumentSnapshot>[];
    final pastMeetings = <DocumentSnapshot>[];

    for (final meeting in meetings) {
      final data = meeting.data() as Map<String, dynamic>;
      final date = data['date'] as String? ?? '';
      final timeSlot = data['timeSlot'] as String? ?? '';

      if (_isMeetingToday(date)) {
        todayMeetings.add(meeting);
      } else if (_isMeetingPast(date, timeSlot)) {
        pastMeetings.add(meeting);
      }
    }

    // Sort today's meetings by time (earliest first)
    todayMeetings.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;
      
      final dateTimeA = _getMeetingDateTime(
        dataA['date'] as String? ?? '',
        dataA['timeSlot'] as String? ?? '',
      );
      final dateTimeB = _getMeetingDateTime(
        dataB['date'] as String? ?? '',
        dataB['timeSlot'] as String? ?? '',
      );
      
      if (dateTimeA == null && dateTimeB == null) return 0;
      if (dateTimeA == null) return 1;
      if (dateTimeB == null) return -1;
      
      return dateTimeA.compareTo(dateTimeB);
    });

    // Sort past meetings by date/time (most recent first)
    pastMeetings.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;
      
      final dateTimeA = _getMeetingDateTime(
        dataA['date'] as String? ?? '',
        dataA['timeSlot'] as String? ?? '',
      );
      final dateTimeB = _getMeetingDateTime(
        dataB['date'] as String? ?? '',
        dataB['timeSlot'] as String? ?? '',
      );
      
      if (dateTimeA == null && dateTimeB == null) return 0;
      if (dateTimeA == null) return 1;
      if (dateTimeB == null) return -1;
      
      return dateTimeB.compareTo(dateTimeA); // Reverse order for past meetings
    });

    return {
      'today': todayMeetings,
      'past': pastMeetings,
    };
  }

  Future<void> _rescheduleMeeting(String meetingId, Map<String, dynamic> currentData) async {
    // Get current time in local timezone
    final DateTime now = DateTime.now();
    
    // Step 1: Let user pick a new date (only future dates allowed)
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      selectableDayPredicate: (DateTime date) {
        // Allow selection if it's today or a future date
        return date.isAfter(now.subtract(const Duration(days: 1)));
      },
    );

    if (pickedDate == null) return; // User canceled date picker

    // Step 2: Let user pick a new time (with validation)
    TimeOfDay initialTime = TimeOfDay.now();
    
    // If selected date is today, ensure time is at least 15 minutes from now
    if (DateUtils.isSameDay(pickedDate, now)) {
      initialTime = TimeOfDay.fromDateTime(now.add(const Duration(minutes: 15)));
    }

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              hourMinuteTextColor: MaterialStateColor.resolveWith((states) {
                return states.contains(MaterialState.selected) 
                    ? Colors.blue.shade700 
                    : Colors.grey;
              }),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null) return; // User canceled time picker

    // Step 3: Validate selected time
    final DateTime selectedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (selectedDateTime.isBefore(now.add(const Duration(minutes: 15)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please select a time at least 15 minutes from now',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return; // Don't proceed with invalid time
    }

    // Format the new date and time
    final newDate = DateFormat('yyyy-MM-dd').format(pickedDate);
    final startTime = pickedTime.format(context);
    final endTime = TimeOfDay(
      hour: pickedTime.hour + 1,
      minute: pickedTime.minute,
    ).format(context);
    final newTimeSlot = '$startTime-$endTime';

    // Step 4: Professional confirmation dialog
    final bool? confirmReschedule = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Reschedule", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("New meeting details:", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  const TextSpan(text: "📅 Date: ", style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: "$newDate\n"),
                  const TextSpan(text: "⏰ Time: ", style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: "$startTime - $endTime"),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text("This action cannot be undone.", style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("CONFIRM RESCHEDULE"),
          ),
        ],
      ),
    );

    if (confirmReschedule != true) return;

    // Step 5: Update Firestore
    try {
      await FirebaseFirestore.instance.collection('meetings').doc(meetingId).update({
        'date': newDate,
        'timeSlot': newTimeSlot,
        'status': 'rescheduled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Meeting successfully rescheduled!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reschedule failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    // Check if the URL can be launched before attempting to launch it
    if (await canLaunchUrl(uri)) {
      // Use LaunchMode.externalApplication to open in the device's default web browser
      await launchUrl(uri, mode: LaunchMode.externalApplication); 
    } else {
      // You can add error handling here, like a SnackBar message
      debugPrint('Could not launch $url');
    }
  }

  Widget _buildMeetingCard(DocumentSnapshot meeting, {bool isToday = false}) {
    final data = meeting.data() as Map<String, dynamic>;
    final date = data['date'] as String;
    final timeSlot = data['timeSlot'] as String;
    final guestName = data['guestName'] as String;
    final guestEmail = data['guestEmail'] as String;
    final purpose = data['purpose'] as String? ?? 'No purpose specified';
    final status = data['status'] as String? ?? 'confirmed';
    
    // Format time slot for display
    final formattedTimeSlot = timeSlot.replaceAll('-', ' to ');
    final meetingDate = DateTime.parse(date);
    
    // Status colors
    final statusColors = {
      'confirmed': Colors.green,
      'pending': Colors.orange,
      'rejected': Colors.red,
      'cancelled': Colors.grey,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isToday 
            ? BorderSide(color: Colors.blue.shade200, width: 1)
            : BorderSide.none,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isToday 
              ? LinearGradient(
                  colors: [Colors.blue.shade50, Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isToday ? Colors.blue.shade50 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: statusColors[status]?.withOpacity(0.3) ?? Colors.grey,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      guestName[0].toUpperCase(),
                      style: TextStyle(
                        color: isToday ? Colors.blue.shade800 : Colors.grey.shade800,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              guestName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColors[status]?.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: statusColors[status]?.withOpacity(0.3) ?? Colors.transparent,
                                ),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: statusColors[status],
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          guestEmail,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Today',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  purpose,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time_outlined,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    formattedTimeSlot,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  if (!isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_month,
                            size: 14,
                            color: Colors.blueGrey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('MMM d, yyyy').format(meetingDate),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blueGrey.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (!isToday) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(Icons.email_outlined, size: 16, color: Colors.blue.shade700),
                        label: Text(
                          'CONTACT',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          side: BorderSide(color: Colors.blue.shade100),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          // Implement contact functionality
                          final uri = Uri(
                            scheme: 'mailto',
                            path: guestEmail,
                            queryParameters: {'subject': 'Regarding our meeting on ${DateFormat('MMM d').format(meetingDate)}'},
                          );
                          launchUrl(uri);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(Icons.schedule_outlined, size: 16, color: Colors.orange.shade700),
                        label: Text(
                          'RESCHEDULE',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          side: BorderSide(color: Colors.orange.shade100),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          final data = meeting.data();
                          if (data != null) {
                            _rescheduleMeeting(meeting.id, data as Map<String, dynamic>);
                          }
                        },
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
  }

  Widget _buildSubscriptionStatus(DocumentSnapshot<Map<String, dynamic>>? subscription, 
      {required DateTime? accountCreationDate}) {
    final now = DateTime.now();
    if (accountCreationDate == null) return const SizedBox.shrink();

    final trialEndDate = accountCreationDate.add(const Duration(days: 30));
    final isTrialPeriod = now.isBefore(trialEndDate);
    final hasActiveSubscription = subscription?.data()?['status'] == 'active';
    final hadSubscription = subscription?.exists ?? false;
    final remainingTrialDays = trialEndDate.difference(now).inDays;

    if (hasActiveSubscription) {
      final planName = _getPlanDisplayName(subscription!.data()!['plan'] ?? '');
      return _buildStatusBadge(
        icon: Icons.verified,
        primaryColor: Colors.green,
        text: '$planName • Active',
      );
    }

    if (isTrialPeriod && !hadSubscription) {
      return _buildStatusBadge(
        icon: Icons.star_rounded,
        primaryColor: Colors.pink,
        text: 'Trial • ${remainingTrialDays}d left',
      );
    }

    if (!isTrialPeriod && !hadSubscription) {
      return _buildStatusBadge(
        icon: Icons.hourglass_bottom_rounded,
        primaryColor: Colors.grey,
        text: 'Trial Ended',
      );
    }

    if (hadSubscription) {
      return _buildStatusBadge(
        icon: Icons.warning_rounded,
        primaryColor: Colors.orange,
        text: 'Subscription Expired',
      );
    }

    return const SizedBox.shrink();
  }

  String _getPlanDisplayName(String planId) {
    switch (planId.toLowerCase()) {
      case 'monthly': return 'Pro Monthly';
      case 'quarterly': return 'Pro Quarterly';
      case 'yearly': return 'Pro Annual';
      case 'professional': return 'Pro';
      case 'enterprise': return 'Enterprise';
      default: return 'Pro';
    }
  }

  Widget _buildStatusBadge({
    required IconData icon,
    required MaterialColor primaryColor,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: primaryColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMeetingCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.calendar_today, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text(
              'No meetings scheduled',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Schedule a new meeting or take a break!',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => _createNewMeeting(context),
              child: const Text('Schedule Meeting'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text(
          'No past meetings found',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(String name, String date, String bookingId) {
    final user = _auth.currentUser;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey[200],
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: user?.photoURL == null
                  ? Icon(
                      Icons.person,
                      size: 30,
                      color: Colors.blue[800],
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good ${_getGreeting()},',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          date,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 12),
        _buildBookingIdCard(bookingId),
      ],
    );
  }

  Widget _buildBookingIdCard(String bookingId) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.link, color: Colors.blue[700], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Booking ID',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color.fromARGB(255, 25, 118, 210),
                  ),
                ),
                Text(
                  bookingId,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.content_copy, size: 20),
            onPressed: () => _copyBookingId(bookingId),
          ),
        ],
      ),
    );
  }

  Future<void> _copyBookingId(String bookingId) async {
    try {
      await Clipboard.setData(ClipboardData(text: bookingId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking ID copied to clipboard'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to copy: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildQuickStats(int upcomingCount, int completedCount) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            value: upcomingCount.toString(),
            label: 'Upcoming',
            icon: Icons.event_available,
            color: Colors.blue[700]!,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            value: completedCount.toString(),
            label: 'Completed',
            icon: Icons.history,
            color: Colors.green[700]!,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.add,
            label: 'New Meeting',
            color: Colors.blue[700]!,
            onTap: () => _createNewMeeting(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.link,
            label: 'Share Link',
            color: Colors.green[700]!,
            onTap: () => _showBookingLink(context),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? actionText, VoidCallback? onAction}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        if (actionText != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionText),
          ),
      ],
    );
  }

  void _logout(BuildContext context) async {
    await _auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginPage()),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

// Stream to get count of pending meetings
  Stream<int> _getPendingMeetingsCountStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);

    return FirebaseFirestore.instance
        .collection('meetings')
        .where('hostId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Show booking link dialog
  void _showBookingLink(BuildContext context) {
    // Use the dynamic logic from Section 2 for the base URL
    const String BASE_URL = IS_LOCAL_TESTING ? LOCAL_BASE_URL : PROD_BASE_URL;
    final bookingLink = '$BASE_URL/book/${_auth.currentUser?.uid}';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your Booking Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(bookingLink),
            const SizedBox(height: 16),
            // --- Button to OPEN the link ---
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Booking Page'),
              onPressed: () {
                // Call the launch function
                _launchUrl(bookingLink);
                // Optionally close the dialog after launching
                // Navigator.pop(context); 
              },
            ),
            const SizedBox(height: 8), 
            // --- Button to COPY the link --- (Kept your original functionality)
            OutlinedButton.icon( // Changed style to OutlinedButton to distinguish
              icon: const Icon(Icons.copy),
              label: const Text('Copy Link'),
              onPressed: () {
                Navigator.pop(context);
                _copyBookingId(bookingLink); // Assuming _copyBookingId is defined elsewhere
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  // Show availability settings page
  void _showAvailabilitySettings(BuildContext context) {
    Navigator.pushNamed(context, '/calendar');
  }

  void _showAllMeetings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MonthlyMeetingsPage(), // Direct navigation
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    Navigator.pushNamed(context, '/notifications');
  }

  void _createNewMeeting(BuildContext context) {
    Navigator.pushNamed(context, '/meetings_schedule');
  }

  void _showCalendar(BuildContext context) {
    Navigator.pushNamed(context, '/calendar');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('MeetSync Pro', 
               style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: false,
        elevation: 0,
        actions: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _subscriptionStream,
            builder: (context, snapshot) {
              return _buildSubscriptionStatus(
                snapshot.data,
                accountCreationDate: FirebaseAuth.instance.currentUser?.metadata.creationTime,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications, size: 26),
            onPressed: () => _showNotifications(context),
          ),
          const SizedBox(width: 8),
          StreamBuilder<int>(
            stream: _getPendingMeetingsCountStream(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return IconButton(
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text(count.toString()),
                  child: const Icon(Icons.inbox),
                ),
                tooltip: 'Meeting Requests',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MeetingRequestsPage()),
                  );
                },
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 26),
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'availability',
                child: ListTile(
                  leading: Icon(Icons.calendar_today),
                  title: Text('Set Availability'),
                  subtitle: Text('Configure your working hours'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'booking_link',
                child: ListTile(
                  leading: Icon(Icons.link),
                  title: Text('My Booking Link'),
                  subtitle: Text('Share your scheduling page'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Settings'),
                ),
              ),
              const PopupMenuDivider(height: 8),
              PopupMenuItem<String>(
                value: 'logout',
                child: const ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('Logout', style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
            onSelected: (value) async {
              Navigator.of(context).pop();
              switch (value) {
                case 'logout':
                  _logout(context);
                  break;
                case 'availability':
                  _showAvailabilitySettings(context);
                  break;
                case 'booking_link':
                  _showBookingLink(context);
                  break;
                case 'settings':
                  Navigator.pushNamed(context, '/settings');
                  break;
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userStream,
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = userSnapshot.data!.data() ?? {};
          final displayName = userData['displayName'] ?? 
                            _auth.currentUser?.email?.split('@')[0] ?? 'Host';
          final bookingId = userData['bookingId'] ?? '';
          final currentDate = DateFormat('EEEE, MMMM d').format(DateTime.now());

          return StreamBuilder<QuerySnapshot>(
            stream: _meetingsStream,
            builder: (context, meetingsSnapshot) {
              if (meetingsSnapshot.hasError) {
                return const Center(
                  child: Text('Error loading meetings'),
                );
              }

              if (meetingsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allMeetings = meetingsSnapshot.data?.docs ?? [];
              final categorizedMeetings = _categorizeMeetings(allMeetings);
              final todayMeetings = categorizedMeetings['today'] ?? [];
              final pastMeetings = categorizedMeetings['past'] ?? [];

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeSection(displayName, currentDate, bookingId),
                    const SizedBox(height: 32),
                    _buildQuickStats(todayMeetings.length, pastMeetings.length),
                    const SizedBox(height: 24),
                    _buildQuickActions(),
                    const SizedBox(height: 32),
                    _buildSectionHeader("Today's Schedule", 
                        actionText: "View Calendar", 
                        onAction: () => _showCalendar(context)),
                    const SizedBox(height: 16),
                    if (todayMeetings.isEmpty)
                      _buildEmptyMeetingCard()
                    else
                      ...todayMeetings.map((meeting) => _buildMeetingCard(meeting, isToday: true)),
                    const SizedBox(height: 32),
                    _buildSectionHeader("Meeting History", 
                        actionText: "See All", 
                        onAction: () => _showAllMeetings(context)),
                    const SizedBox(height: 16),
                    if (pastMeetings.isEmpty)
                      _buildEmptyHistoryCard()
                    else
                      ...pastMeetings.take(3).map((meeting) => _buildMeetingCard(meeting)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}