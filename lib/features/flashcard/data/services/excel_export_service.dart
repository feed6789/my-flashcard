import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flashcard_app/core/database/local_database.dart';
import 'package:flashcard_app/features/flashcard/data/models/flashcard_model.dart';
import 'package:flutter/material.dart';

class ExcelExportService {
  // Định nghĩa các cột
  static const List<String> columnNames = [
    'id',
    'vietnamese',
    'jp_kanji',
    'jp_reading',
    'jp_type',
    'jp_detail_type',
    'jp_level',
    'english',
    'en_ipa',
    'en_level',
    'han_viet',
    'cn_character',
    'cn_pinyin',
    'cn_level',
    'example_sentence',
    'context_note'
  ];

  // Export flashcards ra file Excel
  Future<void> exportToExcel(List<Flashcard> flashcards, {String? fileName}) async {
    try {
      // Tạo Excel
      var excel = Excel.createExcel();
      String sheetName = 'Flashcards';
      Sheet sheetObject = excel[sheetName]!;

      // Thêm header
      List<String> headers = [
        'ID', 'Vietnamese', 'JP_Kanji', 'JP_Reading', 'JP_Type',
        'JP_Detail_Type', 'JP_Level', 'English', 'EN_IPA', 'EN_Level',
        'Han_Viet', 'CN_Character', 'CN_Pinyin', 'CN_Level',
        'Example_Sentence', 'Context_Note'
      ];

      sheetObject.appendRow(headers.map((h) => TextCellValue(h)).toList());

      // Thêm dữ liệu
      for (var card in flashcards) {
        sheetObject.appendRow([
          TextCellValue(card.id),
          TextCellValue(card.vietnamese),
          TextCellValue(card.jpKanji ?? ''),
          TextCellValue(card.jpReading ?? ''),
          TextCellValue(card.jpType ?? ''),
          TextCellValue(card.jpDetailType ?? ''),
          TextCellValue(card.jpLevel ?? ''),
          TextCellValue(card.english ?? ''),
          TextCellValue(card.enIpa ?? ''),
          TextCellValue(card.enLevel ?? ''),
          TextCellValue(card.hanViet ?? ''),
          TextCellValue(card.cnCharacter ?? ''),
          TextCellValue(card.cnPinyin ?? ''),
          TextCellValue(card.cnLevel ?? ''),
          TextCellValue(card.exampleSentence ?? ''),
          TextCellValue(card.contextNote ?? ''),
        ]);
      }

      // Lưu file
      List<int>? fileBytes = excel.save();
      if (fileBytes == null) {
        throw Exception('Failed to generate Excel file');
      }

      // Chuyển sang Uint8List
      Uint8List bytes = Uint8List.fromList(fileBytes);

      // Mở dialog save file
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Flashcards',
        fileName: fileName ?? 'flashcards_export_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        bytes: bytes,
      );

      if (outputFile != null) {
        print('✅ Exported to: $outputFile');
      } else {
        print('ℹ️ User cancelled export');
      }

    } catch (e) {
      print('❌ Error exporting Excel: $e');
      throw Exception('Failed to export Excel: $e');
    }
  }

  // Export flashcards ra file CSV
  Future<void> exportToCSV(List<Flashcard> flashcards, {String? fileName}) async {
    try {
      // Tạo CSV content
      StringBuffer csvBuffer = StringBuffer();

      // Thêm header
      csvBuffer.writeln(columnNames.join(','));

      // Thêm dữ liệu
      for (var card in flashcards) {
        List<String> row = [
          card.id,
          card.vietnamese,
          card.jpKanji ?? '',
          card.jpReading ?? '',
          card.jpType ?? '',
          card.jpDetailType ?? '',
          card.jpLevel ?? '',
          card.english ?? '',
          card.enIpa ?? '',
          card.enLevel ?? '',
          card.hanViet ?? '',
          card.cnCharacter ?? '',
          card.cnPinyin ?? '',
          card.cnLevel ?? '',
          card.exampleSentence ?? '',
          card.contextNote ?? '',
        ];
        // Escape dấu phẩy trong nội dung
        row = row.map((cell) {
          if (cell.contains(',') || cell.contains('"') || cell.contains('\n')) {
            return '"${cell.replaceAll('"', '""')}"';
          }
          return cell;
        }).toList();
        csvBuffer.writeln(row.join(','));
      }

      // Chuyển thành bytes
      Uint8List bytes = Uint8List.fromList(csvBuffer.toString().codeUnits);

      // Mở dialog save file
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Flashcards',
        fileName: fileName ?? 'flashcards_export_${DateTime.now().millisecondsSinceEpoch}.csv',
        bytes: bytes,
      );

      if (outputFile != null) {
        print('✅ Exported to: $outputFile');
      } else {
        print('ℹ️ User cancelled export');
      }

    } catch (e) {
      print('❌ Error exporting CSV: $e');
      throw Exception('Failed to export CSV: $e');
    }
  }

  // Export toàn bộ local flashcards
  Future<void> exportAllLocalFlashcards() async {
    try {
      final localDb = LocalDatabase();
      final cards = await localDb.getAllFlashcards();

      if (cards.isEmpty) {
        throw Exception('No flashcards to export');
      }

      // Hỏi người dùng chọn format
      final format = await _showFormatDialog();
      if (format == null) return;

      if (format == 'excel') {
        await exportToExcel(cards);
      } else {
        await exportToCSV(cards);
      }

    } catch (e) {
      print('❌ Export error: $e');
      rethrow;
    }
  }

  // Export flashcards đã lọc
  Future<void> exportFilteredFlashcards(List<Flashcard> cards) async {
    if (cards.isEmpty) {
      throw Exception('No flashcards to export');
    }

    final format = await _showFormatDialog();
    if (format == null) return;

    if (format == 'excel') {
      await exportToExcel(cards);
    } else {
      await exportToCSV(cards);
    }
  }

  // Dialog chọn format
  Future<String?> _showFormatDialog() async {
    // Lưu ý: Hàm này cần context, sẽ được gọi từ widget
    return 'excel'; // Mặc định, sẽ được override
  }

  // Hàm cho widget gọi
  Future<void> exportWithFormat(BuildContext context, List<Flashcard> cards) async {
    if (cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No flashcards to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Hiển thị dialog chọn format
    final format = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Export Format'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.table_chart, color: Colors.green),
                title: const Text('Excel (.xlsx)'),
                subtitle: const Text('Best for editing'),
                onTap: () => Navigator.pop(context, 'excel'),
              ),
              ListTile(
                leading: const Icon(Icons.text_fields, color: Colors.blue),
                title: const Text('CSV (.csv)'),
                subtitle: const Text('Compatible with many apps'),
                onTap: () => Navigator.pop(context, 'csv'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (format == null) return;

    try {
      if (format == 'excel') {
        await exportToExcel(cards);
      } else {
        await exportToCSV(cards);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Exported ${cards.length} flashcards'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Export failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}