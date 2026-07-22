import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class BookingLookupPage extends StatefulWidget {
  @override
  _BookingLookupPageState createState() => _BookingLookupPageState();
}

class _BookingLookupPageState extends State<BookingLookupPage> {
  // Controllers for form fields
  final TextEditingController _bookingIdController = TextEditingController();
  final TextEditingController _guestNameController = TextEditingController();
  final TextEditingController _guestEmailController = TextEditingController();
  final TextEditingController _meetingPurposeController = TextEditingController();
  
  // State variables
  bool _isLoading = false;
  Map<String, dynamic>? _hostData;
  String? _errorMessage;
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  List<String> _availableSlots = [];
  bool _usingDefaultAvailability = false;

  @override
  void dispose() {
    _bookingIdController.dispose();
    _guestNameController.dispose();
    _guestEmailController.dispose();
    _meetingPurposeController.dispose();
    super.dispose();
  }

  Future<void> _lookupHost() async {
    final bookingId = _bookingIdController.text.trim().toUpperCase();
    
    if (bookingId.isEmpty) {
      setState(() => _errorMessage = 'Please enter a booking ID');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hostData = null;
      _selectedDate = null;
      _selectedTimeSlot = null;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('bookingId', isEqualTo: bookingId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() => _errorMessage = 'Booking ID not found');
      } else {
        final hostDoc = querySnapshot.docs.first;
        setState(() => _hostData = {
          ...hostDoc.data(),
          'uid': hostDoc.id,
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error looking up host: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAvailability(DateTime date) async {
    if (_hostData == null) return;

    setState(() {
      _isLoading = true;
      _availableSlots = [];
      _selectedTimeSlot = null;
    });

    try {
      final dateKey = _formatDate(date);
      
      // Get host's availability
      final availabilityDoc = await FirebaseFirestore.instance
          .collection('availability')
          .doc(_hostData!['uid'])
          .get();

      // Get existing bookings for this date (only pending or confirmed)
      final bookingsQuery = await FirebaseFirestore.instance
          .collection('meetings')
          .where('hostId', isEqualTo: _hostData!['uid'])
          .where('date', isEqualTo: dateKey)
          .where('status', whereIn: ['pending', 'confirmed'])
          .get();

      final bookedSlots = bookingsQuery.docs
          .map((doc) => doc['timeSlot'] as String)
          .toList();

      List<String> availableSlots = [];
      
      if (availabilityDoc.exists) {
        final data = availabilityDoc.data()!;
        final slots = data['slots'] as Map<String, dynamic>? ?? {};
        
        if (slots.containsKey(dateKey)) {
          final daySlots = List<String>.from(slots[dateKey]);
          availableSlots = daySlots.where((slot) => 
              slot != 'BLOCKED' && !bookedSlots.contains(slot)).toList();
          setState(() => _usingDefaultAvailability = false);
        } else {
          // Use default availability (8:00-16:00) if no specific slots for this date
          availableSlots = _generate2HourSlots('08:00', '16:00')
              .where((slot) => !bookedSlots.contains(slot))
              .toList();
          setState(() => _usingDefaultAvailability = true);
        }
      } else {
        // Use default availability if no availability document exists
        availableSlots = _generate2HourSlots('08:00', '16:00')
            .where((slot) => !bookedSlots.contains(slot))
            .toList();
        setState(() => _usingDefaultAvailability = true);
      }

      // Filter out past time slots if date is today
      if (_isToday(date)) {
        availableSlots = _filterFutureSlots(availableSlots);
      }
      
      setState(() => _availableSlots = availableSlots);

    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading availability: ${e.toString()}';
        _availableSlots = [];
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<String> _generate2HourSlots(String startTime, String endTime) {
    final slots = <String>[];
    final start = TimeOfDay(
      hour: int.parse(startTime.split(':')[0]),
      minute: int.parse(startTime.split(':')[1]),
    );
    final end = TimeOfDay(
      hour: int.parse(endTime.split(':')[0]),
      minute: int.parse(endTime.split(':')[1]),
    );

    var currentHour = start.hour;
    var currentMinute = start.minute;

    while (currentHour < end.hour || 
          (currentHour == end.hour && currentMinute <= end.minute - 120)) {
      final endHour = currentHour + 2;
      final endMinute = currentMinute;
      
      if (endHour > end.hour || 
          (endHour == end.hour && endMinute > end.minute)) {
        break;
      }

      final slotStart = '${currentHour.toString().padLeft(2, '0')}:'
                        '${currentMinute.toString().padLeft(2, '0')}';
      final slotEnd = '${endHour.toString().padLeft(2, '0')}:'
                      '${endMinute.toString().padLeft(2, '0')}';
      
      slots.add('$slotStart-$slotEnd');
      currentHour = endHour;
    }

    return slots;
  }

  List<String> _filterFutureSlots(List<String> slots) {
    final now = DateTime.now();
    return slots.where((slot) {
      final slotStartTime = slot.split('-')[0];
      final slotHour = int.parse(slotStartTime.split(':')[0]);
      final slotMinute = int.parse(slotStartTime.split(':')[1]);
      
      final slotDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        slotHour,
        slotMinute,
      );
      
      // Allow booking only if slot starts at least 30 minutes from now
      return slotDateTime.isAfter(now.add(const Duration(minutes: 30)));
    }).toList();
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && 
           date.month == now.month && 
           date.day == now.day;
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _formatTimeSlot(String slot) {
    final parts = slot.split('-');
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
      await _loadAvailability(picked);
    }
  }

  Future<void> _bookMeeting() async {
    if (_guestNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    if (_guestEmailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email')),
      );
      return;
    }

    if (_selectedDate == null || _selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and time slot')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dateKey = _formatDate(_selectedDate!);
      
      // Check if the slot is already booked
      final conflictingBookings = await FirebaseFirestore.instance
          .collection('meetings')
          .where('hostId', isEqualTo: _hostData!['uid'])
          .where('date', isEqualTo: dateKey)
          .where('timeSlot', isEqualTo: _selectedTimeSlot)
          .where('status', whereIn: ['pending', 'confirmed'])
          .limit(1)
          .get();

      if (conflictingBookings.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This time slot is already booked. Please choose another.'),
            backgroundColor: Colors.red,
          ),
        );
        await _loadAvailability(_selectedDate!);
        return;
      }

      // Create the meeting document
      await FirebaseFirestore.instance.collection('meetings').add({
        'hostId': _hostData!['uid'],
        'hostName': _hostData!['displayName'],
        'hostEmail': _hostData!['email'],
        'guestName': _guestNameController.text.trim(),
        'guestEmail': _guestEmailController.text.trim(),
        'purpose': _meetingPurposeController.text.trim(),
        'date': dateKey,
        'timeSlot': _selectedTimeSlot,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meeting request sent successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Reset form but keep host data
      setState(() {
        _guestNameController.clear();
        _guestEmailController.clear();
        _meetingPurposeController.clear();
        _selectedDate = null;
        _selectedTimeSlot = null;
        _availableSlots = [];
      });
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to book meeting: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    setState(() {
      _bookingIdController.clear();
      _guestNameController.clear();
      _guestEmailController.clear();
      _meetingPurposeController.clear();
      _hostData = null;
      _selectedDate = null;
      _selectedTimeSlot = null;
      _availableSlots = [];
      _errorMessage = null;
    });
  }

  void _navigateToMyBookings() {
    Navigator.pushNamed(context, '/my-bookings');
  }

  Widget _buildTimeSlotChips() {
    if (_availableSlots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          _usingDefaultAvailability 
              ? 'No available slots remaining for this date'
              : 'Host has not set availability for this date',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _availableSlots.map((slot) {
        final isSelected = _selectedTimeSlot == slot;
        final formattedSlot = _formatTimeSlot(slot);
        
        return FilterChip(
          label: Text(formattedSlot),
          selected: isSelected,
          onSelected: (selected) {
            setState(() => _selectedTimeSlot = selected ? slot : null);
          },
          selectedColor: Colors.blue[100],
          checkmarkColor: Colors.blue,
          labelStyle: TextStyle(
            color: isSelected ? Colors.blue : Colors.black,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected ? Colors.blue : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule a Meeting'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Booking ID Lookup Section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Find Host',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _bookingIdController,
                      decoration: InputDecoration(
                        labelText: 'Host Booking ID',
                        hintText: 'Enter 8-character booking ID',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 8,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _lookupHost,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Find Host'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // NEW: My Bookings Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _navigateToMyBookings,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: BorderSide(color: Colors.orange),
                        ),
                        icon: Icon(Icons.history, color: Colors.orange),
                        label: Text(
                          'View My Bookings',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Host Profile Section
            if (_hostData != null) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Host Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 30,
                          backgroundImage: _hostData!['profileImage'] != null
                              ? NetworkImage(_hostData!['profileImage'])
                              : null,
                          child: _hostData!['profileImage'] == null
                              ? const Icon(Icons.person, size: 30)
                              : null,
                        ),
                        title: Text(
                          _hostData!['displayName'] ?? 'No name provided',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: _hostData!['company'] != null
                            ? Text(_hostData!['company'])
                            : null,
                      ),
                    ],
                  ),
                ),
              ),

              // Booking Form Section
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meeting Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Guest Name
                      TextField(
                        controller: _guestNameController,
                        decoration: const InputDecoration(
                          labelText: 'Your Name *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Guest Email
                      TextField(
                        controller: _guestEmailController,
                        decoration: const InputDecoration(
                          labelText: 'Your Email *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      
                      // Meeting Purpose
                      TextField(
                        controller: _meetingPurposeController,
                        decoration: const InputDecoration(
                          labelText: 'Meeting Purpose',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      
                      // Date Selection
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedDate == null
                                  ? 'Select a date *'
                                  : 'Selected: ${DateFormat('EEE, MMM d, y').format(_selectedDate!)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _selectDate,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            child: const Text('Select Date'),
                          ),
                        ],
                      ),
                      
                      // Time Slot Selection
                      if (_selectedDate != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Available Time Slots (2-hour blocks) *',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator())
                        else
                          _buildTimeSlotChips(),
                        if (_usingDefaultAvailability && _availableSlots.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Using host\'s default availability (8:00 AM - 4:00 PM)',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        if (_selectedDate != null && _isToday(_selectedDate!))
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Only future time slots are available for today',
                              style: TextStyle(
                                color: Colors.orange[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Book Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _bookMeeting,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Request Meeting',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Reset Button
            if (_hostData != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _resetForm,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Start Over'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}