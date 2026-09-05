// lib/features/flashcard/presentation/pages/flashcard_list_page.dart

import 'package:flashcard_app/core/providers/theme_provider.dart';
import 'package:flashcard_app/features/flashcard/data/datasources/supabase_source.dart';
import 'package:flashcard_app/features/flashcard/presentation/widgets/color_picker_dialog.dart';
import 'package:flashcard_app/features/flashcard/presentation/widgets/login_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flashcard_app/core/database/local_database.dart';
import 'package:flashcard_app/features/flashcard/data/models/flashcard_model.dart';
import 'package:flashcard_app/features/flashcard/data/repositories/flashcard_repository.dart';
import 'package:flashcard_app/features/flashcard/data/services/excel_import_service.dart';
import 'package:flashcard_app/features/flashcard/presentation/widgets/flashcard_card.dart';
import 'package:flashcard_app/features/flashcard/presentation/widgets/filter_dialog.dart';
import 'package:flashcard_app/features/flashcard/presentation/widgets/settings_dialog.dart';
import 'package:flashcard_app/features/study/presentation/pages/study_page.dart';
import 'package:flashcard_app/core/database/local_database.dart';
import 'package:flashcard_app/core/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==================== PROVIDERS ====================
// Settings provider
final settingsProvider = StateProvider<Map<String, dynamic>>((ref) => {
      'itemsPerPage': 50,
      'showFields': {
        'vietnamese': true,
        'english': true,
        'jpKanji': true,
        'jpReading': true,
        'jpType': true,
        'jpDetailType': true,
        'jpLevel': true,
        'enIpa': true,
        'enLevel': true,
        'hanViet': true,
        'cnCharacter': true,
        'cnPinyin': true,
        'cnLevel': true,
        'exampleSentence': true,
        'contextNote': true,
      },
      'selectedFilters': {
        'jpLevel': [],
        'enLevel': [],
        'cnLevel': [],
        'jpDetailType': [],
        'studyStatus': [],
      }
    });
// Supabase Provider (Read Only)
final supabaseFlashcardsProvider = FutureProvider<List<Flashcard>>((ref) async {
  final repository = FlashcardRepository();
  return await repository.getSupabaseFlashcards();
});

// Thêm provider mới cho trạng thái tải
final isLoadingFromSupabaseProvider = StateProvider<bool>((ref) => false);
final downloadProgressProvider = StateProvider<double>((ref) => 0.0);

// Local Provider (Full CRUD)
final localFlashcardsProvider =
    StateNotifierProvider<LocalFlashcardNotifier, List<Flashcard>>((ref) {
  return LocalFlashcardNotifier();
});

// Filter Provider
final filterProvider = StateProvider<Map<String, dynamic>>((ref) => {});
bool _isSyncing = false;

class LocalFlashcardNotifier extends StateNotifier<List<Flashcard>> {
  final FlashcardRepository _repository = FlashcardRepository();

  LocalFlashcardNotifier() : super([]) {
    loadLocalFlashcards();
  }

  Future<void> loadLocalFlashcards() async {
    try {
      final cards = await _repository.getLocalFlashcards();
      state = cards;
    } catch (e) {
      state = [];
    }
  }

