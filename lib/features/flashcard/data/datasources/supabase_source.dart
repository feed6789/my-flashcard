// lib/features/flashcard/data/datasources/supabase_source.dart

import 'package:flashcard_app/config/supabase_config.dart';
import 'package:flashcard_app/features/flashcard/data/datasources/flashcard_source.dart';
import 'package:flashcard_app/features/flashcard/data/models/flashcard_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSource implements FlashcardSource {
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<List<Flashcard>> getAllFlashcards() async {
    try {
      print('📡 Fetching all flashcards from Supabase...');

      List<Flashcard> allCards = [];
      int page = 0;
      int pageSize = 1000;
      bool hasMore = true;

      while (hasMore) {
        final from = page * pageSize;
        final to = from + pageSize - 1;

        print('📄 Fetching page ${page + 1} (range: $from - $to)');

        final response = await _client
            .from('flashcards')
            .select()
            .order('id', ascending: true)
            .range(from, to);

        if (response.isEmpty) {
          hasMore = false;
          break;
        }

        final cards = response.map((json) => Flashcard.fromJson(json)).toList();
        allCards.addAll(cards);

        if (cards.length < pageSize) {
          hasMore = false;
        }

        page++;
      }

      print('📥 Loaded ${allCards.length} flashcards from Supabase');
      return allCards;
    } catch (e) {
      print('❌ Supabase error: $e');
      throw Exception('Failed to load flashcards from Supabase: $e');
    }
  }

  // Hàm lấy flashcards với filter và sort
  Future<List<Flashcard>> getFlashcardsWithFilter({
    String? jpLevel,
    String? enLevel,
    String? cnLevel,
    String? searchQuery,
    String? sortBy = 'id',
    bool ascending = true,
    int? limit = 1000,
  }) async {
    try {
      print('📡 Fetching filtered flashcards from Supabase...');

      // Sử dụng dynamic để tránh lỗi type
      dynamic query = _client.from('flashcards').select();

      // Áp dụng filter - sử dụng eq cho từng điều kiện
      if (jpLevel != null && jpLevel.isNotEmpty) {
        query = query.eq('jp_level', jpLevel);
      }

      if (enLevel != null && enLevel.isNotEmpty) {
        query = query.eq('en_level', enLevel);
      }

      if (cnLevel != null && cnLevel.isNotEmpty) {
        query = query.eq('cn_level', cnLevel);
      }

      // Áp dụng search
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('vietnamese.ilike.%$searchQuery%,'
            'english.ilike.%$searchQuery%,'
            'jp_kanji.ilike.%$searchQuery%');
      }

      // Áp dụng sort
      if (sortBy != null && sortBy.isNotEmpty) {
        query = query.order(sortBy, ascending: ascending);
      }

      // Áp dụng limit
      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;

      print('📥 Loaded ${response.length} filtered flashcards from Supabase');

      // Debug: In thông tin filter
      print('🔍 Filter applied:');
      print('  JLPT: ${jpLevel ?? "All"}');
      print('  CEFR: ${enLevel ?? "All"}');
      print('  HSK: ${cnLevel ?? "All"}');
      print('  Search: ${searchQuery ?? "None"}');
      print('  Sort: $sortBy ${ascending ? "ASC" : "DESC"}');

      return response.map((json) => Flashcard.fromJson(json)).toList();
    } catch (e) {
      print('❌ Supabase filter error: $e');
      throw Exception('Failed to load filtered flashcards: $e');
    }
  }

  // Hàm lấy flashcards theo cấp độ JLPT
  Future<List<Flashcard>> getFlashcardsByJpLevel(String level) async {
    try {
      // Kiểm tra level không null và không rỗng
      if (level.isEmpty) {
        return await getAllFlashcards();
      }

      final response = await _client
          .from('flashcards')
          .select()
          .eq('jp_level', level)
          .order('id', ascending: true);

      return response.map((json) => Flashcard.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error getting flashcards by JLPT level: $e');
      throw Exception('Failed to load flashcards by JLPT level: $e');
    }
  }

  // Hàm lấy flashcards theo cấp độ CEFR
  Future<List<Flashcard>> getFlashcardsByEnLevel(String level) async {
    try {
      // Kiểm tra level không null và không rỗng
      if (level.isEmpty) {
        return await getAllFlashcards();
      }

      final response = await _client
          .from('flashcards')
          .select()
          .eq('en_level', level)
          .order('id', ascending: true);

      return response.map((json) => Flashcard.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error getting flashcards by CEFR level: $e');
      throw Exception('Failed to load flashcards by CEFR level: $e');
    }
  }

  // Hàm lấy flashcards theo cấp độ HSK
  Future<List<Flashcard>> getFlashcardsByCnLevel(String level) async {
    try {
      // Kiểm tra level không null và không rỗng
      if (level.isEmpty) {
        return await getAllFlashcards();
      }

      final response = await _client
          .from('flashcards')
          .select()
          .eq('cn_level', level)
          .order('id', ascending: true);

      return response.map((json) => Flashcard.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error getting flashcards by HSK level: $e');
      throw Exception('Failed to load flashcards by HSK level: $e');
    }
  }

  // Hàm tìm kiếm từ vựng
  Future<List<Flashcard>> searchFlashcardsByKeyword(String keyword) async {
    try {
      // Kiểm tra keyword không null và không rỗng
      if (keyword.isEmpty) {
        return await getAllFlashcards();
      }

      final response = await _client
          .from('flashcards')
          .select()
          .or('vietnamese.ilike.%$keyword%,'
              'english.ilike.%$keyword%,'
              'jp_kanji.ilike.%$keyword%,'
              'jp_reading.ilike.%$keyword%,'
              'cn_character.ilike.%$keyword%')
          .order('id', ascending: true);

      return response.map((json) => Flashcard.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error searching flashcards: $e');
      throw Exception('Failed to search flashcards: $e');
    }
  }

  // Hàm lấy flashcards theo danh sách ID
  Future<List<Flashcard>> getFlashcardsByIds(List<String> ids) async {
    try {
      if (ids.isEmpty) return [];

      // Xây dựng query filter thủ công
      List<Flashcard> allCards = await getAllFlashcards();
      return allCards.where((card) => ids.contains(card.id)).toList();
    } catch (e) {
      print('❌ Error getting flashcards by IDs: $e');
      throw Exception('Failed to load flashcards by IDs: $e');
    }
  }

  // Hàm đếm tổng số flashcards
  Future<int> countFlashcards() async {
    try {
      final response = await _client.from('flashcards').select('id');

      return response.length;
    } catch (e) {
      print('❌ Error counting flashcards: $e');
      return 0;
    }
  }

  // Hàm đếm flashcards theo cấp độ
  Future<Map<String, int>> countFlashcardsByLevel() async {
    try {
      final Map<String, int> counts = {};

      // Lấy tất cả cards và đếm thủ công
      final allCards = await getAllFlashcards();

      // Đếm theo JLPT - Sử dụng null check an toàn
      final jpLevels = ['N1', 'N2', 'N3', 'N4', 'N5'];
      for (var level in jpLevels) {
        counts['JLPT_$level'] =
            allCards.where((card) => card.jpLevel == level).length;
      }

      // Đếm theo CEFR
      final enLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
      for (var level in enLevels) {
        counts['CEFR_$level'] =
            allCards.where((card) => card.enLevel == level).length;
      }

      // Đếm theo HSK
      final cnLevels = ['HSK1', 'HSK2', 'HSK3', 'HSK4', 'HSK5', 'HSK6'];
      for (var level in cnLevels) {
        counts['HSK_$level'] =
            allCards.where((card) => card.cnLevel == level).length;
      }

      return counts;
    } catch (e) {
      print('❌ Error counting flashcards by level: $e');
      return {};
    }
  }

  // Hàm lấy các cấp độ có sẵn
  Future<Map<String, List<String>>> getAvailableLevels() async {
    try {
      final allCards = await getAllFlashcards();

      // Lấy các cấp độ duy nhất - Sử dụng null check an toàn
      final jpLevels = allCards
          .where((card) => card.jpLevel != null && card.jpLevel!.isNotEmpty)
          .map((card) => card.jpLevel!)
          .toSet()
          .toList()
        ..sort();

      final enLevels = allCards
          .where((card) => card.enLevel != null && card.enLevel!.isNotEmpty)
          .map((card) => card.enLevel!)
          .toSet()
          .toList()
        ..sort();

      final cnLevels = allCards
          .where((card) => card.cnLevel != null && card.cnLevel!.isNotEmpty)
          .map((card) => card.cnLevel!)
          .toSet()
          .toList()
        ..sort();

      return {
        'jpLevels': jpLevels,
        'enLevels': enLevels,
        'cnLevels': cnLevels,
      };
    } catch (e) {
      print('❌ Error getting available levels: $e');
      return {
        'jpLevels': [],
        'enLevels': [],
        'cnLevels': [],
      };
    }
  }

  // Hàm lấy flashcards phân trang
  Future<List<Flashcard>> getFlashcardsPaged({
    int page = 0,
    int pageSize = 50,
    String? jpLevel,
    String? enLevel,
    String? cnLevel,
    String? sortBy = 'id',
    bool ascending = true,
  }) async {
    try {
      print('📡 Fetching page $page with size $pageSize...');

      dynamic query = _client.from('flashcards').select();

      // Áp dụng filter - với null check
      if (jpLevel != null && jpLevel.isNotEmpty) {
        query = query.eq('jp_level', jpLevel);
      }

      if (enLevel != null && enLevel.isNotEmpty) {
        query = query.eq('en_level', enLevel);
      }

      if (cnLevel != null && cnLevel.isNotEmpty) {
        query = query.eq('cn_level', cnLevel);
      }

      // Áp dụng sort - với null check
      if (sortBy != null && sortBy.isNotEmpty) {
        query = query.order(sortBy, ascending: ascending);
      }

      // Áp dụng phân trang
      final start = page * pageSize;
      final end = start + pageSize - 1;
      query = query.range(start, end);

      final response = await query;

      print('📥 Loaded ${response.length} flashcards from page $page');
      return response.map((json) => Flashcard.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error getting paged flashcards: $e');
      throw Exception('Failed to load paged flashcards: $e');
    }
  }

  // Hàm kiểm tra kết nối
  Future<bool> testConnection() async {
    try {
      await _client.from('flashcards').select().limit(1);
      return true;
    } catch (e) {
      print('❌ Connection test failed: $e');
      return false;
    }
  }

  // Hàm lấy thống kê nhanh
  Future<Map<String, dynamic>> getQuickStats() async {
    try {
      final allCards = await getAllFlashcards();

      // Đếm các trường không null
      final hasEnglish = allCards
          .where((card) => card.english != null && card.english!.isNotEmpty)
          .length;
      final hasJpKanji = allCards
          .where((card) => card.jpKanji != null && card.jpKanji!.isNotEmpty)
          .length;
      final hasCnCharacter = allCards
          .where((card) =>
              card.cnCharacter != null && card.cnCharacter!.isNotEmpty)
          .length;

      return {
        'total': allCards.length,
        'hasEnglish': hasEnglish,
        'hasJpKanji': hasJpKanji,
        'hasCnCharacter': hasCnCharacter,
        'hasJpLevel': allCards
            .where((card) => card.jpLevel != null && card.jpLevel!.isNotEmpty)
            .length,
        'hasEnLevel': allCards
            .where((card) => card.enLevel != null && card.enLevel!.isNotEmpty)
            .length,
        'hasCnLevel': allCards
            .where((card) => card.cnLevel != null && card.cnLevel!.isNotEmpty)
            .length,
      };
    } catch (e) {
      print('❌ Error getting quick stats: $e');
      return {
        'total': 0,
        'hasEnglish': 0,
        'hasJpKanji': 0,
        'hasCnCharacter': 0,
        'hasJpLevel': 0,
        'hasEnLevel': 0,
        'hasCnLevel': 0,
      };
    }
  }

  // Sync study status lên Supabase
  Future<void> syncStudyStatus(String cardId, String studyStatus) async {
    try {
      final user = SupabaseConfig.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('🔄 Syncing study status for card $cardId: $studyStatus');

      await _client
          .from('flashcards')
          .update({
            'study_status': studyStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', cardId)
          .eq('user_id', user.id);

      print('✅ Synced study status for card $cardId');
    } catch (e) {
      print('❌ Error syncing study status: $e');
      rethrow;
    }
  }

// Sync multiple cards
  Future<void> syncMultipleStudyStatus(Map<String, String> updates) async {
    try {
      final user = SupabaseConfig.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('🔄 Syncing ${updates.length} study statuses');

      for (var entry in updates.entries) {
        await _client
            .from('flashcards')
            .update({
              'study_status': entry.value,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', entry.key)
            .eq('user_id', user.id);
      }

      print('✅ Synced ${updates.length} study statuses');
    } catch (e) {
      print('❌ Error syncing study statuses: $e');
      rethrow;
    }
  }

  Future<Map<String, String>> loadStudyStatus() async {
    try {
      final user = SupabaseConfig.currentUser;
      if (user == null) {
        print('⚠️ User not authenticated');
        return {};
      }

      print('📥 Loading study statuses from Supabase...');

      final Map<String, String> statusMap = {};
      int page = 0;
      int pageSize = 500;
      bool hasMore = true;

      while (hasMore) {
        final from = page * pageSize;
        final to = from + pageSize - 1;

        print('📄 Fetching page ${page + 1} (range: $from - $to)');

        final response = await _client
            .from('flashcards')
            .select('id, study_status')
            .eq('user_id', user.id)
            .range(from, to);

        // KIỂM TRA RESPONSE KHÔNG NULL
        if (response == null) {
          print('⚠️ Response is null');
          hasMore = false;
          break;
        }

        if (response.isEmpty) {
          hasMore = false;
          break;
        }

        for (var item in response) {
          // KIỂM TRA ITEM VÀ ID KHÔNG NULL
          if (item != null && item['id'] != null) {
            final id = item['id'].toString();
            final status = item['study_status']?.toString() ?? 'new';
            statusMap[id] = status;
          }
        }

        if (response.length < pageSize) {
          hasMore = false;
        }

        page++;
      }

      print('✅ Loaded ${statusMap.length} study statuses');
      return statusMap;
    } catch (e) {
      print('❌ Error loading study statuses: $e');
      return {};
    }
  }

  // ==================== UNSUPPORTED METHODS ====================
  // Các phương thức này không được hỗ trợ vì Supabase chỉ đọc

  @override
  Future<Flashcard> addFlashcard(Flashcard flashcard) {
    throw UnsupportedError(
        'Cannot add to Supabase. Please use Local database for adding cards.');
  }

  @override
  Future<List<Flashcard>> addMultipleFlashcards(List<Flashcard> flashcards) {
    throw UnsupportedError(
        'Cannot add to Supabase. Please use Local database for adding cards.');
  }

  @override
  Future<Flashcard> updateFlashcard(Flashcard flashcard) {
    throw UnsupportedError(
        'Cannot update Supabase. Please use Local database for updating cards.');
  }

  @override
  Future<void> deleteFlashcard(String id) {
    throw UnsupportedError(
        'Cannot delete from Supabase. Please use Local database for deleting cards.');
  }

  @override
  Future<void> deleteAllFlashcards() {
    throw UnsupportedError(
        'Cannot delete from Supabase. Please use Local database for deleting cards.');
  }

  @override
  Future<List<Flashcard>> searchFlashcards(String query) {
    throw UnsupportedError(
        'Cannot search in Supabase. Please use Local database for searching.');
  }
}
