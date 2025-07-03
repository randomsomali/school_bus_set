import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/auth_provider.dart';
import 'package:app/services/attendance_service.dart';
import 'package:app/services/student_service.dart';
import 'package:intl/intl.dart';

class AttendanceTab extends StatefulWidget {
  const AttendanceTab({Key? key}) : super(key: key);

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  final AttendanceService _attendanceService = AttendanceService();
  final StudentService _studentService = StudentService();

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _isLoading = true;
  String? _error;

  // Filter states
  String _selectedFilter = 'today'; // 'today', 'custom'
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedStudentId;
  String? _selectedType; // 'enter', 'leave', null for all

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _loadAttendance();
  }

  Future<void> _loadStudents() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userData = authProvider.userData;

      Map<String, dynamic> response;
      if (authProvider.isAdmin) {
        response = await _studentService.getAllStudents();
      } else {
        response = await _studentService.getStudentsByParent(userData!['_id']);
      }

      if (mounted) {
        if (response['success']) {
          setState(() {
            _students = List<Map<String, dynamic>>.from(response['data']);
          });
        }
      }
    } catch (e) {
      // Silently fail for students loading
    }
  }

  Future<void> _loadAttendance() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      Map<String, dynamic> response;

      if (_selectedFilter == 'today') {
        response = await _attendanceService.getTodayAttendance();
      } else {
        // Use the general attendance endpoint with date range
        response = await _attendanceService.getAllAttendance(
          startDate: _startDate,
          endDate: _endDate,
          studentId: _selectedStudentId,
          type: _selectedType,
        );
      }

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
        _selectedFilter = 'custom';
      });
      _loadAttendance();
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedFilter = 'today';
      _startDate = null;
      _endDate = null;
      _selectedStudentId = null;
      _selectedType = null;
    });
    _loadAttendance();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attendance Records',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Filter Options
                Row(
                  children: [
                    // Today/Custom Filter
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'today', label: Text('Today')),
                          ButtonSegment(value: 'custom', label: Text('Custom')),
                        ],
                        selected: {_selectedFilter},
                        onSelectionChanged: (Set<String> selection) {
                          setState(() {
                            _selectedFilter = selection.first;
                            if (_selectedFilter == 'today') {
                              _startDate = null;
                              _endDate = null;
                            }
                          });
                          _loadAttendance();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Date Range Picker
                    if (_selectedFilter == 'custom')
                      ElevatedButton.icon(
                        onPressed: _showDateRangePicker,
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _startDate != null && _endDate != null
                              ? '${DateFormat('MMM dd').format(_startDate!)} - ${DateFormat('MMM dd').format(_endDate!)}'
                              : 'Select Date Range',
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Additional Filters
                Row(
                  children: [
                    // Student Filter (for admin)
                    if (authProvider.isAdmin && _students.isNotEmpty)
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Student',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          value: _selectedStudentId,
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('All Students'),
                            ),
                            ..._students
                                .map((student) => DropdownMenuItem<String>(
                                      value: student['_id'],
                                      child: Text(student['name']),
                                    )),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedStudentId = value;
                            });
                            _loadAttendance();
                          },
                        ),
                      ),

                    if (authProvider.isAdmin && _students.isNotEmpty)
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
              ],
            ),
          ),

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
                    : _attendanceRecords.isEmpty
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
                              padding: const EdgeInsets.all(16),
                              itemCount: _attendanceRecords.length,
                              itemBuilder: (context, index) {
                                final record = _attendanceRecords[index];
                                final student =
                                    record['student'] as Map<String, dynamic>?;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: record['type'] == 'enter'
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
                                      student?['name'] ?? 'Unknown Student',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Type: ${record['type']?.toString().toUpperCase() ?? 'Unknown'}',
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        if (record['date'] != null)
                                          Text(
                                            'Date: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(record['date']))}',
                                            style: GoogleFonts.poppins(
                                              color: Colors.grey[500],
                                              fontSize: 12,
                                            ),
                                          ),
                                        if (record['time'] != null)
                                          Text(
                                            'Time: ${record['time']}',
                                            style: GoogleFonts.poppins(
                                              color: Colors.grey[500],
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: authProvider.isAdmin
                                        ? Text(
                                            'ID: ${student?['fingerprintId'] ?? 'N/A'}',
                                            style: GoogleFonts.poppins(
                                              color: Colors.grey[500],
                                              fontSize: 12,
                                            ),
                                          )
                                        : null,
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
