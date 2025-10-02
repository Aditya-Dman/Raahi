import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'services/supabase_data_service.dart';
import 'services/supabase_auth_service.dart';

class KYCUpdateScreen extends StatefulWidget {
  const KYCUpdateScreen({super.key});

  @override
  State<KYCUpdateScreen> createState() => _KYCUpdateScreenState();
}

class _KYCUpdateScreenState extends State<KYCUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _countryController = TextEditingController();

  String _selectedIdType = 'Aadhaar Card';
  DateTime? _idExpiryDate;
  File? _idDocumentImage;
  File? _addressProofImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _nationalityController.dispose();
    _idNumberController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isIdDocument) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          if (isIdDocument) {
            _idDocumentImage = File(pickedFile.path);
          } else {
            _addressProofImage = File(pickedFile.path);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFD2B48C),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _idExpiryDate = picked;
      });
    }
  }

  void _submitKYC() async {
    print('🔧 Submit KYC button pressed');

    // Enhanced debugging for validation
    print('🔧 Checking form fields...');
    print('🔧 First Name: "${_firstNameController.text}"');
    print('🔧 Last Name: "${_lastNameController.text}"');
    print('🔧 Email: "${_emailController.text}"');
    print('🔧 Nationality: "${_nationalityController.text}"');
    print('🔧 ID Number: "${_idNumberController.text}"');
    print('🔧 ID Expiry Date: $_idExpiryDate');
    print('🔧 Address Line 1: "${_addressLine1Controller.text}"');
    print('🔧 Address Line 2: "${_addressLine2Controller.text}"');
    print('🔧 City: "${_cityController.text}"');
    print('🔧 State: "${_stateController.text}"');
    print('🔧 Postal Code: "${_postalCodeController.text}"');
    print('🔧 Country: "${_countryController.text}"');
    print('🔧 ID Photo: $_idDocumentImage');
    print('🔧 Address Proof: $_addressProofImage');

    if (_formKey.currentState!.validate()) {
      print('🔧 Form validation passed');

      if (_idDocumentImage == null) {
        print('🔧 ID document image missing');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload ID document image')),
        );
        return;
      }

      if (_addressProofImage == null) {
        print('🔧 Address proof image missing');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload address proof image')),
        );
        return;
      }

      if (_idExpiryDate == null) {
        print('🔧 ID expiry date missing');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select ID expiry date')),
        );
        return;
      }

      print('🔧 All validations passed, starting submission...');

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFD2B48C)),
        ),
      );

      try {
        // Get current user ID
        final authService = SupabaseAuthService();
        final currentUser = await authService.getCurrentUser();

        if (currentUser == null) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not authenticated')),
          );
          return;
        }

        // Save KYC data to database
        final dataService = SupabaseDataService();
        final success = await dataService.saveKYCData(
          userId: currentUser.id,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          nationality: _nationalityController.text.trim(),
          idType: _selectedIdType,
          idNumber: _idNumberController.text.trim(),
          idExpiryDate: _idExpiryDate!.toIso8601String(),
          addressLine1: _addressLine1Controller.text.trim(),
          addressLine2: _addressLine2Controller.text.trim().isEmpty
              ? null
              : _addressLine2Controller.text.trim(),
          city: _cityController.text.trim(),
          state: _stateController.text.trim(),
          postalCode: _postalCodeController.text.trim(),
          country: _countryController.text.trim(),
          idDocumentImagePath: _idDocumentImage?.path,
          addressProofImagePath: _addressProofImage?.path,
        );

        Navigator.pop(context); // Close loading dialog

        if (success) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'KYC information submitted successfully! Status: Pending',
              ),
              backgroundColor: Colors.green,
            ),
          );

          // Go back to dashboard with success flag
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to submit KYC information. Please try again.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } else {
      print('🔧 Form validation failed');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields correctly'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F3),
      appBar: AppBar(
        title: const Text(
          'KYC Verification',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFD2B48C),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Personal Information Section
              _buildSectionHeader('Personal Information', Icons.person_outline),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _firstNameController,
                      label: 'First Name',
                      icon: Icons.person,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter first name';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _lastNameController,
                      label: 'Last Name',
                      icon: Icons.person,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter last name';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _emailController,
                label: 'Email Address',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter email address';
                  }
                  if (!RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _nationalityController,
                label: 'Nationality',
                icon: Icons.flag,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter nationality';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 32),

              // ID Document Section
              _buildSectionHeader('Identity Document', Icons.credit_card),
              const SizedBox(height: 16),

              // ID Type Dropdown
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedIdType,
                  decoration: const InputDecoration(
                    labelText: 'ID Document Type',
                    prefixIcon: Icon(Icons.badge),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  items: ['Aadhaar Card', 'Passport'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedIdType = newValue!;
                    });
                  },
                ),
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _idNumberController,
                label: 'ID Number',
                icon: Icons.numbers,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter ID number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Expiry Date
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    _idExpiryDate == null
                        ? 'Select Expiry Date'
                        : 'Expires: ${_idExpiryDate!.day}/${_idExpiryDate!.month}/${_idExpiryDate!.year}',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _selectDate,
                ),
              ),

              const SizedBox(height: 16),

              // ID Document Image Upload
              _buildImageUploadCard(
                title: 'Upload ID Document',
                subtitle: 'Clear photo of your $_selectedIdType',
                image: _idDocumentImage,
                onTap: () => _pickImage(true),
              ),

              const SizedBox(height: 32),

              // Address Information Section
              _buildSectionHeader(
                'Address Information',
                Icons.location_on_outlined,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _addressLine1Controller,
                label: 'Address Line 1',
                icon: Icons.home,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter address line 1';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _addressLine2Controller,
                label: 'Address Line 2 (Optional)',
                icon: Icons.home_outlined,
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _cityController,
                      label: 'City',
                      icon: Icons.location_city,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter city';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _stateController,
                      label: 'State',
                      icon: Icons.map,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter state';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _postalCodeController,
                      label: 'Postal Code',
                      icon: Icons.local_post_office,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter postal code';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _countryController,
                      label: 'Country',
                      icon: Icons.public,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter country';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Address Proof Image Upload
              _buildImageUploadCard(
                title: 'Upload Address Proof',
                subtitle: 'Utility bill, bank statement, or rental agreement',
                image: _addressProofImage,
                onTap: () => _pickImage(false),
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitKYC,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD2B48C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Submit KYC Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFD2B48C),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildImageUploadCard({
    required String title,
    required String subtitle,
    required File? image,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (image != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    image,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Image uploaded successfully',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: onTap, child: const Text('Change Image')),
              ] else ...[
                Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD2B48C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const Icon(
                    Icons.cloud_upload_outlined,
                    size: 40,
                    color: Color(0xFFD2B48C),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD2B48C),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Choose File',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
