import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/hardware_volume_service.dart';
import '../../services/permission_gatekeeper_service.dart';

class PreFlightPermissionDialogs {
  /// Step 2.1: Battery Optimization Dialog
  static Future<bool> showBatteryOptimizationDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.battery_alert, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Background Sleep Tracking',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: const Text(
            'To prevent Android from terminating sleep tracking and audio synthesis during the night, please allow uninterrupted background activity:\n\n'
            '1. Tap "Open App Settings" below.\n'
            '2. Select "Battery".\n'
            '3. Choose "Unrestricted".',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              onPressed: () async {
                final isIgnored =
                    await PermissionGatekeeperService.isBatteryOptimizationIgnored();
                if (isIgnored && ctx.mounted) {
                  Navigator.of(ctx).pop(true);
                } else {
                  await PermissionGatekeeperService.requestBatteryOptimizationExemption();
                  final recheck =
                      await PermissionGatekeeperService.isBatteryOptimizationIgnored();
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop(recheck);
                  }
                }
              },
              child: const Text('Retry Check'),
            ),
            FilledButton(
              onPressed: () async {
                await PermissionGatekeeperService.openSettings();
              },
              child: const Text('Open App Settings'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  /// Step 2.2: Microphone Access Required Dialog
  static Future<bool> showMicrophoneRequiredDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          icon: const Icon(Icons.mic_off, size: 36),
          title: const Text('Microphone Access Required'),
          content: const Text(
            'Analysis Mode listens for high-frequency bedsheet rustling to detect your natural sleep cycle boundaries.\n\n'
            'Please grant Microphone access or disable Analysis Mode to proceed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final granted =
                    await PermissionGatekeeperService.requestMicrophonePermission();
                if (ctx.mounted) {
                  Navigator.of(ctx).pop(granted);
                }
              },
              child: const Text('Grant Access'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  /// Step 2.3: Reactive 70% Hardware Speaker Volume Check (Auto-Proceed)
  static Future<bool> showReactiveVolumeDialog(
    BuildContext context,
    HardwareVolumeService volumeService, {
    bool forcePrompt = false,
  }) async {
    final double initialVol = await volumeService.getVolume();
    if (!forcePrompt && volumeService.isVolumeOptimal(initialVol)) {
      return true;
    }

    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return _ReactiveVolumeDialogWidget(
          volumeService: volumeService,
          forcePrompt: forcePrompt,
        );
      },
    );
    return result ?? false;
  }
}

class _ReactiveVolumeDialogWidget extends StatefulWidget {
  final HardwareVolumeService volumeService;
  final bool forcePrompt;

  const _ReactiveVolumeDialogWidget({
    required this.volumeService,
    this.forcePrompt = false,
  });

  @override
  State<_ReactiveVolumeDialogWidget> createState() =>
      _ReactiveVolumeDialogWidgetState();
}

class _ReactiveVolumeDialogWidgetState
    extends State<_ReactiveVolumeDialogWidget> {
  double _currentVolume = 0.5;
  StreamSubscription<double>? _sub;
  bool _dismissed = false;
  Timer? _autoProceedTimer;

  @override
  void initState() {
    super.initState();
    _initVolume();
  }

  Future<void> _initVolume() async {
    final vol = await widget.volumeService.getVolume();
    if (mounted && !_dismissed) {
      setState(() => _currentVolume = vol);
      if (!widget.forcePrompt) {
        _checkAutoProceed(vol);
      }
    }

    _sub = widget.volumeService.listenToVolume((newVol) {
      if (!mounted || _dismissed) return;
      setState(() => _currentVolume = newVol);
      _checkAutoProceed(newVol);
    });
  }

  void _checkAutoProceed(double vol) {
    if (_dismissed) return;
    if (widget.volumeService.isVolumeOptimal(vol)) {
      _autoProceedTimer?.cancel();
      _autoProceedTimer = Timer(const Duration(milliseconds: 350), () {
        if (mounted && !_dismissed) {
          _dismiss(true);
        }
      });
    }
  }

  void _dismiss(bool result) {
    if (_dismissed) return;
    _dismissed = true;
    _autoProceedTimer?.cancel();
    _autoProceedTimer = null;
    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  void dispose() {
    _autoProceedTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOptimal = widget.volumeService.isVolumeOptimal(_currentVolume);

    return AlertDialog(
      icon: Icon(
        isOptimal ? Icons.volume_up : Icons.volume_down,
        size: 36,
        color: isOptimal ? Colors.green.shade600 : theme.colorScheme.primary,
      ),
      title: const Text('Adjust Media Volume to 70%'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'For scientifically calibrated decibel levels (30–44 dBA), your phone or device media volume must be set to 70% (±5%).\n\n'
            'Adjust using your volume buttons, slider below, or tap automatic setup.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Current: ${(_currentVolume * 100).round()}%'),
              Text(
                'Target: 70%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isOptimal ? Colors.green.shade600 : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _currentVolume.clamp(0.0, 1.0),
              minHeight: 12,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOptimal ? Colors.green.shade600 : theme.colorScheme.primary,
              ),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          Slider(
            value: _currentVolume.clamp(0.0, 1.0),
            min: 0.0,
            max: 1.0,
            divisions: 20,
            onChanged: (val) async {
              setState(() => _currentVolume = val);
              await widget.volumeService.setVolume(val);
              _checkAutoProceed(val);
            },
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Set to 70% Automatically'),
            onPressed: () async {
              await widget.volumeService.setTargetVolume();
              final v = await widget.volumeService.getVolume();
              if (mounted && !_dismissed) {
                setState(() => _currentVolume = v);
                _checkAutoProceed(v);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _dismiss(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => _dismiss(true),
          child: const Text('Confirm 70% Volume'),
        ),
      ],
    );
  }
}
