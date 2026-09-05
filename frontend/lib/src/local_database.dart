part of '../main.dart';

class LocalCaterProDb {
  LocalCaterProDb._();
  static final instance = LocalCaterProDb._();
  Database? _db;
  Future<void>? _dailyBackupRun;

  static const stateId = 'default';
  static const databaseFileName = 'caterpro_local.db';
  static const dailyBackupPrefsKey = 'localDb.lastDailyBackupDate';

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('Local SQLite cache is not available on web');
    }
    final existing = _db;
    if (existing != null) return existing;
    final basePath = await getDatabasesPath();
    final dbPath = path_package.join(basePath, databaseFileName);
    return _db = await openDatabase(
      dbPath,
      version: 6,
      onCreate: (db, version) async => createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        await createSchema(db);
        if (oldVersion < 3) {
          await addColumnIfMissing(db, 'cp_business_profiles', 'ifsc', 'text');
        }
        if (oldVersion < 4) {
          await addColumnIfMissing(
              db, 'cp_business_profiles', 'account_holder_name', 'text');
          await addColumnIfMissing(
              db, 'cp_business_profiles', 'branch_name', 'text');
        }
        if (oldVersion < 5) {
          await createSchema(db);
        }
        if (oldVersion < 6) {
          await createSchema(db);
        }
      },
    );
  }

  Future<void> createDailyBackupIfNeeded() {
    if (kIsWeb) return Future.value();
    return _dailyBackupRun ??= _createDailyBackupIfNeeded().whenComplete(() {
      _dailyBackupRun = null;
    });
  }

  Future<void> _createDailyBackupIfNeeded() async {
    try {
      final now = DateTime.now();
      final today =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(dailyBackupPrefsKey) == today) return;

      final db = await database;
      final basePath = await getDatabasesPath();
      final backupDir = Directory(path_package.join(basePath, 'backups'));
      if (!await backupDir.exists()) await backupDir.create(recursive: true);

      final backupPath =
          path_package.join(backupDir.path, 'caterpro_local_$today.db');
      final backupFile = File(backupPath);
      if (await backupFile.exists()) await backupFile.delete();

      try {
        final escapedPath = backupPath.replaceAll("'", "''");
        await db.execute("VACUUM INTO '$escapedPath'");
      } catch (_) {
        await db.close();
        _db = null;
        final sourcePath = path_package.join(basePath, databaseFileName);
        await File(sourcePath).copy(backupPath);
        await database;
      }

      await rotateDailyBackups(backupDir);
      await prefs.setString(dailyBackupPrefsKey, today);
    } catch (error) {
      debugPrint('Daily SQLite backup skipped: $error');
    }
  }

  Future<void> rotateDailyBackups(Directory backupDir) async {
    final files = await backupDir
        .list()
        .where((entity) =>
            entity is File &&
            path_package.basename(entity.path).startsWith('caterpro_local_') &&
            path_package.extension(entity.path) == '.db')
        .cast<File>()
        .toList();
    files.sort((a, b) =>
        path_package.basename(b.path).compareTo(path_package.basename(a.path)));
    for (final file in files.skip(7)) {
      try {
        await file.delete();
      } catch (error) {
        debugPrint('Old SQLite backup delete skipped: $error');
      }
    }
  }

  Future<void> createSchema(Database db) async {
    for (final sql in schemaStatements) {
      await db.execute(sql);
    }
  }

  Future<void> addColumnIfMissing(
      Database db, String table, String column, String type) async {
    try {
      await db.execute('alter table $table add column $column $type');
    } catch (error) {
      if (!error.toString().toLowerCase().contains('duplicate column')) {
        rethrow;
      }
    }
  }

  List<String> get schemaStatements => const [
        '''
        create table if not exists cp_users (
          state_id text not null,
          id text not null,
          name text,
          email text,
          role text,
          raw text not null,
          synced integer not null default 1,
          updated_at text not null,
          primary key (state_id, id)
        )
        ''',
        '''
        create table if not exists cp_business_profiles (
          state_id text not null,
          user_id text not null,
          business_name text,
          service_type text,
          gstin text,
          gst_type text,
          gst_rate real,
          ifsc text,
          account_holder_name text,
          branch_name text,
          phone text,
          email text,
          raw text not null,
          synced integer not null default 1,
          updated_at text not null,
          primary key (state_id, user_id)
        )
        ''',
        '''
        create table if not exists cp_clients (
          state_id text not null,
          user_id text not null,
          id text not null,
          name text,
          mobile text,
          city text,
          raw text not null,
          synced integer not null default 1,
          updated_at text not null,
          primary key (state_id, user_id, id)
        )
        ''',
        '''
        create table if not exists cp_employees (
          state_id text not null,
          user_id text not null,
          id text not null,
          name text,
          mobile text,
          designation text,
          pay_per_day real,
          pay_per_hour real,
          raw text not null,
          synced integer not null default 1,
          updated_at text not null,
          primary key (state_id, user_id, id)
        )
        ''',
        '''
        create table if not exists cp_events (
          state_id text not null,
          user_id text not null,
          id text not null,
          name text,
          primary_client text,
          mobile text,
          venue text,
          status text,
          notes text,
          add_ons text not null,
          raw text not null,
          synced integer not null default 1,
          updated_at text not null,
          primary key (state_id, user_id, id)
        )
        ''',
        '''
        create table if not exists cp_event_dates (
          state_id text not null,
          user_id text not null,
          event_id text not null,
          id text not null,
          event_date text,
          label text,
          additional_services text not null,
          raw text not null,
          synced integer not null default 1,
          updated_at text not null,
          primary key (state_id, user_id, event_id, id)
        )
        ''',
        '''
        create table if not exists cp_menu_slots (
          state_id text not null,
          user_id text not null,
          event_id text not null,
          date_id text not null,
          id text not null,
          type text,
          delivery_time text,
          pax integer,
          price_per_pax integer,
          enabled integer,
          menu_item_ids text not null,
          additional_services text not null,
          raw text not null,
          synced integer not null default 1,
          updated_at text not null,
          primary key (state_id, user_id, event_id, date_id, id)
        )
        ''',
        '''
        create table if not exists cp_event_payments (
          state_id text not null,
          user_id text not null,
          event_id text not null,
          id text not null,
          amount integer,
          payment_date text,
          mode text,
          reference text,
          settled integer,
          raw text not null,
          synced integer not null default 1,
          updated_at text not null,
          primary key (state_id, user_id, event_id, id)
        )
        ''',
        '''
        create table if not exists cp_event_assignments (
          state_id text not null,
          user_id text not null,
          event_id text not null,
          employee_id text not null,
          name text,
          designation text,
          pay_per_day real,
          pay_per_hour real,
          raw text not null,
          synced integer not null default 1,
          updated_at text not null,
          primary key (state_id, user_id, event_id, employee_id)
        )
        ''',
        '''
        create table if not exists cp_attendance (
          state_id text not null,
          user_id text not null,
          event_id text not null,
          employee_id text not null,
          attendance_date text not null,
          status text,
          hours real,
          pay_per_day real,
          pay_per_hour real,
          raw text not null,
          synced integer not null default 1,
          updated_at text not null,
          primary key (state_id, user_id, event_id, employee_id, attendance_date)
        )
        ''',
        '''
        create table if not exists cp_additional_services (
          state_id text not null,
          user_id text not null,
          id text not null,
          name text,
          unit text,
          price real,
          raw text not null,
          synced integer not null default 1,
          updated_at text not null,
          primary key (state_id, user_id, id)
        )
        ''',
        '''
        create table if not exists cp_custom_menus (
          state_id text not null,
          user_id text not null,
          id text not null,
          name text,
          type text,
          item_ids text not null,
          raw text not null,
          synced integer not null default 1,
          updated_at text not null,
          primary key (state_id, user_id, id)
        )
        ''',
        '''
        create table if not exists cp_manual_invoices (
          state_id text not null,
          user_id text not null,
          id text not null,
          invoice_number text,
          client_name text,
          mobile text,
          event_name text,
          event_date text,
          invoice_date text,
          total integer,
          pending integer,
          raw text not null,
          synced integer not null default 1,
          updated_at text not null,
          primary key (state_id, user_id, id)
        )
        ''',
        '''
        create table if not exists cp_manual_invoice_items (
          state_id text not null,
          user_id text not null,
          invoice_id text not null,
          id text not null,
          title text,
          quantity integer,
          rate integer,
          amount integer,
          raw text not null,
          synced integer not null default 1,
          updated_at text not null,
          primary key (state_id, user_id, invoice_id, id)
        )
        ''',
        '''
        create table if not exists cp_audit_logs (
          state_id text not null,
          user_id text not null,
          id text not null,
          action text,
          entity_type text,
          entity_id text,
          entity_label text,
          summary text,
          created_at text not null,
          raw text not null,
          synced integer not null default 1,
          updated_at text not null,
          primary key (state_id, user_id, id)
        )
        ''',
        '''
        create table if not exists cp_menu_items (
          state_id text not null,
          id text not null,
          english text,
          kannada text,
          title text,
          category text,
          meals text not null,
          veg integer,
          raw text not null,
          synced integer not null default 1,
          updated_at text not null,
          primary key (state_id, id)
        )
        ''',
        '''
        create table if not exists cp_user_menu_items (
          state_id text not null,
          user_id text not null,
          id text not null,
          english text,
          kannada text,
          title text,
          category text,
          meals text not null,
          veg integer,
          raw text not null,
          synced integer not null default 1,
          updated_at text not null,
          primary key (state_id, user_id, id)
        )
        ''',
        '''
        create table if not exists cp_raw_materials (
          state_id text not null,
          id text not null,
          name text,
          category text,
          unit text,
          raw text not null,
          synced integer not null default 1,
          updated_at text not null,
          primary key (state_id, id)
        )
        ''',
        '''
        create table if not exists cp_user_raw_materials (
          state_id text not null,
          user_id text not null,
          id text not null,
          name text,
          category text,
          unit text,
          raw text not null,
          synced integer not null default 1,
          updated_at text not null,
          primary key (state_id, user_id, id)
        )
        ''',
        '''
        create table if not exists cp_produce_items (
          state_id text not null,
          id text not null,
          name text,
          category text,
          unit text,
          raw text not null,
          synced integer not null default 1,
          updated_at text not null,
          primary key (state_id, id)
        )
        ''',
        '''
        create table if not exists cp_user_produce_items (
          state_id text not null,
          user_id text not null,
          id text not null,
          name text,
          category text,
          unit text,
          raw text not null,
          synced integer not null default 1,
          updated_at text not null,
          primary key (state_id, user_id, id)
        )
        ''',
        '''
        create table if not exists cp_vessel_items (
          state_id text not null,
          id text not null,
          name text,
          category text,
          unit text,
          raw text not null,
          synced integer not null default 1,
          updated_at text not null,
          primary key (state_id, id)
        )
        ''',
        '''
        create table if not exists cp_user_vessel_items (
          state_id text not null,
          user_id text not null,
          id text not null,
          name text,
          category text,
          unit text,
          raw text not null,
          synced integer not null default 1,
          updated_at text not null,
          primary key (state_id, user_id, id)
        )
        ''',
      ];

  Future<String> currentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth.userId') ?? 'default-user';
  }

  String encode(Object? value) => jsonEncode(value ?? []);

  Map<String, dynamic> decodeRaw(Map<String, Object?> row) {
    final raw = row['raw']?.toString() ?? '{}';
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
  }

  Future<void> saveSnapshot({
    required Map<String, dynamic> userData,
    required Map<String, dynamic> universal,
    required bool synced,
  }) async {
    if (kIsWeb) return;
    final db = await database;
    final userId = await currentUserId();
    final updatedAt = DateTime.now().toIso8601String();
    final syncedValue = synced ? 1 : 0;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final table in userTables) {
        batch.delete(table, where: 'state_id = ?', whereArgs: [stateId]);
      }
      if (userData.containsKey('menuItems')) {
        batch.delete('cp_user_menu_items',
            where: 'state_id = ? and user_id = ?',
            whereArgs: [stateId, userId]);
      }
      if (userData.containsKey('rawMaterials')) {
        batch.delete('cp_user_raw_materials',
            where: 'state_id = ? and user_id = ?',
            whereArgs: [stateId, userId]);
      }
      if (userData.containsKey('produceItems')) {
        batch.delete('cp_user_produce_items',
            where: 'state_id = ? and user_id = ?',
            whereArgs: [stateId, userId]);
      }
      if (userData.containsKey('vesselItems')) {
        batch.delete('cp_user_vessel_items',
            where: 'state_id = ? and user_id = ?',
            whereArgs: [stateId, userId]);
      }
      if (universal.containsKey('menuItems')) {
        batch.delete('cp_menu_items',
            where: 'state_id = ?', whereArgs: [stateId]);
      }
      if (universal.containsKey('rawMaterials')) {
        batch.delete('cp_raw_materials',
            where: 'state_id = ?', whereArgs: [stateId]);
      }
      if (universal.containsKey('produceItems')) {
        batch.delete('cp_produce_items',
            where: 'state_id = ?', whereArgs: [stateId]);
      }
      if (universal.containsKey('vesselItems')) {
        batch.delete('cp_vessel_items',
            where: 'state_id = ?', whereArgs: [stateId]);
      }
      upsertUserRows(batch, userId, userData, updatedAt, syncedValue);
      upsertUniversalRows(batch, universal, updatedAt, syncedValue);
      await batch.commit(noResult: true);
    });
  }

  Future<bool> hasMasterData() async {
    if (kIsWeb) return true;
    final db = await database;
    final userId = await currentUserId();
    for (final table in [
      'cp_user_menu_items',
      'cp_user_produce_items',
      'cp_user_vessel_items',
    ]) {
      final rows = await db.rawQuery(
          'select count(*) as total from $table where state_id = ? and user_id = ?',
          [stateId, userId]);
      if (((rows.first['total'] as int?) ?? 0) == 0) return false;
    }
    return true;
  }

  Future<void> saveMasterData({
    required Map<String, dynamic> universal,
    required bool synced,
  }) async {
    if (kIsWeb) return;
    final db = await database;
    final userId = await currentUserId();
    final updatedAt = DateTime.now().toIso8601String();
    final syncedValue = synced ? 1 : 0;
    await db.transaction((txn) async {
      final batch = txn.batch();
      if (universal.containsKey('menuItems')) {
        batch.delete('cp_menu_items',
            where: 'state_id = ?', whereArgs: [stateId]);
      }
      if (universal.containsKey('rawMaterials')) {
        batch.delete('cp_raw_materials',
            where: 'state_id = ?', whereArgs: [stateId]);
      }
      if (universal.containsKey('produceItems')) {
        batch.delete('cp_produce_items',
            where: 'state_id = ?', whereArgs: [stateId]);
      }
      if (universal.containsKey('vesselItems')) {
        batch.delete('cp_vessel_items',
            where: 'state_id = ?', whereArgs: [stateId]);
      }
      batch.delete('cp_user_menu_items',
          where: 'state_id = ? and user_id = ?', whereArgs: [stateId, userId]);
      batch.delete('cp_user_raw_materials',
          where: 'state_id = ? and user_id = ?', whereArgs: [stateId, userId]);
      batch.delete('cp_user_produce_items',
          where: 'state_id = ? and user_id = ?', whereArgs: [stateId, userId]);
      batch.delete('cp_user_vessel_items',
          where: 'state_id = ? and user_id = ?', whereArgs: [stateId, userId]);
      upsertUniversalRows(batch, universal, updatedAt, syncedValue);
      upsertUserCatalogRows(
          batch,
          userId,
          {
            'menuItems': mapList(universal['menuItems']),
            'rawMaterials': mapList(universal['rawMaterials']),
            'produceItems': mapList(universal['produceItems']),
            'vesselItems': mapList(universal['vesselItems']),
          },
          updatedAt,
          syncedValue);
      await batch.commit(noResult: true);
    });
  }

  List<String> get userTables => const [
        'cp_audit_logs',
        'cp_manual_invoice_items',
        'cp_manual_invoices',
        'cp_event_assignments',
        'cp_event_payments',
        'cp_menu_slots',
        'cp_event_dates',
        'cp_attendance',
        'cp_events',
        'cp_custom_menus',
        'cp_additional_services',
        'cp_employees',
        'cp_clients',
        'cp_business_profiles',
        'cp_users',
      ];

  List<String> get localTables => const [
        'cp_audit_logs',
        'cp_manual_invoice_items',
        'cp_manual_invoices',
        'cp_event_assignments',
        'cp_event_payments',
        'cp_menu_slots',
        'cp_event_dates',
        'cp_attendance',
        'cp_events',
        'cp_custom_menus',
        'cp_additional_services',
        'cp_employees',
        'cp_clients',
        'cp_business_profiles',
        'cp_users',
        'cp_menu_items',
        'cp_raw_materials',
        'cp_produce_items',
        'cp_vessel_items',
      ];

  void insert(Batch batch, String table, Map<String, Object?> values) {
    batch.insert(table, values, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  void upsertUserRows(Batch batch, String userId, Map<String, dynamic> userData,
      String updatedAt, int synced) {
    final profile = Map<String, dynamic>.from(
        (userData['businessProfile'] as Map?) ?? const {});
    insert(batch, 'cp_users', {
      'state_id': stateId,
      'id': userId,
      'name': '',
      'email': '',
      'role': '',
      'raw': encode({'id': userId}),
      'synced': synced,
      'updated_at': updatedAt,
    });
    insert(batch, 'cp_business_profiles', {
      'state_id': stateId,
      'user_id': userId,
      'business_name': profile['businessName']?.toString() ?? '',
      'service_type': profile['serviceType']?.toString() ?? '',
      'gstin': profile['gstin']?.toString() ?? '',
      'gst_type': profile['gstType']?.toString() ?? '',
      'gst_rate': double.tryParse(profile['gstRate']?.toString() ?? '') ?? 0,
      'ifsc': profile['ifsc']?.toString() ?? '',
      'account_holder_name': profile['accountHolderName']?.toString() ?? '',
      'branch_name': profile['branchName']?.toString() ?? '',
      'phone': profile['phone']?.toString() ?? '',
      'email': profile['email']?.toString() ?? '',
      'raw': encode(profile),
      'synced': synced,
      'updated_at': updatedAt,
    });
    for (final item in mapList(userData['clients'])) {
      insert(batch, 'cp_clients', {
        'state_id': stateId,
        'user_id': userId,
        'id': item['id']?.toString() ?? '',
        'name': item['name']?.toString() ?? '',
        'mobile': item['mobile']?.toString() ?? '',
        'city': item['city']?.toString() ?? item['address']?.toString() ?? '',
        'raw': encode(item),
        'synced': synced,
        'updated_at': updatedAt,
      });
    }
    for (final item in mapList(userData['employees'])) {
      insert(batch, 'cp_employees', {
        'state_id': stateId,
        'user_id': userId,
        'id': item['id']?.toString() ?? '',
        'name': item['name']?.toString() ?? '',
        'mobile': item['mobile']?.toString() ?? '',
        'designation': item['designation']?.toString() ?? '',
        'pay_per_day':
            double.tryParse(item['payPerDay']?.toString() ?? '') ?? 0,
        'pay_per_hour':
            double.tryParse(item['payPerHour']?.toString() ?? '') ?? 0,
        'raw': encode(item),
        'synced': synced,
        'updated_at': updatedAt,
      });
    }
    for (final item in mapList(userData['additionalServices'])) {
      insert(batch, 'cp_additional_services', {
        'state_id': stateId,
        'user_id': userId,
        'id': item['id']?.toString() ?? '',
        'name': item['name']?.toString() ?? '',
        'unit': item['unit']?.toString() ?? '',
        'price': double.tryParse(item['price']?.toString() ?? '') ?? 0,
        'raw': encode(item),
        'synced': synced,
        'updated_at': updatedAt,
      });
    }
    upsertUserCatalogRows(batch, userId, userData, updatedAt, synced);
    for (final item in mapList(userData['customMenus'])) {
      insert(batch, 'cp_custom_menus', {
        'state_id': stateId,
        'user_id': userId,
        'id': item['id']?.toString() ?? '',
        'name': item['name']?.toString() ?? '',
        'type': item['type']?.toString() ?? '',
        'item_ids': encode(item['itemIds']),
        'raw': encode(item),
        'synced': synced,
        'updated_at': updatedAt,
      });
    }
    for (final event in mapList(userData['events'])) {
      final eventId = event['id']?.toString() ?? '';
      insert(batch, 'cp_events', {
        'state_id': stateId,
        'user_id': userId,
        'id': eventId,
        'name': event['name']?.toString() ?? '',
        'primary_client': event['primaryClient']?.toString() ?? '',
        'mobile': event['mobile']?.toString() ?? '',
        'venue': event['venue']?.toString() ?? '',
        'status': event['status']?.toString() ?? '',
        'notes': event['notes']?.toString() ?? '',
        'add_ons': encode(event['addOns']),
        'raw': encode(event),
        'synced': synced,
        'updated_at': updatedAt,
      });
      for (final date in mapList(event['dates'])) {
        final dateId = date['id']?.toString().isNotEmpty == true
            ? date['id']?.toString() ?? ''
            : date['date']?.toString() ?? '';
        insert(batch, 'cp_event_dates', {
          'state_id': stateId,
          'user_id': userId,
          'event_id': eventId,
          'id': dateId,
          'event_date': date['date']?.toString() ?? '',
          'label': date['label']?.toString() ?? '',
          'additional_services': encode(date['additionalServices']),
          'raw': encode(date),
          'synced': synced,
          'updated_at': updatedAt,
        });
        for (final slot in mapList(date['menuSlots'])) {
          insert(batch, 'cp_menu_slots', {
            'state_id': stateId,
            'user_id': userId,
            'event_id': eventId,
            'date_id': dateId,
            'id': slot['id']?.toString() ?? '',
            'type': slot['type']?.toString() ?? '',
            'delivery_time': slot['time']?.toString() ?? '',
            'pax': int.tryParse(slot['pax']?.toString() ?? '') ?? 0,
            'price_per_pax':
                int.tryParse(slot['pricePerPax']?.toString() ?? '') ?? 0,
            'enabled': slot['enabled'] == false ? 0 : 1,
            'menu_item_ids': encode(slot['menuItemIds']),
            'additional_services': encode(slot['additionalServices']),
            'raw': encode(slot),
            'synced': synced,
            'updated_at': updatedAt,
          });
        }
      }
      for (final payment in mapList(event['payments'])) {
        insert(batch, 'cp_event_payments', {
          'state_id': stateId,
          'user_id': userId,
          'event_id': eventId,
          'id': payment['id']?.toString() ?? '',
          'amount': int.tryParse(payment['amount']?.toString() ?? '') ?? 0,
          'payment_date': payment['date']?.toString() ?? '',
          'mode': payment['mode']?.toString() ?? '',
          'reference': payment['reference']?.toString() ?? '',
          'settled': payment['settled'] == true ? 1 : 0,
          'raw': encode(payment),
          'synced': synced,
          'updated_at': updatedAt,
        });
      }
      for (final assignment in mapList(event['employeeAssignments'])) {
        insert(batch, 'cp_event_assignments', {
          'state_id': stateId,
          'user_id': userId,
          'event_id': eventId,
          'employee_id': assignment['employeeId']?.toString() ??
              assignment['id']?.toString() ??
              '',
          'name': assignment['name']?.toString() ??
              assignment['employeeName']?.toString() ??
              '',
          'designation': assignment['designation']?.toString() ?? '',
          'pay_per_day':
              double.tryParse(assignment['payPerDay']?.toString() ?? '') ?? 0,
          'pay_per_hour':
              double.tryParse(assignment['payPerHour']?.toString() ?? '') ?? 0,
          'raw': encode(assignment),
          'synced': synced,
          'updated_at': updatedAt,
        });
      }
    }
    for (final item in mapList(userData['attendance'])) {
      insert(batch, 'cp_attendance', {
        'state_id': stateId,
        'user_id': userId,
        'event_id': item['eventId']?.toString() ?? '',
        'employee_id': item['employeeId']?.toString() ?? '',
        'attendance_date': item['date']?.toString() ?? '',
        'status': item['status']?.toString() ?? '',
        'hours': double.tryParse(item['hours']?.toString() ?? '') ?? 0,
        'pay_per_day':
            double.tryParse(item['payPerDay']?.toString() ?? '') ?? 0,
        'pay_per_hour':
            double.tryParse(item['payPerHour']?.toString() ?? '') ?? 0,
        'raw': encode(item),
        'synced': synced,
        'updated_at': updatedAt,
      });
    }
    for (final invoice in mapList(userData['manualInvoices'])) {
      final invoiceId = invoice['id']?.toString() ?? '';
      insert(batch, 'cp_manual_invoices', {
        'state_id': stateId,
        'user_id': userId,
        'id': invoiceId,
        'invoice_number': invoice['invoiceNumber']?.toString() ?? '',
        'client_name': invoice['clientName']?.toString() ?? '',
        'mobile': invoice['mobile']?.toString() ?? '',
        'event_name': invoice['eventName']?.toString() ?? '',
        'event_date': invoice['eventDate']?.toString() ?? '',
        'invoice_date': invoice['invoiceDate']?.toString() ?? '',
        'total': int.tryParse(invoice['total']?.toString() ?? '') ?? 0,
        'pending': int.tryParse(invoice['pending']?.toString() ?? '') ?? 0,
        'raw': encode(invoice),
        'synced': synced,
        'updated_at': updatedAt,
      });
      for (final item in mapList(invoice['items'])) {
        insert(batch, 'cp_manual_invoice_items', {
          'state_id': stateId,
          'user_id': userId,
          'invoice_id': invoiceId,
          'id': item['id']?.toString() ?? item['title']?.toString() ?? '',
          'title': item['title']?.toString() ?? '',
          'quantity': int.tryParse(item['quantity']?.toString() ?? '') ?? 0,
          'rate': int.tryParse(item['rate']?.toString() ?? '') ?? 0,
          'amount': int.tryParse(item['amount']?.toString() ?? '') ?? 0,
          'raw': encode(item),
          'synced': synced,
          'updated_at': updatedAt,
        });
      }
    }
    for (final entry in mapList(userData['auditLogs'])) {
      insert(batch, 'cp_audit_logs', {
        'state_id': stateId,
        'user_id': userId,
        'id': entry['id']?.toString() ?? '',
        'action': entry['action']?.toString() ?? '',
        'entity_type': entry['entityType']?.toString() ?? '',
        'entity_id': entry['entityId']?.toString() ?? '',
        'entity_label': entry['entityLabel']?.toString() ?? '',
        'summary': entry['summary']?.toString() ?? '',
        'created_at': entry['createdAt']?.toString() ?? updatedAt,
        'raw': encode(entry),
        'synced': synced,
        'updated_at': updatedAt,
      });
    }
  }

  void upsertUserCatalogRows(Batch batch, String userId,
      Map<String, dynamic> userData, String updatedAt, int synced) {
    for (final item in mapList(userData['menuItems'])) {
      insert(batch, 'cp_user_menu_items', {
        'state_id': stateId,
        'user_id': userId,
        'id': item['id']?.toString() ?? '',
        'english': item['english']?.toString() ?? '',
        'kannada': item['kannada']?.toString() ?? '',
        'title': item['title']?.toString() ?? '',
        'category': item['category']?.toString() ?? '',
        'meals': encode(item['meals']),
        'veg': item['veg'] == true ? 1 : 0,
        'raw': encode(item),
        'synced': synced,
        'updated_at': updatedAt,
      });
    }
    for (final item in mapList(userData['rawMaterials'])) {
      insert(batch, 'cp_user_raw_materials', {
        'state_id': stateId,
        'user_id': userId,
        'id': item['id']?.toString() ?? '',
        'name': item['name']?.toString() ?? '',
        'category': item['category']?.toString() ?? '',
        'unit': item['unit']?.toString() ?? '',
        'raw': encode(item),
        'synced': synced,
        'updated_at': updatedAt,
      });
    }
    for (final item in mapList(userData['produceItems'])) {
      insert(batch, 'cp_user_produce_items', {
        'state_id': stateId,
        'user_id': userId,
        'id': item['id']?.toString() ?? '',
        'name': item['name']?.toString() ?? '',
        'category': item['category']?.toString() ?? '',
        'unit': item['unit']?.toString() ?? '',
        'raw': encode(item),
        'synced': synced,
        'updated_at': updatedAt,
      });
    }
    for (final item in mapList(userData['vesselItems'])) {
      insert(batch, 'cp_user_vessel_items', {
        'state_id': stateId,
        'user_id': userId,
        'id': item['id']?.toString() ?? '',
        'name': item['name']?.toString() ?? '',
        'category': item['category']?.toString() ?? '',
        'unit': item['unit']?.toString() ?? '',
        'raw': encode(item),
        'synced': synced,
        'updated_at': updatedAt,
      });
    }
  }

  void upsertUniversalRows(Batch batch, Map<String, dynamic> universal,
      String updatedAt, int synced) {
    for (final item in mapList(universal['menuItems'])) {
      insert(batch, 'cp_menu_items', {
        'state_id': stateId,
        'id': item['id']?.toString() ?? '',
        'english': item['english']?.toString() ?? '',
        'kannada': item['kannada']?.toString() ?? '',
        'title': item['title']?.toString() ?? '',
        'category': item['category']?.toString() ?? '',
        'meals': encode(item['meals']),
        'veg': item['veg'] == true ? 1 : 0,
        'raw': encode(item),
        'synced': synced,
        'updated_at': updatedAt,
      });
    }
    for (final item in mapList(universal['rawMaterials'])) {
      insert(batch, 'cp_raw_materials', {
        'state_id': stateId,
        'id': item['id']?.toString() ?? '',
        'name': item['name']?.toString() ?? '',
        'category': item['category']?.toString() ?? '',
        'unit': item['unit']?.toString() ?? '',
        'raw': encode(item),
        'synced': synced,
        'updated_at': updatedAt,
      });
    }
    for (final item in mapList(universal['produceItems'])) {
      insert(batch, 'cp_produce_items', {
        'state_id': stateId,
        'id': item['id']?.toString() ?? '',
        'name': item['name']?.toString() ?? '',
        'category': item['category']?.toString() ?? '',
        'unit': item['unit']?.toString() ?? '',
        'raw': encode(item),
        'synced': synced,
        'updated_at': updatedAt,
      });
    }
    for (final item in mapList(universal['vesselItems'])) {
      insert(batch, 'cp_vessel_items', {
        'state_id': stateId,
        'id': item['id']?.toString() ?? '',
        'name': item['name']?.toString() ?? '',
        'category': item['category']?.toString() ?? '',
        'unit': item['unit']?.toString() ?? '',
        'raw': encode(item),
        'synced': synced,
        'updated_at': updatedAt,
      });
    }
  }

  Future<Map<String, dynamic>?> loadSnapshot() async {
    if (kIsWeb) return null;
    final db = await database;
    final userId = await currentUserId();
    final events = await rawRows(db, 'cp_events', 'user_id = ?', [userId]);
    if (!await hasSnapshotRows(db, userId)) return null;
    return {
      'userData': {
        'events': events,
        'clients': await rawRows(db, 'cp_clients', 'user_id = ?', [userId]),
        'employees': await rawRows(db, 'cp_employees', 'user_id = ?', [userId]),
        'attendance':
            await rawRows(db, 'cp_attendance', 'user_id = ?', [userId]),
        'additionalServices': await rawRows(
            db, 'cp_additional_services', 'user_id = ?', [userId]),
        'menuItems':
            await rawRows(db, 'cp_user_menu_items', 'user_id = ?', [userId]),
        'rawMaterials':
            await rawRows(db, 'cp_user_raw_materials', 'user_id = ?', [userId]),
        'produceItems':
            await rawRows(db, 'cp_user_produce_items', 'user_id = ?', [userId]),
        'vesselItems':
            await rawRows(db, 'cp_user_vessel_items', 'user_id = ?', [userId]),
        'customMenus':
            await rawRows(db, 'cp_custom_menus', 'user_id = ?', [userId]),
        'manualInvoices':
            await rawRows(db, 'cp_manual_invoices', 'user_id = ?', [userId]),
        'auditLogs':
            await rawRows(db, 'cp_audit_logs', 'user_id = ?', [userId]),
        'businessProfile': await firstRaw(
              db,
              'cp_business_profiles',
              'user_id = ?',
              [userId],
            ) ??
            {},
      },
      'universal': {
        'menuItems': await rawRows(db, 'cp_menu_items', null, const []),
        'rawMaterials': await rawRows(db, 'cp_raw_materials', null, const []),
        'produceItems': await rawRows(db, 'cp_produce_items', null, const []),
        'vesselItems': await rawRows(db, 'cp_vessel_items', null, const []),
      },
    };
  }

  Future<List<Map<String, dynamic>>> rawRows(
      Database db, String table, String? where, List<Object?> whereArgs) async {
    final rows = await db.query(table,
        where: where == null ? 'state_id = ?' : 'state_id = ? and $where',
        whereArgs: [stateId, ...whereArgs]);
    return rows.map(decodeRaw).toList();
  }

  Future<bool> hasSnapshotRows(Database db, String userId) async {
    for (final table in userTables.where((table) => table != 'cp_users')) {
      final rows = await db.rawQuery(
          'select 1 from $table where state_id = ? and user_id = ? limit 1',
          [stateId, userId]);
      if (rows.isNotEmpty) return true;
    }
    for (final table in [
      'cp_user_menu_items',
      'cp_user_raw_materials',
      'cp_user_produce_items',
      'cp_user_vessel_items'
    ]) {
      final rows = await db.rawQuery(
          'select 1 from $table where state_id = ? and user_id = ? limit 1',
          [stateId, userId]);
      if (rows.isNotEmpty) return true;
    }
    for (final table in [
      'cp_menu_items',
      'cp_raw_materials',
      'cp_produce_items',
      'cp_vessel_items'
    ]) {
      final rows = await db.rawQuery(
          'select 1 from $table where state_id = ? limit 1', [stateId]);
      if (rows.isNotEmpty) return true;
    }
    return false;
  }

  Future<Map<String, dynamic>?> firstRaw(
      Database db, String table, String where, List<Object?> whereArgs) async {
    final rows = await db.query(table,
        where: 'state_id = ? and $where',
        whereArgs: [stateId, ...whereArgs],
        limit: 1);
    if (rows.isEmpty) return null;
    return decodeRaw(rows.first);
  }

  Future<Map<String, int>> syncCounts() async {
    if (kIsWeb) return {};
    final db = await database;
    final counts = <String, int>{};
    for (final table in localTables.reversed) {
      final rows = await db.rawQuery(
          'select count(*) as total, sum(case when synced = 0 then 1 else 0 end) as unsynced from $table where state_id = ?',
          [stateId]);
      counts[table] = (rows.first['unsynced'] as int?) ?? 0;
    }
    return counts;
  }

  Future<bool> hasUnsyncedChanges() async {
    final counts = await syncCounts();
    return counts.values.any((count) => count > 0);
  }

  List<Map<String, dynamic>> mapList(Object? value) => ((value as List?) ?? [])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}
