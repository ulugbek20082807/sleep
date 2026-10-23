import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/sleep_session_record.dart';
import '../../data/repositories/sleep_history_repository.dart';
import 'sleep_history_state.dart';

class SleepHistoryCubit extends Cubit<SleepHistoryState> {
  final SleepHistoryRepository repository;

  SleepHistoryCubit({required this.repository})
      : super(const SleepHistoryState());

  Future<void> loadHistory(String profileId) async {
    emit(state.copyWith(status: SleepHistoryStatus.loading));
    try {
      final records = await repository.getHistory(profileId);
      emit(state.copyWith(
        status: SleepHistoryStatus.loaded,
        records: records,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: SleepHistoryStatus.error,
        errorMessage: 'Failed to load sleep history: $e',
      ));
    }
  }

  Future<void> addSession(SleepSessionRecord record) async {
    try {
      await repository.addRecord(record);
      final records = await repository.getHistory(record.profileId);
      emit(state.copyWith(
        status: SleepHistoryStatus.loaded,
        records: records,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: SleepHistoryStatus.error,
        errorMessage: 'Failed to add session: $e',
      ));
    }
  }

  Future<void> deleteSession(String profileId, String sessionId) async {
    try {
      await repository.deleteRecord(profileId, sessionId);
      final records = await repository.getHistory(profileId);
      emit(state.copyWith(
        status: SleepHistoryStatus.loaded,
        records: records,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: SleepHistoryStatus.error,
        errorMessage: 'Failed to delete session: $e',
      ));
    }
  }
}

