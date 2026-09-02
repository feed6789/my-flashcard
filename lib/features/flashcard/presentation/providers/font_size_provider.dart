// lib/features/flashcard/presentation/providers/font_size_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

final fontSizeProvider = StateProvider<Map<String, double>>((ref) => {
  'vietnamese': 28.0,
  'english': 20.0,
  'jpKanji': 24.0,
  'jpReading': 16.0,
  'jpDetailType': 16.0,
  'jpLevel': 16.0,
  'enLevel': 16.0,
  'hanViet': 20.0,
  'cnCharacter': 24.0,
  'cnPinyin': 16.0,
  'cnLevel': 16.0,
  'exampleSentence': 16.0,
  'contextNote': 16.0,
});