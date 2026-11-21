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

  /// Thứ bậc trạng thái học: new < learning < reviewing < mastered
  /// Số càng lớn = càng "cao cấp", không thể bị đè bởi số nhỏ hơn.
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

  /// Quyết định giữa local và remote, trả về:
  /// - `UserProgress` được chọn (có thể là local hoặc remote)
  /// - `bool isLocalWin` = true nếu local thắng (cần push)
  ///
  /// Quy tắc:
  /// 1. So sánh rank trước:
  ///    - rank khác nhau → rank cao hơn thắng (bất kể thời gian)
  /// 2. Nếu rank bằng nhau → so `updated_at`:
  ///    - cái nào mới hơn thắng
  /// 3. Nếu cùng rank + cùng thời gian (hoặc null) → giữ local (không push)
  ({UserProgress winner, bool isLocalWin}) _resolveConflict(
    UserProgress local,
    UserProgress remote,
  ) {
    final localRank = _rankOf(local.studyStatus);
    final remoteRank = _rankOf(remote.studyStatus);

    // 1. Ưu tiên theo rank
    if (localRank > remoteRank) {
      return (winner: local, isLocalWin: true);
    }
    if (remoteRank > localRank) {
      return (winner: remote, isLocalWin: false);
    }

    // 2. Cùng rank → xét updated_at
    final localTime = local.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final remoteTime =
        remote.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

    if (localTime.isAfter(remoteTime)) {
      return (winner: local, isLocalWin: true);
    }
    if (remoteTime.isAfter(localTime)) {
      return (winner: remote, isLocalWin: false);
    }

    // 3. Bằng nhau hoàn toàn → không cần làm gì, giữ local
    return (winner: local, isLocalWin: false);
  }

  /// Merge local progress + remote progress.
  /// - Card chỉ có local → push lên remote (nếu id hợp lệ)
  /// - Card chỉ có remote → thêm vào local
  /// - Card có cả 2 → resolveConflict() quyết định
  Future<Map<String, int>> syncProgress() async {
    if (!SupabaseConfig.isAuthenticated) {
      print('⚠️ Skip sync: not authenticated');
      return {'pulled': 0, 'pushed': 0};
    }

    try {
      print('🔄 Starting sync progress...');

      // 1. Pull from remote
      final remoteList = await _remoteSource.getUserProgress();
      final remoteMap = <int, UserProgress>{
        for (final p in remoteList) p.flashcardId: p,
      };

      // 2. Local progress
      final localList = await _localDb.getAllUserProgress();
      final localMap = <int, UserProgress>{
        for (final p in localList) p.flashcardId: p,
      };

      // 3. Merge
      final toPush = <UserProgress>[];
      final toSaveLocal = <UserProgress>[];
      final allKeys = {...remoteMap.keys, ...localMap.keys};

      int conflictResolvedByRank = 0;
      int conflictResolvedByTime = 0;

      for (final key in allKeys) {
        final remote = remoteMap[key];
        final local = localMap[key];

        if (local == null && remote != null) {
          // Chỉ có remote → đưa vào local
          toSaveLocal.add(remote);
        } else if (local != null && remote == null) {
          // Chỉ có local → đẩy lên remote (nếu id hợp lệ)
          if (local.flashcardId > 0) {
            toPush.add(local);
          }
        } else if (local != null && remote != null) {
          // Có cả 2 → resolveConflict
          final result = _resolveConflict(local, remote);

          // Log để debug
          final localRank = _rankOf(local.studyStatus);
          final remoteRank = _rankOf(remote.studyStatus);
          if (localRank != remoteRank) {
            conflictResolvedByRank++;
            print(
                '⚖️ Conflict card $key: local=${local.studyStatus}(rank=$localRank) '
                'vs remote=${remote.studyStatus}(rank=$remoteRank) '
                '→ winner=${result.winner.studyStatus}');
          } else if (result.winner.studyStatus != local.studyStatus ||
              result.winner.studyStatus != remote.studyStatus) {
            conflictResolvedByTime++;
            print('⏰ Conflict card $key: same rank, decided by updated_at '
                '→ winner=${result.winner.studyStatus}');
          }

          if (result.isLocalWin) {
            // Local thắng → push lên remote + giữ local
            if (local.flashcardId > 0) {
              toPush.add(result.winner);
            }
          } else {
            // Remote thắng → ghi đè local
            // Nhưng chỉ ghi nếu khác biệt thực sự
            final sameStatus = local.studyStatus == remote.studyStatus;
            final sameInterval = local.srsInterval == remote.srsInterval;
            final sameEase =
                (local.srsEaseFactor - remote.srsEaseFactor).abs() < 0.001;

            if (!sameStatus || !sameInterval || !sameEase) {
              toSaveLocal.add(result.winner);
            }
          }
        }
      }

      // 4. Push lên remote
      int pushedCount = 0;
      if (toPush.isNotEmpty) {
        pushedCount = await _remoteSource.upsertMultipleProgress(toPush);
      }

      // 5. Lưu vào local (chỉ những cái remote mới hơn / rank cao hơn)
      for (final p in toSaveLocal) {
        await _localDb.insertUserProgress(p); // upsert
      }

      print('✅ Sync done: pulled=${toSaveLocal.length}, pushed=$pushedCount, '
          'rankConflicts=$conflictResolvedByRank, timeConflicts=$conflictResolvedByTime');
      return {
        'pulled': toSaveLocal.length,
        'pushed': pushedCount,
      };
    } catch (e) {
      print('❌ Sync failed: $e');
      rethrow;
    }
  }

  /// Push một progress duy nhất (dùng khi user đổi status)
  /// ⚠️ Có thêm logic bảo vệ: không push status thấp hơn status hiện có trên server
  Future<void> pushOne(UserProgress progress) async {
    if (!SupabaseConfig.isAuthenticated) return;
    if (progress.flashcardId <= 0) return;

    try {
      // Kiểm tra status hiện tại trên server trước khi push
      final serverList = await _remoteSource.getUserProgress();
      UserProgress? serverProgress;
      for (final s in serverList) {
        if (s.flashcardId == progress.flashcardId) {
          serverProgress = s;
          break;
        }
      }

      if (serverProgress != null) {
        // Nếu server có rank cao hơn → KHÔNG push (bảo vệ status cao)
        final localRank = _rankOf(progress.studyStatus);
        final serverRank = _rankOf(serverProgress.studyStatus);

        if (serverRank > localRank) {
          print('🛡️ Skip push: server has higher rank '
              '(${serverProgress.studyStatus} > ${progress.studyStatus}) for card ${progress.flashcardId}');
          return;
        }
      }

      await _remoteSource.upsertProgress(progress);
      print('☁️ Pushed: ${progress.flashcardId} -> ${progress.studyStatus}');
    } catch (e) {
      print('⚠️ Push one failed (will retry later): $e');
    }
  }
}
