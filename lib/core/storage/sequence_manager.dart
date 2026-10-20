import 'dart:async';

import 'package:intl/intl.dart';

import 'hive_database.dart';

class SequenceManager {
  final HiveDatabase database;
  Future<void> _lock = Future.value();

  SequenceManager(this.database);

  Future<T> _synchronized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _lock = _lock.then((_) async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  /// Generates the next atomic sequential number for a given document prefix.
  /// Format: `[PREFIX]-DD.MM.YYYY-NNNN` (e.g. `Ftr-19.10.2026-0001`)
  /// Serialized with an async mutex lock to guarantee uniqueness under concurrency.
  Future<String> getNextNumber({
    required String prefix,
    DateTime? date,
    required String targetBoxName,
    required String numberFieldName,
  }) {
    return _synchronized(() async {
      final localDate = date ?? DateTime.now();
      final dateKey = DateFormat('dd.MM.yyyy').format(localDate);
      final counterKey = '${prefix}_$dateKey';

      final counterBox = database.sequenceCountersBox;
      final currentCounterMap = counterBox.get(counterKey);
      var nextIndex = 1;

      if (currentCounterMap != null &&
          currentCounterMap['lastNumber'] != null) {
        nextIndex = (currentCounterMap['lastNumber'] as int) + 1;
      }

      // Safety reconciliation: Inspect target box to prevent collisions
      final targetBox = database.getBox(targetBoxName);
      while (true) {
        final formattedNumber =
            '$prefix-$dateKey-${nextIndex.toString().padLeft(4, '0')}';

        bool conflict = false;
        for (final key in targetBox.keys) {
          final doc = targetBox.get(key);
          if (doc != null && doc[numberFieldName] == formattedNumber) {
            conflict = true;
            break;
          }
        }

        if (!conflict) {
          // Atomically save the allocated index before returning
          await counterBox.put(counterKey, {
            'date': dateKey,
            'prefix': prefix,
            'lastNumber': nextIndex,
            'updatedAt': DateTime.now().toIso8601String(),
          });
          return formattedNumber;
        }

        // If collision was found in existing records, increment and re-check
        nextIndex++;
      }
    });
  }

  Future<String> getNextInvoiceNumber([DateTime? date]) {
    return getNextNumber(
      prefix: 'Ftr',
      date: date,
      targetBoxName: HiveBoxes.invoices,
      numberFieldName: 'invoiceNumber',
    );
  }

  Future<String> getNextPurchaseNumber([DateTime? date]) {
    return getNextNumber(
      prefix: 'Pur',
      date: date,
      targetBoxName: HiveBoxes.purchases,
      numberFieldName: 'purchaseNumber',
    );
  }

  Future<String> getNextReturnNumber([DateTime? date]) {
    return getNextNumber(
      prefix: 'Ret',
      date: date,
      targetBoxName: HiveBoxes.salesReturns,
      numberFieldName: 'returnNumber',
    );
  }
}
