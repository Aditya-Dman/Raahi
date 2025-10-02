import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ai_alert_service.dart';
import 'dart:async';

// AI Alert Display Widget - Shows active alerts in the UI
class AIAlertWidget extends StatefulWidget {
  const AIAlertWidget({super.key});

  @override
  State<AIAlertWidget> createState() => _AIAlertWidgetState();
}

class _AIAlertWidgetState extends State<AIAlertWidget>
    with TickerProviderStateMixin {
  final AIAlertService _alertService = AIAlertService();
  late AnimationController _pulseController;
  late AnimationController _flashController;
  Timer? _alertCheckTimer;
  bool _isFlashing = false;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _flashController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Set up alert callbacks
    _alertService.onNewAlert = _onNewAlert;
    _alertService.onAlertResolved = _onAlertResolved;

    // Start checking for alerts
    _startAlertMonitoring();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _flashController.dispose();
    _alertCheckTimer?.cancel();
    _alertService.onNewAlert = null;
    _alertService.onAlertResolved = null;
    super.dispose();
  }

  void _startAlertMonitoring() {
    _alertCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {}); // Refresh UI to show new alerts
      }
    });
  }

  void _onNewAlert(AIAlert alert) {
    if (!mounted) return;

    // Trigger visual effects for high-priority alerts
    if (alert.deliveryMethods.contains(AlertDeliveryMethod.visual)) {
      _triggerVisualAlert(alert.type);
    }

    // Show in-app notification
    if (alert.deliveryMethods.contains(AlertDeliveryMethod.inApp)) {
      _showInAppAlert(alert);
    }

    setState(() {}); // Refresh UI
  }

  void _onAlertResolved(AIAlert alert) {
    if (mounted) {
      setState(() {}); // Refresh UI
    }
  }

  void _triggerVisualAlert(AIAlertType type) {
    switch (type) {
      case AIAlertType.critical:
      case AIAlertType.highRisk:
        _startFlashing();
        break;
      case AIAlertType.mediumRisk:
        HapticFeedback.mediumImpact();
        break;
      case AIAlertType.lowRisk:
        // No visual alert for low risk
        break;
    }
  }

  void _startFlashing() {
    if (!_isFlashing) {
      _isFlashing = true;
      _flashController.repeat();

      // Stop flashing after 10 seconds
      Timer(const Duration(seconds: 10), () {
        if (mounted && _isFlashing) {
          _isFlashing = false;
          _flashController.stop();
          _flashController.reset();
        }
      });
    }
  }

  void _showInAppAlert(AIAlert alert) {
    showDialog(
      context: context,
      barrierDismissible: alert.type == AIAlertType.lowRisk,
      builder: (context) => AlertDialog(
        backgroundColor: _getAlertBackgroundColor(alert.type),
        title: Row(
          children: [
            Icon(
              _getAlertIcon(alert.type),
              color: _getAlertColor(alert.type),
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                alert.title,
                style: TextStyle(
                  color: _getAlertColor(alert.type),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert.message),
            if (alert.recommendations.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Recommendations:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...alert.recommendations
                  .take(3)
                  .map(
                    (rec) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('• $rec'),
                    ),
                  ),
            ],
          ],
        ),
        actions: [
          if (alert.type != AIAlertType.lowRisk)
            TextButton(
              onPressed: () {
                _alertService.acknowledgeAlert(alert.id);
                Navigator.of(context).pop();
              },
              child: const Text('Acknowledge'),
            ),
          ElevatedButton(
            onPressed: () {
              _alertService.resolveAlert(alert.id);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _getAlertColor(alert.type),
            ),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeAlerts = _alertService.activeAlerts;
    final criticalAlerts = _alertService.getAlertsByType(AIAlertType.critical);
    final highRiskAlerts = _alertService.getAlertsByType(AIAlertType.highRisk);
    final hasUnacknowledged = _alertService.hasUnacknowledgedAlerts;

    if (activeAlerts.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _flashController,
      builder: (context, child) {
        return Container(
          decoration: _isFlashing
              ? BoxDecoration(
                  color: Colors.red.withOpacity(_flashController.value * 0.3),
                )
              : null,
          child: Card(
            margin: const EdgeInsets.all(8),
            color: _getWidgetBackgroundColor(activeAlerts),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Header
                  Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Icon(
                            Icons.warning_amber,
                            color: _getWidgetIconColor(activeAlerts),
                            size: 24 + (_pulseController.value * 4),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'AI Safety Alerts',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getWidgetIconColor(
                            activeAlerts,
                          ).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${activeAlerts.length}',
                          style: TextStyle(
                            color: _getWidgetIconColor(activeAlerts),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Alert Summary
                  if (criticalAlerts.isNotEmpty)
                    _buildAlertSummaryRow(
                      'Critical',
                      criticalAlerts.length,
                      Colors.red,
                      Icons.emergency,
                    ),

                  if (highRiskAlerts.isNotEmpty)
                    _buildAlertSummaryRow(
                      'High Risk',
                      highRiskAlerts.length,
                      Colors.orange,
                      Icons.warning,
                    ),

                  if (hasUnacknowledged)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '⚠️ You have unacknowledged alerts',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showAllAlerts(),
                          icon: const Icon(Icons.list, size: 16),
                          label: const Text('View All'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: activeAlerts.isNotEmpty
                              ? () => _resolveAllAlerts()
                              : null,
                          icon: const Icon(Icons.check_circle, size: 16),
                          label: const Text('Clear All'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlertSummaryRow(
    String label,
    int count,
    Color color,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            '$label: $count',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showAllAlerts() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Active AI Alerts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _alertService.activeAlerts.length,
                  itemBuilder: (context, index) {
                    final alert = _alertService.activeAlerts[index];
                    return _buildAlertListItem(alert);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _alertService.clearAllAlerts();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Clear All'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertListItem(AIAlert alert) {
    return Card(
      color: _getAlertBackgroundColor(alert.type),
      child: ListTile(
        leading: Icon(
          _getAlertIcon(alert.type),
          color: _getAlertColor(alert.type),
        ),
        title: Text(
          alert.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _getAlertColor(alert.type),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert.message),
            const SizedBox(height: 4),
            Text(
              _formatAlertTime(alert.timestamp),
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!alert.isAcknowledged)
              IconButton(
                onPressed: () {
                  _alertService.acknowledgeAlert(alert.id);
                  setState(() {});
                },
                icon: const Icon(Icons.check),
                tooltip: 'Acknowledge',
              ),
            IconButton(
              onPressed: () {
                _alertService.resolveAlert(alert.id);
                setState(() {});
              },
              icon: const Icon(Icons.close),
              tooltip: 'Resolve',
            ),
          ],
        ),
      ),
    );
  }

  void _resolveAllAlerts() {
    _alertService.clearAllAlerts();
    setState(() {});
  }

  Color _getAlertColor(AIAlertType type) {
    switch (type) {
      case AIAlertType.critical:
        return Colors.red;
      case AIAlertType.highRisk:
        return Colors.orange;
      case AIAlertType.mediumRisk:
        return Colors.amber;
      case AIAlertType.lowRisk:
        return Colors.blue;
    }
  }

  Color _getAlertBackgroundColor(AIAlertType type) {
    return _getAlertColor(type).withOpacity(0.1);
  }

  IconData _getAlertIcon(AIAlertType type) {
    switch (type) {
      case AIAlertType.critical:
        return Icons.emergency;
      case AIAlertType.highRisk:
        return Icons.warning;
      case AIAlertType.mediumRisk:
        return Icons.info;
      case AIAlertType.lowRisk:
        return Icons.notifications;
    }
  }

  Color _getWidgetBackgroundColor(List<AIAlert> alerts) {
    if (alerts.any((a) => a.type == AIAlertType.critical)) {
      return Colors.red.withOpacity(0.1);
    }
    if (alerts.any((a) => a.type == AIAlertType.highRisk)) {
      return Colors.orange.withOpacity(0.1);
    }
    return Colors.amber.withOpacity(0.05);
  }

  Color _getWidgetIconColor(List<AIAlert> alerts) {
    if (alerts.any((a) => a.type == AIAlertType.critical)) {
      return Colors.red;
    }
    if (alerts.any((a) => a.type == AIAlertType.highRisk)) {
      return Colors.orange;
    }
    return Colors.amber;
  }

  String _formatAlertTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

// Floating Alert Banner for Critical Alerts
class FloatingAlertBanner extends StatefulWidget {
  const FloatingAlertBanner({super.key});

  @override
  State<FloatingAlertBanner> createState() => _FloatingAlertBannerState();
}

class _FloatingAlertBannerState extends State<FloatingAlertBanner>
    with SingleTickerProviderStateMixin {
  final AIAlertService _alertService = AIAlertService();
  late AnimationController _animationController;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _alertService.onNewAlert = _checkForCriticalAlerts;
    _checkForCriticalAlerts(null); // Initial check
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _checkForCriticalAlerts(AIAlert? newAlert) {
    final hasCritical = _alertService.hasCriticalAlerts;

    if (hasCritical && !_isVisible) {
      _isVisible = true;
      _animationController.forward();
    } else if (!hasCritical && _isVisible) {
      _isVisible = false;
      _animationController.reverse();
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -100 * (1 - _animationController.value)),
          child: Opacity(
            opacity: _animationController.value,
            child: _isVisible ? _buildBanner() : const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.red,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            const Icon(Icons.emergency, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'CRITICAL SAFETY ALERT',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                // Show critical alerts dialog
                final criticalAlerts = _alertService.getAlertsByType(
                  AIAlertType.critical,
                );
                if (criticalAlerts.isNotEmpty) {
                  // Handle critical alert action
                }
              },
              child: const Text(
                'VIEW',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
