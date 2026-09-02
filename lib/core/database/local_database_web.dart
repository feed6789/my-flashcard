// Chỉ dùng cho web
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flashcard_app/features/flashcard/data/models/flashcard_model.dart';

class LocalDatabaseWeb {
  static final LocalDatabaseWeb _instance = LocalDatabaseWeb._internal();
  factory LocalDatabaseWeb() => _instance;
  LocalDatabaseWeb._internal();

  Future<List<Flashcard>> getAllFlashcards() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('flashcards');
    if (data == null) return [];
    
    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((json) => Flashcard.fromJson(json)).toList();
  }

  Future<void> insertFlashcard(Flashcard flashcard) async {
    final cards = await getAllFlashcards();
    cards.insert(0, flashcard);
    await _saveAll(cards);
  }

  Future<void> insertMultipleFlashcards(List<Flashcard> flashcards) async {
    final cards = await getAllFlashcards();
    cards.insertAll(0, flashcards);
    await _saveAll(cards);
  }

  Future<void> updateFlashcard(Flashcard flashcard) async {
    final cards = await getAllFlashcards();
    final index = cards.indexWhere((c) => c.id == flashcard.id);
    if (index != -1) {
      cards[index] = flashcard;
      await _saveAll(cards);
    }
  }

  Future<void> deleteFlashcard(String id) async {
    final cards = await getAllFlashcards();
    cards.removeWhere((c) => c.id == id);
    await _saveAll(cards);
  }

  Future<void> deleteAllFlashcards() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('flashcards');
  }

  Future<List<Flashcard>> searchFlashcards(String query) async {
    final cards = await getAllFlashcards();
    return cards.where((c) =>
      c.vietnamese.contains(query) ||
      (c.english?.contains(query) ?? false) ||
      (c.jpKanji?.contains(query) ?? false)
    ).toList();
  }

  Future<void> _saveAll(List<Flashcard> cards) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = cards.map((c) => c.toJson()).toList();
    await prefs.setString('flashcards', jsonEncode(jsonList));
  }
}