import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dashboard_data_provider.dart';

// Widget to display AI behavior insights and anomaly detection
class BehaviorInsightsWidget extends StatelessWidget {
  const BehaviorInsightsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardDataProvider>(
      builder: (context, provider, child) {
        return Card(
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.psychology_outlined,
                      color: _getAnomalyRiskColor(provider.anomalyRisk),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'AI Behavior Analysis',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (provider.isBehaviorTracking)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Current Status Row
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Current Activity',
                        _formatActivity(provider.currentActivity),
                        _getActivityIcon(provider.currentActivity),
                        _getActivityColor(provider.currentActivity),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricCard(
                        'Stress Level',
                        provider.stressLevelFormatted,
                        Icons.favorite_border,
                        _getStressColor(provider.stressLevel),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Anomaly Risk Indicator
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getAnomalyRiskColor(
                      provider.anomalyRisk,
                    ).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getAnomalyRiskColor(
                        provider.anomalyRisk,
                      ).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Anomaly Risk',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getAnomalyRiskColor(provider.anomalyRisk),
                            ),
                          ),
                          Text(
                            provider.anomalyRiskFormatted,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _getAnomalyRiskColor(provider.anomalyRisk),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: provider.anomalyRisk / 100,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getAnomalyRiskColor(provider.anomalyRisk),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getAnomalyRiskDescription(provider.anomalyRisk),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Safety Recommendations
                if (provider.isHighRiskSituation()) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.warning_amber,
                              color: Colors.orange,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Safety Recommendations',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...provider
                            .getSafetyRecommendations()
                            .take(2)
                            .map(
                              (rec) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Text(
                                  '• $rec',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showDetailedAnalytics(context, provider),
                        icon: const Icon(Icons.analytics_outlined, size: 16),
                        label: const Text('View Analytics'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showStressLevelDialog(context, provider),
                        icon: const Icon(Icons.tune, size: 16),
                        label: const Text('Update Stress'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
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

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  String _formatActivity(String activity) {
    switch (activity) {
      case 'tourist_activity':
        return 'Touring';
      case 'stationary':
        return 'Stationary';
      case 'walking':
        return 'Walking';
      case 'running':
        return 'Running';
      case 'vehicle':
        return 'In Vehicle';
      default:
        return 'Unknown';
    }
  }

  IconData _getActivityIcon(String activity) {
    switch (activity) {
      case 'tourist_activity':
        return Icons.camera_alt_outlined;
      case 'stationary':
        return Icons.pause_circle_outline;
      case 'walking':
        return Icons.directions_walk;
      case 'running':
        return Icons.directions_run;
      case 'vehicle':
        return Icons.directions_car;
      default:
        return Icons.help_outline;
    }
  }

  Color _getActivityColor(String activity) {
    switch (activity) {
      case 'tourist_activity':
        return Colors.blue;
      case 'stationary':
        return Colors.grey;
      case 'walking':
        return Colors.green;
      case 'running':
        return Colors.orange;
      case 'vehicle':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getStressColor(double stress) {
    if (stress < 3.0) return Colors.green;
    if (stress < 6.0) return Colors.yellow.shade700;
    if (stress < 8.0) return Colors.orange;
    return Colors.red;
  }

  Color _getAnomalyRiskColor(double risk) {
    if (risk < 20.0) return Colors.green;
    if (risk < 50.0) return Colors.yellow.shade700;
    if (risk < 80.0) return Colors.orange;
    return Colors.red;
  }

  String _getAnomalyRiskDescription(double risk) {
    if (risk < 20.0) return 'Normal behavior patterns detected';
    if (risk < 50.0) return 'Minor behavioral variations observed';
    if (risk < 80.0) return 'Unusual behavior patterns detected';
    return 'Significant anomalies requiring attention';
  }

  void _showDetailedAnalytics(
    BuildContext context,
    DashboardDataProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxHeight: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Detailed Behavior Analytics',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAnalyticsSection(
                        'Recent Anomalies',
                        provider
                            .getRecentAnomalies()
                            .map((a) => '${a.anomalyType}: ${a.description}')
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      _buildAnalyticsSection(
                        'Safety Recommendations',
                        provider.getSafetyRecommendations(),
                      ),
                      const SizedBox(height: 16),
                      _buildBehaviorSummary(provider.getBehaviorAnalytics()),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        provider.resetBehaviorData();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Reset Data'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
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

  Widget _buildAnalyticsSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text(
            'No data available',
            style: TextStyle(color: Colors.grey.shade600),
          )
        else
          ...items
              .take(5)
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('• $item', style: const TextStyle(fontSize: 12)),
                ),
              ),
      ],
    );
  }

  Widget _buildBehaviorSummary(Map<String, dynamic> analytics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Behavior Summary',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text('Total Patterns: ${analytics['totalPatterns'] ?? 0}'),
        Text(
          'Learning Mode: ${analytics['isLearning'] == true ? 'Active' : 'Completed'}',
        ),
        Text(
          'Baseline Established: ${analytics['hasBaseline'] == true ? 'Yes' : 'No'}',
        ),
        if (analytics['analytics'] != null) ...[
          Text(
            'Current Risk: ${(analytics['analytics']['currentRisk'] ?? 0).toStringAsFixed(1)}%',
          ),
          Text(
            'Learning Progress: ${((analytics['analytics']['learningProgress'] ?? 0) * 100).toStringAsFixed(0)}%',
          ),
        ],
      ],
    );
  }

  void _showStressLevelDialog(
    BuildContext context,
    DashboardDataProvider provider,
  ) {
    double currentStress = provider.stressLevel;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Update Stress Level'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Current stress level: ${currentStress.toStringAsFixed(1)}/10',
              ),
              const SizedBox(height: 16),
              Slider(
                value: currentStress,
                min: 1.0,
                max: 10.0,
                divisions: 90,
                label: currentStress.toStringAsFixed(1),
                onChanged: (value) {
                  setState(() {
                    currentStress = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              Text(
                _getStressDescription(currentStress),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                provider.updateStressLevel(currentStress);
                Navigator.of(context).pop();
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  String _getStressDescription(double stress) {
    if (stress < 2.0) return 'Very relaxed and calm';
    if (stress < 4.0) return 'Relaxed and comfortable';
    if (stress < 6.0) return 'Normal stress levels';
    if (stress < 8.0) return 'Elevated stress levels';
    if (stress < 9.0) return 'High stress - consider relaxation';
    return 'Very high stress - immediate attention needed';
  }
}
