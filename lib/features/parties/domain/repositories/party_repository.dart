import 'package:fatoura/features/parties/domain/entities/party.dart';

abstract class PartyRepository {
  Future<List<Party>> getCustomers({
    String? query,
    bool includeArchived = false,
  });
  Future<List<Party>> getSuppliers({
    String? query,
    bool includeArchived = false,
  });
  Future<Party?> getPartyById(String id);
  Future<void> saveParty(Party party);
  Future<void> archiveParty(String id);
  Future<double> getCustomerReceivableBalance(String customerId);
  Future<double> getSupplierPayableBalance(String supplierId);
  Future<Map<String, double>> getAllCustomerReceivableBalances();
  Future<Map<String, double>> getAllSupplierPayableBalances();
}
