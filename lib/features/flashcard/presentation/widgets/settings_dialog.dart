import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsDialog extends ConsumerStatefulWidget {
  final int itemsPerPage;
  final Map<String, bool> showFields;
  final Map<String, List<String>> selectedFilters;
  final Function(int, Map<String, bool>, Map<String, List<String>>) onApply;

  const SettingsDialog({
    super.key,
    required this.itemsPerPage,
    required this.showFields,
    required this.selectedFilters,
    required this.onApply,
  });

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  late int _itemsPerPage;
  late Map<String, bool> _showFields;
  late Map<String, List<String>> _selectedFilters;

  // Danh sách các trường có thể hiển thị
  final List<Map<String, String>> _fieldOptions = [
    {'key': 'vietnamese', 'label': '🇻🇳 Vietnamese', 'required': 'true'},
    {'key': 'english', 'label': '🇬🇧 English', 'required': 'false'},
    {'key': 'jpKanji', 'label': '🇯🇵 Japanese Kanji', 'required': 'false'},
    {'key': 'jpReading', 'label': '🔊 Japanese Reading', 'required': 'false'},
    {'key': 'jpType', 'label': '📝 Japanese Type', 'required': 'false'},
    {'key': 'jpDetailType', 'label': '📋 Word Detail Type', 'required': 'false'},
    {'key': 'jpLevel', 'label': '📊 JLPT Level', 'required': 'false'},
    {'key': 'enIpa', 'label': '🔊 English IPA', 'required': 'false'},
    {'key': 'enLevel', 'label': '📊 CEFR Level', 'required': 'false'},
    {'key': 'hanViet', 'label': '🇻🇳 Han-Viet', 'required': 'false'},
    {'key': 'cnCharacter', 'label': '🇨🇳 Chinese Character', 'required': 'false'},
    {'key': 'cnPinyin', 'label': '🔊 Chinese Pinyin', 'required': 'false'},
    {'key': 'cnLevel', 'label': '📊 HSK Level', 'required': 'false'},
    {'key': 'exampleSentence', 'label': '💬 Example Sentence', 'required': 'false'},
    {'key': 'contextNote', 'label': '📌 Context Note', 'required': 'false'},
  ];

  // Các tùy chọn lọc
  final Map<String, List<String>> _filterOptions = {
    'jpLevel': ['N1', 'N2', 'N3', 'N4', 'N5'],
    'enLevel': ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'],
    'cnLevel': ['HSK1', 'HSK2', 'HSK3', 'HSK4', 'HSK5', 'HSK6'],
    'jpDetailType': ['Danh từ', 'Động từ', 'Tính từ', 'Phó từ', 'Liên từ', 'Trợ từ', 'Khác'],
    'studyStatus': ['new', 'learning', 'reviewing', 'mastered'],
  };

  final Map<String, String> _filterLabels = {
    'jpLevel': 'JLPT Level',
    'enLevel': 'CEFR Level',
    'cnLevel': 'HSK Level',
    'jpDetailType': 'Word Type',
    'studyStatus': 'Study Status',
  };

  @override
  void initState() {
    super.initState();
    _itemsPerPage = widget.itemsPerPage;
    // Copy dữ liệu an toàn
    _showFields = Map<String, bool>.from(widget.showFields);
    _selectedFilters = {};
    widget.selectedFilters.forEach((key, value) {
      _selectedFilters[key] = List<String>.from(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                Icon(Icons.settings, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Settings',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                    _buildItemsPerPageSection(),
                    
                    const Divider(),
                    
                    // Show/Hide Fields
                    _buildFieldsSection(),
                    
                    const Divider(),
                    
                    // Multi-select Filters
                    _buildFiltersSection(),
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    // Gửi dữ liệu với kiểu đúng
                    widget.onApply(
                      _itemsPerPage,
                      Map<String, bool>.from(_showFields),
                      Map<String, List<String>>.from(_selectedFilters),
                    );
                  },
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsPerPageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Items per page:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [25, 50, 100, 200, 500].map((size) {
            return ChoiceChip(
              label: Text('$size'),
              selected: _itemsPerPage == size,
              onSelected: (selected) {
                setState(() => _itemsPerPage = size);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFieldsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Show/Hide Fields:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ..._fieldOptions.map((field) {
          final key = field['key']!;
          final label = field['label']!;
          final isRequired = field['required'] == 'true';
          
          return CheckboxListTile(
            title: Text(label),
            value: _showFields[key] ?? true,
            onChanged: isRequired ? null : (checked) {
              setState(() {
                _showFields[key] = checked ?? true;
              });
            },
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            secondary: isRequired 
                ? const Icon(Icons.lock, size: 16, color: Colors.grey)
                : null,
          );
        }).toList(),
      ],
    );
  }

  Widget _buildFiltersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Multi-select Filters:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ..._filterOptions.keys.map((filterKey) {
          final label = _filterLabels[filterKey] ?? filterKey;
          final options = _filterOptions[filterKey]!;
          final selected = _selectedFilters[filterKey] ?? [];
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: options.map((option) {
                  final isSelected = selected.contains(option);
                  return FilterChip(
                    label: Text(option),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          if (!_selectedFilters.containsKey(filterKey)) {
                            _selectedFilters[filterKey] = [];
                          }
                          _selectedFilters[filterKey]!.add(option);
                        } else {
                          _selectedFilters[filterKey]?.remove(option);
                          if (_selectedFilters[filterKey]?.isEmpty ?? true) {
                            _selectedFilters.remove(filterKey);
                          }
                        }
                      });
                    },
                    backgroundColor: Colors.grey.shade200,
                    selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
          );
        }).toList(),
      ],
    );
  }
}