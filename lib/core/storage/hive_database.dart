import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

class HiveBoxes {
  HiveBoxes._();

  static const String shopProfile = 'box_shop_profile';
  static const String parties = 'box_parties';
  static const String products = 'box_products';
  static const String invoices = 'box_invoices';
  static const String payments = 'box_payments';
  static const String salesReturns = 'box_sales_returns';
  static const String purchases = 'box_purchases';
  static const String auditLogs = 'box_audit_logs';
  static const String sequenceCounters = 'box_sequence_counters';
  static const String inventoryMovements = 'box_inventory_movements';

  static const List<String> allBoxes = [
    shopProfile,
    parties,
    products,
    invoices,
    payments,
    salesReturns,
    purchases,
    auditLogs,
    sequenceCounters,
    inventoryMovements,
  ];
}

class HiveDatabase {
  static final HiveDatabase instance = HiveDatabase._internal();

  HiveDatabase._internal();

  bool _isInitialized = false;
  Future<void> _operationLock = Future.value();

  bool get isInitialized => _isInitialized;

  static const Symbol _exclusiveZoneKey = #hiveDatabaseExclusiveZone;

  Future<T> runExclusive<T>(Future<T> Function() action) {
    if (Zone.current[_exclusiveZoneKey] == true) {
      return action();
    }
    final previous = _operationLock;
    final completer = Completer<void>();
    _operationLock = completer.future;
    return previous
        .then((_) => runZoned(action, zoneValues: {_exclusiveZoneKey: true}))
        .whenComplete(completer.complete);
  }

  Future<void> init({String? customPath}) async {
    if (_isInitialized) return;

    if (customPath != null) {
      Hive.init(customPath);
    } else {
      if (!kIsWeb) {
        final appDocDir = await getApplicationDocumentsDirectory();
        final path = '${appDocDir.path}/fatoura_data';
        await Hive.initFlutter(path);
      } else {
        await Hive.initFlutter();
      }
    }

    // Open all core boxes concurrently in parallel
    final unopenedBoxes = HiveBoxes.allBoxes.where((b) => !Hive.isBoxOpen(b));
    await Future.wait(
      unopenedBoxes.map((boxName) => Hive.openBox<Map>(boxName)),
    );

    _isInitialized = true;
  }

  Box<Map> getBox(String boxName) {
    if (!Hive.isBoxOpen(boxName)) {
      throw StateError(
        'Hive box $boxName is not open. Ensure HiveDatabase.init() was called.',
      );
    }
    return Hive.box<Map>(boxName);
  }

  Box<Map> get shopProfileBox => getBox(HiveBoxes.shopProfile);
  Box<Map> get partiesBox => getBox(HiveBoxes.parties);
  Box<Map> get productsBox => getBox(HiveBoxes.products);
  Box<Map> get invoicesBox => getBox(HiveBoxes.invoices);
  Box<Map> get paymentsBox => getBox(HiveBoxes.payments);
  Box<Map> get salesReturnsBox => getBox(HiveBoxes.salesReturns);
  Box<Map> get purchasesBox => getBox(HiveBoxes.purchases);
  Box<Map> get auditLogsBox => getBox(HiveBoxes.auditLogs);
  Box<Map> get sequenceCountersBox => getBox(HiveBoxes.sequenceCounters);
  Box<Map> get inventoryMovementsBox => getBox(HiveBoxes.inventoryMovements);

  /// Dumps all database boxes into a JSON-serializable Map for backup
  Future<Map<String, dynamic>> exportAllData() async {
    final export = <String, dynamic>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': <String, dynamic>{},
    };

    final tables = <String, dynamic>{};
    for (final boxName in HiveBoxes.allBoxes) {
      final box = getBox(boxName);
      final boxData = <String, dynamic>{};
      for (final key in box.keys) {
        final val = box.get(key);
        if (val != null) {
          boxData[key.toString()] = Map<String, dynamic>.from(val);
        }
      }
      tables[boxName] = boxData;
    }

    export['tables'] = tables;
    return export;
  }

  /// Restores all database boxes from a verified backup payload using staged verification.
  Future<void> restoreAllData(Map<String, dynamic> backupData) async {
    final tables = backupData['tables'] as Map<String, dynamic>?;
    if (tables == null) {
      throw ArgumentError('Malformed backup data: missing tables map');
    }
    for (final boxName in HiveBoxes.allBoxes) {
      if (!tables.containsKey(boxName)) {
        if (boxName == HiveBoxes.inventoryMovements) {
          tables[boxName] = <String, dynamic>{};
        } else {
          throw ArgumentError('Malformed backup data: missing table $boxName');
        }
      }
    }

    // 1. Stage and validate all tables and records in memory BEFORE modifying any live box
    final staged = <String, Map<String, dynamic>>{};
    for (final boxName in HiveBoxes.allBoxes) {
      final boxData = tables[boxName];
      if (boxData is! Map) {
        throw ArgumentError('Table $boxName must be a Map of records');
      }
      final records = <String, dynamic>{};
      for (final entry in boxData.entries) {
        if (entry.value is! Map) {
          throw ArgumentError('Record ${entry.key} in $boxName must be a Map');
        }
        records[entry.key.toString()] = Map<String, dynamic>.from(
          entry.value as Map,
        );
      }
      staged[boxName] = records;
    }

    // 2. Atomically commit staged data into live Hive boxes
    for (final boxName in HiveBoxes.allBoxes) {
      final box = getBox(boxName);
      await box.clear();
      final records = staged[boxName]!;
      for (final entry in records.entries) {
        await box.put(entry.key, entry.value);
      }
    }
  }

  Future<void> clearAll() async {
    for (final boxName in HiveBoxes.allBoxes) {
      final box = getBox(boxName);
      await box.clear();
    }
  }

  Future<void> close() async {
    await Hive.close();
    _isInitialized = false;
  }
}
