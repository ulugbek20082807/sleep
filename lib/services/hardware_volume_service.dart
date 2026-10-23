import 'dart:async';
import 'dart:io';
import 'package:volume_controller/volume_controller.dart';
import '../core/sleep_engine_constants.dart';

class HardwareVolumeService {
  final VolumeController _controller = VolumeController.instance;
  static double _fallbackVolume = SleepEngineConstants.requiredHardwareVolumeFraction;
  StreamController<double>? _volumeStreamController;

  /// Returns current system volume in range [0.0, 1.0].
  Future<double> getVolume() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return await _controller.getVolume();
      } else if (Platform.isMacOS) {
        final result = await Process.run('osascript', ['-e', 'output volume of (get volume settings)']);
        if (result.exitCode == 0) {
          final intVal = int.tryParse(result.stdout.toString().trim());
          if (intVal != null) {
            _fallbackVolume = intVal / 100.0;
            return _fallbackVolume;
          }
        }
      }
      return _fallbackVolume;
    } catch (_) {
      return _fallbackVolume;
    }
  }

  /// Sets system media volume to given value in range [0.0, 1.0].
  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    _fallbackVolume = clamped;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        _controller.showSystemUI = false;
        await _controller.setVolume(clamped);
      } else if (Platform.isMacOS) {
        final intVal = (clamped * 100).round();
        await Process.run('osascript', ['-e', 'set volume output volume $intVal']);
      }
    } catch (_) {}
    _volumeStreamController?.add(_fallbackVolume);
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
    _volumeStreamController ??= StreamController<double>.broadcast();
    return _volumeStreamController!.stream.listen(onVolume);
  }

  /// Cancels listening.
  Future<void> removeListener() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await _controller.removeListener();
      }
    } catch (_) {}
    await _volumeStreamController?.close();
    _volumeStreamController = null;
  }
}
