import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Clean interface for background execution and notification updates.
abstract class BackgroundExecutionService {
  Future<void> init();
  Future<void> startBackgroundSession({
    required String title,
    required String text,
  });
  Future<void> updateNotification({
    required String title,
    required String text,
  });
  Future<void> stopBackgroundSession();
}

class FlutterForegroundTaskBackgroundService
    implements BackgroundExecutionService {
  bool _initialized = false;

  @override
  Future<void> init() async {
    if (_initialized) return;

    if (!Platform.isAndroid && !Platform.isIOS) {
      _initialized = true;
      return;
    }

    try {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'sleep_perfecter_foreground_service',
          channelName: 'Sleep Perfecter Tracking Service',
          channelDescription:
              'Keeps sleep acoustics and cycle tracking running reliably overnight.',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.nothing(),
          autoRunOnBoot: false,
          autoRunOnMyPackageReplaced: false,
          allowWakeLock: true,
          allowWifiLock: false,
        ),
      );
      _initialized = true;
    } catch (_) {
      _initialized = true;
    }
  }

  @override
  Future<void> startBackgroundSession({
    required String title,
    required String text,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      await init();
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
        );
        return;
      }

      await FlutterForegroundTask.startService(
        serviceTypes: [
          ForegroundServiceTypes.mediaPlayback,
          ForegroundServiceTypes.microphone,
        ],
        notificationTitle: title,
        notificationText: text,
      );
    } catch (_) {}
  }

  @override
  Future<void> updateNotification({
    required String title,
    required String text,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
        );
      }
    } catch (_) {}
  }

  @override
  Future<void> stopBackgroundSession() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {}
  }
}

