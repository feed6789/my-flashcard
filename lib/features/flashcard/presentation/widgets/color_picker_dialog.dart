import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flashcard_app/core/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ColorPickerDialog extends ConsumerStatefulWidget {
  const ColorPickerDialog({super.key});

  @override
  ConsumerState<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends ConsumerState<ColorPickerDialog> {
  Color selectedColor = Colors.deepPurple;
  
  final List<Color> colorOptions = [
    Colors.deepPurple,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
    Colors.pink,
    Colors.red,
    Colors.orange,
    Colors.amber,
    Colors.green,
    Colors.teal,
    Colors.cyan,
    Colors.brown,
  ];

  @override
  void initState() {
    super.initState();
    selectedColor = ref.read(themeColorProvider);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.color_lens, color: Colors.blue),
          SizedBox(width: 8),
          Text('Choose Theme Color'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colorOptions.map((color) {
            final isSelected = selectedColor == color;
            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedColor = color;
                });
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 4,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ] : [],
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            ref.read(themeColorProvider.notifier).state = selectedColor;
            // Lưu màu vào SharedPreferences
            _saveThemeColor(selectedColor);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: selectedColor,
          ),
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Future<void> _saveThemeColor(Color color) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('theme_color', color.value);
      print('💾 Theme color saved');
    } catch (e) {
      print('❌ Error saving theme color: $e');
    }
  }
}