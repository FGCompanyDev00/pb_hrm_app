import 'dart:io';

import 'package:advanced_calendar_day_view/calendar_day_view.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabaseService {
  Database? _database;
  String calendarTable = 'calendar_table';

  // Getter for our database
  Future<Database> get database async {
    _database ??= await initializeDatabase('calendar');
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
      getDatabase = await openDatabase(path, version: 1, onCreate: _createTable);
    }
    debugPrint("Database Created");
    return getDatabase;
  }

  // Function for creating a Table
  void _createTable(Database db, int newVersion) async {
    if (_database == null) {
      await db.execute('''
        CREATE TABLE $calendarTable (
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
      await db.rawQuery('SELECT * FROM $calendarTable');
    }
  }

  //Fetch operation
  Future<List<Events>> getListEvents() async {
    Database db = await database;
    var result = await db.rawQuery('SELECT * FROM $calendarTable');
    List<Events> storeEvents = [];
    for (var e in result) {
      storeEvents.add(Events.fromJson(e));
    }
    return storeEvents;
  }
  // //Fetch operation
  // Future<List<Map<String, dynamic>>> getPerson(String email) async {
  //   Database db = await this.database;
  //   var result = await db.rawQuery('SELECT * FROM $personTable WHERE $personEmail = \'$email\' ');
  //   return result;
  // }

  // Insert Operation
  Future<void> insertEvents(List<Events> events) async {
    Database db = await database;

    // var batch = db.batch();

    // for (var e in events) {
    //   batch.insert('calendar_table', e.toJson());
    // }

    // await batch.commit(noResult: true);

    for (var e in events) {
      String uid = e.uid;

      // Check if the record exists
      final List<Map<String, dynamic>> existing = await db.query(
        calendarTable,
        where: 'uid = ?', // Condition
        whereArgs: [uid], // Arguments for the condition
      );

      if (existing.isEmpty) {
        // If the record doesn't exist, insert it
        await db.insert(calendarTable, e.toJson());
      }
    }
    debugPrint("Events details inserted in the $calendarTable.");
    return;
  }

  // Future<void> insertEvents(List<Events> data) async {
  //   Database db = await database;
  //   await db.execute('PRAGMA synchronous = OFF;');
  //   await db.transaction((txn) async {
  //     // Create temporary table
  //     await txn.execute('CREATE TEMP TABLE IF NOT EXISTS temp_uids (uid TEXT PRIMARY KEY);');

  //     // Insert uids into the temporary table
  //     final batch = txn.batch();
  //     for (final record in data) {
  //       batch.rawInsert('INSERT OR IGNORE INTO temp_uids (uid) VALUES (?);', [record.uid]);
  //     }
  //     await batch.commit(noResult: true);

  //     // Insert new records
  //     await txn.rawInsert('''
  //     INSERT INTO calendar_table (uid, title, startDateTime, endDateTime, description, status, isMeeting, category, days, members)
  //     SELECT newData.uid, ?, ?, ?, ?, ?, ?, ?, ?, ?
  //     FROM temp_uids AS newData
  //     WHERE NOT EXISTS (
  //         SELECT 1 FROM calendar_table WHERE calendar_table.uid = newData.uid
  //     );
  //   ''', [
  //       data.first.title, // Update placeholders dynamically
  //       data.first.startDateTime,
  //       data.first.endDateTime,
  //       data.first.description,
  //       data.first.status,
  //       data.first.isMeeting,
  //       data.first.category,
  //       data.first.days,
  //       data.first.members,
  //     ]);

  //     // Drop the temporary table
  //     await txn.execute('DROP TABLE temp_uids;');
  //   });
  //   await db.execute('PRAGMA synchronous = FULL;');
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

  // Delete Operation
  // Future<int> deletePerson(String email) async {
  //   Database db = await this.database;
  //   var result = await db.rawDelete('DELETE FROM $personTable WHERE $personEmail = ?', [email]);
  //   return result;
  // }
}
