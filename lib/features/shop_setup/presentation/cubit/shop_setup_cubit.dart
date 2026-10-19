import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fatoura/features/shop_setup/domain/entities/shop_profile.dart';
import 'package:fatoura/features/shop_setup/domain/repositories/shop_profile_repository.dart';

abstract class ShopSetupState extends Equatable {
  const ShopSetupState();
  @override
  List<Object?> get props => [];
}

class ShopSetupInitial extends ShopSetupState {}

class ShopSetupLoading extends ShopSetupState {}

class ShopSetupLoaded extends ShopSetupState {
  final ShopProfile? profile;
  final bool isCompleted;

  const ShopSetupLoaded({this.profile, required this.isCompleted});

  @override
  List<Object?> get props => [profile, isCompleted];
}

class ShopSetupSuccess extends ShopSetupState {
  final ShopProfile profile;

  const ShopSetupSuccess(this.profile);

  @override
  List<Object?> get props => [profile];
}

class ShopSetupError extends ShopSetupState {
  final String message;

  const ShopSetupError(this.message);

  @override
  List<Object?> get props => [message];
}

class ShopSetupCubit extends Cubit<ShopSetupState> {
  final ShopProfileRepository repository;

  ShopSetupCubit(this.repository) : super(ShopSetupInitial());

  Future<void> loadProfile() async {
    emit(ShopSetupLoading());
    try {
      final profile = await repository.getProfile();
      final isCompleted = await repository.hasCompletedSetup();
      emit(ShopSetupLoaded(profile: profile, isCompleted: isCompleted));
    } catch (e) {
      emit(ShopSetupError(e.toString()));
    }
  }

  Future<void> saveProfile({
    required String name,
    required String businessType,
    String phone = '',
    String address = '',
    String defaultCurrency = 'EGP',
    String taxNumber = '',
    bool defaultTaxEnabled = false,
    double defaultTaxRate = 15.0,
  }) async {
    if (name.trim().isEmpty) {
      emit(const ShopSetupError('Shop name cannot be empty.'));
      return;
    }
    if (businessType.trim().isEmpty) {
      emit(const ShopSetupError('Business type cannot be empty.'));
      return;
    }

    emit(ShopSetupLoading());
    try {
      final existing = await repository.getProfile();
      final now = DateTime.now();

      final profile = ShopProfile(
        id: existing?.id ?? 'shop_primary',
        name: name.trim(),
        businessType: businessType.trim(),
        phone: phone.trim(),
        address: address.trim(),
        defaultCurrency: defaultCurrency.trim().toUpperCase(),
        taxNumber: taxNumber.trim(),
        defaultTaxEnabled: defaultTaxEnabled,
        defaultTaxRate: defaultTaxRate,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      await repository.saveProfile(profile);
      emit(ShopSetupSuccess(profile));
    } catch (e) {
      emit(ShopSetupError(e.toString()));
    }
  }
}
