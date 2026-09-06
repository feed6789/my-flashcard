import 'package:flashcard_app/config/supabase_config.dart';
import 'package:flashcard_app/features/flashcard/data/models/user_progress_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProgressSource {
  final SupabaseClient _client = SupabaseConfig.client;

  // Lấy tất cả progress của user hiện tại
  Future<List<UserProgress>> getUserProgress() async {
    try {
      final user = SupabaseConfig.currentUser;
      if (user == null) throw Exception('User not authenticated');

      print('📥 Fetching progress for user: ${user.id}');

      final response =
          await _client.from('user_progress').select().eq('user_id', user.id);

      print('📥 Found ${response.length} progress records');

      // Debug: In ra danh sách
      for (var json in response) {
        print(
            '📝 Server record: ${json['flashcard_id']} -> ${json['study_status']}');
      }

      return response.map((json) => UserProgress.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error loading user progress: $e');
      return [];
    }
  }

  // Lấy progress của một flashcard
  Future<UserProgress?> getProgressForCard(String flashcardId) async {
    try {
      final user = SupabaseConfig.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _client
          .from('user_progress')
          .select()
          .eq('user_id', user.id)
          .eq('flashcard_id', flashcardId)
          .maybeSingle();

      if (response == null) return null;
      return UserProgress.fromJson(response);
    } catch (e) {
      print('❌ Error loading progress for card: $e');
      return null;
    }
  }

  // Upsert progress (thêm mới hoặc cập nhật)
  Future<UserProgress> upsertProgress(UserProgress progress) async {
    try {
      final user = SupabaseConfig.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Tạo bản sao với user_id
      final data = {
        'id': progress.id.isNotEmpty ? progress.id : null,
        'user_id': user.id,
        'flashcard_id': progress.flashcardId,
        'study_status': progress.studyStatus,
        'srs_interval': progress.srsInterval,
        'srs_ease_factor': progress.srsEaseFactor,
        'srs_next_review': progress.srsNextReview?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Loại bỏ null values
      data.removeWhere((key, value) => value == null);

      print('📤 Upserting: ${data['flashcard_id']} -> ${data['study_status']}');

      final response = await _client
          .from('user_progress')
          .upsert(data, onConflict: 'user_id,flashcard_id')
          .select()
          .maybeSingle();

      if (response == null) {
        throw Exception('No data returned after upsert');
      }

      return UserProgress.fromJson(response);
    } catch (e) {
      print('❌ Error upserting progress: $e');
      rethrow;
    }
  }

  // Bulk upsert progress
  Future<void> upsertMultipleProgress(List<UserProgress> progresses) async {
    try {
      final user = SupabaseConfig.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final now = DateTime.now().toIso8601String();
      final data = progresses.map((p) {
        final json = p.toJson();
        json['user_id'] = user.id;
        json['updated_at'] = now;
        return json;
      }).toList();

      await _client
          .from('user_progress')
          .upsert(data, onConflict: 'user_id,flashcard_id');

      print('✅ Bulk upsert ${progresses.length} progresses');
    } catch (e) {
      print('❌ Error bulk upserting progresses: $e');
      rethrow;
    }
  }

  // Xóa progress của user
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
