import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class InitialPermissionsResult {
  final bool notificationGranted;
  final bool microphoneGranted;
  final bool batteryOptimizationIgnored;

  const InitialPermissionsResult({
    required this.notificationGranted,
    required this.microphoneGranted,
    required this.batteryOptimizationIgnored,
  });
}

class PermissionGatekeeperService {
  /// Phase 1: First App Launch Onboarding Gatekeeper.
  /// Requests notification, microphone, and battery optimization exemption.
  static Future<InitialPermissionsResult> requestInitialPermissions() async {
    bool notifGranted = true;
    bool micGranted = true;
    bool batteryIgnored = true;

    try {
      if (Platform.isAndroid) {
        // 1. Notification permission (Android 13+)
        final notifStatus = await Permission.notification.request();
        notifGranted = notifStatus.isGranted;

        // 2. Microphone permission
        final micStatus = await Permission.microphone.request();
        micGranted = micStatus.isGranted;

        // 3. Ignore Battery Optimizations
        final batteryStatus =
            await Permission.ignoreBatteryOptimizations.request();
        batteryIgnored = batteryStatus.isGranted;
      } else if (Platform.isIOS || Platform.isMacOS) {
        final notifStatus = await Permission.notification.request();
        notifGranted = notifStatus.isGranted;
        final micStatus = await Permission.microphone.request();
        micGranted = micStatus.isGranted;
      }
    } catch (_) {}

    return InitialPermissionsResult(
      notificationGranted: notifGranted,
      microphoneGranted: micGranted,
      batteryOptimizationIgnored: batteryIgnored,
    );
  }

  /// Checks if battery optimizations are currently ignored.
  static Future<bool> isBatteryOptimizationIgnored() async {
    if (!Platform.isAndroid) return true;
    try {
      return await Permission.ignoreBatteryOptimizations.isGranted;
    } catch (_) {
      return true;
    }
  }

  /// Requests battery optimization exemption.
  static Future<bool> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return true;
    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      return status.isGranted;
    } catch (_) {
      return true;
    }
  }

  /// Checks if microphone permission is granted.
  static Future<bool> isMicrophoneGranted() async {
    if (Platform.isWindows || Platform.isLinux) return true;
    try {
      return await Permission.microphone.isGranted;
    } catch (_) {
      return true;
    }
  }

  /// Requests microphone permission.
  static Future<bool> requestMicrophonePermission() async {
    if (Platform.isWindows || Platform.isLinux) return true;
    try {
      final status = await Permission.microphone.request();
      return status.isGranted;
    } catch (_) {
      return true;
    }
  }

  /// Checks notification permission.
  static Future<bool> isNotificationGranted() async {
    if (Platform.isWindows || Platform.isLinux) return true;
    try {
      return await Permission.notification.isGranted;
    } catch (_) {
      return true;
    }
  }

  /// Requests notification permission.
  static Future<bool> requestNotificationPermission() async {
    if (Platform.isWindows || Platform.isLinux) return true;
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (_) {
      return true;
    }
  }

  /// Opens application settings.
  static Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } catch (_) {
      return false;
    }
  }
}

