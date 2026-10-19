import 'package:fatoura/core/storage/hive_database.dart';
import 'package:fatoura/features/invoices/domain/entities/invoice.dart';
import 'package:fatoura/features/parties/domain/entities/party.dart';
import 'package:fatoura/features/parties/domain/repositories/party_repository.dart';

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
  Future<double> getCustomerReceivableBalance(String customerId) async {
    final party = await getPartyById(customerId);
    var balance = party?.openingReceivable ?? 0.0;

    // Add remaining balance of all issued invoices for this customer
    final invoiceBox = database.invoicesBox;
    for (final key in invoiceBox.keys) {
      final map = invoiceBox.get(key);
      if (map != null) {
        final invoice = Invoice.fromMap(Map<String, dynamic>.from(map));
        if (invoice.customerId == customerId && invoice.isIssued) {
          balance += invoice.remainingBalance;
        }
      }
    }

    return balance > 0.0 ? balance : 0.0;
  }

  @override
  Future<double> getSupplierPayableBalance(String supplierId) async {
    final party = await getPartyById(supplierId);
    var balance = party?.openingPayable ?? 0.0;

    // Add remaining payable of all issued purchases for this supplier
    final purchaseBox = database.purchasesBox;
    for (final key in purchaseBox.keys) {
      final map = purchaseBox.get(key);
      if (map != null) {
        final doc = map;
        if (doc['supplierId'] == supplierId &&
            doc['documentStatus'] == 'issued') {
          balance += (doc['remainingPayable'] as num?)?.toDouble() ?? 0.0;
        }
      }
    }

    return balance > 0.0 ? balance : 0.0;
  }
}
