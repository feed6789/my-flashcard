import 'package:flutter/material.dart';
import 'package:flashcard_app/features/flashcard/data/models/flashcard_model.dart';

class FlashcardCard extends StatelessWidget {
  final Flashcard card;
  final bool isReadOnly;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final Function(String)? onStatusChange;
  final Map<String, bool>? showFields;

  const FlashcardCard({
    super.key,
    required this.card,
    this.isReadOnly = false,
    this.onDelete,
    this.onEdit,
    this.onStatusChange,
    this.showFields,
  });

  bool _shouldShow(String field) {
    return showFields == null || showFields![field] != false;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // Badge cho biết nguồn dữ liệu
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isReadOnly ? Colors.blue.shade100 : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isReadOnly ? '📡 Server' : '💾 Local',
                          style: TextStyle(
                            fontSize: 10,
                            color: isReadOnly ? Colors.blue.shade800 : Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Vietnamese - luôn hiển thị
                      Expanded(
                        child: Text(
                          card.vietnamese,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Study Status Dropdown (chỉ cho local)
                if (!isReadOnly && onStatusChange != null)
                  _buildStatusDropdown(),
                if (!isReadOnly) ...[
                  if (onEdit != null)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: onEdit,
                      iconSize: 20,
                    ),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: onDelete,
                      iconSize: 20,
                    ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            
            // English
            if (card.english != null && _shouldShow('english'))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '🇬🇧 ${card.english}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            
            // Japanese Kanji
            if (card.jpKanji != null && _shouldShow('jpKanji'))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🇯🇵 ${card.jpKanji}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (card.jpReading != null && _shouldShow('jpReading'))
                      Text(
                        '  (${card.jpReading})',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                  ],
                ),
              ),
            
            // Han Viet
            if (card.hanViet != null && _shouldShow('hanViet'))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '🇻🇳 ${card.hanViet}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            
            // Chinese Character
            if (card.cnCharacter != null && _shouldShow('cnCharacter'))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🇨🇳 ${card.cnCharacter}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (card.cnPinyin != null && _shouldShow('cnPinyin'))
                      Text(
                        '  (${card.cnPinyin})',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                  ],
                ),
              ),
            
            // Word Type
            if (card.jpDetailType != null && _shouldShow('jpDetailType'))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '📝 ${card.jpDetailType}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple.shade800,
                    ),
                  ),
                ),
              ),
            
            // Levels
            if ((card.jpLevel != null && _shouldShow('jpLevel')) || 
                (card.enLevel != null && _shouldShow('enLevel')) || 
                (card.cnLevel != null && _shouldShow('cnLevel')))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (card.jpLevel != null && _shouldShow('jpLevel'))
                      Chip(
                        label: Text('JLPT ${card.jpLevel}'),
                        backgroundColor: Colors.blue.shade100,
                      ),
                    if (card.enLevel != null && _shouldShow('enLevel'))
                      Chip(
                        label: Text('CEFR ${card.enLevel}'),
                        backgroundColor: Colors.green.shade100,
                      ),
                    if (card.cnLevel != null && _shouldShow('cnLevel'))
                      Chip(
                        label: Text('HSK ${card.cnLevel}'),
                        backgroundColor: Colors.red.shade100,
                      ),
                  ],
                ),
              ),
            
            // Example Sentence
            if (card.exampleSentence != null && _shouldShow('exampleSentence'))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '💬 ${card.exampleSentence}',
                    style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                ),
              ),
            
            // Context Note
            if (card.contextNote != null && _shouldShow('contextNote'))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Text(
                    '📌 ${card.contextNote}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
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

    final currentStatus = card.studyStatus ?? 'new';
    final statusList = ['new', 'learning', 'reviewing', 'mastered'];
    final statusLabels = {
      'new': '🆕 New',
      'learning': '📖 Learning',
      'reviewing': '🔄 Reviewing',
      'mastered': '⭐ Mastered',
    };

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
              statusLabels[status] ?? status,
              style: const TextStyle(fontSize: 12),
            ),
          );
        }).toList(),
        onChanged: (newStatus) {
          if (newStatus != null) {
            onStatusChange?.call(newStatus);
          }
        },
      ),
    );
  }
}