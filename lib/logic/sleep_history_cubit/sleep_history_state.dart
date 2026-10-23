import 'package:equatable/equatable.dart';
import '../../data/models/sleep_session_record.dart';

enum SleepHistoryStatus { initial, loading, loaded, error }

class SleepHistoryState extends Equatable {
  final SleepHistoryStatus status;
  final List<SleepSessionRecord> records;
  final String? errorMessage;

  const SleepHistoryState({
    this.status = SleepHistoryStatus.initial,
    this.records = const [],
    this.errorMessage,
  });

  SleepHistoryState copyWith({
    SleepHistoryStatus? status,
    List<SleepSessionRecord>? records,
    String? errorMessage,
  }) {
    return SleepHistoryState(
      status: status ?? this.status,
      records: records ?? this.records,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, records, errorMessage];
}

