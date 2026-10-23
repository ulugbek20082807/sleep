import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/sleep_engine_constants.dart';
import '../../services/audio_io_service.dart';
import '../../services/hardware_volume_service.dart';
import '../../services/permission_gatekeeper_service.dart';
import 'pre_flight_permission_dialogs.dart';

class SoundCalibrationCard extends StatefulWidget {
  final double initialGain;
  final ValueChanged<double> onGainChanged;
  final AudioHardwareService? audioService;
  final HardwareVolumeService? volumeService;
  final String? customSubtitle;

  const SoundCalibrationCard({
    super.key,
    required this.initialGain,
    required this.onGainChanged,
    this.audioService,
    this.volumeService,
    this.customSubtitle,
  });

  @override
  State<SoundCalibrationCard> createState() => _SoundCalibrationCardState();
}

class _SoundCalibrationCardState extends State<SoundCalibrationCard> {
  late double _calibrationGain;
  bool _isCalibrating = false;
  bool _isMicAnalyzing = false;
  double _roomNoiseDba = 28.0;
  double _micInstantDba = 28.0;

  late final AudioHardwareService _audioService;
  late final HardwareVolumeService _volumeService;
  bool _ownsAudioService = false;

  @override
  void initState() {
    super.initState();
    _calibrationGain = widget.initialGain;
    if (widget.audioService != null) {
      _audioService = widget.audioService!;
    } else {
      _audioService = DefaultAudioHardwareService();
      _ownsAudioService = true;
    }
    _volumeService = widget.volumeService ?? HardwareVolumeService();
  }

