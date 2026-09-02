import 'package:flashcard_app/features/flashcard/data/datasources/flashcard_source.dart';
import 'package:flashcard_app/features/flashcard/data/datasources/local_source.dart';
import 'package:flashcard_app/features/flashcard/data/datasources/supabase_source.dart';
import 'package:flashcard_app/features/flashcard/data/models/flashcard_model.dart';

class FlashcardRepository {
  final SupabaseSource _supabaseSource = SupabaseSource();
  final LocalSource _localSource = LocalSource();

  // ============ SUPABASE (Only Read) ============
  Future<List<Flashcard>> getSupabaseFlashcards() async {
    return await _supabaseSource.getAllFlashcards();
  }

  // ============ LOCAL (Full CRUD) ============
  Future<List<Flashcard>> getLocalFlashcards() async {
    return await _localSource.getAllFlashcards();
  }

  Future<Flashcard> addLocalFlashcard(Flashcard flashcard) async {
    return await _localSource.addFlashcard(flashcard);
  }

  Future<List<Flashcard>> addMultipleLocalFlashcards(List<Flashcard> flashcards) async {
    return await _localSource.addMultipleFlashcards(flashcards);
  }

  Future<Flashcard> updateLocalFlashcard(Flashcard flashcard) async {
    return await _localSource.updateFlashcard(flashcard);
  }

  Future<void> deleteLocalFlashcard(String id) async {
    await _localSource.deleteFlashcard(id);
  }

  Future<void> deleteAllLocalFlashcards() async {
    await _localSource.deleteAllFlashcards();
  }

  Future<List<Flashcard>> searchLocalFlashcards(String query) async {
    return await _localSource.searchFlashcards(query);
  }

  // ============ COMBINED ============
  // Lấy cả hai nguồn (dùng cho học tập)
  Future<List<Flashcard>> getAllFlashcards() async {
    final supabaseCards = await _supabaseSource.getAllFlashcards();
    final localCards = await _localSource.getAllFlashcards();
    return [...supabaseCards, ...localCards];
  }
}