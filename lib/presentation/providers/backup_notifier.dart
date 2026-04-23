import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/injection_container.dart';
import '../../domain/entities/backup.dart';
import '../../domain/use_cases/backup/create_backup_use_case.dart';
import '../../domain/use_cases/backup/get_backup_history_use_case.dart';
import '../../domain/use_cases/backup/restore_backup_use_case.dart';
import 'riverpod_bridge.dart';

class BackupState {
  final List<Backup> history;
  final bool isLoading;

  BackupState({this.history = const [], this.isLoading = false});

  BackupState copyWith({List<Backup>? history, bool? isLoading}) {
    return BackupState(
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class BackupNotifier extends Notifier<BackupState> {
  @override
  BackupState build() {
    return BackupState();
  }

  Future<void> loadHistory() async {
    state = state.copyWith(isLoading: true);

    try {
      final auth = ref.read(authControllerProvider);
      final userId = auth.userId;
      if (userId == null) return;
      
      final history = await sl<GetBackupHistoryUseCase>().execute(userId);
      state = state.copyWith(history: history);
    } catch (e) {
      debugPrint('Error loading backup history: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> createBackup() async {
    state = state.copyWith(isLoading: true);

    try {
      final auth = ref.read(authControllerProvider);
      final userId = auth.userId;
      if (userId == null) throw Exception('User not logged in');
      
      await sl<CreateBackupUseCase>().execute(userId);
      await loadHistory();
    } catch (e) {
      debugPrint('Error creating backup: $e');
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> restoreFrom(Backup backup) async {
    state = state.copyWith(isLoading: true);

    try {
      await sl<RestoreBackupUseCase>().execute(backup.url);
    } catch (e) {
      debugPrint('Error restoring backup: $e');
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}

final backupStateProvider = NotifierProvider<BackupNotifier, BackupState>(BackupNotifier.new);
