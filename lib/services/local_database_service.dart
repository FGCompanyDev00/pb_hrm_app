import 'dart:io';
import 'dart:convert';

import 'package:advanced_calendar_day_view/calendar_day_view.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class CalendarDatabaseService {
  Database? _database;
  String calendarTable = 'calendar_table';
  final int _currentVersion = 2; // Increase version for schema changes

  // Getter for our database
  Future<Database> get database async {
    _database ??= await initializeDatabase('calendar');
    return _database!;
  }

  // Function to initialize the database
  Future<Database> initializeDatabase(String nameDb) async {
    try {
      // Getting directory path for both Android and iOS
      Directory directory = await getApplicationDocumentsDirectory();
      String path = '${directory.path}$nameDb.db';

      // Delete existing database if it exists
      if (await databaseExists(path)) {
        await deleteDatabase(path);
        debugPrint("Deleted existing database for clean initialization");
      }

      // Open/create database with versioning support
      Database db = await openDatabase(
        path,
        version: _currentVersion,
        onCreate: _createDatabase,
        onUpgrade: _onUpgrade,
      );

      debugPrint("Database Created/Opened Successfully");
      return db;
    } catch (e) {
      debugPrint("Error initializing database: $e");
      rethrow;
    }
  }

  // Database creation
  Future<void> _createDatabase(Database db, int version) async {
    try {
      await db.execute('''
        CREATE TABLE $calendarTable (
          uid TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          startDateTime TEXT NOT NULL,
          endDateTime TEXT NOT NULL,
          description TEXT NOT NULL,
          status TEXT NOT NULL,
          isMeeting INTEGER NOT NULL,
          location TEXT,
          createdBy TEXT,
          imgName TEXT,
          createdAt TEXT DEFAULT CURRENT_TIMESTAMP,
          isRepeat INTEGER,
          videoConference TEXT,
          backgroundColor TEXT,
          outmeetingUid TEXT,
          leaveType TEXT,
          fileName TEXT,
          category TEXT NOT NULL,
          days REAL,
          members TEXT
        )
      ''');

      // Create indexes for better performance
      await db.execute(
          'CREATE INDEX idx_calendar_date ON $calendarTable(startDateTime, endDateTime)');
      await db.execute(
          'CREATE INDEX idx_calendar_category ON $calendarTable(category)');

      debugPrint("Database tables and indexes created successfully");
    } catch (e) {
      debugPrint("Error creating database: $e");
      rethrow;
    }
  }

  // Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    try {
      if (oldVersion < 2) {
        // Add fileName column if upgrading from version 1
        await db.execute('ALTER TABLE $calendarTable ADD COLUMN fileName TEXT');
      }
      debugPrint("Database upgraded from version $oldVersion to $newVersion");
    } catch (e) {
      debugPrint("Error upgrading database: $e");
      rethrow;
    }
  }

  // Insert Operation with robust error handling
  Future<void> insertEvents(List<Events> events) async {
    if (events.isEmpty) return;

    final Database db = await database;
    final List<Events> eventsCopy = List<Events>.from(events);

    try {
      await db.transaction((txn) async {
        final batch = txn.batch();

        for (var event in eventsCopy) {
          Map<String, dynamic> eventJson = event.toJson();

          // Clean and prepare data
          eventJson.remove('id');
          eventJson['fileName'] = eventJson['fileName'] ?? null;

          // Handle members field
          if (event.members != null) {
            try {
              eventJson['members'] = jsonEncode(event.members);
            } catch (e) {
              debugPrint("Error encoding members: $e");
              eventJson['members'] = '[]';
            }
          }

          // Check for existing record
          final existing = await txn.query(
            calendarTable,
            columns: ['uid'],
            where: 'uid = ?',
            whereArgs: [event.uid],
            limit: 1,
          );

          if (existing.isEmpty) {
            batch.insert(
              calendarTable,
              eventJson,
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
        }

        await batch.commit(noResult: true);
      });

      debugPrint("Successfully inserted ${eventsCopy.length} events");
    } catch (e) {
      debugPrint("Error inserting events: $e");
      debugPrint("Error details: ${e.toString()}");
      rethrow;
    }
  }

  // Fetch operation with improved error handling
  Future<List<Events>> getListEvents() async {
    try {
      final Database db = await database;
      final result = await db.query(
        calendarTable,
        orderBy: 'startDateTime ASC',
      );

      return result
          .map((e) {
            try {
              // Handle members JSON parsing
              if (e['members'] != null && e['members'] is String) {
                try {
                  e['members'] = jsonDecode(e['members'] as String);
                } catch (error) {
                  debugPrint('Error parsing members JSON: $error');
                  e['members'] = [];
                }
              }
              return Events.fromJson(e);
            } catch (error) {
              debugPrint('Error converting record to Event: $error');
              return null;
            }
          })
          .whereType<Events>()
          .toList();
    } catch (e) {
      debugPrint('Error fetching events: $e');
      return [];
    }
  }

  // //Fetch operation
  // Future<List<Map<String, dynamic>>> getPerson(String email) async {
  //   Database db = await this.database;
  //   var result = await db.rawQuery('SELECT * FROM $personTable WHERE $personEmail = \'$email\' ');
  //   return result;
  // }

  // // Insert Operation
  // Future<int> insertPerson(Person person) async {
  //   Database db = await this.database;
  //   var result = await db.insert(personTable, person.toMap());
  //   print("Person details inserted in the $personTable.");
  //   print("$personTable contains $result records.");
  //   return result;
  // }

  // // Update Operation
  // Future<int> updatePerson(Person person) async {
  //   Database db = await this.database;
  //   var result = await db.update(personTable, person.toMap(), where: '$personEmail = ?', whereArgs: [person.email]);
  //   return result;
  // }

  // // Delete Operation
  // Future<int> deletePerson(String email) async {
  //   Database db = await this.database;
  //   var result = await db.rawDelete('DELETE FROM $personTable WHERE $personEmail = ?', [email]);
  //   return result;
  // }
}

class HistoryDatabaseService {
  Database? _database;
  String historyTable = 'history_table';
  String historyPendingTable = 'history_pending_table';

  // Getter for our database
  Future<Database> get database async {
    _database ??= await initializeDatabase('history');
    return _database!;
  }

  // Getter for our database
  Future<Database> get databasePending async {
    _database ??= await initializeDatabase('history_pending');
    return _database!;
  }

  // Function to initialize the database
  Future<Database> initializeDatabase(String nameDb) async {
    // Getting directory path for both Android and iOS
    Directory directory = await getApplicationDocumentsDirectory();
    String path = '${directory.path}$nameDb.db';
    Database getDatabase;
    // Open or create database at a given path.
    final existDatabase = await databaseExists(nameDb);
    if (existDatabase) {
      getDatabase = await openDatabase(path, version: 1, onOpen: _getTable);
    } else {
      getDatabase =
          await openDatabase(path, version: 1, onCreate: _createTable);
    }
    debugPrint("Database Created");
    return getDatabase;
  }

  // Function to initialize the database
  Future<Database> initializeDatabasePending(String nameDb) async {
    // Getting directory path for both Android and iOS
    Directory directory = await getApplicationDocumentsDirectory();
    String path = '${directory.path}$nameDb.db';
    Database getDatabase;
    // Open or create database at a given path.
    final existDatabase = await databaseExists(nameDb);
    if (existDatabase) {
      getDatabase = await openDatabase(path, version: 1, onOpen: _getTable);
    } else {
      getDatabase =
          await openDatabase(path, version: 1, onCreate: _createTable);
    }
    debugPrint("Database Created");
    return getDatabase;
  }

  // Function for creating a Table
  void _createTable(Database db, int newVersion) async {
    if (_database == null) {
      await db.execute('''
        CREATE TABLE $historyTable (
            uid TEXT PRIMARY KEY, -- Unique identifier
            title TEXT NOT NULL, -- Event title
            startDateTime TEXT NOT NULL, -- Start date and time
            endDateTime TEXT NOT NULL, -- End date and time
            description TEXT NOT NULL, -- Description of the event
            status TEXT NOT NULL, -- Event status
            isMeeting INTEGER NOT NULL, -- Is it a meeting? (0 = false, 1 = true)
            location TEXT, -- Optional event location
            createdBy TEXT, -- User who created the event
            imgName TEXT, -- Name of an image file
            createdAt TEXT DEFAULT CURRENT_TIMESTAMP, -- Creation timestamp
            isRepeat INTEGER, -- Is the event recurring? (0 = false, 1 = true)
            videoConference TEXT, -- Video conference link
            backgroundColor TEXT, -- Background color in HEX format
            outmeetingUid TEXT, -- Reference to another meeting UID
            leaveType TEXT, -- Type of leave (if applicable)
            category TEXT NOT NULL, -- Event category
            days INTEGER, -- Number of days (if relevant)
            members TEXT -- JSON string or list of members
        );
      ''');
    }
  }

  // Function for creating a Table
  void _createTablePending(Database db, int newVersion) async {
    if (_database == null) {
      await db.execute('''
        CREATE TABLE $historyPendingTable (
            uid TEXT PRIMARY KEY, -- Unique identifier
            title TEXT NOT NULL, -- Event title
            startDateTime TEXT NOT NULL, -- Start date and time
            endDateTime TEXT NOT NULL, -- End date and time
            description TEXT NOT NULL, -- Description of the event
            status TEXT NOT NULL, -- Event status
            isMeeting INTEGER NOT NULL, -- Is it a meeting? (0 = false, 1 = true)
            location TEXT, -- Optional event location
            createdBy TEXT, -- User who created the event
            imgName TEXT, -- Name of an image file
            createdAt TEXT DEFAULT CURRENT_TIMESTAMP, -- Creation timestamp
            isRepeat INTEGER, -- Is the event recurring? (0 = false, 1 = true)
            videoConference TEXT, -- Video conference link
            backgroundColor TEXT, -- Background color in HEX format
            outmeetingUid TEXT, -- Reference to another meeting UID
            leaveType TEXT, -- Type of leave (if applicable)
            category TEXT NOT NULL, -- Event category
            days INTEGER, -- Number of days (if relevant)
            members TEXT -- JSON string or list of members
        );
      ''');
    }
  }

  // Function for finding a Table
  void _getTable(Database db) async {
    if (_database == null) {
      await db.rawQuery('SELECT * FROM $historyTable');
    }
  }

  // Function for finding a Table
  void _getTablePending(Database db) async {
    if (_database == null) {
      await db.rawQuery('SELECT * FROM $historyPendingTable');
    }
  }

  //Fetch operation
  Future<List<Events>> getListHistory() async {
    Database db = await database;
    var result = await db.rawQuery('SELECT * FROM $historyTable');
    List<Events> storeEvents = [];
    for (var e in result) {
      storeEvents.add(Events.fromJson(e));
    }
    return storeEvents;
  }

  //Fetch Pending operation
  Future<List<Events>> getListPending() async {
    Database db = await databasePending;
    var result = await db.rawQuery('SELECT * FROM $historyPendingTable');
    List<Events> storeEvents = [];
    for (var e in result) {
      storeEvents.add(Events.fromJson(e));
    }
    return storeEvents;
  }

  // Insert Operation
  Future<void> insertHistory(List<Events> events) async {
    Database db = await database;

    for (var e in events) {
      String uid = e.uid;

      // Check if the record exists
      final List<Map<String, dynamic>> existing = await db.query(
        historyTable,
        where: 'uid = ?', // Condition
        whereArgs: [uid], // Arguments for the condition
      );

      if (existing.isEmpty) {
        // If the record doesn't exist, insert it
        await db.insert(historyTable, e.toJson());
      }
    }
    debugPrint("Events details inserted in the $historyTable.");
    return;
  }

  // Insert Operation
  Future<void> insertPending(List<Events> events) async {
    Database db = await databasePending;

    for (var e in events) {
      String uid = e.uid;

      // Check if the record exists
      final List<Map<String, dynamic>> existing = await db.query(
        historyTable,
        where: 'uid = ?', // Condition
        whereArgs: [uid], // Arguments for the condition
      );

      if (existing.isEmpty) {
        // If the record doesn't exist, insert it
        await db.insert(historyTable, e.toJson());
      }
    }
    debugPrint("Events details inserted in the $historyTable.");
    return;
  }
}
