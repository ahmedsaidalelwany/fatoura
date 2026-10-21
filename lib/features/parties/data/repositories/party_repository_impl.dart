import 'package:decimal/decimal.dart';
import 'package:fatoura/core/storage/hive_database.dart';
import 'package:fatoura/features/invoices/domain/entities/invoice.dart';
import 'package:fatoura/features/parties/domain/entities/party.dart';
import 'package:fatoura/features/parties/domain/repositories/party_repository.dart';
import 'package:fatoura/features/payments/domain/entities/payment.dart';

class PartyRepositoryImpl implements PartyRepository {
  final HiveDatabase database;

  PartyRepositoryImpl(this.database);

  @override
  Future<List<Party>> getCustomers({
    String? query,
    bool includeArchived = false,
  }) async {
    final box = database.partiesBox;
    final results = <Party>[];

    for (final key in box.keys) {
      final map = box.get(key);
      if (map != null) {
        final party = Party.fromMap(Map<String, dynamic>.from(map));
        if (party.isCustomer && (includeArchived || !party.isArchived)) {
          if (query == null || query.trim().isEmpty) {
            results.add(party);
          } else {
            final q = query.trim().toLowerCase();
            if (party.name.toLowerCase().contains(q) ||
                party.phone.contains(q) ||
                party.address.toLowerCase().contains(q)) {
              results.add(party);
            }
          }
        }
      }
    }

    results.sort((a, b) => a.name.compareTo(b.name));
    return results;
  }

  @override
  Future<List<Party>> getSuppliers({
    String? query,
    bool includeArchived = false,
  }) async {
    final box = database.partiesBox;
    final results = <Party>[];

    for (final key in box.keys) {
      final map = box.get(key);
      if (map != null) {
        final party = Party.fromMap(Map<String, dynamic>.from(map));
        if (party.isSupplier && (includeArchived || !party.isArchived)) {
          if (query == null || query.trim().isEmpty) {
            results.add(party);
          } else {
            final q = query.trim().toLowerCase();
            if (party.name.toLowerCase().contains(q) ||
                party.phone.contains(q) ||
                party.address.toLowerCase().contains(q)) {
              results.add(party);
            }
          }
        }
      }
    }

    results.sort((a, b) => a.name.compareTo(b.name));
    return results;
  }

  @override
  Future<Party?> getPartyById(String id) async {
    final box = database.partiesBox;
    final map = box.get(id);
    if (map == null) return null;
    return Party.fromMap(Map<String, dynamic>.from(map));
  }

  @override
  Future<void> saveParty(Party party) async {
    final box = database.partiesBox;
    await box.put(party.id, party.toMap());
  }

  @override
  Future<void> archiveParty(String id) async {
    final party = await getPartyById(id);
    if (party != null) {
      await saveParty(
        party.copyWith(isArchived: true, updatedAt: DateTime.now()),
      );
    }
  }

  @override
  Future<double> getCustomerReceivableBalance(
    String customerId, {
    String currency = 'EGP',
  }) async {
    final party = await getPartyById(customerId);
    final openingBalance = party?.openingReceivableCurrency == currency
        ? party!.openingReceivable
        : 0.0;
    var balanceDecimal = Decimal.parse(openingBalance.toString());

    // 1. Add remaining balance of all issued invoices for this customer
    final invoiceBox = database.invoicesBox;
    for (final key in invoiceBox.keys) {
      final map = invoiceBox.get(key);
      if (map != null) {
        final invoice = Invoice.fromMap(Map<String, dynamic>.from(map));
        if (invoice.customerId == customerId &&
            invoice.isIssued &&
            invoice.currency == currency) {
          balanceDecimal += Decimal.parse(invoice.remainingBalance.toString());
        }
      }
    }

    // 2. Deduct unallocated customer payments (payments made directly to customer's account or towards opening balance)
    final paymentsBox = database.paymentsBox;
    for (final key in paymentsBox.keys) {
      final map = paymentsBox.get(key);
      if (map != null) {
        final payment = Payment.fromMap(Map<String, dynamic>.from(map));
        if (payment.partyId == customerId &&
            payment.isCustomerPayment &&
            payment.currency == currency) {
          final totalPayment = Decimal.parse(payment.amount.toString());
          final totalAllocated = payment.allocations.fold<Decimal>(
            Decimal.zero,
            (sum, a) => sum + Decimal.parse(a.amount.toString()),
          );
          final unallocated = totalPayment > totalAllocated
              ? totalPayment - totalAllocated
              : Decimal.zero;
          balanceDecimal -= unallocated;
        }
      }
    }

    final balance = balanceDecimal.toDouble();
    return balance > 0.0 ? balance : 0.0;
  }

