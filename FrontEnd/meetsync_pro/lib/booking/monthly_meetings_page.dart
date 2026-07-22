import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class MonthlyMeetingsPage extends StatefulWidget {
  const MonthlyMeetingsPage({Key? key}) : super(key: key);

  @override
  _MonthlyMeetingsPageState createState() => _MonthlyMeetingsPageState();
}

class _MonthlyMeetingsPageState extends State<MonthlyMeetingsPage> with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  DateTime _selectedMonth = DateTime.now();
  String _selectedStatusFilter = 'all';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animationController.forward();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  DateTime get _firstDayOfMonth => DateTime(_selectedMonth.year, _selectedMonth.month, 1);
  DateTime get _lastDayOfMonth => DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

  Stream<QuerySnapshot> get _meetingsStream {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    try {
      final firstDay = Timestamp.fromDate(_firstDayOfMonth);
      final lastDay = Timestamp.fromDate(_lastDayOfMonth.add(const Duration(days: 1)));

      return _firestore
          .collection('meetings')
          .where('hostId', isEqualTo: user.uid)
          .where('createdAt', isGreaterThanOrEqualTo: firstDay)
          .where('createdAt', isLessThan: lastDay)
          .orderBy('createdAt', descending: false)
          .snapshots();
    } catch (e) {
      print('Error creating meetings stream: $e');
      return const Stream.empty();
    }
  }

  List<DocumentSnapshot> _filterMeetings(List<DocumentSnapshot> meetings) {
    return meetings.where((meeting) {
      try {
        final data = meeting.data() as Map<String, dynamic>?;
        if (data == null) return false;
        
        if (_selectedStatusFilter != 'all') {
          final status = data['status'] as String? ?? 'pending';
          if (status != _selectedStatusFilter) return false;
        }

        if (_searchQuery.isNotEmpty) {
          final guestName = (data['guestName'] as String? ?? '').toLowerCase();
          final guestEmail = (data['guestEmail'] as String? ?? '').toLowerCase();
          final purpose = (data['purpose'] as String? ?? '').toLowerCase();
          
          return guestName.contains(_searchQuery) ||
                 guestEmail.contains(_searchQuery) ||
                 purpose.contains(_searchQuery);
        }

        return true;
      } catch (e) {
        print('Error filtering meeting: $e');
        return false;
      }
    }).toList();
  }

  List<DocumentSnapshot> _sortMeetings(List<DocumentSnapshot> meetings) {
    try {
      meetings.sort((a, b) {
        final dataA = a.data() as Map<String, dynamic>?;
        final dataB = b.data() as Map<String, dynamic>?;
        
        if (dataA == null || dataB == null) return 0;
        
        final dateA = _parseDate(dataA['date'] as String?);
        final dateB = _parseDate(dataB['date'] as String?);
        
        return dateA.compareTo(dateB);
      });
    } catch (e) {
      print('Error sorting meetings: $e');
    }
    
    return meetings;
  }

  DateTime _parseDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return DateTime.now();
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      return DateTime.now();
    }
  }

  Future<void> _contactGuest(String email, String name) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Regarding Our Meeting&body=Hello $name,\n\n',
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        _showContactDialog(email, name);
      }
    } catch (e) {
      _showContactDialog(email, name);
    }
  }

  void _showContactDialog(String email, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Contact $name', style: const TextStyle(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Email:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, const Color.fromARGB(255, 33, 150, 243)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      email,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy, color: Colors.blue.shade700),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Email copied to clipboard'),
                          backgroundColor: Colors.green.shade600,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: Colors.blue.shade700)),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'confirmed':
        return {
          'color': Colors.green.shade700,
          'bgColor': Colors.green.shade50,
          'icon': Icons.check_circle,
          'label': 'Confirmed'
        };
      case 'rejected':
        return {
          'color': Colors.red.shade700,
          'bgColor': Colors.red.shade50,
          'icon': Icons.cancel,
          'label': 'Rejected'
        };
      case 'pending':
        return {
          'color': Colors.orange.shade700,
          'bgColor': Colors.orange.shade50,
          'icon': Icons.schedule,
          'label': 'Pending'
        };
      default:
        return {
          'color': Colors.grey.shade700,
          'bgColor': Colors.grey.shade50,
          'icon': Icons.help_outline,
          'label': 'Unknown'
        };
    }
  }

  Widget _buildMonthNavigator() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade300.withOpacity(0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
              });
            },
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              foregroundColor: Colors.white,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('MMM d').format(_firstDayOfMonth)} - ${DateFormat('MMM d, yyyy').format(_lastDayOfMonth)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
              });
            },
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search meetings...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search, color: Colors.blue.shade700),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey.shade500),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusFilter('All', 'all'),
                const SizedBox(width: 8),
                _buildStatusFilter('Confirmed', 'confirmed'),
                const SizedBox(width: 8),
                _buildStatusFilter('Pending', 'pending'),
                const SizedBox(width: 8),
                _buildStatusFilter('Rejected', 'rejected'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter(String label, String value) {
    final isSelected = _selectedStatusFilter == value;
    final config = _getStatusConfig(value);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected 
            ? (value == 'all' ? Colors.blue.shade700 : config['color'])
            : (value == 'all' ? Colors.grey.shade100 : config['bgColor']),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected 
              ? (value == 'all' ? Colors.blue.shade700 : config['color'])
              : Colors.transparent,
        ),
      ),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedStatusFilter = isSelected ? 'all' : value;
          });
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != 'all') ...[
              Icon(
                config['icon'],
                size: 16,
                color: isSelected ? Colors.white : config['color'],
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : (value == 'all' ? Colors.grey.shade700 : config['color']),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingCard(DocumentSnapshot meeting, int index) {
    try {
      final data = meeting.data() as Map<String, dynamic>?;
      if (data == null) return const SizedBox.shrink();
      
      final date = data['date'] as String? ?? '';
      final timeSlot = data['timeSlot'] as String? ?? '';
      final guestName = data['guestName'] as String? ?? '';
      final guestEmail = data['guestEmail'] as String? ?? '';
      final purpose = data['purpose'] as String? ?? 'No purpose specified';
      final status = data['status'] as String? ?? 'pending';
      
      final statusConfig = _getStatusConfig(status);
      final meetingDate = _parseDate(date);
      final formattedTimeSlot = timeSlot.replaceAll('-', ' to ');
      
      return AnimatedContainer(
        duration: Duration(milliseconds: 300 + (index * 100)),
        margin: const EdgeInsets.only(bottom: 16),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(20),
          shadowColor: statusConfig['color'].withOpacity(0.3),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [statusConfig['bgColor'], Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: statusConfig['color'].withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Hero(
                        tag: 'avatar_${meeting.id}',
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [statusConfig['color'], statusConfig['color'].withOpacity(0.8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: statusConfig['color'].withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            guestName.isNotEmpty ? guestName[0].toUpperCase() : 'G',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              guestName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              guestEmail,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusConfig['color'],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              statusConfig['icon'],
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusConfig['label'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      purpose,
                      style: const TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_month_outlined,
                                size: 18,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('MMM d, yyyy').format(meetingDate),
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (timeSlot.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time_outlined,
                                  size: 18,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    formattedTimeSlot,
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _contactGuest(guestEmail, guestName),
                      icon: const Icon(Icons.email_outlined),
                      label: const Text('Contact Guest'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      print('Error building meeting card: $e');
      return const SizedBox.shrink();
    }
  }

  Widget _buildStatsCard(List<DocumentSnapshot> meetings) {
    try {
      final confirmedCount = meetings.where((m) {
        final data = m.data() as Map<String, dynamic>?;
        return data?['status'] == 'confirmed';
      }).length;
      
      final pendingCount = meetings.where((m) {
        final data = m.data() as Map<String, dynamic>?;
        return (data?['status'] ?? 'pending') == 'pending';
      }).length;
      
      final rejectedCount = meetings.where((m) {
        final data = m.data() as Map<String, dynamic>?;
        return data?['status'] == 'rejected';
      }).length;
      
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Confirmed',
                    confirmedCount.toString(),
                    Colors.green.shade700,
                    Colors.green.shade50,
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    'Pending',
                    pendingCount.toString(),
                    Colors.orange.shade700,
                    Colors.orange.shade50,
                    Icons.schedule,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    'Rejected',
                    rejectedCount.toString(),
                    Colors.red.shade700,
                    Colors.red.shade50,
                    Icons.cancel,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error building stats card: $e');
      return const SizedBox.shrink();
    }
  }

  Widget _buildStatItem(String label, String value, Color color, Color bgColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bgColor, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.calendar_month_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _searchQuery.isNotEmpty || _selectedStatusFilter != 'all'
                  ? 'No meetings match your criteria'
                  : 'No meetings this month',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty || _selectedStatusFilter != 'all'
                  ? 'Try adjusting your search or filters'
                  : 'No meetings scheduled for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
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
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            floating: true,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.grey.shade800,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: const Text(
                'Monthly Meetings',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white, Colors.grey.shade50],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildMonthNavigator(),
                _buildSearchAndFilters(),
              ],
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: _meetingsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading meetings',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                        color: Colors.blue,
                      ),
                    ),
                  ),
                );
              }

              final allMeetings = snapshot.data?.docs ?? [];
              final filteredMeetings = _filterMeetings(allMeetings);
              final sortedMeetings = _sortMeetings(filteredMeetings);

              return SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildStatsCard(allMeetings),
                    if (sortedMeetings.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: sortedMeetings.length,
                        itemBuilder: (context, index) {
                          return _buildMeetingCard(sortedMeetings[index], index);
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}