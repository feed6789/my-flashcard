import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flashcard_app/core/database/local_database.dart';

class FilterDialog extends ConsumerStatefulWidget {
  final Function(Map<String, dynamic>) onApply;
  final Map<String, dynamic> currentFilters;

  const FilterDialog({
    super.key,
    required this.onApply,
    this.currentFilters = const {},
  });

  @override
  ConsumerState<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends ConsumerState<FilterDialog> {
  String selectedJpLevel = '';
  String selectedEnLevel = '';
  String selectedCnLevel = '';
  String selectedJpDetailType = '';
  String selectedStudyStatus = '';
  String selectedSortBy = 'created_at';
  bool sortAscending = false;
  int pageSize = 50;
  
  List<String> jpDetailTypes = [];
  List<String> studyStatuses = ['', 'new', 'learning', 'reviewing', 'mastered'];

  final List<String> jpLevels = ['', 'N1', 'N2', 'N3', 'N4', 'N5'];
  final List<String> enLevels = ['', 'A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
  final List<String> cnLevels = ['', 'HSK1', 'HSK2', 'HSK3', 'HSK4', 'HSK5', 'HSK6'];
  final List<String> sortOptions = [
    'created_at',
    'vietnamese',
    'english',
    'jp_level',
    'en_level',
    'cn_level',
    'jp_detail_type',
  ];

  @override
  void initState() {
    super.initState();
    _loadJpDetailTypes();
    _loadCurrentFilters();
  }

  void _loadCurrentFilters() {
    setState(() {
      selectedJpLevel = widget.currentFilters['jpLevel'] ?? '';
      selectedEnLevel = widget.currentFilters['enLevel'] ?? '';
      selectedCnLevel = widget.currentFilters['cnLevel'] ?? '';
      selectedJpDetailType = widget.currentFilters['jpDetailType'] ?? '';
      selectedStudyStatus = widget.currentFilters['studyStatus'] ?? '';
      selectedSortBy = widget.currentFilters['sortBy'] ?? 'created_at';
      sortAscending = widget.currentFilters['sortAscending'] ?? false;
      pageSize = widget.currentFilters['pageSize'] ?? 50;
    });
  }

  Future<void> _loadJpDetailTypes() async {
    try {
      final types = await LocalDatabase().getAvailableJpDetailTypes();
      setState(() {
        jpDetailTypes = ['', ...types];
      });
    } catch (e) {
      print('❌ Error loading JP detail types: $e');
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'new': return '🆕 New';
      case 'learning': return '📖 Learning';
      case 'reviewing': return '🔄 Reviewing';
      case 'mastered': return '⭐ Mastered';
      default: return 'All';
    }
  }

  String _getSortLabel(String key) {
    switch (key) {
      case 'created_at': return 'Created Date';
      case 'vietnamese': return 'Vietnamese';
      case 'english': return 'English';
      case 'jp_level': return 'JLPT Level';
      case 'en_level': return 'CEFR Level';
      case 'cn_level': return 'HSK Level';
      case 'jp_detail_type': return 'Word Type';
      default: return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.filter_list),
          SizedBox(width: 8),
          Text('Filter & Sort'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // JLPT Filter
            _buildFilterSection('JLPT Level:', jpLevels, selectedJpLevel, (value) {
              setState(() => selectedJpLevel = value);
            }),
            
            const Divider(),
            
            // CEFR Filter
            _buildFilterSection('CEFR Level:', enLevels, selectedEnLevel, (value) {
              setState(() => selectedEnLevel = value);
            }),
            
            const Divider(),
            
            // HSK Filter
            _buildFilterSection('HSK Level:', cnLevels, selectedCnLevel, (value) {
              setState(() => selectedCnLevel = value);
            }),
            
            const Divider(),
            
            // Word Type Filter
            _buildFilterSection(
              'Word Type (JP):', 
              jpDetailTypes, 
              selectedJpDetailType, 
              (value) {
                setState(() => selectedJpDetailType = value);
              },
              isChip: true,
            ),
            
            const Divider(),
            
            // Study Status Filter
            _buildFilterSection(
              'Study Status:', 
              studyStatuses, 
              selectedStudyStatus, 
              (value) {
                setState(() => selectedStudyStatus = value);
              },
              isChip: true,
              getLabel: _getStatusLabel,
            ),
            
            const Divider(),
            
            // Sort
            const Text('Sort By:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: selectedSortBy,
                    isExpanded: true,
                    items: sortOptions.map((option) {
                      return DropdownMenuItem(
                        value: option,
                        child: Text(_getSortLabel(option)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedSortBy = value!);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                  onPressed: () {
                    setState(() => sortAscending = !sortAscending);
                  },
                  tooltip: sortAscending ? 'Ascending' : 'Descending',
                ),
              ],
            ),
            
            const Divider(),
            
            // Page Size
            const Text('Items per page:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButton<int>(
                    value: pageSize,
                    isExpanded: true,
                    items: [20, 50, 100, 200, 500].map((size) {
                      return DropdownMenuItem(
                        value: size,
                        child: Text('$size items'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => pageSize = value!);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              selectedJpLevel = '';
              selectedEnLevel = '';
              selectedCnLevel = '';
              selectedJpDetailType = '';
              selectedStudyStatus = '';
              selectedSortBy = 'created_at';
              sortAscending = false;
              pageSize = 50;
            });
          },
          child: const Text('Clear All'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final filters = {
              'jpLevel': selectedJpLevel,
              'enLevel': selectedEnLevel,
              'cnLevel': selectedCnLevel,
              'jpDetailType': selectedJpDetailType,
              'studyStatus': selectedStudyStatus,
              'sortBy': selectedSortBy,
              'sortAscending': sortAscending,
              'pageSize': pageSize,
            };
            widget.onApply(filters);
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _buildFilterSection(
    String title,
    List<String> options,
    String selected,
    Function(String) onSelected, {
    bool isChip = false,
    String Function(String)? getLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        isChip
            ? Wrap(
                spacing: 8,
                children: options.map((option) {
                  final displayLabel = getLabel?.call(option) ?? (option.isEmpty ? 'All' : option);
                  return FilterChip(
                    label: Text(displayLabel),
                    selected: selected == option,
                    onSelected: (_) => onSelected(option),
                  );
                }).toList(),
              )
            : Wrap(
                spacing: 8,
                children: options.map((option) {
                  return FilterChip(
                    label: Text(option.isEmpty ? 'All' : option),
                    selected: selected == option,
                    onSelected: (_) => onSelected(option),
                  );
                }).toList(),
              ),
      ],
    );
  }
}