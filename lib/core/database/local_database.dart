import 'dart:async';
import 'dart:convert';
import 'package:flashcard_app/features/flashcard/data/models/user_progress_model.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flashcard_app/features/flashcard/data/models/flashcard_model.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  static Database? _database;
  static bool _initialized = false;
  static bool _isWeb = false;
  static bool _useSharedPrefs = false;

  factory LocalDatabase() => _instance;

  LocalDatabase._internal();

  // Khởi tạo database factory
  static void initialize() {
    if (_initialized) return;

    try {
      // Kiểm tra xem có phải web không
      _isWeb = const bool.fromEnvironment('dart.library.js_util') ||
          const bool.fromEnvironment('dart.library.js');

      if (_isWeb) {
        print('🌐 Running on Web - Using SharedPreferences');
        _useSharedPrefs = true;
      } else {
        // Desktop hoặc Mobile
        try {
          sqfliteFfiInit();
          databaseFactory = databaseFactoryFfi;
          print('✅ Database factory initialized for desktop/mobile');
          _useSharedPrefs = false;
        } catch (e) {
          print('⚠️ FFI init failed, falling back to SharedPreferences');
          _useSharedPrefs = true;
        }
      }

      _initialized = true;
      print(
          '✅ Local Database initialized (mode: ${_useSharedPrefs ? "SharedPreferences" : "SQLite"})');
    } catch (e) {
      print('❌ Failed to initialize Local Database: $e');
      // Fallback to SharedPreferences
      _useSharedPrefs = true;
      _initialized = true;
      print('✅ Fallback to SharedPreferences mode');
    }
  }

  // ============ SHAREDPREFERENCES METHODS (CHO WEB) ============
  Future<void> _saveToSharedPrefs(List<Flashcard> cards) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = cards.map((c) => c.toJson()).toList();
    await prefs.setString('flashcards_local', jsonEncode(jsonList));
  }

  Future<List<Flashcard>> _getFromSharedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('flashcards_local');
    if (data == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((json) => Flashcard.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error parsing SharedPreferences data: $e');
      return [];
    }
  }

  // ============ SQLITE METHODS (CHO MOBILE/DESKTOP) ============
  Future<Database> get database async {
    if (_useSharedPrefs) {
      throw Exception('Database not available in SharedPreferences mode');
    }

    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (_useSharedPrefs) {
      throw Exception('Database not available in SharedPreferences mode');
    }

    String path = join(await getDatabasesPath(), 'flashcards_local.db');
    print('📁 Database path: $path');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        print('✅ Database opened successfully');
        final result = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='flashcards_local'");
        if (result.isNotEmpty) {
          print('✅ Table flashcards_local exists');
        } else {
          print('❌ Table flashcards_local does not exist!');
        }
      },
    );
  }

  // ============ COMMON CRUD OPERATIONS ============

  Future<List<Flashcard>> getAllFlashcards() async {
    if (_useSharedPrefs) {
      return await _getFromSharedPrefs();
    }

    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'flashcards_local',
        orderBy: 'created_at DESC',
      );
      print('📥 Loaded ${maps.length} local flashcards');
      return List.generate(maps.length, (i) {
        return Flashcard.fromJson(maps[i]);
      });
    } catch (e) {
      print('❌ Error loading flashcards: $e');
      return [];
    }
  }

  Future<Flashcard> insertFlashcard(Flashcard flashcard) async {
    if (_useSharedPrefs) {
      final cards = await _getFromSharedPrefs();
      // Kiểm tra trùng ID
      final existingIndex = cards.indexWhere((c) => c.id == flashcard.id);
      if (existingIndex != -1) {
        cards[existingIndex] = flashcard;
      } else {
        cards.insert(0, flashcard);
      }
      await _saveToSharedPrefs(cards);
      print(
          '✅ Inserted flashcard to SharedPreferences: ${flashcard.vietnamese}');
      return flashcard;
    }

    try {
      final db = await database;
      print('📝 Inserting flashcard with ID: ${flashcard.id}');
      print('📝 Vietnamese: ${flashcard.vietnamese}');

      final existing = await db.query(
        'flashcards_local',
        where: 'id = ?',
        whereArgs: [flashcard.id],
      );

      if (existing.isNotEmpty) {
        print('⚠️ ID ${flashcard.id} already exists, updating instead');
        await db.update(
          'flashcards_local',
          flashcard.toJson(),
          where: 'id = ?',
          whereArgs: [flashcard.id],
        );
        return flashcard;
      }

      await db.insert(
        'flashcards_local',
        flashcard.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print('✅ Inserted flashcard successfully');
      return flashcard;
    } catch (e) {
      print('❌ Error inserting flashcard: $e');
      rethrow;
    }
  }

  Future<int> insertMultipleFlashcards(List<Flashcard> flashcards) async {
    if (_useSharedPrefs) {
      final cards = await _getFromSharedPrefs();
      int count = 0;
      for (var card in flashcards) {
        final existingIndex = cards.indexWhere((c) => c.id == card.id);
        if (existingIndex != -1) {
          cards[existingIndex] = card;
        } else {
          cards.insert(0, card);
        }
        count++;
      }
      await _saveToSharedPrefs(cards);
      print('✅ Inserted $count flashcards to SharedPreferences');
      return count;
    }

    final db = await database;
    int count = 0;

    try {
      await db.transaction((txn) async {
        for (var card in flashcards) {
          try {
            final existing = await txn.query(
              'flashcards_local',
              where: 'id = ?',
              whereArgs: [card.id],
            );

            if (existing.isNotEmpty) {
              await txn.update(
                'flashcards_local',
                card.toJson(),
                where: 'id = ?',
                whereArgs: [card.id],
              );
              count++;
              continue;
            }

            await txn.insert(
              'flashcards_local',
              card.toJson(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            count++;

            if (count % 100 == 0) {
              print('📊 Imported $count flashcards so far...');
            }
          } catch (e) {
            print('❌ Failed to insert card ${card.vietnamese}: $e');
          }
        }
      });

      print('✅ Inserted $count flashcards successfully');
      return count;
    } catch (e) {
      print('❌ Error in batch insert: $e');
      return count;
    }
  }

  Future<Flashcard> updateFlashcard(Flashcard flashcard) async {
    if (_useSharedPrefs) {
      final cards = await _getFromSharedPrefs();
      final index = cards.indexWhere((c) => c.id == flashcard.id);
      if (index != -1) {
        cards[index] = flashcard;
        await _saveToSharedPrefs(cards);
        print(
            '✅ Updated flashcard in SharedPreferences: ${flashcard.vietnamese}');
      }
      return flashcard;
    }

    try {
      final db = await database;
      await db.update(
        'flashcards_local',
        flashcard.toJson(),
        where: 'id = ?',
        whereArgs: [flashcard.id],
      );
      print('✅ Updated flashcard: ${flashcard.vietnamese}');
      return flashcard;
    } catch (e) {
      print('❌ Error updating flashcard: $e');
      rethrow;
    }
  }

  Future<int> deleteFlashcard(String id) async {
    if (_useSharedPrefs) {
      final cards = await _getFromSharedPrefs();
      final int oldLength = cards.length;
      cards.removeWhere((c) => c.id == id);
      final int newLength = cards.length;
      final int deleted = oldLength - newLength;
      await _saveToSharedPrefs(cards);
      print(
          '✅ Deleted flashcard from SharedPreferences: $id (deleted: $deleted)');
      return deleted;
    }

    try {
      final db = await database;
      final result = await db.delete(
        'flashcards_local',
        where: 'id = ?',
        whereArgs: [id],
      );
      print('✅ Deleted flashcard: $id (affected rows: $result)');
      return result;
    } catch (e) {
      print('❌ Error deleting flashcard: $e');
      rethrow;
    }
  }

  Future<int> deleteAllFlashcards() async {
    if (_useSharedPrefs) {
      await _saveToSharedPrefs([]);
      print('✅ Deleted all flashcards from SharedPreferences');
      return 0;
    }

    try {
      final db = await database;
      final result = await db.delete('flashcards_local');
      print('✅ Deleted all flashcards: $result');
      return result;
    } catch (e) {
      print('❌ Error deleting all flashcards: $e');
      rethrow;
    }
  }

  Future<List<Flashcard>> searchFlashcards(String query) async {
    if (_useSharedPrefs) {
      final cards = await _getFromSharedPrefs();
      final lowerQuery = query.toLowerCase();
      return cards
          .where((c) =>
              c.vietnamese.toLowerCase().contains(lowerQuery) ||
              (c.english?.toLowerCase().contains(lowerQuery) ?? false) ||
              (c.jpKanji?.toLowerCase().contains(lowerQuery) ?? false) ||
              (c.jpReading?.toLowerCase().contains(lowerQuery) ?? false) ||
              (c.cnCharacter?.toLowerCase().contains(lowerQuery) ?? false) ||
              (c.cnPinyin?.toLowerCase().contains(lowerQuery) ?? false))
          .toList();
    }

    final db = await database;
    try {
      final lowerQuery = query.toLowerCase();
      final List<Map<String, dynamic>> maps = await db.query(
        'flashcards_local',
        where:
            'LOWER(vietnamese) LIKE ? OR LOWER(english) LIKE ? OR LOWER(jp_kanji) LIKE ? OR LOWER(jp_reading) LIKE ? OR LOWER(cn_character) LIKE ? OR LOWER(cn_pinyin) LIKE ?',
        whereArgs: [
          '%$lowerQuery%',
          '%$lowerQuery%',
          '%$lowerQuery%',
          '%$lowerQuery%',
          '%$lowerQuery%',
          '%$lowerQuery%'
        ],
        orderBy: 'created_at DESC',
      );
      print('🔍 Search found ${maps.length} results for "$query"');
      return List.generate(maps.length, (i) {
        return Flashcard.fromJson(maps[i]);
      });
    } catch (e) {
      print('❌ Error searching flashcards: $e');
      return [];
    }
  }

  // Hàm kiểm tra database
  Future<Map<String, dynamic>> checkDatabase() async {
    if (_useSharedPrefs) {
      final cards = await _getFromSharedPrefs();
      return {
        'mode': 'SharedPreferences',
        'count': cards.length,
        'hasData': cards.isNotEmpty,
      };
    }

    try {
      final db = await database;
      final tables = await db
          .rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final count = await db.query('flashcards_local');

      return {
        'mode': 'SQLite',
        'tables': tables,
        'count': count.length,
        'databasePath': await getDatabasesPath(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Hàm reset database
  Future<void> resetDatabase() async {
    if (_useSharedPrefs) {
      await _saveToSharedPrefs([]);
      print('✅ SharedPreferences reset successfully');
      return;
    }

    try {
      final db = await database;
      await db.execute('DROP TABLE IF EXISTS flashcards_local');
      await _onCreate(db, 2);
      print('✅ Database reset successfully');
    } catch (e) {
      print('❌ Error resetting database: $e');
      rethrow;
    }
  }

  // Lấy flashcards với filter và phân trang
  Future<List<Flashcard>> getFlashcardsWithFilter({
    String? jpLevel,
    String? enLevel,
    String? cnLevel,
    String? jpDetailType,
    String? studyStatus,
    String? searchQuery,
    String? sortBy = 'id',
    bool ascending = true,
    int? limit,
    int? offset,
  }) async {
    // SHAREDPREFERENCES MODE
    if (_useSharedPrefs) {
      try {
        var cards = await _getFromSharedPrefs();

        // THAY ĐỔI: AND thay vì OR - Lọc tuần tự
        List<Flashcard> filteredCards = List.from(cards);

        // Filter theo JLPT
        if (jpLevel != null && jpLevel.isNotEmpty) {
          final levels = jpLevel.split(',').where((l) => l.isNotEmpty).toList();
          if (levels.isNotEmpty) {
            filteredCards = filteredCards
                .where((c) => c.jpLevel != null && levels.contains(c.jpLevel))
                .toList();
            print('  📊 JLPT filter: $levels -> ${filteredCards.length} cards');
          }
        }

        // Filter theo CEFR
        if (enLevel != null && enLevel.isNotEmpty) {
          final levels = enLevel.split(',').where((l) => l.isNotEmpty).toList();
          if (levels.isNotEmpty) {
            filteredCards = filteredCards
                .where((c) => c.enLevel != null && levels.contains(c.enLevel))
                .toList();
            print('  📊 CEFR filter: $levels -> ${filteredCards.length} cards');
          }
        }

        // Filter theo HSK
        if (cnLevel != null && cnLevel.isNotEmpty) {
          final levels = cnLevel.split(',').where((l) => l.isNotEmpty).toList();
          if (levels.isNotEmpty) {
            filteredCards = filteredCards
                .where((c) => c.cnLevel != null && levels.contains(c.cnLevel))
                .toList();
            print('  📊 HSK filter: $levels -> ${filteredCards.length} cards');
          }
        }

        // Filter theo Word Type
        if (jpDetailType != null && jpDetailType.isNotEmpty) {
          final types =
              jpDetailType.split(',').where((l) => l.isNotEmpty).toList();
          if (types.isNotEmpty) {
            filteredCards = filteredCards
                .where((c) =>
                    c.jpDetailType != null && types.contains(c.jpDetailType))
                .toList();
            print(
                '  📝 Word Type filter: $types -> ${filteredCards.length} cards');
          }
        }

        // Filter theo Study Status
        if (studyStatus != null && studyStatus.isNotEmpty) {
          final statuses =
              studyStatus.split(',').where((l) => l.isNotEmpty).toList();
          if (statuses.isNotEmpty) {
            filteredCards = filteredCards
                .where((c) =>
                    c.studyStatus != null && statuses.contains(c.studyStatus))
                .toList();
            print(
                '  📚 Status filter: $statuses -> ${filteredCards.length} cards');
          }
        }

        // Search không phân biệt hoa thường
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final lowerQuery = searchQuery.toLowerCase();
          filteredCards = filteredCards
              .where((c) =>
                  c.vietnamese.toLowerCase().contains(lowerQuery) ||
                  (c.english?.toLowerCase().contains(lowerQuery) ?? false) ||
                  (c.jpKanji?.toLowerCase().contains(lowerQuery) ?? false) ||
                  (c.jpReading?.toLowerCase().contains(lowerQuery) ?? false) ||
                  (c.cnCharacter?.toLowerCase().contains(lowerQuery) ??
                      false) ||
                  (c.cnPinyin?.toLowerCase().contains(lowerQuery) ?? false) ||
                  (c.contextNote?.toLowerCase().contains(lowerQuery) ??
                      false) ||
                  (c.exampleSentence?.toLowerCase().contains(lowerQuery) ??
                      false))
              .toList();
          print(
              '  🔍 Search filter: "$searchQuery" -> ${filteredCards.length} cards');
        }

        // Sort
        // Sort
        if (sortBy != null && sortBy.isNotEmpty) {
          if (sortBy == 'id') {
            // Sắp xếp ID theo số tự nhiên (1, 2, 3, 4, 5...)
            filteredCards.sort((a, b) {
              // Lấy phần số từ ID (bỏ chữ 'local_' nếu có)
              final aId =
                  int.tryParse(a.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
              final bId =
                  int.tryParse(b.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
              return ascending ? aId.compareTo(bId) : bId.compareTo(aId);
            });
          } else {
            filteredCards.sort((a, b) {
              dynamic aValue, bValue;

              switch (sortBy) {
                case 'vietnamese':
                  aValue = a.vietnamese;
                  bValue = b.vietnamese;
                  break;
                case 'english':
                  aValue = a.english ?? '';
                  bValue = b.english ?? '';
                  break;
                case 'jp_kanji':
                  aValue = a.jpKanji ?? '';
                  bValue = b.jpKanji ?? '';
                  break;
                case 'jp_reading':
                  aValue = a.jpReading ?? '';
                  bValue = b.jpReading ?? '';
                  break;
                case 'jp_level':
                  aValue = a.jpLevel ?? '';
                  bValue = b.jpLevel ?? '';
                  break;
                case 'en_level':
                  aValue = a.enLevel ?? '';
                  bValue = b.enLevel ?? '';
                  break;
                case 'cn_level':
                  aValue = a.cnLevel ?? '';
                  bValue = b.cnLevel ?? '';
                  break;
                case 'jp_detail_type':
                  aValue = a.jpDetailType ?? '';
                  bValue = b.jpDetailType ?? '';
                  break;
                case 'study_status':
                  aValue = a.studyStatus ?? '';
                  bValue = b.studyStatus ?? '';
                  break;
                case 'created_at':
                default:
                  aValue = a.createdAt ?? DateTime.now();
                  bValue = b.createdAt ?? DateTime.now();
                  break;
              }

              if (aValue is int && bValue is int) {
                return ascending
                    ? aValue.compareTo(bValue)
                    : bValue.compareTo(aValue);
              }
              return ascending
                  ? aValue.toString().compareTo(bValue.toString())
                  : bValue.toString().compareTo(aValue.toString());
            });
          }
        }

        // Pagination
        if (limit != null) {
          final start = offset ?? 0;
          final end = (start + limit).clamp(0, filteredCards.length);
          if (start < filteredCards.length) {
            filteredCards = filteredCards.sublist(start, end);
          } else {
            filteredCards = [];
          }
        }

        print(
            '📥 SharedPrefs: Loaded ${filteredCards.length} filtered flashcards');
        return filteredCards;
      } catch (e) {
        print('❌ Error in SharedPrefs filter: $e');
        return [];
      }
    }

    // ============ SQLITE MODE ============
    final db = await database;
    try {
      print('🔍 Building filter query...');

      // THAY ĐỔI: AND thay vì OR
      List<String> conditions = [];
      List<String> whereArgs = [];

      // Filter theo JLPT
      if (jpLevel != null && jpLevel.isNotEmpty) {
        final levels = jpLevel.split(',').where((l) => l.isNotEmpty).toList();
        if (levels.isNotEmpty) {
          conditions.add('jp_level IN (${levels.map((_) => '?').join(',')})');
          whereArgs.addAll(levels);
          print('  📊 JLPT filters: $levels');
        }
      }

      // Filter theo CEFR
      if (enLevel != null && enLevel.isNotEmpty) {
        final levels = enLevel.split(',').where((l) => l.isNotEmpty).toList();
        if (levels.isNotEmpty) {
          conditions.add('en_level IN (${levels.map((_) => '?').join(',')})');
          whereArgs.addAll(levels);
          print('  📊 CEFR filters: $levels');
        }
      }

      // Filter theo HSK
      if (cnLevel != null && cnLevel.isNotEmpty) {
        final levels = cnLevel.split(',').where((l) => l.isNotEmpty).toList();
        if (levels.isNotEmpty) {
          conditions.add('cn_level IN (${levels.map((_) => '?').join(',')})');
          whereArgs.addAll(levels);
          print('  📊 HSK filters: $levels');
        }
      }

      // Filter theo Word Type
      if (jpDetailType != null && jpDetailType.isNotEmpty) {
        final types =
            jpDetailType.split(',').where((l) => l.isNotEmpty).toList();
        if (types.isNotEmpty) {
          conditions
              .add('jp_detail_type IN (${types.map((_) => '?').join(',')})');
          whereArgs.addAll(types);
          print('  📝 Word Type filters: $types');
        }
      }

      // Filter theo Study Status
      if (studyStatus != null && studyStatus.isNotEmpty) {
        final statuses =
            studyStatus.split(',').where((l) => l.isNotEmpty).toList();
        if (statuses.isNotEmpty) {
          conditions
              .add('study_status IN (${statuses.map((_) => '?').join(',')})');
          whereArgs.addAll(statuses);
          print('  📚 Status filters: $statuses');
        }
      }

      // Search không phân biệt hoa thường
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        conditions.add('(LOWER(vietnamese) LIKE ? OR '
            'LOWER(english) LIKE ? OR '
            'LOWER(jp_kanji) LIKE ? OR '
            'LOWER(jp_reading) LIKE ? OR '
            'LOWER(cn_character) LIKE ? OR '
            'LOWER(cn_pinyin) LIKE ? OR '
            'LOWER(context_note) LIKE ? OR '
            'LOWER(example_sentence) LIKE ?)');
        whereArgs.addAll([
          '%$lowerQuery%',
          '%$lowerQuery%',
          '%$lowerQuery%',
          '%$lowerQuery%',
          '%$lowerQuery%',
          '%$lowerQuery%',
          '%$lowerQuery%',
          '%$lowerQuery%'
        ]);
        print('  🔍 Search query: "$searchQuery"');
      }

      // Kết hợp bằng AND
      String whereClause =
          conditions.isNotEmpty ? conditions.join(' AND ') : '';

      // Sort
      String orderBy = 'id ASC';
      if (sortBy != null && sortBy.isNotEmpty) {
        String sortColumn = sortBy;
        switch (sortBy) {
          case 'id':
            sortColumn = 'id';
            break;
          case 'vietnamese':
            sortColumn = 'vietnamese';
            break;
          case 'english':
            sortColumn = 'english';
            break;
          case 'jp_kanji':
            sortColumn = 'jp_kanji';
            break;
          case 'jp_reading':
            sortColumn = 'jp_reading';
            break;
          case 'jp_level':
            sortColumn = 'jp_level';
            break;
          case 'en_level':
            sortColumn = 'en_level';
            break;
          case 'cn_level':
            sortColumn = 'cn_level';
            break;
          case 'jp_detail_type':
            sortColumn = 'jp_detail_type';
            break;
          case 'study_status':
            sortColumn = 'study_status';
            break;
          case 'created_at':
          default:
            sortColumn = 'created_at';
            break;
        }
        orderBy = '$sortColumn ${ascending ? "ASC" : "DESC"}';
        print('  📋 Sort by: $sortBy ${ascending ? "ASC" : "DESC"}');
      }

      // Query
      String sql = '''
      SELECT * FROM flashcards_local
      ${whereClause.isNotEmpty ? "WHERE $whereClause" : ""}
      ORDER BY $orderBy
    ''';

      print('📝 SQL Query: $sql');
      print('📝 Args: $whereArgs');

      List<Map<String, dynamic>> maps;
      if (whereArgs.isNotEmpty) {
        maps = await db.rawQuery(sql, whereArgs);
      } else {
        maps = await db.rawQuery(sql);
      }

      print('📊 Total matching records: ${maps.length}');

      // Pagination
      if (limit != null && maps.isNotEmpty) {
        final start = offset ?? 0;
        final end = (start + limit).clamp(0, maps.length);
        if (start < maps.length) {
          maps = maps.sublist(start, end);
          print(
              '📄 Pagination: offset=$start, limit=$limit, returned ${maps.length} records');
        } else {
          maps = [];
        }
      }

      final result = List.generate(maps.length, (i) {
        return Flashcard.fromJson(maps[i]);
      });

      print('✅ Loaded ${result.length} filtered flashcards');
      return result;
    } catch (e) {
      print('❌ Error getting filtered flashcards: $e');
      return [];
    }
  }

// Lấy danh sách các JP Detail Types có sẵn
  Future<List<String>> getAvailableJpDetailTypes() async {
    if (_useSharedPrefs) {
      final cards = await _getFromSharedPrefs();
      final types = cards
          .where((c) => c.jpDetailType != null && c.jpDetailType!.isNotEmpty)
          .map((c) => c.jpDetailType!)
          .toSet()
          .toList()
        ..sort();
      return types;
    }

    try {
      final db = await database;
      final result = await db.rawQuery('''
      SELECT DISTINCT jp_detail_type 
      FROM flashcards_local 
      WHERE jp_detail_type IS NOT NULL AND jp_detail_type != ''
      ORDER BY jp_detail_type
    ''');
      return result.map((row) => row['jp_detail_type'] as String).toList();
    } catch (e) {
      print('❌ Error getting JP detail types: $e');
      return [];
    }
  }

// Đếm tổng số flashcards với filter
  Future<int> countFlashcardsWithFilter({
    String? jpLevel,
    String? enLevel,
    String? cnLevel,
    String? jpDetailType,
    String? studyStatus,
    String? searchQuery,
  }) async {
    if (_useSharedPrefs) {
      var cards = await _getFromSharedPrefs();

      // Áp dụng AND cho từng filter
      if (jpLevel != null && jpLevel.isNotEmpty) {
        final levels = jpLevel.split(',').where((l) => l.isNotEmpty).toList();
        if (levels.isNotEmpty) {
          cards = cards
              .where((c) => c.jpLevel != null && levels.contains(c.jpLevel))
              .toList();
        }
      }
      if (enLevel != null && enLevel.isNotEmpty) {
        final levels = enLevel.split(',').where((l) => l.isNotEmpty).toList();
        if (levels.isNotEmpty) {
          cards = cards
              .where((c) => c.enLevel != null && levels.contains(c.enLevel))
              .toList();
        }
      }
      if (cnLevel != null && cnLevel.isNotEmpty) {
        final levels = cnLevel.split(',').where((l) => l.isNotEmpty).toList();
        if (levels.isNotEmpty) {
          cards = cards
              .where((c) => c.cnLevel != null && levels.contains(c.cnLevel))
              .toList();
        }
      }
      if (jpDetailType != null && jpDetailType.isNotEmpty) {
        final types =
            jpDetailType.split(',').where((l) => l.isNotEmpty).toList();
        if (types.isNotEmpty) {
          cards = cards
              .where((c) =>
                  c.jpDetailType != null && types.contains(c.jpDetailType))
              .toList();
        }
      }
      if (studyStatus != null && studyStatus.isNotEmpty) {
        final statuses =
            studyStatus.split(',').where((l) => l.isNotEmpty).toList();
        if (statuses.isNotEmpty) {
          cards = cards
              .where((c) =>
                  c.studyStatus != null && statuses.contains(c.studyStatus))
              .toList();
        }
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        cards = cards
            .where((c) =>
                c.vietnamese.toLowerCase().contains(lowerQuery) ||
                (c.english?.toLowerCase().contains(lowerQuery) ?? false) ||
                (c.jpKanji?.toLowerCase().contains(lowerQuery) ?? false) ||
                (c.jpReading?.toLowerCase().contains(lowerQuery) ?? false) ||
                (c.cnCharacter?.toLowerCase().contains(lowerQuery) ?? false) ||
                (c.cnPinyin?.toLowerCase().contains(lowerQuery) ?? false) ||
                (c.contextNote?.toLowerCase().contains(lowerQuery) ?? false) ||
                (c.exampleSentence?.toLowerCase().contains(lowerQuery) ??
                    false))
            .toList();
      }

      return cards.length;
    }

    try {
      final db = await database;
      List<String> conditions = [];
      List<String> whereArgs = [];

      if (jpLevel != null && jpLevel.isNotEmpty) {
        final levels = jpLevel.split(',').where((l) => l.isNotEmpty).toList();
        if (levels.isNotEmpty) {
          conditions.add('jp_level IN (${levels.map((_) => '?').join(',')})');
          whereArgs.addAll(levels);
        }
      }
      if (enLevel != null && enLevel.isNotEmpty) {
        final levels = enLevel.split(',').where((l) => l.isNotEmpty).toList();
        if (levels.isNotEmpty) {
          conditions.add('en_level IN (${levels.map((_) => '?').join(',')})');
          whereArgs.addAll(levels);
        }
      }
      if (cnLevel != null && cnLevel.isNotEmpty) {
        final levels = cnLevel.split(',').where((l) => l.isNotEmpty).toList();
        if (levels.isNotEmpty) {
          conditions.add('cn_level IN (${levels.map((_) => '?').join(',')})');
          whereArgs.addAll(levels);
        }
      }
      if (jpDetailType != null && jpDetailType.isNotEmpty) {
        final types =
            jpDetailType.split(',').where((l) => l.isNotEmpty).toList();
        if (types.isNotEmpty) {
          conditions
              .add('jp_detail_type IN (${types.map((_) => '?').join(',')})');
          whereArgs.addAll(types);
        }
      }
      if (studyStatus != null && studyStatus.isNotEmpty) {
        final statuses =
            studyStatus.split(',').where((l) => l.isNotEmpty).toList();
        if (statuses.isNotEmpty) {
          conditions
              .add('study_status IN (${statuses.map((_) => '?').join(',')})');
          whereArgs.addAll(statuses);
        }
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        conditions.add('(LOWER(vietnamese) LIKE ? OR '
            'LOWER(english) LIKE ? OR '
            'LOWER(jp_kanji) LIKE ? OR '
            'LOWER(jp_reading) LIKE ? OR '
            'LOWER(cn_character) LIKE ? OR '
            'LOWER(cn_pinyin) LIKE ? OR '
            'LOWER(context_note) LIKE ? OR '
            'LOWER(example_sentence) LIKE ?)');
        whereArgs.addAll([
          '%$lowerQuery%',
          '%$lowerQuery%',
          '%$lowerQuery%',
          '%$lowerQuery%',
          '%$lowerQuery%',
          '%$lowerQuery%',
          '%$lowerQuery%',
          '%$lowerQuery%'
        ]);
      }

      String whereClause =
          conditions.isNotEmpty ? conditions.join(' AND ') : '';

      final result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM flashcards_local 
      ${whereClause.isNotEmpty ? "WHERE $whereClause" : ""}
    ''', whereArgs);

      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      print('❌ Error counting flashcards: $e');
      return 0;
    }
  }

  // ==================== USER PROGRESS OPERATIONS ====================

  Future<List<UserProgress>> getAllUserProgress() async {
    if (_useSharedPrefs) {
      // SharedPreferences mode
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString('user_progress');
      if (data == null) return [];
      try {
        final List<dynamic> jsonList = jsonDecode(data);
        return jsonList.map((json) => UserProgress.fromJson(json)).toList();
      } catch (e) {
        print('❌ Error parsing user progress: $e');
        return [];
      }
    }

    final db = await database;
    try {
      final List<Map<String, dynamic>> maps =
          await db.query('user_progress_local');
      return List.generate(maps.length, (i) {
        return UserProgress.fromJson(maps[i]);
      });
    } catch (e) {
      print('❌ Error getting all user progress: $e');
      return [];
    }
  }

  Future<UserProgress?> getUserProgressByFlashcardId(String flashcardId) async {
    if (_useSharedPrefs) {
      final all = await getAllUserProgress();
      try {
        return all.firstWhere((p) => p.flashcardId.toString() == flashcardId);
      } catch (e) {
        return null;
      }
    }

    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'user_progress_local',
        where: 'flashcard_id = ?',
        whereArgs: [int.tryParse(flashcardId) ?? 0],
      );

      if (maps.isEmpty) return null;
      return UserProgress.fromJson(maps.first);
    } catch (e) {
      print('❌ Error getting user progress by flashcard id: $e');
      return null;
    }
  }


  Future<UserProgress> insertUserProgress(UserProgress progress) async {
    if (_useSharedPrefs) {
      final all = await getAllUserProgress();
      // Kiểm tra trùng
      final existingIndex =
          all.indexWhere((p) => p.flashcardId == progress.flashcardId);
      if (existingIndex != -1) {
        all[existingIndex] = progress;
      } else {
        all.add(progress);
      }
      await _saveUserProgressToPrefs(all);
      return progress;
    }

    final db = await database;
    try {
      await db.insert(
        'user_progress_local',
        progress.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return progress;
    } catch (e) {
      print('❌ Error inserting user progresss: $e');
      rethrow;
    }
  }

  Future<UserProgress> updateUserProgress(UserProgress progress) async {
    if (_useSharedPrefs) {
      final all = await getAllUserProgress();
      final index =
          all.indexWhere((p) => p.flashcardId == progress.flashcardId);
      if (index != -1) {
        all[index] = progress;
        await _saveUserProgressToPrefs(all);
      } else {
        all.add(progress);
        await _saveUserProgressToPrefs(all);
      }
      return progress;
    }

    final db = await database;
    try {
      await db.update(
        'user_progress_local',
        progress.toJson(),
        where: 'flashcard_id = ?',
        whereArgs: [progress.flashcardId],
      );
      return progress;
    } catch (e) {
      print('❌ Error updating user progress: $e');
      rethrow;
    }
  }

  Future<int> deleteUserProgress(String flashcardId) async {
    if (_useSharedPrefs) {
      final all = await getAllUserProgress();
      final int oldLength = all.length;
      all.removeWhere((p) => p.flashcardId == flashcardId);
      final int newLength = all.length;
      await _saveUserProgressToPrefs(all);
      return oldLength - newLength; // Trả về số lượng đã xóa
    }

    final db = await database;
    try {
      final result = await db.delete(
        'user_progress_local',
        where: 'flashcard_id = ?',
        whereArgs: [flashcardId],
      );
      return result;
    } catch (e) {
      print('❌ Error deleting user progress: $e');
      rethrow;
    }
  }

  Future<void> _saveUserProgressToPrefs(List<UserProgress> progresses) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = progresses.map((p) => p.toJson()).toList();
      await prefs.setString('user_progress', jsonEncode(jsonList));
    } catch (e) {
      print('❌ Error saving user progress to prefs: $e');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    print('🔄 Creating database tables...');

    // Bảng flashcards_local
    await db.execute('''
    CREATE TABLE flashcards_local (
      id TEXT PRIMARY KEY,
      vietnamese TEXT NOT NULL,
      jp_kanji TEXT,
      jp_reading TEXT,
      jp_type TEXT,
      jp_detail_type TEXT,
      jp_level TEXT,
      english TEXT,
      en_ipa TEXT,
      en_level TEXT,
      han_viet TEXT,
      cn_character TEXT,
      cn_pinyin TEXT,
      cn_level TEXT,
      example_sentence TEXT,
      context_note TEXT,
      study_status TEXT DEFAULT 'new',
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  ''');

    // ⭐ Bảng user_progress_local
    await db.execute('''
    CREATE TABLE user_progress_local (
      id TEXT PRIMARY KEY,
      flashcard_id INTEGER NOT NULL,
      study_status TEXT DEFAULT 'new',
      srs_interval INTEGER DEFAULT 0,
      srs_ease_factor REAL DEFAULT 2.5,
      srs_next_review TEXT,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (flashcard_id) REFERENCES flashcards_local(id) ON DELETE CASCADE,
      UNIQUE(flashcard_id)
    )
  ''');

    // Index cho user_progress_local
    await db.execute(
        'CREATE INDEX idx_user_progress_local_flashcard_id ON user_progress_local(flashcard_id)');
    await db.execute(
        'CREATE INDEX idx_user_progress_local_study_status ON user_progress_local(study_status)');

    // Index cho flashcards_local
    await db
        .execute('CREATE INDEX idx_vietnamese ON flashcards_local(vietnamese)');
    await db.execute('CREATE INDEX idx_english ON flashcards_local(english)');
    await db.execute('CREATE INDEX idx_jp_level ON flashcards_local(jp_level)');

    print('✅ Local database created with user_progress table');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('🔄 Upgrading database from version $oldVersion to $newVersion');

    if (oldVersion < 2) {
      // Tạo bảng user_progress_local cho version mới
      await db.execute('''
      CREATE TABLE user_progress_local (
        id TEXT PRIMARY KEY,
        flashcard_id INTEGER NOT NULL,
        study_status TEXT DEFAULT 'new',
        srs_interval INTEGER DEFAULT 0,
        srs_ease_factor REAL DEFAULT 2.5,
        srs_next_review TEXT,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (flashcard_id) REFERENCES flashcards_local(id) ON DELETE CASCADE,
        UNIQUE(flashcard_id)
      )
    ''');

      await db.execute(
          'CREATE INDEX idx_user_progress_local_flashcard_id ON user_progress_local(flashcard_id)');
      await db.execute(
          'CREATE INDEX idx_user_progress_local_study_status ON user_progress_local(study_status)');

      print('✅ Database upgraded to version $newVersion');
    }
  }
}