  @override
  Future<double> getSupplierPayableBalance(
    String supplierId, {
    String currency = 'EGP',
  }) async {
    final party = await getPartyById(supplierId);
    final openingBalance = party?.openingPayableCurrency == currency
        ? party!.openingPayable
        : 0.0;
    var balanceDecimal = Decimal.parse(openingBalance.toString());

    // 1. Add remaining payable of all issued purchases for this supplier
    final purchaseBox = database.purchasesBox;
    for (final key in purchaseBox.keys) {
      final map = purchaseBox.get(key);
      if (map != null) {
        final doc = map;
        if (doc['supplierId'] == supplierId &&
            doc['documentStatus'] == 'issued' &&
            (doc['currency'] as String? ?? 'EGP') == currency) {
          final remaining =
              (doc['remainingPayable'] as num?)?.toDouble() ?? 0.0;
          balanceDecimal += Decimal.parse(remaining.toString());
        }
      }
    }

    // 2. Deduct unallocated supplier disbursements (payments made towards opening payable or on-account)
    final paymentsBox = database.paymentsBox;
    for (final key in paymentsBox.keys) {
      final map = paymentsBox.get(key);
      if (map != null) {
        final payment = Payment.fromMap(Map<String, dynamic>.from(map));
        if (payment.partyId == supplierId &&
            !payment.isCustomerPayment &&
            payment.currency == currency) {
          final totalPayment = Decimal.parse(payment.amount.toString());
          final totalAllocated = payment.allocations.fold<Decimal>(
            Decimal.zero,
            (sum, a) => sum + Decimal.parse(a.amount.toString()),
          );
          final unallocated = totalPayment > totalAllocated
              ? totalPayment - totalAllocated
              : Decimal.zero;
          balanceDecimal -= unallocated;
        }
      }
    }

    final balance = balanceDecimal.toDouble();
    return balance > 0.0 ? balance : 0.0;
  }

  @override
  Future<Map<String, double>> getAllCustomerReceivableBalances({
    String currency = 'EGP',
  }) async {
    final customers = await getCustomers(includeArchived: true);
    final balances = <String, Decimal>{};
    for (final c in customers) {
      final openingBalance = c.openingReceivableCurrency == currency
          ? c.openingReceivable
          : 0.0;
      balances[c.id] = Decimal.parse(openingBalance.toString());
    }

    final invoiceBox = database.invoicesBox;
    for (final key in invoiceBox.keys) {
      final map = invoiceBox.get(key);
      if (map != null) {
        final invoice = Invoice.fromMap(Map<String, dynamic>.from(map));
        if (invoice.customerId != null &&
            invoice.isIssued &&
            invoice.currency == currency) {
          final custId = invoice.customerId!;
          final rem = Decimal.parse(invoice.remainingBalance.toString());
          balances[custId] = (balances[custId] ?? Decimal.zero) + rem;
        }
      }
    }

    final paymentsBox = database.paymentsBox;
    for (final key in paymentsBox.keys) {
      final map = paymentsBox.get(key);
      if (map != null) {
        final payment = Payment.fromMap(Map<String, dynamic>.from(map));
        if (payment.isCustomerPayment &&
            payment.currency == currency &&
            payment.partyId != null &&
            payment.partyId!.isNotEmpty) {
          final custId = payment.partyId!;
          final totalPayment = Decimal.parse(payment.amount.toString());
          final totalAllocated = payment.allocations.fold<Decimal>(
            Decimal.zero,
            (sum, a) => sum + Decimal.parse(a.amount.toString()),
          );
          final unallocated = totalPayment > totalAllocated
              ? totalPayment - totalAllocated
              : Decimal.zero;
          balances[custId] = (balances[custId] ?? Decimal.zero) - unallocated;
        }
      }
    }

    return balances.map((key, val) {
      final doubleVal = val.toDouble();
      return MapEntry(key, doubleVal > 0.0 ? doubleVal : 0.0);
    });
  }

  @override
  Future<Map<String, double>> getAllSupplierPayableBalances({
    String currency = 'EGP',
  }) async {
    final suppliers = await getSuppliers(includeArchived: true);
    final balances = <String, Decimal>{};
    for (final s in suppliers) {
      final openingBalance = s.openingPayableCurrency == currency
          ? s.openingPayable
          : 0.0;
      balances[s.id] = Decimal.parse(openingBalance.toString());
    }

    final purchaseBox = database.purchasesBox;
    for (final key in purchaseBox.keys) {
      final map = purchaseBox.get(key);
      if (map != null) {
        final doc = map;
        if (doc['documentStatus'] == 'issued' &&
            (doc['currency'] as String? ?? 'EGP') == currency &&
            doc['supplierId'] != null) {
          final suppId = doc['supplierId'] as String;
          final remaining =
              (doc['remainingPayable'] as num?)?.toDouble() ?? 0.0;
          balances[suppId] =
              (balances[suppId] ?? Decimal.zero) +
              Decimal.parse(remaining.toString());
        }
      }
    }

    final paymentsBox = database.paymentsBox;
    for (final key in paymentsBox.keys) {
      final map = paymentsBox.get(key);
      if (map != null) {
        final payment = Payment.fromMap(Map<String, dynamic>.from(map));
        if (!payment.isCustomerPayment &&
            payment.currency == currency &&
            payment.partyId != null &&
            payment.partyId!.isNotEmpty) {
          final suppId = payment.partyId!;
          final totalPayment = Decimal.parse(payment.amount.toString());
          final totalAllocated = payment.allocations.fold<Decimal>(
            Decimal.zero,
            (sum, a) => sum + Decimal.parse(a.amount.toString()),
          );
          final unallocated = totalPayment > totalAllocated
              ? totalPayment - totalAllocated
              : Decimal.zero;
          balances[suppId] = (balances[suppId] ?? Decimal.zero) - unallocated;
        }
      }
    }

    return balances.map((key, val) {
      final doubleVal = val.toDouble();
      return MapEntry(key, doubleVal > 0.0 ? doubleVal : 0.0);
    });
  }
}
