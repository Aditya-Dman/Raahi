import 'dart:async';
import 'dart:math';

class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  // Stream controllers for real-time data
  final StreamController<HealthData> _healthDataController = StreamController.broadcast();
  final StreamController<ActivityData> _activityDataController = StreamController.broadcast();
  
  Stream<HealthData> get healthDataStream => _healthDataController.stream;
  Stream<ActivityData> get activityDataStream => _activityDataController.stream;

  Timer? _healthTimer;
  Timer? _activityTimer;

  HealthData _currentHealthData = HealthData(
    heartRate: 72,
    bloodOxygen: 98,
    bodyTemperature: 98.6,
    stressLevel: 'Low',
  );

  ActivityData _currentActivityData = ActivityData(
    steps: 8432,
    stepGoal: 10000,
    calories: 320,
    calorieGoal: 450,
    distance: 6.2,
    distanceGoal: 8.0,
    sleepDuration: Duration(hours: 7, minutes: 32),
    sleepQuality: 4,
  );

  void startHealthMonitoring() {
    _healthTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateHealthData();
    });

    _activityTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _updateActivityData();
    });
  }

  void stopHealthMonitoring() {
    _healthTimer?.cancel();
    _activityTimer?.cancel();
  }

  void _updateHealthData() {
    final random = Random();
    
    // Simulate realistic health data variations
    _currentHealthData = HealthData(
      heartRate: _currentHealthData.heartRate + (random.nextDouble() - 0.5) * 4,
      bloodOxygen: (_currentHealthData.bloodOxygen + (random.nextDouble() - 0.5) * 2)
          .clamp(95.0, 100.0),
      bodyTemperature: _currentHealthData.bodyTemperature + (random.nextDouble() - 0.5) * 0.5,
      stressLevel: _getStressLevel(_currentHealthData.heartRate),
    );

    _healthDataController.add(_currentHealthData);
  }

  void _updateActivityData() {
    final random = Random();
    
    // Simulate activity progress throughout the day
    _currentActivityData = ActivityData(
      steps: (_currentActivityData.steps + random.nextInt(200)).clamp(0, 15000),
      stepGoal: _currentActivityData.stepGoal,
      calories: (_currentActivityData.calories + random.nextInt(20)).clamp(0, 800),
      calorieGoal: _currentActivityData.calorieGoal,
      distance: _currentActivityData.distance + (random.nextDouble() * 0.2),
      distanceGoal: _currentActivityData.distanceGoal,
      sleepDuration: _currentActivityData.sleepDuration,
      sleepQuality: _currentActivityData.sleepQuality,
    );

    _activityDataController.add(_currentActivityData);
  }

  String _getStressLevel(double heartRate) {
    if (heartRate > 90) return 'High';
    if (heartRate > 80) return 'Medium';
    return 'Low';
  }

  // Get current data
  HealthData getCurrentHealthData() => _currentHealthData;
  ActivityData getCurrentActivityData() => _currentActivityData;

  // Device management
  List<ConnectedDevice> getConnectedDevices() {
    return [
      ConnectedDevice(
        id: '1',
        name: 'Apple Watch Series 9',
        type: DeviceType.smartWatch,
        isConnected: true,
        batteryLevel: 85,
        lastSync: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      ConnectedDevice(
        id: '2',
        name: 'Fitbit Charge 5',
        type: DeviceType.fitnessTracker,
        isConnected: true,
        batteryLevel: 62,
        lastSync: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
      ConnectedDevice(
        id: '3',
        name: 'Samsung Galaxy Watch',
        type: DeviceType.healthMonitor,
        isConnected: false,
        batteryLevel: 0,
        lastSync: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];
  }

  // Health alerts
  List<HealthAlert> getHealthAlerts() {
    return [
      HealthAlert(
        id: '1',
        title: 'Heart Rate Alert',
        message: 'Heart rate elevated during rest (${_currentHealthData.heartRate.round()} BPM)',
        severity: _currentHealthData.heartRate > 90 ? AlertSeverity.high : AlertSeverity.medium,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        icon: 'heart',
      ),
      HealthAlert(
        id: '2',
        title: 'Hydration Reminder',
        message: 'Remember to drink water - Goal: 2L/day',
        severity: AlertSeverity.low,
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        icon: 'water',
      ),
      if (_currentHealthData.heartRate > 100)
        HealthAlert(
          id: '3',
          title: 'Emergency Alert',
          message: 'Abnormal heart rate detected - Emergency contacts notified',
          severity: AlertSeverity.high,
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          icon: 'warning',
        ),
    ];
  }

  void dispose() {
    _healthTimer?.cancel();
    _activityTimer?.cancel();
    _healthDataController.close();
    _activityDataController.close();
  }
}

// Data models
class HealthData {
  final double heartRate;
  final double bloodOxygen;
  final double bodyTemperature;
  final String stressLevel;

  HealthData({
    required this.heartRate,
    required this.bloodOxygen,
    required this.bodyTemperature,
    required this.stressLevel,
  });

  String get heartRateStatus {
    if (heartRate < 60) return 'Low';
    if (heartRate > 100) return 'High';
    return 'Normal';
  }

  String get bloodOxygenStatus {
    if (bloodOxygen < 95) return 'Low';
    if (bloodOxygen >= 98) return 'Excellent';
    return 'Good';
  }

  String get temperatureStatus {
    if (bodyTemperature < 97.0 || bodyTemperature > 99.5) return 'Abnormal';
    return 'Normal';
  }
}

class ActivityData {
  final int steps;
  final int stepGoal;
  final int calories;
  final int calorieGoal;
  final double distance;
  final double distanceGoal;
  final Duration sleepDuration;
  final int sleepQuality; // 1-5 stars

  ActivityData({
    required this.steps,
    required this.stepGoal,
    required this.calories,
    required this.calorieGoal,
    required this.distance,
    required this.distanceGoal,
    required this.sleepDuration,
    required this.sleepQuality,
  });

  double get stepProgress => steps / stepGoal;
  double get calorieProgress => calories / calorieGoal;
  double get distanceProgress => distance / distanceGoal;

  String get sleepDurationText {
    final hours = sleepDuration.inHours;
    final minutes = sleepDuration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  String get sleepQualityText {
    switch (sleepQuality) {
      case 5: return 'Excellent';
      case 4: return 'Good';
      case 3: return 'Fair';
      case 2: return 'Poor';
      default: return 'Very Poor';
    }
  }
}

class ConnectedDevice {
  final String id;
  final String name;
  final DeviceType type;
  final bool isConnected;
  final int batteryLevel;
  final DateTime lastSync;

  ConnectedDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.isConnected,
    required this.batteryLevel,
    required this.lastSync,
  });

  String get typeString {
    switch (type) {
      case DeviceType.smartWatch: return 'Smart Watch';
      case DeviceType.fitnessTracker: return 'Fitness Tracker';
      case DeviceType.healthMonitor: return 'Health Monitor';
    }
  }
}

enum DeviceType {
  smartWatch,
  fitnessTracker,
  healthMonitor,
}

class HealthAlert {
  final String id;
  final String title;
  final String message;
  final AlertSeverity severity;
  final DateTime timestamp;
  final String icon;

  HealthAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.timestamp,
    required this.icon,
  });

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} min ago';
    } else {
      return 'Just now';
    }
  }
}

enum AlertSeverity {
  low,
  medium,
  high,
}