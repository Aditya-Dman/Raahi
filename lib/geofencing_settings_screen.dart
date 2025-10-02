import 'package:flutter/material.dart';
import 'services/geofencing_service.dart';

class GeofencingSettingsScreen extends StatefulWidget {
  const GeofencingSettingsScreen({super.key});

  @override
  State<GeofencingSettingsScreen> createState() => _GeofencingSettingsScreenState();
}

class _GeofencingSettingsScreenState extends State<GeofencingSettingsScreen> {
  final GeofencingService _geofencingService = GeofencingService();
  
  bool _enabled = true;
  double _safetyThreshold = 65.0;
  double _anomalyThreshold = 60.0;
  int _alertIntervalMinutes = 5;
  bool _persistToSupabase = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    setState(() {
      _enabled = _geofencingService.isEnabled;
      _safetyThreshold = _geofencingService.safetyThreshold;
      _anomalyThreshold = _geofencingService.anomalyThreshold;
      _alertIntervalMinutes = _geofencingService.alertInterval.inMinutes;
      _persistToSupabase = _geofencingService.persistToSupabase;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    await _geofencingService.updateSettings(
      enabled: _enabled,
      safetyThreshold: _safetyThreshold,
      anomalyThreshold: _anomalyThreshold,
      alertInterval: Duration(minutes: _alertIntervalMinutes),
      persistToSupabase: _persistToSupabase,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Geofencing settings saved'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Geofencing Settings'),
          backgroundColor: const Color(0xFF6C63FF),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🛡️ Geofencing Settings'),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF4ECDC4)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security, color: Colors.white, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI Geofencing Protection',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Configure smart alerts for high-risk areas',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Enable/Disable Toggle
            _buildSettingsCard(
              title: 'Enable Geofencing',
              subtitle: 'Turn on/off location-based safety alerts',
              child: Switch(
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
                activeThumbColor: const Color(0xFF6C63FF),
              ),
            ),

            const SizedBox(height: 16),

            // Safety Threshold
            _buildSettingsCard(
              title: 'Safety Score Threshold',
              subtitle: 'Alert when safety score drops below ${_safetyThreshold.round()}%',
              child: Column(
                children: [
                  Slider(
                    value: _safetyThreshold,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${_safetyThreshold.round()}%',
                    onChanged: _enabled ? (value) => setState(() => _safetyThreshold = value) : null,
                    activeColor: const Color(0xFF6C63FF),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('0%', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      Text('100%', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Anomaly Threshold
            _buildSettingsCard(
              title: 'Anomaly Risk Threshold',
              subtitle: 'Alert when AI detects ${_anomalyThreshold.round()}% anomaly risk',
              child: Column(
                children: [
                  Slider(
                    value: _anomalyThreshold,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${_anomalyThreshold.round()}%',
                    onChanged: _enabled ? (value) => setState(() => _anomalyThreshold = value) : null,
                    activeColor: const Color(0xFFFF6B6B),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('0%', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      Text('100%', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Alert Interval
            _buildSettingsCard(
              title: 'Alert Frequency',
              subtitle: 'Minimum $_alertIntervalMinutes minutes between alerts',
              child: Column(
                children: [
                  Slider(
                    value: _alertIntervalMinutes.toDouble(),
                    min: 1,
                    max: 60,
                    divisions: 11,
                    label: '${_alertIntervalMinutes}min',
                    onChanged: _enabled ? (value) => setState(() => _alertIntervalMinutes = value.round()) : null,
                    activeColor: const Color(0xFF4ECDC4),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('1min', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      Text('60min', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Supabase Persistence
            _buildSettingsCard(
              title: 'Save to Cloud',
              subtitle: 'Store geofence alerts in your account for analytics',
              child: Switch(
                value: _persistToSupabase,
                onChanged: _enabled ? (value) => setState(() => _persistToSupabase = value) : null,
                activeThumbColor: const Color(0xFF6C63FF),
              ),
            ),

            const SizedBox(height: 24),

            // Current Status Card
            _buildStatusCard(),

            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save),
                    SizedBox(width: 8),
                    Text(
                      'Save Settings',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D1B69),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _enabled ? const Color(0xFFE8F5E8) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _enabled ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _enabled ? Icons.shield : Icons.warning,
            color: _enabled ? Colors.green : Colors.orange,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _enabled ? 'Geofencing Active' : 'Geofencing Disabled',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _enabled ? Colors.green[800] : Colors.orange[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _enabled 
                    ? 'Your location is being monitored for safety'
                    : 'Enable geofencing to receive safety alerts',
                  style: TextStyle(
                    fontSize: 14,
                    color: _enabled ? Colors.green[700] : Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
