import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import 'package:fatoura/features/parties/domain/entities/party.dart';
import 'package:fatoura/features/parties/domain/repositories/party_repository.dart';

abstract class PartiesState extends Equatable {
  const PartiesState();
  @override
  List<Object?> get props => [];
}

class PartiesInitial extends PartiesState {}

class PartiesLoading extends PartiesState {}

class CustomersLoaded extends PartiesState {
  final List<Party> customers;
  final Map<String, double> balances;

  const CustomersLoaded({required this.customers, this.balances = const {}});

  @override
  List<Object?> get props => [customers, balances];
}

class SuppliersLoaded extends PartiesState {
  final List<Party> suppliers;
  final Map<String, double> balances;

  const SuppliersLoaded({required this.suppliers, this.balances = const {}});

  @override
  List<Object?> get props => [suppliers, balances];
}

class PartyOperationSuccess extends PartiesState {
  final String message;

  const PartyOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class PartiesError extends PartiesState {
  final String message;

  const PartiesError(this.message);

  @override
  List<Object?> get props => [message];
}

class PartiesCubit extends Cubit<PartiesState> {
  final PartyRepository repository;

  PartiesCubit(this.repository) : super(PartiesInitial());

  Future<void> loadCustomers({String? query}) async {
    emit(PartiesLoading());
    try {
      final customers = await repository.getCustomers(query: query);
      final balances = await repository.getAllCustomerReceivableBalances();
      emit(CustomersLoaded(customers: customers, balances: balances));
    } catch (e) {
      emit(PartiesError(e.toString()));
    }
  }

  Future<void> loadSuppliers({String? query}) async {
    emit(PartiesLoading());
    try {
      final suppliers = await repository.getSuppliers(query: query);
      final balances = await repository.getAllSupplierPayableBalances();
      emit(SuppliersLoaded(suppliers: suppliers, balances: balances));
    } catch (e) {
      emit(PartiesError(e.toString()));
    }
  }

  Future<void> saveParty({
    String? id,
    required String name,
    String phone = '',
    String address = '',
    String email = '',
    String notes = '',
    required bool isCustomer,
    required bool isSupplier,
    double openingReceivable = 0.0,
    double openingPayable = 0.0,
  }) async {
    if (name.trim().isEmpty) {
      emit(const PartiesError('Party name cannot be empty.'));
      return;
    }

    emit(PartiesLoading());
    try {
      final partyId = id ?? const Uuid().v4();
      final now = DateTime.now();

      final party = Party(
        id: partyId,
        name: name.trim(),
        phone: phone.trim(),
        address: address.trim(),
        email: email.trim(),
        notes: notes.trim(),
        isCustomer: isCustomer,
        isSupplier: isSupplier,
        openingReceivable: openingReceivable,
        openingPayable: openingPayable,
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveParty(party);
      emit(const PartyOperationSuccess('Party saved successfully'));

      if (isCustomer) {
        await loadCustomers();
      } else {
        await loadSuppliers();
      }
    } catch (e) {
      emit(PartiesError(e.toString()));
    }
  }

  Future<void> archiveParty(String id, bool isCustomer) async {
    emit(PartiesLoading());
    try {
      await repository.archiveParty(id);
      emit(const PartyOperationSuccess('Party archived successfully'));
      if (isCustomer) {
        await loadCustomers();
      } else {
        await loadSuppliers();
      }
    } catch (e) {
      emit(PartiesError(e.toString()));
    }
  }
}
