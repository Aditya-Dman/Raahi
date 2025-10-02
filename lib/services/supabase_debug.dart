import 'package:flutter/material.dart';
import 'supabase_service.dart';
import 'supabase_data_service.dart';
import 'supabase_auth_service.dart';
import 'dart:convert';

class SupabaseDebugScreen extends StatefulWidget {
  const SupabaseDebugScreen({super.key});

  @override
  State<SupabaseDebugScreen> createState() => _SupabaseDebugScreenState();
}

class _SupabaseDebugScreenState extends State<SupabaseDebugScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final SupabaseAuthService _authService = SupabaseAuthService();
  final SupabaseDataService _dataService = SupabaseDataService();

  final Map<String, dynamic> _debugInfo = {};
  String _status = 'Ready';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _checkConnection() async {
    setState(() {
      _isLoading = true;
      _status = 'Checking connection...';
    });

    try {
      // Check if user is authenticated using auth service
      final user = await _authService.getCurrentUser();
      _debugInfo['user_authenticated'] = user != null;

      if (user != null) {
        _debugInfo['user_id'] = user.id;
        _debugInfo['user_email'] = user.email;
      } else {
        _debugInfo['auth_error'] = 'Not authenticated - please log in';
      }

      setState(() {
        _status = user != null ? 'User authenticated' : 'Not authenticated';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error checking connection: $e';
        _debugInfo['error'] = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _testTouristInfoTable() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing tourist_info table...';
    });

    try {
      // Check if current user exists
      final user = await _authService.getCurrentUser();
      if (user == null) {
        setState(() {
          _status = 'Not authenticated - please log in first';
          _isLoading = false;
        });
        return;
      }

      // Check if table exists by querying it
      try {
        final result = await _supabaseService.client
            .from('tourist_info')
            .select()
            .limit(1);

        _debugInfo['tourist_info_table_exists'] = true;
        _debugInfo['query_result'] = result;

        // Try to get the user's tourist info
        final userInfo = await _dataService.getTouristInfo(user.id);
        _debugInfo['user_tourist_info'] = userInfo;

        if (userInfo == null) {
          // Create a test record
          final testContact = {
            "id": DateTime.now().millisecondsSinceEpoch.toString(),
            "name": "Test Contact",
            "phone_number": "+1234567890",
            "relationship": "Test",
            "is_primary": true,
            "user_id": user.id,
            "created_at": DateTime.now().toIso8601String(),
            "updated_at": DateTime.now().toIso8601String(),
          };

          final success = await _dataService.saveTouristInfo(
            userId: user.id,
            destination: 'Test Destination',
            checkInDate: DateTime.now(),
            checkOutDate: DateTime.now().add(Duration(days: 7)),
            hotelInfo: 'Test Hotel',
            emergencyContact: json.encode([testContact]),
          );

          _debugInfo['created_test_record'] = success;
        }

        setState(() {
          _status = 'Tourist info table exists and was tested';
          _isLoading = false;
        });
      } catch (tableError) {
        _debugInfo['tourist_info_table_exists'] = false;
        _debugInfo['table_error'] = tableError.toString();

        // Try to create the table with SQL
        try {
          // Create SQL for the tourist_info table
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
          ALTER TABLE public.tourist_info ENABLE ROW LEVEL SECURITY;
          ''';

          await _supabaseService.client.rpc('run_sql', params: {'query': sql});
          _debugInfo['created_table'] = true;

          // Create policy
          final policySQL = '''
          CREATE POLICY tourist_info_policy ON public.tourist_info
            FOR ALL USING (auth.uid() = user_id);
          ''';

          await _supabaseService.client.rpc(
            'run_sql',
            params: {'query': policySQL},
          );
          _debugInfo['created_policy'] = true;

          // Grant permissions
          final permSQL = '''
          GRANT SELECT, INSERT, UPDATE, DELETE ON public.tourist_info TO authenticated;
          GRANT USAGE, SELECT ON SEQUENCE tourist_info_id_seq TO authenticated;
          ''';

          await _supabaseService.client.rpc(
            'run_sql',
            params: {'query': permSQL},
          );
          _debugInfo['granted_permissions'] = true;

          setState(() {
            _status = 'Created tourist_info table!';
            _isLoading = false;
          });
        } catch (createError) {
          _debugInfo['create_table_error'] = createError.toString();
          setState(() {
            _status = 'Error creating table: $createError';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _status = 'Error testing tourist_info table: $e';
        _debugInfo['error'] = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _testEmergencyContact() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing emergency contact...';
    });

    try {
      // Check if current user exists
      final user = await _authService.getCurrentUser();
      if (user == null) {
        setState(() {
          _status = 'Not authenticated - please log in first';
          _isLoading = false;
        });
        return;
      } // Create a test emergency contact
      final now = DateTime.now();
      final testContact = {
        "id": now.millisecondsSinceEpoch.toString(),
        "user_id": user.id,
        "name": "Test Contact ${now.second}",
        "phone_number": "+1234567890",
        "relationship": "Test",
        "is_primary": true,
        "created_at": now.toIso8601String(),
        "updated_at": now.toIso8601String(),
      };

      // Direct Supabase Insert to tourist_info
      try {
        // First check if user record exists
        final response = await _supabaseService.client
            .from('tourist_info')
            .select()
            .eq('user_id', user.id.toString());

        if (response.isNotEmpty) {
          // Update existing record
          final existingInfo = response[0];
          List<dynamic> contacts = [];

          if (existingInfo['emergency_contact'] != null) {
            if (existingInfo['emergency_contact'] is String) {
              contacts = json.decode(existingInfo['emergency_contact']);
            } else {
              contacts = existingInfo['emergency_contact'];
            }
          }

          contacts.add(testContact);

          await _supabaseService.client
              .from('tourist_info')
              .update({'emergency_contact': contacts})
              .eq('user_id', user.id);

          _debugInfo['updated_contact'] = true;
        } else {
          // Create new record
          await _supabaseService.client.from('tourist_info').insert({
            'user_id': user.id,
            'destination': 'Test',
            'check_in_date': now.toIso8601String(),
            'check_out_date': now.add(Duration(days: 1)).toIso8601String(),
            'emergency_contact': [testContact],
            'created_at': now.toIso8601String(),
          });

          _debugInfo['created_contact'] = true;
        }

        // Retrieve contacts to verify
        final contacts = await _dataService.getEmergencyContacts(user.id);
        _debugInfo['retrieved_contacts'] = contacts
            .map((c) => c.toMap())
            .toList();

        setState(() {
          _status = 'Emergency contact test successful!';
          _isLoading = false;
        });
      } catch (insertError) {
        _debugInfo['insert_error'] = insertError.toString();
        setState(() {
          _status = 'Error inserting contact: $insertError';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error testing emergency contact: $e';
        _debugInfo['error'] = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supabase Debug'),
        backgroundColor: const Color(0xFFD2B48C),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: $_status',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 8),
                    const Text(
                      'Debug Information:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    if (_debugInfo.isNotEmpty)
                      ...(_debugInfo.entries.map(
                        (entry) => Text('${entry.key}: ${entry.value}'),
                      )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _checkConnection,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC19A6B),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Check Connection',
                style: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _testTouristInfoTable,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC19A6B),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Test Tourist Info Table',
                style: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _testEmergencyContact,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC19A6B),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Test Emergency Contact',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
