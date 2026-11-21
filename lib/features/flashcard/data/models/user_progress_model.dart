class UserProgress {
  final String id;
  final String userId;
  final int flashcardId; // bigint trong Supabase
  final String studyStatus;
  final int srsInterval;
  final double srsEaseFactor;
  final DateTime? srsNextReview;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  UserProgress({
    required this.id,
    required this.userId,
    required this.flashcardId,
    required this.studyStatus,
    required this.srsInterval,
    required this.srsEaseFactor,
    this.srsNextReview,
    this.updatedAt,
    this.createdAt,
  });

  /// Parse flashcard_id an toàn: chấp nhận int, numeric string, hoặc local id
  static int _parseFlashcardId(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      // Chỉ parse được nếu là số thuần
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      flashcardId: _parseFlashcardId(json['flashcard_id']),
      studyStatus: json['study_status'] ?? 'new',
      srsInterval: (json['srs_interval'] as num?)?.toInt() ?? 0,
      srsEaseFactor: (json['srs_ease_factor'] as num?)?.toDouble() ?? 2.5,
      srsNextReview: json['srs_next_review'] != null
          ? DateTime.tryParse(json['srs_next_review'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'flashcard_id': flashcardId,
      'study_status': studyStatus,
      'srs_interval': srsInterval,
      'srs_ease_factor': srsEaseFactor,
      'srs_next_review': srsNextReview?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Chỉ gửi lên Supabase những field cần thiết
  Map<String, dynamic> toSupabaseJson({required String userId}) {
    return {
      'user_id': userId,
      'flashcard_id': flashcardId,
      'study_status': studyStatus,
      'srs_interval': srsInterval,
      'srs_ease_factor': srsEaseFactor,
      'srs_next_review': srsNextReview?.toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  UserProgress copyWith({
    String? id,
    String? userId,
    int? flashcardId,
    String? studyStatus,
    int? srsInterval,
    double? srsEaseFactor,
    DateTime? srsNextReview,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) {
    return UserProgress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      flashcardId: flashcardId ?? this.flashcardId,
      studyStatus: studyStatus ?? this.studyStatus,
      srsInterval: srsInterval ?? this.srsInterval,
      srsEaseFactor: srsEaseFactor ?? this.srsEaseFactor,
      srsNextReview: srsNextReview ?? this.srsNextReview,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
