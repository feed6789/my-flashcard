import 'package:flashcard_app/features/flashcard/data/models/flashcard_model.dart';

// Interface cho các nguồn dữ liệu
abstract class FlashcardSource {
  Future<List<Flashcard>> getAllFlashcards();
  Future<Flashcard> addFlashcard(Flashcard flashcard);
  Future<List<Flashcard>> addMultipleFlashcards(List<Flashcard> flashcards);
  Future<Flashcard> updateFlashcard(Flashcard flashcard);
  Future<void> deleteFlashcard(String id);
  Future<void> deleteAllFlashcards();
  Future<List<Flashcard>> searchFlashcards(String query);
}