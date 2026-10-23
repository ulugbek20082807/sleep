import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/sleep_core_engine.dart';
import '../../core/sleep_engine_constants.dart';
import '../../data/models/app_user_profile_meta.dart';
import '../../logic/profile_bloc/profile_bloc.dart';
import '../../logic/profile_bloc/profile_event.dart';
import '../../logic/profile_bloc/profile_state.dart';
import '../../services/audio_io_service.dart';
import '../../services/hardware_volume_service.dart';
import '../widgets/profile_avatar_menu_button.dart';
import '../widgets/sound_calibration_card.dart';
import 'main_shell_screen.dart';

class CreateEditProfileScreen extends StatefulWidget {
  final bool isFirstProfile;
  final AppUserProfileMeta? existingMeta;
  final UserProfileModel? existingProfile;

  const CreateEditProfileScreen({
    super.key,
    this.isFirstProfile = false,
    this.existingMeta,
    this.existingProfile,
  });

  @override
  State<CreateEditProfileScreen> createState() =>
      _CreateEditProfileScreenState();
}

class _CreateEditProfileScreenState extends State<CreateEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _ageController;

  String? _avatarPath;
  double _heightCm = 175.0;
  double _weightKg = 70.0;
  int _ageYears = 20;
  BiologicalSex _sex = BiologicalSex.otherOrUnspecified;

  TimeOfDay? _habitualBedtime = const TimeOfDay(hour: 23, minute: 30);
  bool _bedtimeUnknown = false;

  TimeOfDay? _habitualWakeTime = const TimeOfDay(hour: 7, minute: 30);
  bool _wakeTimeUnknown = false;

  SurveySleepLatencyOption _latency = SurveySleepLatencyOption.unknown;
  SurveyNoiseSensitivityOption _sensitivity =
      SurveyNoiseSensitivityOption.unknown;
  SurveyCycleRhythmOption _cycleRhythm = SurveyCycleRhythmOption.unknown;

  // Speaker Calibration State
  double _calibrationGain = 0.008;
  bool _isSubmitting = false;
  final DefaultAudioHardwareService _audioService =
      DefaultAudioHardwareService();
  final HardwareVolumeService _volumeService = HardwareVolumeService();

  @override
  void initState() {
    super.initState();
    final meta = widget.existingMeta;
    final profile = widget.existingProfile;

    _nameController = TextEditingController(
      text: meta?.displayName ?? (widget.isFirstProfile ? 'Main Profile' : ''),
    );
    _avatarPath = meta?.avatarPath;

    if (profile != null) {
      _heightCm = profile.heightCm;
      _weightKg = profile.weightKg;
      _ageYears = profile.ageYears;
      _sex = profile.sex;

      final totalBed = profile.habitualBedtimeMin.round();
      _habitualBedtime =
          TimeOfDay(hour: (totalBed ~/ 60) % 24, minute: totalBed % 60);
      _bedtimeUnknown = false;

      final totalWake = profile.habitualWakeMin.round();
      _habitualWakeTime =
          TimeOfDay(hour: (totalWake ~/ 60) % 24, minute: totalWake % 60);
      _wakeTimeUnknown = false;

      _calibrationGain = profile.calibrated30dBaAmplitude;
    }

    _ageController = TextEditingController(text: _ageYears.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final picker = ImagePicker();
                  final picked =
                      await picker.pickImage(source: ImageSource.gallery);
                  if (picked != null) {
                    setState(() => _avatarPath = picked.path);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final picker = ImagePicker();
                  final picked =
                      await picker.pickImage(source: ImageSource.camera);
                  if (picked != null) {
                    setState(() => _avatarPath = picked.path);
                  }
                },
              ),
              if (_avatarPath != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Remove Photo (Use Placeholder)'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    setState(() => _avatarPath = null);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _saveProfile() {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    _audioService.stopCalibrationTone();

    setState(() => _isSubmitting = true);

    final double? bedtimeMin = (_bedtimeUnknown || _habitualBedtime == null)
        ? null
        : (_habitualBedtime!.hour * 60.0 + _habitualBedtime!.minute);

    final double? wakeMin = (_wakeTimeUnknown || _habitualWakeTime == null)
        ? null
        : (_habitualWakeTime!.hour * 60.0 + _habitualWakeTime!.minute);

    final survey = OnboardingSurveyInput(
      heightCm: _heightCm,
      weightKg: _weightKg,
      ageYears: _ageYears,
      sex: _sex,
      habitualBedtimeMinutesFromMidnight: bedtimeMin?.round(),
      habitualWakeMinutesFromMidnight: wakeMin?.round(),
      latencyAnswer: _latency,
      sensitivityAnswer: _sensitivity,
      cycleRhythmAnswer: _cycleRhythm,
      calibrated30dBaDigitalAmplitude: _calibrationGain,
    );

    final profileBloc = context.read<ProfileBloc>();

    if (widget.existingMeta != null) {
      // Editing existing profile
      final updatedMeta = widget.existingMeta!.copyWith(
        displayName: _nameController.text.trim(),
        avatarPath: _avatarPath,
        clearAvatar: _avatarPath == null,
      );

      UserProfileModel? updatedProfile;
      if (widget.existingProfile != null) {
        updatedProfile = widget.existingProfile!.copyWith(
          heightCm: _heightCm,
          weightKg: _weightKg,
          ageYears: _ageYears,
          sex: _sex,
          habitualBedtimeMin: bedtimeMin ??
              SleepEngineConstants.defaultHabitualBedtimeMinFromMidnight,
          habitualWakeMin: wakeMin ?? 450.0,
          calibrated30dBaAmplitude: _calibrationGain,
        );
      }

      profileBloc.add(EditProfileEvent(
        meta: updatedMeta,
        updatedUserProfile: updatedProfile,
      ));
    } else {
      // Creating new profile
      profileBloc.add(CreateProfileEvent(
        displayName: _nameController.text.trim(),
        avatarPath: _avatarPath,
        survey: survey,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existingMeta != null;

    return BlocConsumer<ProfileBloc, ProfileState>(
      listener: (context, state) {
        if (state is ProfileLoaded && _isSubmitting) {
          if (widget.isFirstProfile) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MainShellScreen()),
              (route) => false,
            );
          } else {
            Navigator.of(context).pop();
          }
        } else if (state is ProfileError && _isSubmitting) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            title: Text(isEditing
                ? 'Edit Profile'
                : (widget.isFirstProfile
                    ? 'Create Your Sleep Profile'
                    : 'New Profile')),
            automaticallyImplyLeading: !widget.isFirstProfile,
          ),
          body: Form(
            key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          children: [
            // Avatar Section
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: ProfileAvatarWidget(
                      avatarPath: _avatarPath,
                      radius: 44,
                      initials: _nameController.text,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: theme.colorScheme.primary,
                      child: Icon(
                        Icons.camera_alt,
                        size: 14,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.add_a_photo, size: 16),
                label: Text(_avatarPath == null ? 'Add Avatar' : 'Change Avatar'),
                onPressed: _pickAvatar,
              ),
            ),
            const SizedBox(height: 16),

            // Profile Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Profile Name',
                hintText: 'e.g. Alex',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter a profile name';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Physique Section Header
            Text(
              'Physique & Biology',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Used to compute normative sleep onset latency and acoustic masking thresholds.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Biological Sex
            SegmentedButton<BiologicalSex>(
              segments: const [
                ButtonSegment(
                  value: BiologicalSex.male,
                  label: Text('Male'),
                ),
                ButtonSegment(
                  value: BiologicalSex.female,
                  label: Text('Female'),
                ),
                ButtonSegment(
                  value: BiologicalSex.otherOrUnspecified,
                  label: Text('Other'),
                ),
              ],
              selected: {_sex},
              onSelectionChanged: (set) => setState(() => _sex = set.first),
            ),
            const SizedBox(height: 16),

            // Age Field
            TextFormField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Age (Years)',
                prefixIcon: Icon(Icons.cake_outlined),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                final parsed = int.tryParse(v);
                if (parsed != null && parsed >= 13 && parsed <= 95) {
                  _ageYears = parsed;
                }
              },
            ),
            const SizedBox(height: 16),

            // Height Slider
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Height'),
                        Text(
                          '${_heightCm.round()} cm',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Slider(
                      value: _heightCm,
                      min: 120.0,
                      max: 230.0,
                      divisions: 110,
                      onChanged: (val) => setState(() => _heightCm = val),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Weight Slider
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Weight'),
                        Text(
                          '${_weightKg.toStringAsFixed(1)} kg',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Slider(
                      value: _weightKg,
                      min: 35.0,
                      max: 200.0,
                      divisions: 165,
                      onChanged: (val) => setState(() => _weightKg = val),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Habitual Routine Section
            Text(
              'Habitual Sleep Schedule',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Anchors your circadian phase and the Wake Maintenance Zone (WMZ).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),

            // Bedtime Selector
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              leading: const Icon(Icons.bedtime_outlined),
              title: const Text('Usual Bedtime'),
              trailing: _bedtimeUnknown
                  ? const Text('Irregular / Unknown')
                  : Text(
                      _habitualBedtime != null
                          ? '${_habitualBedtime!.hour.toString().padLeft(2, '0')}:${_habitualBedtime!.minute.toString().padLeft(2, '0')}'
                          : 'Not Set',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
              onTap: _bedtimeUnknown
                  ? null
                  : () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _habitualBedtime ??
                            const TimeOfDay(hour: 23, minute: 30),
                      );
                      if (picked != null) {
                        setState(() => _habitualBedtime = picked);
                      }
                    },
            ),
            CheckboxListTile(
              title: const Text("I don't know / Irregular bedtime"),
              value: _bedtimeUnknown,
              onChanged: (val) => setState(() => _bedtimeUnknown = val ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
            const SizedBox(height: 8),

            // Wake time Selector
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              leading: const Icon(Icons.wb_sunny_outlined),
              title: const Text('Usual Wake Time'),
              trailing: _wakeTimeUnknown
                  ? const Text('Irregular / Unknown')
                  : Text(
                      _habitualWakeTime != null
                          ? '${_habitualWakeTime!.hour.toString().padLeft(2, '0')}:${_habitualWakeTime!.minute.toString().padLeft(2, '0')}'
                          : 'Not Set',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
              onTap: _wakeTimeUnknown
                  ? null
                  : () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _habitualWakeTime ??
                            const TimeOfDay(hour: 7, minute: 30),
                      );
                      if (picked != null) {
                        setState(() => _habitualWakeTime = picked);
                      }
                    },
            ),
            CheckboxListTile(
              title: const Text("I don't know / Irregular wake time"),
              value: _wakeTimeUnknown,
              onChanged: (val) =>
                  setState(() => _wakeTimeUnknown = val ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
            const SizedBox(height: 24),

            // Scientific Survey MCQs
            Text(
              'Sleep Characteristics Survey',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Q1: Sleep Latency
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: RadioGroup<SurveySleepLatencyOption>(
                  groupValue: _latency,
                  onChanged: (v) => setState(() => _latency = v!),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How long does it usually take you to fall asleep?',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      RadioListTile<SurveySleepLatencyOption>(
                        title: Text('< 10 minutes (Fast)'),
                        value: SurveySleepLatencyOption.fastUnder10Min,
                      ),
                      RadioListTile<SurveySleepLatencyOption>(
                        title: Text('10 – 20 minutes (Normal)'),
                        value: SurveySleepLatencyOption.normal10To20Min,
                      ),
                      RadioListTile<SurveySleepLatencyOption>(
                        title: Text('20 – 35 minutes (Slow)'),
                        value: SurveySleepLatencyOption.slow20To35Min,
                      ),
                      RadioListTile<SurveySleepLatencyOption>(
                        title: Text('> 35 minutes (Very Slow)'),
                        value: SurveySleepLatencyOption.verySlowOver35Min,
                      ),
                      RadioListTile<SurveySleepLatencyOption>(
                        title: Text("I don't know (Use Normative Average)"),
                        value: SurveySleepLatencyOption.unknown,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Q2: Noise Sensitivity
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: RadioGroup<SurveyNoiseSensitivityOption>(
                  groupValue: _sensitivity,
                  onChanged: (v) => setState(() => _sensitivity = v!),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How easily do bedroom noises wake you up?',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      RadioListTile<SurveyNoiseSensitivityOption>(
                        title: Text('Light sleeper (Easily woken)'),
                        value: SurveyNoiseSensitivityOption.lightSleeperEasilyWoken,
                      ),
                      RadioListTile<SurveyNoiseSensitivityOption>(
                        title: Text('Average sleeper'),
                        value: SurveyNoiseSensitivityOption.averageSleeper,
                      ),
                      RadioListTile<SurveyNoiseSensitivityOption>(
                        title: Text('Deep sleeper (Hard to wake)'),
                        value: SurveyNoiseSensitivityOption.deepSleeperHardToWake,
                      ),
                      RadioListTile<SurveyNoiseSensitivityOption>(
                        title: Text("I don't know (Estimate from Age/BMI)"),
                        value: SurveyNoiseSensitivityOption.unknown,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Q3: Natural Cycle Rhythm
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: RadioGroup<SurveyCycleRhythmOption>(
                  groupValue: _cycleRhythm,
                  onChanged: (v) => setState(() => _cycleRhythm = v!),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What is your natural sleep cycle length?',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      RadioListTile<SurveyCycleRhythmOption>(
                        title: Text('Short cycles (~80 minutes)'),
                        value: SurveyCycleRhythmOption.shortCyclesAround80Min,
                      ),
                      RadioListTile<SurveyCycleRhythmOption>(
                        title: Text('Standard cycles (~90 minutes)'),
                        value: SurveyCycleRhythmOption.standardCyclesAround90Min,
                      ),
                      RadioListTile<SurveyCycleRhythmOption>(
                        title: Text('Long cycles (~100+ minutes)'),
                        value: SurveyCycleRhythmOption.longCyclesAround100PlusMin,
                      ),
                      RadioListTile<SurveyCycleRhythmOption>(
                        title: Text("I don't know (Adaptive Kalman Initializer)"),
                        value: SurveyCycleRhythmOption.unknown,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Quiet-Room 30 dBA Speaker Calibration Card
            SoundCalibrationCard(
              initialGain: _calibrationGain,
              onGainChanged: (val) => setState(() => _calibrationGain = val),
              audioService: _audioService,
              volumeService: _volumeService,
            ),
            const SizedBox(height: 12),

            // Save Action
            FilledButton.icon(
              icon: _isSubmitting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(
                _isSubmitting
                    ? 'Saving...'
                    : (isEditing ? 'Save Changes' : 'Create Profile'),
                style: const TextStyle(fontSize: 16),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _isSubmitting ? null : _saveProfile,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
      },
    );
  }
}
