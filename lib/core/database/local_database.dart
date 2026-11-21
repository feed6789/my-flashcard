// lib/core/database/local_database.dart

import 'dart:async';
import 'dart:convert';

import 'package:flashcard_app/features/flashcard/data/models/flashcard_model.dart';
import 'package:flashcard_app/features/flashcard/data/models/user_progress_model.dart';
import 'package:path/path.dart' as p;
import 'package:sembast/sembast.dart' as sembast;
import 'package:sembast_web/sembast_web.dart' as sembast_web;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqflite_ffi;

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();

  // SQLite
  static sqflite.Database? _database;

  // Sembast (Web / IndexedDB)
  static sembast.Database? _sembastDb;
  static final _sembastFlashcardStore =
      sembast.stringMapStoreFactory.store('flashcards');
  static final _sembastProgressStore =
      sembast.stringMapStoreFactory.store('user_progress');

  static bool _initialized = false;
  static bool _isWeb = false;
  static bool _useSharedPrefs = false;
  static bool _useSembast = false;

  static const _prefsFlashcardsKey = 'flashcards_local';
  static const _prefsProgressKey = 'user_progress';
  static const _migrationFlagKey = 'migrated_to_sembast_v1';

  factory LocalDatabase() => _instance;

  LocalDatabase._internal();

  // ============================================================
  // INITIALIZE
  // ============================================================
  static void initialize() {
    if (_initialized) return;

    try {
      _isWeb = const bool.fromEnvironment('dart.library.js_util') ||
          const bool.fromEnvironment('dart.library.js');

      if (_isWeb) {
        print('🌐 Running on Web - Using IndexedDB (sembast_web)');
        _useSembast = true;
        _useSharedPrefs = false;
      } else {
        try {
          sqflite_ffi.sqfliteFfiInit();
          sqflite.databaseFactory = sqflite_ffi.databaseFactoryFfi;
          print('✅ Database factory initialized for desktop/mobile');
          _useSharedPrefs = false;
        } catch (e) {
          print('⚠️ FFI init failed, falling back to SharedPreferences: $e');
          _useSharedPrefs = true;
        }
      }

      _initialized = true;
      print(
          '✅ Local Database initialized (mode: ${_useSembast ? "IndexedDB" : (_useSharedPrefs ? "SharedPreferences" : "SQLite")})');
    } catch (e) {
      print('❌ Failed to initialize Local Database: $e');
      _useSharedPrefs = true;
      _initialized = true;
    }
  }

  // ============================================================
  // SHAREDPREFERENCES (fallback)
  // ============================================================
  Future<void> _saveToSharedPrefs(List<Flashcard> cards) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = cards.map((c) => c.toJson()).toList();
    await prefs.setString(_prefsFlashcardsKey, jsonEncode(jsonList));
  }

  Future<List<Flashcard>> _getFromSharedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_prefsFlashcardsKey);
    if (data == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((json) => Flashcard.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error parsing SharedPreferences data: $e');
      return [];
    }
  }

  Future<void> _saveProgressToSharedPrefs(
      List<UserProgress> progresses) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = progresses.map((p) => p.toJson()).toList();
      await prefs.setString(_prefsProgressKey, jsonEncode(jsonList));
    } catch (e) {
      print('❌ Error saving user progress to prefs: $e');
    }
  }

  Future<List<UserProgress>> _getProgressFromSharedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_prefsProgressKey);
    if (data == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((json) => UserProgress.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error parsing user progress: $e');
      return [];
    }
  }

  // ============================================================
  // SEMBAST / INDEXEDDB (Web)
  // ============================================================
  Future<sembast.Database> _getSembastDb() async {
    if (_sembastDb != null) return _sembastDb!;
    _sembastDb =
        await sembast_web.databaseFactoryWeb.openDatabase('flashcards.db');
    print('✅ Sembast database opened (IndexedDB)');
    return _sembastDb!;
  }

  Future<List<Flashcard>> _getAllFromSembast() async {
    try {
      final db = await _getSembastDb();
      final records = await _sembastFlashcardStore.find(db);
      print('📥 Loaded ${records.length} flashcards from IndexedDB');
      return records.map((snapshot) {
        final map = Map<String, dynamic>.from(snapshot.value);
        return Flashcard.fromJson(map);
      }).toList();
    } catch (e) {
      print('❌ Error loading from IndexedDB: $e');
      return [];
    }
  }

  Future<void> _saveAllToSembast(List<Flashcard> cards) async {
    try {
      final db = await _getSembastDb();
      await db.transaction((txn) async {
        await _sembastFlashcardStore.delete(txn);
        for (final card in cards) {
          await _sembastFlashcardStore.record(card.id).put(txn, card.toJson());
        }
      });
      print('✅ Saved ${cards.length} flashcards to IndexedDB');
    } catch (e) {
      print('❌ Error saving to IndexedDB: $e');
      rethrow;
    }
  }

  Future<List<UserProgress>> _getAllProgressFromSembast() async {
    try {
      final db = await _getSembastDb();
      final records = await _sembastProgressStore.find(db);
      return records.map((snapshot) {
        final map = Map<String, dynamic>.from(snapshot.value);
        return UserProgress.fromJson(map);
      }).toList();
    } catch (e) {
      print('❌ Error loading progress from IndexedDB: $e');
      return [];
    }
  }

  Future<void> _saveAllProgressToSembast(
      List<UserProgress> progresses) async {
    try {
      final db = await _getSembastDb();
      await db.transaction((txn) async {
        await _sembastProgressStore.delete(txn);
        for (final p in progresses) {
          await _sembastProgressStore
              .record(p.flashcardId.toString())
              .put(txn, p.toJson());
        }
      });
    } catch (e) {
      print('❌ Error saving progress to IndexedDB: $e');
      rethrow;
    }
  }

  // ============================================================
  // SQLITE (mobile / desktop)
  // ============================================================
  Future<sqflite.Database> get database async {
    if (_useSharedPrefs) {
      throw Exception('Database not available in SharedPreferences mode');
    }
    if (_useSembast) {
      throw Exception('Database not available in Sembast mode');
    }
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<sqflite.Database> _initDatabase() async {
    String path =
        p.join(await sqflite.getDatabasesPath(), 'flashcards_local.db');
    print('📁 Database path: $path');

    return await sqflite.openDatabase(
      path,
      version: 3,
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

  // ============================================================
  // FLASHCARD CRUD
  // ============================================================
  Future<List<Flashcard>> getAllFlashcards() async {
    if (_useSembast) {
      return await _getAllFromSembast();
    }

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
      return List.generate(maps.length, (i) => Flashcard.fromJson(maps[i]));
    } catch (e) {
      print('❌ Error loading flashcards: $e');
      return [];
    }
  }

  Future<Flashcard> insertFlashcard(Flashcard flashcard) async {
    if (_useSembast) {
      try {
        final db = await _getSembastDb();
        await _sembastFlashcardStore
            .record(flashcard.id)
            .put(db, flashcard.toJson());
        print('✅ Inserted flashcard to IndexedDB: ${flashcard.vietnamese}');
        return flashcard;
      } catch (e) {
        print('❌ Error inserting flashcard to IndexedDB: $e');
        rethrow;
      }
    }

    if (_useSharedPrefs) {
      final cards = await _getFromSharedPrefs();
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
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );

      print('✅ Inserted flashcard successfully');
      return flashcard;
    } catch (e) {
      print('❌ Error inserting flashcard: $e');
      rethrow;
    }
  }

  Future<int> insertMultipleFlashcards(List<Flashcard> flashcards) async {
    if (_useSembast) {
      try {
        final db = await _getSembastDb();
        int count = 0;
        await db.transaction((txn) async {
          for (final card in flashcards) {
            await _sembastFlashcardStore
                .record(card.id)
                .put(txn, card.toJson());
            count++;
          }
        });
        print('✅ Inserted $count flashcards to IndexedDB');
        return count;
      } catch (e) {
        print('❌ Error batch inserting to IndexedDB: $e');
        return 0;
      }
    }

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
              conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
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
    if (_useSembast) {
      try {
        final db = await _getSembastDb();
        await _sembastFlashcardStore
            .record(flashcard.id)
            .put(db, flashcard.toJson());
        print('✅ Updated flashcard in IndexedDB: ${flashcard.vietnamese}');
        return flashcard;
      } catch (e) {
        print('❌ Error updating flashcard in IndexedDB: $e');
        rethrow;
      }
    }

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
    if (_useSembast) {
      try {
        final db = await _getSembastDb();
        await _sembastFlashcardStore.record(id).delete(db);
        print('✅ Deleted flashcard from IndexedDB: $id');
        return 1;
      } catch (e) {
        print('❌ Error deleting flashcard from IndexedDB: $e');
        rethrow;
      }
    }

    if (_useSharedPrefs) {
      final cards = await _getFromSharedPrefs();
      final int oldLength = cards.length;
      cards.removeWhere((c) => c.id == id);
      final int deleted = oldLength - cards.length;
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
    if (_useSembast) {
      try {
        final db = await _getSembastDb();
        final count = await _sembastFlashcardStore.count(db);
        await _sembastFlashcardStore.delete(db);
        print('✅ Deleted all flashcards from IndexedDB: $count');
        return count;
      } catch (e) {
        print('❌ Error deleting all flashcards from IndexedDB: $e');
        rethrow;
      }
    }

    if (_useSharedPrefs) {
      final cards = await _getFromSharedPrefs();
      final count = cards.length;
      await _saveToSharedPrefs([]);
      print('✅ Deleted all flashcards from SharedPreferences');
      return count;
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
    if (_useSembast) {
      final cards = await _getAllFromSembast();
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
      return List.generate(maps.length, (i) => Flashcard.fromJson(maps[i]));
    } catch (e) {
      print('❌ Error searching flashcards: $e');
      return [];
    }
  }

  // ============================================================
  // FILTER + PAGINATION
  // ============================================================
  Future<List<Flashcard>> getFlashcardsWithFilter({
    String? jpLevel,
    String? enLevel,
    String? cnLevel,
    String? jpDetailType,
    String? studyStatus,
    String? topic,
    String? searchQuery,
    String? sortBy = 'id',
    bool ascending = true,
    int? limit,
    int? offset,
  }) async {
    // IndexedDB hoặc SharedPreferences: filter in-memory
    if (_useSembast || _useSharedPrefs) {
      try {
        var cards = _useSembast
            ? await _getAllFromSembast()
            : await _getFromSharedPrefs();

        List<String> splitList(String? s) =>
            s?.split(',').where((e) => e.isNotEmpty).toList() ?? [];

        final jpLevels = splitList(jpLevel);
        if (jpLevels.isNotEmpty) {
          cards = cards
              .where((c) => c.jpLevel != null && jpLevels.contains(c.jpLevel))
              .toList();
        }
        final enLevels = splitList(enLevel);
        if (enLevels.isNotEmpty) {
          cards = cards
              .where((c) => c.enLevel != null && enLevels.contains(c.enLevel))
              .toList();
        }
        final cnLevels = splitList(cnLevel);
        if (cnLevels.isNotEmpty) {
          cards = cards
              .where((c) => c.cnLevel != null && cnLevels.contains(c.cnLevel))
              .toList();
        }
        final types = splitList(jpDetailType);
        if (types.isNotEmpty) {
          cards = cards
              .where((c) =>
                  c.jpDetailType != null && types.contains(c.jpDetailType))
              .toList();
        }
        final statuses = splitList(studyStatus);
        if (statuses.isNotEmpty) {
          cards = cards
              .where((c) =>
                  c.studyStatus != null && statuses.contains(c.studyStatus))
              .toList();
        }
        final topics = splitList(topic);
        if (topics.isNotEmpty) {
          cards = cards
              .where((c) => c.topic != null && topics.contains(c.topic))
              .toList();
        }

        if (searchQuery != null && searchQuery.isNotEmpty) {
          final lowerQuery = searchQuery.toLowerCase();
          cards = cards
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
        }

        if (sortBy != null && sortBy.isNotEmpty) {
          cards.sort((a, b) {
            dynamic aValue, bValue;
            switch (sortBy) {
              case 'id':
                final aId =
                    int.tryParse(a.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                final bId =
                    int.tryParse(b.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                return ascending ? aId.compareTo(bId) : bId.compareTo(aId);
              case 'vietnamese':
                aValue = a.vietnamese;
                bValue = b.vietnamese;
                break;
              case 'english':
                aValue = a.english ?? '';
                bValue = b.english ?? '';
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
              case 'topic':
                aValue = a.topic ?? '';
                bValue = b.topic ?? '';
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

        if (limit != null) {
          final start = offset ?? 0;
          final end = (start + limit).clamp(0, cards.length);
          if (start < cards.length) {
            cards = cards.sublist(start, end);
          } else {
            cards = [];
          }
        }

        return cards;
      } catch (e) {
        print('❌ Error in in-memory filter: $e');
        return [];
      }
    }

    // ============ SQLITE ============
    final db = await database;
    try {
      List<String> conditions = [];
      List<String> whereArgs = [];

      void addInCondition(
          String column, String? csv, List<String> args, List<String> conds) {
        if (csv == null || csv.isEmpty) return;
        final values = csv.split(',').where((e) => e.isNotEmpty).toList();
        if (values.isEmpty) return;
        conds.add('$column IN (${values.map((_) => '?').join(',')})');
        args.addAll(values);
      }

      addInCondition('jp_level', jpLevel, whereArgs, conditions);
      addInCondition('en_level', enLevel, whereArgs, conditions);
      addInCondition('cn_level', cnLevel, whereArgs, conditions);
      addInCondition('jp_detail_type', jpDetailType, whereArgs, conditions);
      addInCondition('study_status', studyStatus, whereArgs, conditions);
      addInCondition('topic', topic, whereArgs, conditions);

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
        whereArgs.addAll(List.filled(8, '%$lowerQuery%'));
      }

      final whereClause =
          conditions.isNotEmpty ? conditions.join(' AND ') : '';

      String sortColumn = 'id';
      switch (sortBy) {
        case 'vietnamese':
          sortColumn = 'vietnamese';
          break;
        case 'english':
          sortColumn = 'english';
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
        case 'topic':
          sortColumn = 'topic';
          break;
        case 'created_at':
          sortColumn = 'created_at';
          break;
        case 'id':
        default:
          sortColumn = 'id';
          break;
      }
      final orderBy = '$sortColumn ${ascending ? "ASC" : "DESC"}';

      String sql = 'SELECT * FROM flashcards_local '
          '${whereClause.isNotEmpty ? "WHERE $whereClause" : ""} '
          'ORDER BY $orderBy';

      List<Map<String, dynamic>> maps = whereArgs.isNotEmpty
          ? await db.rawQuery(sql, whereArgs)
          : await db.rawQuery(sql);

      if (limit != null && maps.isNotEmpty) {
        final start = offset ?? 0;
        final end = (start + limit).clamp(0, maps.length);
        if (start < maps.length) {
          maps = maps.sublist(start, end);
        } else {
          maps = [];
        }
      }

      return List.generate(maps.length, (i) => Flashcard.fromJson(maps[i]));
    } catch (e) {
      print('❌ Error getting filtered flashcards: $e');
      return [];
    }
  }

  Future<List<String>> getAvailableJpDetailTypes() async {
    if (_useSembast || _useSharedPrefs) {
      final cards = _useSembast
          ? await _getAllFromSembast()
          : await _getFromSharedPrefs();
      return cards
          .where((c) => c.jpDetailType != null && c.jpDetailType!.isNotEmpty)
          .map((c) => c.jpDetailType!)
          .toSet()
          .toList()
        ..sort();
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

  Future<int> countFlashcardsWithFilter({
    String? jpLevel,
    String? enLevel,
    String? cnLevel,
    String? jpDetailType,
    String? studyStatus,
    String? topic,
    String? searchQuery,
  }) async {
    if (_useSembast || _useSharedPrefs) {
      var cards = _useSembast
          ? await _getAllFromSembast()
          : await _getFromSharedPrefs();

      List<String> splitList(String? s) =>
          s?.split(',').where((e) => e.isNotEmpty).toList() ?? [];

      final jpLevels = splitList(jpLevel);
      if (jpLevels.isNotEmpty) {
        cards = cards
            .where((c) => c.jpLevel != null && jpLevels.contains(c.jpLevel))
            .toList();
      }
      final enLevels = splitList(enLevel);
      if (enLevels.isNotEmpty) {
        cards = cards
            .where((c) => c.enLevel != null && enLevels.contains(c.enLevel))
            .toList();
      }
      final cnLevels = splitList(cnLevel);
      if (cnLevels.isNotEmpty) {
        cards = cards
            .where((c) => c.cnLevel != null && cnLevels.contains(c.cnLevel))
            .toList();
      }
      final types = splitList(jpDetailType);
      if (types.isNotEmpty) {
        cards = cards
            .where((c) =>
                c.jpDetailType != null && types.contains(c.jpDetailType))
            .toList();
      }
      final statuses = splitList(studyStatus);
      if (statuses.isNotEmpty) {
        cards = cards
            .where((c) =>
                c.studyStatus != null && statuses.contains(c.studyStatus))
            .toList();
      }
      final topics = splitList(topic);
      if (topics.isNotEmpty) {
        cards = cards
            .where((c) => c.topic != null && topics.contains(c.topic))
            .toList();
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

    // SQLITE
    try {
      final db = await database;
      List<String> conditions = [];
      List<String> whereArgs = [];

      void addInCondition(
          String column, String? csv, List<String> args, List<String> conds) {
        if (csv == null || csv.isEmpty) return;
        final values = csv.split(',').where((e) => e.isNotEmpty).toList();
        if (values.isEmpty) return;
        conds.add('$column IN (${values.map((_) => '?').join(',')})');
        args.addAll(values);
      }

      addInCondition('jp_level', jpLevel, whereArgs, conditions);
      addInCondition('en_level', enLevel, whereArgs, conditions);
      addInCondition('cn_level', cnLevel, whereArgs, conditions);
      addInCondition('jp_detail_type', jpDetailType, whereArgs, conditions);
      addInCondition('study_status', studyStatus, whereArgs, conditions);
      addInCondition('topic', topic, whereArgs, conditions);

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
        whereArgs.addAll(List.filled(8, '%$lowerQuery%'));
      }

      final whereClause =
          conditions.isNotEmpty ? conditions.join(' AND ') : '';

      final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM flashcards_local '
          '${whereClause.isNotEmpty ? "WHERE $whereClause" : ""}',
          whereArgs);

      return sqflite.Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      print('❌ Error counting flashcards: $e');
      return 0;
    }
  }

  // ============================================================
  // USER PROGRESS
  // ============================================================
  Future<List<UserProgress>> getAllUserProgress() async {
    if (_useSembast) {
      return await _getAllProgressFromSembast();
    }

    if (_useSharedPrefs) {
      return await _getProgressFromSharedPrefs();
    }

    final db = await database;
    try {
      final List<Map<String, dynamic>> maps =
          await db.query('user_progress_local');
      return List.generate(maps.length, (i) => UserProgress.fromJson(maps[i]));
    } catch (e) {
      print('❌ Error getting all user progress: $e');
      return [];
    }
  }

  Future<UserProgress?> getUserProgressByFlashcardId(
      String flashcardId) async {
    if (_useSembast) {
      final all = await _getAllProgressFromSembast();
      try {
        return all.firstWhere((p) => p.flashcardId.toString() == flashcardId);
      } catch (_) {
        return null;
      }
    }

    if (_useSharedPrefs) {
      final all = await _getProgressFromSharedPrefs();
      try {
        return all.firstWhere((p) => p.flashcardId.toString() == flashcardId);
      } catch (_) {
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
    if (_useSembast) {
      try {
        final db = await _getSembastDb();
        await _sembastProgressStore
            .record(progress.flashcardId.toString())
            .put(db, progress.toJson());
        return progress;
      } catch (e) {
        print('❌ Error inserting user progress to IndexedDB: $e');
        rethrow;
      }
    }

    if (_useSharedPrefs) {
      final all = await _getProgressFromSharedPrefs();
      final existingIndex =
          all.indexWhere((p) => p.flashcardId == progress.flashcardId);
      if (existingIndex != -1) {
        all[existingIndex] = progress;
      } else {
        all.add(progress);
      }
      await _saveProgressToSharedPrefs(all);
      return progress;
    }

    final db = await database;
    try {
      await db.insert(
        'user_progress_local',
        progress.toJson(),
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
      return progress;
    } catch (e) {
      print('❌ Error inserting user progress: $e');
      rethrow;
    }
  }

  Future<UserProgress> updateUserProgress(UserProgress progress) async {
    if (_useSembast) {
      try {
        final db = await _getSembastDb();
        await _sembastProgressStore
            .record(progress.flashcardId.toString())
            .put(db, progress.toJson());
        return progress;
      } catch (e) {
        print('❌ Error updating user progress in IndexedDB: $e');
        rethrow;
      }
    }

    if (_useSharedPrefs) {
      final all = await _getProgressFromSharedPrefs();
      final index =
          all.indexWhere((p) => p.flashcardId == progress.flashcardId);
      if (index != -1) {
        all[index] = progress;
      } else {
        all.add(progress);
      }
      await _saveProgressToSharedPrefs(all);
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
    if (_useSembast) {
      try {
        final db = await _getSembastDb();
        await _sembastProgressStore.record(flashcardId).delete(db);
        return 1;
      } catch (e) {
        print('❌ Error deleting user progress from IndexedDB: $e');
        rethrow;
      }
    }

    if (_useSharedPrefs) {
      final all = await _getProgressFromSharedPrefs();
      final int oldLength = all.length;
      all.removeWhere((p) => p.flashcardId.toString() == flashcardId);
      await _saveProgressToSharedPrefs(all);
      return oldLength - all.length;
    }

    final db = await database;
    try {
      final result = await db.delete(
        'user_progress_local',
        where: 'flashcard_id = ?',
        whereArgs: [int.tryParse(flashcardId) ?? 0],
      );
      return result;
    } catch (e) {
      print('❌ Error deleting user progress: $e');
      rethrow;
    }
  }

  // ============================================================
  // UTILITIES
  // ============================================================
  Future<Map<String, dynamic>> checkDatabase() async {
    if (_useSembast) {
      final cards = await _getAllFromSembast();
      final progress = await _getAllProgressFromSembast();
      return {
        'mode': 'IndexedDB',
        'count': cards.length,
        'progressCount': progress.length,
        'hasData': cards.isNotEmpty,
      };
    }

    if (_useSharedPrefs) {
      final cards = await _getFromSharedPrefs();
      final progress = await _getProgressFromSharedPrefs();
      return {
        'mode': 'SharedPreferences',
        'count': cards.length,
        'progressCount': progress.length,
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
        'databasePath': await sqflite.getDatabasesPath(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<void> resetDatabase() async {
    if (_useSembast) {
      final db = await _getSembastDb();
      await _sembastFlashcardStore.delete(db);
      await _sembastProgressStore.delete(db);
      print('✅ IndexedDB reset successfully');
      return;
    }

    if (_useSharedPrefs) {
      await _saveToSharedPrefs([]);
      await _saveProgressToSharedPrefs([]);
      print('✅ SharedPreferences reset successfully');
      return;
    }

    try {
      final db = await database;
      await db.execute('DROP TABLE IF EXISTS flashcards_local');
      await db.execute('DROP TABLE IF EXISTS user_progress_local');
      await _onCreate(db, 3);
      print('✅ Database reset successfully');
    } catch (e) {
      print('❌ Error resetting database: $e');
      rethrow;
    }
  }

  // ============================================================
  // MIGRATION: localStorage -> IndexedDB (Web)
  // ============================================================
  Future<void> migrateFromSharedPrefsToSembast() async {
    if (!_useSembast) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final migratedFlag = prefs.getBool(_migrationFlagKey) ?? false;
      if (migratedFlag) return;

      final oldCards = prefs.getString(_prefsFlashcardsKey);
      final oldProgress = prefs.getString(_prefsProgressKey);

      if (oldCards != null) {
        final List<dynamic> jsonList = jsonDecode(oldCards);
        final cards = jsonList.map((j) => Flashcard.fromJson(j)).toList();
        if (cards.isNotEmpty) {
          await _saveAllToSembast(cards);
          print('✅ Migrated ${cards.length} flashcards to IndexedDB');
        }
      }

      if (oldProgress != null) {
        final List<dynamic> jsonList = jsonDecode(oldProgress);
        final progresses =
            jsonList.map((j) => UserProgress.fromJson(j)).toList();
        if (progresses.isNotEmpty) {
          await _saveAllProgressToSembast(progresses);
          print(
              '✅ Migrated ${progresses.length} progress records to IndexedDB');
        }
      }

      await prefs.remove(_prefsFlashcardsKey);
      await prefs.remove(_prefsProgressKey);
      await prefs.setBool(_migrationFlagKey, true);
      print('✅ Migration completed and old localStorage keys removed');
    } catch (e) {
      print('❌ Migration error: $e');
    }
  }

  // ============================================================
  // SQLITE SCHEMA
  // ============================================================
  Future<void> _onCreate(sqflite.Database db, int version) async {
    print('🔄 Creating database tables...');

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
      topic TEXT,
      next_review TEXT,
      interval INTEGER,
      ease_factor REAL,
      study_status TEXT DEFAULT 'new',
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  ''');

    await db.execute('''
    CREATE TABLE user_progress_local (
      id TEXT PRIMARY KEY,
      user_id TEXT,
      flashcard_id INTEGER NOT NULL,
      study_status TEXT DEFAULT 'new',
      srs_interval INTEGER DEFAULT 0,
      srs_ease_factor REAL DEFAULT 2.5,
      srs_next_review TEXT,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(flashcard_id)
    )
  ''');

    await db.execute(
        'CREATE INDEX idx_user_progress_local_flashcard_id ON user_progress_local(flashcard_id)');
    await db.execute(
        'CREATE INDEX idx_user_progress_local_study_status ON user_progress_local(study_status)');
    await db.execute(
        'CREATE INDEX idx_vietnamese ON flashcards_local(vietnamese)');
    await db.execute('CREATE INDEX idx_english ON flashcards_local(english)');
    await db.execute('CREATE INDEX idx_jp_level ON flashcards_local(jp_level)');
    await db.execute('CREATE INDEX idx_topic ON flashcards_local(topic)');

    print('✅ Local database created with user_progress table');
  }

  Future<void> _onUpgrade(
      sqflite.Database db, int oldVersion, int newVersion) async {
    print('🔄 Upgrading database from version $oldVersion to $newVersion');

    if (oldVersion < 2) {
      await db.execute('''
      CREATE TABLE IF NOT EXISTS user_progress_local (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        flashcard_id INTEGER NOT NULL,
        study_status TEXT DEFAULT 'new',
        srs_interval INTEGER DEFAULT 0,
        srs_ease_factor REAL DEFAULT 2.5,
        srs_next_review TEXT,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(flashcard_id)
      )
    ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_user_progress_local_flashcard_id ON user_progress_local(flashcard_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_user_progress_local_study_status ON user_progress_local(study_status)');
    }

    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE flashcards_local ADD COLUMN topic TEXT');
      } catch (_) {}
      try {
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_topic ON flashcards_local(topic)');
      } catch (_) {}
      for (final col in [
        'next_review TEXT',
        'interval INTEGER',
        'ease_factor REAL',
      ]) {
        try {
          await db.execute('ALTER TABLE flashcards_local ADD COLUMN $col');
        } catch (_) {}
      }
    }
  }
}