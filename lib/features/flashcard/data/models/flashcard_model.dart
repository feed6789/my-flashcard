class Flashcard {
  final String id;
  final String vietnamese;
  final String? jpKanji;
  final String? jpReading;
  final String? jpType;
  final String? jpDetailType;
  final String? jpLevel;
  final String? english;
  final String? enIpa;
  final String? enLevel;
  final String? hanViet;
  final String? cnCharacter;
  final String? cnPinyin;
  final String? cnLevel;
  final String? exampleSentence;
  final String? contextNote;
  final DateTime? nextReview;
  final int? interval;
  final double? easeFactor;
  final DateTime? createdAt;
  final String? studyStatus;

  Flashcard({
    required this.id,
    required this.vietnamese,
    this.jpKanji,
    this.jpReading,
    this.jpType,
    this.jpDetailType,
    this.jpLevel,
    this.english,
    this.enIpa,
    this.enLevel,
    this.hanViet,
    this.cnCharacter,
    this.cnPinyin,
    this.cnLevel,
    this.exampleSentence,
    this.contextNote,
    this.nextReview,
    this.interval,
    this.easeFactor,
    this.createdAt,
    this.studyStatus,
  });

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    // Xử lý ID từ int8 của Supabase
    String idValue;
    if (json['id'] is int) {
      idValue = json['id'].toString();
    } else if (json['id'] is String) {
      idValue = json['id'] as String;
    } else {
      idValue = '';
    }
    
    return Flashcard(
      id: idValue,
      vietnamese: json['vietnamese'] ?? '',
      jpKanji: json['jp_kanji'],
      jpReading: json['jp_reading'],
      jpType: json['jp_type'],
      jpDetailType: json['jp_detail_type'],
      jpLevel: json['jp_level'],
      english: json['english'],
      enIpa: json['en_ipa'],
      enLevel: json['en_level'],
      hanViet: json['han_viet'],
      cnCharacter: json['cn_character'],
      cnPinyin: json['cn_pinyin'],
      cnLevel: json['cn_level'],
      exampleSentence: json['example_sentence'],
      contextNote: json['context_note'],
      nextReview: json['next_review'] != null 
          ? DateTime.parse(json['next_review']) 
          : null,
      interval: json['interval'],
      easeFactor: json['ease_factor']?.toDouble(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      studyStatus: json['study_status'] ?? 'new',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vietnamese': vietnamese,
      'jp_kanji': jpKanji,
      'jp_reading': jpReading,
      'jp_type': jpType,
      'jp_detail_type': jpDetailType,
      'jp_level': jpLevel,
      'english': english,
      'en_ipa': enIpa,
      'en_level': enLevel,
      'han_viet': hanViet,
      'cn_character': cnCharacter,
      'cn_pinyin': cnPinyin,
      'cn_level': cnLevel,
      'example_sentence': exampleSentence,
      'context_note': contextNote,
      'next_review': nextReview?.toIso8601String(),
      'interval': interval,
      'ease_factor': easeFactor,
      'study_status': studyStatus,
    };
  }

  // THÊM PHƯƠNG THỨC copyWith
  Flashcard copyWith({
    String? id,
    String? vietnamese,
    String? jpKanji,
    String? jpReading,
    String? jpType,
    String? jpDetailType,
    String? jpLevel,
    String? english,
    String? enIpa,
    String? enLevel,
    String? hanViet,
    String? cnCharacter,
    String? cnPinyin,
    String? cnLevel,
    String? exampleSentence,
    String? contextNote,
    DateTime? nextReview,
    int? interval,
    double? easeFactor,
    DateTime? createdAt,
    String? studyStatus,
  }) {
    return Flashcard(
      id: id ?? this.id,
      vietnamese: vietnamese ?? this.vietnamese,
      jpKanji: jpKanji ?? this.jpKanji,
      jpReading: jpReading ?? this.jpReading,
      jpType: jpType ?? this.jpType,
      jpDetailType: jpDetailType ?? this.jpDetailType,
      jpLevel: jpLevel ?? this.jpLevel,
      english: english ?? this.english,
      enIpa: enIpa ?? this.enIpa,
      enLevel: enLevel ?? this.enLevel,
      hanViet: hanViet ?? this.hanViet,
      cnCharacter: cnCharacter ?? this.cnCharacter,
      cnPinyin: cnPinyin ?? this.cnPinyin,
      cnLevel: cnLevel ?? this.cnLevel,
      exampleSentence: exampleSentence ?? this.exampleSentence,
      contextNote: contextNote ?? this.contextNote,
      nextReview: nextReview ?? this.nextReview,
      interval: interval ?? this.interval,
      easeFactor: easeFactor ?? this.easeFactor,
      createdAt: createdAt ?? this.createdAt,
      studyStatus: studyStatus ?? this.studyStatus,
    );
  }
}