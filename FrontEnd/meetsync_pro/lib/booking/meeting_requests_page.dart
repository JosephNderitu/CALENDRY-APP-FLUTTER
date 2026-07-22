import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class MeetingRequestsPage extends StatefulWidget {
  const MeetingRequestsPage({Key? key}) : super(key: key);

  @override
  _MeetingRequestsPageState createState() => _MeetingRequestsPageState();
}

class _MeetingRequestsPageState extends State<MeetingRequestsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Stream<QuerySnapshot> _meetingsStream;
  
  // Search and filter controllers
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, expired, upcoming
  bool _isSearchExpanded = false;

  @override
  void initState() {
    super.initState();
    _initializeStream();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initializeStream() {
    final user = _auth.currentUser;
    if (user == null) return;

    _meetingsStream = _firestore
        .collection('meetings')
        .where('hostId', isEqualTo: user.uid)
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

  // Check if meeting date has expired
  bool _isMeetingExpired(String dateStr, String timeSlot) {
    final meetingDateTime = _getMeetingDateTime(dateStr, timeSlot);
    if (meetingDateTime == null) return false;
    return meetingDateTime.isBefore(DateTime.now());
  }

  // Get time until meeting (for sorting and display)
  Duration? _getTimeUntilMeeting(String dateStr, String timeSlot) {
    final meetingDateTime = _getMeetingDateTime(dateStr, timeSlot);
    if (meetingDateTime == null) return null;
    return meetingDateTime.difference(DateTime.now());
  }

  // Sort meetings by date and time
  List<DocumentSnapshot> _sortMeetings(List<DocumentSnapshot> meetings) {
    if (meetings.isEmpty) return [];
    
    // Separate upcoming and expired meetings
    final upcomingMeetings = <DocumentSnapshot>[];
    final expiredMeetings = <DocumentSnapshot>[];
    
    for (final meeting in meetings) {
      final data = meeting.data() as Map<String, dynamic>;
      final date = data['date'] as String? ?? '';
      final timeSlot = data['timeSlot'] as String? ?? '';
      
      if (_isMeetingExpired(date, timeSlot)) {
        expiredMeetings.add(meeting);
      } else {
        upcomingMeetings.add(meeting);
      }
    }
    
    // Sort upcoming meetings by date/time (earliest first)
    upcomingMeetings.sort((a, b) {
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
    
    // Sort expired meetings by date/time (most recently expired first)
    expiredMeetings.sort((a, b) {
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
      
      return dateTimeB.compareTo(dateTimeA); // Reverse order for expired
    });
    
    // Combine lists: upcoming first, then expired
    return [...upcomingMeetings, ...expiredMeetings];
  }

  // Filter meetings based on search and filter criteria
  List<DocumentSnapshot> _filterMeetings(List<DocumentSnapshot> meetings) {
    return meetings.where((meeting) {
      final data = meeting.data() as Map<String, dynamic>;
      
      // Only show pending meetings
      if (data['status'] != 'pending') return false;
      
      final guestName = (data['guestName'] as String? ?? '').toLowerCase();
      final guestEmail = (data['guestEmail'] as String? ?? '').toLowerCase();
      final purpose = (data['purpose'] as String? ?? '').toLowerCase();
      final date = data['date'] as String? ?? '';
      final timeSlot = data['timeSlot'] as String? ?? '';
      
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final searchMatch = guestName.contains(_searchQuery) ||
            guestEmail.contains(_searchQuery) ||
            purpose.contains(_searchQuery) ||
            date.toLowerCase().contains(_searchQuery) ||
            timeSlot.toLowerCase().contains(_searchQuery);
        
        if (!searchMatch) return false;
      }
      
      // Time filter
      if (_selectedFilter != 'all') {
        final isExpired = _isMeetingExpired(date, timeSlot);
        
        switch (_selectedFilter) {
          case 'expired':
            return isExpired;
          case 'upcoming':
            return !isExpired;
        }
      }
      
      return true;
    }).toList();
  }

  Future<void> _updateMeetingStatus(String meetingId, String status) async {
    // Confirmation dialog content based on action
    final String action = status == 'confirmed' ? 'accept' : 'reject';
    final Color primaryColor = status == 'confirmed' 
        ? Colors.green.shade700 
        : Colors.red.shade700;

    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirm ${action == 'accept' ? 'Acceptance' : 'Rejection'}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        content: Text(
          action == 'accept'
              ? 'You are about to confirm this meeting. This action will notify all participants.'
              : 'You are about to reject this meeting. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(
              action == 'accept' ? 'CONFIRM ACCEPT' : 'CONFIRM REJECT',
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return; // User canceled

    try {
      await _firestore.collection('meetings').doc(meetingId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Meeting ${status == 'confirmed' ? 'accepted' : 'rejected'} successfully',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          backgroundColor: status == 'confirmed' 
              ? Colors.green.shade700 
              : Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error updating meeting: ${e.toString()}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _rescheduleMeeting(String meetingId, Map<String, dynamic> currentData) async {
    // 1. Show initial confirmation dialog about auto-confirmation
    final bool? proceedWithReschedule = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Reschedule Meeting",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        content: const Text(
          "Rescheduling will automatically confirm this meeting at the new time. "
          "All participants will be notified of the change.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "CANCEL",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text("CONTINUE"),
          ),
        ],
      ),
    );

    if (proceedWithReschedule != true) return;

    // 2. Date selection with validation
    final DateTime now = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      selectableDayPredicate: (DateTime date) {
        // Only allow today or future dates
        return date.isAfter(now.subtract(const Duration(days: 1)));
      },
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.grey.shade800,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue.shade700,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

    // 3. Time selection with validation
    TimeOfDay initialTime = TimeOfDay.now();
    // If selected date is today, set initial time to 15 minutes from now
    if (DateUtils.isSameDay(pickedDate, now)) {
      initialTime = TimeOfDay.fromDateTime(now.add(const Duration(minutes: 15)));
    }

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.grey.shade800,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue.shade700,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null) return;

    // 4. Validate selected time is not in the past
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
      return;
    }

    // 5. Format the new date and time
    final newDate = DateFormat('yyyy-MM-dd').format(pickedDate);
    final startTime = pickedTime.format(context);
    final endTime = TimeOfDay(
      hour: pickedTime.hour + 1,
      minute: pickedTime.minute,
    ).format(context);
    final newTimeSlot = '$startTime-$endTime';

    // 6. Final confirmation dialog
    final bool? confirmReschedule = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Confirm Reschedule",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("New meeting time:"),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(pickedDate),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '$startTime - $endTime',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "This meeting will be automatically confirmed.",
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("BACK"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text("CONFIRM RESCHEDULE"),
          ),
        ],
      ),
    );

    if (confirmReschedule != true) return;

    // 7. Update Firestore
    try {
      await _firestore.collection('meetings').doc(meetingId).update({
        'date': newDate,
        'timeSlot': newTimeSlot,
        'status': 'confirmed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Meeting rescheduled and confirmed successfully',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error rescheduling meeting: ${e.toString()}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        // Search bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search meetings, guests, or purpose...',
              hintStyle: TextStyle(color: Colors.grey.shade500),
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey.shade500),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : IconButton(
                      icon: Icon(
                        _isSearchExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey.shade500,
                      ),
                      onPressed: () {
                        setState(() {
                          _isSearchExpanded = !_isSearchExpanded;
                        });
                      },
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        
        // Filter options
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _isSearchExpanded ? 60 : 0,
          child: _isSearchExpanded
              ? Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All', 'all'),
                        _buildFilterChip('Upcoming', 'upcoming'),
                        _buildFilterChip('Expired', 'expired'),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = selected ? value : 'all';
          });
        },
        backgroundColor: Colors.grey.shade100,
        selectedColor: Colors.blue.shade700,
        checkmarkColor: Colors.white,
      ),
    );
  }

  Widget _buildTimeIndicator(String date, String timeSlot) {
    final timeUntil = _getTimeUntilMeeting(date, timeSlot);
    if (timeUntil == null) return const SizedBox.shrink();

    final isExpired = timeUntil.isNegative;
    
    if (isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Expired',
          style: TextStyle(
            color: Colors.red.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    } else {
      final days = timeUntil.inDays;
      final hours = timeUntil.inHours % 24;
      final minutes = timeUntil.inMinutes % 60;
      
      String timeText;
      Color bgColor;
      Color textColor;
      
      if (days > 0) {
        timeText = days == 1 ? 'Tomorrow' : 'In $days days';
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade700;
      } else if (hours > 0) {
        timeText = hours == 1 ? 'In 1 hour' : 'In $hours hours';
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange.shade700;
      } else {
        timeText = minutes <= 1 ? 'Starting now' : 'In $minutes min';
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade700;
      }
      
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          timeText,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
  }

  Widget _buildMeetingCard(DocumentSnapshot meeting) {
    final data = meeting.data() as Map<String, dynamic>;
    final date = data['date'] as String;
    final timeSlot = data['timeSlot'] as String;
    final isExpired = _isMeetingExpired(date, timeSlot);
    
    // Format time slot for display
    if (timeSlot.isEmpty) {
      return const SizedBox.shrink(); // Skip if time slot is empty
    }
    final formattedTimeSlot = timeSlot.replaceAll('-', ' to ');
    final guestName = data['guestName'] as String;
    final guestEmail = data['guestEmail'] as String;
    final purpose = data['purpose'] as String? ?? 'No purpose specified';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isExpired 
            ? BorderSide(color: Colors.red.shade200, width: 1)
            : BorderSide.none,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isExpired 
              ? LinearGradient(
                  colors: [Colors.red.shade50, Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isExpired ? Colors.red.shade50 : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          guestName[0].toUpperCase(),
                          style: TextStyle(
                            color: isExpired ? Colors.red.shade800 : Colors.blue.shade800,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isExpired)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.schedule,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          guestName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          guestEmail,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildTimeIndicator(date, timeSlot),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  purpose,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 18,
                    color: isExpired ? Colors.red.shade600 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MMMM d, yyyy').format(DateTime.parse(date)),
                    style: TextStyle(
                      color: isExpired ? Colors.red.shade600 : Colors.grey.shade700,
                      fontSize: 14,
                      fontWeight: isExpired ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.access_time_outlined,
                    size: 18,
                    color: isExpired ? Colors.red.shade600 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formattedTimeSlot,
                    style: TextStyle(
                      color: isExpired ? Colors.red.shade600 : Colors.grey.shade700,
                      fontSize: 14,
                      fontWeight: isExpired ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  // Reject Button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _updateMeetingStatus(meeting.id, 'rejected'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade700),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Reject',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Reschedule Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _rescheduleMeeting(meeting.id, data),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Reschedule',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  
                  if (!isExpired) ...[
                    const SizedBox(width: 12),
                    
                    // Accept Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _updateMeetingStatus(meeting.id, 'confirmed'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Accept',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 72,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              _searchQuery.isNotEmpty || _selectedFilter != 'all'
                  ? 'No meetings match your search'
                  : 'No Pending Meeting Requests',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty || _selectedFilter != 'all'
                  ? 'Try adjusting your search or filters'
                  : 'All meeting requests have been processed',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Meeting Requests',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          _buildSearchAndFilters(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _meetingsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading meetings',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Colors.blue,
                    ),
                  );
                }

                final allMeetings = snapshot.data?.docs ?? [];
                final filteredMeetings = _filterMeetings(allMeetings);
                final sortedMeetings = _sortMeetings(filteredMeetings);

                if (sortedMeetings.isEmpty) {
                  return _buildEmptyState();
                }

                // Separate meetings into upcoming and expired
                final upcomingMeetings = <DocumentSnapshot>[];
                final expiredMeetings = <DocumentSnapshot>[];

                for (final meeting in sortedMeetings) {
                  final data = meeting.data() as Map<String, dynamic>;
                  final date = data['date'] as String? ?? '';
                  final timeSlot = data['timeSlot'] as String? ?? '';
                  
                  if (_isMeetingExpired(date, timeSlot)) {
                    expiredMeetings.add(meeting);
                  } else {
                    upcomingMeetings.add(meeting);
                  }
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Show upcoming meetings section
                      if (upcomingMeetings.isNotEmpty) ...[
                        _buildSectionHeader('Upcoming Meetings', upcomingMeetings.length),
                        ...upcomingMeetings.map((meeting) => _buildMeetingCard(meeting)),
                        const SizedBox(height: 20),
                      ],
                      
                      // Show expired meetings section
                      if (expiredMeetings.isNotEmpty) ...[
                        _buildSectionHeader('Expired Meetings', expiredMeetings.length),
                        ...expiredMeetings.map((meeting) => _buildMeetingCard(meeting)),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}