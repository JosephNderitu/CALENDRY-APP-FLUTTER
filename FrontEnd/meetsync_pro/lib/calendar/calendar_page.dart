import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final user = FirebaseAuth.instance.currentUser;
  Map<String, List<String>> availability = {};
  DateTime selectedDate = DateTime.now();
  bool loading = true;

  List<String> _getDefaultSlots() {
    return ['08:00-16:00']; // Default from 8 AM to 4 PM
  }

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('availability')
        .doc(user!.uid)
        .get();

    setState(() {
      if (doc.exists) {
        final data = doc.data()!;
        final slots = Map<String, dynamic>.from(data['slots'] ?? {});
        availability = slots.map((key, value) => MapEntry(key, List<String>.from(value)));
      } else {
        availability = {};
      }
      loading = false;
    });
  }

  Future<void> _updateSlot(String dateKey, List<String> slots) async {
    setState(() {
      if (slots.isNotEmpty && slots != _getDefaultSlots()) {
        availability[dateKey] = slots;
      } else {
        availability.remove(dateKey);
      }
    });
    
    await FirebaseFirestore.instance
        .collection('availability')
        .doc(user!.uid)
        .set({
      'slots': availability,
    }, SetOptions(merge: true));
  }

  void _pickTimeRange() async {
    final startTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.indigo,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteTextColor: Colors.indigo,
              dayPeriodTextColor: Colors.indigo,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (startTime == null) return;

    final endTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: startTime.hour + 1, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color.fromARGB(255, 152, 163, 227),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteTextColor: const Color.fromARGB(255, 131, 145, 222),
              dayPeriodTextColor: const Color.fromARGB(255, 97, 109, 181),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (endTime == null) return;

    final timeRange = '${_formatTime(startTime)}-${_formatTime(endTime)}';
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);

    final currentSlots = availability[dateKey] ?? _getDefaultSlots();
    if (currentSlots.contains(timeRange)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This time slot already exists')),
      );
      return;
    }
    final updatedSlots = List<String>.from(currentSlots);
    updatedSlots.add(timeRange);
    await _updateSlot(dateKey, updatedSlots);
  }

  void _deleteSlot(String dateKey, int index) async {
    final currentSlots = availability[dateKey] ?? _getDefaultSlots();
    final updatedSlots = List<String>.from(currentSlots);
    updatedSlots.removeAt(index);
    await _updateSlot(dateKey, updatedSlots);
  }

  void _blockDate() async {
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    await _updateSlot(dateKey, ['BLOCKED']);
  }

  void _clearDate() async {
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    setState(() {
      availability.remove(dateKey);
    });
    await FirebaseFirestore.instance
        .collection('availability')
        .doc(user!.uid)
        .update({
      'slots.$dateKey': FieldValue.delete(),
    });
  }

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('HH:mm').format(dt);
  }

  Widget _buildSlotItem(String slot, String dateKey, int index) {
    final isBlocked = slot == 'BLOCKED';
    final isDefault = !isBlocked && (availability[dateKey] == null || availability[dateKey]!.isEmpty);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isBlocked ? Colors.red[50] : (isDefault ? Colors.blue[50] : Colors.teal[50]),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          isBlocked ? Icons.block : Icons.access_time,
          color: isBlocked ? Colors.red[700] : (isDefault ? Colors.blue[700] : Colors.teal[700]),
        ),
        title: Text(
          isBlocked ? 'Date Blocked' : (isDefault ? '$slot (Default)' : slot),
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isBlocked ? Colors.red[800] : (isDefault ? Colors.blue[800] : Colors.teal[800]),
          ),
        ),
        trailing: isDefault 
            ? const Icon(Icons.lock, color: Colors.grey)
            : IconButton(
                icon: const Icon(Icons.delete, color: Colors.grey),
                onPressed: () => _deleteSlot(dateKey, index),
              ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    final slots = availability[dateKey] ?? _getDefaultSlots();
    final formattedDate = DateFormat('EEEE, MMMM d, y').format(selectedDate);
    final now = DateTime.now();
    final currentDate = DateTime(now.year, now.month, now.day);

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'MY AVAILABILITY',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: 1.2,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo, Colors.blue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: loading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
                ),
              )
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Calendar Section
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text(
                                'SELECT DATE',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo[800],
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: Theme.of(context).colorScheme.copyWith(
                                        primary: Colors.indigo,
                                        onPrimary: Colors.white,
                                      ),
                                ),
                                child: CalendarDatePicker(
                                  initialDate: selectedDate,
                                  firstDate: currentDate,
                                  lastDate: DateTime(currentDate.year + 1),
                                  onDateChanged: (date) {
                                    setState(() => selectedDate = date);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Selected Date Info
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Text(
                          formattedDate.toUpperCase(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo[800],
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Slots Section
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'AVAILABILITY SLOTS',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo[800],
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (availability[dateKey] == null || availability[dateKey]!.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Text(
                                    'Using default availability (8:00 AM - 4:00 PM)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ...List.generate(
                                slots.length,
                                (index) => _buildSlotItem(slots[index], dateKey, index),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  _buildActionButton(
                                    icon: Icons.add,
                                    label: 'Add Slot',
                                    color: Colors.teal,
                                    onPressed: _pickTimeRange,
                                  ),
                                  _buildActionButton(
                                    icon: Icons.block,
                                    label: 'Block Date',
                                    color: Colors.red,
                                    onPressed: _blockDate,
                                  ),
                                  _buildActionButton(
                                    icon: Icons.clear,
                                    label: 'Clear',
                                    color: Colors.orange,
                                    onPressed: _clearDate,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}