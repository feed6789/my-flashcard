import 'package:flashcard_app/config/supabase_config.dart';
import 'package:flashcard_app/core/database/local_database.dart';
import 'package:flashcard_app/features/flashcard/data/datasources/user_progress_source.dart';
import 'package:flashcard_app/features/flashcard/data/models/user_progress_model.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final _localDb = LocalDatabase();
  final _remoteSource = UserProgressSource();

  /// Thứ bậc: new < learning < reviewing < mastered
  static const Map<String, int> _statusRank = {
    'new': 0,
    'learning': 1,
    'reviewing': 2,
    'mastered': 3,
  };

  static int _rankOf(String? status) {
    if (status == null) return 0;
    return _statusRank[status] ?? 0;
  }

  /// Resolve conflict giữa local và remote.
  ///
  /// Thứ tự ưu tiên:
  /// 1. Nếu LOCAL có `forceDowngradeAt` MỚI HƠN `remote.updatedAt`
  ///    → LOCAL thắng tuyệt đối (user chủ động hạ cấp)
  /// 2. Nếu REMOTE có `forceDowngradeAt` MỚI HƠN `local.updatedAt`
  ///    → REMOTE thắng tuyệt đối
  /// 3. So sánh rank (new < learning < reviewing < mastered)
  ///    - rank cao hơn thắng
  /// 4. Cùng rank → so `updated_at`, cái mới hơn thắng
  /// 5. Bằng nhau → giữ local (không push)
  ({UserProgress winner, bool isLocalWin, String reason}) _resolveConflict(
    UserProgress local,
    UserProgress remote,
  ) {
    final localTime = local.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final remoteTime =
        remote.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

    // 1. LOCAL force downgrade mới hơn remote.updated_at
    if (local.forceDowngradeAt != null &&
        local.forceDowngradeAt!.isAfter(remoteTime)) {
      return (
        winner: local,
        isLocalWin: true,
        reason: 'local_force_downgrade',
      );
    }

    // 2. REMOTE force downgrade mới hơn local.updated_at
    if (remote.forceDowngradeAt != null &&
        remote.forceDowngradeAt!.isAfter(localTime)) {
      return (
        winner: remote,
        isLocalWin: false,
        reason: 'remote_force_downgrade',
      );
    }

    // 3. So sánh rank
    final localRank = _rankOf(local.studyStatus);
    final remoteRank = _rankOf(remote.studyStatus);

    if (localRank > remoteRank) {
      return (winner: local, isLocalWin: true, reason: 'local_higher_rank');
    }
    if (remoteRank > localRank) {
      return (winner: remote, isLocalWin: false, reason: 'remote_higher_rank');
    }

    // 4. Cùng rank → so updated_at
    if (localTime.isAfter(remoteTime)) {
      return (winner: local, isLocalWin: true, reason: 'local_newer');
    }
    if (remoteTime.isAfter(localTime)) {
      return (winner: remote, isLocalWin: false, reason: 'remote_newer');
    }

    // 5. Bằng nhau
    return (winner: local, isLocalWin: false, reason: 'equal');
  }

  Future<Map<String, int>> syncProgress() async {
    if (!SupabaseConfig.isAuthenticated) {
      print('⚠️ Skip sync: not authenticated');
      return {'pulled': 0, 'pushed': 0};
    }

    try {
      print('🔄 Starting sync progress...');

      final remoteList = await _remoteSource.getUserProgress();
      final remoteMap = <int, UserProgress>{
        for (final p in remoteList) p.flashcardId: p,
      };

      final localList = await _localDb.getAllUserProgress();
      final localMap = <int, UserProgress>{
        for (final p in localList) p.flashcardId: p,
      };

      final toPush = <UserProgress>[];
      final toSaveLocal = <UserProgress>[];
      final allKeys = {...remoteMap.keys, ...localMap.keys};

      int rankConflicts = 0;
      int timeConflicts = 0;
      int forceDowngrades = 0;

      for (final key in allKeys) {
        final remote = remoteMap[key];
        final local = localMap[key];

        if (local == null && remote != null) {
          toSaveLocal.add(remote);
        } else if (local != null && remote == null) {
          if (local.flashcardId > 0) toPush.add(local);
        } else if (local != null && remote != null) {
          final result = _resolveConflict(local, remote);

          switch (result.reason) {
            case 'local_force_downgrade':
            case 'remote_force_downgrade':
              forceDowngrades++;
              print(
                  '🔽 Force downgrade card $key: ${result.reason} → ${result.winner.studyStatus}');
              break;
            case 'local_higher_rank':
            case 'remote_higher_rank':
              rankConflicts++;
              print('⚖️ Rank conflict card $key: local=${local.studyStatus} '
                  'vs remote=${remote.studyStatus} → ${result.winner.studyStatus}');
              break;
            case 'local_newer':
            case 'remote_newer':
              timeConflicts++;
              break;
          }

          if (result.isLocalWin) {
            if (local.flashcardId > 0) {
              // Khi push, clear force_downgrade_at (đã xử lý xong)
              final pushProgress = result.winner.copyWith(
                clearForceDowngrade: true,
                updatedAt: DateTime.now().toUtc(),
              );
              toPush.add(pushProgress);

              // Đồng thời cập nhật local (clear force flag)
              await _localDb.insertUserProgress(pushProgress);
            }
          } else {
            final sameStatus = local.studyStatus == remote.studyStatus;
            final sameInterval = local.srsInterval == remote.srsInterval;
            final sameEase =
                (local.srsEaseFactor - remote.srsEaseFactor).abs() < 0.001;
            final sameForce = local.forceDowngradeAt == remote.forceDowngradeAt;

            if (!sameStatus || !sameInterval || !sameEase || !sameForce) {
              toSaveLocal.add(remote);
            }
          }
        }
      }

      int pushedCount = 0;
      if (toPush.isNotEmpty) {
        pushedCount = await _remoteSource.upsertMultipleProgress(toPush);
      }

      for (final p in toSaveLocal) {
        await _localDb.insertUserProgress(p);
      }

      print('✅ Sync done: pulled=${toSaveLocal.length}, pushed=$pushedCount, '
          'rankConflicts=$rankConflicts, timeConflicts=$timeConflicts, '
          'forceDowngrades=$forceDowngrades');

      return {'pulled': toSaveLocal.length, 'pushed': pushedCount};
    } catch (e) {
      print('❌ Sync failed: $e');
      rethrow;
    }
  }

  Future<void> pushOne(UserProgress progress) async {
    if (!SupabaseConfig.isAuthenticated) return;
    if (progress.flashcardId <= 0) return;

    try {
      final serverList = await _remoteSource.getUserProgress();
      UserProgress? serverProgress;
      for (final s in serverList) {
        if (s.flashcardId == progress.flashcardId) {
          serverProgress = s;
          break;
        }
      }

      if (serverProgress != null) {
        final localRank = _rankOf(progress.studyStatus);
        final serverRank = _rankOf(serverProgress.studyStatus);

        // Cho phép push nếu:
        // - local rank >= server rank (bình thường)
        // - HOẶC có force downgrade mới hơn server.updated_at (chủ động hạ cấp)
        final forceDowngradeNewer = progress.forceDowngradeAt != null &&
            (serverProgress.updatedAt == null ||
                progress.forceDowngradeAt!.isAfter(serverProgress.updatedAt!));

        if (serverRank > localRank && !forceDowngradeNewer) {
          print('🛡️ Skip push: server has higher rank '
              '(${serverProgress.studyStatus} > ${progress.studyStatus})');
          return;
        }

        if (forceDowngradeNewer) {
          print(
              '🔽 Force downgrade accepted: ${serverProgress.studyStatus} → ${progress.studyStatus}');
        }
      }

      // Khi push thành công → clear force flag
      final toPush = progress.copyWith(
        clearForceDowngrade: true,
        updatedAt: DateTime.now().toUtc(),
      );
      await _remoteSource.upsertProgress(toPush);
      await _localDb.insertUserProgress(toPush);

      print('☁️ Pushed: ${toPush.flashcardId} -> ${toPush.studyStatus}');
    } catch (e) {
      print('⚠️ Push one failed (will retry later): $e');
    }
  }
}
