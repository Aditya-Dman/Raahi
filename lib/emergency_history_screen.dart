import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'services/emergency_alert_service.dart';

class EmergencyHistoryScreen extends StatefulWidget {
  const EmergencyHistoryScreen({super.key});

  @override
  State<EmergencyHistoryScreen> createState() => _EmergencyHistoryScreenState();
}

class _EmergencyHistoryScreenState extends State<EmergencyHistoryScreen> {
  final _service = EmergencyAlertService();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _service.loadAlertHistory();
    if (mounted) setState(() => _loading = false);
  }

  String _label(AlertType type) => switch (type) {
    AlertType.sos => 'SOS emergency',
    AlertType.medical => 'Medical assistance',
    AlertType.security => 'Security assistance',
    AlertType.location => 'Location shared',
  };

  @override
  Widget build(BuildContext context) {
    final history = _service.alertHistory;
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency history')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : history.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'No emergency events have been recorded yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final event = history[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.tealSoft,
                      foregroundColor: AppColors.teal,
                      child: Icon(
                        event.type == AlertType.sos
                            ? Icons.sos_rounded
                            : Icons.notifications_active_outlined,
                      ),
                    ),
                    title: Text(
                      _label(event.type),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${event.timestamp.toLocal()}\n'
                        '${event.location == null ? 'Location unavailable' : 'Location captured'}',
                      ),
                    ),
                    trailing: Text(
                      event.contactsNotified > 0
                          ? '${event.contactsNotified} notified'
                          : 'Recorded',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
