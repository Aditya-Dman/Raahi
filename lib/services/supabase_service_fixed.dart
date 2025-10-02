import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  // Initialize Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );

    // Create required tables if they don't exist
    await _createRequiredTables();
  }

  // Create required tables in Supabase
  static Future<void> _createRequiredTables() async {
    try {
      final instance = SupabaseService();

      // Create tourist_info table if it doesn't exist
      try {
        // First try to query the table to see if it exists
        await instance.client.from('tourist_info').select().limit(1);
        print('Tourist info table already exists');
      } catch (tableError) {
        // Table doesn't exist, create it
        try {
          // This SQL directly creates the tourist_info table if it doesn't exist
          final sql = '''
          CREATE TABLE IF NOT EXISTS public.tourist_info (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            user_id UUID NOT NULL REFERENCES auth.users(id),
            destination TEXT NOT NULL DEFAULT '',
            check_in_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
            check_out_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
            hotel_info TEXT,
            emergency_contact JSONB,
            created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
          );
          -- Enable RLS
          ALTER TABLE public.tourist_info ENABLE ROW LEVEL SECURITY;
          ''';

          await instance.client.rpc('run_sql', params: {'query': sql});
          print('Tourist info table created via SQL');

          // Create policy separately to handle if it already exists
          try {
            final policySQL = '''
            CREATE POLICY user_policy ON public.tourist_info
              FOR ALL 
              USING (auth.uid() = user_id);
            ''';
            await instance.client.rpc('run_sql', params: {'query': policySQL});
            print('Access policy created');
          } catch (policyError) {
            print('Policy may already exist: $policyError');
          }

          // Grant permissions
          try {
            final grantSQL =
                'GRANT SELECT, INSERT, UPDATE, DELETE ON public.tourist_info TO authenticated;';
            await instance.client.rpc('run_sql', params: {'query': grantSQL});
            print('Permissions granted to authenticated users');
          } catch (grantError) {
            print('Grant error (may be ok): $grantError');
          }
        } catch (sqlError) {
          print('Could not create tourist_info table: $sqlError');
        }
      }
    } catch (e) {
      print('Error creating required tables: $e');
    }
  }

  // Auth methods
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: data,
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  // User accessors
  User? get currentUser => client.auth.currentUser;

  bool get isAuthenticated => client.auth.currentUser != null;

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // Database operations
  Future<List<dynamic>> select(String table) async {
    final response = await client.from(table).select();
    return response;
  }

  Future<List<dynamic>> selectWhere(
    String table,
    String column,
    dynamic value,
  ) async {
    final response = await client.from(table).select().eq(column, value);
    return response;
  }

  Future<void> insert(String table, Map<String, dynamic> data) async {
    await client.from(table).insert(data);
  }

  Future<void> update(
    String table,
    Map<String, dynamic> data,
    String column,
    dynamic value,
  ) async {
    await client.from(table).update(data).eq(column, value);
  }

  Future<void> delete(String table, String column, dynamic value) async {
    await client.from(table).delete().eq(column, value);
  }
}