  Future<bool> addCard(Flashcard card) async {
    try {
      final newCard = await _repository.addLocalFlashcard(card);
      state = [newCard, ...state];
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addMultipleCards(List<Flashcard> cards) async {
    try {
      final addedCards = await _repository.addMultipleLocalFlashcards(cards);
      state = [...addedCards, ...state];
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateCard(Flashcard card) async {
    try {
      final updatedCard = await _repository.updateLocalFlashcard(card);
      final index = state.indexWhere((c) => c.id == updatedCard.id);
      if (index != -1) {
        state = [...state]..[index] = updatedCard;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteCard(String id) async {
    try {
      await _repository.deleteLocalFlashcard(id);
      state = state.where((card) => card.id != id).toList();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteAllCards() async {
    try {
      await _repository.deleteAllLocalFlashcards();
      state = [];
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Flashcard>> searchCards(String query) async {
    if (query.isEmpty) {
      await loadLocalFlashcards();
      return state;
    }
    try {
      final results = await _repository.searchLocalFlashcards(query);
      return results;
    } catch (e) {
      return [];
    }
  }
}

// ==================== MAIN PAGE ====================

class FlashcardListPage extends ConsumerStatefulWidget {
  const FlashcardListPage({super.key});

  @override
  ConsumerState<FlashcardListPage> createState() => _FlashcardListPageState();
}

class _FlashcardListPageState extends ConsumerState<FlashcardListPage> {
  // Controllers
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _vietnameseController = TextEditingController();
  final _englishController = TextEditingController();
  final _jpKanjiController = TextEditingController();
  final _jpReadingController = TextEditingController();
  final _jpTypeController = TextEditingController();
  final _jpDetailTypeController = TextEditingController();
  final _jpLevelController = TextEditingController();
  final _enIpaController = TextEditingController();
  final _enLevelController = TextEditingController();
  final _hanVietController = TextEditingController();
  final _cnCharacterController = TextEditingController();
  final _cnPinyinController = TextEditingController();
  final _cnLevelController = TextEditingController();
  final _exampleSentenceController = TextEditingController();
  final _contextNoteController = TextEditingController();

  // State
  final ExcelImportService _excelService = ExcelImportService();
  bool _isImporting = false;
  bool _isSearching = false;

  // Pagination
  int _currentPage = 0;
  int _pageSize = 50;
  int _totalItems = 0;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  // Thêm biến lưu filter hiện tại để khôi phục
  Map<String, dynamic> _currentFilters = {};

  String _sortBy = 'id';
  bool _sortAscending = true;

  // Provider để chia sẻ danh sách flashcards đã lọc
  final filteredFlashcardsProvider =
      StateProvider<List<Flashcard>>((ref) => []);

// Provider để refresh
  final refreshStudyProvider = StateProvider<bool>((ref) => false);

  // Settings
  int _itemsPerPage = 50;
  Map<String, bool> _showFields = {
    'vietnamese': true,
    'english': true,
    'jpKanji': true,
    'jpReading': true,
    'jpDetailType': true,
    'jpLevel': true,
    'enLevel': true,
    'cnCharacter': true,
    'cnPinyin': true,
    'cnLevel': true,
    'exampleSentence': true,
    'contextNote': true,
  };

  Map<String, List<String>> _selectedFilters = {
    'jpLevel': [],
    'enLevel': [],
    'cnLevel': [],
    'jpDetailType': [],
    'studyStatus': [],
  };

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      if (_searchController.text.isNotEmpty) {
        _performSearch(_searchController.text, _searchField);
      } else {
        _performSearch('', _searchField);
      }
    });

    _scrollController.addListener(_onScroll);

    _loadSettings();

    // Load dữ liệu ban đầu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFlashcardsWithFilter();
    });
  }

  // Thêm vào flashcard_list_page.dart
  void refreshData() {
    print('🔄 Refreshing data from database...');
    setState(() {
      _currentPage = 0;
      _totalItems = 0;
    });
    _loadFlashcardsWithFilter();
  }

  void _loadSettings() {
    // Load settings từ SharedPreferences trước
    _loadSettingsState().then((_) {
      // Load filter từ SharedPreferences
      _loadFilterState().then((_) {
        // Load current page
        _loadCurrentPage().then((_) {
          // Sau khi load tất cả, load dữ liệu
          _loadFlashcardsWithFilter();
        });
      });
    });
  }

// ==================== HÀM LOAD SELECTED FILTERS AN TOÀN ====================

  Map<String, List<String>> _loadSelectedFiltersSafe(
      Map<String, dynamic> settings) {
    final Map<String, List<String>> result = {
      'jpLevel': [],
      'enLevel': [],
      'cnLevel': [],
      'jpDetailType': [],
      'studyStatus': [],
    };

    try {
      final filtersData = settings['selectedFilters'];
      if (filtersData is Map<String, dynamic>) {
        filtersData.forEach((key, value) {
          if (result.containsKey(key)) {
            if (value is List) {
              // Chuyển đổi List<dynamic> thành List<String>
              result[key] = value.whereType<String>().toList();
            } else if (value is String) {
              // Nếu là String, split thành List
              result[key] =
                  value.split(',').where((s) => s.isNotEmpty).toList();
            } else {
              result[key] = [];
            }
          }
        });
      }
    } catch (e) {
      print('❌ Error loading selected filters: $e');
      // Giữ giá trị mặc định
    }

    return result;
  }

// ==================== HÀM LƯU SELECTED FILTERS ====================

  Map<String, List<String>> _saveSelectedFilters(
      Map<String, List<String>> filters) {
    final Map<String, List<String>> result = {};
    filters.forEach((key, value) {
      if (value is List) {
        result[key] = List<String>.from(value);
      } else {
        result[key] = [];
      }
    });
    return result;
  }

  void _applyFiltersToQuery() {
    final filterMap = ref.read(filterProvider);
    final updatedFilters = Map<String, dynamic>.from(filterMap);

    // Xóa các filter cũ
    updatedFilters.remove('jpLevel');
    updatedFilters.remove('enLevel');
    updatedFilters.remove('cnLevel');
    updatedFilters.remove('jpDetailType');
    updatedFilters.remove('studyStatus');

    // Áp dụng các filter đã chọn
    _applySingleFilter(updatedFilters, 'jpLevel', _selectedFilters);
    _applySingleFilter(updatedFilters, 'enLevel', _selectedFilters);
    _applySingleFilter(updatedFilters, 'cnLevel', _selectedFilters);
    _applySingleFilter(updatedFilters, 'jpDetailType', _selectedFilters);
    _applySingleFilter(updatedFilters, 'studyStatus', _selectedFilters);

    // Giữ lại search query nếu có
    if (filterMap.containsKey('searchQuery')) {
      updatedFilters['searchQuery'] = filterMap['searchQuery'];
    }

    ref.read(filterProvider.notifier).state = updatedFilters;
  }

  void _applySingleFilter(
    Map<String, dynamic> filters,
    String key,
    Map<String, List<String>> selectedFilters,
  ) {
    final selected = selectedFilters[key] ?? [];
    if (selected.isNotEmpty) {
      // Join các giá trị thành string cách nhau bằng dấu phẩy
      filters[key] = selected.join(',');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _vietnameseController.dispose();
    _englishController.dispose();
    _jpKanjiController.dispose();
    _jpReadingController.dispose();
    _jpTypeController.dispose();
    _jpDetailTypeController.dispose();
    _jpLevelController.dispose();
    _enIpaController.dispose();
    _enLevelController.dispose();
    _hanVietController.dispose();
    _cnCharacterController.dispose();
    _cnPinyinController.dispose();
    _cnLevelController.dispose();
    _exampleSentenceController.dispose();
    _contextNoteController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (!_isLoadingMore && _currentPage * _pageSize < _totalItems) {
      setState(() {
        _currentPage++;
        _isLoadingMore = true;
      });
      _loadFlashcardsWithFilter();
    }
  }

  Future<void> _performSearch(String query, String field) async {
    if (query.isEmpty) {
      setState(() => _isSearching = false);
      // Reset về trang 1 khi xóa search
      setState(() {
        _currentPage = 0;
        _totalItems = 0;
      });
      _loadFlashcardsWithFilter();
      return;
    }

    setState(() => _isSearching = true);

    // Update filter với search query và field
    final currentFilters = ref.read(filterProvider);
    final updatedFilters = Map<String, dynamic>.from(currentFilters);
    updatedFilters['searchQuery'] = query;
    updatedFilters['searchField'] = field;
    ref.read(filterProvider.notifier).state = updatedFilters;

    // Reset về trang 1 khi search
    setState(() {
      _currentPage = 0;
      _totalItems = 0;
    });
    _loadFlashcardsWithFilter();
  }

  Future<void> _loadFlashcardsWithFilter({bool keepPage = false}) async {
    // KIỂM TRA MOUNTED
    if (!mounted) return;

    final filters = ref.read(filterProvider);
    final notifier = ref.read(localFlashcardsProvider.notifier);

    // Lưu filter hiện tại
    _currentFilters = Map.from(filters);

    try {
      setState(() => _isLoadingMore = true);

      final localDb = LocalDatabase();

      String? searchQuery = filters['searchQuery'];
      if (searchQuery != null && searchQuery.isNotEmpty) {
        searchQuery = searchQuery.toLowerCase();
      }

      String sortBy = filters['sortBy'] ?? 'id';
      bool ascending = filters['sortAscending'] ?? true;

      final offset = _currentPage * _pageSize;

      final cards = await localDb.getFlashcardsWithFilter(
        jpLevel: filters['jpLevel'],
        enLevel: filters['enLevel'],
        cnLevel: filters['cnLevel'],
        jpDetailType: filters['jpDetailType'],
        studyStatus: filters['studyStatus'],
        searchQuery: searchQuery,
        sortBy: sortBy,
        ascending: ascending,
        limit: _pageSize,
        offset: offset,
      );

      final total = await localDb.countFlashcardsWithFilter(
        jpLevel: filters['jpLevel'],
        enLevel: filters['enLevel'],
        cnLevel: filters['cnLevel'],
        jpDetailType: filters['jpDetailType'],
        studyStatus: filters['studyStatus'],
        searchQuery: searchQuery,
      );

      // KIỂM TRA MOUNTED TRƯỚC KHI SETSTATE
      if (!mounted) return;

      setState(() {
        _totalItems = total;
        notifier.state = cards;
        _isLoadingMore = false;
        _isSearching = false;
      });

      // Lưu trạng thái
      await _saveCurrentPage();
      await _saveFilterState();
      await _saveSettingsState();

      print(
          '📊 Loaded ${cards.length} cards (total: $total, page: ${_currentPage + 1})');
    } catch (e) {
      print('❌ Error loading with filter: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _updateStudyStatus(String cardId, String newStatus) async {
    try {
      print('🔄 Updating status for card $cardId to $newStatus');

      final localDb = LocalDatabase();
      final cards = await localDb.getAllFlashcards();
      final cardIndex = cards.indexWhere((c) => c.id == cardId);

      if (cardIndex != -1) {
        // Sử dụng copyWith đã được thêm vào model
        final updatedCard = cards[cardIndex].copyWith(studyStatus: newStatus);
        await localDb.updateFlashcard(updatedCard);
        print(
            '✅ Updated card in database: ${updatedCard.vietnamese} -> $newStatus');

        // Cập nhật state
        final notifier = ref.read(localFlashcardsProvider.notifier);
        final currentCards = notifier.state;
        final index = currentCards.indexWhere((c) => c.id == cardId);
        if (index != -1) {
          final newList = [...currentCards];
          newList[index] = updatedCard;
          notifier.state = newList;
        }

        // Cập nhật danh sách hiển thị
        setState(() {});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('✅ Status updated to ${_getStatusLabel(newStatus)}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        print('❌ Card not found in database: $cardId');
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

  String _getStatusLabel(String status) {
    switch (status) {
      case 'new':
        return '🆕 New';
      case 'learning':
        return '📖 Learning';
      case 'reviewing':
        return '🔄 Reviewing';
      case 'mastered':
        return '⭐ Mastered';
      default:
        return status;
    }
  }

  void _showSettingsDialog(BuildContext context) {
    final settings = ref.read(settingsProvider);

    // Lấy dữ liệu hiện tại
    int itemsPerPage = settings['itemsPerPage'] ?? 50;
    String sortBy = settings['sortBy'] ?? 'id';
    bool sortAscending = settings['sortAscending'] ?? true;

    // Lấy showFields
    Map<String, bool> showFields = {};
    final showFieldsData = settings['showFields'];
    if (showFieldsData is Map<String, dynamic>) {
      showFieldsData.forEach((key, value) {
        showFields[key] = value is bool ? value : true;
      });
    } else {
      // Default values
      const defaultFields = [
        'vietnamese',
        'english',
        'jpKanji',
        'jpReading',
        'jpType',
        'jpDetailType',
        'jpLevel',
        'enIpa',
        'enLevel',
        'hanViet',
        'cnCharacter',
        'cnPinyin',
        'cnLevel',
        'exampleSentence',
        'contextNote'
      ];
      for (var field in defaultFields) {
        showFields[field] = true;
      }
    }

    // Danh sách các trường có thể hiển thị
    final List<Map<String, String>> fieldOptions = [
      {'key': 'vietnamese', 'label': '🇻🇳 Vietnamese', 'required': 'true'},
      {'key': 'english', 'label': '🇬🇧 English', 'required': 'false'},
      {'key': 'jpKanji', 'label': '🇯🇵 Japanese Kanji', 'required': 'false'},
      {'key': 'jpReading', 'label': '🔊 Japanese Reading', 'required': 'false'},
      {'key': 'jpType', 'label': '📝 Japanese Type', 'required': 'false'},
      {
        'key': 'jpDetailType',
        'label': '📋 Word Detail Type',
        'required': 'false'
      },
      {'key': 'jpLevel', 'label': '📊 JLPT Level', 'required': 'false'},
      {'key': 'enIpa', 'label': '🔊 English IPA', 'required': 'false'},
      {'key': 'enLevel', 'label': '📊 CEFR Level', 'required': 'false'},
      {'key': 'hanViet', 'label': '🇻🇳 Han-Viet', 'required': 'false'},
      {
        'key': 'cnCharacter',
        'label': '🇨🇳 Chinese Character',
        'required': 'false'
      },
      {'key': 'cnPinyin', 'label': '🔊 Chinese Pinyin', 'required': 'false'},
      {'key': 'cnLevel', 'label': '📊 HSK Level', 'required': 'false'},
      {
        'key': 'exampleSentence',
        'label': '💬 Example Sentence',
        'required': 'false'
      },
      {'key': 'contextNote', 'label': '📌 Context Note', 'required': 'false'},
    ];

    // Danh sách sort options
    final List<Map<String, String>> sortOptions = [
      {'key': 'id', 'label': '🔢 ID (1, 2, 3...)'},
      {'key': 'created_at', 'label': '📅 Created Date'},
      {'key': 'vietnamese', 'label': '🇻🇳 Vietnamese'},
      {'key': 'english', 'label': '🇬🇧 English'},
      {'key': 'jp_level', 'label': '📊 JLPT Level'},
      {'key': 'en_level', 'label': '📊 CEFR Level'},
      {'key': 'cn_level', 'label': '📊 HSK Level'},
      {'key': 'jp_detail_type', 'label': '📋 Word Type'},
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(Icons.settings,
                            color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        const Text(
                          'Settings',
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
                            // Items per page
                            const Text(
                              'Items per page:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [25, 50, 100, 200, 500].map((size) {
                                return ChoiceChip(
                                  label: Text('$size'),
                                  selected: itemsPerPage == size,
                                  onSelected: (selected) {
                                    setState(() {
                                      itemsPerPage = size;
                                    });
                                  },
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 16),
                            const Divider(),

                            // Sort By
                            const Text(
                              'Sort By:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            ...sortOptions.map((option) {
                              final key = option['key']!;
                              final label = option['label']!;
                              final isSelected = sortBy == key;

                              return RadioListTile<String>(
                                title: Text(label),
                                value: key,
                                groupValue: sortBy,
                                onChanged: (value) {
                                  setState(() {
                                    sortBy = value!;
                                  });
                                },
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              );
                            }).toList(),

                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text('Order:'),
                                const SizedBox(width: 16),
                                ChoiceChip(
                                  label: const Text('Ascending'),
                                  selected: sortAscending,
                                  onSelected: (selected) {
                                    setState(() {
                                      sortAscending = selected;
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('Descending'),
                                  selected: !sortAscending,
                                  onSelected: (selected) {
                                    setState(() {
                                      sortAscending = !selected;
                                    });
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                            const Divider(),

                            // Show/Hide Fields
                            const Text(
                              'Show/Hide Fields:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            ...fieldOptions.map((field) {
                              final key = field['key']!;
                              final label = field['label']!;
                              final isRequired = field['required'] == 'true';
                              final isChecked = showFields[key] ?? true;

                              return CheckboxListTile(
                                title: Text(label),
                                value: isChecked,
                                onChanged: isRequired
                                    ? null
                                    : (checked) {
                                        setState(() {
                                          showFields[key] = checked ?? true;
                                        });
                                      },
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                secondary: isRequired
                                    ? const Icon(Icons.lock,
                                        size: 16, color: Colors.grey)
                                    : null,
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),

                    const Divider(),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              // Reset về mặc định
                              itemsPerPage = 50;
                              sortBy = 'id';
                              sortAscending = true;

                              // Reset show fields
                              const defaultFields = [
                                'vietnamese',
                                'english',
                                'jpKanji',
                                'jpReading',
                                'jpType',
                                'jpDetailType',
                                'jpLevel',
                                'enIpa',
                                'enLevel',
                                'hanViet',
                                'cnCharacter',
                                'cnPinyin',
                                'cnLevel',
                                'exampleSentence',
                                'contextNote'
                              ];
                              for (var field in defaultFields) {
                                showFields[field] = true;
                              }
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
                        // Trong _showSettingsDialog, phần onPressed của Apply button
                        ElevatedButton(
                          onPressed: () {
                            // Lưu settings
                            final newSettings = {
                              'itemsPerPage': itemsPerPage,
                              'sortBy': sortBy,
                              'sortAscending': sortAscending,
                              'showFields': Map<String, bool>.from(showFields),
                            };

                            ref.read(settingsProvider.notifier).state =
                                newSettings;

                            // Cập nhật state
                            setState(() {
                              _itemsPerPage = itemsPerPage;
                              _pageSize = itemsPerPage;
                              _sortBy = sortBy;
                              _sortAscending = sortAscending;
                              _showFields = Map<String, bool>.from(showFields);
                            });

                            // Lưu tất cả trạng thái
                            _saveSettingsState();
                            _saveCurrentPage();
                            _saveFilterState();

                            // Cập nhật filter
                            final currentFilter = ref.read(filterProvider);
                            final updatedFilter =
                                Map<String, dynamic>.from(currentFilter);
                            updatedFilter['sortBy'] = sortBy;
                            updatedFilter['sortAscending'] = sortAscending;
                            ref.read(filterProvider.notifier).state =
                                updatedFilter;

                            Navigator.pop(context);
                            _loadFlashcardsWithFilter(keepPage: true);
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

  void _onSettingsApplied(
    int itemsPerPage,
    Map<String, bool> newShowFields,
    Map<String, List<String>> newSelectedFilters,
  ) {
    // Cập nhật state
    setState(() {
      _itemsPerPage = itemsPerPage;
      _pageSize = itemsPerPage;
      _showFields = Map<String, bool>.from(newShowFields);

      // Cập nhật _selectedFilters an toàn
      _selectedFilters = {};
      newSelectedFilters.forEach((key, value) {
        _selectedFilters[key] = List<String>.from(value);
      });

      _currentPage = 0;
      _totalItems = 0;
    });

    // Lưu settings
    final newSettings = {
      'itemsPerPage': itemsPerPage,
      'showFields': Map<String, bool>.from(newShowFields),
      'selectedFilters': _saveSelectedFilters(_selectedFilters),
    };
    ref.read(settingsProvider.notifier).state = newSettings;

    // Áp dụng filters và load lại dữ liệu
    _applyFiltersToQuery();
    _loadFlashcardsWithFilter();
  }

// ==================== HÀM CHUẨN BỊ DỮ LIỆU CHO DIALOG ====================

  Map<String, bool> _prepareShowFields(Map<String, dynamic> settings) {
    final Map<String, bool> result = {};
    final showFieldsData = settings['showFields'];

    if (showFieldsData is Map<String, dynamic>) {
      showFieldsData.forEach((key, value) {
        result[key] = value is bool ? value : true;
      });
    } else {
      // Default values
      const defaultFields = [
        'vietnamese',
        'english',
        'jpKanji',
        'jpReading',
        'jpType',
        'jpDetailType',
        'jpLevel',
        'enIpa',
        'enLevel',
        'hanViet',
        'cnCharacter',
        'cnPinyin',
        'cnLevel',
        'exampleSentence',
        'contextNote'
      ];
      for (var field in defaultFields) {
        result[field] = true;
      }
    }

    return result;
  }

  Map<String, List<String>> _prepareSelectedFilters(
      Map<String, dynamic> settings) {
    final Map<String, List<String>> result = {
      'jpLevel': [],
      'enLevel': [],
      'cnLevel': [],
      'jpDetailType': [],
      'studyStatus': [],
    };

    try {
      final filtersData = settings['selectedFilters'];
      if (filtersData is Map<String, dynamic>) {
        filtersData.forEach((key, value) {
          if (result.containsKey(key)) {
            if (value is List) {
              result[key] = value.whereType<String>().toList();
            } else if (value is String) {
              result[key] =
                  value.split(',').where((s) => s.isNotEmpty).toList();
            } else {
              result[key] = [];
            }
          }
        });
      }
    } catch (e) {
      print('❌ Error preparing selected filters: $e');
    }

    return result;
  }

  void _applyFilter(
    Map<String, dynamic> filters,
    String key,
    Map<String, List<String>> selectedFilters,
  ) {
    final selected = selectedFilters[key] ?? [];
    if (selected.isNotEmpty) {
      filters[key] = selected.join(',');
    } else {
      filters.remove(key);
    }
  }

  String _getFieldLabel(String key) {
    switch (key) {
      case 'vietnamese':
        return '🇻🇳 Vietnamese';
      case 'english':
        return '🇬🇧 English';
      case 'jpKanji':
        return '🇯🇵 Japanese Kanji';
      case 'jpReading':
        return '🔊 Japanese Reading';
      case 'jpDetailType':
        return '📝 Word Type';
      case 'jpLevel':
        return '📊 JLPT Level';
      case 'enLevel':
        return '📊 CEFR Level';
      case 'cnCharacter':
        return '🇨🇳 Chinese Character';
      case 'cnPinyin':
        return '🔊 Chinese Pinyin';
      case 'cnLevel':
        return '📊 HSK Level';
      case 'exampleSentence':
        return '💬 Example Sentence';
      case 'contextNote':
        return '📝 Context Note';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localCards = ref.watch(localFlashcardsProvider);
    final isDownloading = ref.watch(isLoadingFromSupabaseProvider);
    final downloadProgress = ref.watch(downloadProgressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcards'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Nút chuyển theme
          IconButton(
            icon: Icon(
              ref.watch(themeModeProvider) == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () {
              final current = ref.read(themeModeProvider);
              ref.read(themeModeProvider.notifier).state =
                  current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
            },
            tooltip: 'Toggle theme',
          ),
          // Nút đổi màu
          IconButton(
            icon: const Icon(Icons.color_lens),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const ColorPickerDialog(),
              ).then((_) {
                // Refresh để áp dụng màu mới
                setState(() {});
              });
            },
            tooltip: 'Change theme color',
          ),
          // NHÓM 1: Filter, Settings, Search
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune),
            tooltip: 'Filter & Settings',
            onSelected: (value) {
              switch (value) {
                case 'filter':
                  _showFilterDialog(context);
                  break;
                case 'settings':
                  _showSettingsDialog(context);
                  break;
                case 'search':
                  _showSearchDialog(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'filter',
                child: Row(
                  children: [
                    Icon(Icons.filter_list),
                    SizedBox(width: 8),
                    Text('Filter'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'search',
                child: Row(
                  children: [
                    Icon(Icons.search),
                    SizedBox(width: 8),
                    Text('Search'),
                  ],
                ),
              ),
            ],
          ),

          // NHÓM 2: Download, Import, Refresh, Delete
          PopupMenuButton<String>(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Data Management',
            onSelected: (value) {
              switch (value) {
                case 'download':
                  _downloadFromSupabase(context);
                  break;
                case 'import':
                  _showImportOptions(context);
                  break;
                case 'refresh':
                  ref.invalidate(supabaseFlashcardsProvider);
                  // KHÔNG reset _currentPage về 0
                  _loadFlashcardsWithFilter(keepPage: true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🔄 Refreshing data...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  break;
                case 'delete_all':
                  _confirmDeleteAll(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'download',
                child: Row(
                  children: [
                    Icon(Icons.cloud_download),
                    SizedBox(width: 8),
                    Text('Download from Server'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.upload_file),
                    SizedBox(width: 8),
                    Text('Import Excel'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete All', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    ref.watch(authNotifierProvider).isAuthenticated
                        ? Icons.cloud_sync
                        : Icons.cloud_off,
                    color: ref.watch(authNotifierProvider).isAuthenticated
                        ? Colors.blue
                        : Colors.grey,
                  ),
            onPressed: _isSyncing ? null : _syncStudyStatus,
            tooltip: ref.watch(authNotifierProvider).isAuthenticated
                ? 'Sync to server'
                : 'Login to sync',
          ),

// Nút đăng xuất (chỉ hiện khi đã login)
          if (ref.watch(authNotifierProvider).isAuthenticated)
            PopupMenuButton<String>(
              icon: const Icon(Icons.account_circle),
              onSelected: (value) {
                if (value == 'logout') {
                  _logout();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
            ),

          // NHÓM 3: Study
          // Nút Study
          if (localCards.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.school),
              onPressed: () {
                // Cập nhật provider trước khi vào Study
                ref.read(filteredFlashcardsProvider.notifier).state =
                    localCards;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudyPage(
                      flashcards: localCards,
                      initialIndex: 0,
                    ),
                  ),
                ).then((_) {
                  // KIỂM TRA MOUNTED TRƯỚC KHI GỌI REF
                  if (mounted) {
                    // Refresh dữ liệu nhưng giữ nguyên trang
                    _loadFlashcardsWithFilter(keepPage: true);
                  }
                });
              },
              tooltip: 'Study flashcards',
            ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar khi đang tải
          if (isDownloading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Downloading from server...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: downloadProgress,
                          backgroundColor: Colors.grey.shade300,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(downloadProgress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),

          // Local flashcards list
          Expanded(
            child: _buildLocalTab(localCards),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isImporting ? null : () => _showAddCardDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  // ==================== BUILD TABS ====================

  Widget _buildLocalTab(List<Flashcard> localCards) {
    // Kiểm tra có filter không
    final filters = ref.read(filterProvider);
    bool hasFilter = false;
    if ((filters['jpLevel'] != null && filters['jpLevel'].isNotEmpty) ||
        (filters['enLevel'] != null && filters['enLevel'].isNotEmpty) ||
        (filters['cnLevel'] != null && filters['cnLevel'].isNotEmpty) ||
        (filters['jpDetailType'] != null &&
            filters['jpDetailType'].isNotEmpty) ||
        (filters['studyStatus'] != null && filters['studyStatus'].isNotEmpty) ||
        (filters['searchQuery'] != null && filters['searchQuery'].isNotEmpty)) {
      hasFilter = true;
    }

    if (localCards.isEmpty && !_isLoadingMore) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storage, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _isSearching ? 'No search results' : 'No local flashcards',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              _isSearching
                  ? 'Try different keywords'
                  : 'Add new cards or import from Excel',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            if (!_isSearching) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showImportOptions(context),
                icon: const Icon(Icons.upload_file),
                label: const Text('Import Excel'),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        // Thông tin phân trang
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '📚 ${localCards.length} of $_totalItems cards',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (_totalItems > 0)
                Text(
                  '📄 Page ${_currentPage + 1} of ${(_totalItems / _pageSize).ceil()}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: localCards.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == localCards.length && _isLoadingMore) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final card = localCards[index];
              return FlashcardCard(
                card: card,
                isReadOnly: false,
                showFields: _showFields,
                onDelete: () async {
                  final success = await ref
                      .read(localFlashcardsProvider.notifier)
                      .deleteCard(card.id);
                  if (!success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to delete card'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                onEdit: () => _showEditCardDialog(context, card),
                onStatusChange: (newStatus) =>
                    _updateStudyStatus(card.id, newStatus),
              );
            },
          ),
        ),
        // Pagination controls - LUÔN HIỂN THỊ
        if (_totalItems > _pageSize)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentPage > 0
                      ? () {
                          setState(() {
                            _currentPage--;
                          });
                          _loadFlashcardsWithFilter(); // Load lại trang mới
                        }
                      : null,
                ),
                ..._getPageNumbers().map((page) {
                  if (page == -1) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text('...'),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ChoiceChip(
                      label: Text('${page + 1}'),
                      selected: _currentPage == page,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _currentPage = page;
                          });
                          _loadFlashcardsWithFilter(); // Load lại trang mới
                        }
                      },
                    ),
                  );
                }),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: (_currentPage + 1) * _pageSize < _totalItems
                      ? () {
                          setState(() {
                            _currentPage++;
                          });
                          _loadFlashcardsWithFilter(); // Load lại trang mới
                        }
                      : null,
                ),
              ],
            ),
          ),
        if (_isLoadingMore)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  List<int> _getPageNumbers() {
    final totalPages = (_totalItems / _pageSize).ceil();
    if (totalPages <= 7) {
      return List.generate(totalPages, (i) => i);
    }

    List<int> pages = [];
    if (_currentPage < 3) {
      pages = [0, 1, 2, 3, 4, -1, totalPages - 1];
    } else if (_currentPage > totalPages - 4) {
      pages = [
        0,
        -1,
        totalPages - 5,
        totalPages - 4,
        totalPages - 3,
        totalPages - 2,
        totalPages - 1
      ];
    } else {
      pages = [
        0,
        -1,
        _currentPage - 1,
        _currentPage,
        _currentPage + 1,
        -1,
        totalPages - 1
      ];
    }
    return pages;
  }

  // ==================== IMPORT EXCEL ====================

  void _showImportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Import from Excel',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Import 16-column Excel file to Local database',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.upload_file, color: Colors.blue),
                title: const Text('Import Excel File'),
                subtitle: const Text('Select .xlsx or .xls file'),
                onTap: () {
                  Navigator.pop(context);
                  _importExcel();
                },
              ),
              ListTile(
                leading: const Icon(Icons.download, color: Colors.green),
                title: const Text('Download Sample Excel'),
                subtitle: const Text('Get template with correct format'),
                onTap: () {
                  Navigator.pop(context);
                  _downloadSampleExcel();
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.orange),
                title: const Text('Excel Format Guide'),
                subtitle: const Text('View required 16 columns'),
                onTap: () {
                  Navigator.pop(context);
                  _showExcelGuide(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ==================== HÀM TẢI TỪ SUPABASE ====================

  Future<void> _downloadFromSupabase(BuildContext context) async {
    final isDownloading = ref.read(isLoadingFromSupabaseProvider.notifier);
    final progress = ref.read(downloadProgressProvider.notifier);

    final localDb = LocalDatabase();
    final existingCards = await localDb.getAllFlashcards();

    if (existingCards.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Download from Server'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'You already have ${existingCards.length} local flashcards.'),
                const SizedBox(height: 8),
                const Text('Do you want to:'),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.add_circle, color: Colors.green),
                  title: const Text('Append (Add more)'),
                  onTap: () => Navigator.pop(context, true),
                ),
                ListTile(
                  leading: const Icon(Icons.refresh, color: Colors.orange),
                  title: const Text('Replace (Delete all and download new)'),
                  onTap: () => Navigator.pop(context, false),
                ),
                ListTile(
                  leading: const Icon(Icons.cancel, color: Colors.red),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.pop(context, null),
                ),
              ],
            ),
          );
        },
      );

      if (confirm == null) return;
      if (!confirm) {
        await localDb.deleteAllFlashcards();
        ref.read(localFlashcardsProvider.notifier).state = [];
      }
    }

    isDownloading.state = true;
    progress.state = 0.0;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Downloading from server...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );

      final repository = FlashcardRepository();
      final supabaseCards = await repository.getSupabaseFlashcards();

      progress.state = 0.5;

      if (supabaseCards.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No data available on server'),
            backgroundColor: Colors.orange,
          ),
        );
        isDownloading.state = false;
        return;
      }

      print('📥 Downloaded ${supabaseCards.length} cards from Supabase');

      // Thêm vào local database
      final added = await localDb.insertMultipleFlashcards(supabaseCards);

      progress.state = 1.0;

      // Refresh local list
      await ref.read(localFlashcardsProvider.notifier).loadLocalFlashcards();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Downloaded $added flashcards successfully!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '❌ Download failed: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      isDownloading.state = false;
      progress.state = 0.0;
    }
  }

  Future<void> _importExcel() async {
    if (_isImporting) return;

    setState(() => _isImporting = true);

    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Importing flashcards from Excel...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );

      final flashcards = await _excelService.importFromFile();

      if (!mounted) return;

      if (flashcards.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No valid flashcards found in Excel file'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isImporting = false);
        return;
      }

      final success = await ref
          .read(localFlashcardsProvider.notifier)
          .addMultipleCards(flashcards);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Imported ${flashcards.length} flashcards successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        // Reset và load lại
        setState(() {
          _currentPage = 0;
          _totalItems = 0;
        });
        _loadFlashcardsWithFilter();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Import completed with some errors'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '❌ Import failed: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _downloadSampleExcel() async {
    try {
      await _excelService.exportSampleExcel();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Sample Excel downloaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to download sample: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==================== FILTER DIALOG ====================

  // Sửa lỗi: Chuyển Map<String, dynamic> đúng cách
  void _showFilterDialog(BuildContext context) {
    final currentFilter = ref.read(filterProvider);

    // Lấy các giá trị filter hiện tại
    Map<String, List<String>> tempFilters = {};

    // Xử lý jpLevel
    if (currentFilter.containsKey('jpLevel') &&
        currentFilter['jpLevel'] is String) {
      final value = currentFilter['jpLevel'] as String;
      if (value.isNotEmpty) {
        tempFilters['jpLevel'] =
            value.split(',').where((s) => s.isNotEmpty).toList();
      }
    }

    // Xử lý enLevel
    if (currentFilter.containsKey('enLevel') &&
        currentFilter['enLevel'] is String) {
      final value = currentFilter['enLevel'] as String;
      if (value.isNotEmpty) {
        tempFilters['enLevel'] =
            value.split(',').where((s) => s.isNotEmpty).toList();
      }
    }

    // Xử lý cnLevel
    if (currentFilter.containsKey('cnLevel') &&
        currentFilter['cnLevel'] is String) {
      final value = currentFilter['cnLevel'] as String;
      if (value.isNotEmpty) {
        tempFilters['cnLevel'] =
            value.split(',').where((s) => s.isNotEmpty).toList();
      }
    }

    // Xử lý jpDetailType
    if (currentFilter.containsKey('jpDetailType') &&
        currentFilter['jpDetailType'] is String) {
      final value = currentFilter['jpDetailType'] as String;
      if (value.isNotEmpty) {
        tempFilters['jpDetailType'] =
            value.split(',').where((s) => s.isNotEmpty).toList();
      }
    }

    // Xử lý studyStatus
    if (currentFilter.containsKey('studyStatus') &&
        currentFilter['studyStatus'] is String) {
      final value = currentFilter['studyStatus'] as String;
      if (value.isNotEmpty) {
        tempFilters['studyStatus'] =
            value.split(',').where((s) => s.isNotEmpty).toList();
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Các tùy chọn filter
            final jpLevels = ['N1', 'N2', 'N3', 'N4', 'N5'];
            final enLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
            final cnLevels = ['HSK1', 'HSK2', 'HSK3', 'HSK4', 'HSK5', 'HSK6'];
            final statusOptions = ['new', 'learning', 'reviewing', 'mastered'];
            final statusLabels = {
              'new': '🆕 New',
              'learning': '📖 Learning',
              'reviewing': '🔄 Reviewing',
              'mastered': '⭐ Mastered',
            };

            // Lấy word types từ database
            List<String> wordTypes = [];
            // Sẽ load sau

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(Icons.filter_list,
                            color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        const Text(
                          'Filter Flashcards',
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
                            // JLPT Filter
                            _buildFilterSection(
                              context,
                              'JLPT Level:',
                              jpLevels,
                              tempFilters['jpLevel'] ?? [],
                              (selected) {
                                setState(() {
                                  if (selected.isNotEmpty) {
                                    tempFilters['jpLevel'] = selected;
                                  } else {
                                    tempFilters.remove('jpLevel');
                                  }
                                });
                              },
                            ),

                            const Divider(),

                            // CEFR Filter
                            _buildFilterSection(
                              context,
                              'CEFR Level:',
                              enLevels,
                              tempFilters['enLevel'] ?? [],
                              (selected) {
                                setState(() {
                                  if (selected.isNotEmpty) {
                                    tempFilters['enLevel'] = selected;
                                  } else {
                                    tempFilters.remove('enLevel');
                                  }
                                });
                              },
                            ),

                            const Divider(),

                            // HSK Filter
                            _buildFilterSection(
                              context,
                              'HSK Level:',
                              cnLevels,
                              tempFilters['cnLevel'] ?? [],
                              (selected) {
                                setState(() {
                                  if (selected.isNotEmpty) {
                                    tempFilters['cnLevel'] = selected;
                                  } else {
                                    tempFilters.remove('cnLevel');
                                  }
                                });
                              },
                            ),

                            const Divider(),

                            // Word Type Filter (sẽ load từ database)
                            FutureBuilder<List<String>>(
                              future:
                                  LocalDatabase().getAvailableJpDetailTypes(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData &&
                                    snapshot.data!.isNotEmpty) {
                                  return _buildFilterSection(
                                    context,
                                    'Word Type:',
                                    snapshot.data!,
                                    tempFilters['jpDetailType'] ?? [],
                                    (selected) {
                                      setState(() {
                                        if (selected.isNotEmpty) {
                                          tempFilters['jpDetailType'] =
                                              selected;
                                        } else {
                                          tempFilters.remove('jpDetailType');
                                        }
                                      });
                                    },
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),

                            const Divider(),

                            // Study Status Filter
                            _buildFilterSection(
                              context,
                              'Study Status:',
                              statusOptions,
                              tempFilters['studyStatus'] ?? [],
                              (selected) {
                                setState(() {
                                  if (selected.isNotEmpty) {
                                    tempFilters['studyStatus'] = selected;
                                  } else {
                                    tempFilters.remove('studyStatus');
                                  }
                                });
                              },
                              getLabel: (status) =>
                                  statusLabels[status] ?? status,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Divider(),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              tempFilters.clear();
                            });
                          },
                          child: const Text('Clear All'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            // Chuyển đổi filter sang dạng String join
                            final filterMap = <String, String>{};
                            tempFilters.forEach((key, value) {
                              if (value.isNotEmpty) {
                                filterMap[key] = value.join(',');
                              }
                            });

                            ref.read(filterProvider.notifier).state = filterMap;
                            Navigator.pop(context);

                            // Áp dụng filter - RESET về trang 1
                            setState(() {
                              _currentPage = 0;
                              _totalItems = 0;
                            });
                            _loadFlashcardsWithFilter();
                            // _loadFlashcardsWithFilter sẽ tự động lưu tất cả trạng thái
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

  Widget _buildFilterSection(
    BuildContext context,
    String title,
    List<String> options,
    List<String> selected,
    Function(List<String>) onChanged, {
    String Function(String)? getLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          children: options.map((option) {
            final displayLabel = getLabel?.call(option) ?? option;
            final isSelected = selected is List && selected.contains(option);

            return FilterChip(
              label: Text(displayLabel),
              selected: isSelected,
              onSelected: (isSelected) {
                if (isSelected) {
                  // Tạo list mới
                  final newSelected =
                      List<String>.from(selected is List ? selected : []);
                  if (!newSelected.contains(option)) {
                    newSelected.add(option);
                  }
                  onChanged(newSelected);
                } else {
                  // Tạo list mới và xóa option
                  final newSelected =
                      List<String>.from(selected is List ? selected : []);
                  newSelected.remove(option);
                  onChanged(newSelected);
                }
              },
              backgroundColor: Colors.grey.shade200,
              selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.black87,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ==================== DIALOGS ====================

  void _showAddCardDialog(BuildContext context) {
    _clearControllers();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Flashcard (Local)'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField(
                    controller: _vietnameseController,
                    label: 'Vietnamese *',
                    hint: 'Enter Vietnamese word',
                    isRequired: true,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _englishController,
                    label: 'English',
                    hint: 'Enter English translation',
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _jpKanjiController,
                    label: 'Japanese Kanji',
                    hint: 'Enter Japanese Kanji',
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _jpReadingController,
                    label: 'Japanese Reading',
                    hint: 'Enter Hiragana/Katakana',
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _cnCharacterController,
                    label: 'Chinese Character',
                    hint: 'Enter Chinese character',
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _cnPinyinController,
                    label: 'Chinese Pinyin',
                    hint: 'Enter Pinyin',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final newCard = _createFlashcardFromControllers();
                  Navigator.pop(context);

                  final success = await ref
                      .read(localFlashcardsProvider.notifier)
                      .addCard(newCard);

                  if (!context.mounted) return;

                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Flashcard added successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // Reset và load lại
                    setState(() {
                      _currentPage = 0;
                      _totalItems = 0;
                    });
                    _loadFlashcardsWithFilter();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('❌ Failed to add flashcard.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showEditCardDialog(BuildContext context, Flashcard card) {
    _loadCardToControllers(card);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Flashcard (Local)'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField(
                    controller: _vietnameseController,
                    label: 'Vietnamese *',
                    hint: 'Enter Vietnamese word',
                    isRequired: true,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _englishController,
                    label: 'English',
                    hint: 'Enter English translation',
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _jpKanjiController,
                    label: 'Japanese Kanji',
                    hint: 'Enter Japanese Kanji',
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _jpReadingController,
                    label: 'Japanese Reading',
                    hint: 'Enter Hiragana/Katakana',
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _cnCharacterController,
                    label: 'Chinese Character',
                    hint: 'Enter Chinese character',
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _cnPinyinController,
                    label: 'Chinese Pinyin',
                    hint: 'Enter Pinyin',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final updatedCard =
                      _createFlashcardFromControllers(id: card.id);
                  Navigator.pop(context);

                  final success = await ref
                      .read(localFlashcardsProvider.notifier)
                      .updateCard(updatedCard);

                  if (!context.mounted) return;

                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Flashcard updated successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadFlashcardsWithFilter();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('❌ Failed to update flashcard.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  String _searchField = 'all';

  void _showSearchDialog(BuildContext context) {
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Search Local Cards'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search field selector
                  DropdownButtonFormField<String>(
                    value: _searchField,
                    decoration: const InputDecoration(
                      labelText: 'Search in',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: 'all', child: Text('All Fields')),
                      const DropdownMenuItem(
                          value: 'vietnamese', child: Text('🇻🇳 Vietnamese')),
                      const DropdownMenuItem(
                          value: 'english', child: Text('🇬🇧 English')),
                      const DropdownMenuItem(
                          value: 'jp_kanji',
                          child: Text('🇯🇵 Japanese Kanji')),
                      const DropdownMenuItem(
                          value: 'jp_reading',
                          child: Text('🔊 Japanese Reading')),
                      const DropdownMenuItem(
                          value: 'cn_character',
                          child: Text('🇨🇳 Chinese Character')),
                      const DropdownMenuItem(
                          value: 'cn_pinyin', child: Text('🔊 Chinese Pinyin')),
                      const DropdownMenuItem(
                          value: 'example_sentence',
                          child: Text('💬 Example Sentence')),
                      const DropdownMenuItem(
                          value: 'context_note',
                          child: Text('📌 Context Note')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _searchField = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: 'Enter search keyword...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      _performSearch(value, _searchField);
                    },
                    autofocus: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _performSearch('', _searchField);
                    Navigator.pop(context);
                  },
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showExcelGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excel Format Guide'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your Excel file must have these 16 columns in order:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildColumnInfo(1, 'ID', 'Unique identifier'),
                _buildColumnInfo(2, 'Vietnamese', 'Vietnamese word (required)'),
                _buildColumnInfo(3, 'JP_Kanji', 'Japanese Kanji'),
                _buildColumnInfo(4, 'JP_Reading', 'Hiragana/Katakana reading'),
                _buildColumnInfo(5, 'JP_Type', 'Japanese type (Han/Thuần)'),
                _buildColumnInfo(
                    6, 'JP_Detail_Type', 'Detailed classification'),
                _buildColumnInfo(7, 'JP_Level', 'JLPT N1-N5'),
                _buildColumnInfo(8, 'English', 'English translation'),
                _buildColumnInfo(9, 'EN_IPA', 'English IPA pronunciation'),
                _buildColumnInfo(10, 'EN_Level', 'CEFR A1-C2'),
                _buildColumnInfo(11, 'Han_Viet', 'Sino-Vietnamese reading'),
                _buildColumnInfo(12, 'CN_Character', 'Chinese character'),
                _buildColumnInfo(13, 'CN_Pinyin', 'Chinese Pinyin'),
                _buildColumnInfo(14, 'CN_Level', 'HSK1-HSK6'),
                _buildColumnInfo(15, 'Example_Sentence', 'Example sentence'),
                _buildColumnInfo(16, 'Context_Note', 'Context notes'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💡 Tips:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text('• First row must be headers'),
                      Text('• Empty rows will be skipped'),
                      Text('• Vietnamese column is required'),
                      Text('• Use "Download Sample Excel" for template'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete All Local Cards?'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This action cannot be undone!',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('All your local flashcards will be permanently deleted.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(context);
                final success = await ref
                    .read(localFlashcardsProvider.notifier)
                    .deleteAllCards();
                if (!context.mounted) return;
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ All local cards deleted'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  setState(() {
                    _currentPage = 0;
                    _totalItems = 0;
                  });
                  _loadFlashcardsWithFilter();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Failed to delete all cards'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );
  }

  // ==================== HELPER METHODS ====================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool isRequired = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }

  Widget _buildColumnInfo(int number, String name, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            alignment: Alignment.centerRight,
            child: Text(
              '$number.',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _clearControllers() {
    _vietnameseController.clear();
    _englishController.clear();
    _jpKanjiController.clear();
    _jpReadingController.clear();
    _jpTypeController.clear();
    _jpDetailTypeController.clear();
    _jpLevelController.clear();
    _enIpaController.clear();
    _enLevelController.clear();
    _hanVietController.clear();
    _cnCharacterController.clear();
    _cnPinyinController.clear();
    _cnLevelController.clear();
    _exampleSentenceController.clear();
    _contextNoteController.clear();
  }

  void _loadCardToControllers(Flashcard card) {
    _vietnameseController.text = card.vietnamese;
    _englishController.text = card.english ?? '';
    _jpKanjiController.text = card.jpKanji ?? '';
    _jpReadingController.text = card.jpReading ?? '';
    _jpTypeController.text = card.jpType ?? '';
    _jpDetailTypeController.text = card.jpDetailType ?? '';
    _jpLevelController.text = card.jpLevel ?? '';
    _enIpaController.text = card.enIpa ?? '';
    _enLevelController.text = card.enLevel ?? '';
    _hanVietController.text = card.hanViet ?? '';
    _cnCharacterController.text = card.cnCharacter ?? '';
    _cnPinyinController.text = card.cnPinyin ?? '';
    _cnLevelController.text = card.cnLevel ?? '';
    _exampleSentenceController.text = card.exampleSentence ?? '';
    _contextNoteController.text = card.contextNote ?? '';
  }

  Flashcard _createFlashcardFromControllers({String? id}) {
    return Flashcard(
      id: id ?? '',
      vietnamese: _vietnameseController.text,
      english:
          _englishController.text.isNotEmpty ? _englishController.text : null,
      jpKanji:
          _jpKanjiController.text.isNotEmpty ? _jpKanjiController.text : null,
      jpReading: _jpReadingController.text.isNotEmpty
          ? _jpReadingController.text
          : null,
      jpType: _jpTypeController.text.isNotEmpty ? _jpTypeController.text : null,
      jpDetailType: _jpDetailTypeController.text.isNotEmpty
          ? _jpDetailTypeController.text
          : null,
      jpLevel:
          _jpLevelController.text.isNotEmpty ? _jpLevelController.text : null,
      enIpa: _enIpaController.text.isNotEmpty ? _enIpaController.text : null,
      enLevel:
          _enLevelController.text.isNotEmpty ? _enLevelController.text : null,
      hanViet:
          _hanVietController.text.isNotEmpty ? _hanVietController.text : null,
      cnCharacter: _cnCharacterController.text.isNotEmpty
          ? _cnCharacterController.text
          : null,
      cnPinyin:
          _cnPinyinController.text.isNotEmpty ? _cnPinyinController.text : null,
      cnLevel:
          _cnLevelController.text.isNotEmpty ? _cnLevelController.text : null,
      exampleSentence: _exampleSentenceController.text.isNotEmpty
          ? _exampleSentenceController.text
          : null,
      contextNote: _contextNoteController.text.isNotEmpty
          ? _contextNoteController.text
          : null,
    );
  }

  // Hàm mở login dialog
  void _showLoginDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final emailController = TextEditingController();
            final passwordController = TextEditingController();
            final formKey = GlobalKey<FormState>();
            bool isLogin = true;
            bool obscurePassword = true;
            bool isLoading = false;
            String? errorMessage;

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.cloud_sync, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Text(isLogin ? 'Sign In to Sync' : 'Create Account'),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isLogin
                            ? 'Sign in to sync your flashcards and progress'
                            : 'Create an account to sync your flashcards and progress',
                        style:
                            const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),

                      // Email
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Password
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),

                      // Error message
                      if (errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            errorMessage!,
                            style: TextStyle(
                                color: Colors.red.shade700, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      isLogin = !isLogin;
                      errorMessage = null;
                    });
                  },
                  child: Text(isLogin ? 'Create Account' : 'Back to Sign In'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setState(() {
                              isLoading = true;
                              errorMessage = null;
                            });

                            final authNotifier =
                                ref.read(authNotifierProvider.notifier);
                            bool success;

                            if (isLogin) {
                              success = await authNotifier.signIn(
                                emailController.text,
                                passwordController.text,
                              );
                            } else {
                              success = await authNotifier.signUp(
                                emailController.text,
                                passwordController.text,
                              );
                            }

                            if (!mounted) return;

                            if (success &&
                                ref
                                    .read(authNotifierProvider)
                                    .isAuthenticated) {
                              // Đóng dialog
                              Navigator.pop(context);

                              // Hiển thị loading
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text('Syncing data from server...'),
                                    ],
                                  ),
                                  duration: Duration(seconds: 30),
                                ),
                              );

                              // Đồng bộ toàn bộ dữ liệu
                              await _syncAllData();

                              // Refresh danh sách
                              await ref
                                  .read(localFlashcardsProvider.notifier)
                                  .loadLocalFlashcards();
                              setState(() {
                                _currentPage = 0;
                                _totalItems = 0;
                              });
                              _loadFlashcardsWithFilter();

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('✅ Sync completed successfully!'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            } else {
                              setState(() {
                                isLoading = false;
                                errorMessage =
                                    'Login failed. Please check your credentials.';
                              });
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isLogin ? 'Sign In & Sync' : 'Create & Sync'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _syncAllData() async {
    try {
      print('🔄 Starting full sync...');

      final supabaseSource = SupabaseSource();
      final localDb = LocalDatabase();

      // 1. Tải toàn bộ flashcards từ Supabase
      final serverCards = await supabaseSource.getAllFlashcards();
      print('📥 Downloaded ${serverCards.length} cards from server');

      // 2. Lấy local cards
      final localCards = await localDb.getAllFlashcards();
      print('📚 Local cards: ${localCards.length}');

      // 3. Merge dữ liệu: ưu tiên server (vì có study status đã đồng bộ)
      // Tạo map để dễ tìm kiếm
      final serverCardMap = {for (var card in serverCards) card.id: card};
      final localCardMap = {for (var card in localCards) card.id: card};

      int updatedCount = 0;
      int addedCount = 0;

      // Cập nhật local từ server (ưu tiên server)
      for (var serverCard in serverCards) {
        if (localCardMap.containsKey(serverCard.id)) {
          // Card đã có local, cập nhật study status
          final localCard = localCardMap[serverCard.id]!;
          if (localCard.studyStatus != serverCard.studyStatus) {
            final updatedCard =
                localCard.copyWith(studyStatus: serverCard.studyStatus);
            await localDb.updateFlashcard(updatedCard);
            updatedCount++;
          }
        } else {
          // Card chưa có local, thêm mới
          await localDb.insertFlashcard(serverCard);
          addedCount++;
        }
      }

      // 4. Upload local cards chưa có trên server (nếu có)
      int uploadedCount = 0;
      for (var localCard in localCards) {
        if (!serverCardMap.containsKey(localCard.id) &&
            localCard.studyStatus != null) {
          // Upload study status lên server
          await supabaseSource.syncStudyStatus(
              localCard.id, localCard.studyStatus!);
          uploadedCount++;
        }
      }

      print(
          '✅ Sync completed: updated=$updatedCount, added=$addedCount, uploaded=$uploadedCount');
    } catch (e) {
      print('❌ Sync error: $e');
      rethrow;
    }
  }

  // Hàm sync study status
  Future<void> _syncStudyStatus() async {
    final authState = ref.read(authNotifierProvider);

    // Kiểm tra đăng nhập
    if (!authState.isAuthenticated) {
      _showLoginDialog();
      return;
    }

    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      final localDb = LocalDatabase();
      final allCards = await localDb.getAllFlashcards();

      // Lấy các card có study status
      final updates = <String, String>{};
      for (var card in allCards) {
        if (card.studyStatus != null) {
          updates[card.id] = card.studyStatus!;
        }
      }

      if (updates.isNotEmpty) {
        final supabaseSource = SupabaseSource();
        await supabaseSource.syncMultipleStudyStatus(updates);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Synced ${updates.length} study statuses'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ℹ️ No study statuses to sync'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error syncing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '❌ Sync failed: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

// Hàm load study status từ server
  Future<void> _loadStudyStatusFromServer() async {
    final authState = ref.read(authNotifierProvider);

    if (!authState.isAuthenticated) {
      return;
    }

    try {
      print('📥 Loading study statuses from server...');
      final supabaseSource = SupabaseSource();
      final statusMap = await supabaseSource.loadStudyStatus();

      if (statusMap.isEmpty) {
        print('ℹ️ No study statuses on server');
        return;
      }

      // Cập nhật local database
      final localDb = LocalDatabase();
      final allCards = await localDb.getAllFlashcards();

      int updatedCount = 0;
      for (var card in allCards) {
        if (statusMap.containsKey(card.id)) {
          final serverStatus = statusMap[card.id];
          if (serverStatus != null && serverStatus != card.studyStatus) {
            final updatedCard = card.copyWith(studyStatus: serverStatus);
            await localDb.updateFlashcard(updatedCard);
            updatedCount++;
          }
        }
      }

      if (updatedCount > 0) {
        // Refresh danh sách
        await ref.read(localFlashcardsProvider.notifier).loadLocalFlashcards();
        print('✅ Updated $updatedCount cards from server');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('✅ Loaded $updatedCount study statuses from server'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error loading study statuses: $e');
    }
  }

// Hàm đăng xuất
  Future<void> _logout() async {
    final authNotifier = ref.read(authNotifierProvider.notifier);
    await authNotifier.signOut();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('👋 Logged out'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // ==================== SAVE / LOAD PAGE STATE ====================

  Future<void> _saveCurrentPage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('current_page', _currentPage);
      await prefs.setInt('page_size', _pageSize);
      print('💾 Saved page state: page $_currentPage, size $_pageSize');
    } catch (e) {
      print('❌ Error saving page state: $e');
    }
  }

  Future<void> _loadCurrentPage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPage = prefs.getInt('current_page');
      final savedSize = prefs.getInt('page_size');

      if (savedPage != null) {
        setState(() {
          _currentPage = savedPage;
        });
        print('📂 Loaded page state: page $_currentPage');
      }

      if (savedSize != null) {
        setState(() {
          _pageSize = savedSize;
          _itemsPerPage = savedSize;
        });
      }
    } catch (e) {
      print('❌ Error loading page state: $e');
    }
  }

  // ==================== SAVE / LOAD FILTER STATE ====================

  Future<void> _saveFilterState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filters = ref.read(filterProvider);

      // Lưu từng filter
      if (filters.containsKey('jpLevel')) {
        await prefs.setString('filter_jpLevel', filters['jpLevel'] ?? '');
      }
      if (filters.containsKey('enLevel')) {
        await prefs.setString('filter_enLevel', filters['enLevel'] ?? '');
      }
      if (filters.containsKey('cnLevel')) {
        await prefs.setString('filter_cnLevel', filters['cnLevel'] ?? '');
      }
      if (filters.containsKey('jpDetailType')) {
        await prefs.setString(
            'filter_jpDetailType', filters['jpDetailType'] ?? '');
      }
      if (filters.containsKey('studyStatus')) {
        await prefs.setString(
            'filter_studyStatus', filters['studyStatus'] ?? '');
      }
      if (filters.containsKey('searchQuery')) {
        await prefs.setString(
            'filter_searchQuery', filters['searchQuery'] ?? '');
      }
      if (filters.containsKey('sortBy')) {
        await prefs.setString('filter_sortBy', filters['sortBy'] ?? 'id');
      }
      if (filters.containsKey('sortAscending')) {
        await prefs.setBool(
            'filter_sortAscending', filters['sortAscending'] ?? true);
      }

      print('💾 Saved filter state');
    } catch (e) {
      print('❌ Error saving filter state: $e');
    }
  }

  Future<void> _loadFilterState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filters = <String, dynamic>{};

      // Load từng filter
      final jpLevel = prefs.getString('filter_jpLevel');
      if (jpLevel != null && jpLevel.isNotEmpty) {
        filters['jpLevel'] = jpLevel;
      }

      final enLevel = prefs.getString('filter_enLevel');
      if (enLevel != null && enLevel.isNotEmpty) {
        filters['enLevel'] = enLevel;
      }

      final cnLevel = prefs.getString('filter_cnLevel');
      if (cnLevel != null && cnLevel.isNotEmpty) {
        filters['cnLevel'] = cnLevel;
      }

      final jpDetailType = prefs.getString('filter_jpDetailType');
      if (jpDetailType != null && jpDetailType.isNotEmpty) {
        filters['jpDetailType'] = jpDetailType;
      }

      final studyStatus = prefs.getString('filter_studyStatus');
      if (studyStatus != null && studyStatus.isNotEmpty) {
        filters['studyStatus'] = studyStatus;
      }

      final searchQuery = prefs.getString('filter_searchQuery');
      if (searchQuery != null && searchQuery.isNotEmpty) {
        filters['searchQuery'] = searchQuery;
      }

      final sortBy = prefs.getString('filter_sortBy');
      if (sortBy != null && sortBy.isNotEmpty) {
        filters['sortBy'] = sortBy;
      }

      final sortAscending = prefs.getBool('filter_sortAscending');
      if (sortAscending != null) {
        filters['sortAscending'] = sortAscending;
      }

      if (filters.isNotEmpty) {
        ref.read(filterProvider.notifier).state = filters;
        print('📂 Loaded filter state: $filters');
      }
    } catch (e) {
      print('❌ Error loading filter state: $e');
    }
  }

  // ==================== SAVE / LOAD SETTINGS STATE ====================

  Future<void> _saveSettingsState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = ref.read(settingsProvider);

      // Lưu items per page
      await prefs.setInt(
          'settings_itemsPerPage', settings['itemsPerPage'] ?? 50);

      // Lưu sort
      await prefs.setString('settings_sortBy', settings['sortBy'] ?? 'id');
      await prefs.setBool(
          'settings_sortAscending', settings['sortAscending'] ?? true);

      // Lưu show fields
      final showFields = settings['showFields'] as Map<String, bool>?;
      if (showFields != null) {
        final fieldsJson = <String, String>{};
        showFields.forEach((key, value) {
          fieldsJson[key] = value.toString();
        });
        await prefs.setString('settings_showFields', fieldsJson.toString());
      }

      // Lưu selected filters
      final selectedFilters = _selectedFilters;
      if (selectedFilters.isNotEmpty) {
        final filtersJson = <String, String>{};
        selectedFilters.forEach((key, value) {
          filtersJson[key] = value.join(',');
        });
        await prefs.setString(
            'settings_selectedFilters', filtersJson.toString());
      }

      print('💾 Saved settings state');
    } catch (e) {
      print('❌ Error saving settings state: $e');
    }
  }

  Future<void> _loadSettingsState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = <String, dynamic>{};

      // Load items per page
      final itemsPerPage = prefs.getInt('settings_itemsPerPage');
      if (itemsPerPage != null) {
        settings['itemsPerPage'] = itemsPerPage;
        setState(() {
          _itemsPerPage = itemsPerPage;
          _pageSize = itemsPerPage;
        });
      }

      // Load sort
      final sortBy = prefs.getString('settings_sortBy');
      if (sortBy != null) {
        settings['sortBy'] = sortBy;
        setState(() {
          _sortBy = sortBy;
        });
      }

      final sortAscending = prefs.getBool('settings_sortAscending');
      if (sortAscending != null) {
        settings['sortAscending'] = sortAscending;
        setState(() {
          _sortAscending = sortAscending;
        });
      }

      // Load show fields
      final showFieldsData = prefs.getString('settings_showFields');
      if (showFieldsData != null && showFieldsData.isNotEmpty) {
        try {
          final Map<String, bool> showFields = {};
          final cleaned =
              showFieldsData.replaceAll('{', '').replaceAll('}', '');
          final parts = cleaned.split(', ');
          for (var part in parts) {
            final pair = part.split(': ');
            if (pair.length == 2) {
              final key = pair[0].trim();
              final value = pair[1].trim() == 'true';
              showFields[key] = value;
            }
          }
          if (showFields.isNotEmpty) {
            settings['showFields'] = showFields;
            setState(() {
              _showFields = showFields;
            });
          }
        } catch (e) {
          print('❌ Error parsing show fields: $e');
        }
      }

      // Load selected filters
      final selectedFiltersData = prefs.getString('settings_selectedFilters');
      if (selectedFiltersData != null && selectedFiltersData.isNotEmpty) {
        try {
          final Map<String, List<String>> selectedFilters = {};
          final cleaned =
              selectedFiltersData.replaceAll('{', '').replaceAll('}', '');
          final parts = cleaned.split(', ');
          for (var part in parts) {
            final pair = part.split(': ');
            if (pair.length == 2) {
              final key = pair[0].trim();
              final values =
                  pair[1].trim().split(',').where((s) => s.isNotEmpty).toList();
              selectedFilters[key] = values;
            }
          }
          if (selectedFilters.isNotEmpty) {
            setState(() {
              _selectedFilters = selectedFilters;
            });
          }
        } catch (e) {
          print('❌ Error parsing selected filters: $e');
        }
      }

      if (settings.isNotEmpty) {
        ref.read(settingsProvider.notifier).state = settings;
        print('📂 Loaded settings state');
      }
    } catch (e) {
      print('❌ Error loading settings state: $e');
    }
  }
}
