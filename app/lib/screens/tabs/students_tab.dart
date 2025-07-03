import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/auth_provider.dart';
import 'package:app/services/student_service.dart';
import 'package:app/services/user_service.dart';
import 'package:app/screens/student_attendance_screen.dart';
import 'package:flutter/services.dart';

class StudentsTab extends StatefulWidget {
  const StudentsTab({Key? key}) : super(key: key);

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  final StudentService _studentService = StudentService();
  final UserService _userService = UserService();
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _parents = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _loadParents();
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
        setState(() {
          _isLoading = false;
          if (response['success']) {
            _students = List<Map<String, dynamic>>.from(response['data']);
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
          _error = 'Failed to load students: $e';
        });
      }
    }
  }

  Future<void> _loadParents() async {
    try {
      final response = await _userService.getAllUsers();
      if (response['success']) {
        final allUsers = List<Map<String, dynamic>>.from(response['data']);
        _parents = allUsers.where((user) => user['role'] == 'parent').toList();
      }
    } catch (e) {
      // Silently fail for parents loading
    }
  }

  Future<void> _showAddStudentDialog() async {
    if (_parents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('No parents available. Please create a parent user first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    String name = '';
    String selectedParentId = _parents.first['_id'];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Student', style: GoogleFonts.poppins()),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Student Name',
                  border: OutlineInputBorder(),
                  hintText: 'Enter full name',
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                ],
                maxLength: 255,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Student name is required';
                  }
                  if (value.trim().length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  if (value.trim().length > 255) {
                    return 'Name cannot exceed 255 characters';
                  }

                  // Check if name contains only letters and spaces
                  if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
                    return 'Name can only contain letters and spaces';
                  }

                  // Check if student name already exists
                  final existingStudent = _students
                      .where((student) =>
                          student['name']?.toString().toLowerCase() ==
                              value.trim().toLowerCase() &&
                          student['_id'] != null)
                      .toList();
                  if (existingStudent.isNotEmpty) {
                    return 'Student with this name already exists';
                  }

                  return null;
                },
                onSaved: (value) => name = value!.trim(),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Parent',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.family_restroom),
                ),
                value: selectedParentId,
                items: _parents.map((parent) {
                  return DropdownMenuItem<String>(
                    value: parent['_id'],
                    child: Text(parent['phone']),
                  );
                }).toList(),
                onChanged: (value) => selectedParentId = value!,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a parent';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                Navigator.of(context).pop();
                await _createStudent(name, selectedParentId);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _createStudent(String name, String parentId) async {
    try {
      final response = await _studentService.createStudent(
        name: name,
        parentId: parentId,
      );

      if (mounted) {
        if (response['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Student created successfully')),
          );
          _loadStudents();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message']),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating student: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEditStudentDialog(Map<String, dynamic> student) async {
    if (_parents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('No parents available. Please create a parent user first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    String name = student['name'] ?? '';
    String selectedParentId =
        student['parent']?['_id'] ?? _parents.first['_id'];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Student', style: GoogleFonts.poppins()),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Student Name',
                  border: OutlineInputBorder(),
                  hintText: 'Enter full name',
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                ],
                maxLength: 255,
                initialValue: name,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Student name is required';
                  }
                  if (value.trim().length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  if (value.trim().length > 255) {
                    return 'Name cannot exceed 255 characters';
                  }

                  // Check if name contains only letters and spaces
                  if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
                    return 'Name can only contain letters and spaces';
                  }

                  // Check if student name already exists (excluding current student)
                  final existingStudent = _students
                      .where((s) =>
                          s['name']?.toString().toLowerCase() ==
                              value.trim().toLowerCase() &&
                          s['_id'] != student['_id'])
                      .toList();
                  if (existingStudent.isNotEmpty) {
                    return 'Student with this name already exists';
                  }

                  return null;
                },
                onSaved: (value) => name = value!.trim(),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Parent',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.family_restroom),
                ),
                value: selectedParentId,
                items: _parents.map((parent) {
                  return DropdownMenuItem<String>(
                    value: parent['_id'],
                    child: Text(parent['phone']),
                  );
                }).toList(),
                onChanged: (value) => selectedParentId = value!,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a parent';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                Navigator.of(context).pop();
                await _updateStudent(student['_id'], name, selectedParentId);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStudent(
      String studentId, String name, String parentId) async {
    try {
      final response = await _studentService.updateStudent(
        studentId: studentId,
        name: name,
        parentId: parentId,
      );

      if (mounted) {
        if (response['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Student updated successfully')),
          );
          _loadStudents();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message']),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating student: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteStudent(String studentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Student', style: GoogleFonts.poppins()),
        content: const Text(
            'Are you sure you want to delete this student? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final response = await _studentService.deleteStudent(studentId);

        if (mounted) {
          if (response['success']) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Student deleted successfully')),
            );
            _loadStudents();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response['message']),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting student: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: GoogleFonts.poppins(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadStudents,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Students',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (authProvider.isAdmin)
                            ElevatedButton.icon(
                              onPressed: _showAddStudentDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Student'),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _students.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.school,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No students found',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadStudents,
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                itemCount: _students.length,
                                itemBuilder: (context, index) {
                                  final student = _students[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      onTap: () {
                                        // Navigate to student attendance page
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                StudentAttendanceScreen(
                                              student: student,
                                            ),
                                          ),
                                        );
                                      },
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            theme.colorScheme.primary,
                                        child: Text(
                                          student['name']?[0]
                                                  ?.toString()
                                                  .toUpperCase() ??
                                              '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        student['name'] ?? 'Unknown Student',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Fingerprint ID: ${student['fingerprintId'] ?? 'N/A'}',
                                            style: GoogleFonts.poppins(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          if (authProvider.isAdmin &&
                                              student['parent'] != null)
                                            Text(
                                              'Parent: ${student['parent']?['phone'] ?? 'Unknown'}',
                                              style: GoogleFonts.poppins(
                                                color: Colors.grey[500],
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // View Attendance Button
                                          IconButton(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      StudentAttendanceScreen(
                                                    student: student,
                                                  ),
                                                ),
                                              );
                                            },
                                            icon: Icon(
                                              Icons.assignment,
                                              color: theme.colorScheme.primary,
                                            ),
                                            tooltip: 'View Attendance',
                                          ),
                                          // Admin actions
                                          if (authProvider.isAdmin)
                                            PopupMenuButton(
                                              itemBuilder: (context) => [
                                                const PopupMenuItem(
                                                  value: 'edit',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.edit),
                                                      SizedBox(width: 8),
                                                      Text('Edit'),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.delete,
                                                          color: Colors.red),
                                                      SizedBox(width: 8),
                                                      Text('Delete',
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.red)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                              onSelected: (value) {
                                                if (value == 'edit') {
                                                  _showEditStudentDialog(
                                                      student);
                                                } else if (value == 'delete') {
                                                  _deleteStudent(
                                                      student['_id']);
                                                }
                                              },
                                            ),
                                        ],
                                      ),
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
