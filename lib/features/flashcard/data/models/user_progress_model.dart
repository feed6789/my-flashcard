class UserProgress {
  final String id;
  final String userId;
  final int flashcardId; // Đổi từ String sang int
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

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      flashcardId: json['flashcard_id'] is String 
          ? int.tryParse(json['flashcard_id']) ?? 0 
          : json['flashcard_id'] ?? 0,
      studyStatus: json['study_status'] ?? 'new',
      srsInterval: json['srs_interval'] ?? 0,
      srsEaseFactor: json['srs_ease_factor']?.toDouble() ?? 2.5,
      srsNextReview: json['srs_next_review'] != null 
          ? DateTime.parse(json['srs_next_review']) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
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