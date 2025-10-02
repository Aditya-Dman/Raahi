import 'dart:convert';
import 'supabase_service.dart';
import 'supabase_auth_service.dart';
import 'blockchain_service.dart';
import '../models/emergency_contact.dart';

class SupabaseDataService {
  static final SupabaseDataService _instance = SupabaseDataService._internal();
  factory SupabaseDataService() => _instance;
  SupabaseDataService._internal();

  final SupabaseService _supabaseService = SupabaseService();

  // User profile operations
  Future<List<AppUser>> getAllUsers() async {
    try {
      final response = await _supabaseService.select('user_profiles');
      return response.map((user) => AppUser.fromMap(user)).toList();
    } catch (e) {
      print('Error getting users: $e');
      return [];
    }
  }

  Future<AppUser?> getUserById(String id) async {
    try {
      final response = await _supabaseService.selectWhere(
        'user_profiles',
        'id',
        id,
      );
      if (response.isNotEmpty) {
        return AppUser.fromMap(response.first);
      }
      return null;
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }

  Future<AppUser?> getUserByEmail(String email) async {
    try {
      final response = await _supabaseService.selectWhere(
        'user_profiles',
        'email',
        email,
      );
      if (response.isNotEmpty) {
        return AppUser.fromMap(response.first);
      }
      return null;
    } catch (e) {
      print('Error getting user by email: $e');
      return null;
    }
  }

  Future<bool> updateUserProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _supabaseService.update('user_profiles', updates, 'id', userId);
      return true;
    } catch (e) {
      print('Error updating user profile: $e');
      return false;
    }
  }

  Future<bool> deleteUser(String userId) async {
    try {
      await _supabaseService.delete('user_profiles', 'id', userId);
      return true;
    } catch (e) {
      print('Error deleting user: $e');
      return false;
    }
  }

  // Location tracking operations (for tourist safety features)
  Future<bool> saveUserLocation({
    required String userId,
    required double latitude,
    required double longitude,
    String? locationName,
  }) async {
    try {
      await _supabaseService.insert('user_locations', {
        'user_id': userId,
        'latitude': latitude,
        'longitude': longitude,
        'location_name': locationName,
        'timestamp': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error saving location: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getUserLocations(String userId) async {
    try {
      final response = await _supabaseService.selectWhere(
        'user_locations',
        'user_id',
        userId,
      );
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting user locations: $e');
      return [];
    }
  }

  // Geofence alert operations
  Future<bool> saveGeofenceAlert({
    required String userId,
    required double latitude,
    required double longitude,
    required String alertType,
    required String zoneId,
    required double severity,
    required Map<String, dynamic> evidence,
  }) async {
    try {
      await _supabaseService.insert('user_locations', {
        'user_id': userId,
        'latitude': latitude,
        'longitude': longitude,
        'location_name': 'Geofence Alert: $alertType in $zoneId (severity: ${(severity * 100).round()}%)',
        'timestamp': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error saving geofence alert: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getGeofenceAlerts(String userId) async {
    try {
      final response = await _supabaseService.client
          .from('user_locations')
          .select()
          .eq('user_id', userId)
          .like('location_name', 'Geofence Alert:%')
          .order('timestamp', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting geofence alerts: $e');
      return [];
    }
  }

  // Debugging function to check Supabase connection and directly create tourist info
  Future<Map<String, dynamic>> debugSupabaseConnection() async {
    final Map<String, dynamic> result = {'supabase_connected': false};

    try {
      // Check connection
      final user = _supabaseService.currentUser;
      result['supabase_connected'] = user != null;

      if (user != null) {
        result['current_user_id'] = user.id;

        // Try to directly create tourist_info record for this user
        try {
          await _supabaseService.client.from('tourist_info').insert({
            'user_id': user.id,
            'destination': 'Test Destination',
            'check_in_date': DateTime.now().toIso8601String(),
            'check_out_date': DateTime.now()
                .add(Duration(days: 7))
                .toIso8601String(),
            'hotel_info': 'Test Hotel',
            'emergency_contact': json.encode([
              {
                "id": DateTime.now().millisecondsSinceEpoch.toString(),
                "name": "Test Contact",
                "phone_number": "+1234567890",
                "relationship": "Test",
                "is_primary": true,
                "user_id": user.id,
                "created_at": DateTime.now().toIso8601String(),
                "updated_at": DateTime.now().toIso8601String(),
              },
            ]),
            'created_at': DateTime.now().toIso8601String(),
          });

          result['test_record_created'] = true;
        } catch (insertError) {
          print('Error creating test record: $insertError');
          result['test_record_error'] = insertError.toString();
        }
      }

      // Log diagnostic info
      print('Supabase debug info: $result');
      return result;
    } catch (e) {
      print('Error in debug connection: $e');
      result['error'] = e.toString();
      return result;
    }
  }

  // Emergency alerts operations
  Future<bool> createEmergencyAlert({
    required String userId,
    required String alertType,
    required String message,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _supabaseService.insert('emergency_alerts', {
        'user_id': userId,
        'alert_type': alertType,
        'message': message,
        'latitude': latitude,
        'longitude': longitude,
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error creating emergency alert: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getActiveAlerts() async {
    try {
      final response = await _supabaseService.selectWhere(
        'emergency_alerts',
        'status',
        'active',
      );
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting active alerts: $e');
      return [];
    }
  }

  Future<bool> updateAlertStatus(String alertId, String status) async {
    try {
      await _supabaseService.update(
        'emergency_alerts',
        {'status': status},
        'id',
        alertId,
      );
      return true;
    } catch (e) {
      print('Error updating alert status: $e');
      return false;
    }
  }

  // Tourist information operations
  Future<bool> saveTouristInfo({
    required String userId,
    required String destination,
    required DateTime checkInDate,
    required DateTime checkOutDate,
    String? hotelInfo,
    String? emergencyContact,
  }) async {
    try {
      await _supabaseService.insert('tourist_info', {
        'user_id': userId,
        'destination': destination,
        'check_in_date': checkInDate.toIso8601String(),
        'check_out_date': checkOutDate.toIso8601String(),
        'hotel_info': hotelInfo,
        'emergency_contact': emergencyContact,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error saving tourist info: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getTouristInfo(String userId) async {
    try {
      print('🔧 DEBUG: Getting tourist info for userId: $userId');
      final response = await _supabaseService.selectWhere(
        'tourist_info',
        'user_id',
        userId,
      );
      print('🔧 DEBUG: getTouristInfo response: $response');
      if (response.isNotEmpty) {
        print('🔧 DEBUG: Found existing tourist info: ${response.first}');
        return response.first;
      }
      print('🔧 DEBUG: No existing tourist info found');
      return null;
    } catch (e) {
      print('🔧 ERROR getting tourist info: $e');
      return null;
    }
  }

  // Direct method to create tourist_info table if it doesn't exist
  Future<bool> ensureTouristInfoTableExists() async {
    try {
      // Try direct database operation to create table
      final sql = '''
      CREATE TABLE IF NOT EXISTS public.tourist_info (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        user_id UUID REFERENCES auth.users(id),
        destination TEXT DEFAULT '',
        check_in_date TIMESTAMP WITH TIME ZONE DEFAULT now(),
        check_out_date TIMESTAMP WITH TIME ZONE DEFAULT now(),
        hotel_info TEXT,
        emergency_contact JSONB,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
      );
      ''';

      await _supabaseService.client.rpc('run_sql', params: {'query': sql});
      return true;
    } catch (e) {
      print('Error creating tourist_info table (may already exist): $e');
      return false;
    }
  }

  // Emergency Contacts operations - Save to tourist_info table
  Future<bool> addEmergencyContact(EmergencyContact contact) async {
    try {
      print('🔧 DEBUG: Starting addEmergencyContact');
      print('🔧 User ID: ${contact.userId}');
      print('🔧 Contact name: ${contact.name}');
      print('🔧 Contact phoneNumber: ${contact.phoneNumber}');
      print('🔧 Contact data: ${contact.toMap()}');

      // First ensure the table exists
      print('🔧 DEBUG: Ensuring tourist_info table exists...');
      await ensureTouristInfoTableExists();
      print('🔧 DEBUG: Table check completed');

      // Get existing tourist info to preserve other data
      print(
        '🔧 DEBUG: Getting existing tourist info for user: ${contact.userId}',
      );
      final existingInfo = await getTouristInfo(contact.userId);
      print('🔧 DEBUG: Existing info: $existingInfo');
      List<Map<String, dynamic>> contactsList = [];

      // Parse existing emergency contacts if any
      if (existingInfo != null && existingInfo['emergency_contact'] != null) {
        try {
          final existingContacts = existingInfo['emergency_contact'];
          if (existingContacts is String) {
            // Try to parse as JSON
            contactsList = List<Map<String, dynamic>>.from(
              json.decode(existingContacts),
            );
          } else if (existingContacts is List) {
            contactsList = List<Map<String, dynamic>>.from(existingContacts);
          }
        } catch (parseError) {
          print('Error parsing existing contacts, starting fresh: $parseError');
          contactsList = [];
        }
      }

      // If this is marked as primary, remove primary from other contacts
      if (contact.isPrimary) {
        for (var existingContact in contactsList) {
          existingContact['is_primary'] = false;
        }
      }

      // Add the new contact
      contactsList.add(contact.toMap());
      print('🔧 DEBUG: Final contacts list: $contactsList');
      print('🔧 DEBUG: JSON encoded: ${json.encode(contactsList)}');

      // Save back to tourist_info
      if (existingInfo != null) {
        print('🔧 DEBUG: Updating existing tourist_info record');
        // Update existing record
        await _supabaseService.update(
          'tourist_info',
          {'emergency_contact': json.encode(contactsList)},
          'user_id',
          contact.userId,
        );
        print('🔧 DEBUG: Update completed successfully');
      } else {
        print('🔧 DEBUG: Creating new tourist_info record');
        // Create new tourist info record with emergency contact
        await _supabaseService.insert('tourist_info', {
          'user_id': contact.userId,
          'destination': '',
          'check_in_date': DateTime.now().toIso8601String(),
          'check_out_date': DateTime.now().toIso8601String(),
          'hotel_info': '',
          'emergency_contact': json.encode(contactsList),
          'created_at': DateTime.now().toIso8601String(),
        });
        print('🔧 DEBUG: Insert completed successfully');
      }

      print('🔧 DEBUG: Emergency contact added successfully to tourist_info');
      return true;
    } catch (e) {
      print('Error adding emergency contact: $e');
      print('Full error details: ${e.toString()}');
      return false;
    }
  }

  Future<List<EmergencyContact>> getEmergencyContacts(String userId) async {
    try {
      print('Getting emergency contacts for user: $userId');

      // Get from tourist_info table
      final touristInfo = await getTouristInfo(userId);
      if (touristInfo == null || touristInfo['emergency_contact'] == null) {
        print('No emergency contacts found');
        return [];
      }

      final contactsData = touristInfo['emergency_contact'];
      List<Map<String, dynamic>> contactsList = [];

      // Parse the contacts data
      if (contactsData is String) {
        try {
          contactsList = List<Map<String, dynamic>>.from(
            json.decode(contactsData),
          );
        } catch (parseError) {
          print('Error parsing contacts JSON: $parseError');
          return [];
        }
      } else if (contactsData is List) {
        contactsList = List<Map<String, dynamic>>.from(contactsData);
      }

      print('Found ${contactsList.length} emergency contacts');
      final contacts = contactsList
          .map((contactMap) => EmergencyContact.fromMap(contactMap))
          .toList();
      return contacts;
    } catch (e) {
      print('Error getting emergency contacts: $e');
      print('Full error details: ${e.toString()}');
      return [];
    }
  }

  Future<bool> updateEmergencyContact(EmergencyContact contact) async {
    try {
      print('Updating emergency contact: ${contact.id}');

      // Get existing contacts from tourist_info
      final existingContacts = await getEmergencyContacts(contact.userId);
      if (existingContacts.isEmpty) {
        print('No existing contacts found for update');
        return false;
      }

      // Find and update the specific contact
      bool found = false;
      List<Map<String, dynamic>> updatedContactsList = [];

      for (var existingContact in existingContacts) {
        if (existingContact.id == contact.id) {
          // If this contact is being marked as primary, remove primary from others
          if (contact.isPrimary) {
            for (var otherContact in existingContacts) {
              if (otherContact.id != contact.id) {
                updatedContactsList.add(
                  otherContact.copyWith(isPrimary: false).toMap(),
                );
              }
            }
          }
          // Add the updated contact
          updatedContactsList.add(
            contact.copyWith(updatedAt: DateTime.now()).toMap(),
          );
          found = true;
        } else {
          // Keep other contacts unchanged (unless we need to remove primary)
          if (contact.isPrimary) {
            updatedContactsList.add(
              existingContact.copyWith(isPrimary: false).toMap(),
            );
          } else {
            updatedContactsList.add(existingContact.toMap());
          }
        }
      }

      if (!found) {
        print('Contact with ID ${contact.id} not found');
        return false;
      }

      // Save updated contacts back to tourist_info
      await _supabaseService.update(
        'tourist_info',
        {'emergency_contact': json.encode(updatedContactsList)},
        'user_id',
        contact.userId,
      );

      print('Emergency contact updated successfully');
      return true;
    } catch (e) {
      print('Error updating emergency contact: $e');
      return false;
    }
  }

  Future<bool> deleteEmergencyContact(String contactId, String userId) async {
    try {
      print('Deleting emergency contact: $contactId');

      // Get existing contacts from tourist_info
      final existingContacts = await getEmergencyContacts(userId);
      if (existingContacts.isEmpty) {
        print('No existing contacts found for deletion');
        return false;
      }

      // Remove the specific contact
      final updatedContactsList = existingContacts
          .where((contact) => contact.id != contactId)
          .map((contact) => contact.toMap())
          .toList();

      // Save updated contacts back to tourist_info
      await _supabaseService.update(
        'tourist_info',
        {'emergency_contact': json.encode(updatedContactsList)},
        'user_id',
        userId,
      );

      print('Emergency contact deleted successfully');
      return true;
    } catch (e) {
      print('Error deleting emergency contact: $e');
      return false;
    }
  }

  Future<EmergencyContact?> getPrimaryEmergencyContact(String userId) async {
    try {
      final contacts = await getEmergencyContacts(userId);
      // Find primary contact first
      for (final contact in contacts) {
        if (contact.isPrimary) {
          return contact;
        }
      }
      // If no primary, return first contact or null
      return contacts.isNotEmpty ? contacts.first : null;
    } catch (e) {
      print('Error getting primary emergency contact: $e');
      return null;
    }
  }

  // KYC operations
  Future<bool> saveKYCData({
    required String userId,
    required String firstName,
    required String lastName,
    required String email,
    required String nationality,
    required String idType,
    required String idNumber,
    required String idExpiryDate,
    required String addressLine1,
    String? addressLine2,
    required String city,
    required String state,
    required String postalCode,
    required String country,
    String? idDocumentImagePath,
    String? addressProofImagePath,
  }) async {
    try {
      final kycData = {
        'user_id': userId,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'nationality': nationality,
        'id_type': idType,
        'id_number': idNumber,
        'id_expiry_date': idExpiryDate,
        'address_line_1': addressLine1,
        'address_line_2': addressLine2,
        'city': city,
        'state': state,
        'postal_code': postalCode,
        'country': country,
        'id_document_image_path': idDocumentImagePath,
        'address_proof_image_path': addressProofImagePath,
        'status': 'pending',
        'submitted_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Generate blockchain-based digital ID
      final blockchainService = BlockchainService();
      final digitalIDRecord = blockchainService.createDigitalIDRecord(
        userId: userId,
        kycData: kycData,
        status: 'pending',
      );

      // Save KYC data first (without blockchain columns to avoid DB errors)
      await _supabaseService.insert('kyc_verifications', kycData);

      // Save blockchain digital ID separately
      try {
        await _supabaseService.insert('digital_ids', digitalIDRecord);
        print('Digital ID created: ${digitalIDRecord['digital_id_hash']}');
      } catch (e) {
        print(
          'Note: Digital ID table not created yet. Creating mock data for demo.',
        );
        // For demo purposes, we'll just log the digital ID
      }

      print(
        'KYC data saved successfully with blockchain digital ID: ${digitalIDRecord['digital_id_hash']}',
      );
      return true;
    } catch (e) {
      print('Error saving KYC data: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getKYCData(String userId) async {
    try {
      // Get the most recent KYC record for this user (for prototype demonstration)
      final response = await _supabaseService.selectWhere(
        'kyc_verifications',
        'user_id',
        userId,
      );

      if (response.isNotEmpty) {
        // Sort by created_at descending to get the most recent
        response.sort((a, b) {
          final aTime = DateTime.parse(
            a['created_at'] ?? DateTime.now().toIso8601String(),
          );
          final bTime = DateTime.parse(
            b['created_at'] ?? DateTime.now().toIso8601String(),
          );
          return bTime.compareTo(aTime); // Descending order
        });
        return response.first; // Return the most recent record
      }
      return null;
    } catch (e) {
      print('Error getting KYC data: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getDigitalID(String userId) async {
    try {
      // Get the most recent digital ID record for this user
      final response = await _supabaseService.selectWhere(
        'digital_ids',
        'user_id',
        userId,
      );

      if (response.isNotEmpty) {
        // Sort by created_at descending to get the most recent
        response.sort((a, b) {
          final aTime = DateTime.parse(
            a['created_at'] ?? DateTime.now().toIso8601String(),
          );
          final bTime = DateTime.parse(
            b['created_at'] ?? DateTime.now().toIso8601String(),
          );
          return bTime.compareTo(aTime); // Descending order
        });
        return response.first; // Return the most recent record
      }
      return null;
    } catch (e) {
      print('Error getting Digital ID data: $e');
      return null;
    }
  }

  Future<String> getKYCStatus(String userId) async {
    try {
      final kycData = await getKYCData(userId);
      if (kycData != null) {
        return kycData['status'] ?? 'not_submitted';
      }
      return 'not_submitted';
    } catch (e) {
      print('Error getting KYC status: $e');
      return 'not_submitted';
    }
  }

  Future<bool> updateKYCStatus(String userId, String status) async {
    try {
      await _supabaseService.update(
        'kyc_verifications',
        {'status': status, 'updated_at': DateTime.now().toIso8601String()},
        'user_id',
        userId,
      );
      return true;
    } catch (e) {
      print('Error updating KYC status: $e');
      return false;
    }
  }

  // Method to reset KYC for prototype demonstration
  Future<bool> resetKYCForDemo(String userId) async {
    try {
      // For demo purposes, just create a new record with 'not_submitted' status
      // This allows the user to submit KYC again to show the flow
      final demoResetData = {
        'user_id': userId,
        'status': 'not_submitted',
        'submitted_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        // Add minimal data for the reset record with correct column names
        'first_name': 'Demo',
        'last_name': 'Reset',
        'email': 'demo@reset.com',
        'nationality': 'Demo',
        'id_type': 'Passport',
        'id_number': 'DEMO-RESET',
        'address_line_1': 'Demo Address',
        'address_line_2': null,
        'city': 'Demo City',
        'state': 'Demo State',
        'postal_code': '00000',
        'country': 'Demo Country',
        'id_document_image_path': null,
        'address_proof_image_path': null,
      };

      await _supabaseService.insert('kyc_verifications', demoResetData);
      print('KYC demo reset record created - user can submit again');
      return true;
    } catch (e) {
      print('Error resetting KYC for demo: $e');
      return false;
    }
  }
}
