import 'package:flashcard_app/core/database/local_database.dart';
import 'package:flashcard_app/features/flashcard/data/datasources/flashcard_source.dart';
import 'package:flashcard_app/features/flashcard/data/models/flashcard_model.dart';

class LocalSource implements FlashcardSource {
  final LocalDatabase _localDb = LocalDatabase();

  @override
  Future<List<Flashcard>> getAllFlashcards() async {
    try {
      return await _localDb.getAllFlashcards();
    } catch (e) {
      print('❌ Error getting all flashcards: $e');
      return [];
    }
  }

  @override
  Future<Flashcard> addFlashcard(Flashcard flashcard) async {
    try {
      print('🔄 Adding flashcard to local database...');
      print('📝 Vietnamese: ${flashcard.vietnamese}');
      
      // Tạo ID mới với timestamp + random để đảm bảo unique
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = DateTime.now().microsecondsSinceEpoch;
      final newId = 'local_${timestamp}_${random}';
      
      final newCard = Flashcard(
        id: newId,
        vietnamese: flashcard.vietnamese,
        jpKanji: flashcard.jpKanji,
        jpReading: flashcard.jpReading,
        jpType: flashcard.jpType,
        jpDetailType: flashcard.jpDetailType,
        jpLevel: flashcard.jpLevel,
        english: flashcard.english,
        enIpa: flashcard.enIpa,
        enLevel: flashcard.enLevel,
        hanViet: flashcard.hanViet,
        cnCharacter: flashcard.cnCharacter,
        cnPinyin: flashcard.cnPinyin,
        cnLevel: flashcard.cnLevel,
        exampleSentence: flashcard.exampleSentence,
        contextNote: flashcard.contextNote,
      );
      
      print('🆔 Generated ID: ${newCard.id}');
      
      final result = await _localDb.insertFlashcard(newCard);
      print('✅ Flashcard added successfully: ${result.vietnamese}');
      return result;
      
    } catch (e) {
      print('❌ Error adding flashcard: $e');
      print('📝 Flashcard data: ${flashcard.toJson()}');
      rethrow;
    }
  }

  @override
  Future<List<Flashcard>> addMultipleFlashcards(List<Flashcard> flashcards) async {
    if (flashcards.isEmpty) {
      print('⚠️ No flashcards to import');
      return [];
    }
    
    try {
      print('🔄 Adding ${flashcards.length} flashcards to local database...');
      
      // Tạo ID cho các card chưa có ID
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      final cardsWithId = flashcards.asMap().entries.map((entry) {
        final index = entry.key;
        final card = entry.value;
        
        // Tạo ID unique cho từng card
        final newId = 'local_${timestamp}_${index}_${DateTime.now().microsecondsSinceEpoch}';
        
        return Flashcard(
          id: card.id.isEmpty || card.id.startsWith('temp_') ? newId : card.id,
          vietnamese: card.vietnamese,
          jpKanji: card.jpKanji,
          jpReading: card.jpReading,
          jpType: card.jpType,
          jpDetailType: card.jpDetailType,
          jpLevel: card.jpLevel,
          english: card.english,
          enIpa: card.enIpa,
          enLevel: card.enLevel,
          hanViet: card.hanViet,
          cnCharacter: card.cnCharacter,
          cnPinyin: card.cnPinyin,
          cnLevel: card.cnLevel,
          exampleSentence: card.exampleSentence,
          contextNote: card.contextNote,
        );
      }).toList();

      print('🆔 Generated IDs for ${cardsWithId.length} cards');
      
      final count = await _localDb.insertMultipleFlashcards(cardsWithId);
      print('✅ Imported $count flashcards successfully');
      
      // Trả về danh sách đã import thành công
      return cardsWithId.take(count).toList();
      
    } catch (e) {
      print('❌ Error adding multiple flashcards: $e');
      rethrow;
    }
  }

  @override
  Future<Flashcard> updateFlashcard(Flashcard flashcard) async {
    try {
      print('🔄 Updating flashcard: ${flashcard.id}');
      final result = await _localDb.updateFlashcard(flashcard);
      print('✅ Flashcard updated: ${result.vietnamese}');
      return result;
    } catch (e) {
      print('❌ Error updating flashcard: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteFlashcard(String id) async {
    try {
      print('🔄 Deleting flashcard: $id');
      await _localDb.deleteFlashcard(id);
      print('✅ Flashcard deleted');
    } catch (e) {
      print('❌ Error deleting flashcard: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteAllFlashcards() async {
    try {
      print('🔄 Deleting all flashcards...');
      await _localDb.deleteAllFlashcards();
      print('✅ All flashcards deleted');
    } catch (e) {
      print('❌ Error deleting all flashcards: $e');
      rethrow;
    }
  }

  @override
  Future<List<Flashcard>> searchFlashcards(String query) async {
    try {
      print('🔍 Searching flashcards: $query');
      final results = await _localDb.searchFlashcards(query);
      print('✅ Found ${results.length} results');
      return results;
    } catch (e) {
      print('❌ Error searching flashcards: $e');
      return [];
    }
  }
}