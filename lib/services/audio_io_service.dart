import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:record/record.dart' hide IosAudioCategory;
import '../core/sleep_core_engine.dart';
import '../core/sleep_engine_constants.dart';

bool get _isAudioTestEnv {
  try {
    final String binding = WidgetsBinding.instance.runtimeType.toString();
    return binding.contains('Test') ||
        Platform.environment.containsKey('FLUTTER_TEST');
  } catch (_) {
    return false;
  }
}

/// Clean interface for Audio Hardware I/O.
/// Allows Stage 2 (18–20 kHz FMCW ultrasonic sonar chest-breathing detection)
/// to be implemented without modifying any UI screens or BLoC state machines.
abstract class AudioHardwareService {
  Future<void> startSpeaker({
    required int sampleRate,
    required Float32List Function(int frameCount) onAudioRequest,
  });

  Future<void> stopSpeaker();

  Future<void> startMicrophone({
    required int sampleRate,
    required void Function(List<double> normalizedSamples) onSamples,
  });

  Future<void> stopMicrophone();

  Future<void> dispose();
}

/// Helper converting 16-bit little-endian PCM bytes to normalized doubles in [-1.0, 1.0].
List<double> convertPcm16BytesToNormalizedDoubles(Uint8List pcm16Bytes) {
  final ByteData byteData = ByteData.sublistView(pcm16Bytes);
  final int sampleCount = pcm16Bytes.lengthInBytes ~/ 2;
  final Float64List normalized = Float64List(sampleCount);
  for (int i = 0; i < sampleCount; i++) {
    final int int16Sample = byteData.getInt16(i * 2, Endian.little);
    normalized[i] = int16Sample / 32768.0;
  }
  return normalized;
}

class DefaultAudioHardwareService implements AudioHardwareService {
  static bool disableNativeAudioForTesting = false;

  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _micSubscription;

  bool _isSpeakerRunning = false;
  bool _isMicRunning = false;

  // Calibration tone support
  ProceduralSleepAudioSynthesizer? _calibrationSynthesizer;
  Timer? _calibrationTimer;
  double _calibrationGain = 0.008;

  @override
  Future<void> startSpeaker({
    required int sampleRate,
    required Float32List Function(int frameCount) onAudioRequest,
  }) async {
    if (_isSpeakerRunning) {
      await stopSpeaker();
    }
    _isSpeakerRunning = true;

    if (disableNativeAudioForTesting || _isAudioTestEnv) return;

    try {
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        await FlutterPcmSound.setup(
          sampleRate: sampleRate,
          channelCount: 1,
          iosAudioCategory: IosAudioCategory.playback,
          iosAllowBackgroundAudio: true,
        );
        await FlutterPcmSound.setFeedThreshold(4096);

        FlutterPcmSound.setFeedCallback((int remainingFrames) {
          if (!_isSpeakerRunning) return;
          const int chunkSize = 2048;
          final Float32List floatSamples = onAudioRequest(chunkSize);
          final Int16List int16 = Int16List(chunkSize);
          for (int i = 0; i < chunkSize; i++) {
            final double s = floatSamples[i].clamp(-1.0, 1.0);
            int16[i] = (s * 32767.0).round();
          }
          FlutterPcmSound.feed(PcmArrayInt16.fromList(int16));
        });

        // Pre-feed initial chunks so the native audio queue is primed
        for (int p = 0; p < 2; p++) {
          const int chunkSize = 2048;
          final Float32List floatSamples = onAudioRequest(chunkSize);
          final Int16List int16 = Int16List(chunkSize);
          for (int i = 0; i < chunkSize; i++) {
            final double s = floatSamples[i].clamp(-1.0, 1.0);
            int16[i] = (s * 32767.0).round();
          }
          await FlutterPcmSound.feed(PcmArrayInt16.fromList(int16));
        }

        FlutterPcmSound.start();
      }
    } catch (_) {
      // Graceful fallback for non-supported platforms or simulators
    }
  }

  @override
  Future<void> stopSpeaker() async {
    _isSpeakerRunning = false;
    if (disableNativeAudioForTesting || _isAudioTestEnv) return;
    try {
      FlutterPcmSound.setFeedCallback(null);
      await FlutterPcmSound.release();
    } catch (_) {}
  }

  @override
  Future<void> startMicrophone({
    required int sampleRate,
    required void Function(List<double> normalizedSamples) onSamples,
  }) async {
    if (_isMicRunning) return;
    _isMicRunning = true;
    if (disableNativeAudioForTesting || _isAudioTestEnv) return;

    try {
      _recorder = AudioRecorder();
      final hasPermission = await _recorder!.hasPermission();
      if (!hasPermission) {
        _isMicRunning = false;
        return;
      }

      final stream = await _recorder!.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
        ),
      );

      _micSubscription = stream.listen((Uint8List chunk) {
        if (!_isMicRunning) return;
        final normalized = convertPcm16BytesToNormalizedDoubles(chunk);
        onSamples(normalized);
      });
    } catch (_) {
      _isMicRunning = false;
    }
  }

  @override
  Future<void> stopMicrophone() async {
    _isMicRunning = false;
    if (_isAudioTestEnv) return;
    try {
      await _micSubscription?.cancel();
      _micSubscription = null;
      await _recorder?.stop();
      await _recorder?.dispose();
      _recorder = null;
    } catch (_) {}
  }

  /// Starts continuous pink noise test tone for the 30 dBA Speaker Calibration Card.
  Future<void> startCalibrationTone({
    required double digitalGain,
    int sampleRate = SleepEngineConstants.defaultSpeakerSampleRateHz,
  }) async {
    _calibrationGain = digitalGain;
    _calibrationSynthesizer =
        ProceduralSleepAudioSynthesizer(sampleRateHz: sampleRate);

    await startSpeaker(
      sampleRate: sampleRate,
      onAudioRequest: (frameCount) {
        if (_calibrationSynthesizer == null) {
          return Float32List(frameCount);
        }
        return _calibrationSynthesizer!.synthesizePcmBuffer(
          frameCount,
          SoundSynthesisRecipe(
            targetVolumeDba: 30.0,
            digitalLinearGain: _calibrationGain,
            spectralSlopeBeta: 1.0,
            lowPassCutoffHz: 800.0,
            highPassCutoffHz: SleepEngineConstants.defaultHighPassCutoffHz,
            modulationFreqHz: 0.0,
            modulationDepthDb: 0.0,
            enable50msN3Pulses: false,
          ),
        );
      },
    );
  }

  void updateCalibrationGain(double newGain) {
    _calibrationGain = newGain;
  }

  Future<void> stopCalibrationTone() async {
    _calibrationTimer?.cancel();
    _calibrationTimer = null;
    _calibrationSynthesizer = null;
    await stopSpeaker();
  }

  @override
  Future<void> dispose() async {
    await stopCalibrationTone();
    await stopSpeaker();
    await stopMicrophone();
  }
}
