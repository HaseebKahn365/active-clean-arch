import 'package:flutter/foundation.dart';
import '../../domain/entities/backup.dart';
import '../../domain/use_cases/backup/create_backup_use_case.dart';
import '../../domain/use_cases/backup/get_backup_history_use_case.dart';
import '../../domain/use_cases/backup/restore_backup_use_case.dart';
import 'auth_provider.dart';

class BackupController extends ChangeNotifier {
  final CreateBackupUseCase createBackupUseCase;
  final GetBackupHistoryUseCase getBackupHistoryUseCase;
  final RestoreBackupUseCase restoreBackupUseCase;
  final AppAuthProvider authProvider;

  BackupController({
    required this.createBackupUseCase,
    required this.getBackupHistoryUseCase,
    required this.restoreBackupUseCase,
    required this.authProvider,
  });

  List<Backup> _history = [];
  bool _isLoading = false;

  List<Backup> get history => _history;
  bool get isLoading => _isLoading;

  Future<void> loadHistory() async {
    _isLoading = true;
    notifyListeners();

    try {
      final userId = authProvider.userId;
      if (userId == null) return;
      _history = await getBackupHistoryUseCase.execute(userId);
    } catch (e) {
      debugPrint('Error loading backup history: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createBackup() async {
    _isLoading = true;
    notifyListeners();

    try {
      final userId = authProvider.userId;
      if (userId == null) throw Exception('User not logged in');
      await createBackupUseCase.execute(userId);
      await loadHistory();
    } catch (e) {
      debugPrint('Error creating backup: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> restoreFrom(Backup backup) async {
    _isLoading = true;
    notifyListeners();

    try {
      await restoreBackupUseCase.execute(backup.url);
    } catch (e) {
      debugPrint('Error restoring backup: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
