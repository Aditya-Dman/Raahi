import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/emergency_contact.dart';
import 'services/supabase_data_service.dart';
import 'services/supabase_auth_service.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final SupabaseDataService _dataService = SupabaseDataService();
  final SupabaseAuthService _authService = SupabaseAuthService();
  List<EmergencyContact> contacts = [];
  bool isLoading = true;

  // Beige color theme
  static const Color primaryBeige = Color(0xFFD2B48C);
  static const Color secondaryBeige = Color(0xFFC19A6B);
  static const Color lightBeige = Color(0xFFF5F5DC);
  static const Color darkBeige = Color(0xFF8B7355);

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => isLoading = true);

    // Get current user from Supabase auth
    final currentUser = await _authService.getCurrentUser();
    if (currentUser != null) {
      final userContacts = await _dataService.getEmergencyContacts(
        currentUser.id.toString(),
      );
      setState(() {
        contacts = userContacts;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
      _showSnackBar('Please log in to view emergency contacts');
    }
  }

  Future<void> _callContact(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        _showSnackBar('Could not launch phone app');
      }
    } catch (e) {
      _showSnackBar('Error making call: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: secondaryBeige),
    );
  }

  void _showAddEditDialog([EmergencyContact? contact]) {
    showDialog(
      context: context,
      builder: (context) => AddEditContactDialog(
        contact: contact,
        onSave: (savedContact) async {
          final currentUser = await _authService.getCurrentUser();
          if (currentUser != null) {
            final contactWithUserId = savedContact.copyWith(
              userId: currentUser.id.toString(),
            );

            bool success;
            if (contact == null) {
              success = await _dataService.addEmergencyContact(
                contactWithUserId,
              );
            } else {
              success = await _dataService.updateEmergencyContact(
                contactWithUserId,
              );
            }

            if (success) {
              _loadContacts();
              _showSnackBar(
                contact == null
                    ? 'Contact added successfully'
                    : 'Contact updated successfully',
              );
            } else {
              _showSnackBar('Failed to save contact');
            }
          } else {
            _showSnackBar('Please log in to save contacts');
          }
        },
      ),
    );
  }

  Future<void> _deleteContact(EmergencyContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: lightBeige,
        title: Text(
          'Delete Contact',
          style: TextStyle(color: darkBeige, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete ${contact.name}?',
          style: TextStyle(color: darkBeige),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: secondaryBeige)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        final success = await _dataService.deleteEmergencyContact(
          contact.id,
          currentUser.id.toString(),
        );
        if (success) {
          _loadContacts();
          _showSnackBar('Contact deleted successfully');
        } else {
          _showSnackBar('Failed to delete contact');
        }
      } else {
        _showSnackBar('Please log in to delete contacts');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBeige,
      appBar: AppBar(
        title: Text(
          'Emergency Contacts',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryBeige,
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryBeige))
          : contacts.isEmpty
          ? _buildEmptyState()
          : _buildContactsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: primaryBeige,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.contact_emergency, size: 80, color: secondaryBeige),
          SizedBox(height: 20),
          Text(
            'No Emergency Contacts',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: darkBeige,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Add your trusted contacts for emergencies',
            style: TextStyle(fontSize: 16, color: secondaryBeige),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () => _showAddEditDialog(),
            icon: Icon(Icons.add, color: Colors.white),
            label: Text(
              'Add First Contact',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBeige,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return Card(
          color: Colors.white,
          margin: EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 3,
          child: ListTile(
            contentPadding: EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: contact.isPrimary
                  ? primaryBeige
                  : secondaryBeige,
              child: Icon(
                contact.isPrimary ? Icons.star : Icons.person,
                color: Colors.white,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    contact.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: darkBeige,
                    ),
                  ),
                ),
                if (contact.isPrimary)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryBeige,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'PRIMARY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text(
                  contact.relationship,
                  style: TextStyle(
                    color: secondaryBeige,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  contact.phoneNumber,
                  style: TextStyle(color: darkBeige, fontSize: 16),
                ),
                if (contact.email != null && contact.email!.isNotEmpty) ...[
                  SizedBox(height: 2),
                  Text(
                    contact.email!,
                    style: TextStyle(color: secondaryBeige, fontSize: 14),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _callContact(contact.phoneNumber),
                  icon: Icon(Icons.call, color: Colors.green),
                  tooltip: 'Call',
                ),
                PopupMenuButton(
                  icon: Icon(Icons.more_vert, color: secondaryBeige),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: primaryBeige),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                      onTap: () => Future.delayed(
                        Duration.zero,
                        () => _showAddEditDialog(contact),
                      ),
                    ),
                    PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                      onTap: () => Future.delayed(
                        Duration.zero,
                        () => _deleteContact(contact),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AddEditContactDialog extends StatefulWidget {
  final EmergencyContact? contact;
  final Function(EmergencyContact) onSave;

  const AddEditContactDialog({super.key, this.contact, required this.onSave});

  @override
  State<AddEditContactDialog> createState() => _AddEditContactDialogState();
}

class _AddEditContactDialogState extends State<AddEditContactDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String _selectedRelationship = 'Family';
  bool _isPrimary = false;

  // Beige color theme
  static const Color primaryBeige = Color(0xFFD2B48C);
  static const Color secondaryBeige = Color(0xFFC19A6B);
  static const Color lightBeige = Color(0xFFF5F5DC);
  static const Color darkBeige = Color(0xFF8B7355);

  final List<String> relationships = [
    'Family',
    'Friend',
    'Spouse',
    'Parent',
    'Sibling',
    'Colleague',
    'Doctor',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.contact != null) {
      _nameController.text = widget.contact!.name;
      _phoneController.text = widget.contact!.phoneNumber;
      _emailController.text = widget.contact!.email ?? '';
      _selectedRelationship = widget.contact!.relationship;
      _isPrimary = widget.contact!.isPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: lightBeige,
      title: Text(
        widget.contact == null ? 'Add Emergency Contact' : 'Edit Contact',
        style: TextStyle(color: darkBeige, fontWeight: FontWeight.bold),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: TextStyle(color: secondaryBeige),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: primaryBeige),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: TextStyle(color: secondaryBeige),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: primaryBeige),
                  ),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a phone number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email (Optional)',
                  labelStyle: TextStyle(color: secondaryBeige),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: primaryBeige),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedRelationship,
                decoration: InputDecoration(
                  labelText: 'Relationship',
                  labelStyle: TextStyle(color: secondaryBeige),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: primaryBeige),
                  ),
                ),
                items: relationships.map((relationship) {
                  return DropdownMenuItem(
                    value: relationship,
                    child: Text(relationship),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRelationship = value!;
                  });
                },
              ),
              SizedBox(height: 16),
              CheckboxListTile(
                title: Text(
                  'Set as Primary Contact',
                  style: TextStyle(color: darkBeige),
                ),
                subtitle: Text(
                  'This will be your main emergency contact',
                  style: TextStyle(color: secondaryBeige, fontSize: 12),
                ),
                value: _isPrimary,
                onChanged: (value) {
                  setState(() {
                    _isPrimary = value ?? false;
                  });
                },
                activeColor: primaryBeige,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: secondaryBeige)),
        ),
        ElevatedButton(
          onPressed: _saveContact,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBeige,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            widget.contact == null ? 'Add Contact' : 'Update Contact',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  void _saveContact() {
    if (_formKey.currentState!.validate()) {
      final now = DateTime.now();
      final contact = EmergencyContact(
        id: widget.contact?.id,
        userId: widget.contact?.userId ?? '', // Will be set by parent
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        relationship: _selectedRelationship,
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        isPrimary: _isPrimary,
        createdAt: widget.contact?.createdAt ?? now,
        updatedAt: now,
      );

      widget.onSave(contact);
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}