  @override
  void didUpdateWidget(covariant SoundCalibrationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialGain != widget.initialGain && !_isCalibrating) {
      _calibrationGain = widget.initialGain;
    }
  }

  @override
  void dispose() {
    if (_isCalibrating) {
      _audioService.stopCalibrationTone();
    }
    if (_isMicAnalyzing) {
      _audioService.stopMicrophone();
    }
    if (_ownsAudioService) {
      _audioService.dispose();
    }
    super.dispose();
  }

  double _gainToApproxDba(double gain) {
    if (gain <= 0.0001) return 20.0;
    // 0.008 digital gain corresponds to baseline 30 dBA
    return 30.0 + 20.0 * (log(gain / 0.008) / ln10);
  }

  Future<void> _toggleCalibration() async {
    if (_isCalibrating) {
      await _audioService.stopCalibrationTone();
      if (mounted) setState(() => _isCalibrating = false);
    } else {
      // Step 1: Pre-test 70% volume check (unless in testing mode)
      if (!DefaultAudioHardwareService.disableNativeAudioForTesting) {
        final currentVol = await _volumeService.getVolume();
        if (!_volumeService.isVolumeOptimal(currentVol) && mounted) {
          final proceed =
              await PreFlightPermissionDialogs.showReactiveVolumeDialog(
            context,
            _volumeService,
            forcePrompt: true,
          );
          if (!proceed || !mounted) return;
        }
      }

      await _audioService.startCalibrationTone(digitalGain: _calibrationGain);
      if (mounted) setState(() => _isCalibrating = true);
    }
  }

  Future<void> _toggleMicAnalysis() async {
    if (_isMicAnalyzing) {
      await _audioService.stopMicrophone();
      if (mounted) setState(() => _isMicAnalyzing = false);
    } else {
      final granted =
          await PermissionGatekeeperService.requestMicrophonePermission();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Microphone permission is required for room acoustic feedback.')),
        );
        return;
      }

      await _audioService.startMicrophone(
        sampleRate: SleepEngineConstants.defaultMicSampleRateHz,
        onSamples: (samples) {
          if (samples.isEmpty) return;
          double sumSquares = 0.0;
          for (final s in samples) {
            sumSquares += s * s;
          }
          final rms = sqrt(sumSquares / samples.length);
          final dbfs = 20.0 * (log(max(1e-5, rms)) / ln10);
          final estimatedDba = (dbfs + 94.0).clamp(18.0, 95.0);

          if (mounted) {
            setState(() {
              _micInstantDba = estimatedDba;
              _roomNoiseDba = _roomNoiseDba * 0.85 + estimatedDba * 0.15;
            });
          }
        },
      );
      if (mounted) setState(() => _isMicAnalyzing = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final approxDba = _gainToApproxDba(_calibrationGain);
    final dbaDelta = (approxDba - _roomNoiseDba);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row with Icon Badge & Priority Tag
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.tune,
                    color: theme.colorScheme.onPrimary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Quiet-Room 30 dBA Calibration',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: const Text('Essential'),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Explanatory Text
            Text(
              widget.customSubtitle ??
                  'Calibrates your speaker baseline so acoustic masking (30–44 dBA) is gentle and never too loud.\n'
                  'Ensure device volume is set to 70%, then adjust until barely audible from your pillow.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
            ),
            const SizedBox(height: 12),

            // Action Buttons and Live Readouts
            Row(
              children: [
                FilledButton.tonalIcon(
                  icon: Icon(_isCalibrating ? Icons.stop : Icons.volume_up),
                  label: Text(_isCalibrating
                      ? 'Stop Test'
                      : 'Test Calibration Tone'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: _isCalibrating
                        ? theme.colorScheme.errorContainer
                        : null,
                    foregroundColor: _isCalibrating
                        ? theme.colorScheme.onErrorContainer
                        : null,
                  ),
                  onPressed: _toggleCalibration,
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Gain: ${_calibrationGain.toStringAsFixed(4)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '~${approxDba.toStringAsFixed(1)} dBA Target',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Gain Slider
            Slider(
              value: _calibrationGain.clamp(0.0001, 0.25),
              min: 0.0001,
              max: 0.25,
              divisions: 250,
              onChanged: (val) {
                setState(() => _calibrationGain = val);
                widget.onGainChanged(val);
                if (_isCalibrating) {
                  _audioService.updateCalibrationGain(val);
                }
              },
            ),

            // Slider Range Descriptions
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Whisper (~30 dBA)', style: TextStyle(fontSize: 11)),
                  Text('Soft (~36 dBA)', style: TextStyle(fontSize: 11)),
                  Text('Ambient (~42 dBA)', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Mic Room Noise Analyzer Tool
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _isMicAnalyzing ? Icons.mic : Icons.mic_none,
                        size: 18,
                        color: _isMicAnalyzing
                            ? Colors.green.shade600
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Room Acoustic Check',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: Icon(
                          _isMicAnalyzing ? Icons.stop : Icons.play_arrow,
                          size: 14,
                        ),
                        label: Text(
                          _isMicAnalyzing ? 'Stop' : 'Check Mic',
                          style: const TextStyle(fontSize: 11),
                        ),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: _toggleMicAnalysis,
                      ),
                    ],
                  ),
                  if (_isMicAnalyzing) ...[
                    const Divider(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Noise Floor',
                                style: theme.textTheme.labelSmall),
                            Text(
                              '${_roomNoiseDba.toStringAsFixed(1)} dBA',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: _roomNoiseDba < 36.0
                                    ? Colors.green.shade700
                                    : Colors.amber.shade800,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('Mic Live', style: theme.textTheme.labelSmall),
                            Text(
                              '${_micInstantDba.toStringAsFixed(1)} dBA',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Signal/Floor',
                                style: theme.textTheme.labelSmall),
                            Text(
                              '${dbaDelta >= 0 ? "+" : ""}${dbaDelta.toStringAsFixed(1)} dB',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _roomNoiseDba < 36.0
                          ? '✓ Room quiet, ideal for calibrating 30 dBA'
                          : '⚠️ Room noise detected; calibrate closer to pillow',
                      style: TextStyle(
                        fontSize: 10,
                        color: _roomNoiseDba < 36.0
                            ? Colors.green.shade800
                            : Colors.amber.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
