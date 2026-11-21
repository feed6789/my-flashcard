import 'package:flashcard_app/config/supabase_config.dart';
import 'package:flashcard_app/features/flashcard/data/models/user_progress_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProgressSource {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Lấy toàn bộ progress của user hiện tại
  Future<List<UserProgress>> getUserProgress() async {
    try {
      final user = SupabaseConfig.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response =
          await _client.from('user_progress').select().eq('user_id', user.id);

      print('📥 Fetched ${response.length} progress records from Supabase');
      return response.map((json) => UserProgress.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error loading user progress: $e');
      return [];
    }
  }

  /// Upsert một progress
  Future<UserProgress?> upsertProgress(UserProgress progress) async {
    try {
      final user = SupabaseConfig.currentUser;
      if (user == null) {
        print('⚠️ Not authenticated, skip upsert');
        return null;
      }

      // Chỉ đồng bộ flashcard có id là số nguyên (từ server)
      if (progress.flashcardId <= 0) {
        print('⚠️ Skip upsert: flashcardId is not a valid bigint '
            '(${progress.flashcardId})');
        return null;
      }

      final data = progress.toSupabaseJson(userId: user.id);

      final response = await _client
          .from('user_progress')
          .upsert(data, onConflict: 'user_id,flashcard_id')
          .select()
          .maybeSingle();

      if (response == null) {
        print('⚠️ Upsert returned null');
        return null;
      }
      return UserProgress.fromJson(response);
    } catch (e) {
      print('❌ Error upserting progress: $e');
      rethrow;
    }
  }

  /// Bulk upsert nhiều progress
  Future<int> upsertMultipleProgress(List<UserProgress> progresses) async {
    try {
      final user = SupabaseConfig.currentUser;
      if (user == null) return 0;

      // Lọc chỉ những progress có flashcardId hợp lệ (bigint)
      final valid = progresses
          .where((p) => p.flashcardId > 0)
          .map((p) => p.toSupabaseJson(userId: user.id))
          .toList();

      if (valid.isEmpty) {
        print('⚠️ No valid progress to upsert');
        return 0;
      }

      await _client
          .from('user_progress')
          .upsert(valid, onConflict: 'user_id,flashcard_id');

      print('✅ Bulk upsert ${valid.length} progresses');
      return valid.length;
    } catch (e) {
      print('❌ Error bulk upserting progresses: $e');
      rethrow;
    }
  }

  /// Xoá toàn bộ progress của user
  Future<void> deleteAllProgress() async {
    try {
      final user = SupabaseConfig.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _client.from('user_progress').delete().eq('user_id', user.id);
      print('✅ Deleted all progress for user');
    } catch (e) {
      print('❌ Error deleting progress: $e');
      rethrow;
    }
  }
}
