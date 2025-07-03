import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/services/attendance_service.dart';
import 'package:intl/intl.dart';

class StudentAttendanceScreen extends StatefulWidget {
  final Map<String, dynamic> student;

  const StudentAttendanceScreen({
    Key? key,
    required this.student,
  }) : super(key: key);

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  final AttendanceService _attendanceService = AttendanceService();

  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _isLoading = true;
  String? _error;

  // Filter states
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedType; // 'enter', 'leave', null for all

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await _attendanceService.getAttendanceByStudent(
        studentId: widget.student['_id'] ?? '',
        startDate: _startDate,
        endDate: _endDate,
        type: _selectedType,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (response['success']) {
            _attendanceRecords =
                List<Map<String, dynamic>>.from(response['data']);
            _error = null;
          } else {
            _error = response['message'];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load attendance: $e';
        });
      }
    }
  }

  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadAttendance();
    }
  }

  void _resetFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedType = null;
    });
    _loadAttendance();
  }

  // Group attendance records by date
  Map<String, List<Map<String, dynamic>>> _groupAttendanceByDate() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final record in _attendanceRecords) {
      final date = record['date'] as String?;
      if (date != null) {
        final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.parse(date));
        if (!grouped.containsKey(dateKey)) {
          grouped[dateKey] = [];
        }
        grouped[dateKey]!.add(record);
      }
    }

    // Sort dates in descending order
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    final Map<String, List<Map<String, dynamic>>> sortedGrouped = {};
    for (final key in sortedKeys) {
      sortedGrouped[key] = grouped[key]!;
    }

    return sortedGrouped;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final studentName = widget.student['name'] ?? 'Unknown Student';
    final fingerprintId = widget.student['fingerprintId'] ?? 'N/A';
    final groupedAttendance = _groupAttendanceByDate();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '$studentName - Attendance',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Student Info Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary,
                  radius: 30,
                  child: Text(
                    studentName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fingerprint ID: $fingerprintId',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Filter Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Date Range Picker
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showDateRangePicker,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _startDate != null && _endDate != null
                          ? '${DateFormat('MMM dd').format(_startDate!)} - ${DateFormat('MMM dd').format(_endDate!)}'
                          : 'Select Date Range',
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Type Filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: _selectedType,
                    items: const [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text('All'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'enter',
                        child: Text('Enter'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'leave',
                        child: Text('Leave'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value;
                      });
                      _loadAttendance();
                    },
                  ),
                ),

                const SizedBox(width: 12),

                // Reset Button
                IconButton(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reset Filters',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Attendance Records
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: GoogleFonts.poppins(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadAttendance,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : groupedAttendance.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.assignment,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No attendance records found',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadAttendance,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: groupedAttendance.length,
                              itemBuilder: (context, index) {
                                final dateKey =
                                    groupedAttendance.keys.elementAt(index);
                                final records = groupedAttendance[dateKey]!;
                                final date = DateTime.parse(dateKey);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Date Header
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary
                                              .withOpacity(0.1),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(12),
                                            topRight: Radius.circular(12),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today,
                                              color: theme.colorScheme.primary,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              DateFormat('EEEE, MMMM dd, yyyy')
                                                  .format(date),
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Attendance Records for this date
                                      ...records.map((record) {
                                        return ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor:
                                                record['type'] == 'enter'
                                                    ? Colors.green
                                                    : Colors.red,
                                            child: Icon(
                                              record['type'] == 'enter'
                                                  ? Icons.login
                                                  : Icons.logout,
                                              color: Colors.white,
                                            ),
                                          ),
                                          title: Text(
                                            record['type']
                                                    ?.toString()
                                                    .toUpperCase() ??
                                                'Unknown',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          subtitle: Text(
                                            'Time: ${record['time'] ?? 'N/A'}',
                                            style: GoogleFonts.poppins(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          trailing: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: record['type'] == 'enter'
                                                  ? Colors.green
                                                      .withOpacity(0.1)
                                                  : Colors.red.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              record['type'] == 'enter'
                                                  ? 'IN'
                                                  : 'OUT',
                                              style: GoogleFonts.poppins(
                                                color: record['type'] == 'enter'
                                                    ? Colors.green
                                                    : Colors.red,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
