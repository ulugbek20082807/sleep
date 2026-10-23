import 'package:equatable/equatable.dart';
import '../../core/sleep_core_engine.dart';

/// Completed sleep history item and telemetry summary.
class SleepSessionRecord extends Equatable {
  final String sessionId;
  final String profileId;
  final String sleepStartTimeIso;
  final String targetWakeTimeIso;
  final String actualEndTimeIso;
  final double totalElapsedMinutes;
  final double predictedSolMinutes;
  final double circadianShiftHours;
  final SleepPresetType presetUsed;
  final PreSleepPhysicalState physicalStateUsed;
  final bool analysisModeEnabled;
  final bool cycleBoundaryCalibrated;
  final double? measuredCycleDurationMinutes;
  final int completedCyclesCount;
  final WakeTimeHealthZone wakeHealthZoneAtStart;
  final Map<String, double> stageMinutesSummary;
  final List<Map<String, dynamic>> stageTimelineSamples;

  const SleepSessionRecord({
    required this.sessionId,
    required this.profileId,
    required this.sleepStartTimeIso,
    required this.targetWakeTimeIso,
    required this.actualEndTimeIso,
    required this.totalElapsedMinutes,
    required this.predictedSolMinutes,
    required this.circadianShiftHours,
    required this.presetUsed,
    required this.physicalStateUsed,
    required this.analysisModeEnabled,
    required this.cycleBoundaryCalibrated,
    this.measuredCycleDurationMinutes,
    required this.completedCyclesCount,
    required this.wakeHealthZoneAtStart,
    required this.stageMinutesSummary,
    required this.stageTimelineSamples,
  });

  DateTime get sleepStartTime => DateTime.parse(sleepStartTimeIso);
  DateTime get targetWakeTime => DateTime.parse(targetWakeTimeIso);
  DateTime get actualEndTime => DateTime.parse(actualEndTimeIso);

  double get netSleepMinutes =>
      (totalElapsedMinutes - predictedSolMinutes).clamp(0.0, double.infinity);

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'profileId': profileId,
      'sleepStartTimeIso': sleepStartTimeIso,
      'targetWakeTimeIso': targetWakeTimeIso,
      'actualEndTimeIso': actualEndTimeIso,
      'totalElapsedMinutes': totalElapsedMinutes,
      'predictedSolMinutes': predictedSolMinutes,
      'circadianShiftHours': circadianShiftHours,
      'presetUsed': presetUsed.name,
      'physicalStateUsed': physicalStateUsed.name,
      'analysisModeEnabled': analysisModeEnabled,
      'cycleBoundaryCalibrated': cycleBoundaryCalibrated,
      'measuredCycleDurationMinutes': measuredCycleDurationMinutes,
      'completedCyclesCount': completedCyclesCount,
      'wakeHealthZoneAtStart': wakeHealthZoneAtStart.name,
      'stageMinutesSummary': stageMinutesSummary,
      'stageTimelineSamples': stageTimelineSamples,
    };
  }

  factory SleepSessionRecord.fromJson(Map<String, dynamic> json) {
    return SleepSessionRecord(
      sessionId: json['sessionId'] as String,
      profileId: json['profileId'] as String,
      sleepStartTimeIso: json['sleepStartTimeIso'] as String,
      targetWakeTimeIso: json['targetWakeTimeIso'] as String,
      actualEndTimeIso: json['actualEndTimeIso'] as String,
      totalElapsedMinutes: (json['totalElapsedMinutes'] as num).toDouble(),
      predictedSolMinutes: (json['predictedSolMinutes'] as num).toDouble(),
      circadianShiftHours: (json['circadianShiftHours'] as num).toDouble(),
      presetUsed: SleepPresetType.values.firstWhere(
        (e) => e.name == json['presetUsed'],
        orElse: () => SleepPresetType.basicBalancedSleep,
      ),
      physicalStateUsed: PreSleepPhysicalState.values.firstWhere(
        (e) => e.name == json['physicalStateUsed'],
        orElse: () => PreSleepPhysicalState.normalBaseline,
      ),
      analysisModeEnabled: json['analysisModeEnabled'] as bool? ?? false,
      cycleBoundaryCalibrated: json['cycleBoundaryCalibrated'] as bool? ?? false,
      measuredCycleDurationMinutes:
          (json['measuredCycleDurationMinutes'] as num?)?.toDouble(),
      completedCyclesCount: (json['completedCyclesCount'] as num?)?.toInt() ?? 0,
      wakeHealthZoneAtStart: WakeTimeHealthZone.values.firstWhere(
        (e) => e.name == json['wakeHealthZoneAtStart'],
        orElse: () => WakeTimeHealthZone.greenOptimal,
      ),
      stageMinutesSummary:
          (json['stageMinutesSummary'] as Map<String, dynamic>?)?.map(
                (k, v) => MapEntry(k, (v as num).toDouble()),
              ) ??
              <String, double>{},
      stageTimelineSamples: (json['stageTimelineSamples'] as List<dynamic>?)
              ?.map((item) => Map<String, dynamic>.from(item as Map))
              .toList() ??
          <Map<String, dynamic>>[],
    );
  }

  @override
  List<Object?> get props => [
        sessionId,
        profileId,
        sleepStartTimeIso,
        targetWakeTimeIso,
        actualEndTimeIso,
        totalElapsedMinutes,
        predictedSolMinutes,
        circadianShiftHours,
        presetUsed,
        physicalStateUsed,
        analysisModeEnabled,
        cycleBoundaryCalibrated,
        measuredCycleDurationMinutes,
        completedCyclesCount,
        wakeHealthZoneAtStart,
        stageMinutesSummary,
        stageTimelineSamples,
      ];
}

