// lib/features/flashcard/data/services/excel_import_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flashcard_app/features/flashcard/data/models/flashcard_model.dart';

class ExcelImportService {
  // Định nghĩa các cột theo thứ tự
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

  /// Helper function để lấy giá trị từ cell an toàn
  String _getCellValue(dynamic cell) {
    if (cell == null) return '';
    try {
      final value = cell.value;
      if (value == null) return '';
      if (value is DateTime) {
        return value.toIso8601String();
      }
      return value.toString().trim();
    } catch (e) {
      return '';
    }
  }

  /// Helper function để lấy giá trị từ row theo index
  String _getValueFromRow(List<dynamic> row, int index) {
    if (index < row.length && row[index] != null) {
      return _getCellValue(row[index]);
    }
    return '';
  }

  /// Import flashcards từ file Excel
  Future<List<Flashcard>> importFromFile() async {
    try {
      // Chọn file Excel
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        throw Exception('No file selected');
      }

      final file = result.files.first;
      final fileBytes = file.bytes;

      if (fileBytes == null) {
        throw Exception('Failed to read file: File bytes are null');
      }

      // Đọc file Excel - Chuyển List<int> sang Uint8List
      var excel = Excel.decodeBytes(Uint8List.fromList(fileBytes));

      if (excel.tables.isEmpty) {
        throw Exception('No sheets found in Excel file');
      }

      var sheet = excel.tables[excel.tables.keys.first];

      if (sheet == null) {
        throw Exception('No sheet found in Excel file');
      }

      print('📊 Excel file loaded: ${excel.tables.keys.first}');
      print('📊 Total rows: ${sheet.rows.length}');

      // Parse dữ liệu
      List<Flashcard> flashcards = [];
      int rowIndex = 0;

      for (var row in sheet.rows) {
        rowIndex++;

        // Bỏ qua header
        if (rowIndex == 1) {
          // Kiểm tra header có đúng format không
          var header = row.map((cell) => _getCellValue(cell)).toList();
          print('📋 Header: $header');
          continue;
        }

        // Bỏ qua hàng trống
        if (row.isEmpty ||
            row.every((cell) => cell == null || _getCellValue(cell).isEmpty)) {
          continue;
        }

        try {
          // Lấy dữ liệu từ các cột
          final id = _getValueFromRow(row, 0);
          final vietnamese = _getValueFromRow(row, 1);

          // Bỏ qua nếu không có Vietnamese
          if (vietnamese.isEmpty) {
            print('⚠️ Row $rowIndex: Skipped (empty Vietnamese)');
            continue;
          }

          final flashcard = Flashcard(
            id: id.isNotEmpty
                ? id
                : 'local_${DateTime.now().millisecondsSinceEpoch}_$rowIndex',
            vietnamese: vietnamese,
            jpKanji: _getValueFromRow(row, 2).isNotEmpty
                ? _getValueFromRow(row, 2)
                : null,
            jpReading: _getValueFromRow(row, 3).isNotEmpty
                ? _getValueFromRow(row, 3)
                : null,
            jpType: _getValueFromRow(row, 4).isNotEmpty
                ? _getValueFromRow(row, 4)
                : null,
            jpDetailType: _getValueFromRow(row, 5).isNotEmpty
                ? _getValueFromRow(row, 5)
                : null,
            jpLevel: _getValueFromRow(row, 6).isNotEmpty
                ? _getValueFromRow(row, 6)
                : null,
            english: _getValueFromRow(row, 7).isNotEmpty
                ? _getValueFromRow(row, 7)
                : null,
            enIpa: _getValueFromRow(row, 8).isNotEmpty
                ? _getValueFromRow(row, 8)
                : null,
            enLevel: _getValueFromRow(row, 9).isNotEmpty
                ? _getValueFromRow(row, 9)
                : null,
            hanViet: _getValueFromRow(row, 10).isNotEmpty
                ? _getValueFromRow(row, 10)
                : null,
            cnCharacter: _getValueFromRow(row, 11).isNotEmpty
                ? _getValueFromRow(row, 11)
                : null,
            cnPinyin: _getValueFromRow(row, 12).isNotEmpty
                ? _getValueFromRow(row, 12)
                : null,
            cnLevel: _getValueFromRow(row, 13).isNotEmpty
                ? _getValueFromRow(row, 13)
                : null,
            exampleSentence: _getValueFromRow(row, 14).isNotEmpty
                ? _getValueFromRow(row, 14)
                : null,
            contextNote: _getValueFromRow(row, 15).isNotEmpty
                ? _getValueFromRow(row, 15)
                : null,
          );

          flashcards.add(flashcard);
          print('✅ Row $rowIndex: Imported "${flashcard.vietnamese}"');
        } catch (e) {
          print('⚠️ Error parsing row $rowIndex: $e');
        }
      }

      if (flashcards.isNotEmpty) {
        print('📝 Sample first card:');
        print('  Vietnamese: ${flashcards.first.vietnamese}');
        print('  English: ${flashcards.first.english}');
        print('  JP Kanji: ${flashcards.first.jpKanji}');
      }

      if (flashcards.isEmpty) {
        throw Exception('No valid flashcards found in file');
      }

      // In thống kê
      print('📊 Import Statistics:');
      print('  Total cards parsed: ${flashcards.length}');
      print(
          '  Cards with Vietnamese: ${flashcards.where((c) => c.vietnamese.isNotEmpty).length}');
      print(
          '  Cards with English: ${flashcards.where((c) => c.english != null && c.english!.isNotEmpty).length}');
      print(
          '  Cards with JP Kanji: ${flashcards.where((c) => c.jpKanji != null && c.jpKanji!.isNotEmpty).length}');
      return flashcards;
    } catch (e) {
      print('❌ Import error: $e');
      throw Exception('Failed to import Excel: $e');
    }
  }

  /// Tạo và tải file Excel mẫu
  Future<void> exportSampleExcel() async {
    try {
      // Tạo Excel
      var excel = Excel.createExcel();
      String sheetName = 'Flashcards';
      Sheet sheetObject = excel[sheetName]!;

      // Định nghĩa headers
      List<String> headers = [
        'ID',
        'Vietnamese',
        'JP_Kanji',
        'JP_Reading',
        'JP_Type',
        'JP_Detail_Type',
        'JP_Level',
        'English',
        'EN_IPA',
        'EN_Level',
        'Han_Viet',
        'CN_Character',
        'CN_Pinyin',
        'CN_Level',
        'Example_Sentence',
        'Context_Note'
      ];

      // Thêm header row
      sheetObject.appendRow(headers.map((h) => TextCellValue(h)).toList());

      // Thêm dữ liệu mẫu
      List<List<String>> sampleData = [
        [
          '1',
          'Xin chào',
          'こんにちは',
          'こんにちは',
          'Greeting',
          'Casual',
          'N5',
          'Hello',
          'həˈloʊ',
          'A1',
          'Xin chào',
          '你好',
          'nǐ hǎo',
          'HSK1',
          'Xin chào, tôi là...',
          'Greeting in Japanese'
        ],
        [
          '2',
          'Cảm ơn',
          'ありがとう',
          'ありがとう',
          'Greeting',
          'Casual',
          'N5',
          'Thank you',
          'θæŋk juː',
          'A1',
          'Cảm ơn',
          '谢谢',
          'xiè xie',
          'HSK1',
          'Cảm ơn bạn đã giúp đỡ',
          'Gratitude expression'
        ],
        [
          '3',
          'Tôi',
          '私',
          'わたし',
          'Pronoun',
          'Personal',
          'N5',
          'I',
          'aɪ',
          'A1',
          'Tôi',
          '我',
          'wǒ',
          'HSK1',
          'Tôi là sinh viên',
          'First person pronoun'
        ],
        [
          '4',
          'Đẹp',
          '美しい',
          'うつくしい',
          'Adjective',
          'i-adjective',
          'N4',
          'Beautiful',
          'ˈbjuːtəfl',
          'A2',
          'Đẹp',
          '美丽',
          'měi lì',
          'HSK3',
          'Cô ấy rất đẹp',
          'Describing appearance'
        ],
        [
          '5',
          'Học',
          '勉強する',
          'べんきょうする',
          'Verb',
          'する-verb',
          'N5',
          'Study',
          'ˈstʌdi',
          'A1',
          'Học',
          '学习',
          'xué xí',
          'HSK1',
          'Tôi học tiếng Nhật',
          'Learning activity'
        ],
      ];

      // Thêm dữ liệu mẫu
      for (var rowData in sampleData) {
        sheetObject.appendRow(rowData.map((s) => TextCellValue(s)).toList());
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
        dialogTitle: 'Save Sample Excel File',
        fileName: 'sample_flashcards.xlsx',
        bytes: bytes,
      );

      if (outputFile != null) {
        print('✅ Sample Excel saved to: $outputFile');
      } else {
        print('ℹ️ User cancelled save');
      }
    } catch (e) {
      print('❌ Error creating sample Excel: $e');
      throw Exception('Failed to create sample Excel: $e');
    }
  }

  /// Đọc file Excel từ đường dẫn (dùng cho test)
  Future<List<Flashcard>> importFromPath(String filePath) async {
    try {
      File file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found: $filePath');
      }

      var fileBytes = await file.readAsBytes();
      var excel = Excel.decodeBytes(Uint8List.fromList(fileBytes));

      if (excel.tables.isEmpty) {
        throw Exception('No sheets found in Excel file');
      }

      var sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null) {
        throw Exception('No sheet found in Excel file');
      }

      List<Flashcard> flashcards = [];
      int rowIndex = 0;

      for (var row in sheet.rows) {
        rowIndex++;

        if (rowIndex == 1) continue; // Skip header

        if (row.isEmpty ||
            row.every((cell) => cell == null || _getCellValue(cell).isEmpty)) {
          continue;
        }

        try {
          final vietnamese = _getValueFromRow(row, 1);
          if (vietnamese.isEmpty) continue;

          final flashcard = Flashcard(
            id: _getValueFromRow(row, 0).isNotEmpty
                ? _getValueFromRow(row, 0)
                : 'local_${DateTime.now().millisecondsSinceEpoch}_$rowIndex',
            vietnamese: vietnamese,
            jpKanji: _getValueFromRow(row, 2).isNotEmpty
                ? _getValueFromRow(row, 2)
                : null,
            jpReading: _getValueFromRow(row, 3).isNotEmpty
                ? _getValueFromRow(row, 3)
                : null,
            jpType: _getValueFromRow(row, 4).isNotEmpty
                ? _getValueFromRow(row, 4)
                : null,
            jpDetailType: _getValueFromRow(row, 5).isNotEmpty
                ? _getValueFromRow(row, 5)
                : null,
            jpLevel: _getValueFromRow(row, 6).isNotEmpty
                ? _getValueFromRow(row, 6)
                : null,
            english: _getValueFromRow(row, 7).isNotEmpty
                ? _getValueFromRow(row, 7)
                : null,
            enIpa: _getValueFromRow(row, 8).isNotEmpty
                ? _getValueFromRow(row, 8)
                : null,
            enLevel: _getValueFromRow(row, 9).isNotEmpty
                ? _getValueFromRow(row, 9)
                : null,
            hanViet: _getValueFromRow(row, 10).isNotEmpty
                ? _getValueFromRow(row, 10)
                : null,
            cnCharacter: _getValueFromRow(row, 11).isNotEmpty
                ? _getValueFromRow(row, 11)
                : null,
            cnPinyin: _getValueFromRow(row, 12).isNotEmpty
                ? _getValueFromRow(row, 12)
                : null,
            cnLevel: _getValueFromRow(row, 13).isNotEmpty
                ? _getValueFromRow(row, 13)
                : null,
            exampleSentence: _getValueFromRow(row, 14).isNotEmpty
                ? _getValueFromRow(row, 14)
                : null,
            contextNote: _getValueFromRow(row, 15).isNotEmpty
                ? _getValueFromRow(row, 15)
                : null,
          );

          flashcards.add(flashcard);
        } catch (e) {
          print('⚠️ Error parsing row $rowIndex: $e');
        }
      }

      return flashcards;
    } catch (e) {
      print('❌ Import error: $e');
      throw Exception('Failed to import Excel: $e');
    }
  }

  /// Validate file Excel trước khi import
  Future<Map<String, dynamic>> validateExcelFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return {'valid': false, 'message': 'No file selected'};
      }

      final file = result.files.first;
      final fileBytes = file.bytes;

      if (fileBytes == null) {
        return {'valid': false, 'message': 'Failed to read file'};
      }

      var excel = Excel.decodeBytes(Uint8List.fromList(fileBytes));
      if (excel.tables.isEmpty) {
        return {'valid': false, 'message': 'No sheets found'};
      }

      var sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null || sheet.rows.isEmpty) {
        return {'valid': false, 'message': 'Sheet is empty'};
      }

      // Kiểm tra header
      var headerRow = sheet.rows.first;
      var headers = headerRow.map((cell) => _getCellValue(cell)).toList();

      // Kiểm tra số cột
      if (headers.length < 16) {
        return {
          'valid': false,
          'message': 'File has ${headers.length} columns, expected 16 columns'
        };
      }

      // Kiểm tra các cột bắt buộc
      var requiredColumns = ['Vietnamese', 'ID'];
      var missingColumns =
          requiredColumns.where((col) => !headers.contains(col)).toList();

      if (missingColumns.isNotEmpty) {
        return {
          'valid': false,
          'message': 'Missing required columns: ${missingColumns.join(", ")}'
        };
      }

      // Kiểm tra dữ liệu
      int totalRows = sheet.rows.length - 1; // Trừ header
      int validRows = 0;

      for (var i = 1; i < sheet.rows.length; i++) {
        var row = sheet.rows[i];
        if (row.isNotEmpty && row.length > 1) {
          var vietnamese = _getValueFromRow(row, 1);
          if (vietnamese.isNotEmpty) {
            validRows++;
          }
        }
      }

      return {
        'valid': true,
        'message': 'File validated successfully',
        'totalRows': totalRows,
        'validRows': validRows,
        'columns': headers,
      };
    } catch (e) {
      return {'valid': false, 'message': 'Error validating file: $e'};
    }
  }

  /// Đếm số lượng flashcards trong file
  Future<int> countFlashcardsInFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return 0;
      }

      final fileBytes = result.files.first.bytes;
      if (fileBytes == null) return 0;

      var excel = Excel.decodeBytes(Uint8List.fromList(fileBytes));
      if (excel.tables.isEmpty) return 0;

      var sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null) return 0;

      int count = 0;
      for (var i = 1; i < sheet.rows.length; i++) {
        var row = sheet.rows[i];
        if (row.isNotEmpty && row.length > 1) {
          var vietnamese = _getValueFromRow(row, 1);
          if (vietnamese.isNotEmpty) {
            count++;
          }
        }
      }

      return count;
    } catch (e) {
      print('❌ Error counting flashcards: $e');
      return 0;
    }
  }
}
