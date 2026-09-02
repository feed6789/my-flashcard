// lib/features/study/presentation/pages/study_page.dart

import 'package:flip_card/flip_card_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flashcard_app/features/flashcard/data/models/flashcard_model.dart';
import 'package:flashcard_app/core/database/local_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==================== PROVIDERS ====================

final studySettingsProvider = StateProvider<Map<String, dynamic>>((ref) => {
      'frontFields': ['vietnamese', 'english'],
      'backFields': [
        'vietnamese',
        'english',
        'jpKanji',
        'jpReading',
        'jpDetailType',
        'jpLevel',
        'enLevel',
        'cnCharacter',
        'cnPinyin',
        'cnLevel',
        'exampleSentence',
        'contextNote'
      ],
    });

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

final textAlignmentProvider =
    StateProvider<TextAlign>((ref) => TextAlign.center);

// ==================== STUDY PAGE ====================

class StudyPage extends ConsumerStatefulWidget {
  final List<Flashcard> flashcards;
  final int initialIndex;

  const StudyPage({
    super.key,
    required this.flashcards,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends ConsumerState<StudyPage> {
  // Page Controller
  late PageController _pageController;
  int _currentIndex = 0;

  // Flip Card Controllers
  final Map<int, FlipCardController> _controllers = {};

  // Danh sách hiển thị (được lọc từ widget.flashcards)
  List<Flashcard> _displayCards = [];

  // Shuffle
  bool _isShuffled = false;

  // Filter status
  final Map<String, bool> _statusFilters = {
    'new': true,
    'learning': true,
    'reviewing': true,
    'mastered': true,
  };

  // Status labels
  final Map<String, String> _statusLabels = {
    'new': '🆕 New',
    'learning': '📖 Learning',
    'reviewing': '🔄 Reviewing',
    'mastered': '⭐ Mastered',
  };

  // ==================== INIT ====================

  @override
  void initState() {
    super.initState();

    // 1. Khởi tạo PageController TRƯỚC
    _currentIndex = widget.initialIndex.clamp(0, widget.flashcards.length - 1);
    _pageController = PageController(initialPage: _currentIndex);

    // 2. Khởi tạo danh sách hiển thị từ widget.flashcards
    _displayCards = List<Flashcard>.from(widget.flashcards);

    // 3. Khởi tạo controllers
    for (int i = 0; i < _displayCards.length; i++) {
      _controllers[i] = FlipCardController();
    }

    // 4. Load settings
    _loadSettingsFromPrefs();
    _loadFontSizesFromPrefs();
    _loadTextAlignmentFromPrefs();

    // 5. Load dữ liệu từ database (sau khi đã khởi tạo xong)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDataFromDatabase();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadDataFromDatabase() async {
    try {
      final localDb = LocalDatabase();
      final allCards = await localDb.getAllFlashcards();

      // Lọc danh sách theo ID của widget.flashcards
      final filteredIds = widget.flashcards.map((c) => c.id).toSet();
      final filteredCards =
          allCards.where((c) => filteredIds.contains(c.id)).toList();

      // Sắp xếp theo thứ tự của widget.flashcards
      final orderMap = <String, int>{};
      for (int i = 0; i < widget.flashcards.length; i++) {
        orderMap[widget.flashcards[i].id] = i;
      }
      filteredCards
          .sort((a, b) => (orderMap[a.id] ?? 0).compareTo(orderMap[b.id] ?? 0));

      setState(() {
        _displayCards = List<Flashcard>.from(filteredCards);
        _isShuffled = false;
        _currentIndex = 0;
      });

      // Kiểm tra _pageController đã được khởi tạo chưa
      _controllers.clear();
      for (int i = 0; i < _displayCards.length; i++) {
        _controllers[i] = FlipCardController();
      }

      // Chỉ gọi jumpToPage nếu _pageController đã được khởi tạo
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }

      print('✅ Loaded ${_displayCards.length} cards from database');
    } catch (e) {
      print('❌ Error loading data: $e');
      setState(() {
        _displayCards = List<Flashcard>.from(widget.flashcards);
      });
    }
  }

  // ==================== GET CURRENT CARDS ====================

  List<Flashcard> get _currentCards {
    // Lọc theo study status nếu không phải "All"
    if (_statusFilters.values.every((v) => v == true)) {
      // Tất cả đều được chọn -> hiển thị tất cả
      if (_isShuffled) {
        final shuffled = List<Flashcard>.from(_displayCards);
        shuffled.shuffle();
        return shuffled;
      }
      return _displayCards;
    }

    // Lọc theo các status được chọn
    final selectedStatuses = _statusFilters.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();

    final filtered = _displayCards
        .where((card) =>
            card.studyStatus != null &&
            selectedStatuses.contains(card.studyStatus))
        .toList();

    if (_isShuffled) {
      final shuffled = List<Flashcard>.from(filtered);
      shuffled.shuffle();
      return shuffled;
    }
    return filtered;
  }

  // ==================== SHUFFLE ====================

  void _toggleShuffle(bool value) {
    setState(() {
      _isShuffled = value;
      _currentIndex = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    });
  }

  // ==================== UPDATE STUDY STATUS ====================

  Future<void> _updateStudyStatus(String cardId, String newStatus) async {
    try {
      print('🔄 Updating status for card $cardId to $newStatus');

      final localDb = LocalDatabase();

      // 1. Lấy tất cả cards từ database
      final allCards = await localDb.getAllFlashcards();
      final cardIndex = allCards.indexWhere((c) => c.id == cardId);

      if (cardIndex == -1) {
        print('❌ Card not found in database');
        return;
      }

      // 2. Cập nhật database
      final updatedCard = allCards[cardIndex].copyWith(studyStatus: newStatus);
      await localDb.updateFlashcard(updatedCard);
      print('✅ Database updated: ${updatedCard.vietnamese} -> $newStatus');

      // 3. Cập nhật danh sách hiển thị trong Study Page
      final displayIndex = _displayCards.indexWhere((c) => c.id == cardId);
      if (displayIndex != -1) {
        setState(() {
          _displayCards[displayIndex] = updatedCard;
        });
        print('✅ Updated display list at index $displayIndex');
      }

      // 4. Thông báo
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Status updated to ${_statusLabels[newStatus] ?? newStatus}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('❌ Error updating status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to update status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    final flashcards = _currentCards;
    final totalCards = flashcards.length;

    if (totalCards == 0) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Study'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No flashcards to study',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please apply filters on the main page',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(totalCards),
      body: Column(
        children: [
          // Shuffle status
          if (_isShuffled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange.shade50,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shuffle, size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    '🔀 Shuffled mode',
                    style: TextStyle(fontSize: 14, color: Colors.orange),
                  ),
                ],
              ),
            ),
          // Filter info
          if (widget.flashcards.length > 0 &&
              _displayCards.length < widget.flashcards.length)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.filter_alt, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Showing ${_displayCards.length} of ${widget.flashcards.length} cards',
                    style: const TextStyle(fontSize: 14, color: Colors.blue),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemCount: totalCards,
                  itemBuilder: (context, index) {
                    final card = flashcards[index];

                    if (!_controllers.containsKey(index)) {
                      _controllers[index] = FlipCardController();
                    }

                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: FlipCard(
                        key: ValueKey('${card.id}_${card.studyStatus}_$index'),
                        controller: _controllers[index]!,
                        flipOnTouch: true,
                        direction: FlipDirection.HORIZONTAL,
                        front: _buildFrontCard(card),
                        back: _buildBackCard(card),
                      ),
                    );
                  },
                ),
                // Previous button - bên trái
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(Icons.chevron_left, size: 40),
                      onPressed: _currentIndex > 0
                          ? () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          : null,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withOpacity(0.3),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Next button - bên phải
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right, size: 40),
                      onPressed: _currentIndex < totalCards - 1
                          ? () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          : null,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withOpacity(0.3),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildBottomControls(),
        ],
      ),
    );
  }

  // ==================== APP BAR ====================

  PreferredSizeWidget _buildAppBar(int totalCards) {
    return AppBar(
      title: const Text('Study'),
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      actions: [
        // Font size button
        IconButton(
          icon: const Icon(Icons.text_fields),
          onPressed: () => _showFontSizeDialog(context),
          tooltip: 'Font size',
        ),
        // Settings button
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => _showSettingsDialog(context),
          tooltip: 'Customize cards',
        ),
        // Progress
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              '${_currentIndex + 1}/$totalCards',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== BOTTOM CONTROLS ====================

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status filter row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // All button
              _buildStatusFilterChip(
                label: 'All',
                isSelected: _statusFilters.values.every((v) => v == true),
                onTap: () {
                  setState(() {
                    final allSelected =
                        _statusFilters.values.every((v) => v == true);
                    if (allSelected) {
                      // Nếu đang all, bỏ chọn tất cả
                      _statusFilters.updateAll((key, value) => false);
                    } else {
                      // Nếu không all, chọn tất cả
                      _statusFilters.updateAll((key, value) => true);
                    }
                    _currentIndex = 0;
                    if (_pageController.hasClients) {
                      _pageController.jumpToPage(0);
                    }
                  });
                },
                color: Colors.purple,
              ),
              ..._statusFilters.keys.map((status) {
                return _buildStatusFilterChip(
                  label: _statusLabels[status] ?? status,
                  isSelected: _statusFilters[status] ?? false,
                  onTap: () {
                    setState(() {
                      _statusFilters[status] =
                          !(_statusFilters[status] ?? false);
                      _currentIndex = 0;
                      if (_pageController.hasClients) {
                        _pageController.jumpToPage(0);
                      }
                    });
                  },
                  color: _getStatusColor(status),
                );
              }).toList(),
            ],
          ),
          const SizedBox(height: 8),
          // Shuffle toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shuffle, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Switch(
                value: _isShuffled,
                onChanged: _toggleShuffle,
                activeColor: Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                _isShuffled ? 'Shuffle ON' : 'Shuffle OFF',
                style: TextStyle(
                  fontSize: 12,
                  color: _isShuffled ? Colors.orange : Colors.grey,
                  fontWeight: _isShuffled ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Icon(
                Icons.check_circle,
                size: 14,
                color: color,
              )
            else
              Icon(
                Icons.circle_outlined,
                size: 14,
                color: Colors.grey.shade400,
              ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'new':
        return Colors.grey;
      case 'learning':
        return Colors.orange;
      case 'reviewing':
        return Colors.blue;
      case 'mastered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // ==================== BUILD FRONT CARD ====================

  Widget _buildFrontCard(Flashcard card) {
    final settings = ref.watch(studySettingsProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    List<String> frontFields = [];
    final frontData = settings['frontFields'];
    if (frontData is List) {
      frontFields = frontData.whereType<String>().toList();
    } else {
      frontFields = ['vietnamese', 'english'];
    }

    final gradientColors = isDarkMode
        ? const [Color(0xFF1A237E), Color(0xFF0D47A1)]
        : const [Color(0xFFE3F2FD), Color(0xFFBBDEFB)];

    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.black54;
    final badgeColor = isDarkMode ? Colors.blue.shade800 : Colors.blue.shade200;
    final badgeTextColor = isDarkMode ? Colors.white : Colors.blue;
    final hintBgColor = isDarkMode
        ? Colors.white.withOpacity(0.15)
        : Colors.white.withOpacity(0.6);
    final hintTextColor = isDarkMode ? Colors.white70 : Colors.grey;

    if (frontFields.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                'No fields selected for front side',
                style: TextStyle(fontSize: 18, color: textColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please customize in settings',
                style: TextStyle(fontSize: 14, color: subtitleColor),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '📖 Front',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: badgeTextColor,
                      ),
                    ),
                  ),
                  _buildStatusDropdown(card),
                ],
              ),
              const SizedBox(height: 24),
              ..._buildFields(card, frontFields, isDarkMode),
              const SizedBox(height: 24),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: hintBgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app, size: 16, color: hintTextColor),
                    const SizedBox(width: 8),
                    Text(
                      'Tap to flip',
                      style: TextStyle(fontSize: 12, color: hintTextColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== BUILD BACK CARD ====================

  Widget _buildBackCard(Flashcard card) {
    final settings = ref.watch(studySettingsProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    List<String> backFields = [];
    final backData = settings['backFields'];
    if (backData is List) {
      backFields = backData.whereType<String>().toList();
    } else {
      backFields = [
        'vietnamese',
        'english',
        'jpKanji',
        'jpReading',
        'jpDetailType',
        'jpLevel',
        'enLevel',
        'cnCharacter',
        'cnPinyin',
        'cnLevel',
        'exampleSentence',
        'contextNote'
      ];
    }

    final gradientColors = isDarkMode
        ? const [Color(0xFF1B5E20), Color(0xFF2E7D32)]
        : const [Color(0xFFE8F5E9), Color(0xFFC8E6C9)];

    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.black54;
    final badgeColor =
        isDarkMode ? Colors.green.shade800 : Colors.green.shade200;
    final badgeTextColor = isDarkMode ? Colors.white : Colors.green;
    final hintBgColor = isDarkMode
        ? Colors.white.withOpacity(0.15)
        : Colors.white.withOpacity(0.6);
    final hintTextColor = isDarkMode ? Colors.white70 : Colors.grey;

    if (backFields.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                'No fields selected for back side',
                style: TextStyle(fontSize: 18, color: textColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please customize in settings',
                style: TextStyle(fontSize: 14, color: subtitleColor),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '📖 Back',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: badgeTextColor,
                      ),
                    ),
                  ),
                  _buildStatusDropdown(card),
                ],
              ),
              const SizedBox(height: 24),
              ..._buildFields(card, backFields, isDarkMode),
              const SizedBox(height: 24),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: hintBgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app, size: 16, color: hintTextColor),
                    const SizedBox(width: 8),
                    Text(
                      'Tap to flip back',
                      style: TextStyle(fontSize: 12, color: hintTextColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== BUILD FIELDS ====================

  List<Widget> _buildFields(
      Flashcard card, List<String> fields, bool isDarkMode) {
    final fontSizes = ref.watch(fontSizeProvider);
    final textAlignment = ref.watch(textAlignmentProvider);

    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.black54;
    final exampleBgColor =
        isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100;
    final noteBgColor = isDarkMode
        ? Colors.amber.shade900.withOpacity(0.3)
        : Colors.amber.shade50;
    final noteBorderColor =
        isDarkMode ? Colors.amber.shade700 : Colors.amber.shade200;

    final Map<String, Widget Function()> fieldBuilders = {
      'vietnamese': () => Text(
            card.vietnamese,
            style: TextStyle(
              fontSize: fontSizes['vietnamese'] ?? 28.0,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: textAlignment,
          ),
      'english': () => card.english != null
          ? Text(
              card.english!,
              style: TextStyle(
                fontSize: fontSizes['english'] ?? 20.0,
                color: subtitleColor,
              ),
              textAlign: textAlignment,
            )
          : const SizedBox.shrink(),
      'jpKanji': () => card.jpKanji != null
          ? _buildFieldRow(
              '🇯🇵 Kanji',
              card.jpKanji!,
              fontSize: fontSizes['jpKanji'] ?? 24.0,
              isDarkMode: isDarkMode,
              alignment: textAlignment,
            )
          : const SizedBox.shrink(),
      'jpReading': () => card.jpReading != null
          ? _buildFieldRow(
              '🔊 Reading',
              card.jpReading!,
              fontSize: fontSizes['jpReading'] ?? 16.0,
              isDarkMode: isDarkMode,
              alignment: textAlignment,
            )
          : const SizedBox.shrink(),
      'jpType': () => card.jpType != null
          ? _buildFieldRow(
              '📝 JP Type',
              card.jpType!,
              fontSize: fontSizes['jpType'] ?? 16.0,
              isDarkMode: isDarkMode,
              alignment: textAlignment,
            )
          : const SizedBox.shrink(),
      'jpDetailType': () => card.jpDetailType != null
          ? _buildFieldRow(
              '📋 Word Type',
              card.jpDetailType!,
              fontSize: fontSizes['jpDetailType'] ?? 16.0,
              isDarkMode: isDarkMode,
              alignment: textAlignment,
            )
          : const SizedBox.shrink(),
      'jpLevel': () => card.jpLevel != null
          ? _buildFieldRow(
              '📊 JLPT',
              card.jpLevel!,
              fontSize: fontSizes['jpLevel'] ?? 16.0,
              isDarkMode: isDarkMode,
              alignment: textAlignment,
            )
          : const SizedBox.shrink(),
      'enIpa': () => card.enIpa != null
          ? _buildFieldRow(
              '🔊 IPA',
              card.enIpa!,
              fontSize: fontSizes['enIpa'] ?? 16.0,
              isDarkMode: isDarkMode,
              alignment: textAlignment,
            )
          : const SizedBox.shrink(),
      'enLevel': () => card.enLevel != null
          ? _buildFieldRow(
              '📊 CEFR',
              card.enLevel!,
              fontSize: fontSizes['enLevel'] ?? 16.0,
              isDarkMode: isDarkMode,
              alignment: textAlignment,
            )
          : const SizedBox.shrink(),
      'hanViet': () => card.hanViet != null
          ? _buildFieldRow(
              '🇻🇳 Han-Viet',
              card.hanViet!,
              fontSize: fontSizes['hanViet'] ?? 20.0,
              isDarkMode: isDarkMode,
              alignment: textAlignment,
            )
          : const SizedBox.shrink(),
      'cnCharacter': () => card.cnCharacter != null
          ? _buildFieldRow(
              '🇨🇳 Chinese',
              card.cnCharacter!,
              fontSize: fontSizes['cnCharacter'] ?? 24.0,
              isDarkMode: isDarkMode,
              alignment: textAlignment,
            )
          : const SizedBox.shrink(),
      'cnPinyin': () => card.cnPinyin != null
          ? _buildFieldRow(
              '🔊 Pinyin',
              card.cnPinyin!,
              fontSize: fontSizes['cnPinyin'] ?? 16.0,
              isDarkMode: isDarkMode,
              alignment: textAlignment,
            )
          : const SizedBox.shrink(),
      'cnLevel': () => card.cnLevel != null
          ? _buildFieldRow(
              '📊 HSK',
              card.cnLevel!,
              fontSize: fontSizes['cnLevel'] ?? 16.0,
              isDarkMode: isDarkMode,
              alignment: textAlignment,
            )
          : const SizedBox.shrink(),
      'exampleSentence': () => card.exampleSentence != null
          ? _buildFieldRow(
              '💬 Example',
              card.exampleSentence!,
              isExample: true,
              fontSize: fontSizes['exampleSentence'] ?? 16.0,
              isDarkMode: isDarkMode,
              alignment: textAlignment,
            )
          : const SizedBox.shrink(),
      'contextNote': () => card.contextNote != null
          ? _buildFieldRow(
              '📌 Note',
              card.contextNote!,
              isNote: true,
              fontSize: fontSizes['contextNote'] ?? 16.0,
              isDarkMode: isDarkMode,
              alignment: textAlignment,
            )
          : const SizedBox.shrink(),
    };

    List<Widget> result = [];
    for (var field in fields) {
      if (fieldBuilders.containsKey(field)) {
        final widget = fieldBuilders[field]!();
        if (widget is! SizedBox) {
          result.add(widget);
          if (field != fields.last) {
            result.add(const SizedBox(height: 8));
          }
        }
      }
    }
    return result;
  }

  // ==================== FIELD ROW ====================

  Widget _buildFieldRow(
    String label,
    String value, {
    bool isExample = false,
    bool isNote = false,
    double fontSize = 16.0,
    bool isDarkMode = false,
    TextAlign alignment = TextAlign.center,
  }) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.black54;
    final exampleBgColor =
        isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100;
    final noteBgColor = isDarkMode
        ? Colors.amber.shade900.withOpacity(0.3)
        : Colors.amber.shade50;
    final noteBorderColor =
        isDarkMode ? Colors.amber.shade700 : Colors.amber.shade200;

    if (isExample) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: exampleBgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: subtitleColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: fontSize,
                fontStyle: FontStyle.italic,
                color: textColor,
              ),
              textAlign: alignment,
            ),
          ],
        ),
      );
    }

    if (isNote) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: noteBgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: noteBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: subtitleColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: fontSize,
                color: textColor,
              ),
              textAlign: alignment,
            ),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: subtitleColor,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              color: textColor,
            ),
            textAlign: alignment,
          ),
        ),
      ],
    );
  }

  // ==================== STATUS DROPDOWN ====================

  Widget _buildStatusDropdown(Flashcard card) {
    final currentStatus = card.studyStatus ?? 'new';

    final statusColors = {
      'new': Colors.grey,
      'learning': Colors.orange,
      'reviewing': Colors.blue,
      'mastered': Colors.green,
    };

    final statusIcons = {
      'new': Icons.fiber_new,
      'learning': Icons.school,
      'reviewing': Icons.autorenew,
      'mastered': Icons.star,
    };

    final statusList = ['new', 'learning', 'reviewing', 'mastered'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: statusColors[currentStatus]?.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: statusColors[currentStatus] ?? Colors.grey,
          width: 1,
        ),
      ),
      child: DropdownButton<String>(
        value: currentStatus,
        underline: const SizedBox(),
        icon: Icon(
          statusIcons[currentStatus],
          size: 16,
          color: statusColors[currentStatus],
        ),
        style: TextStyle(
          fontSize: 12,
          color: statusColors[currentStatus],
        ),
        items: statusList.map((status) {
          return DropdownMenuItem(
            value: status,
            child: Text(
              _statusLabels[status] ?? status,
              style: const TextStyle(fontSize: 12),
            ),
          );
        }).toList(),
        onChanged: (newStatus) {
          if (newStatus != null && newStatus != currentStatus) {
            _updateStudyStatus(card.id, newStatus);
          }
        },
      ),
    );
  }

  // ==================== SETTINGS DIALOG ====================

  void _showSettingsDialog(BuildContext context) {
    final settings = ref.read(studySettingsProvider);

    List<String> currentFrontFields = [];
    final frontData = settings['frontFields'];
    if (frontData is List) {
      currentFrontFields = frontData.whereType<String>().toList();
    } else {
      currentFrontFields = ['vietnamese', 'english'];
    }

    List<String> currentBackFields = [];
    final backData = settings['backFields'];
    if (backData is List) {
      currentBackFields = backData.whereType<String>().toList();
    } else {
      currentBackFields = [
        'vietnamese',
        'english',
        'jpKanji',
        'jpReading',
        'jpDetailType',
        'jpLevel',
        'enLevel',
        'cnCharacter',
        'cnPinyin',
        'cnLevel',
        'exampleSentence',
        'contextNote'
      ];
    }

    List<String> tempFrontFields = List.from(currentFrontFields);
    List<String> tempBackFields = List.from(currentBackFields);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final List<Map<String, dynamic>> allFields = [
              {'key': 'vietnamese', 'label': '🇻🇳 Vietnamese'},
              {'key': 'english', 'label': '🇬🇧 English'},
              {'key': 'jpKanji', 'label': '🇯🇵 Kanji'},
              {'key': 'jpReading', 'label': '🔊 Reading'},
              {'key': 'jpType', 'label': '📝 Japanese Type'},
              {'key': 'jpDetailType', 'label': '📋 Word Detail Type'},
              {'key': 'jpLevel', 'label': '📊 JLPT Level'},
              {'key': 'enIpa', 'label': '🔊 English IPA'},
              {'key': 'enLevel', 'label': '📊 CEFR Level'},
              {'key': 'hanViet', 'label': '🇻🇳 Han-Viet'},
              {'key': 'cnCharacter', 'label': '🇨🇳 Chinese Character'},
              {'key': 'cnPinyin', 'label': '🔊 Chinese Pinyin'},
              {'key': 'cnLevel', 'label': '📊 HSK Level'},
              {'key': 'exampleSentence', 'label': '💬 Example Sentence'},
              {'key': 'contextNote', 'label': '📌 Context Note'},
            ];

            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.style,
                            color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        const Text(
                          'Customize Cards',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '📖 Front Side',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...allFields.map((field) {
                              final String key = field['key'] as String;
                              final String label = field['label'] as String;
                              final bool isSelected =
                                  tempFrontFields.contains(key);

                              return CheckboxListTile(
                                title: Text(label),
                                value: isSelected,
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      if (!tempFrontFields.contains(key)) {
                                        tempFrontFields.add(key);
                                      }
                                    } else {
                                      tempFrontFields.remove(key);
                                    }
                                  });
                                },
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              );
                            }).toList(),
                            const SizedBox(height: 16),
                            const Divider(),
                            const Text(
                              '📖 Back Side',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...allFields.map((field) {
                              final String key = field['key'] as String;
                              final String label = field['label'] as String;
                              final bool isSelected =
                                  tempBackFields.contains(key);

                              return CheckboxListTile(
                                title: Text(label),
                                value: isSelected,
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      if (!tempBackFields.contains(key)) {
                                        tempBackFields.add(key);
                                      }
                                    } else {
                                      tempBackFields.remove(key);
                                    }
                                  });
                                },
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              tempFrontFields = ['vietnamese', 'english'];
                              tempBackFields = [
                                'vietnamese',
                                'english',
                                'jpKanji',
                                'jpReading',
                                'jpDetailType',
                                'jpLevel',
                                'enLevel',
                                'cnCharacter',
                                'cnPinyin',
                                'cnLevel',
                                'exampleSentence',
                                'contextNote'
                              ];
                            });
                          },
                          child: const Text('Reset Defaults'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final newSettings = {
                              'frontFields': List<String>.from(tempFrontFields),
                              'backFields': List<String>.from(tempBackFields),
                            };
                            ref.read(studySettingsProvider.notifier).state =
                                newSettings;
                            _saveSettingsToPrefs(newSettings);
                            Navigator.pop(context);
                            setState(() {});
                          },
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==================== FONT SIZE DIALOG ====================

  void _showFontSizeDialog(BuildContext context) {
    final currentSizes = ref.read(fontSizeProvider);
    final currentAlignment = ref.read(textAlignmentProvider);

    Map<String, double> tempSizes = Map.from(currentSizes);
    TextAlign tempAlignment = currentAlignment;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final List<Map<String, String>> fontOptions = [
              {'key': 'vietnamese', 'label': '🇻🇳 Vietnamese'},
              {'key': 'english', 'label': '🇬🇧 English'},
              {'key': 'jpKanji', 'label': '🇯🇵 Kanji'},
              {'key': 'jpReading', 'label': '🔊 Reading'},
              {'key': 'jpType', 'label': '📝 Japanese Type'},
              {'key': 'jpDetailType', 'label': '📋 Word Detail Type'},
              {'key': 'jpLevel', 'label': '📊 JLPT Level'},
              {'key': 'enIpa', 'label': '🔊 English IPA'},
              {'key': 'enLevel', 'label': '📊 CEFR Level'},
              {'key': 'hanViet', 'label': '🇻🇳 Han-Viet'},
              {'key': 'cnCharacter', 'label': '🇨🇳 Chinese Character'},
              {'key': 'cnPinyin', 'label': '🔊 Chinese Pinyin'},
              {'key': 'cnLevel', 'label': '📊 HSK Level'},
              {'key': 'exampleSentence', 'label': '💬 Example Sentence'},
              {'key': 'contextNote', 'label': '📌 Context Note'},
            ];

            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.text_fields,
                            color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        const Text(
                          'Text Settings',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            // Text Alignment
                            const Text(
                              'Text Alignment:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildAlignmentChip(
                                  'Left',
                                  TextAlign.left,
                                  tempAlignment,
                                  () {
                                    setState(() {
                                      tempAlignment = TextAlign.left;
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                _buildAlignmentChip(
                                  'Center',
                                  TextAlign.center,
                                  tempAlignment,
                                  () {
                                    setState(() {
                                      tempAlignment = TextAlign.center;
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                _buildAlignmentChip(
                                  'Right',
                                  TextAlign.right,
                                  tempAlignment,
                                  () {
                                    setState(() {
                                      tempAlignment = TextAlign.right;
                                    });
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                            const Divider(),

                            // Font Sizes
                            const Text(
                              'Font Sizes:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...fontOptions.map((option) {
                              final key = option['key']!;
                              final label = option['label']!;
                              final size = tempSizes[key] ?? 16.0;

                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 120,
                                      child: Text(
                                        label,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    Expanded(
                                      child: Slider(
                                        value: size,
                                        min: 10,
                                        max: 40,
                                        divisions: 30,
                                        label: '${size.round()}px',
                                        onChanged: (value) {
                                          setState(() {
                                            tempSizes[key] = value;
                                          });
                                        },
                                      ),
                                    ),
                                    SizedBox(
                                      width: 40,
                                      child: Text(
                                        '${size.round()}px',
                                        style: const TextStyle(fontSize: 12),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              tempSizes = {
                                'vietnamese': 28.0,
                                'english': 20.0,
                                'jpKanji': 24.0,
                                'jpReading': 16.0,
                                'jpType': 16.0,
                                'jpDetailType': 16.0,
                                'jpLevel': 16.0,
                                'enIpa': 16.0,
                                'enLevel': 16.0,
                                'hanViet': 20.0,
                                'cnCharacter': 24.0,
                                'cnPinyin': 16.0,
                                'cnLevel': 16.0,
                                'exampleSentence': 16.0,
                                'contextNote': 16.0,
                              };
                              tempAlignment = TextAlign.center;
                            });
                          },
                          child: const Text('Reset Defaults'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            ref.read(fontSizeProvider.notifier).state =
                                Map.from(tempSizes);
                            ref.read(textAlignmentProvider.notifier).state =
                                tempAlignment;
                            _saveFontSizesToPrefs(tempSizes);
                            _saveTextAlignmentToPrefs(tempAlignment);
                            Navigator.pop(context);
                            setState(() {});
                          },
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==================== HELPER WIDGETS ====================

  Widget _buildAlignmentChip(
    String label,
    TextAlign value,
    TextAlign current,
    VoidCallback onTap,
  ) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ==================== SAVE / LOAD SETTINGS ====================

  Future<void> _saveSettingsToPrefs(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          'study_front_fields', List<String>.from(settings['frontFields']));
      await prefs.setStringList(
          'study_back_fields', List<String>.from(settings['backFields']));
      print('✅ Study settings saved');
    } catch (e) {
      print('❌ Error saving study settings: $e');
    }
  }

  void _loadSettingsFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final frontFields = prefs.getStringList('study_front_fields');
      final backFields = prefs.getStringList('study_back_fields');

      if (frontFields != null && backFields != null) {
        final settings = {
          'frontFields': frontFields,
          'backFields': backFields,
        };
        ref.read(studySettingsProvider.notifier).state = settings;
        print('✅ Loaded study settings');
      }
    } catch (e) {
      print('❌ Error loading study settings: $e');
    }
  }

  Future<void> _saveFontSizesToPrefs(Map<String, double> sizes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, String> stringSizes = {};
      sizes.forEach((key, value) {
        stringSizes[key] = value.toString();
      });
      await prefs.setString('font_sizes', stringSizes.toString());
      print('✅ Font sizes saved');
    } catch (e) {
      print('❌ Error saving font sizes: $e');
    }
  }

  void _loadFontSizesFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString('font_sizes');
      if (data != null && data.isNotEmpty) {
        final Map<String, double> sizes = {};
        final cleaned = data.replaceAll('{', '').replaceAll('}', '');
        final parts = cleaned.split(', ');
        for (var part in parts) {
          final pair = part.split(': ');
          if (pair.length == 2) {
            final key = pair[0].trim();
            final value = double.tryParse(pair[1].trim()) ?? 16.0;
            sizes[key] = value;
          }
        }
        if (sizes.isNotEmpty) {
          ref.read(fontSizeProvider.notifier).state = sizes;
          print('✅ Font sizes loaded');
        }
      }
    } catch (e) {
      print('❌ Error loading font sizes: $e');
    }
  }

  Future<void> _saveTextAlignmentToPrefs(TextAlign alignment) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int value = alignment.index;
      await prefs.setInt('text_alignment', value);
      print('✅ Text alignment saved: $alignment');
    } catch (e) {
      print('❌ Error saving text alignment: $e');
    }
  }

  void _loadTextAlignmentFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? value = prefs.getInt('text_alignment');
      if (value != null) {
        final alignment = TextAlign.values[value];
        ref.read(textAlignmentProvider.notifier).state = alignment;
        print('✅ Text alignment loaded: $alignment');
      }
    } catch (e) {
      print('❌ Error loading text alignment: $e');
    }
  }
}
