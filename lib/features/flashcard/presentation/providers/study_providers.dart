import 'package:flashcard_app/features/flashcard/data/models/flashcard_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Auto-flip
final autoFlipEnabledProvider = StateProvider<bool>((ref) => false);
final autoFlipFrontDurationProvider = StateProvider<double>((ref) => 3.0);
final autoFlipBackDurationProvider = StateProvider<double>((ref) => 2.0);

// TTS
final ttsEnabledProvider = StateProvider<bool>((ref) => true);
final ttsAutoPlayProvider = StateProvider<bool>((ref) => false);
final ttsLanguageProvider = StateProvider<String>((ref) => 'ja');

// Font
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

final textAlignmentProvider = StateProvider<TextAlign>((ref) => TextAlign.center);

// SRS
final srsEnabledProvider = StateProvider<bool>((ref) => false);
final reviewQueueProvider = StateProvider<List<Flashcard>>((ref) => []);

// Study Settings
final studySettingsProvider = StateProvider<Map<String, dynamic>>((ref) => {
  'frontFields': ['vietnamese', 'english'],
  'backFields': [
    'vietnamese', 'english', 'jpKanji', 'jpReading', 
    'jpDetailType', 'jpLevel', 'enLevel', 
    'cnCharacter', 'cnPinyin', 'cnLevel',
    'exampleSentence', 'contextNote'
  ],
});

// Status indicators
final isAutoFlippingProvider = StateProvider<bool>((ref) => false);
final isTtsPlayingProvider = StateProvider<bool>((ref) => false);