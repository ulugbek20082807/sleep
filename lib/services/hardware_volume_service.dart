import 'dart:async';
import 'dart:io';
import 'package:volume_controller/volume_controller.dart';
import '../core/sleep_engine_constants.dart';

class HardwareVolumeService {
  final VolumeController _controller = VolumeController.instance;

  /// Returns current system volume in range [0.0, 1.0].
  Future<double> getVolume() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return await _controller.getVolume();
      }
      return SleepEngineConstants.requiredHardwareVolumeFraction;
    } catch (_) {
      return SleepEngineConstants.requiredHardwareVolumeFraction;
    }
  }

  /// Sets system media volume to given value in range [0.0, 1.0].
  Future<void> setVolume(double volume) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        _controller.showSystemUI = false;
        await _controller.setVolume(volume.clamp(0.0, 1.0));
      }
    } catch (_) {}
  }

  /// Sets system media volume to target 70% fraction.
  Future<void> setTargetVolume() async {
    await setVolume(SleepEngineConstants.requiredHardwareVolumeFraction);
  }

  /// Checks if given volume is within the optimal [0.65, 0.75] window.
  bool isVolumeOptimal(double volume) {
    const double target = SleepEngineConstants.requiredHardwareVolumeFraction;
    const double tolerance = SleepEngineConstants.hardwareVolumeTolerance;
    return volume >= (target - tolerance) && volume <= (target + tolerance);
  }

  /// Listens to live volume adjustments.
  StreamSubscription<double>? listenToVolume(void Function(double volume) onVolume) {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return _controller.addListener(onVolume, fetchInitialVolume: true);
      }
    } catch (_) {}
    return null;
  }

  /// Cancels listening.
  Future<void> removeListener() async {
    try {
      await _controller.removeListener();
    } catch (_) {}
  }
}

